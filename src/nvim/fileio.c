// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// fileio.c: read from and write to a file

#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <string.h>
#include <inttypes.h>
#include <fcntl.h>

#include "nvim/vim.h"
#include "nvim/api/private/handle.h"
#include "nvim/ascii.h"
#include "nvim/fileio.h"
#include "nvim/buffer.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/fold.h"
#include "nvim/func_attr.h"
#include "nvim/getchar.h"
#include "nvim/hashtab.h"
#include "nvim/iconv.h"
#include "nvim/mbyte.h"
#include "nvim/memfile.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/garray.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/path.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/search.h"
#include "nvim/sha256.h"
#include "nvim/state.h"
#include "nvim/strings.h"
#include "nvim/ui.h"
#include "nvim/ui_compositor.h"
#include "nvim/types.h"
#include "nvim/undo.h"
#include "nvim/window.h"
#include "nvim/shada.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/os/time.h"
#include "nvim/os/input.h"

#define BUFSIZE         8192    /* size of normal write buffer */
#define SMBUFSIZE       256     /* size of emergency write buffer */

//
// The autocommands are stored in a list for each event.
// Autocommands for the same pattern, that are consecutive, are joined
// together, to avoid having to match the pattern too often.
// The result is an array of Autopat lists, which point to AutoCmd lists:
//
// last_autopat[0]  -----------------------------+
//                                               V
// first_autopat[0] --> Autopat.next  -->  Autopat.next -->  NULL
//                      Autopat.cmds       Autopat.cmds
//                          |                    |
//                          V                    V
//                      AutoCmd.next       AutoCmd.next
//                          |                    |
//                          V                    V
//                      AutoCmd.next            NULL
//                          |
//                          V
//                         NULL
//
// last_autopat[1]  --------+
//                          V
// first_autopat[1] --> Autopat.next  -->  NULL
//                      Autopat.cmds
//                          |
//                          V
//                      AutoCmd.next
//                          |
//                          V
//                         NULL
//   etc.
//
//   The order of AutoCmds is important, this is the order in which they were
//   defined and will have to be executed.
//
typedef struct AutoCmd {
  char_u          *cmd;                 // Command to be executed (NULL when
                                        // command has been removed)
  bool once;                            // "One shot": removed after execution
  char nested;                          // If autocommands nest here
  char last;                            // last command in list
  sctx_T script_ctx;                    // script context where defined
  struct AutoCmd  *next;                // Next AutoCmd in list
} AutoCmd;

typedef struct AutoPat {
  struct AutoPat  *next;                // next AutoPat in AutoPat list; MUST
                                        // be the first entry
  char_u          *pat;                 // pattern as typed (NULL when pattern
                                        // has been removed)
  regprog_T       *reg_prog;            // compiled regprog for pattern
  AutoCmd         *cmds;                // list of commands to do
  int group;                            // group ID
  int patlen;                           // strlen() of pat
  int buflocal_nr;                      // !=0 for buffer-local AutoPat
  char allow_dirs;                      // Pattern may match whole path
  char last;                            // last pattern for apply_autocmds()
} AutoPat;

///
/// Struct used to keep status while executing autocommands for an event.
///
typedef struct AutoPatCmd {
  AutoPat     *curpat;          // next AutoPat to examine
  AutoCmd     *nextcmd;         // next AutoCmd to execute
  int group;                    // group being used
  char_u      *fname;           // fname to match with
  char_u      *sfname;          // sfname to match with
  char_u      *tail;            // tail of fname
  event_T event;                // current event
  int arg_bufnr;                // initially equal to <abuf>, set to zero when
                                // buf is deleted
  struct AutoPatCmd   *next;    // chain of active apc-s for auto-invalidation
} AutoPatCmd;

#define AUGROUP_DEFAULT    -1      /* default autocmd group */
#define AUGROUP_ERROR      -2      /* erroneous autocmd group */
#define AUGROUP_ALL        -3      /* all autocmd groups */

#define HAS_BW_FLAGS
#define FIO_LATIN1     0x01    /* convert Latin1 */
#define FIO_UTF8       0x02    /* convert UTF-8 */
#define FIO_UCS2       0x04    /* convert UCS-2 */
#define FIO_UCS4       0x08    /* convert UCS-4 */
#define FIO_UTF16      0x10    /* convert UTF-16 */
#define FIO_ENDIAN_L   0x80    /* little endian */
#define FIO_NOCONVERT  0x2000  /* skip encoding conversion */
#define FIO_UCSBOM     0x4000  /* check for BOM at start of file */
#define FIO_ALL        -1      /* allow all formats */

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
  int bw_fd;                     // file descriptor
  char_u      *bw_buf;           // buffer with data to be written
  int bw_len;                    // length of data
#ifdef HAS_BW_FLAGS
  int bw_flags;                  // FIO_ flags
#endif
  char_u bw_rest[CONV_RESTLEN];  // not converted bytes
  int bw_restlen;                // nr of bytes in bw_rest[]
  int bw_first;                  // first write call
  char_u      *bw_conv_buf;      // buffer for writing converted chars
  int bw_conv_buflen;            // size of bw_conv_buf
  int bw_conv_error;             // set for conversion error
  linenr_T bw_conv_error_lnum;   // first line with error or zero
  linenr_T bw_start_lnum;        // line number at start of buffer
# ifdef HAVE_ICONV
  iconv_t bw_iconv_fd;           // descriptor for iconv() or -1
# endif
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "fileio.c.generated.h"
#endif

static char *e_auchangedbuf = N_(
    "E812: Autocommands changed buffer or buffer name");

// Set by the apply_autocmds_group function if the given event is equal to
// EVENT_FILETYPE. Used by the readfile function in order to determine if
// EVENT_BUFREADPOST triggered the EVENT_FILETYPE.
//
// Relying on this value requires one to reset it prior calling
// apply_autocmds_group.
static bool au_did_filetype INIT(= false);

void filemess(buf_T *buf, char_u *name, char_u *s, int attr)
{
  int msg_scroll_save;

  if (msg_silent != 0) {
    return;
  }
  add_quoted_fname((char *)IObuff, IOSIZE - 80, buf, (const char *)name);
  xstrlcat((char *)IObuff, (const char *)s, IOSIZE);
  // For the first message may have to start a new line.
  // For further ones overwrite the previous one, reset msg_scroll before
  // calling filemess().
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
  ui_flush();
  msg_scrolled_ign = FALSE;
}

static AutoPat *last_autopat[NUM_EVENTS] = {
  NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
  NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
  NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
  NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
  NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
  NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
};

/*
 * Read lines from file "fname" into the buffer after line "from".
 *
 * 1. We allocate blocks with try_malloc, as big as possible.
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
 * READ_FIFO	read from fifo/socket instead of a file
 *
 * return FAIL for failure, NOTDONE for directory (failure), or OK
 */
int
readfile(
    char_u *fname,
    char_u *sfname,
    linenr_T from,
    linenr_T lines_to_skip,
    linenr_T lines_to_read,
    exarg_T *eap,                       // can be NULL!
    int flags
)
{
  int fd = 0;
  int newfile = (flags & READ_NEW);
  int check_readonly;
  int filtering = (flags & READ_FILTER);
  int read_stdin = (flags & READ_STDIN);
  int read_buffer = (flags & READ_BUFFER);
  int read_fifo = (flags & READ_FIFO);
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
  uint8_t *p = NULL;
  off_T filesize = 0;
  int skip_read = false;
  context_sha256_T sha_ctx;
  int read_undo_file = false;
  linenr_T linecnt;
  int error = FALSE;                    /* errors encountered */
  int ff_error = EOL_UNKNOWN;           /* file format with errors */
  long linerest = 0;                    /* remaining chars in line */
  int perm = 0;
#ifdef UNIX
  int swap_mode = -1;                   /* protection bits for swap file */
#endif
  int fileformat = 0;                   // end-of-line format
  bool keep_fileformat = false;
  FileInfo file_info;
  int file_readonly;
  linenr_T skip_count = 0;
  linenr_T read_count = 0;
  int msg_save = msg_scroll;
  linenr_T read_no_eol_lnum = 0;        // non-zero lnum when last line of
                                        // last read was missing the eol
  bool file_rewind = false;
  int can_retry;
  linenr_T conv_error = 0;              // line nr with conversion error
  linenr_T illegal_byte = 0;            // line nr with illegal byte
  bool keep_dest_enc = false;           // don't retry when char doesn't fit
                                        // in destination encoding
  int bad_char_behavior = BAD_REPLACE;
  /* BAD_KEEP, BAD_DROP or character to
   * replace with */
  char_u      *tmpname = NULL;          /* name of 'charconvert' output file */
  int fio_flags = 0;
  char_u      *fenc;                    // fileencoding to use
  bool fenc_alloced;                    // fenc_next is in allocated memory
  char_u      *fenc_next = NULL;        // next item in 'fencs' or NULL
  bool advance_fenc = false;
  long real_size = 0;
# ifdef HAVE_ICONV
  iconv_t iconv_fd = (iconv_t)-1;       // descriptor for iconv() or -1
  int did_iconv = false;                // TRUE when iconv() failed and trying
                                        // 'charconvert' next
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

  au_did_filetype = false;  // reset before triggering any autocommands

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

  // For Unix: Use the short file name whenever possible.
  // Avoids problems with networks and when directory names are changed.
  // Don't do this for Windows, a "cd" in a sub-shell may have moved us to
  // another directory, which we don't detect.
  if (sfname == NULL) {
    sfname = fname;
  }
#if defined(UNIX)
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
   * If the name is too long we might crash further on, quit here.
   */
  if (fname != NULL && *fname != NUL) {
    if (STRLEN(fname) >= MAXPATHL) {
      filemess(curbuf, fname, (char_u *)_("Illegal file name"), 0);
      msg_end();
      msg_scroll = msg_save;
      return FAIL;
    }
  }

  if (!read_buffer && !read_stdin && !read_fifo) {
    perm = os_getperm((const char *)fname);
#ifdef UNIX
    // On Unix it is possible to read a directory, so we have to
    // check for it before os_open().
    if (perm >= 0 && !S_ISREG(perm)                 // not a regular file ...
# ifdef S_ISFIFO
        && !S_ISFIFO(perm)                          // ... or fifo
# endif
# ifdef S_ISSOCK
        && !S_ISSOCK(perm)                          // ... or socket
# endif
# ifdef OPEN_CHR_FILES
        && !(S_ISCHR(perm) && is_dev_fd_file(fname))
        // ... or a character special file named /dev/fd/<n>
# endif
        ) {
      if (S_ISDIR(perm)) {
        filemess(curbuf, fname, (char_u *)_("is a directory"), 0);
      } else {
        filemess(curbuf, fname, (char_u *)_("is not a file"), 0);
      }
      msg_end();
      msg_scroll = msg_save;
      return S_ISDIR(perm) ? NOTDONE : FAIL;
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

  if (newfile && !read_stdin && !read_buffer && !read_fifo) {
    // Remember time of file.
    if (os_fileinfo((char *)fname, &file_info)) {
      buf_store_file_info(curbuf, &file_info);
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
      swap_mode = (file_info.stat.st_mode & 0644) | 0600;
#endif
    } else {
      curbuf->b_mtime = 0;
      curbuf->b_mtime_read = 0;
      curbuf->b_orig_size = 0;
      curbuf->b_orig_mode = 0;
    }

    /* Reset the "new file" flag.  It will be set again below when the
     * file doesn't exist. */
    curbuf->b_flags &= ~(BF_NEW | BF_NEW_W);
  }

  // Check readonly.
  file_readonly = false;
  if (!read_buffer && !read_stdin) {
    if (!newfile || readonlymode || !(perm & 0222)
        || !os_file_is_writable((char *)fname)) {
      file_readonly = true;
    }
    fd = os_open((char *)fname, O_RDONLY, 0);
  }

  if (fd < 0) {                     // cannot open at all
    msg_scroll = msg_save;
#ifndef UNIX
    // On non-unix systems we can't open a directory, check here.
    if (os_isdir(fname)) {
      filemess(curbuf, sfname, (char_u *)_("is a directory"), 0);
      curbuf->b_p_ro = true;        // must use "w!" now
    } else {
#endif
    if (!newfile) {
      return FAIL;
    }
    if (perm == UV_ENOENT) {  // check if the file exists
      // Set the 'new-file' flag, so that when the file has
      // been created by someone else, a ":w" will complain.
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
    } else {
      filemess(curbuf, sfname, (char_u *)(
            (fd == UV_EFBIG) ? _("[File too big]") :
# if defined(UNIX) && defined(EOVERFLOW)
            // libuv only returns -errno in Unix and in Windows open() does not
            // set EOVERFLOW
            (fd == -EOVERFLOW) ? _("[File too big]") :
# endif
            _("[Permission Denied]")), 0);
      curbuf->b_p_ro = TRUE;                  /* must use "w!" now */
    }

    return FAIL;
  }
#ifndef UNIX
  }
#endif

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
    if (!read_stdin
        && (curbuf != old_curbuf
            || (using_b_ffname && (old_b_ffname != curbuf->b_ffname))
            || (using_b_fname && (old_b_fname != curbuf->b_fname)))) {
      EMSG(_(e_auchangedbuf));
      if (!read_buffer) {
        close(fd);
      }
      return FAIL;
    }
#ifdef UNIX
    // Set swap file protection bits after creating it.
    if (swap_mode > 0 && curbuf->b_ml.ml_mfp != NULL
        && curbuf->b_ml.ml_mfp->mf_fname != NULL) {
      const char *swap_fname = (const char *)curbuf->b_ml.ml_mfp->mf_fname;

      // If the group-read bit is set but not the world-read bit, then
      // the group must be equal to the group of the original file.  If
      // we can't make that happen then reset the group-read bit.  This
      // avoids making the swap file readable to more users when the
      // primary group of the user is too permissive.
      if ((swap_mode & 044) == 040) {
        FileInfo swap_info;

        if (os_fileinfo(swap_fname, &swap_info)
            && file_info.stat.st_gid != swap_info.stat.st_gid
            && os_fchown(curbuf->b_ml.ml_mfp->mf_fd, -1, file_info.stat.st_gid)
            == -1) {
          swap_mode &= 0600;
        }
      }

      (void)os_setperm(swap_fname, swap_mode);
    }
#endif
  }

  // If "Quit" selected at ATTENTION dialog, don't load the file.
  if (swap_exists_action == SEA_QUIT) {
    if (!read_buffer && !read_stdin)
      close(fd);
    return FAIL;
  }

  ++no_wait_return;         /* don't wait for return yet */

  /*
   * Set '[ mark to the line above where the lines go (line 1 if zero).
   */
  curbuf->b_op_start.lnum = ((from == 0) ? 1 : from);
  curbuf->b_op_start.col = 0;

  int try_mac = (vim_strchr(p_ffs, 'm') != NULL);
  int try_dos = (vim_strchr(p_ffs, 'd') != NULL);
  int try_unix = (vim_strchr(p_ffs, 'x') != NULL);

  if (!read_buffer) {
    int m = msg_scroll;
    int n = msg_scrolled;

    // The file must be closed again, the autocommands may want to change
    // the file before reading it.
    if (!read_stdin) {
      close(fd);                // ignore errors
    }

    // The output from the autocommands should not overwrite anything and
    // should not be overwritten: Set msg_scroll, restore its value if no
    // output was done.
    msg_scroll = true;
    if (filtering) {
      apply_autocmds_exarg(EVENT_FILTERREADPRE, NULL, sfname,
                           false, curbuf, eap);
    } else if (read_stdin) {
      apply_autocmds_exarg(EVENT_STDINREADPRE, NULL, sfname,
                           false, curbuf, eap);
    } else if (newfile) {
      apply_autocmds_exarg(EVENT_BUFREADPRE, NULL, sfname,
                           false, curbuf, eap);
    } else {
      apply_autocmds_exarg(EVENT_FILEREADPRE, sfname, sfname,
                           false, NULL, eap);
    }

    // autocommands may have changed it
    try_mac = (vim_strchr(p_ffs, 'm') != NULL);
    try_dos = (vim_strchr(p_ffs, 'd') != NULL);
    try_unix = (vim_strchr(p_ffs, 'x') != NULL);

    if (msg_scrolled == n) {
      msg_scroll = m;
    }

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
                        || (fd = os_open((char *)fname, O_RDONLY, 0)) < 0)) {
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
    if (!read_stdin && !read_buffer) {
      filemess(curbuf, sfname, (char_u *)"", 0);
    }
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
    fenc_alloced = true;
    keep_dest_enc = true;
  } else if (curbuf->b_p_bin) {
    fenc = (char_u *)"";                // binary: don't convert
    fenc_alloced = false;
  } else if (curbuf->b_help) {
    // Help files are either utf-8 or latin1.  Try utf-8 first, if this
    // fails it must be latin1.
    // It is needed when the first line contains non-ASCII characters.
    // That is only in *.??x files.
    fenc_next = (char_u *)"latin1";
    fenc = (char_u *)"utf-8";

    fenc_alloced = false;
  } else if (*p_fencs == NUL) {
    fenc = curbuf->b_p_fenc;            // use format from buffer
    fenc_alloced = false;
  } else {
    fenc_next = p_fencs;                // try items in 'fileencodings'
    fenc = next_fenc(&fenc_next, &fenc_alloced);
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
    } else if (read_stdin || vim_lseek(fd, (off_T)0L, SEEK_SET) != 0) {
      // Can't rewind the file, give up.
      error = true;
      goto failed;
    }
    // Delete the previously read lines.
    while (lnum > from) {
      ml_delete(lnum--, false);
    }
    file_rewind = false;
    if (set_options) {
      curbuf->b_p_bomb = FALSE;
      curbuf->b_start_bomb = FALSE;
    }
    conv_error = 0;
  }

  /*
   * When retrying with another "fenc" and the first time "fileformat"
   * will be reset.
   */
  if (keep_fileformat) {
    keep_fileformat = false;
  } else {
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

# ifdef HAVE_ICONV
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
    advance_fenc = false;

    if (eap != NULL && eap->force_enc != 0) {
      /* Conversion given with "++cc=" wasn't possible, read
       * without conversion. */
      notconverted = TRUE;
      conv_error = 0;
      if (fenc_alloced)
        xfree(fenc);
      fenc = (char_u *)"";
      fenc_alloced = false;
    } else {
      if (fenc_alloced)
        xfree(fenc);
      if (fenc_next != NULL) {
        fenc = next_fenc(&fenc_next, &fenc_alloced);
      } else {
        fenc = (char_u *)"";
        fenc_alloced = false;
      }
    }
    if (tmpname != NULL) {
      os_remove((char *)tmpname);  // delete converted file
      XFREE_CLEAR(tmpname);
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



# ifdef HAVE_ICONV
    // Try using iconv() if we can't convert internally.
    if (fio_flags == 0
        && !did_iconv
        ) {
      iconv_fd = (iconv_t)my_iconv_open(
          enc_utf8 ? (char_u *)"utf-8" : p_enc, fenc);
    }
# endif

    /*
     * Use the 'charconvert' expression when conversion is required
     * and we can't do it internally or with iconv().
     */
    if (fio_flags == 0 && !read_stdin && !read_buffer && *p_ccv != NUL
        && !read_fifo
#  ifdef HAVE_ICONV
        && iconv_fd == (iconv_t)-1
#  endif
        ) {
#  ifdef HAVE_ICONV
      did_iconv = false;
#  endif
      /* Skip conversion when it's already done (retry for wrong
       * "fileformat"). */
      if (tmpname == NULL) {
        tmpname = readfile_charconvert(fname, fenc, &fd);
        if (tmpname == NULL) {
          // Conversion failed.  Try another one.
          advance_fenc = true;
          if (fd < 0) {
            /* Re-opening the original file failed! */
            EMSG(_("E202: Conversion made file unreadable!"));
            error = TRUE;
            goto failed;
          }
          goto retry;
        }
      }
    } else {
      if (fio_flags == 0
# ifdef HAVE_ICONV
          && iconv_fd == (iconv_t)-1
# endif
          ) {
        /* Conversion wanted but we can't.
         * Try the next conversion in 'fileencodings' */
        advance_fenc = true;
        goto retry;
      }
    }
  }

  /* Set "can_retry" when it's possible to rewind the file and try with
   * another "fenc" value.  It's FALSE when no other "fenc" to try, reading
   * stdin or fixed at a specific encoding. */
  can_retry = (*fenc != NUL && !read_stdin && !keep_dest_enc && !read_fifo);

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
                      && !read_fifo
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
     * up to max_unsigned characters (and other things).
     */
    {
      if (!skip_read) {
        size = 0x10000L;                            /* use buffer >= 64K */

        for (; size >= 10; size /= 2) {
          new_buffer = verbose_try_malloc((size_t)size + (size_t)linerest + 1);
          if (new_buffer) {
            break;
          }
        }
        if (new_buffer == NULL) {
          error = TRUE;
          break;
        }
        if (linerest)           /* copy characters from the previous buffer */
          memmove(new_buffer, ptr - linerest, (size_t)linerest);
        xfree(buffer);
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
# ifdef HAVE_ICONV
        if (iconv_fd != (iconv_t)-1) {
          size = size / ICONV_MULT;
        } else {
# endif
        if (fio_flags & FIO_LATIN1) {
          size = size / 2;
        } else if (fio_flags & (FIO_UCS2 | FIO_UTF16)) {
          size = (size * 2 / 3) & ~1;
        } else if (fio_flags & FIO_UCS4) {
          size = (size * 2 / 3) & ~3;
        } else if (fio_flags == FIO_UCSBOM) {
          size = size / ICONV_MULT;  // worst case
        }
# ifdef HAVE_ICONV
        }
# endif
        if (conv_restlen > 0) {
          // Insert unconverted bytes from previous line.
          memmove(ptr, conv_rest, conv_restlen);  // -V614
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
              } else {
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
        } else {
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
# ifdef HAVE_ICONV
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
            } else {
              /* Replace the trailing bytes with the replacement
               * character if we were converting; if we weren't,
               * leave the UTF8 checking code to do it, as it
               * works slightly differently. */
              if (bad_char_behavior != BAD_KEEP && (fio_flags != 0
# ifdef HAVE_ICONV
                                                    || iconv_fd != (iconv_t)-1
# endif
                                                    )) {
                while (conv_restlen > 0) {
                  *(--ptr) = bad_char_behavior;
                  --conv_restlen;
                }
              }
              fio_flags = 0;  // don't convert this
# ifdef HAVE_ICONV
              if (iconv_fd != (iconv_t)-1) {
                iconv_close(iconv_fd);
                iconv_fd = (iconv_t)-1;
              }
# endif
            }
          }
        }
      }

      skip_read = FALSE;

      /*
       * At start of file: Check for BOM.
       * Also check for a BOM for other Unicode encodings, but not after
       * converting with 'charconvert' or when a BOM has already been
       * found.
       */
      if ((filesize == 0)
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
          memmove(ptr, ptr + blen, (size_t)size);
          if (set_options) {
            curbuf->b_p_bomb = TRUE;
            curbuf->b_start_bomb = TRUE;
          }
        }

        if (fio_flags == FIO_UCSBOM) {
          if (ccname == NULL) {
            // No BOM detected: retry with next encoding.
            advance_fenc = true;
          } else {
            /* BOM detected: set "fenc" and jump back */
            if (fenc_alloced)
              xfree(fenc);
            fenc = ccname;
            fenc_alloced = false;
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

# ifdef HAVE_ICONV
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
          } else if (bad_char_behavior != BAD_DROP) {
            *top++ = bad_char_behavior;
            --to_size;
          }
        }

        if (from_size > 0) {
          /* Some remaining characters, keep them for the next
           * round. */
          memmove(conv_rest, (char_u *)fromp, from_size);
          conv_restlen = (int)from_size;
        }

        /* move the linerest to before the converted characters */
        line_start = ptr - linerest;
        memmove(line_start, buffer, (size_t)linerest);
        size = (long)((char_u *)top - ptr);
      }
# endif

      if (fio_flags != 0) {
        unsigned int u8c;
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
        } else if (fio_flags & (FIO_UCS2 | FIO_UTF16)) {
          /* Check for a trailing byte */
          p = ptr + (size & ~1);
          if (size & 1)
            tail = p;
          if ((fio_flags & FIO_UTF16) && p > ptr) {
            /* Check for a trailing leading word */
            if (fio_flags & FIO_ENDIAN_L) {
              u8c = (*--p << 8);
              u8c += *--p;
            } else {
              u8c = *--p;
              u8c += (*--p << 8);
            }
            if (u8c >= 0xd800 && u8c <= 0xdbff)
              tail = p;
            else
              p += 2;
          }
        } else {   /*  FIO_UCS4 */
                     /* Check for trailing 1, 2 or 3 bytes */
          p = ptr + (size & ~3);
          if (size & 3)
            tail = p;
        }

        /* If there is a trailing incomplete sequence move it to
         * conv_rest[]. */
        if (tail != NULL) {
          conv_restlen = (int)((ptr + size) - tail);
          memmove(conv_rest, tail, conv_restlen);
          size -= conv_restlen;
        }


        while (p > ptr) {
          if (fio_flags & FIO_LATIN1)
            u8c = *--p;
          else if (fio_flags & (FIO_UCS2 | FIO_UTF16)) {
            if (fio_flags & FIO_ENDIAN_L) {
              u8c = (*--p << 8);
              u8c += *--p;
            } else {
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
              } else {
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
          } else if (fio_flags & FIO_UCS4) {
            if (fio_flags & FIO_ENDIAN_L) {
              u8c = (unsigned)(*--p) << 24;
              u8c += (unsigned)(*--p) << 16;
              u8c += (unsigned)(*--p) << 8;
              u8c += *--p;
            } else {          /* big endian */
              u8c = *--p;
              u8c += (unsigned)(*--p) << 8;
              u8c += (unsigned)(*--p) << 16;
              u8c += (unsigned)(*--p) << 24;
            }
          } else {        /* UTF-8 */
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
          assert(u8c <= INT_MAX);
          // produce UTF-8
          dest -= utf_char2len((int)u8c);
          (void)utf_char2bytes((int)u8c, dest);
        }

        // move the linerest to before the converted characters
        line_start = dest - linerest;
        memmove(line_start, buffer, (size_t)linerest);
        size = (long)((ptr + real_size) - dest);
        ptr = dest;
      } else if (enc_utf8 && !curbuf->b_p_bin) {
        int incomplete_tail = FALSE;

        // Reading UTF-8: Check if the bytes are valid UTF-8.
        for (p = ptr;; p++) {
          int todo = (int)((ptr + size) - p);
          int l;

          if (todo <= 0) {
            break;
          }
          if (*p >= 0x80) {
            // A length of 1 means it's an illegal byte.  Accept
            // an incomplete character at the end though, the next
            // read() will get the next bytes, we'll check it
            // then.
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
                memmove(conv_rest, p, conv_restlen);
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
# ifdef HAVE_ICONV
              // When we did a conversion report an error.
              if (iconv_fd != (iconv_t)-1 && conv_error == 0) {
                conv_error = readfile_linenr(linecnt, ptr, p);
              }
# endif
              /* Remember the first linenr with an illegal byte */
              if (conv_error == 0 && illegal_byte == 0)
                illegal_byte = readfile_linenr(linecnt, ptr, p);

              /* Drop, keep or replace the bad byte. */
              if (bad_char_behavior == BAD_DROP) {
                memmove(p, p + 1, todo - 1);
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
          // Retry reading with another conversion.
# ifdef HAVE_ICONV
          if (*p_ccv != NUL && iconv_fd != (iconv_t)-1) {
            // iconv() failed, try 'charconvert'
            did_iconv = true;
          } else {
# endif
          // use next item from 'fileencodings'
          advance_fenc = true;
# ifdef HAVE_ICONV
          }
# endif
          file_rewind = true;
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
          // Reset the carriage return counter.
          if (try_mac) {
            try_mac = 1;
          }

          for (p = ptr; p < ptr + size; ++p) {
            if (*p == NL) {
              if (!try_unix
                  || (try_dos && p > ptr && p[-1] == CAR))
                fileformat = EOL_DOS;
              else
                fileformat = EOL_UNIX;
              break;
            } else if (*p == CAR && try_mac) {
              try_mac++;
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
          } else if (fileformat == EOL_UNKNOWN && try_mac == 1) {
            // Looking for CR but found no end-of-line markers at all:
            // use the default format.
            fileformat = default_fileformat();
          }
        }

        /* No NL found: may use Mac format */
        if (fileformat == EOL_UNKNOWN && try_mac)
          fileformat = EOL_MAC;

        /* Still nothing found?  Use first format in 'ffs' */
        if (fileformat == EOL_UNKNOWN)
          fileformat = default_fileformat();

        // May set 'p_ff' if editing a new file.
        if (set_options) {
          set_fileformat(fileformat, OPT_LOCAL);
        }
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
    } else {
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
              if (ptr > line_start && ptr[-1] == CAR) {
                // remove CR before NL
                ptr[-1] = NUL;
                len--;
              } else if (ff_error != EOL_DOS) {
                // Reading in Dos format, but no CR-LF found!
                // When 'fileformats' includes "unix", delete all
                // the lines read so far and start all over again.
                // Otherwise give an error message later.
                if (try_unix
                    && !read_stdin
                    && (read_buffer
                        || vim_lseek(fd, (off_T)0L, SEEK_SET) == 0)) {
                  fileformat = EOL_UNIX;
                  if (set_options)
                    set_fileformat(EOL_UNIX, OPT_LOCAL);
                  file_rewind = true;
                  keep_fileformat = true;
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
    os_breakcheck();
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

  if (set_options) {
    // Remember the current file format.
    save_file_ff(curbuf);
    // If editing a new file: set 'fenc' for the current buffer.
    // Also for ":read ++edit file".
    set_string_option_direct((char_u *)"fenc", -1, fenc,
        OPT_FREE | OPT_LOCAL, 0);
  }
  if (fenc_alloced)
    xfree(fenc);
# ifdef HAVE_ICONV
  if (iconv_fd != (iconv_t)-1) {
    iconv_close(iconv_fd);
#  ifndef __clang_analyzer__
    iconv_fd = (iconv_t)-1;
#  endif
  }
# endif

  if (!read_buffer && !read_stdin) {
    close(fd);  // errors are ignored
  } else {
    (void)os_set_cloexec(fd);
  }
  xfree(buffer);

  if (read_stdin) {
    close(0);
#ifndef WIN32
    // On Unix, use stderr for stdin, makes shell commands work.
    vim_ignored = dup(2);
#else
    // On Windows, use the console input handle for stdin.
    HANDLE conin = CreateFile("CONIN$", GENERIC_READ | GENERIC_WRITE,
                              FILE_SHARE_READ, (LPSECURITY_ATTRIBUTES)NULL,
                              OPEN_EXISTING, 0, (HANDLE)NULL);
    vim_ignored = _open_osfhandle(conin, _O_RDONLY);
#endif
  }

  if (tmpname != NULL) {
    os_remove((char *)tmpname);  // delete converted file
    xfree(tmpname);
  }
  --no_wait_return;                     /* may wait for return now */

  /*
   * In recovery mode everything but autocommands is skipped.
   */
  if (!recoverymode) {
    /* need to delete the last line, which comes from the empty buffer */
    if (newfile && wasempty && !(curbuf->b_ml.ml_flags & ML_EMPTY)) {
      ml_delete(curbuf->b_ml.ml_line_count, false);
      linecnt--;
    }
    curbuf->deleted_bytes = 0;
    curbuf->deleted_codepoints = 0;
    curbuf->deleted_codeunits = 0;
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
      add_quoted_fname((char *)IObuff, IOSIZE, curbuf, (const char *)sfname);
      c = false;

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
      if (notconverted) {
        STRCAT(IObuff, _("[NOT converted]"));
        c = TRUE;
      } else if (converted) {
        STRCAT(IObuff, _("[converted]"));
        c = TRUE;
      }
      if (conv_error != 0) {
        sprintf((char *)IObuff + STRLEN(IObuff),
            _("[CONVERSION ERROR in line %" PRId64 "]"), (int64_t)conv_error);
        c = TRUE;
      } else if (illegal_byte > 0) {
        sprintf((char *)IObuff + STRLEN(IObuff),
            _("[ILLEGAL BYTE in line %" PRId64 "]"), (int64_t)illegal_byte);
        c = TRUE;
      } else if (error)  {
        STRCAT(IObuff, _("[READ ERRORS]"));
        c = TRUE;
      }
      if (msg_add_fileformat(fileformat))
        c = TRUE;

      msg_add_lines(c, (long)linecnt, filesize);

      XFREE_CLEAR(keep_msg);
      p = NULL;
      msg_scrolled_ign = TRUE;

      if (!read_stdin && !read_buffer) {
        p = msg_trunc_attr(IObuff, FALSE, 0);
      }

      if (read_stdin || read_buffer || restart_edit != 0
          || (msg_scrolled != 0 && !need_wait_return)) {
        // Need to repeat the message after redrawing when:
        // - When reading from stdin (the screen will be cleared next).
        // - When restart_edit is set (otherwise there will be a delay before
        //   redrawing).
        // - When the screen was scrolled but there is no wait-return prompt.
        set_keep_msg(p, 0);
      }
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
   * We remember if the last line of the read didn't have
   * an eol even when 'binary' is off, to support turning 'fixeol' off,
   * or writing the read again with 'binary' on.  The latter is required
   * for ":autocmd FileReadPost *.gz set bin|'[,']!gunzip" to work.
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

  if (!read_stdin && !read_fifo && (!read_buffer || sfname != NULL)) {
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
    msg_scroll = true;
    if (filtering) {
      apply_autocmds_exarg(EVENT_FILTERREADPOST, NULL, sfname,
                           false, curbuf, eap);
    } else if (newfile || (read_buffer && sfname != NULL)) {
      apply_autocmds_exarg(EVENT_BUFREADPOST, NULL, sfname,
                           false, curbuf, eap);
      if (!au_did_filetype && *curbuf->b_p_ft != NUL) {
        // EVENT_FILETYPE was not triggered but the buffer already has a
        // filetype.  Trigger EVENT_FILETYPE using the existing filetype.
        apply_autocmds(EVENT_FILETYPE, curbuf->b_p_ft, curbuf->b_fname,
                       true, curbuf);
      }
    } else {
      apply_autocmds_exarg(EVENT_FILEREADPOST, sfname, sfname,
                           false, NULL, eap);
    }
    if (msg_scrolled == n) {
      msg_scroll = m;
    }
    if (aborting()) {       // autocmds may abort script processing
      return FAIL;
    }
  }

  if (recoverymode && error)
    return FAIL;
  return OK;
}

#ifdef OPEN_CHR_FILES
/// Returns true if the file name argument is of the form "/dev/fd/\d\+",
/// which is the name of files used for process substitution output by
/// some shells on some operating systems, e.g., bash on SunOS.
/// Do not accept "/dev/fd/[012]", opening these may hang Vim.
///
/// @param fname file name to check
bool is_dev_fd_file(char_u *fname)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  return STRNCMP(fname, "/dev/fd/", 8) == 0
         && ascii_isdigit(fname[8])
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
readfile_linenr(
    linenr_T linecnt,         // line count before reading more bytes
    char_u *p,                // start of more bytes read
    char_u *endp              // end of more bytes read
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
 */
void prep_exarg(exarg_T *eap, buf_T *buf)
{
  eap->cmd = xmalloc(STRLEN(buf->b_p_ff) + STRLEN(buf->b_p_fenc) + 15);

  sprintf((char *)eap->cmd, "e ++ff=%s ++enc=%s", buf->b_p_ff, buf->b_p_fenc);
  eap->force_enc = 14 + (int)STRLEN(buf->b_p_ff);
  eap->bad_char = buf->b_bad_char;
  eap->force_ff = 7;

  eap->force_bin = buf->b_p_bin ? FORCE_BIN : FORCE_NOBIN;
  eap->read_edit = FALSE;
  eap->forceit = FALSE;
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
    set_string_option_direct((char_u *)"fenc", -1, fenc, OPT_FREE|OPT_LOCAL, 0);
    xfree(fenc);
  }
}

// Find next fileencoding to use from 'fileencodings'.
// "pp" points to fenc_next.  It's advanced to the next item.
// When there are no more items, an empty string is returned and *pp is set to
// NULL.
// When *pp is not set to NULL, the result is in allocated memory and "alloced"
// is set to true.
static char_u *next_fenc(char_u **pp, bool *alloced)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  char_u      *p;
  char_u      *r;

  *alloced = false;
  if (**pp == NUL) {
    *pp = NULL;
    return (char_u *)"";
  }
  p = vim_strchr(*pp, ',');
  if (p == NULL) {
    r = enc_canonize(*pp);
    *pp += STRLEN(*pp);
  } else {
    r = vim_strnsave(*pp, (int)(p - *pp));
    *pp = p + 1;
    p = enc_canonize(r);
    xfree(r);
    r = p;
  }
  *alloced = true;
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

  tmpname = vim_tempname();
  if (tmpname == NULL)
    errmsg = (char_u *)_("Can't find temp file for conversion");
  else {
    close(*fdp);                /* close the input file, ignore errors */
    *fdp = -1;
    if (eval_charconvert((char *) fenc, enc_utf8 ? "utf-8" : (char *) p_enc,
                         (char *) fname, (char *) tmpname) == FAIL) {
      errmsg = (char_u *)_("Conversion with 'charconvert' failed");
    }
    if (errmsg == NULL && (*fdp = os_open((char *)tmpname, O_RDONLY, 0)) < 0) {
      errmsg = (char_u *)_("can't read output of 'charconvert'");
    }
  }

  if (errmsg != NULL) {
    /* Don't use emsg(), it breaks mappings, the retry with
     * another type of conversion might still work. */
    MSG(errmsg);
    if (tmpname != NULL) {
      os_remove((char *)tmpname);  // delete converted file
      XFREE_CLEAR(tmpname);
    }
  }

  /* If the input file is closed, open it (caller should check for error). */
  if (*fdp < 0) {
    *fdp = os_open((char *)fname, O_RDONLY, 0);
  }

  return tmpname;
}


/*
 * Read marks for the current buffer from the ShaDa file, when we support
 * buffer marks and the buffer has a name.
 */
static void check_marks_read(void)
{
  if (!curbuf->b_marks_read && get_shada_parameter('\'') > 0
      && curbuf->b_ffname != NULL) {
    shada_read_marks();
  }

  /* Always set b_marks_read; needed when 'shada' is changed to include
   * the ' parameter after opening a buffer. */
  curbuf->b_marks_read = true;
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
buf_write(
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
#define SET_ERRMSG_NUM(num, msg) \
  errnum = num, errmsg = msg, errmsgarg = 0
#define SET_ERRMSG_ARG(msg, error) \
  errnum = NULL, errmsg = msg, errmsgarg = error
#define SET_ERRMSG(msg) \
  errnum = NULL, errmsg = msg, errmsgarg = 0
  const char *errnum = NULL;
  char *errmsg = NULL;
  int errmsgarg = 0;
  bool errmsg_allocated = false;
  char_u          *buffer;
  char_u smallbuf[SMBUFSIZE];
  char_u          *backup_ext;
  int bufsize;
  long perm;                                // file permissions
  int retval = OK;
  int newfile = false;                      // TRUE if file doesn't exist yet
  int msg_save = msg_scroll;
  int overwriting;                          // TRUE if writing over original
  int no_eol = false;                       // no end-of-line written
  int device = false;                       // writing to a device
  int prev_got_int = got_int;
  int checking_conversion;
  bool file_readonly = false;               // overwritten file is read-only
  static char     *err_readonly =
    "is read-only (cannot override: \"W\" in 'cpoptions')";
#if defined(UNIX)
  int made_writable = FALSE;                /* 'w' bit has been set */
#endif
  /* writing everything */
  int whole = (start == 1 && end == buf->b_ml.ml_line_count);
  linenr_T old_line_count = buf->b_ml.ml_line_count;
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
  unsigned int bkc = get_bkc_value(buf);

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
# ifdef HAVE_ICONV
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

  // For Unix: Use the short file name whenever possible.
  // Avoids problems with networks and when directory names are changed.
  // Don't do this for Windows, a "cd" in a sub-shell may have moved us to
  // another directory, which we don't detect.
  ffname = fname;                           // remember full fname
#ifdef UNIX
  fname = sfname;
#endif

  if (buf->b_ffname != NULL && fnamecmp(ffname, buf->b_ffname) == 0)
    overwriting = TRUE;
  else
    overwriting = FALSE;

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
    bufref_T bufref;

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

    // Set curwin/curbuf to buf and save a few things.
    aucmd_prepbuf(&aco, buf);
    set_bufref(&bufref, buf);

    if (append) {
      if (!(did_cmd = apply_autocmds_exarg(EVENT_FILEAPPENDCMD,
                sfname, sfname, FALSE, curbuf, eap))) {
        if (overwriting && bt_nofile(curbuf))
          nofile_err = TRUE;
        else
          apply_autocmds_exarg(EVENT_FILEAPPENDPRE,
              sfname, sfname, FALSE, curbuf, eap);
      }
    } else if (filtering) {
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
      } else {
        if (overwriting && bt_nofile(curbuf))
          nofile_err = TRUE;
        else
          apply_autocmds_exarg(EVENT_BUFWRITEPRE,
              sfname, sfname, FALSE, curbuf, eap);
      }
    } else {
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

    // In three situations we return here and don't write the file:
    // 1. the autocommands deleted or unloaded the buffer.
    // 2. The autocommands abort script processing.
    // 3. If one of the "Cmd" autocommands was executed.
    if (!bufref_valid(&bufref)) {
      buf = NULL;
    }
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

  buffer = verbose_try_malloc(BUFSIZE);
  // can't allocate big buffer, use small one (to be able to write when out of
  // memory)
  if (buffer == NULL) {
    buffer = smallbuf;
    bufsize = SMBUFSIZE;
  } else
    bufsize = BUFSIZE;

  /*
   * Get information about original file (if there is one).
   */
  FileInfo file_info_old;
#if defined(UNIX)
  perm = -1;
  if (!os_fileinfo((char *)fname, &file_info_old)) {
    newfile = TRUE;
  } else {
    perm = file_info_old.stat.st_mode;
    if (!S_ISREG(file_info_old.stat.st_mode)) {             /* not a file */
      if (S_ISDIR(file_info_old.stat.st_mode)) {
        SET_ERRMSG_NUM("E502", _("is a directory"));
        goto fail;
      }
      if (os_nodetype((char *)fname) != NODE_WRITABLE) {
        SET_ERRMSG_NUM("E503", _("is not a file or writable device"));
        goto fail;
      }
      /* It's a device of some kind (or a fifo) which we can write to
       * but for which we can't make a backup. */
      device = TRUE;
      newfile = TRUE;
      perm = -1;
    }
  }
#else  // win32
  // Check for a writable device name.
  c = fname == NULL ? NODE_OTHER : os_nodetype((char *)fname);
  if (c == NODE_OTHER) {
    SET_ERRMSG_NUM("E503", _("is not a file or writable device"));
    goto fail;
  }
  if (c == NODE_WRITABLE) {
    device = TRUE;
    newfile = TRUE;
    perm = -1;
  } else {
    perm = os_getperm((const char *)fname);
    if (perm < 0) {
      newfile = true;
    } else if (os_isdir(fname)) {
      SET_ERRMSG_NUM("E502", _("is a directory"));
      goto fail;
    }
    if (overwriting) {
      os_fileinfo((char *)fname, &file_info_old);
    }
  }
#endif  // !UNIX

  if (!device && !newfile) {
    /*
     * Check if the file is really writable (when renaming the file to
     * make a backup we won't discover it later).
     */
    file_readonly = !os_file_is_writable((char *)fname);

    if (!forceit && file_readonly) {
      if (vim_strchr(p_cpo, CPO_FWRITE) != NULL) {
        SET_ERRMSG_NUM("E504", _(err_readonly));
      } else {
        SET_ERRMSG_NUM("E505", _("is read-only (add ! to override)"));
      }
      goto fail;
    }

    /*
     * Check if the timestamp hasn't changed since reading the file.
     */
    if (overwriting) {
      retval = check_mtime(buf, &file_info_old);
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
  buf->b_saving = true;

  /*
   * If we are not appending or filtering, the file exists, and the
   * 'writebackup', 'backup' or 'patchmode' option is set, need a backup.
   * When 'patchmode' is set also make a backup when appending.
   *
   * Do not make any backup, if 'writebackup' and 'backup' are both switched
   * off.  This helps when editing large files on almost-full disks.
   */
  if (!(append && *p_pm == NUL) && !filtering && perm >= 0 && dobackup) {
    FileInfo file_info;

    if ((bkc & BKC_YES) || append) {       /* "yes" */
      backup_copy = TRUE;
    } else if ((bkc & BKC_AUTO)) {          /* "auto" */
      int i;

      /*
       * Don't rename the file when:
       * - it's a hard link
       * - it's a symbolic link
       * - we don't have write permission in the directory
       */
      if (os_fileinfo_hardlinks(&file_info_old) > 1
          || !os_fileinfo_link((char *)fname, &file_info)
          || !os_fileinfo_id_equal(&file_info, &file_info_old)) {
        backup_copy = TRUE;
      } else {
        /*
         * Check if we can create a file and set the owner/group to
         * the ones from the original file.
         * First find a file name that doesn't exist yet (use some
         * arbitrary numbers).
         */
        STRCPY(IObuff, fname);
        for (i = 4913;; i += 123) {
          sprintf((char *)path_tail(IObuff), "%d", i);
          if (!os_fileinfo_link((char *)IObuff, &file_info)) {
            break;
          }
        }
        fd = os_open((char *)IObuff,
            O_CREAT|O_WRONLY|O_EXCL|O_NOFOLLOW, perm);
        if (fd < 0)             /* can't write in directory */
          backup_copy = TRUE;
        else {
# ifdef UNIX
          os_fchown(fd, file_info_old.stat.st_uid, file_info_old.stat.st_gid);
          if (!os_fileinfo((char *)IObuff, &file_info)
              || file_info.stat.st_uid != file_info_old.stat.st_uid
              || file_info.stat.st_gid != file_info_old.stat.st_gid
              || (long)file_info.stat.st_mode != perm) {
            backup_copy = TRUE;
          }
# endif
          /* Close the file before removing it, on MS-Windows we
           * can't delete an open file. */
          close(fd);
          os_remove((char *)IObuff);
        }
      }
    }

    /*
     * Break symlinks and/or hardlinks if we've been asked to.
     */
    if ((bkc & BKC_BREAKSYMLINK) || (bkc & BKC_BREAKHARDLINK)) {
# ifdef UNIX
      bool file_info_link_ok = os_fileinfo_link((char *)fname, &file_info);

      /* Symlinks. */
      if ((bkc & BKC_BREAKSYMLINK)
          && file_info_link_ok
          && !os_fileinfo_id_equal(&file_info, &file_info_old)) {
        backup_copy = FALSE;
      }

      /* Hardlinks. */
      if ((bkc & BKC_BREAKHARDLINK)
          && os_fileinfo_hardlinks(&file_info_old) > 1
          && (!file_info_link_ok
              || os_fileinfo_id_equal(&file_info, &file_info_old))) {
        backup_copy = FALSE;
      }
# endif
    }

    /* make sure we have a valid backup extension to use */
    if (*p_bex == NUL)
      backup_ext = (char_u *)".bak";
    else
      backup_ext = p_bex;

    if (backup_copy) {
      char_u *wp;
      int some_error = false;
      char_u      *dirp;
      char_u      *rootname;

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
        /*
         * Isolate one directory name, using an entry in 'bdir'.
         */
        (void)copy_option_part(&dirp, IObuff, IOSIZE, ",");
        rootname = get_file_in_dir(fname, IObuff);
        if (rootname == NULL) {
          some_error = TRUE;                /* out of memory */
          goto nobackup;
        }

        FileInfo file_info_new;
        {
          /*
           * Make backup file name.
           */
          backup = (char_u *)modname((char *)rootname, (char *)backup_ext, FALSE);
          if (backup == NULL) {
            xfree(rootname);
            some_error = TRUE;                          /* out of memory */
            goto nobackup;
          }

          /*
           * Check if backup file already exists.
           */
          if (os_fileinfo((char *)backup, &file_info_new)) {
            if (os_fileinfo_id_equal(&file_info_new, &file_info_old)) {
              //
              // Backup file is same as original file.
              // May happen when modname() gave the same file back (e.g. silly
              // link). If we don't check here, we either ruin the file when
              // copying or erase it after writing.
              //
              XFREE_CLEAR(backup);              // no backup file to delete
            } else if (!p_bk) {
              // We are not going to keep the backup file, so don't
              // delete an existing one, and try to use another name instead.
              // Change one character, just before the extension.
              //
              wp = backup + STRLEN(backup) - 1 - STRLEN(backup_ext);
              if (wp < backup) {                // empty file name ???
                wp = backup;
              }
              *wp = 'z';
              while (*wp > 'a'
                     && os_fileinfo((char *)backup, &file_info_new)) {
                --*wp;
              }
              // They all exist??? Must be something wrong.
              if (*wp == 'a') {
                XFREE_CLEAR(backup);
              }
            }
          }
        }
        xfree(rootname);

        /*
         * Try to create the backup file
         */
        if (backup != NULL) {
          /* remove old backup, if present */
          os_remove((char *)backup);

          // set file protection same as original file, but
          // strip s-bit.
          (void)os_setperm((const char *)backup, perm & 0777);

#ifdef UNIX
          //
          // Try to set the group of the backup same as the original file. If
          // this fails, set the protection bits for the group same as the
          // protection bits for others.
          //
          if (file_info_new.stat.st_gid != file_info_old.stat.st_gid
              && os_chown((char *)backup, -1, file_info_old.stat.st_gid) != 0) {
            os_setperm((const char *)backup,
                       (perm & 0707) | ((perm & 07) << 3));
          }
#endif

          // copy the file
          if (os_copy((char *)fname, (char *)backup, UV_FS_COPYFILE_FICLONE)
              != 0) {
            SET_ERRMSG(_("E506: Can't write to backup file "
                         "(add ! to override)"));
          }

#ifdef UNIX
          os_file_settime((char *)backup,
                          file_info_old.stat.st_atim.tv_sec,
                          file_info_old.stat.st_mtim.tv_sec);
#endif
#ifdef HAVE_ACL
          mch_set_acl(backup, acl);
#endif
          break;
        }
      }

nobackup:
      if (backup == NULL && errmsg == NULL) {
        SET_ERRMSG(_(
            "E509: Cannot create backup file (add ! to override)"));
      }
      // Ignore errors when forceit is TRUE.
      if ((some_error || errmsg != NULL) && !forceit) {
        retval = FAIL;
        goto fail;
      }
      SET_ERRMSG(NULL);
    } else {
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
        SET_ERRMSG_NUM("E504", _(err_readonly));
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
          backup = (char_u *)modname((char *)rootname, (char *)backup_ext, FALSE);
          xfree(rootname);
        }

        if (backup != NULL) {
          /*
           * If we are not going to keep the backup file, don't
           * delete an existing one, try to use another name.
           * Change one character, just before the extension.
           */
          if (!p_bk && os_path_exists(backup)) {
            p = backup + STRLEN(backup) - 1 - STRLEN(backup_ext);
            if (p < backup)             /* empty file name ??? */
              p = backup;
            *p = 'z';
            while (*p > 'a' && os_path_exists(backup)) {
              (*p)--;
            }
            // They all exist??? Must be something wrong!
            if (*p == 'a') {
              XFREE_CLEAR(backup);
            }
          }
        }
        if (backup != NULL) {
          // Delete any existing backup and move the current version
          // to the backup. For safety, we don't remove the backup
          // until the write has finished successfully. And if the
          // 'backup' option is set, leave it around.

          // If the renaming of the original file to the backup file
          // works, quit here.
          ///
          if (vim_rename(fname, backup) == 0) {
            break;
          }

          XFREE_CLEAR(backup);             // don't do the rename below
        }
      }
      if (backup == NULL && !forceit) {
        SET_ERRMSG(_("E510: Can't make backup file (add ! to override)"));
        goto fail;
      }
    }
  }

#if defined(UNIX)
  // When using ":w!" and the file was read-only: make it writable
  if (forceit && perm >= 0 && !(perm & 0200)
      && file_info_old.stat.st_uid == getuid()
      && vim_strchr(p_cpo, CPO_FWRITE) == NULL) {
    perm |= 0200;
    (void)os_setperm((const char *)fname, perm);
    made_writable = true;
  }
#endif

  // When using ":w!" and writing to the current file, 'readonly' makes no
  // sense, reset it, unless 'Z' appears in 'cpoptions'.
  if (forceit && overwriting && vim_strchr(p_cpo, CPO_KEEPRO) == NULL) {
    buf->b_p_ro = false;
    need_maketitle = true;          // set window title later
    status_redraw_all();            // redraw status lines later
  }

  if (end > buf->b_ml.ml_line_count)
    end = buf->b_ml.ml_line_count;
  if (buf->b_ml.ml_flags & ML_EMPTY)
    start = end + 1;

  // If the original file is being overwritten, there is a small chance that
  // we crash in the middle of writing. Therefore the file is preserved now.
  // This makes all block numbers positive so that recovery does not need
  // the original file.
  // Don't do this if there is a backup file and we are exiting.
  if (reset_changed && !newfile && overwriting
      && !(exiting && backup != NULL)) {
    ml_preserve(buf, false, !!p_fs);
    if (got_int) {
      SET_ERRMSG(_(e_interr));
      goto restore_backup;
    }
  }


  // Default: write the file directly.  May write to a temp file for
  // multi-byte conversion.
  wfname = fname;

  // Check for forced 'fileencoding' from "++opt=val" argument.
  if (eap != NULL && eap->force_enc != 0) {
    fenc = eap->cmd + eap->force_enc;
    fenc = enc_canonize(fenc);
    fenc_tofree = fenc;
  } else {
    fenc = buf->b_p_fenc;
  }

  // Check if the file needs to be converted.
  converted = need_conversion(fenc);

  // Check if UTF-8 to UCS-2/4 or Latin1 conversion needs to be done.  Or
  // Latin1 to Unicode conversion.  This is handled in buf_write_bytes().
  // Prepare the flags for it and allocate bw_conv_buf when needed.
  if (converted && (enc_utf8 || STRCMP(p_enc, "latin1") == 0)) {
    wb_flags = get_fio_flags(fenc);
    if (wb_flags & (FIO_UCS2 | FIO_UCS4 | FIO_UTF16 | FIO_UTF8)) {
      // Need to allocate a buffer to translate into.
      if (wb_flags & (FIO_UCS2 | FIO_UTF16 | FIO_UTF8)) {
        write_info.bw_conv_buflen = bufsize * 2;
      } else {       // FIO_UCS4
        write_info.bw_conv_buflen = bufsize * 4;
      }
      write_info.bw_conv_buf = verbose_try_malloc(write_info.bw_conv_buflen);
      if (!write_info.bw_conv_buf) {
        end = 0;
      }
    }
  }



  if (converted && wb_flags == 0) {
#  ifdef HAVE_ICONV
    // Use iconv() conversion when conversion is needed and it's not done
    // internally.
    write_info.bw_iconv_fd = (iconv_t)my_iconv_open(fenc,
        enc_utf8 ? (char_u *)"utf-8" : p_enc);
    if (write_info.bw_iconv_fd != (iconv_t)-1) {
      /* We're going to use iconv(), allocate a buffer to convert in. */
      write_info.bw_conv_buflen = bufsize * ICONV_MULT;
      write_info.bw_conv_buf = verbose_try_malloc(write_info.bw_conv_buflen);
      if (!write_info.bw_conv_buf) {
        end = 0;
      }
      write_info.bw_first = TRUE;
    } else
#  endif

    /*
     * When the file needs to be converted with 'charconvert' after
     * writing, write to a temp file instead and let the conversion
     * overwrite the original file.
     */
    if (*p_ccv != NUL) {
      wfname = vim_tempname();
      if (wfname == NULL) {  // Can't write without a tempfile!
        SET_ERRMSG(_("E214: Can't find temp file for writing"));
        goto restore_backup;
      }
    }
  }
  if (converted && wb_flags == 0
#  ifdef HAVE_ICONV
      && write_info.bw_iconv_fd == (iconv_t)-1
#  endif
      && wfname == fname
      ) {
    if (!forceit) {
      SET_ERRMSG(_(
          "E213: Cannot convert (add ! to write without conversion)"));
      goto restore_backup;
    }
    notconverted = TRUE;
  }

  // If conversion is taking place, we may first pretend to write and check
  // for conversion errors.  Then loop again to write for real.
  // When not doing conversion this writes for real right away.
  for (checking_conversion = true; ; checking_conversion = false) {
    // There is no need to check conversion when:
    // - there is no conversion
    // - we make a backup file, that can be restored in case of conversion
    // failure.
    if (!converted || dobackup) {
      checking_conversion = false;
    }

    if (checking_conversion) {
      // Make sure we don't write anything.
      fd = -1;
      write_info.bw_fd = fd;
    } else {
      // Open the file "wfname" for writing.
      // We may try to open the file twice: If we can't write to the file
      // and forceit is TRUE we delete the existing file and try to
      // create a new one. If this still fails we may have lost the
      // original file!  (this may happen when the user reached his
      // quotum for number of files).
      // Appending will fail if the file does not exist and forceit is
      // FALSE.
      while ((fd = os_open((char *)wfname,
                           O_WRONLY |
                           (append ?
                            (forceit ? (O_APPEND | O_CREAT) : O_APPEND)
                            : (O_CREAT | O_TRUNC))
                           , perm < 0 ? 0666 : (perm & 0777))) < 0) {
        // A forced write will try to create a new file if the old one
        // is still readonly. This may also happen when the directory
        // is read-only. In that case the mch_remove() will fail.
        if (errmsg == NULL) {
#ifdef UNIX
          FileInfo file_info;

          // Don't delete the file when it's a hard or symbolic link.
          if ((!newfile && os_fileinfo_hardlinks(&file_info_old) > 1)
              || (os_fileinfo_link((char *)fname, &file_info)
                  && !os_fileinfo_id_equal(&file_info, &file_info_old))) {
            SET_ERRMSG(_("E166: Can't open linked file for writing"));
          } else {
#endif
            SET_ERRMSG_ARG(_("E212: Can't open file for writing: %s"), fd);
            if (forceit && vim_strchr(p_cpo, CPO_FWRITE) == NULL
                && perm >= 0) {
#ifdef UNIX
              // we write to the file, thus it should be marked
              // writable after all
              if (!(perm & 0200)) {
                made_writable = true;
              }
              perm |= 0200;
              if (file_info_old.stat.st_uid != getuid()
                  || file_info_old.stat.st_gid != getgid()) {
                perm &= 0777;
              }
#endif
              if (!append) {                    // don't remove when appending
                os_remove((char *)wfname);
              }
              continue;
            }
#ifdef UNIX
          }
#endif
        }

restore_backup:
        {
          // If we failed to open the file, we don't need a backup. Throw it
          // away.  If we moved or removed the original file try to put the
          // backup in its place.
          if (backup != NULL && wfname == fname) {
            if (backup_copy) {
              // There is a small chance that we removed the original,
              // try to move the copy in its place.
              // This may not work if the vim_rename() fails.
              // In that case we leave the copy around.
              // If file does not exist, put the copy in its place
              if (!os_path_exists(fname)) {
                vim_rename(backup, fname);
              }
              // if original file does exist throw away the copy
              if (os_path_exists(fname)) {
                os_remove((char *)backup);
              }
            } else {
              // try to put the original file back
              vim_rename(backup, fname);
            }
          }

          // if original file no longer exists give an extra warning
          if (!newfile && !os_path_exists(fname)) {
            end = 0;
          }
        }

        if (wfname != fname) {
          xfree(wfname);
        }
        goto fail;
      }
      write_info.bw_fd = fd;
    }
    SET_ERRMSG(NULL);

    write_info.bw_buf = buffer;
    nchars = 0;

    // use "++bin", "++nobin" or 'binary'
    if (eap != NULL && eap->force_bin != 0) {
      write_bin = (eap->force_bin == FORCE_BIN);
    } else {
      write_bin = buf->b_p_bin;
    }

    // Skip the BOM when appending and the file already existed, the BOM
    // only makes sense at the start of the file.
    if (buf->b_p_bomb && !write_bin && (!append || perm < 0)) {
      write_info.bw_len = make_bom(buffer, fenc);
      if (write_info.bw_len > 0) {
        // don't convert
        write_info.bw_flags = FIO_NOCONVERT | wb_flags;
        if (buf_write_bytes(&write_info) == FAIL) {
          end = 0;
        } else {
          nchars += write_info.bw_len;
        }
      }
    }
    write_info.bw_start_lnum = start;

    write_undo_file = (buf->b_p_udf && overwriting && !append
                       && !filtering && reset_changed && !checking_conversion);
    if (write_undo_file) {
      // Prepare for computing the hash value of the text.
      sha256_start(&sha_ctx);
    }

    write_info.bw_len = bufsize;
#ifdef HAS_BW_FLAGS
    write_info.bw_flags = wb_flags;
#endif
    fileformat = get_fileformat_force(buf, eap);
    s = buffer;
    len = 0;
    for (lnum = start; lnum <= end; lnum++) {
      // The next while loop is done once for each character written.
      // Keep it fast!
      ptr = ml_get_buf(buf, lnum, false) - 1;
      if (write_undo_file) {
        sha256_update(&sha_ctx, ptr + 1, (uint32_t)(STRLEN(ptr + 1) + 1));
      }
      while ((c = *++ptr) != NUL) {
        if (c == NL) {
          *s = NUL;                       // replace newlines with NULs
        } else if (c == CAR && fileformat == EOL_MAC) {
          *s = NL;                        // Mac: replace CRs with NLs
        } else {
          *s = c;
        }
        s++;
        if (++len != bufsize) {
          continue;
        }
        if (buf_write_bytes(&write_info) == FAIL) {
          end = 0;                        // write error: break loop
          break;
        }
        nchars += bufsize;
        s = buffer;
        len = 0;
        write_info.bw_start_lnum = lnum;
      }
      // write failed or last line has no EOL: stop here
      if (end == 0
          || (lnum == end
              && (write_bin || !buf->b_p_fixeol)
              && (lnum == buf->b_no_eol_lnum
                  || (lnum == buf->b_ml.ml_line_count && !buf->b_p_eol)))) {
        lnum++;                           // written the line, count it
        no_eol = true;
        break;
      }
      if (fileformat == EOL_UNIX) {
        *s++ = NL;
      } else {
        *s++ = CAR;                       // EOL_MAC or EOL_DOS: write CR
        if (fileformat == EOL_DOS) {      // write CR-NL
          if (++len == bufsize) {
            if (buf_write_bytes(&write_info) == FAIL) {
              end = 0;                    // write error: break loop
              break;
            }
            nchars += bufsize;
            s = buffer;
            len = 0;
          }
          *s++ = NL;
        }
      }
      if (++len == bufsize) {
        if (buf_write_bytes(&write_info) == FAIL) {
          end = 0;  // Write error: break loop.
          break;
        }
        nchars += bufsize;
        s = buffer;
        len = 0;

        os_breakcheck();
        if (got_int) {
          end = 0;  // Interrupted, break loop.
          break;
        }
      }
    }
    if (len > 0 && end > 0) {
      write_info.bw_len = len;
      if (buf_write_bytes(&write_info) == FAIL) {
        end = 0;                      // write error
      }
      nchars += len;
    }

    // Stop when writing done or an error was encountered.
    if (!checking_conversion || end == 0) {
        break;
    }

    // If no error happened until now, writing should be ok, so loop to
    // really write the buffer.
  }

  // If we started writing, finish writing. Also when an error was
  // encountered.
  if (!checking_conversion) {
    // On many journalling file systems there is a bug that causes both the
    // original and the backup file to be lost when halting the system right
    // after writing the file.  That's because only the meta-data is
    // journalled.  Syncing the file slows down the system, but assures it has
    // been written to disk and we don't lose it.
    // For a device do try the fsync() but don't complain if it does not work
    // (could be a pipe).
    // If the 'fsync' option is FALSE, don't fsync().  Useful for laptops.
    int error;
    if (p_fs && (error = os_fsync(fd)) != 0 && !device
        // fsync not supported on this storage.
        && error != UV_ENOTSUP) {
      SET_ERRMSG_ARG(e_fsync, error);
      end = 0;
    }

#ifdef UNIX
    // When creating a new file, set its owner/group to that of the original
    // file.  Get the new device and inode number.
    if (backup != NULL && !backup_copy) {
      // don't change the owner when it's already OK, some systems remove
      // permission or ACL stuff
      FileInfo file_info;
      if (!os_fileinfo((char *)wfname, &file_info)
          || file_info.stat.st_uid != file_info_old.stat.st_uid
          || file_info.stat.st_gid != file_info_old.stat.st_gid) {
        os_fchown(fd, file_info_old.stat.st_uid, file_info_old.stat.st_gid);
        if (perm >= 0) {  // Set permission again, may have changed.
          (void)os_setperm((const char *)wfname, perm);
        }
      }
      buf_set_file_id(buf);
    } else if (!buf->file_id_valid) {
      // Set the file_id when creating a new file.
      buf_set_file_id(buf);
    }
#endif

    if ((error = os_close(fd)) != 0) {
      SET_ERRMSG_ARG(_("E512: Close failed: %s"), error);
      end = 0;
    }

#ifdef UNIX
    if (made_writable) {
      perm &= ~0200;              // reset 'w' bit for security reasons
    }
#endif
    if (perm >= 0) {  // Set perm. of new file same as old file.
      (void)os_setperm((const char *)wfname, perm);
    }
#ifdef HAVE_ACL
    // Probably need to set the ACL before changing the user (can't set the
    // ACL on a file the user doesn't own).
    if (!backup_copy) {
      mch_set_acl(wfname, acl);
    }
#endif

    if (wfname != fname) {
      // The file was written to a temp file, now it needs to be converted
      // with 'charconvert' to (overwrite) the output file.
      if (end != 0) {
        if (eval_charconvert(enc_utf8 ? "utf-8" : (char *)p_enc, (char *)fenc,
                             (char *)wfname, (char *)fname) == FAIL) {
          write_info.bw_conv_error = true;
          end = 0;
        }
      }
      os_remove((char *)wfname);
      xfree(wfname);
    }
  }

  if (end == 0) {
    // Error encountered.
    if (errmsg == NULL) {
      if (write_info.bw_conv_error) {
        if (write_info.bw_conv_error_lnum == 0) {
          SET_ERRMSG(_(
              "E513: write error, conversion failed "
              "(make 'fenc' empty to override)"));
        } else {
          errmsg_allocated = true;
          SET_ERRMSG(xmalloc(300));
          vim_snprintf(
              errmsg, 300,
              _("E513: write error, conversion failed in line %" PRIdLINENR
                " (make 'fenc' empty to override)"),
              write_info.bw_conv_error_lnum);
        }
      } else if (got_int) {
        SET_ERRMSG(_(e_interr));
      } else {
        SET_ERRMSG(_("E514: write error (file system full?)"));
      }
    }

    // If we have a backup file, try to put it in place of the new file,
    // because the new file is probably corrupt.  This avoids losing the
    // original file when trying to make a backup when writing the file a
    // second time.
    // When "backup_copy" is set we need to copy the backup over the new
    // file.  Otherwise rename the backup file.
    // If this is OK, don't give the extra warning message.
    if (backup != NULL) {
      if (backup_copy) {
        // This may take a while, if we were interrupted let the user
        // know we got the message.
        if (got_int) {
          MSG(_(e_interr));
          ui_flush();
        }

        // copy the file.
        if (os_copy((char *)backup, (char *)fname, UV_FS_COPYFILE_FICLONE)
            == 0) {
          end = 1;  // success
        }
      } else {
        if (vim_rename(backup, fname) == 0) {
          end = 1;
        }
      }
    }
    goto fail;
  }

  lnum -= start;            /* compute number of written lines */
  --no_wait_return;         /* may wait for return now */

#if !defined(UNIX)
  fname = sfname;           /* use shortname now, for the messages */
#endif
  if (!filtering) {
    add_quoted_fname((char *)IObuff, IOSIZE, buf, (const char *)fname);
    c = false;
    if (write_info.bw_conv_error) {
      STRCAT(IObuff, _(" CONVERSION ERROR"));
      c = TRUE;
      if (write_info.bw_conv_error_lnum != 0)
        vim_snprintf_add((char *)IObuff, IOSIZE, _(" in line %" PRId64 ";"),
            (int64_t)write_info.bw_conv_error_lnum);
    } else if (notconverted) {
      STRCAT(IObuff, _("[NOT converted]"));
      c = TRUE;
    } else if (converted) {
      STRCAT(IObuff, _("[converted]"));
      c = TRUE;
    }
    if (device) {
      STRCAT(IObuff, _("[Device]"));
      c = TRUE;
    } else if (newfile) {
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
      && (overwriting || vim_strchr(p_cpo, CPO_PLUS) != NULL)) {
    unchanged(buf, true, false);
    const varnumber_T changedtick = buf_get_changedtick(buf);
    if (buf->b_last_changedtick + 1 == changedtick) {
      // b:changedtick may be incremented in unchanged() but that
      // should not trigger a TextChanged event.
      buf->b_last_changedtick = changedtick;
    }
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
    char *org = modname((char *)fname, (char *)p_pm, FALSE);

    if (backup != NULL) {
      /*
       * If the original file does not exist yet
       * the current backup file becomes the original file
       */
      if (org == NULL) {
        EMSG(_("E205: Patchmode: can't save original file"));
      } else if (!os_path_exists((char_u *)org)) {
        vim_rename(backup, (char_u *)org);
        XFREE_CLEAR(backup);                   // don't delete the file
#ifdef UNIX
        os_file_settime(org,
                        file_info_old.stat.st_atim.tv_sec,
                        file_info_old.stat.st_mtim.tv_sec);
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
          || (empty_fd = os_open(org,
                  O_CREAT | O_EXCL | O_NOFOLLOW,
                  perm < 0 ? 0666 : (perm & 0777))) < 0)
        EMSG(_("E206: patchmode: can't touch empty original file"));
      else
        close(empty_fd);
    }
    if (org != NULL) {
      os_setperm(org, os_getperm((const char *)fname) & 0777);
      xfree(org);
    }
  }

  /*
   * Remove the backup unless 'backup' option is set
   */
  if (!p_bk && backup != NULL
      && !write_info.bw_conv_error
      && os_remove((char *)backup) != 0) {
    EMSG(_("E207: Can't delete backup file"));
  }

  goto nofail;

  /*
   * Finish up.  We get here either after failure or success.
   */
fail:
  --no_wait_return;             /* may wait for return now */
nofail:

  /* Done saving, we accept changed buffer warnings again */
  buf->b_saving = false;

  xfree(backup);
  if (buffer != smallbuf)
    xfree(buffer);
  xfree(fenc_tofree);
  xfree(write_info.bw_conv_buf);
# ifdef HAVE_ICONV
  if (write_info.bw_iconv_fd != (iconv_t)-1) {
    iconv_close(write_info.bw_iconv_fd);
    write_info.bw_iconv_fd = (iconv_t)-1;
  }
# endif
#ifdef HAVE_ACL
  mch_free_acl(acl);
#endif

  if (errmsg != NULL) {
    // - 100 to save some space for further error message
#ifndef UNIX
    add_quoted_fname((char *)IObuff, IOSIZE - 100, buf, (const char *)sfname);
#else
    add_quoted_fname((char *)IObuff, IOSIZE - 100, buf, (const char *)fname);
#endif
    if (errnum != NULL) {
      if (errmsgarg != 0) {
        emsgf("%s: %s%s: %s", errnum, IObuff, errmsg, os_strerror(errmsgarg));
      } else {
        emsgf("%s: %s%s", errnum, IObuff, errmsg);
      }
    } else if (errmsgarg != 0) {
      emsgf(errmsg, os_strerror(errmsgarg));
    } else {
      EMSG(errmsg);
    }
    if (errmsg_allocated) {
      xfree(errmsg);
    }

    retval = FAIL;
    if (end == 0) {
      const int attr = HL_ATTR(HLF_E);  // Set highlight for error messages.
      MSG_PUTS_ATTR(_("\nWARNING: Original file may be lost or damaged\n"),
                    attr | MSG_HIST);
      MSG_PUTS_ATTR(_(
              "don't quit the editor until the file is successfully written!"),
          attr | MSG_HIST);

      /* Update the timestamp to avoid an "overwrite changed file"
       * prompt when writing again. */
      if (os_fileinfo((char *)fname, &file_info_old)) {
        buf_store_file_info(buf, &file_info_old);
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
#undef SET_ERRMSG
#undef SET_ERRMSG_ARG
#undef SET_ERRMSG_NUM
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
    if (au_has_group((char_u *)"filetypedetect")) {
      (void)do_doautocmd((char_u *)"filetypedetect BufRead", false, NULL);
    }
    do_modelines(0);
  }

  return OK;
}

/// Put file name into the specified buffer with quotes
///
/// Replaces home directory at the start with `~`.
///
/// @param[out]  ret_buf  Buffer to save results to.
/// @param[in]  buf_len  ret_buf length.
/// @param[in]  buf  buf_T file name is coming from.
/// @param[in]  fname  File name to write.
static void add_quoted_fname(char *const ret_buf, const size_t buf_len,
                             const buf_T *const buf, const char *fname)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (fname == NULL) {
    fname = "-stdin-";
  }
  ret_buf[0] = '"';
  home_replace(buf, (const char_u *)fname, (char_u *)ret_buf + 1,
               (int)buf_len - 4, true);
  xstrlcat(ret_buf, "\" ", buf_len);
}

/// Append message for text mode to IObuff.
///
/// @param eol_type line ending type
///
/// @return true if something was appended.
static bool msg_add_fileformat(int eol_type)
{
#ifndef USE_CRNL
  if (eol_type == EOL_DOS) {
    STRCAT(IObuff, shortmess(SHM_TEXT) ? _("[dos]") : _("[dos format]"));
    return true;
  }
#endif
  if (eol_type == EOL_MAC) {
    STRCAT(IObuff, shortmess(SHM_TEXT) ? _("[mac]") : _("[mac format]"));
    return true;
  }
#ifdef USE_CRNL
  if (eol_type == EOL_UNIX) {
    STRCAT(IObuff, shortmess(SHM_TEXT) ? _("[unix]") : _("[unix format]"));
    return true;
  }
#endif
  return false;
}

/*
 * Append line and character count to IObuff.
 */
void msg_add_lines(int insert_space, long lnum, off_T nchars)
{
  char_u  *p;

  p = IObuff + STRLEN(IObuff);

  if (insert_space)
    *p++ = ' ';
  if (shortmess(SHM_LINES)) {
     sprintf((char *)p, "%" PRId64 "L, %" PRId64 "C",
             (int64_t)lnum, (int64_t)nchars);
  }
  else {
    if (lnum == 1)
      STRCPY(p, _("1 line, "));
    else
      sprintf((char *)p, _("%" PRId64 " lines, "), (int64_t)lnum);
    p += STRLEN(p);
    if (nchars == 1)
      STRCPY(p, _("1 character"));
    else {
      sprintf((char *)p, _("%" PRId64 " characters"), (int64_t)nchars);
    }
  }
}

/*
 * Append message for missing line separator to IObuff.
 */
static void msg_add_eol(void)
{
  STRCAT(IObuff,
      shortmess(SHM_LAST) ? _("[noeol]") : _("[Incomplete last line]"));
}

/*
 * Check modification time of file, before writing to it.
 * The size isn't checked, because using a tool like "gzip" takes care of
 * using the same timestamp but can't set the size.
 */
static int check_mtime(buf_T *buf, FileInfo *file_info)
{
  if (buf->b_mtime_read != 0
      && time_differs(file_info->stat.st_mtim.tv_sec,
                      buf->b_mtime_read)) {
    msg_scroll = true;  // Don't overwrite messages here.
    msg_silent = 0;     // Must give this prompt.
    // Don't use emsg() here, don't want to flush the buffers.
    msg_attr(_("WARNING: The file has been changed since reading it!!!"),
             HL_ATTR(HLF_E));
    if (ask_yesno(_("Do you really want to write to it"), true) == 'n') {
      return FAIL;
    }
    msg_scroll = false;  // Always overwrite the file message now.
  }
  return OK;
}

/// Return true if the times differ
///
/// @param t1 first time
/// @param t2 second time
static bool time_differs(long t1, long t2) FUNC_ATTR_CONST
{
#if defined(__linux__) || defined(MSWIN)
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
 * Handles 'encoding' conversion.
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
   * Skip conversion when writing the BOM.
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
    } else if (flags & (FIO_UCS4 | FIO_UTF16 | FIO_UCS2 | FIO_LATIN1)) {
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
          memmove(ip->bw_rest + ip->bw_restlen, buf, (size_t)l);
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
          } else {
            ip->bw_restlen -= n;
            memmove(ip->bw_rest, ip->bw_rest + n,
                (size_t)ip->bw_restlen);
            n = 0;
          }
        } else {
          n = utf_ptr2len_len(buf + wlen, len - wlen);
          if (n > len - wlen) {
            /* We have an incomplete byte sequence at the end to
             * be written.  We can't convert it without the
             * remaining bytes.  Keep them for the next call. */
            if (len - wlen > CONV_RESTLEN)
              return FAIL;
            ip->bw_restlen = len - wlen;
            memmove(ip->bw_rest, buf + wlen,
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

# ifdef HAVE_ICONV
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
        memmove(fp, ip->bw_rest, (size_t)ip->bw_restlen);
        memmove(fp + ip->bw_restlen, buf, (size_t)len);
        from = fp;
        tolen = ip->bw_conv_buflen - fromlen;
      } else {
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
        memmove(ip->bw_rest, (void *)from, fromlen);
      ip->bw_restlen = (int)fromlen;

      buf = ip->bw_conv_buf;
      len = (int)((char_u *)to - ip->bw_conv_buf);
    }
# endif
  }

  if (ip->bw_fd < 0) {
    // Only checking conversion, which is OK if we get here.
    return OK;
  }
  wlen = write_eintr(ip->bw_fd, buf, len);
  return (wlen < len) ? FAIL : OK;
}

/// Convert a Unicode character to bytes.
///
/// @param c character to convert
/// @param[in,out] pp pointer to store the result at
/// @param flags FIO_ flags that specify which encoding to use
///
/// @return true for an error, false when it's OK.
static bool ucs2bytes(unsigned c, char_u **pp, int flags) FUNC_ATTR_NONNULL_ALL
{
  char_u      *p = *pp;
  bool error = false;
  int cc;


  if (flags & FIO_UCS4) {
    if (flags & FIO_ENDIAN_L) {
      *p++ = c;
      *p++ = (c >> 8);
      *p++ = (c >> 16);
      *p++ = (c >> 24);
    } else {
      *p++ = (c >> 24);
      *p++ = (c >> 16);
      *p++ = (c >> 8);
      *p++ = c;
    }
  } else if (flags & (FIO_UCS2 | FIO_UTF16)) {
    if (c >= 0x10000) {
      if (flags & FIO_UTF16) {
        /* Make two words, ten bits of the character in each.  First
         * word is 0xd800 - 0xdbff, second one 0xdc00 - 0xdfff */
        c -= 0x10000;
        if (c >= 0x100000) {
          error = true;
        }
        cc = ((c >> 10) & 0x3ff) + 0xd800;
        if (flags & FIO_ENDIAN_L) {
          *p++ = cc;
          *p++ = ((unsigned)cc >> 8);
        } else {
          *p++ = ((unsigned)cc >> 8);
          *p++ = cc;
        }
        c = (c & 0x3ff) + 0xdc00;
      } else {
        error = true;
      }
    }
    if (flags & FIO_ENDIAN_L) {
      *p++ = c;
      *p++ = (c >> 8);
    } else {
      *p++ = (c >> 8);
      *p++ = c;
    }
  } else { /* Latin1 */
    if (c >= 0x100) {
      error = true;
      *p++ = 0xBF;
    } else
      *p++ = c;
  }

  *pp = p;
  return error;
}

/// Return true if file encoding "fenc" requires conversion from or to
/// 'encoding'.
///
/// @param fenc file encoding to check
///
/// @return true if conversion is required
static bool need_conversion(const char_u *fenc)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  int same_encoding;
  int enc_flags;
  int fenc_flags;

  if (*fenc == NUL || STRCMP(p_enc, fenc) == 0) {
    same_encoding = TRUE;
    fenc_flags = 0;
  } else {
    /* Ignore difference between "ansi" and "latin1", "ucs-4" and
     * "ucs-4be", etc. */
    enc_flags = get_fio_flags(p_enc);
    fenc_flags = get_fio_flags(fenc);
    same_encoding = (enc_flags != 0 && fenc_flags == enc_flags);
  }
  if (same_encoding) {
    // Specified file encoding matches UTF-8.
    return false;
  }

  /* Encodings differ.  However, conversion is not needed when 'enc' is any
   * Unicode encoding and the file is UTF-8. */
  return !(enc_utf8 && fenc_flags == FIO_UTF8);
}

/// Return the FIO_ flags needed for the internal conversion if 'name' was
/// unicode or latin1, otherwise 0. If "name" is an empty string,
/// use 'encoding'.
///
/// @param name string to check for encoding
static int get_fio_flags(const char_u *name)
{
  int prop;

  if (*name == NUL) {
    name = p_enc;
  }
  prop = enc_canon_props(name);
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
  } else if (p[0] == 0xff && p[1] == 0xfe) {
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

/// Shorten filename of a buffer.
/// When "force" is TRUE: Use full path from now on for files currently being
/// edited, both for file name and swap file name.  Try to shorten the file
/// names a bit, if safe to do so.
/// When "force" is FALSE: Only try to shorten absolute file names.
/// For buffers that have buftype "nofile" or "scratch": never change the file
/// name.
void shorten_buf_fname(buf_T *buf, char_u *dirname, int force)
{
  char_u      *p;

  if (buf->b_fname != NULL
      && !bt_nofile(buf)
      && !path_with_url((char *)buf->b_fname)
      && (force
          || buf->b_sfname == NULL
          || path_is_absolute(buf->b_sfname))) {
    XFREE_CLEAR(buf->b_sfname);
    p = path_shorten_fname(buf->b_ffname, dirname);
    if (p != NULL) {
      buf->b_sfname = vim_strsave(p);
      buf->b_fname = buf->b_sfname;
    }
    if (p == NULL) {
      buf->b_fname = buf->b_ffname;
    }
  }
}

/// Shorten filenames for all buffers.
void shorten_fnames(int force)
{
  char_u dirname[MAXPATHL];

  os_dirname(dirname, MAXPATHL);
  FOR_ALL_BUFFERS(buf) {
      shorten_buf_fname(buf, dirname, force);

    // Always make the swap file name a full path, a "nofile" buffer may
    // also have a swap file.
    mf_fullname(buf->b_ml.ml_mfp);
  }
  status_redraw_all();
  redraw_tabline = TRUE;
}

/// Get new filename ended by given extension.
///
/// @param fname        The original filename.
///                     If NULL, use current directory name and ext to
///                     compute new filename.
/// @param ext          The extension to add to the filename.
///                     4 chars max if prefixed with a dot, 3 otherwise.
/// @param prepend_dot  If true, prefix ext with a dot.
///                     Does nothing if ext already starts with a dot, or
///                     if fname is NULL.
///
/// @return [allocated] - A new filename, made up from:
///                       * fname + ext, if fname not NULL.
///                       * current dir + ext, if fname is NULL.
///                       Result is guaranteed to:
///                       * be ended by <ext>.
///                       * have a basename with at most BASENAMELEN chars:
///                         original basename is truncated if necessary.
///                       * be different than original: basename chars are
///                         replaced by "_" if necessary. If that can't be done
///                         because truncated value of original filename was
///                         made of all underscores, replace first "_" by "v".
///                     - NULL, if fname is NULL and there was a problem trying
///                       to get current directory.
char *modname(const char *fname, const char *ext, bool prepend_dot)
  FUNC_ATTR_NONNULL_ARG(2)
{
  char *retval;
  size_t fnamelen;
  size_t extlen = strlen(ext);

  // If there is no file name we must get the name of the current directory
  // (we need the full path in case :cd is used).
  if (fname == NULL || *fname == NUL) {
    retval = xmalloc(MAXPATHL + extlen + 3);  // +3 for PATHSEP, "_" (Win), NUL
    if (os_dirname((char_u *)retval, MAXPATHL) == FAIL
        || (fnamelen = strlen(retval)) == 0) {
      xfree(retval);
      return NULL;
    }
    add_pathsep(retval);
    fnamelen = strlen(retval);
    prepend_dot = FALSE;  // nothing to prepend a dot to
  } else {
    fnamelen = strlen(fname);
    retval = xmalloc(fnamelen + extlen + 3);
    strcpy(retval, fname);
  }

  // Search backwards until we hit a '/', '\' or ':'.
  // Then truncate what is after the '/', '\' or ':' to BASENAMELEN characters.
  char *ptr = NULL;
  for (ptr = retval + fnamelen; ptr > retval; MB_PTR_BACK(retval, ptr)) {
    if (vim_ispathsep(*ptr)) {
      ptr++;
      break;
    }
  }

  // the file name has at most BASENAMELEN characters.
  if (strlen(ptr) > BASENAMELEN) {
    ptr[BASENAMELEN] = '\0';
  }

  char *s;
  s = ptr + strlen(ptr);

  // Append the extension.
  // ext can start with '.' and cannot exceed 3 more characters.
  strcpy(s, ext);

  char *e;
  // Prepend the dot if needed.
  if (prepend_dot && *(e = (char *)path_tail((char_u *)retval)) != '.') {
    STRMOVE(e + 1, e);
    *e = '.';
  }

  // Check that, after appending the extension, the file name is really
  // different.
  if (fname != NULL && strcmp(fname, retval) == 0) {
    // we search for a character that can be replaced by '_'
    while (--s >= ptr) {
      if (*s != '_') {
        *s = '_';
        break;
      }
    }
    if (s < ptr) {  // fname was "________.<ext>", how tricky!
      *ptr = 'v';
    }
  }
  return retval;
}

/// Like fgets(), but if the file line is too long, it is truncated and the
/// rest of the line is thrown away.
///
/// @param[out] buf buffer to fill
/// @param size size of the buffer
/// @param fp file to read from
///
/// @return true for EOF or error
bool vim_fgets(char_u *buf, int size, FILE *fp) FUNC_ATTR_NONNULL_ALL
{
  char *retval;

  assert(size > 0);
  buf[size - 2] = NUL;

  do {
    errno = 0;
    retval = fgets((char *)buf, size, fp);
  } while (retval == NULL && errno == EINTR && ferror(fp));

  if (buf[size - 2] != NUL && buf[size - 2] != '\n') {
    char tbuf[200];

    buf[size - 1] = NUL;  // Truncate the line.

    // Now throw away the rest of the line:
    do {
      tbuf[sizeof(tbuf) - 2] = NUL;
      errno = 0;
      retval = fgets((char *)tbuf, sizeof(tbuf), fp);
      if (retval == NULL && (feof(fp) || errno != EINTR)) {
        break;
      }
    } while (tbuf[sizeof(tbuf) - 2] != NUL && tbuf[sizeof(tbuf) - 2] != '\n');
  }
  return retval == NULL;
}

/// Read 2 bytes from "fd" and turn them into an int, MSB first.
/// Returns -1 when encountering EOF.
int get2c(FILE *fd)
{
  const int n = getc(fd);
  if (n == EOF) {
    return -1;
  }
  const int c = getc(fd);
  if (c == EOF) {
    return -1;
  }
  return (n << 8) + c;
}

/// Read 3 bytes from "fd" and turn them into an int, MSB first.
/// Returns -1 when encountering EOF.
int get3c(FILE *fd)
{
  int n = getc(fd);
  if (n == EOF) {
    return -1;
  }
  int c = getc(fd);
  if (c == EOF) {
    return -1;
  }
  n = (n << 8) + c;
  c = getc(fd);
  if (c == EOF) {
    return -1;
  }
  return (n << 8) + c;
}

/// Read 4 bytes from "fd" and turn them into an int, MSB first.
/// Returns -1 when encountering EOF.
int get4c(FILE *fd)
{
  // Use unsigned rather than int otherwise result is undefined
  // when left-shift sets the MSB.
  unsigned n;

  int c = getc(fd);
  if (c == EOF) {
    return -1;
  }
  n = (unsigned)c;
  c = getc(fd);
  if (c == EOF) {
    return -1;
  }
  n = (n << 8) + (unsigned)c;
  c = getc(fd);
  if (c == EOF) {
    return -1;
  }
  n = (n << 8) + (unsigned)c;
  c = getc(fd);
  if (c == EOF) {
    return -1;
  }
  n = (n << 8) + (unsigned)c;
  return (int)n;
}

/// Read 8 bytes from `fd` and turn them into a time_t, MSB first.
/// Returns -1 when encountering EOF.
time_t get8ctime(FILE *fd)
{
  time_t n = 0;

  for (int i = 0; i < 8; i++) {
    const int c = getc(fd);
    if (c == EOF) {
      return -1;
    }
    n = (n << 8) + c;
  }
  return n;
}

/// Reads a string of length "cnt" from "fd" into allocated memory.
/// @return pointer to the string or NULL when unable to read that many bytes.
char *read_string(FILE *fd, size_t cnt)
{
  char *str = xmallocz(cnt);
  for (size_t i = 0; i < cnt; i++) {
    int c = getc(fd);
    if (c == EOF) {
      xfree(str);
      return NULL;
    }
    str[i] = (char)c;
  }
  return str;
}

/// Writes a number to file "fd", most significant bit first, in "len" bytes.
/// @returns false in case of an error.
bool put_bytes(FILE *fd, uintmax_t number, size_t len)
{
  assert(len > 0);
  for (size_t i = len - 1; i < len; i--) {
    if (putc((int)(number >> (i * 8)), fd) == EOF) {
      return false;
    }
  }
  return true;
}

/// Writes time_t to file "fd" in 8 bytes.
/// @returns FAIL when the write failed.
int put_time(FILE *fd, time_t time_)
{
  uint8_t buf[8];
  time_to_bytes(time_, buf);
  return fwrite(buf, sizeof(uint8_t), ARRAY_SIZE(buf), fd) == 1 ? OK : FAIL;
}

/// os_rename() only works if both files are on the same file system, this
/// function will (attempts to?) copy the file across if rename fails -- webb
///
/// @return -1 for failure, 0 for success
int vim_rename(const char_u *from, const char_u *to)
  FUNC_ATTR_NONNULL_ALL
{
  int fd_in;
  int fd_out;
  int n;
  char        *errmsg = NULL;
  char        *buffer;
  long perm;
#ifdef HAVE_ACL
  vim_acl_T acl;                /* ACL from original file */
#endif
  bool use_tmp_file = false;

  /*
   * When the names are identical, there is nothing to do.  When they refer
   * to the same file (ignoring case and slash/backslash differences) but
   * the file name differs we need to go through a temp file.
   */
  if (fnamecmp(from, to) == 0) {
    if (p_fic && (STRCMP(path_tail((char_u *)from), path_tail((char_u *)to))
                  != 0)) {
      use_tmp_file = true;
    } else {
      return 0;
    }
  }

  // Fail if the "from" file doesn't exist. Avoids that "to" is deleted.
  FileInfo from_info;
  if (!os_fileinfo((char *)from, &from_info)) {
    return -1;
  }

  // It's possible for the source and destination to be the same file.
  // This happens when "from" and "to" differ in case and are on a FAT32
  // filesystem. In that case go through a temp file name.
  FileInfo to_info;
  if (os_fileinfo((char *)to, &to_info)
      && os_fileinfo_id_equal(&from_info,  &to_info)) {
    use_tmp_file = true;
  }

  if (use_tmp_file) {
    char_u tempname[MAXPATHL + 1];

    /*
     * Find a name that doesn't exist and is in the same directory.
     * Rename "from" to "tempname" and then rename "tempname" to "to".
     */
    if (STRLEN(from) >= MAXPATHL - 5)
      return -1;
    STRCPY(tempname, from);
    for (n = 123; n < 99999; n++) {
      char * tail = (char *)path_tail(tempname);
      snprintf(tail, (MAXPATHL + 1) - (tail - (char *)tempname - 1), "%d", n);

      if (!os_path_exists(tempname)) {
        if (os_rename(from, tempname) == OK) {
          if (os_rename(tempname, to) == OK)
            return 0;
          /* Strange, the second step failed.  Try moving the
           * file back and return failure. */
          os_rename(tempname, from);
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
   * os_rename() work, on other systems it makes sure that we don't have
   * two files when the os_rename() fails.
   */

  os_remove((char *)to);

  /*
   * First try a normal rename, return if it works.
   */
  if (os_rename(from, to) == OK)
    return 0;

  /*
   * Rename() failed, try copying the file.
   */
  perm = os_getperm((const char *)from);
#ifdef HAVE_ACL
  // For systems that support ACL: get the ACL from the original file.
  acl = mch_get_acl(from);
#endif
  fd_in = os_open((char *)from, O_RDONLY, 0);
  if (fd_in < 0) {
#ifdef HAVE_ACL
    mch_free_acl(acl);
#endif
    return -1;
  }

  /* Create the new file with same permissions as the original. */
  fd_out = os_open((char *)to,
      O_CREAT|O_EXCL|O_WRONLY|O_NOFOLLOW, (int)perm);
  if (fd_out < 0) {
    close(fd_in);
#ifdef HAVE_ACL
    mch_free_acl(acl);
#endif
    return -1;
  }

  // Avoid xmalloc() here as vim_rename() is called by buf_write() when nvim
  // is `preserve_exit()`ing.
  buffer = try_malloc(BUFSIZE);
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

  xfree(buffer);
  close(fd_in);
  if (close(fd_out) < 0)
    errmsg = _("E209: Error closing \"%s\"");
  if (n < 0) {
    errmsg = _("E210: Error reading \"%s\"");
    to = from;
  }
#ifndef UNIX  // For Unix os_open() already set the permission.
  os_setperm((const char *)to, perm);
#endif
#ifdef HAVE_ACL
  mch_set_acl(to, acl);
  mch_free_acl(acl);
#endif
  if (errmsg != NULL) {
    EMSG2(errmsg, to);
    return -1;
  }
  os_remove((char *)from);
  return 0;
}

static int already_warned = FALSE;

// Check if any not hidden buffer has been changed.
// Postpone the check if there are characters in the stuff buffer, a global
// command is being executed, a mapping is being executed or an autocommand is
// busy.
// Returns TRUE if some message was written (screen should be redrawn and
// cursor positioned).
int
check_timestamps(
    int focus                      // called for GUI focus event
)
{
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
      ) {
    need_check_timestamps = true;               // check later
  } else {
    no_wait_return++;
    did_check_timestamps = true;
    already_warned = false;
    FOR_ALL_BUFFERS(buf) {
      // Only check buffers in a window.
      if (buf->b_nwindows > 0) {
        bufref_T bufref;
        set_bufref(&bufref, buf);
        n = buf_check_timestamp(buf, focus);
        if (didit < n) {
          didit = n;
        }
        if (n > 0 && !bufref_valid(&bufref)) {
          // Autocommands have removed the buffer, start at the first one again.
          buf = firstbuf;
          continue;
        }
      }
    }
    --no_wait_return;
    need_check_timestamps = FALSE;
    if (need_wait_return && didit == 2) {
      // make sure msg isn't overwritten
      msg_puts("\n");
      ui_flush();
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
  for (lnum = 1; lnum <= frombuf->b_ml.ml_line_count; lnum++) {
    p = vim_strsave(ml_get_buf(frombuf, lnum, false));
    if (ml_append(lnum - 1, p, 0, false) == FAIL) {
      xfree(p);
      retval = FAIL;
      break;
    }
    xfree(p);
  }

  /* Delete all the lines in "frombuf". */
  if (retval != FAIL) {
    curbuf = frombuf;
    for (lnum = curbuf->b_ml.ml_line_count; lnum > 0; lnum--) {
      if (ml_delete(lnum, false) == FAIL) {
        // Oops!  We could try putting back the saved lines, but that
        // might fail again...
        retval = FAIL;
        break;
      }
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
buf_check_timestamp(
    buf_T *buf,
    int focus               /* called for GUI focus event */
)
  FUNC_ATTR_NONNULL_ALL
{
  int retval = 0;
  char_u      *path;
  char        *mesg = NULL;
  char        *mesg2 = "";
  bool helpmesg = false;
  bool reload = false;
  bool can_reload = false;
  uint64_t orig_size = buf->b_orig_size;
  int orig_mode = buf->b_orig_mode;
  static bool busy = false;
  char_u      *s;
  char        *reason;

  bufref_T bufref;
  set_bufref(&bufref, buf);

  // If its a terminal, there is no file name, the buffer is not loaded,
  // 'buftype' is set, we are in the middle of a save or being called
  // recursively: ignore this buffer.
  if (buf->terminal
      || buf->b_ffname == NULL
      || buf->b_ml.ml_mfp == NULL
      || !bt_normal(buf)
      || buf->b_saving
      || busy
      )
    return 0;

  FileInfo file_info;
  bool file_info_ok;
  if (!(buf->b_flags & BF_NOTEDITED)
      && buf->b_mtime != 0
      && (!(file_info_ok = os_fileinfo((char *)buf->b_ffname, &file_info))
          || time_differs(file_info.stat.st_mtim.tv_sec, buf->b_mtime)
          || (int)file_info.stat.st_mode != buf->b_orig_mode)) {
    const long prev_b_mtime = buf->b_mtime;

    retval = 1;

    // set b_mtime to stop further warnings (e.g., when executing
    // FileChangedShell autocmd)
    if (!file_info_ok) {
      // Check the file again later to see if it re-appears.
      buf->b_mtime = -1;
      buf->b_orig_size = 0;
      buf->b_orig_mode = 0;
    } else {
      buf_store_file_info(buf, &file_info);
    }

    /* Don't do anything for a directory.  Might contain the file
     * explorer. */
    if (os_isdir(buf->b_fname)) {
    } else if ((buf->b_p_ar >= 0 ? buf->b_p_ar : p_ar)
               && !bufIsChanged(buf) && file_info_ok) {
      // If 'autoread' is set, the buffer has no changes and the file still
      // exists, reload the buffer.  Use the buffer-local option value if it
      // was set, the global option value otherwise.
      reload = true;
    } else {
      if (!file_info_ok) {
        reason = "deleted";
      } else if (bufIsChanged(buf)) {
        reason = "conflict";
      } else if (orig_size != buf->b_orig_size || buf_contents_changed(buf)) {
        reason = "changed";
      } else if (orig_mode != buf->b_orig_mode) {
        reason = "mode";
      } else {
        reason = "time";
      }

      // Only give the warning if there are no FileChangedShell
      // autocommands.
      // Avoid being called recursively by setting "busy".
      busy = true;
      set_vim_var_string(VV_FCS_REASON, reason, -1);
      set_vim_var_string(VV_FCS_CHOICE, "", -1);
      allbuf_lock++;
      bool n = apply_autocmds(EVENT_FILECHANGEDSHELL,
                              buf->b_fname, buf->b_fname, false, buf);
      allbuf_lock--;
      busy = false;
      if (n) {
        if (!bufref_valid(&bufref)) {
          EMSG(_("E246: FileChangedShell autocommand deleted buffer"));
        }
        s = get_vim_var_str(VV_FCS_CHOICE);
        if (STRCMP(s, "reload") == 0 && *reason != 'd') {
          reload = true;
        } else if (STRCMP(s, "ask") == 0) {
          n = false;
        } else {
          return 2;
        }
      }
      if (!n) {
        if (*reason == 'd') {
          // Only give the message once.
          if (prev_b_mtime != -1) {
            mesg = _("E211: File \"%s\" no longer available");
          }
        } else {
          helpmesg = true;
          can_reload = true;

          // Check if the file contents really changed to avoid
          // giving a warning when only the timestamp was set (e.g.,
          // checked out of CVS).  Always warn when the buffer was
          // changed.
          if (reason[2] == 'n') {
            mesg = _(
                "W12: Warning: File \"%s\" has changed and the buffer was changed in Vim as well");
            mesg2 = _("See \":help W12\" for more info.");
          } else if (reason[1] == 'h') {
            mesg = _(
                "W11: Warning: File \"%s\" has changed since editing started");
            mesg2 = _("See \":help W11\" for more info.");
          } else if (*reason == 'm') {
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
             && os_path_exists(buf->b_ffname)) {
    retval = 1;
    mesg = _("W13: Warning: File \"%s\" has been created after editing started");
    buf->b_flags |= BF_NEW_W;
    can_reload = true;
  }

  if (mesg != NULL) {
    path = home_replace_save(buf, buf->b_fname);
    if (!helpmesg) {
      mesg2 = "";
    }
    const size_t tbuf_len = STRLEN(path) + STRLEN(mesg) + STRLEN(mesg2) + 2;
    char *const tbuf = xmalloc(tbuf_len);
    snprintf(tbuf, tbuf_len, mesg, path);
    // Set warningmsg here, before the unimportant and output-specific
    // mesg2 has been appended.
    set_vim_var_string(VV_WARNINGMSG, tbuf, -1);
    if (can_reload) {
      if (*mesg2 != NUL) {
        xstrlcat(tbuf, "\n", tbuf_len - 1);
        xstrlcat(tbuf, mesg2, tbuf_len - 1);
      }
      if (do_dialog(VIM_WARNING, (char_u *) _("Warning"), (char_u *) tbuf,
                    (char_u *) _("&OK\n&Load File"), 1, NULL, true) == 2) {
        reload = true;
      }
    } else if (State > NORMAL_BUSY || (State & CMDLINE) || already_warned) {
      if (*mesg2 != NUL) {
        xstrlcat(tbuf, "; ", tbuf_len - 1);
        xstrlcat(tbuf, mesg2, tbuf_len - 1);
      }
      EMSG(tbuf);
      retval = 2;
    } else {
      if (!autocmd_busy) {
        msg_start();
        msg_puts_attr(tbuf, HL_ATTR(HLF_E) + MSG_HIST);
        if (*mesg2 != NUL) {
          msg_puts_attr(mesg2, HL_ATTR(HLF_W) + MSG_HIST);
        }
        msg_clr_eos();
        (void)msg_end();
        if (emsg_silent == 0) {
          ui_flush();
          /* give the user some time to think about it */
          os_delay(1000L, true);

          /* don't redraw and erase the message */
          redraw_cmdline = FALSE;
        }
      }
      already_warned = TRUE;
    }

    xfree(path);
    xfree(tbuf);
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

  // Trigger FileChangedShell when the file was changed in any way.
  if (bufref_valid(&bufref) && retval != 0) {
    (void)apply_autocmds(EVENT_FILECHANGEDSHELLPOST, buf->b_fname, buf->b_fname,
                         false, buf);
  }
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
  bufref_T bufref;
  int saved = OK;
  aco_save_T aco;
  int flags = READ_NEW;

  /* set curwin/curbuf for "buf" and save some things */
  aucmd_prepbuf(&aco, buf);

  // We only want to read the text from the file, not reset the syntax
  // highlighting, clear marks, diff status, etc.  Force the fileformat and
  // encoding to be the same.

  prep_exarg(&ea, buf);
  old_cursor = curwin->w_cursor;
  old_topline = curwin->w_topline;

  if (p_ur < 0 || curbuf->b_ml.ml_line_count <= p_ur) {
    /* Save all the text, so that the reload can be undone.
     * Sync first so that this is a separate undo-able action. */
    u_sync(FALSE);
    saved = u_savecommon(0, curbuf->b_ml.ml_line_count + 1, 0, TRUE);
    flags |= READ_KEEP_UNDO;
  }

  // To behave like when a new file is edited (matters for
  // BufReadPost autocommands) we first need to delete the current
  // buffer contents.  But if reading the file fails we should keep
  // the old contents.  Can't use memory only, the file might be
  // too big.  Use a hidden buffer to move the buffer contents to.
  if (BUFEMPTY() || saved == FAIL) {
    savebuf = NULL;
  } else {
    // Allocate a buffer without putting it in the buffer list.
    savebuf = buflist_new(NULL, NULL, (linenr_T)1, BLN_DUMMY);
    set_bufref(&bufref, savebuf);
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
    curbuf->b_flags |= BF_CHECK_RO;           // check for RO again
    keep_filetype = true;                     // don't detect 'filetype'
    if (readfile(buf->b_ffname, buf->b_fname, (linenr_T)0, (linenr_T)0,
                 (linenr_T)MAXLNUM, &ea, flags) != OK) {
      if (!aborting()) {
        EMSG2(_("E321: Could not reload \"%s\""), buf->b_fname);
      }
      if (savebuf != NULL && bufref_valid(&bufref) && buf == curbuf) {
        // Put the text back from the save buffer.  First
        // delete any lines that readfile() added.
        while (!BUFEMPTY()) {
          if (ml_delete(buf->b_ml.ml_line_count, false) == FAIL) {
            break;
          }
        }
        (void)move_lines(savebuf, buf);
      }
    } else if (buf == curbuf) {  // "buf" still valid.
      // Mark the buffer as unmodified and free undo info.
      unchanged(buf, true, true);
      if ((flags & READ_KEEP_UNDO) == 0) {
        u_blockfree(buf);
        u_clearall(buf);
      } else {
        // Mark all undo states as changed.
        u_unchanged(curbuf);
      }
    }
  }
  xfree(ea.cmd);

  if (savebuf != NULL && bufref_valid(&bufref)) {
    wipe_buffer(savebuf, false);
  }

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

  /* Update folds unless they are defined manually. */
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp->w_buffer == curwin->w_buffer
        && !foldmethodIsManual(wp)) {
      foldUpdateAll(wp);
    }
  }

  /* If the mode didn't change and 'readonly' was set, keep the old
   * value; the user probably used the ":view" command.  But don't
   * reset it, might have had a read error. */
  if (orig_mode == curbuf->b_orig_mode)
    curbuf->b_p_ro |= old_ro;

  /* Modelines must override settings done by autocommands. */
  do_modelines(0);

  /* restore curwin/curbuf and a few other things */
  aucmd_restbuf(&aco);
  /* Careful: autocommands may have made "buf" invalid! */
}

void buf_store_file_info(buf_T *buf, FileInfo *file_info)
  FUNC_ATTR_NONNULL_ALL
{
  buf->b_mtime = file_info->stat.st_mtim.tv_sec;
  buf->b_orig_size = os_fileinfo_size(file_info);
  buf->b_orig_mode = (int)file_info->stat.st_mode;
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

#if defined(BACKSLASH_IN_FILENAME)
/// Convert all backslashes in fname to forward slashes in-place,
/// unless when it looks like a URL.
void forward_slash(char_u *fname)
{
  char_u      *p;

  if (path_with_url((const char *)fname)) {
    return;
  }
  for (p = fname; *p != NUL; p++) {
    // The Big5 encoding can have '\' in the trail byte.
    if (*p == '\\') {
      *p = '/';
    }
  }
}
#endif

/// Name of Vim's own temp dir. Ends in a slash.
static char_u *vim_tempdir = NULL;

/// Create a directory for private use by this instance of Neovim.
/// This is done once, and the same directory is used for all temp files.
/// This method avoids security problems because of symlink attacks et al.
/// It's also a bit faster, because we only need to check for an existing
/// file when creating the directory and not for each temp file.
static void vim_maketempdir(void)
{
  static const char *temp_dirs[] = TEMP_DIR_NAMES;
  // Try the entries in `TEMP_DIR_NAMES` to create the temp directory.
  char_u template[TEMP_FILE_PATH_MAXLEN];
  char_u path[TEMP_FILE_PATH_MAXLEN];

  // Make sure the umask doesn't remove the executable bit.
  // "repl" has been reported to use "0177".
  mode_t umask_save = umask(0077);
  for (size_t i = 0; i < ARRAY_SIZE(temp_dirs); i++) {
    // Expand environment variables, leave room for "/nvimXXXXXX/999999999"
    expand_env((char_u *)temp_dirs[i], template, TEMP_FILE_PATH_MAXLEN - 22);
    if (!os_isdir(template)) {  // directory doesn't exist
      continue;
    }

    add_pathsep((char *)template);
    // Concatenate with temporary directory name pattern
    STRCAT(template, "nvimXXXXXX");

    if (os_mkdtemp((const char *)template, (char *)path) != 0) {
      continue;
    }

    if (vim_settempdir((char *)path)) {
      // Successfully created and set temporary directory so stop trying.
      break;
    } else {
      // Couldn't set `vim_tempdir` to `path` so remove created directory.
      os_rmdir((char *)path);
    }
  }
  (void)umask(umask_save);
}

/// Delete "name" and everything in it, recursively.
/// @param name The path which should be deleted.
/// @return 0 for success, -1 if some file was not deleted.
int delete_recursive(const char *name)
{
  int result = 0;

  if (os_isrealdir(name)) {
    snprintf((char *)NameBuff, MAXPATHL, "%s/*", name);  // NOLINT

    char_u **files;
    int file_count;
    char_u *exp = vim_strsave(NameBuff);
    if (gen_expand_wildcards(1, &exp, &file_count, &files,
                             EW_DIR | EW_FILE | EW_SILENT | EW_ALLLINKS
                             | EW_DODOT | EW_EMPTYOK) == OK) {
      for (int i = 0; i < file_count; i++) {
        if (delete_recursive((const char *)files[i]) != 0) {
          result = -1;
        }
      }
      FreeWild(file_count, files);
    } else {
      result = -1;
    }

    xfree(exp);
    os_rmdir(name);
  } else {
    result = os_remove(name) == 0 ? 0 : -1;
  }

  return result;
}

/// Delete the temp directory and all files it contains.
void vim_deltempdir(void)
{
  if (vim_tempdir != NULL) {
    // remove the trailing path separator
    path_tail(vim_tempdir)[-1] = NUL;
    delete_recursive((const char *)vim_tempdir);
    XFREE_CLEAR(vim_tempdir);
  }
}

/// Get the name of temp directory. This directory would be created on the first
/// call to this function.
char_u *vim_gettempdir(void)
{
  if (vim_tempdir == NULL) {
    vim_maketempdir();
  }

  return vim_tempdir;
}

/// Set Neovim own temporary directory name to `tempdir`. This directory should
/// be already created. Expand this name to a full path and put it in
/// `vim_tempdir`. This avoids that using `:cd` would confuse us.
///
/// @param tempdir must be no longer than MAXPATHL.
///
/// @return false if we run out of memory.
static bool vim_settempdir(char *tempdir)
{
  char *buf = verbose_try_malloc(MAXPATHL + 2);
  if (!buf) {
    return false;
  }
  vim_FullName(tempdir, buf, MAXPATHL, false);
  add_pathsep(buf);
  vim_tempdir = (char_u *)xstrdup(buf);
  xfree(buf);
  return true;
}

/// Return a unique name that can be used for a temp file.
///
/// @note The temp file is NOT created.
///
/// @return pointer to the temp file name or NULL if Neovim can't create
///         temporary directory for its own temporary files.
char_u *vim_tempname(void)
{
  // Temp filename counter.
  static uint32_t temp_count;

  char_u *tempdir = vim_gettempdir();
  if (!tempdir) {
    return NULL;
  }

  // There is no need to check if the file exists, because we own the directory
  // and nobody else creates a file in it.
  char_u template[TEMP_FILE_PATH_MAXLEN];
  snprintf((char *)template, TEMP_FILE_PATH_MAXLEN,
           "%s%" PRIu32, tempdir, temp_count++);
  return vim_strsave(template);
}


/*
 * Code for automatic commands.
 */
#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "auevents_name_map.generated.h"
#endif

static AutoPatCmd *active_apc_list = NULL; /* stack of active autocommands */

/// List of autocmd group names
static garray_T augroups = { 0, 0, sizeof(char_u *), 10, NULL };
#define AUGROUP_NAME(i) (((char **)augroups.ga_data)[i])

/*
 * The ID of the current group.  Group 0 is the default one.
 */
static int current_augroup = AUGROUP_DEFAULT;

static int au_need_clean = FALSE;   /* need to delete marked patterns */



static event_T last_event;
static int last_group;
static int autocmd_blocked = 0;         /* block all autocmds */

// use get_deleted_augroup() to get this
static const char *deleted_augroup = NULL;

static inline const char *get_deleted_augroup(void)
  FUNC_ATTR_ALWAYS_INLINE
{
    if (deleted_augroup == NULL) {
      deleted_augroup = _("--Deleted--");
    }
    return deleted_augroup;
}

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
      if (AUGROUP_NAME(ap->group) == NULL) {
        msg_puts_attr(get_deleted_augroup(), HL_ATTR(HLF_E));
      } else {
        msg_puts_attr(AUGROUP_NAME(ap->group), HL_ATTR(HLF_T));
      }
      msg_puts("  ");
    }
    msg_puts_attr(event_nr2name(event), HL_ATTR(HLF_T));
    last_event = event;
    last_group = ap->group;
    msg_putchar('\n');
    if (got_int)
      return;
  }
  msg_col = 4;
  msg_outtrans(ap->pat);

  for (ac = ap->cmds; ac != NULL; ac = ac->next) {
    if (ac->cmd == NULL) {              /* skip removed commands */
      continue;
    }
    if (msg_col >= 14) {
      msg_putchar('\n');
    }
    msg_col = 14;
    if (got_int) {
      return;
    }
    msg_outtrans(ac->cmd);
    if (p_verbose > 0) {
      last_set_msg(ac->script_ctx);
    }
    if (got_int) {
      return;
    }
    if (ac->next != NULL) {
      msg_putchar('\n');
      if (got_int) {
        return;
      }
    }
  }
}

// Mark an autocommand handler for deletion.
static void au_remove_pat(AutoPat *ap)
{
  XFREE_CLEAR(ap->pat);
  ap->buflocal_nr = -1;
  au_need_clean = true;
}

// Mark all commands for a pattern for deletion.
static void au_remove_cmds(AutoPat *ap)
{
  for (AutoCmd *ac = ap->cmds; ac != NULL; ac = ac->next) {
    XFREE_CLEAR(ac->cmd);
  }
  au_need_clean = true;
}

// Delete one command from an autocmd pattern.
static void au_del_cmd(AutoCmd *ac)
{
  XFREE_CLEAR(ac->cmd);
  au_need_clean = true;
}

/// Cleanup autocommands and patterns that have been deleted.
/// This is only done when not executing autocommands.
static void au_cleanup(void)
{
  AutoPat     *ap, **prev_ap;
  AutoCmd     *ac, **prev_ac;
  event_T event;

  if (autocmd_busy || !au_need_clean) {
    return;
  }

  // Loop over all events.
  for (event = (event_T)0; (int)event < (int)NUM_EVENTS;
       event = (event_T)((int)event + 1)) {
    // Loop over all autocommand patterns.
    prev_ap = &(first_autopat[(int)event]);
    for (ap = *prev_ap; ap != NULL; ap = *prev_ap) {
      // Loop over all commands for this pattern.
      prev_ac = &(ap->cmds);
      bool has_cmd = false;

      for (ac = *prev_ac; ac != NULL; ac = *prev_ac) {
        // Remove the command if the pattern is to be deleted or when
        // the command has been marked for deletion.
        if (ap->pat == NULL || ac->cmd == NULL) {
          *prev_ac = ac->next;
          xfree(ac->cmd);
          xfree(ac);
        } else {
          has_cmd = true;
          prev_ac = &(ac->next);
        }
      }

      if (ap->pat != NULL && !has_cmd) {
        // Pattern was not marked for deletion, but all of its commands were.
        // So mark the pattern for deletion.
        au_remove_pat(ap);
      }

      // Remove the pattern if it has been marked for deletion.
      if (ap->pat == NULL) {
        if (ap->next == NULL) {
          if (prev_ap == &(first_autopat[(int)event])) {
            last_autopat[(int)event] = NULL;
          } else {
            // this depends on the "next" field being the first in
            // the struct
            last_autopat[(int)event] = (AutoPat *)prev_ap;
          }
        }
        *prev_ap = ap->next;
        vim_regfree(ap->reg_prog);
        xfree(ap);
      } else {
        prev_ap = &(ap->next);
      }
    }
  }

  au_need_clean = false;
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
          smsg(_("auto-removing autocommand: %s <buffer=%d>"),
               event_nr2name(event), buf->b_fnum);
          verbose_leave();
        }
      }
  au_cleanup();
}

// Add an autocmd group name.
// Return its ID.  Returns AUGROUP_ERROR (< 0) for error.
static int au_new_group(char_u *name)
{
  int i = au_find_group(name);
  if (i == AUGROUP_ERROR) {     // the group doesn't exist yet, add it.
    // First try using a free entry.
    for (i = 0; i < augroups.ga_len; i++) {
      if (AUGROUP_NAME(i) == NULL) {
        break;
      }
    }
    if (i == augroups.ga_len) {
      ga_grow(&augroups, 1);
    }

    AUGROUP_NAME(i) = xstrdup((char *)name);
    if (i == augroups.ga_len) {
      augroups.ga_len++;
    }
  }

  return i;
}

static void au_del_group(char_u *name)
{
  int i = au_find_group(name);
  if (i == AUGROUP_ERROR) {      // the group doesn't exist
    EMSG2(_("E367: No such group: \"%s\""), name);
  } else if (i == current_augroup) {
    EMSG(_("E936: Cannot delete the current group"));
  } else {
    event_T event;
    AutoPat *ap;
    int in_use = false;

    for (event = (event_T)0; (int)event < (int)NUM_EVENTS;
         event = (event_T)((int)event + 1)) {
      for (ap = first_autopat[(int)event]; ap != NULL; ap = ap->next) {
        if (ap->group == i && ap->pat != NULL) {
          give_warning((char_u *)
                       _("W19: Deleting augroup that is still in use"), true);
          in_use = true;
          event = NUM_EVENTS;
          break;
        }
      }
    }
    xfree(AUGROUP_NAME(i));
    if (in_use) {
      AUGROUP_NAME(i) = (char *)get_deleted_augroup();
    } else {
      AUGROUP_NAME(i) = NULL;
    }
  }
}

/// Find the ID of an autocmd group name.
///
/// @param name augroup name
///
/// @return the ID or AUGROUP_ERROR (< 0) for error.
static int au_find_group(const char_u *name)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  for (int i = 0; i < augroups.ga_len; i++) {
    if (AUGROUP_NAME(i) != NULL && AUGROUP_NAME(i) != get_deleted_augroup()
        && STRCMP(AUGROUP_NAME(i), name) == 0) {
      return i;
    }
  }
  return AUGROUP_ERROR;
}

/// Return true if augroup "name" exists.
///
/// @param name augroup name
bool au_has_group(const char_u *name)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return au_find_group(name) != AUGROUP_ERROR;
}

/// ":augroup {name}".
void do_augroup(char_u *arg, int del_group)
{
  if (del_group) {
    if (*arg == NUL) {
      EMSG(_(e_argreq));
    } else {
      au_del_group(arg);
    }
  } else if (STRICMP(arg, "end") == 0) {  // ":aug end": back to group 0
    current_augroup = AUGROUP_DEFAULT;
  } else if (*arg) {  // ":aug xxx": switch to group xxx
    int i = au_new_group(arg);
    if (i != AUGROUP_ERROR)
      current_augroup = i;
  } else {  // ":aug": list the group names
    msg_start();
    for (int i = 0; i < augroups.ga_len; ++i) {
      if (AUGROUP_NAME(i) != NULL) {
        msg_puts(AUGROUP_NAME(i));
        msg_puts("  ");
      }
    }
    msg_clr_eos();
    msg_end();
  }
}

#if defined(EXITFREE)
void free_all_autocmds(void)
{
  for (current_augroup = -1; current_augroup < augroups.ga_len;
       current_augroup++) {
    do_autocmd((char_u *)"", true);
  }

  for (int i = 0; i < augroups.ga_len; i++) {
    char *const s = ((char **)(augroups.ga_data))[i];
    if ((const char *)s != get_deleted_augroup()) {
      xfree(s);
    }
  }
  ga_clear(&augroups);
}
#endif

/*
 * Return the event number for event name "start".
 * Return NUM_EVENTS if the event name was not found.
 * Return a pointer to the next event name in "end".
 */
static event_T event_name2nr(const char_u *start, char_u **end)
{
  const char_u *p;
  int i;
  int len;

  // the event name ends with end of line, '|', a blank or a comma
  for (p = start; *p && !ascii_iswhite(*p) && *p != ',' && *p != '|'; p++) {
  }
  for (i = 0; event_names[i].name != NULL; i++) {
    len = (int)event_names[i].len;
    if (len == p - start && STRNICMP(event_names[i].name, start, len) == 0) {
      break;
    }
  }
  if (*p == ',') {
    p++;
  }
  *end = (char_u *)p;
  if (event_names[i].name == NULL) {
    return NUM_EVENTS;
  }
  return event_names[i].event;
}

/// Return the name for event
///
/// @param[in]  event  Event to return name for.
///
/// @return Event name, static string. Returns "Unknown" for unknown events.
static const char *event_nr2name(event_T event)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_CONST
{
  int i;

  for (i = 0; event_names[i].name != NULL; i++) {
    if (event_names[i].event == event) {
      return event_names[i].name;
    }
  }
  return "Unknown";
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
    if (arg[1] && !ascii_iswhite(arg[1])) {
      EMSG2(_("E215: Illegal character after *: %s"), arg);
      return NULL;
    }
    pat = arg + 1;
  } else {
    for (pat = arg; *pat && *pat != '|' && !ascii_iswhite(*pat); pat = p) {
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

/// Return true if "event" is included in 'eventignore'.
///
/// @param event event to check
static bool event_ignored(event_T event)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  char_u *p = p_ei;

  while (*p != NUL) {
    if (STRNICMP(p, "all", 3) == 0 && (p[3] == NUL || p[3] == ',')) {
      return true;
    }
    if (event_name2nr(p, &p) == event) {
      return true;
    }
  }

  return false;
}

/*
 * Return OK when the contents of p_ei is valid, FAIL otherwise.
 */
int check_ei(void)
{
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
  new_ei = vim_strnsave(p_ei, (int)(STRLEN(p_ei) + STRLEN(what)));
  if (*what == ',' && *p_ei == NUL)
    STRCPY(new_ei, what + 1);
  else
    STRCAT(new_ei, what);
  set_string_option_direct((char_u *)"ei", -1, new_ei, OPT_FREE, SID_NONE);
  xfree(new_ei);

  return save_ei;
}

void au_event_restore(char_u *old_ei)
{
  if (old_ei != NULL) {
    set_string_option_direct((char_u *)"ei", -1, old_ei,
        OPT_FREE, SID_NONE);
    xfree(old_ei);
  }
}

// Implements :autocmd.
// Defines an autocmd (does not execute; cf. apply_autocmds_group).
//
// Can be used in the following ways:
//
// :autocmd <event> <pat> <cmd>     Add <cmd> to the list of commands that
//                                  will be automatically executed for <event>
//                                  when editing a file matching <pat>, in
//                                  the current group.
// :autocmd <event> <pat>           Show the autocommands associated with
//                                  <event> and <pat>.
// :autocmd <event>                 Show the autocommands associated with
//                                  <event>.
// :autocmd                         Show all autocommands.
// :autocmd! <event> <pat> <cmd>    Remove all autocommands associated with
//                                  <event> and <pat>, and add the command
//                                  <cmd>, for the current group.
// :autocmd! <event> <pat>          Remove all autocommands associated with
//                                  <event> and <pat> for the current group.
// :autocmd! <event>                Remove all autocommands associated with
//                                  <event> for the current group.
// :autocmd!                        Remove ALL autocommands for the current
//                                  group.
//
//  Multiple events and patterns may be given separated by commas.  Here are
//  some examples:
// :autocmd bufread,bufenter *.c,*.h    set tw=0 smartindent noic
// :autocmd bufleave         *          set tw=79 nosmartindent ic infercase
//
// :autocmd * *.c               show all autocommands for *.c files.
//
// Mostly a {group} argument can optionally appear before <event>.
void do_autocmd(char_u *arg_in, int forceit)
{
  char_u      *arg = arg_in;
  char_u      *pat;
  char_u      *envpat = NULL;
  char_u      *cmd;
  int need_free = false;
  int nested = false;
  bool once = false;
  int group;

  if (*arg == '|') {
    arg = (char_u *)"";
    group = AUGROUP_ALL;  // no argument, use all groups
  } else {
    // Check for a legal group name.  If not, use AUGROUP_ALL.
    group = au_get_grouparg(&arg);
  }

  /*
   * Scan over the events.
   * If we find an illegal name, return here, don't do anything.
   */
  pat = find_end_event(arg, group != AUGROUP_ALL);
  if (pat == NULL)
    return;

  pat = skipwhite(pat);
  if (*pat == '|') {
    pat = (char_u *)"";
    cmd = (char_u *)"";
  } else {
    // Scan over the pattern.  Put a NUL at the end.
    cmd = pat;
    while (*cmd && (!ascii_iswhite(*cmd) || cmd[-1] == '\\')) {
        cmd++;
    }
    if (*cmd) {
      *cmd++ = NUL;
    }

    // Expand environment variables in the pattern.  Set 'shellslash', we want
    // forward slashes here.
    if (vim_strchr(pat, '$') != NULL || vim_strchr(pat, '~') != NULL) {
#ifdef BACKSLASH_IN_FILENAME
      int p_ssl_save = p_ssl;

      p_ssl = true;
#endif
      envpat = expand_env_save(pat);
#ifdef BACKSLASH_IN_FILENAME
      p_ssl = p_ssl_save;
#endif
      if (envpat != NULL) {
        pat = envpat;
      }
    }

    cmd = skipwhite(cmd);
    for (size_t i = 0; i < 2; i++) {
      if (*cmd != NUL) {
        // Check for "++once" flag.
        if (STRNCMP(cmd, "++once", 6) == 0 && ascii_iswhite(cmd[6])) {
          if (once) {
            EMSG2(_(e_duparg2), "++once");
          }
          once = true;
          cmd = skipwhite(cmd + 6);
        }

        // Check for "++nested" flag.
        if ((STRNCMP(cmd, "++nested", 8) == 0 && ascii_iswhite(cmd[8]))) {
          if (nested) {
            EMSG2(_(e_duparg2), "++nested");
          }
          nested = true;
          cmd = skipwhite(cmd + 8);
        }

        // Check for the old (deprecated) "nested" flag.
        if (STRNCMP(cmd, "nested", 6) == 0 && ascii_iswhite(cmd[6])) {
          if (nested) {
            EMSG2(_(e_duparg2), "nested");
          }
          nested = true;
          cmd = skipwhite(cmd + 6);
        }
      }
    }

    // Find the start of the commands.
    // Expand <sfile> in it.
    if (*cmd != NUL) {
      cmd = expand_sfile(cmd);
      if (cmd == NULL) {                // some error
        return;
      }
      need_free = true;
    }
  }

  /*
   * Print header when showing autocommands.
   */
  if (!forceit && *cmd == NUL) {
    // Highlight title
    MSG_PUTS_TITLE(_("\n--- Autocommands ---"));
  }

  /*
   * Loop over the events.
   */
  last_event = (event_T)-1;             // for listing the event name
  last_group = AUGROUP_ERROR;           // for listing the group name
  if (*arg == '*' || *arg == NUL || *arg == '|') {
    for (event_T event = (event_T)0; (int)event < (int)NUM_EVENTS;
         event = (event_T)((int)event + 1)) {
      if (do_autocmd_event(event, pat, once, nested, cmd, forceit, group)
          == FAIL) {
        break;
      }
    }
  } else {
    while (*arg && *arg != '|' && !ascii_iswhite(*arg)) {
      event_T event = event_name2nr(arg, &arg);
      assert(event < NUM_EVENTS);
      if (do_autocmd_event(event, pat, once, nested, cmd, forceit, group)
          == FAIL) {
        break;
      }
    }
  }

  if (need_free)
    xfree(cmd);
  xfree(envpat);
}

/*
 * Find the group ID in a ":autocmd" or ":doautocmd" argument.
 * The "argp" argument is advanced to the following argument.
 *
 * Returns the group ID or AUGROUP_ALL.
 */
static int au_get_grouparg(char_u **argp)
{
  char_u      *group_name;
  char_u      *p;
  char_u      *arg = *argp;
  int group = AUGROUP_ALL;

  for (p = arg; *p && !ascii_iswhite(*p) && *p != '|'; p++) {
  }
  if (p > arg) {
    group_name = vim_strnsave(arg, (int)(p - arg));
    group = au_find_group(group_name);
    if (group == AUGROUP_ERROR)
      group = AUGROUP_ALL;              /* no match, use all groups */
    else
      *argp = skipwhite(p);             /* match, skip over group name */
    xfree(group_name);
  }
  return group;
}

// do_autocmd() for one event.
// Defines an autocmd (does not execute; cf. apply_autocmds_group).
//
// If *pat == NUL: do for all patterns.
// If *cmd == NUL: show entries.
// If forceit == TRUE: delete entries.
// If group is not AUGROUP_ALL: only use this group.
static int do_autocmd_event(event_T event, char_u *pat, bool once, int nested,
                            char_u *cmd, int forceit, int group)
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
    endpat = pat;
    // ignore single comma
    if (*endpat == ',') {
      continue;
    }
    brace_level = 0;
    for (; *endpat && (*endpat != ',' || brace_level || endpat[-1] == '\\');
         ++endpat) {
      if (*endpat == '{')
        brace_level++;
      else if (*endpat == '}')
        brace_level--;
    }
    patlen = (int)(endpat - pat);

    /*
     * detect special <buflocal[=X]> buffer-local patterns
     */
    is_buflocal = FALSE;
    buflocal_nr = 0;

    if (patlen >= 8 && STRNCMP(pat, "<buffer", 7) == 0
        && pat[patlen - 1] == '>') {
      /* "<buffer...>": Error will be printed only for addition.
       * printing and removing will proceed silently. */
      is_buflocal = TRUE;
      if (patlen == 8)
        /* "<buffer>" */
        buflocal_nr = curbuf->b_fnum;
      else if (patlen > 9 && pat[7] == '=') {
        if (patlen == 13 && STRNICMP(pat, "<buffer=abuf>", 13) == 0)
          /* "<buffer=abuf>" */
          buflocal_nr = autocmd_bufnr;
        else if (skipdigits(pat + 8) == pat + patlen - 1)
          /* "<buffer=123>" */
          buflocal_nr = atoi((char *)pat + 8);
      }
    }

    if (is_buflocal) {
      /* normalize pat into standard "<buffer>#N" form */
      sprintf((char *)buflocal_pat, "<buffer=%d>", buflocal_nr);
      pat = buflocal_pat;                       /* can modify pat and patlen */
      patlen = (int)STRLEN(buflocal_pat);       /*   but not endpat */
    }

    // Find AutoPat entries with this pattern.  When adding a command it
    // always goes at or after the last one, so start at the end.
    if (!forceit && *cmd != NUL && last_autopat[(int)event] != NULL) {
      prev_ap = &last_autopat[(int)event];
    } else {
      prev_ap = &first_autopat[(int)event];
    }
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
          emsgf(_("E680: <buffer=%d>: invalid buffer number "),
                buflocal_nr);
          return FAIL;
        }

        ap = xmalloc(sizeof(AutoPat));
        ap->pat = vim_strnsave(pat, patlen);
        ap->patlen = patlen;

        if (is_buflocal) {
          ap->buflocal_nr = buflocal_nr;
          ap->reg_prog = NULL;
        } else {
          char_u      *reg_pat;

          ap->buflocal_nr = 0;
          reg_pat = file_pat_to_reg_pat(pat, endpat,
              &ap->allow_dirs, TRUE);
          if (reg_pat != NULL)
            ap->reg_prog = vim_regcomp(reg_pat, RE_MAGIC);
          xfree(reg_pat);
          if (reg_pat == NULL || ap->reg_prog == NULL) {
            xfree(ap->pat);
            xfree(ap);
            return FAIL;
          }
        }
        ap->cmds = NULL;
        *prev_ap = ap;
        last_autopat[(int)event] = ap;
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
      ac = xmalloc(sizeof(AutoCmd));
      ac->cmd = vim_strsave(cmd);
      ac->script_ctx = current_sctx;
      ac->script_ctx.sc_lnum += sourcing_lnum;
      ac->next = NULL;
      *prev_ac = ac;
      ac->once = once;
      ac->nested = nested;
    }
  }

  au_cleanup();         /* may really delete removed patterns/commands now */
  return OK;
}

// Implementation of ":doautocmd [group] event [fname]".
// Return OK for success, FAIL for failure;
int
do_doautocmd(
    char_u *arg,
    int do_msg,  // give message for no matching autocmds?
    bool *did_something
)
{
  char_u      *fname;
  int nothing_done = TRUE;
  int group;

  if (did_something != NULL) {
    *did_something = false;
  }

  /*
   * Check for a legal group name.  If not, use AUGROUP_ALL.
   */
  group = au_get_grouparg(&arg);

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

  // Loop over the events.
  while (*arg && !ends_excmd(*arg) && !ascii_iswhite(*arg)) {
    if (apply_autocmds_group(event_name2nr(arg, &arg), fname, NULL, true,
                             group, curbuf, NULL)) {
      nothing_done = false;
    }
  }

  if (nothing_done && do_msg) {
    MSG(_("No matching autocommands"));
  }
  if (did_something != NULL) {
    *did_something = !nothing_done;
  }

  return aborting() ? FAIL : OK;
}

/*
 * ":doautoall": execute autocommands for each loaded buffer.
 */
void ex_doautoall(exarg_T *eap)
{
  int retval;
  aco_save_T aco;
  char_u      *arg = eap->arg;
  int call_do_modelines = check_nomodeline(&arg);
  bufref_T bufref;

  /*
   * This is a bit tricky: For some commands curwin->w_buffer needs to be
   * equal to curbuf, but for some buffers there may not be a window.
   * So we change the buffer for the current window for a moment.  This
   * gives problems when the autocommands make changes to the list of
   * buffers or windows...
   */
  FOR_ALL_BUFFERS(buf) {
    if (buf->b_ml.ml_mfp == NULL) {
      continue;
    }
    // Find a window for this buffer and save some values.
    aucmd_prepbuf(&aco, buf);
    set_bufref(&bufref, buf);

    bool did_aucmd;
    // execute the autocommands for this buffer
    retval = do_doautocmd(arg, false, &did_aucmd);

    if (call_do_modelines && did_aucmd) {
      // Execute the modeline settings, but don't set window-local
      // options if we are using the current window for another
      // buffer.
      do_modelines(curwin == aucmd_win ? OPT_NOWIN : 0);
    }

    /* restore the current window */
    aucmd_restbuf(&aco);

    // Stop if there is some error or buffer was deleted.
    if (retval == FAIL || !bufref_valid(&bufref)) {
      break;
    }
  }

  check_cursor();           /* just in case lines got deleted */
}

/// Check *argp for <nomodeline>.  When it is present return false, otherwise
/// return true and advance *argp to after it. Thus do_modelines() should be
/// called when true is returned.
///
/// @param[in,out] argp argument string
bool check_nomodeline(char_u **argp)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (STRNCMP(*argp, "<nomodeline>", 12) == 0) {
    *argp = skipwhite(*argp + 12);
    return false;
  }
  return true;
}

/// Prepare for executing autocommands for (hidden) buffer `buf`.
/// If the current buffer is not in any visible window, put it in a temporary
/// floating window `aucmd_win`.
/// Set `curbuf` and `curwin` to match `buf`.
///
/// @param aco  structure to save values in
/// @param buf  new curbuf
void aucmd_prepbuf(aco_save_T *aco, buf_T *buf)
{
  win_T *win;
  bool need_append = true;  // Append `aucmd_win` to the window list.

  /* Find a window that is for the new buffer */
  if (buf == curbuf) {          /* be quick when buf is curbuf */
    win = curwin;
  } else {
    win = NULL;
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      if (wp->w_buffer == buf) {
        win = wp;
        break;
      }
    }
  }

  // Allocate the `aucmd_win` dummy floating window.
  if (win == NULL && aucmd_win == NULL) {
    win_alloc_aucmd_win();
    need_append = false;
  }
  if (win == NULL && aucmd_win_used)
    /* Strange recursive autocommand, fall back to using the current
     * window.  Expect a few side effects... */
    win = curwin;

  aco->save_curwin = curwin;
  aco->save_prevwin = prevwin;
  aco->save_curbuf = curbuf;
  if (win != NULL) {
    /* There is a window for "buf" in the current tab page, make it the
     * curwin.  This is preferred, it has the least side effects (esp. if
     * "buf" is curbuf). */
    aco->use_aucmd_win = FALSE;
    curwin = win;
  } else {
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
    XFREE_CLEAR(aucmd_win->w_localdir);
    aco->globaldir = globaldir;
    globaldir = NULL;

    block_autocmds();  // We don't want BufEnter/WinEnter autocommands.
    if (need_append) {
      win_append(lastwin, aucmd_win);
      handle_register_window(aucmd_win);
      win_config_float(aucmd_win, aucmd_win->w_float_config);
    }
    // Prevent chdir() call in win_enter_ext(), through do_autochdir()
    int save_acd = p_acd;
    p_acd = false;
    win_enter(aucmd_win, false);
    p_acd = save_acd;
    unblock_autocmds();
    curwin = aucmd_win;
  }
  curbuf = buf;
  aco->new_curwin = curwin;
  set_bufref(&aco->new_curbuf, curbuf);
}

/// Cleanup after executing autocommands for a (hidden) buffer.
/// Restore the window as it was (if possible).
///
/// @param aco  structure holding saved values
void aucmd_restbuf(aco_save_T *aco)
{
  if (aco->use_aucmd_win) {
    curbuf->b_nwindows--;
    // Find "aucmd_win", it can't be closed, but it may be in another tab page.
    // Do not trigger autocommands here.
    block_autocmds();
    if (curwin != aucmd_win) {
      FOR_ALL_TAB_WINDOWS(tp, wp) {
        if (wp == aucmd_win) {
          if (tp != curtab) {
            goto_tabpage_tp(tp, true, true);
          }
          win_goto(aucmd_win);
          goto win_found;
        }
      }
    }
win_found:

    win_remove(curwin, NULL);
    handle_unregister_window(curwin);
    if (curwin->w_grid.chars != NULL) {
      ui_comp_remove_grid(&curwin->w_grid);
      ui_call_win_hide(curwin->w_grid.handle);
      grid_free(&curwin->w_grid);
    }

    aucmd_win_used = false;
    last_status(false);         // may need to remove last status line

    if (!valid_tabpage_win(curtab)) {
      // no valid window in current tabpage
      close_tabpage(curtab);
    }

    unblock_autocmds();

    if (win_valid(aco->save_curwin)) {
      curwin = aco->save_curwin;
    } else {
      // Hmm, original window disappeared.  Just use the first one.
      curwin = firstwin;
    }
    prevwin = win_valid(aco->save_prevwin) ? aco->save_prevwin
              : firstwin;  // window disappeared?
    vars_clear(&aucmd_win->w_vars->dv_hashtab);      // free all w: variables
    hash_init(&aucmd_win->w_vars->dv_hashtab);       // re-use the hashtab
    curbuf = curwin->w_buffer;

    xfree(globaldir);
    globaldir = aco->globaldir;

    // the buffer contents may have changed
    check_cursor();
    if (curwin->w_topline > curbuf->b_ml.ml_line_count) {
      curwin->w_topline = curbuf->b_ml.ml_line_count;
      curwin->w_topfill = 0;
    }
  } else {
    // restore curwin
    if (win_valid(aco->save_curwin)) {
      // Restore the buffer which was previously edited by curwin, if it was
      // changed, we are still the same window and the buffer is valid.
      if (curwin == aco->new_curwin
          && curbuf != aco->new_curbuf.br_buf
          && bufref_valid(&aco->new_curbuf)
          && aco->new_curbuf.br_buf->b_ml.ml_mfp != NULL) {
        if (curwin->w_s == &curbuf->b_s) {
          curwin->w_s = &aco->new_curbuf.br_buf->b_s;
        }
        curbuf->b_nwindows--;
        curbuf = aco->new_curbuf.br_buf;
        curwin->w_buffer = curbuf;
        curbuf->b_nwindows++;
      }

      curwin = aco->save_curwin;
      prevwin = win_valid(aco->save_prevwin) ? aco->save_prevwin
                : firstwin;  // window disappeared?
      curbuf = curwin->w_buffer;
      // In case the autocommand moves the cursor to a position that does not
      // exist in curbuf
      check_cursor();
    }
  }
}

static int autocmd_nested = FALSE;

/// Execute autocommands for "event" and file name "fname".
///
/// @param event event that occured
/// @param fname filename, NULL or empty means use actual file name
/// @param fname_io filename to use for <afile> on cmdline
/// @param force When true, ignore autocmd_busy
/// @param buf Buffer for <abuf>
///
/// @return true if some commands were executed.
bool apply_autocmds(event_T event, char_u *fname, char_u *fname_io, bool force,
                    buf_T *buf)
{
  return apply_autocmds_group(event, fname, fname_io, force,
      AUGROUP_ALL, buf, NULL);
}

/// Like apply_autocmds(), but with extra "eap" argument.  This takes care of
/// setting v:filearg.
///
/// @param event event that occured
/// @param fname NULL or empty means use actual file name
/// @param fname_io fname to use for <afile> on cmdline
/// @param force When true, ignore autocmd_busy
/// @param buf Buffer for <abuf>
/// @param exarg Ex command arguments
///
/// @return true if some commands were executed.
static bool apply_autocmds_exarg(event_T event, char_u *fname, char_u *fname_io,
                                 bool force, buf_T *buf, exarg_T *eap)
{
  return apply_autocmds_group(event, fname, fname_io, force,
      AUGROUP_ALL, buf, eap);
}

/// Like apply_autocmds(), but handles the caller's retval.  If the script
/// processing is being aborted or if retval is FAIL when inside a try
/// conditional, no autocommands are executed.  If otherwise the autocommands
/// cause the script to be aborted, retval is set to FAIL.
///
/// @param event event that occured
/// @param fname NULL or empty means use actual file name
/// @param fname_io fname to use for <afile> on cmdline
/// @param force When true, ignore autocmd_busy
/// @param buf Buffer for <abuf>
/// @param[in,out] retval caller's retval
///
/// @return true if some autocommands were executed
bool apply_autocmds_retval(event_T event, char_u *fname, char_u *fname_io,
                           bool force, buf_T *buf, int *retval)
{
  if (should_abort(*retval)) {
    return false;
  }

  bool did_cmd = apply_autocmds_group(event, fname, fname_io, force,
                                      AUGROUP_ALL, buf, NULL);
  if (did_cmd && aborting()) {
    *retval = FAIL;
  }
  return did_cmd;
}

/// Return true when there is a CursorHold/CursorHoldI autocommand defined for
/// the current mode.
bool has_cursorhold(void) FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return first_autopat[(int)(get_real_state() == NORMAL_BUSY
                             ? EVENT_CURSORHOLD : EVENT_CURSORHOLDI)] != NULL;
}

/// Return true if the CursorHold/CursorHoldI event can be triggered.
bool trigger_cursorhold(void) FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  int state;

  if (!did_cursorhold
      && has_cursorhold()
      && reg_recording == 0
      && typebuf.tb_len == 0
      && !ins_compl_active()
      ) {
    state = get_real_state();
    if (state == NORMAL_BUSY || (state & INSERT) != 0) {
      return true;
    }
  }
  return false;
}

/// Return true if "event" autocommand is defined.
///
/// @param event the autocommand to check
bool has_event(event_T event) FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return first_autopat[event] != NULL;
}

/// Execute autocommands for "event" and file name "fname".
///
/// @param event event that occured
/// @param fname filename, NULL or empty means use actual file name
/// @param fname_io filename to use for <afile> on cmdline,
///                 NULL means use `fname`.
/// @param force When true, ignore autocmd_busy
/// @param group autocmd group ID or AUGROUP_ALL
/// @param buf Buffer for <abuf>
/// @param eap Ex command arguments
///
/// @return true if some commands were executed.
static bool apply_autocmds_group(event_T event, char_u *fname, char_u *fname_io,
                                 bool force, int group, buf_T *buf,
                                 exarg_T *eap)
{
  char_u      *sfname = NULL;   /* short file name */
  char_u      *tail;
  bool save_changed;
  buf_T       *old_curbuf;
  bool retval = false;
  char_u      *save_sourcing_name;
  linenr_T save_sourcing_lnum;
  char_u      *save_autocmd_fname;
  int save_autocmd_bufnr;
  char_u      *save_autocmd_match;
  int save_autocmd_busy;
  int save_autocmd_nested;
  static int nesting = 0;
  AutoPatCmd patcmd;
  AutoPat     *ap;
  void        *save_funccalp;
  char_u      *save_cmdarg;
  long save_cmdbang;
  static int filechangeshell_busy = FALSE;
  proftime_T wait_time;
  bool did_save_redobuff = false;
  save_redo_T save_redo;
  const bool save_KeyTyped = KeyTyped;

  // Quickly return if there are no autocommands for this event or
  // autocommands are blocked.
  if (event == NUM_EVENTS || first_autopat[(int)event] == NULL
      || autocmd_blocked > 0) {
    goto BYPASS_AU;
  }

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
    if (event == EVENT_COLORSCHEME
        || event == EVENT_COLORSCHEMEPRE
        || event == EVENT_OPTIONSET) {
      autocmd_fname = NULL;
    } else if (fname != NULL && !ends_excmd(*fname)) {
      autocmd_fname = fname;
    } else if (buf != NULL) {
      autocmd_fname = buf->b_ffname;
    } else {
      autocmd_fname = NULL;
    }
  } else {
    autocmd_fname = fname_io;
  }
  if (autocmd_fname != NULL) {
    // Allocate MAXPATHL for when eval_vars() resolves the fullpath.
    autocmd_fname = vim_strnsave(autocmd_fname, MAXPATHL);
  }

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
  } else {
    sfname = vim_strsave(fname);
    // Don't try expanding the following events.
    if (event == EVENT_CMDLINECHANGED
        || event == EVENT_CMDLINEENTER
        || event == EVENT_CMDLINELEAVE
        || event == EVENT_CMDWINENTER
        || event == EVENT_CMDWINLEAVE
        || event == EVENT_CMDUNDEFINED
        || event == EVENT_COLORSCHEME
        || event == EVENT_COLORSCHEMEPRE
        || event == EVENT_DIRCHANGED
        || event == EVENT_FILETYPE
        || event == EVENT_FUNCUNDEFINED
        || event == EVENT_OPTIONSET
        || event == EVENT_QUICKFIXCMDPOST
        || event == EVENT_QUICKFIXCMDPRE
        || event == EVENT_REMOTEREPLY
        || event == EVENT_SPELLFILEMISSING
        || event == EVENT_SYNTAX
        || event == EVENT_SIGNAL
        || event == EVENT_TABCLOSED) {
      fname = vim_strsave(fname);
    } else {
      fname = (char_u *)FullName_save((char *)fname, false);
    }
  }
  if (fname == NULL) {      /* out of memory */
    xfree(sfname);
    retval = false;
    goto BYPASS_AU;
  }

#ifdef BACKSLASH_IN_FILENAME
  // Replace all backslashes with forward slashes. This makes the
  // autocommand patterns portable between Unix and Windows.
  if (sfname != NULL) {
    forward_slash(sfname);
  }
  forward_slash(fname);
#endif


  /*
   * Set the name to be used for <amatch>.
   */
  autocmd_match = fname;


  // Don't redraw while doing autocommands.
  RedrawingDisabled++;
  save_sourcing_name = sourcing_name;
  sourcing_name = NULL;         /* don't free this one */
  save_sourcing_lnum = sourcing_lnum;
  sourcing_lnum = 0;            /* no line number here */

  const sctx_T save_current_sctx = current_sctx;

  if (do_profiling == PROF_YES)
    prof_child_enter(&wait_time);     /* doesn't count for the caller itself */

  /* Don't use local function variables, if called from a function */
  save_funccalp = save_funccal();

  /*
   * When starting to execute autocommands, save the search patterns.
   */
  if (!autocmd_busy) {
    save_search_patterns();
    if (!ins_compl_active()) {
      saveRedobuff(&save_redo);
      did_save_redobuff = true;
    }
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

  tail = path_tail(fname);

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
  auto_next_pat(&patcmd, false);

  /* found one, start executing the autocommands */
  if (patcmd.curpat != NULL) {
    /* add to active_apc_list */
    patcmd.next = active_apc_list;
    active_apc_list = &patcmd;

    // set v:cmdarg (only when there is a matching pattern)
    save_cmdbang = (long)get_vim_var_nr(VV_CMDBANG);
    if (eap != NULL) {
      save_cmdarg = set_cmdarg(eap, NULL);
      set_vim_var_nr(VV_CMDBANG, (long)eap->forceit);
    } else {
      save_cmdarg = NULL;  // avoid gcc warning
    }
    retval = true;
    // mark the last pattern, to avoid an endless loop when more patterns
    // are added when executing autocommands
    for (ap = patcmd.curpat; ap->next != NULL; ap = ap->next) {
      ap->last = false;
    }
    ap->last = true;
    check_lnums(true);  // make sure cursor and topline are valid

    // Execute the autocmd. The `getnextac` callback handles iteration.
    do_cmdline(NULL, getnextac, (void *)&patcmd,
               DOCMD_NOWAIT|DOCMD_VERBOSE|DOCMD_REPEAT);

    reset_lnums();  // restore cursor and topline, unless they were changed

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
  xfree(sourcing_name);
  sourcing_name = save_sourcing_name;
  sourcing_lnum = save_sourcing_lnum;
  xfree(autocmd_fname);
  autocmd_fname = save_autocmd_fname;
  autocmd_bufnr = save_autocmd_bufnr;
  autocmd_match = save_autocmd_match;
  current_sctx = save_current_sctx;
  restore_funccal(save_funccalp);
  if (do_profiling == PROF_YES)
    prof_child_exit(&wait_time);
  KeyTyped = save_KeyTyped;
  xfree(fname);
  xfree(sfname);
  --nesting;            /* see matching increment above */

  // When stopping to execute autocommands, restore the search patterns and
  // the redo buffer. Free any buffers in the au_pending_free_buf list and
  // free any windows in the au_pending_free_win list.
  if (!autocmd_busy) {
    restore_search_patterns();
    if (did_save_redobuff) {
      restoreRedobuff(&save_redo);
    }
    did_filetype = FALSE;
    while (au_pending_free_buf != NULL) {
      buf_T *b = au_pending_free_buf->b_next;
      xfree(au_pending_free_buf);
      au_pending_free_buf = b;
    }
    while (au_pending_free_win != NULL) {
      win_T *w = au_pending_free_win->w_next;
      xfree(au_pending_free_win);
      au_pending_free_win = w;
    }
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

  if (retval == OK && event == EVENT_FILETYPE) {
    au_did_filetype = true;
  }

  return retval;
}

static char_u   *old_termresponse = NULL;

/*
 * Block triggering autocommands until unblock_autocmd() is called.
 * Can be used recursively, so long as it's symmetric.
 */
void block_autocmds(void)
{
  /* Remember the value of v:termresponse. */
  if (autocmd_blocked == 0)
    old_termresponse = get_vim_var_str(VV_TERMRESPONSE);
  ++autocmd_blocked;
}

void unblock_autocmds(void)
{
  --autocmd_blocked;

  /* When v:termresponse was set while autocommands were blocked, trigger
   * the autocommands now.  Esp. useful when executing a shell command
   * during startup (nvim -d). */
  if (autocmd_blocked == 0
      && get_vim_var_str(VV_TERMRESPONSE) != old_termresponse)
    apply_autocmds(EVENT_TERMRESPONSE, NULL, NULL, FALSE, curbuf);
}

// Find next autocommand pattern that matches.
static void
auto_next_pat(
    AutoPatCmd *apc,
    int stop_at_last                   /* stop when 'last' flag is set */
)
{
  AutoPat     *ap;
  AutoCmd     *cp;
  char        *s;

  XFREE_CLEAR(sourcing_name);

  for (ap = apc->curpat; ap != NULL && !got_int; ap = ap->next) {
    apc->curpat = NULL;

    /* Only use a pattern when it has not been removed, has commands and
     * the group matches. For buffer-local autocommands only check the
     * buffer number. */
    if (ap->pat != NULL && ap->cmds != NULL
        && (apc->group == AUGROUP_ALL || apc->group == ap->group)) {
      /* execution-condition */
      if (ap->buflocal_nr == 0
          ? match_file_pat(NULL, &ap->reg_prog, apc->fname, apc->sfname,
                           apc->tail, ap->allow_dirs)
          : ap->buflocal_nr == apc->arg_bufnr) {
        const char *const name = event_nr2name(apc->event);
        s = _("%s Autocommands for \"%s\"");
        const size_t sourcing_name_len = (STRLEN(s) + strlen(name) + ap->patlen
                                          + 1);
        sourcing_name = xmalloc(sourcing_name_len);
        snprintf((char *)sourcing_name, sourcing_name_len, s, name,
                 (char *)ap->pat);
        if (p_verbose >= 8) {
          verbose_enter();
          smsg(_("Executing %s"), sourcing_name);
          verbose_leave();
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

/// Get next autocommand command.
/// Called by do_cmdline() to get the next line for ":if".
/// @return allocated string, or NULL for end of autocommands.
char_u *getnextac(int c, void *cookie, int indent, bool do_concat)
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
    smsg(_("autocommand %s"), ac->cmd);
    msg_puts("\n");  // don't overwrite this either
    verbose_leave_scroll();
  }
  retval = vim_strsave(ac->cmd);
  // Remove one-shot ("once") autocmd in anticipation of its execution.
  if (ac->once) {
    au_del_cmd(ac);
  }
  autocmd_nested = ac->nested;
  current_sctx = ac->script_ctx;
  if (ac->last) {
    acp->nextcmd = NULL;
  } else {
    acp->nextcmd = ac->next;
  }

  return retval;
}

/// Return true if there is a matching autocommand for "fname".
/// To account for buffer-local autocommands, function needs to know
/// in which buffer the file will be opened.
///
/// @param event event that occured.
/// @param sfname filename the event occured in.
/// @param buf buffer the file is open in
bool has_autocmd(event_T event, char_u *sfname, buf_T *buf)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  AutoPat     *ap;
  char_u      *fname;
  char_u      *tail = path_tail(sfname);
  bool retval = false;

  fname = (char_u *)FullName_save((char *)sfname, false);
  if (fname == NULL) {
    return false;
  }

#ifdef BACKSLASH_IN_FILENAME
  // Replace all backslashes with forward slashes. This makes the
  // autocommand patterns portable between Unix and Windows.
  sfname = vim_strsave(sfname);
  forward_slash(sfname);
  forward_slash(fname);
#endif

  for (ap = first_autopat[(int)event]; ap != NULL; ap = ap->next) {
    if (ap->pat != NULL && ap->cmds != NULL
        && (ap->buflocal_nr == 0
            ? match_file_pat(NULL, &ap->reg_prog, fname, sfname, tail,
                             ap->allow_dirs)
            : buf != NULL && ap->buflocal_nr == buf->b_fnum)) {
      retval = true;
      break;
    }
  }

  xfree(fname);
#ifdef BACKSLASH_IN_FILENAME
  xfree(sfname);
#endif

  return retval;
}

/*
 * Function given to ExpandGeneric() to obtain the list of autocommand group
 * names.
 */
char_u *get_augroup_name(expand_T *xp, int idx)
{
  if (idx == augroups.ga_len) {  // add "END" add the end
    return (char_u *)"END";
  }
  if (idx >= augroups.ga_len) {  // end of list
    return NULL;
  }
  if (AUGROUP_NAME(idx) == NULL || AUGROUP_NAME(idx) == get_deleted_augroup()) {
    // skip deleted entries
    return (char_u *)"";
  }
  return (char_u *)AUGROUP_NAME(idx);
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

  /* If there only is a group name that's what we expand. */
  if (*arg == NUL && group != AUGROUP_ALL && !ascii_iswhite(arg[-1])) {
    arg = p;
    group = AUGROUP_ALL;
  }

  /* skip over event name */
  for (p = arg; *p != NUL && !ascii_iswhite(*p); ++p)
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
  while (*arg && (!ascii_iswhite(*arg) || arg[-1] == '\\'))
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
  if (idx < augroups.ga_len) {          // First list group names, if wanted
    if (!include_groups || AUGROUP_NAME(idx) == NULL
        || AUGROUP_NAME(idx) == get_deleted_augroup()) {
      return (char_u *)"";              // skip deleted entries
    }
    return (char_u *)AUGROUP_NAME(idx);
  }
  return (char_u *)event_names[idx - augroups.ga_len].name;
}


/// Check whether given autocommand is supported
///
/// @param[in]  event  Event to check.
///
/// @return True if it is, false otherwise.
bool autocmd_supported(const char *const event)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  char_u *p;
  return event_name2nr((const char_u *)event, &p) != NUM_EVENTS;
}

/// Return true if an autocommand is defined for a group, event and
/// pattern:  The group can be omitted to accept any group.
/// `event` and `pattern` can be omitted to accept any event and pattern.
/// Buffer-local patterns <buffer> or <buffer=N> are accepted.
/// Used for:
///   exists("#Group") or
///   exists("#Group#Event") or
///   exists("#Group#Event#pat") or
///   exists("#Event") or
///   exists("#Event#pat")
///
/// @param arg autocommand string
bool au_exists(const char *const arg) FUNC_ATTR_WARN_UNUSED_RESULT
{
  event_T event;
  AutoPat     *ap;
  buf_T       *buflocal_buf = NULL;
  int group;
  bool retval = false;

  // Make a copy so that we can change the '#' chars to a NUL.
  char *const arg_save = xstrdup(arg);
  char *p = strchr(arg_save, '#');
  if (p != NULL) {
    *p++ = NUL;
  }

  // First, look for an autocmd group name.
  group = au_find_group((char_u *)arg_save);
  char *event_name;
  if (group == AUGROUP_ERROR) {
    /* Didn't match a group name, assume the first argument is an event. */
    group = AUGROUP_ALL;
    event_name = arg_save;
  } else {
    if (p == NULL) {
      // "Group": group name is present and it's recognized
      retval = true;
      goto theend;
    }

    // Must be "Group#Event" or "Group#Event#pat".
    event_name = p;
    p = strchr(event_name, '#');
    if (p != NULL) {
      *p++ = NUL;  // "Group#Event#pat"
    }
  }

  char *pattern = p;  // "pattern" is NULL when there is no pattern.

  // Find the index (enum) for the event name.
  event = event_name2nr((char_u *)event_name, (char_u **)&p);

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
                ? fnamecmp(ap->pat, (char_u *)pattern) == 0
                : ap->buflocal_nr == buflocal_buf->b_fnum))) {
      retval = true;
      break;
    }

theend:
  xfree(arg_save);
  return retval;
}

/// Tries matching a filename with a "pattern" ("prog" is NULL), or use the
/// precompiled regprog "prog" ("pattern" is NULL).  That avoids calling
/// vim_regcomp() often.
///
/// Used for autocommands and 'wildignore'.
///
/// @param pattern pattern to match with
/// @param prog pre-compiled regprog or NULL
/// @param fname full path of the file name
/// @param sfname short file name or NULL
/// @param tail tail of the path
/// @param allow_dirs Allow matching with dir
///
/// @return true if there is a match, false otherwise
static bool match_file_pat(char_u *pattern, regprog_T **prog, char_u *fname,
                           char_u *sfname, char_u *tail, int allow_dirs)
{
  regmatch_T regmatch;
  bool result = false;

  regmatch.rm_ic = p_fic;   /* ignore case if 'fileignorecase' is set */
  {
    if (prog != NULL)
      regmatch.regprog = *prog;
    else
      regmatch.regprog = vim_regcomp(pattern, RE_MAGIC);
  }

  /*
   * Try for a match with the pattern with:
   * 1. the full file name, when the pattern has a '/'.
   * 2. the short file name, when the pattern has a '/'.
   * 3. the tail of the file name, when the pattern has no '/'.
   */
  if (regmatch.regprog != NULL
      && ((allow_dirs
           && (vim_regexec(&regmatch, fname, (colnr_T)0)
               || (sfname != NULL
                   && vim_regexec(&regmatch, sfname, (colnr_T)0))))
          || (!allow_dirs && vim_regexec(&regmatch, tail, (colnr_T)0)))) {
    result = true;
  }

  if (prog != NULL) {
    *prog = regmatch.regprog;
  } else {
    vim_regfree(regmatch.regprog);
  }
  return result;
}

/// Check if a file matches with a pattern in "list".
/// "list" is a comma-separated list of patterns, like 'wildignore'.
/// "sfname" is the short file name or NULL, "ffname" the long file name.
///
/// @param list list of patterns to match
/// @param sfname short file name
/// @param ffname full file name
///
/// @return true if there was a match
bool match_file_list(char_u *list, char_u *sfname, char_u *ffname)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(1, 3)
{
  char_u buf[100];
  char_u      *tail;
  char_u      *regpat;
  char allow_dirs;
  bool match;
  char_u      *p;

  tail = path_tail(sfname);

  // try all patterns in 'wildignore'
  p = list;
  while (*p) {
    copy_option_part(&p, buf, ARRAY_SIZE(buf), ",");
    regpat = file_pat_to_reg_pat(buf, NULL, &allow_dirs, false);
    if (regpat == NULL) {
      break;
    }
    match = match_file_pat(regpat, NULL, ffname, sfname, tail, (int)allow_dirs);
    xfree(regpat);
    if (match) {
      return true;
    }
  }
  return false;
}

/// Convert the given pattern "pat" which has shell style wildcards in it, into
/// a regular expression, and return the result in allocated memory.  If there
/// is a directory path separator to be matched, then TRUE is put in
/// allow_dirs, otherwise FALSE is put there -- webb.
/// Handle backslashes before special characters, like "\*" and "\ ".
///
/// Returns NULL on failure.
char_u * file_pat_to_reg_pat(
    const char_u *pat,
    const char_u *pat_end,   // first char after pattern or NULL
    char *allow_dirs,        // Result passed back out in here
    int no_bslash            // Don't use a backward slash as pathsep
)
  FUNC_ATTR_NONNULL_ARG(1)
{
  const char_u *endp;
  char_u      *reg_pat;
  const char_u *p;
  int nested = 0;
  int add_dollar = TRUE;

  if (allow_dirs != NULL)
    *allow_dirs = FALSE;
  if (pat_end == NULL)
    pat_end = pat + STRLEN(pat);

  if (pat_end == pat) {
    return (char_u *)xstrdup("^$");
  }

  size_t size = 2;  // '^' at start, '$' at end.

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
      break;
    }
  }
  reg_pat = xmalloc(size + 1);

  size_t i = 0;

  if (pat[0] == '*')
    while (pat[0] == '*' && pat < pat_end - 1)
      pat++;
  else
    reg_pat[i++] = '^';
  endp = pat_end - 1;
  if (endp >= pat && *endp == '*') {
    while (endp - pat > 0 && *endp == '*') {
      endp--;
    }
    add_dollar = false;
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
          ) {
        reg_pat[i++] = '?';
      } else if (*p == ',' || *p == '%' || *p == '#'
                 || ascii_isspace(*p) || *p == '{' || *p == '}') {
        reg_pat[i++] = *p;
      } else if (*p == '\\' && p[1] == '\\' && p[2] == '{') {
        reg_pat[i++] = '\\';
        reg_pat[i++] = '{';
        p += 2;
      } else {
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
      if (allow_dirs != NULL && vim_ispathsep(*p)) {
        *allow_dirs = true;
      }
      reg_pat[i++] = *p;
      break;
    }
  }
  if (add_dollar)
    reg_pat[i++] = '$';
  reg_pat[i] = NUL;
  if (nested != 0) {
    if (nested < 0) {
      EMSG(_("E219: Missing {."));
    } else {
      EMSG(_("E220: Missing }."));
    }
    XFREE_CLEAR(reg_pat);
  }
  return reg_pat;
}

#if defined(EINTR)
/*
 * Version of read() that retries when interrupted by EINTR (possibly
 * by a SIGWINCH).
 */
long read_eintr(int fd, void *buf, size_t bufsize)
{
  long ret;

  for (;; ) {
    ret = read(fd, buf, bufsize);
    if (ret >= 0 || errno != EINTR)
      break;
  }
  return ret;
}

/*
 * Version of write() that retries when interrupted by EINTR (possibly
 * by a SIGWINCH).
 */
long write_eintr(int fd, void *buf, size_t bufsize)
{
  long ret = 0;
  long wlen;

  /* Repeat the write() so long it didn't fail, other than being interrupted
   * by a signal. */
  while (ret < (long)bufsize) {
    wlen = write(fd, (char *)buf + ret, bufsize - ret);
    if (wlen < 0) {
      if (errno != EINTR)
        break;
    } else
      ret += wlen;
  }
  return ret;
}
#endif
