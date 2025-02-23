// fileio.c: read from and write to a file

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <iconv.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <uv.h>

#include "auto/config.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/buffer_updates.h"
#include "nvim/change.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/drawscreen.h"
#include "nvim/edit.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_eval.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/highlight_defs.h"
#include "nvim/iconv_defs.h"
#include "nvim/log.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memfile.h"
#include "nvim/memfile_defs.h"
#include "nvim/memline.h"
#include "nvim/memline_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/os/fs.h"
#include "nvim/os/fs_defs.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/time.h"
#include "nvim/path.h"
#include "nvim/pos_defs.h"
#include "nvim/regexp.h"
#include "nvim/regexp_defs.h"
#include "nvim/sha256.h"
#include "nvim/shada.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/undo_defs.h"
#include "nvim/vim_defs.h"

#ifdef BACKSLASH_IN_FILENAME
# include "nvim/charset.h"
#endif

#ifdef HAVE_DIRFD_AND_FLOCK
# include <dirent.h>
# include <sys/file.h>
#endif

#ifdef OPEN_CHR_FILES
# include "nvim/charset.h"
#endif

// For compatibility with libuv < 1.20.0 (tested on 1.18.0)
#ifndef UV_FS_COPYFILE_FICLONE
# define UV_FS_COPYFILE_FICLONE 0
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "fileio.c.generated.h"
#endif

static const char *e_auchangedbuf = N_("E812: Autocommands changed buffer or buffer name");

void filemess(buf_T *buf, char *name, char *s)
{
  int prev_msg_col = msg_col;

  if (msg_silent != 0) {
    return;
  }

  add_quoted_fname(IObuff, IOSIZE - 100, buf, name);

  // Avoid an over-long translation to cause trouble.
  xstrlcat(IObuff, s, IOSIZE);

  // For the first message may have to start a new line.
  // For further ones overwrite the previous one, reset msg_scroll before
  // calling filemess().
  int msg_scroll_save = msg_scroll;
  if (shortmess(SHM_OVERALL) && !msg_listdo_overwrite && !exiting && p_verbose == 0) {
    msg_scroll = false;
  }
  if (!msg_scroll) {    // wait a bit when overwriting an error msg
    msg_check_for_delay(false);
  }
  msg_start();
  if (prev_msg_col != 0 && msg_col == 0) {
    msg_putchar('\r');  // overwrite any previous message.
  }
  msg_scroll = msg_scroll_save;
  msg_scrolled_ign = true;
  // may truncate the message to avoid a hit-return prompt
  msg_outtrans(msg_may_trunc(false, IObuff), 0, false);
  msg_clr_eos();
  ui_flush();
  msg_scrolled_ign = false;
}

/// Read lines from file "fname" into the buffer after line "from".
///
/// 1. We allocate blocks with try_malloc, as big as possible.
/// 2. Each block is filled with characters from the file with a single read().
/// 3. The lines are inserted in the buffer with ml_append().
///
/// (caller must check that fname != NULL, unless READ_STDIN is used)
///
/// "lines_to_skip" is the number of lines that must be skipped
/// "lines_to_read" is the number of lines that are appended
/// When not recovering lines_to_skip is 0 and lines_to_read MAXLNUM.
///
/// flags:
/// READ_NEW     starting to edit a new buffer
/// READ_FILTER  reading filter output
/// READ_STDIN   read from stdin instead of a file
/// READ_BUFFER  read from curbuf instead of a file (converting after reading
///              stdin)
/// READ_NOFILE  do not read a file, only trigger BufReadCmd
/// READ_DUMMY   read into a dummy buffer (to check if file contents changed)
/// READ_KEEP_UNDO  don't clear undo info or read it from a file
/// READ_FIFO    read from fifo/socket instead of a file
///
/// @param eap  can be NULL!
///
/// @return     FAIL for failure, NOTDONE for directory (failure), or OK
int readfile(char *fname, char *sfname, linenr_T from, linenr_T lines_to_skip,
             linenr_T lines_to_read, exarg_T *eap, int flags, bool silent)
{
  int retval = FAIL;  // jump to "theend" instead of returning
  int fd = stdin_fd >= 0 ? stdin_fd : 0;
  bool newfile = (flags & READ_NEW);
  bool filtering = (flags & READ_FILTER);
  bool read_stdin = (flags & READ_STDIN);
  bool read_buffer = (flags & READ_BUFFER);
  bool read_fifo = (flags & READ_FIFO);
  bool set_options = newfile || read_buffer || (eap != NULL && eap->read_edit);
  linenr_T read_buf_lnum = 1;           // next line to read from curbuf
  colnr_T read_buf_col = 0;             // next char to read from this line
  char c;
  linenr_T lnum = from;
  char *ptr = NULL;              // pointer into read buffer
  char *buffer = NULL;           // read buffer
  char *new_buffer = NULL;       // init to shut up gcc
  char *line_start = NULL;       // init to shut up gcc
  int wasempty;                         // buffer was empty before reading
  colnr_T len;
  ptrdiff_t size = 0;
  uint8_t *p = NULL;
  off_T filesize = 0;
  bool skip_read = false;
  context_sha256_T sha_ctx;
  bool read_undo_file = false;
  int split = 0;  // number of split lines
  linenr_T linecnt;
  bool error = false;                   // errors encountered
  int ff_error = EOL_UNKNOWN;           // file format with errors
  ptrdiff_t linerest = 0;               // remaining chars in line
  int perm = 0;
#ifdef UNIX
  int swap_mode = -1;                   // protection bits for swap file
#endif
  int fileformat = 0;                   // end-of-line format
  bool keep_fileformat = false;
  FileInfo file_info;
  linenr_T skip_count = 0;
  linenr_T read_count = 0;
  int msg_save = msg_scroll;
  linenr_T read_no_eol_lnum = 0;        // non-zero lnum when last line of
                                        // last read was missing the eol
  bool file_rewind = false;
  linenr_T conv_error = 0;              // line nr with conversion error
  linenr_T illegal_byte = 0;            // line nr with illegal byte
  bool keep_dest_enc = false;           // don't retry when char doesn't fit
                                        // in destination encoding
  int bad_char_behavior = BAD_REPLACE;
  // BAD_KEEP, BAD_DROP or character to
  // replace with
  char *tmpname = NULL;          // name of 'charconvert' output file
  int fio_flags = 0;
  char *fenc;                    // fileencoding to use
  bool fenc_alloced;                    // fenc_next is in allocated memory
  char *fenc_next = NULL;        // next item in 'fencs' or NULL
  bool advance_fenc = false;
  int real_size = 0;
  iconv_t iconv_fd = (iconv_t)-1;       // descriptor for iconv() or -1
  bool did_iconv = false;               // true when iconv() failed and trying
                                        // 'charconvert' next
  bool converted = false;                // true if conversion done
  bool notconverted = false;             // true if conversion wanted but it wasn't possible
  char conv_rest[CONV_RESTLEN];
  int conv_restlen = 0;                 // nr of bytes in conv_rest[]
  pos_T orig_start;
  buf_T *old_curbuf;
  char *old_b_ffname;
  char *old_b_fname;
  int using_b_ffname;
  int using_b_fname;
  static char *msg_is_a_directory = N_("is a directory");

  curbuf->b_au_did_filetype = false;  // reset before triggering any autocommands

  curbuf->b_no_eol_lnum = 0;    // in case it was set by the previous read

  // If there is no file name yet, use the one for the read file.
  // BF_NOTEDITED is set to reflect this.
  // Don't do this for a read from a filter.
  // Only do this when 'cpoptions' contains the 'f' flag.
  if (curbuf->b_ffname == NULL
      && !filtering
      && fname != NULL
      && vim_strchr(p_cpo, CPO_FNAMER) != NULL
      && !(flags & READ_DUMMY)) {
    if (set_rw_fname(fname, sfname) == FAIL) {
      goto theend;
    }
  }

  // Remember the initial values of curbuf, curbuf->b_ffname and
  // curbuf->b_fname to detect whether they are altered as a result of
  // executing nasty autocommands.  Also check if "fname" and "sfname"
  // point to one of these values.
  old_curbuf = curbuf;
  old_b_ffname = curbuf->b_ffname;
  old_b_fname = curbuf->b_fname;
  using_b_ffname = (fname == curbuf->b_ffname) || (sfname == curbuf->b_ffname);
  using_b_fname = (fname == curbuf->b_fname) || (sfname == curbuf->b_fname);

  // After reading a file the cursor line changes but we don't want to
  // display the line.
  ex_no_reprint = true;

  // don't display the file info for another buffer now
  need_fileinfo = false;

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

  // The BufReadCmd and FileReadCmd events intercept the reading process by
  // executing the associated commands instead.
  if (!filtering && !read_stdin && !read_buffer) {
    orig_start = curbuf->b_op_start;

    // Set '[ mark to the line above where the lines go (line 1 if zero).
    curbuf->b_op_start.lnum = ((from == 0) ? 1 : from);
    curbuf->b_op_start.col = 0;

    if (newfile) {
      if (apply_autocmds_exarg(EVENT_BUFREADCMD, NULL, sfname,
                               false, curbuf, eap)) {
        retval = OK;
        if (aborting()) {
          retval = FAIL;
        }

        // The BufReadCmd code usually uses ":read" to get the text and
        // perhaps ":file" to change the buffer name. But we should
        // consider this to work like ":edit", thus reset the
        // BF_NOTEDITED flag.  Then ":write" will work to overwrite the
        // same file.
        if (retval == OK) {
          curbuf->b_flags &= ~BF_NOTEDITED;
        }
        goto theend;
      }
    } else if (apply_autocmds_exarg(EVENT_FILEREADCMD, sfname, sfname,
                                    false, NULL, eap)) {
      retval = aborting() ? FAIL : OK;
      goto theend;
    }

    curbuf->b_op_start = orig_start;

    if (flags & READ_NOFILE) {
      // Return NOTDONE instead of FAIL so that BufEnter can be triggered
      // and other operations don't fail.
      retval = NOTDONE;
      goto theend;
    }
  }

  if (((shortmess(SHM_OVER) && !msg_listdo_overwrite) || curbuf->b_help) && p_verbose == 0) {
    msg_scroll = false;         // overwrite previous file message
  } else {
    msg_scroll = true;          // don't overwrite previous file message
  }
  // If the name is too long we might crash further on, quit here.
  if (fname != NULL && *fname != NUL) {
    size_t namelen = strlen(fname);

    // If the name is too long we might crash further on, quit here.
    if (namelen >= MAXPATHL) {
      filemess(curbuf, fname, _("Illegal file name"));
      msg_end();
      msg_scroll = msg_save;
      goto theend;
    }

    // If the name ends in a path separator, we can't open it.  Check here,
    // because reading the file may actually work, but then creating the
    // swap file may destroy it!  Reported on MS-DOS and Win 95.
    if (after_pathsep(fname, fname + namelen)) {
      if (!silent) {
        filemess(curbuf, fname, _(msg_is_a_directory));
      }
      msg_end();
      msg_scroll = msg_save;
      retval = NOTDONE;
      goto theend;
    }
  }

  if (!read_stdin && fname != NULL) {
    perm = os_getperm(fname);
  }

#ifdef OPEN_CHR_FILES
# define IS_CHR_DEV(perm, fname) S_ISCHR(perm) && is_dev_fd_file(fname)
#else
# define IS_CHR_DEV(perm, fname) false
#endif

  if (!read_stdin && !read_buffer && !read_fifo) {
    if (perm >= 0 && !S_ISREG(perm)                 // not a regular file ...
        && !S_ISFIFO(perm)                          // ... or fifo
        && !S_ISSOCK(perm)                          // ... or socket
        && !(IS_CHR_DEV(perm, fname))
        // ... or a character special file named /dev/fd/<n>
        ) {
      // On Unix it is possible to read a directory, so we have to
      // check for it before os_open().
      if (S_ISDIR(perm)) {
        if (!silent) {
          filemess(curbuf, fname, _(msg_is_a_directory));
        }
        retval = NOTDONE;
      } else {
        filemess(curbuf, fname, _("is not a file"));
      }
      msg_end();
      msg_scroll = msg_save;
      goto theend;
    }
  }

  // Set default or forced 'fileformat' and 'binary'.
  set_file_options(set_options, eap);

  // When opening a new file we take the readonly flag from the file.
  // Default is r/w, can be set to r/o below.
  // Don't reset it when in readonly mode
  // Only set/reset b_p_ro when BF_CHECK_RO is set.
  bool check_readonly = (newfile && (curbuf->b_flags & BF_CHECK_RO));
  if (check_readonly && !readonlymode) {
    curbuf->b_p_ro = false;
  }

  if (newfile && !read_stdin && !read_buffer && !read_fifo) {
    // Remember time of file.
    if (os_fileinfo(fname, &file_info)) {
      buf_store_file_info(curbuf, &file_info);
      curbuf->b_mtime_read = curbuf->b_mtime;
      curbuf->b_mtime_read_ns = curbuf->b_mtime_ns;
#ifdef UNIX
      // Use the protection bits of the original file for the swap file.
      // This makes it possible for others to read the name of the
      // edited file from the swapfile, but only if they can read the
      // edited file.
      // Remove the "write" and "execute" bits for group and others
      // (they must not write the swapfile).
      // Add the "read" and "write" bits for the user, otherwise we may
      // not be able to write to the file ourselves.
      // Setting the bits is done below, after creating the swap file.
      swap_mode = ((int)file_info.stat.st_mode & 0644) | 0600;
#endif
    } else {
      curbuf->b_mtime = 0;
      curbuf->b_mtime_ns = 0;
      curbuf->b_mtime_read = 0;
      curbuf->b_mtime_read_ns = 0;
      curbuf->b_orig_size = 0;
      curbuf->b_orig_mode = 0;
    }

    // Reset the "new file" flag.  It will be set again below when the
    // file doesn't exist.
    curbuf->b_flags &= ~(BF_NEW | BF_NEW_W);
  }

  // Check readonly.
  bool file_readonly = false;
  if (!read_buffer && !read_stdin) {
    if (!newfile || readonlymode || !(perm & 0222)
        || !os_file_is_writable(fname)) {
      file_readonly = true;
    }
    fd = os_open(fname, O_RDONLY, 0);
  }

  if (fd < 0) {                     // cannot open at all
    msg_scroll = msg_save;
    if (!newfile) {
      goto theend;
    }
    if (perm == UV_ENOENT) {  // check if the file exists
      // Set the 'new-file' flag, so that when the file has
      // been created by someone else, a ":w" will complain.
      curbuf->b_flags |= BF_NEW;

      // Create a swap file now, so that other Vims are warned
      // that we are editing this file.  Don't do this for a
      // "nofile" or "nowrite" buffer type.
      if (!bt_dontwrite(curbuf)) {
        check_need_swap(newfile);
        // SwapExists autocommand may mess things up
        if (curbuf != old_curbuf
            || (using_b_ffname
                && (old_b_ffname != curbuf->b_ffname))
            || (using_b_fname
                && (old_b_fname != curbuf->b_fname))) {
          emsg(_(e_auchangedbuf));
          goto theend;
        }
      }
      if (!silent) {
        if (dir_of_file_exists(fname)) {
          filemess(curbuf, sfname, _("[New]"));
        } else {
          filemess(curbuf, sfname, _("[New DIRECTORY]"));
        }
      }
      // Even though this is a new file, it might have been
      // edited before and deleted.  Get the old marks.
      check_marks_read();
      // Set forced 'fileencoding'.
      if (eap != NULL) {
        set_forced_fenc(eap);
      }
      apply_autocmds_exarg(EVENT_BUFNEWFILE, sfname, sfname,
                           false, curbuf, eap);
      // remember the current fileformat
      save_file_ff(curbuf);

      if (!aborting()) {  // autocmds may abort script processing
        retval = OK;      // a new file is not an error
      }
      goto theend;
    }
#if defined(UNIX) && defined(EOVERFLOW)
    filemess(curbuf, sfname, ((fd == UV_EFBIG) ? _("[File too big]")
                                               :
                              // libuv only returns -errno
                              // in Unix and in Windows
                              // open() does not set
                              // EOVERFLOW
                              (fd == -EOVERFLOW) ? _("[File too big]")
                                                 : _("[Permission Denied]")));
#else
    filemess(curbuf, sfname, ((fd == UV_EFBIG) ? _("[File too big]")
                                               : _("[Permission Denied]")));
#endif
    curbuf->b_p_ro = true;                  // must use "w!" now

    goto theend;
  }

  // Only set the 'ro' flag for readonly files the first time they are
  // loaded.    Help files always get readonly mode
  if ((check_readonly && file_readonly) || curbuf->b_help) {
    curbuf->b_p_ro = true;
  }

  if (set_options) {
    // Don't change 'eol' if reading from buffer as it will already be
    // correctly set when reading stdin.
    if (!read_buffer) {
      curbuf->b_p_eof = false;
      curbuf->b_start_eof = false;
      curbuf->b_p_eol = true;
      curbuf->b_start_eol = true;
    }
    curbuf->b_p_bomb = false;
    curbuf->b_start_bomb = false;
  }

  // Create a swap file now, so that other Vims are warned that we are
  // editing this file.
  // Don't do this for a "nofile" or "nowrite" buffer type.
  if (!bt_dontwrite(curbuf)) {
    check_need_swap(newfile);
    if (!read_stdin
        && (curbuf != old_curbuf
            || (using_b_ffname && (old_b_ffname != curbuf->b_ffname))
            || (using_b_fname && (old_b_fname != curbuf->b_fname)))) {
      emsg(_(e_auchangedbuf));
      if (!read_buffer) {
        close(fd);
      }
      goto theend;
    }
#ifdef UNIX
    // Set swap file protection bits after creating it.
    if (swap_mode > 0 && curbuf->b_ml.ml_mfp != NULL
        && curbuf->b_ml.ml_mfp->mf_fname != NULL) {
      const char *swap_fname = curbuf->b_ml.ml_mfp->mf_fname;

      // If the group-read bit is set but not the world-read bit, then
      // the group must be equal to the group of the original file.  If
      // we can't make that happen then reset the group-read bit.  This
      // avoids making the swap file readable to more users when the
      // primary group of the user is too permissive.
      if ((swap_mode & 044) == 040) {
        FileInfo swap_info;

        if (os_fileinfo(swap_fname, &swap_info)
            && file_info.stat.st_gid != swap_info.stat.st_gid
            && os_fchown(curbuf->b_ml.ml_mfp->mf_fd, (uv_uid_t)(-1),
                         (uv_gid_t)file_info.stat.st_gid)
            == -1) {
          swap_mode &= 0600;
        }
      }

      os_setperm(swap_fname, swap_mode);
    }
#endif
  }

  // If "Quit" selected at ATTENTION dialog, don't load the file.
  if (swap_exists_action == SEA_QUIT) {
    if (!read_buffer && !read_stdin) {
      close(fd);
    }
    goto theend;
  }

  no_wait_return++;         // don't wait for return yet

  // Set '[ mark to the line above where the lines go (line 1 if zero).
  orig_start = curbuf->b_op_start;
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
    curbuf->b_op_start = orig_start;

    if (msg_scrolled == n) {
      msg_scroll = m;
    }

    if (aborting()) {       // autocmds may abort script processing
      no_wait_return--;
      msg_scroll = msg_save;
      curbuf->b_p_ro = true;            // must use "w!" now
      goto theend;
    }
    // Don't allow the autocommands to change the current buffer.
    // Try to re-open the file.
    //
    // Don't allow the autocommands to change the buffer name either
    // (cd for example) if it invalidates fname or sfname.
    if (!read_stdin && (curbuf != old_curbuf
                        || (using_b_ffname && (old_b_ffname != curbuf->b_ffname))
                        || (using_b_fname && (old_b_fname != curbuf->b_fname))
                        || (fd = os_open(fname, O_RDONLY, 0)) < 0)) {
      no_wait_return--;
      msg_scroll = msg_save;
      if (fd < 0) {
        emsg(_("E200: *ReadPre autocommands made the file unreadable"));
      } else {
        emsg(_("E201: *ReadPre autocommands must not change current buffer"));
      }
      curbuf->b_p_ro = true;            // must use "w!" now
      goto theend;
    }
  }

  // Autocommands may add lines to the file, need to check if it is empty
  wasempty = (curbuf->b_ml.ml_flags & ML_EMPTY);

  if (!recoverymode && !filtering && !(flags & READ_DUMMY) && !silent) {
    if (!read_stdin && !read_buffer) {
      filemess(curbuf, sfname, "");
    }
  }

  msg_scroll = false;                   // overwrite the file message

  // Set linecnt now, before the "retry" caused by a wrong guess for
  // fileformat, and after the autocommands, which may change them.
  linecnt = curbuf->b_ml.ml_line_count;

  // "++bad=" argument.
  if (eap != NULL && eap->bad_char != 0) {
    bad_char_behavior = eap->bad_char;
    if (set_options) {
      curbuf->b_bad_char = eap->bad_char;
    }
  } else {
    curbuf->b_bad_char = 0;
  }

  // Decide which 'encoding' to use or use first.
  if (eap != NULL && eap->force_enc != 0) {
    fenc = enc_canonize(eap->cmd + eap->force_enc);
    fenc_alloced = true;
    keep_dest_enc = true;
  } else if (curbuf->b_p_bin) {
    fenc = "";                // binary: don't convert
    fenc_alloced = false;
  } else if (curbuf->b_help) {
    // Help files are either utf-8 or latin1.  Try utf-8 first, if this
    // fails it must be latin1.
    // It is needed when the first line contains non-ASCII characters.
    // That is only in *.??x files.
    fenc_next = "latin1";
    fenc = "utf-8";

    fenc_alloced = false;
  } else if (*p_fencs == NUL) {
    fenc = curbuf->b_p_fenc;            // use format from buffer
    fenc_alloced = false;
  } else {
    fenc_next = p_fencs;                // try items in 'fileencodings'
    fenc = next_fenc(&fenc_next, &fenc_alloced);
  }

  // Jump back here to retry reading the file in different ways.
  // Reasons to retry:
  // - encoding conversion failed: try another one from "fenc_next"
  // - BOM detected and fenc was set, need to setup conversion
  // - "fileformat" check failed: try another
  //
  // Variables set for special retry actions:
  // "file_rewind"      Rewind the file to start reading it again.
  // "advance_fenc"     Advance "fenc" using "fenc_next".
  // "skip_read"        Re-use already read bytes (BOM detected).
  // "did_iconv"        iconv() conversion failed, try 'charconvert'.
  // "keep_fileformat" Don't reset "fileformat".
  //
  // Other status indicators:
  // "tmpname"  When != NULL did conversion with 'charconvert'.
  //                    Output file has to be deleted afterwards.
  // "iconv_fd" When != -1 did conversion with iconv().
retry:

  if (file_rewind) {
    if (read_buffer) {
      read_buf_lnum = 1;
      read_buf_col = 0;
    } else if (read_stdin || vim_lseek(fd, 0, SEEK_SET) != 0) {
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
      curbuf->b_p_bomb = false;
      curbuf->b_start_bomb = false;
    }
    conv_error = 0;
  }

  // When retrying with another "fenc" and the first time "fileformat"
  // will be reset.
  if (keep_fileformat) {
    keep_fileformat = false;
  } else {
    if (eap != NULL && eap->force_ff != 0) {
      fileformat = get_fileformat_force(curbuf, eap);
      try_unix = try_dos = try_mac = false;
    } else if (curbuf->b_p_bin) {
      fileformat = EOL_UNIX;                    // binary: use Unix format
    } else if (*p_ffs ==
               NUL) {
      fileformat = get_fileformat(curbuf);      // use format from buffer
    } else {
      fileformat = EOL_UNKNOWN;                 // detect from file
    }
  }

  if (iconv_fd != (iconv_t)-1) {
    // aborted conversion with iconv(), close the descriptor
    iconv_close(iconv_fd);
    iconv_fd = (iconv_t)-1;
  }

  if (advance_fenc) {
    // Try the next entry in 'fileencodings'.
    advance_fenc = false;

    if (eap != NULL && eap->force_enc != 0) {
      // Conversion given with "++cc=" wasn't possible, read
      // without conversion.
      notconverted = true;
      conv_error = 0;
      if (fenc_alloced) {
        xfree(fenc);
      }
      fenc = "";
      fenc_alloced = false;
    } else {
      if (fenc_alloced) {
        xfree(fenc);
      }
      if (fenc_next != NULL) {
        fenc = next_fenc(&fenc_next, &fenc_alloced);
      } else {
        fenc = "";
        fenc_alloced = false;
      }
    }
    if (tmpname != NULL) {
      os_remove(tmpname);  // delete converted file
      XFREE_CLEAR(tmpname);
    }
  }

  // Conversion may be required when the encoding of the file is different
  // from 'encoding' or 'encoding' is UTF-16, UCS-2 or UCS-4.
  fio_flags = 0;
  converted = need_conversion(fenc);
  if (converted) {
    // "ucs-bom" means we need to check the first bytes of the file
    // for a BOM.
    if (strcmp(fenc, ENC_UCSBOM) == 0) {
      fio_flags = FIO_UCSBOM;
    } else {
      // Check if UCS-2/4 or Latin1 to UTF-8 conversion needs to be
      // done.  This is handled below after read().  Prepare the
      // fio_flags to avoid having to parse the string each time.
      // Also check for Unicode to Latin1 conversion, because iconv()
      // appears not to handle this correctly.  This works just like
      // conversion to UTF-8 except how the resulting character is put in
      // the buffer.
      fio_flags = get_fio_flags(fenc);
    }

    // Try using iconv() if we can't convert internally.
    if (fio_flags == 0
        && !did_iconv) {
      iconv_fd = (iconv_t)my_iconv_open("utf-8", fenc);
    }

    // Use the 'charconvert' expression when conversion is required
    // and we can't do it internally or with iconv().
    if (fio_flags == 0 && !read_stdin && !read_buffer && *p_ccv != NUL
        && !read_fifo && iconv_fd == (iconv_t)-1) {
      did_iconv = false;
      // Skip conversion when it's already done (retry for wrong
      // "fileformat").
      if (tmpname == NULL) {
        tmpname = readfile_charconvert(fname, fenc, &fd);
        if (tmpname == NULL) {
          // Conversion failed.  Try another one.
          advance_fenc = true;
          if (fd < 0) {
            // Re-opening the original file failed!
            emsg(_("E202: Conversion made file unreadable!"));
            error = true;
            goto failed;
          }
          goto retry;
        }
      }
    } else {
      if (fio_flags == 0 && iconv_fd == (iconv_t)-1) {
        // Conversion wanted but we can't.
        // Try the next conversion in 'fileencodings'
        advance_fenc = true;
        goto retry;
      }
    }
  }

  // Set "can_retry" when it's possible to rewind the file and try with
  // another "fenc" value.  It's false when no other "fenc" to try, reading
  // stdin or fixed at a specific encoding.
  bool can_retry = (*fenc != NUL && !read_stdin && !keep_dest_enc && !read_fifo);

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
    if (read_undo_file) {
      sha256_start(&sha_ctx);
    }
  }

  while (!error && !got_int) {
    // We allocate as much space for the file as we can get, plus
    // space for the old line plus room for one terminating NUL.
    // The amount is limited by the fact that read() only can read
    // up to max_unsigned characters (and other things).
    {
      if (!skip_read) {
        // Use buffer >= 64K.  Add linerest to double the size if the
        // line gets very long, to avoid a lot of copying. But don't
        // read more than 1 Mbyte at a time, so we can be interrupted.
        size = MIN(0x10000 + linerest, 0x100000);
      }

      // Protect against the argument of lalloc() going negative.
      if (size < 0 || size + linerest + 1 < 0 || linerest >= MAXCOL) {
        split++;
        *ptr = NL;  // split line by inserting a NL
        size = 1;
      } else if (!skip_read) {
        for (; size >= 10; size /= 2) {
          new_buffer = verbose_try_malloc((size_t)size + (size_t)linerest + 1);
          if (new_buffer) {
            break;
          }
        }
        if (new_buffer == NULL) {
          error = true;
          break;
        }
        if (linerest) {         // copy characters from the previous buffer
          memmove(new_buffer, ptr - linerest, (size_t)linerest);
        }
        xfree(buffer);
        buffer = new_buffer;
        ptr = buffer + linerest;
        line_start = buffer;

        // May need room to translate into.
        // For iconv() we don't really know the required space, use a
        // factor ICONV_MULT.
        // latin1 to utf-8: 1 byte becomes up to 2 bytes
        // utf-16 to utf-8: 2 bytes become up to 3 bytes, 4 bytes
        // become up to 4 bytes, size must be multiple of 2
        // ucs-2 to utf-8: 2 bytes become up to 3 bytes, size must be
        // multiple of 2
        // ucs-4 to utf-8: 4 bytes become up to 6 bytes, size must be
        // multiple of 4
        real_size = (int)size;
        if (iconv_fd != (iconv_t)-1) {
          size = size / ICONV_MULT;
        } else if (fio_flags & FIO_LATIN1) {
          size = size / 2;
        } else if (fio_flags & (FIO_UCS2 | FIO_UTF16)) {
          size = (size * 2 / 3) & ~1;
        } else if (fio_flags & FIO_UCS4) {
          size = (size * 2 / 3) & ~3;
        } else if (fio_flags == FIO_UCSBOM) {
          size = size / ICONV_MULT;  // worst case
        }

        if (conv_restlen > 0) {
          // Insert unconverted bytes from previous line.
          memmove(ptr, conv_rest, (size_t)conv_restlen);
          ptr += conv_restlen;
          size -= conv_restlen;
        }

        if (read_buffer) {
          // Read bytes from curbuf.  Used for converting text read
          // from stdin.
          if (read_buf_lnum > from) {
            size = 0;
          } else {
            int ni;
            int tlen = 0;
            while (true) {
              p = (uint8_t *)ml_get(read_buf_lnum) + read_buf_col;
              int n = ml_get_len(read_buf_lnum) - read_buf_col;
              if (tlen + n + 1 > size) {
                // Filled up to "size", append partial line.
                // Change NL to NUL to reverse the effect done
                // below.
                n = (int)(size - tlen);
                for (ni = 0; ni < n; ni++) {
                  if (p[ni] == NL) {
                    ptr[tlen++] = NUL;
                  } else {
                    ptr[tlen++] = (char)p[ni];
                  }
                }
                read_buf_col += n;
                break;
              }

              // Append whole line and new-line.  Change NL
              // to NUL to reverse the effect done below.
              for (ni = 0; ni < n; ni++) {
                if (p[ni] == NL) {
                  ptr[tlen++] = NUL;
                } else {
                  ptr[tlen++] = (char)p[ni];
                }
              }
              ptr[tlen++] = NL;
              read_buf_col = 0;
              if (++read_buf_lnum > from) {
                // When the last line didn't have an
                // end-of-line don't add it now either.
                if (!curbuf->b_p_eol) {
                  tlen--;
                }
                size = tlen;
                break;
              }
            }
          }
        } else {
          // Read bytes from the file.
          size_t read_size = (size_t)size;
          size = read_eintr(fd, ptr, read_size);
        }

        if (size <= 0) {
          if (size < 0) {                           // read error
            error = true;
          } else if (conv_restlen > 0) {
            // Reached end-of-file but some trailing bytes could
            // not be converted.  Truncated file?

            // When we did a conversion report an error.
            if (fio_flags != 0 || iconv_fd != (iconv_t)-1) {
              if (can_retry) {
                goto rewind_retry;
              }
              if (conv_error == 0) {
                conv_error = curbuf->b_ml.ml_line_count
                             - linecnt + 1;
              }
            } else if (illegal_byte == 0) {
              // Remember the first linenr with an illegal byte
              illegal_byte = curbuf->b_ml.ml_line_count
                             - linecnt + 1;
            }
            if (bad_char_behavior == BAD_DROP) {
              *(ptr - conv_restlen) = NUL;
              conv_restlen = 0;
            } else {
              // Replace the trailing bytes with the replacement
              // character if we were converting; if we weren't,
              // leave the UTF8 checking code to do it, as it
              // works slightly differently.
              if (bad_char_behavior != BAD_KEEP && (fio_flags != 0 || iconv_fd != (iconv_t)-1)) {
                while (conv_restlen > 0) {
                  *(--ptr) = (char)bad_char_behavior;
                  conv_restlen--;
                }
              }
              fio_flags = 0;  // don't convert this
              if (iconv_fd != (iconv_t)-1) {
                iconv_close(iconv_fd);
                iconv_fd = (iconv_t)-1;
              }
            }
          }
        }
      }

      skip_read = false;

      // At start of file: Check for BOM.
      // Also check for a BOM for other Unicode encodings, but not after
      // converting with 'charconvert' or when a BOM has already been
      // found.
      if ((filesize == 0)
          && (fio_flags == FIO_UCSBOM
              || (!curbuf->b_p_bomb
                  && tmpname == NULL
                  && (*fenc == 'u' || *fenc == NUL)))) {
        char *ccname;
        int blen = 0;

        // no BOM detection in a short file or in binary mode
        if (size < 2 || curbuf->b_p_bin) {
          ccname = NULL;
        } else {
          ccname = check_for_bom(ptr, (int)size, &blen,
                                 fio_flags == FIO_UCSBOM ? FIO_ALL : get_fio_flags(fenc));
        }
        if (ccname != NULL) {
          // Remove BOM from the text
          filesize += blen;
          size -= blen;
          memmove(ptr, ptr + blen, (size_t)size);
          if (set_options) {
            curbuf->b_p_bomb = true;
            curbuf->b_start_bomb = true;
          }
        }

        if (fio_flags == FIO_UCSBOM) {
          if (ccname == NULL) {
            // No BOM detected: retry with next encoding.
            advance_fenc = true;
          } else {
            // BOM detected: set "fenc" and jump back
            if (fenc_alloced) {
              xfree(fenc);
            }
            fenc = ccname;
            fenc_alloced = false;
          }
          // retry reading without getting new bytes or rewinding
          skip_read = true;
          goto retry;
        }
      }

      // Include not converted bytes.
      ptr -= conv_restlen;
      size += conv_restlen;
      conv_restlen = 0;
      // Break here for a read error or end-of-file.
      if (size <= 0) {
        break;
      }

      if (iconv_fd != (iconv_t)-1) {
        // Attempt conversion of the read bytes to 'encoding' using iconv().
        const char *fromp = ptr;
        size_t from_size = (size_t)size;
        ptr += size;
        char *top = ptr;
        size_t to_size = (size_t)(real_size - size);

        // If there is conversion error or not enough room try using
        // another conversion.  Except for when there is no
        // alternative (help files).
        while ((iconv(iconv_fd, (void *)&fromp, &from_size,
                      &top, &to_size)
                == (size_t)-1 && ICONV_ERRNO != ICONV_EINVAL)
               || from_size > CONV_RESTLEN) {
          if (can_retry) {
            goto rewind_retry;
          }
          if (conv_error == 0) {
            conv_error = readfile_linenr(linecnt, ptr, top);
          }

          // Deal with a bad byte and continue with the next.
          fromp++;
          from_size--;
          if (bad_char_behavior == BAD_KEEP) {
            *top++ = *(fromp - 1);
            to_size--;
          } else if (bad_char_behavior != BAD_DROP) {
            *top++ = (char)bad_char_behavior;
            to_size--;
          }
        }

        if (from_size > 0) {
          // Some remaining characters, keep them for the next
          // round.
          memmove(conv_rest, fromp, from_size);
          conv_restlen = (int)from_size;
        }

        // move the linerest to before the converted characters
        line_start = ptr - linerest;
        memmove(line_start, buffer, (size_t)linerest);
        size = (top - ptr);
      }

      if (fio_flags != 0) {
        unsigned u8c;
        char *tail = NULL;

        // Convert Unicode or Latin1 to UTF-8.
        // Go from end to start through the buffer, because the number
        // of bytes may increase.
        // "dest" points to after where the UTF-8 bytes go, "p" points
        // to after the next character to convert.
        char *dest = ptr + real_size;
        if (fio_flags == FIO_LATIN1 || fio_flags == FIO_UTF8) {
          p = (uint8_t *)ptr + size;
          if (fio_flags == FIO_UTF8) {
            // Check for a trailing incomplete UTF-8 sequence
            tail = ptr + size - 1;
            while (tail > ptr && (*tail & 0xc0) == 0x80) {
              tail--;
            }
            if (tail + utf_byte2len(*tail) <= ptr + size) {
              tail = NULL;
            } else {
              p = (uint8_t *)tail;
            }
          }
        } else if (fio_flags & (FIO_UCS2 | FIO_UTF16)) {
          // Check for a trailing byte
          p = (uint8_t *)ptr + (size & ~1);
          if (size & 1) {
            tail = (char *)p;
          }
          if ((fio_flags & FIO_UTF16) && p > (uint8_t *)ptr) {
            // Check for a trailing leading word
            if (fio_flags & FIO_ENDIAN_L) {
              u8c = (unsigned)(*--p) << 8;
              u8c += *--p;
            } else {
              u8c = *--p;
              u8c += (unsigned)(*--p) << 8;
            }
            if (u8c >= 0xd800 && u8c <= 0xdbff) {
              tail = (char *)p;
            } else {
              p += 2;
            }
          }
        } else {   //  FIO_UCS4
                   // Check for trailing 1, 2 or 3 bytes
          p = (uint8_t *)ptr + (size & ~3);
          if (size & 3) {
            tail = (char *)p;
          }
        }

        // If there is a trailing incomplete sequence move it to
        // conv_rest[].
        if (tail != NULL) {
          conv_restlen = (int)((ptr + size) - tail);
          memmove(conv_rest, tail, (size_t)conv_restlen);
          size -= conv_restlen;
        }

        while (p > (uint8_t *)ptr) {
          if (fio_flags & FIO_LATIN1) {
            u8c = *--p;
          } else if (fio_flags & (FIO_UCS2 | FIO_UTF16)) {
            if (fio_flags & FIO_ENDIAN_L) {
              u8c = (unsigned)(*--p) << 8;
              u8c += *--p;
            } else {
              u8c = *--p;
              u8c += (unsigned)(*--p) << 8;
            }
            if ((fio_flags & FIO_UTF16)
                && u8c >= 0xdc00 && u8c <= 0xdfff) {
              int u16c;

              if (p == (uint8_t *)ptr) {
                // Missing leading word.
                if (can_retry) {
                  goto rewind_retry;
                }
                if (conv_error == 0) {
                  conv_error = readfile_linenr(linecnt, ptr, (char *)p);
                }
                if (bad_char_behavior == BAD_DROP) {
                  continue;
                }
                if (bad_char_behavior != BAD_KEEP) {
                  u8c = (unsigned)bad_char_behavior;
                }
              }

              // found second word of double-word, get the first
              // word and compute the resulting character
              if (fio_flags & FIO_ENDIAN_L) {
                u16c = (*--p << 8);
                u16c += *--p;
              } else {
                u16c = *--p;
                u16c += (*--p << 8);
              }
              u8c = 0x10000 + (((unsigned)u16c & 0x3ff) << 10)
                    + (u8c & 0x3ff);

              // Check if the word is indeed a leading word.
              if (u16c < 0xd800 || u16c > 0xdbff) {
                if (can_retry) {
                  goto rewind_retry;
                }
                if (conv_error == 0) {
                  conv_error = readfile_linenr(linecnt, ptr, (char *)p);
                }
                if (bad_char_behavior == BAD_DROP) {
                  continue;
                }
                if (bad_char_behavior != BAD_KEEP) {
                  u8c = (unsigned)bad_char_behavior;
                }
              }
            }
          } else if (fio_flags & FIO_UCS4) {
            if (fio_flags & FIO_ENDIAN_L) {
              u8c = (unsigned)(*--p) << 24;
              u8c += (unsigned)(*--p) << 16;
              u8c += (unsigned)(*--p) << 8;
              u8c += *--p;
            } else {          // big endian
              u8c = *--p;
              u8c += (unsigned)(*--p) << 8;
              u8c += (unsigned)(*--p) << 16;
              u8c += (unsigned)(*--p) << 24;
            }
            // Replace characters over INT_MAX with Unicode replacement character
            if (u8c > INT_MAX) {
              u8c = 0xfffd;
            }
          } else {        // UTF-8
            if (*--p < 0x80) {
              u8c = *p;
            } else {
              len = utf_head_off(ptr, (char *)p);
              p -= len;
              u8c = (unsigned)utf_ptr2char((char *)p);
              if (len == 0) {
                // Not a valid UTF-8 character, retry with
                // another fenc when possible, otherwise just
                // report the error.
                if (can_retry) {
                  goto rewind_retry;
                }
                if (conv_error == 0) {
                  conv_error = readfile_linenr(linecnt, ptr, (char *)p);
                }
                if (bad_char_behavior == BAD_DROP) {
                  continue;
                }
                if (bad_char_behavior != BAD_KEEP) {
                  u8c = (unsigned)bad_char_behavior;
                }
              }
            }
          }
          assert(u8c <= INT_MAX);
          // produce UTF-8
          dest -= utf_char2len((int)u8c);
          utf_char2bytes((int)u8c, dest);
        }

        // move the linerest to before the converted characters
        line_start = dest - linerest;
        memmove(line_start, buffer, (size_t)linerest);
        size = ((ptr + real_size) - dest);
        ptr = dest;
      } else if (!curbuf->b_p_bin) {
        bool incomplete_tail = false;

        // Reading UTF-8: Check if the bytes are valid UTF-8.
        for (p = (uint8_t *)ptr;; p++) {
          int todo = (int)(((uint8_t *)ptr + size) - p);

          if (todo <= 0) {
            break;
          }
          if (*p >= 0x80) {
            // A length of 1 means it's an illegal byte.  Accept
            // an incomplete character at the end though, the next
            // read() will get the next bytes, we'll check it
            // then.
            int l = utf_ptr2len_len((char *)p, todo);
            if (l > todo && !incomplete_tail) {
              // Avoid retrying with a different encoding when
              // a truncated file is more likely, or attempting
              // to read the rest of an incomplete sequence when
              // we have already done so.
              if (p > (uint8_t *)ptr || filesize > 0) {
                incomplete_tail = true;
              }
              // Incomplete byte sequence, move it to conv_rest[]
              // and try to read the rest of it, unless we've
              // already done so.
              if (p > (uint8_t *)ptr) {
                conv_restlen = todo;
                memmove(conv_rest, p, (size_t)conv_restlen);
                size -= conv_restlen;
                break;
              }
            }
            if (l == 1 || l > todo) {
              // Illegal byte.  If we can try another encoding
              // do that, unless at EOF where a truncated
              // file is more likely than a conversion error.
              if (can_retry && !incomplete_tail) {
                break;
              }

              // When we did a conversion report an error.
              if (iconv_fd != (iconv_t)-1 && conv_error == 0) {
                conv_error = readfile_linenr(linecnt, ptr, (char *)p);
              }

              // Remember the first linenr with an illegal byte
              if (conv_error == 0 && illegal_byte == 0) {
                illegal_byte = readfile_linenr(linecnt, ptr, (char *)p);
              }

              // Drop, keep or replace the bad byte.
              if (bad_char_behavior == BAD_DROP) {
                memmove(p, p + 1, (size_t)(todo - 1));
                p--;
                size--;
              } else if (bad_char_behavior != BAD_KEEP) {
                *p = (uint8_t)bad_char_behavior;
              }
            } else {
              p += l - 1;
            }
          }
        }
        if (p < (uint8_t *)ptr + size && !incomplete_tail) {
          // Detected a UTF-8 error.
rewind_retry:
          // Retry reading with another conversion.
          if (*p_ccv != NUL && iconv_fd != (iconv_t)-1) {
            // iconv() failed, try 'charconvert'
            did_iconv = true;
          } else {
            // use next item from 'fileencodings'
            advance_fenc = true;
          }
          file_rewind = true;
          goto retry;
        }
      }

      // count the number of characters (after conversion!)
      filesize += size;

      // when reading the first part of a file: guess EOL type
      if (fileformat == EOL_UNKNOWN) {
        // First try finding a NL, for Dos and Unix
        if (try_dos || try_unix) {
          // Reset the carriage return counter.
          if (try_mac) {
            try_mac = 1;
          }

          for (p = (uint8_t *)ptr; p < (uint8_t *)ptr + size; p++) {
            if (*p == NL) {
              if (!try_unix
                  || (try_dos && p > (uint8_t *)ptr && p[-1] == CAR)) {
                fileformat = EOL_DOS;
              } else {
                fileformat = EOL_UNIX;
              }
              break;
            } else if (*p == CAR && try_mac) {
              try_mac++;
            }
          }

          // Don't give in to EOL_UNIX if EOL_MAC is more likely
          if (fileformat == EOL_UNIX && try_mac) {
            // Need to reset the counters when retrying fenc.
            try_mac = 1;
            try_unix = 1;
            for (; p >= (uint8_t *)ptr && *p != CAR; p--) {}
            if (p >= (uint8_t *)ptr) {
              for (p = (uint8_t *)ptr; p < (uint8_t *)ptr + size; p++) {
                if (*p == NL) {
                  try_unix++;
                } else if (*p == CAR) {
                  try_mac++;
                }
              }
              if (try_mac > try_unix) {
                fileformat = EOL_MAC;
              }
            }
          } else if (fileformat == EOL_UNKNOWN && try_mac == 1) {
            // Looking for CR but found no end-of-line markers at all:
            // use the default format.
            fileformat = default_fileformat();
          }
        }

        // No NL found: may use Mac format
        if (fileformat == EOL_UNKNOWN && try_mac) {
          fileformat = EOL_MAC;
        }

        // Still nothing found?  Use first format in 'ffs'
        if (fileformat == EOL_UNKNOWN) {
          fileformat = default_fileformat();
        }

        // May set 'p_ff' if editing a new file.
        if (set_options) {
          set_fileformat(fileformat, OPT_LOCAL);
        }
      }
    }

    // This loop is executed once for every character read.
    // Keep it fast!
    if (fileformat == EOL_MAC) {
      ptr--;
      while (++ptr, --size >= 0) {
        // catch most common case first
        if ((c = *ptr) != NUL && c != CAR && c != NL) {
          continue;
        }
        if (c == NUL) {
          *ptr = NL;            // NULs are replaced by newlines!
        } else if (c == NL) {
          *ptr = CAR;           // NLs are replaced by CRs!
        } else {
          if (skip_count == 0) {
            *ptr = NUL;                     // end of line
            len = (colnr_T)(ptr - line_start + 1);
            if (ml_append(lnum, line_start, len, newfile) == FAIL) {
              error = true;
              break;
            }
            if (read_undo_file) {
              sha256_update(&sha_ctx, (uint8_t *)line_start, (size_t)len);
            }
            lnum++;
            if (--read_count == 0) {
              error = true;                     // break loop
              line_start = ptr;                 // nothing left to write
              break;
            }
          } else {
            skip_count--;
          }
          line_start = ptr + 1;
        }
      }
    } else {
      ptr--;
      while (++ptr, --size >= 0) {
        if ((c = *ptr) != NUL && c != NL) {        // catch most common case
          continue;
        }
        if (c == NUL) {
          *ptr = NL;            // NULs are replaced by newlines!
        } else {
          if (skip_count == 0) {
            *ptr = NUL;                         // end of line
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
                    && (read_buffer || vim_lseek(fd, 0, SEEK_SET) == 0)) {
                  fileformat = EOL_UNIX;
                  if (set_options) {
                    set_fileformat(EOL_UNIX, OPT_LOCAL);
                  }
                  file_rewind = true;
                  keep_fileformat = true;
                  goto retry;
                }
                ff_error = EOL_DOS;
              }
            }
            if (ml_append(lnum, line_start, len, newfile) == FAIL) {
              error = true;
              break;
            }
            if (read_undo_file) {
              sha256_update(&sha_ctx, (uint8_t *)line_start, (size_t)len);
            }
            lnum++;
            if (--read_count == 0) {
              error = true;                         // break loop
              line_start = ptr;                 // nothing left to write
              break;
            }
          } else {
            skip_count--;
          }
          line_start = ptr + 1;
        }
      }
    }
    linerest = (ptr - line_start);
    os_breakcheck();
  }

failed:
  // not an error, max. number of lines reached
  if (error && read_count == 0) {
    error = false;
  }

  // In Dos format ignore a trailing CTRL-Z, unless 'binary' is set.
  // In old days the file length was in sector count and the CTRL-Z the
  // marker where the file really ended.  Assuming we write it to a file
  // system that keeps file length properly the CTRL-Z should be dropped.
  // Set the 'endoffile' option so the user can decide what to write later.
  // In Unix format the CTRL-Z is just another character.
  if (linerest != 0
      && !curbuf->b_p_bin
      && fileformat == EOL_DOS
      && ptr[-1] == Ctrl_Z) {
    ptr--;
    linerest--;
    if (set_options) {
      curbuf->b_p_eof = true;
    }
  }

  // If we get EOF in the middle of a line, note the fact and
  // complete the line ourselves.
  if (!error
      && !got_int
      && linerest != 0) {
    // remember for when writing
    if (set_options) {
      curbuf->b_p_eol = false;
    }
    *ptr = NUL;
    len = (colnr_T)(ptr - line_start + 1);
    if (ml_append(lnum, line_start, len, newfile) == FAIL) {
      error = true;
    } else {
      if (read_undo_file) {
        sha256_update(&sha_ctx, (uint8_t *)line_start, (size_t)len);
      }
      read_no_eol_lnum = ++lnum;
    }
  }

  if (set_options) {
    // Remember the current file format.
    save_file_ff(curbuf);
    // If editing a new file: set 'fenc' for the current buffer.
    // Also for ":read ++edit file".
    set_option_direct(kOptFileencoding, CSTR_AS_OPTVAL(fenc), OPT_LOCAL, 0);
  }
  if (fenc_alloced) {
    xfree(fenc);
  }
  if (iconv_fd != (iconv_t)-1) {
    iconv_close(iconv_fd);
  }

  if (!read_buffer && !read_stdin) {
    close(fd);  // errors are ignored
  } else {
    os_set_cloexec(fd);
  }
  xfree(buffer);

  if (read_stdin) {
    close(fd);
    if (stdin_fd < 0) {
#ifndef MSWIN
      // On Unix, use stderr for stdin, makes shell commands work.
      vim_ignored = dup(2);
#else
      // On Windows, use the console input handle for stdin.
      HANDLE conin = CreateFile("CONIN$", GENERIC_READ | GENERIC_WRITE,
                                FILE_SHARE_READ, (LPSECURITY_ATTRIBUTES)NULL,
                                OPEN_EXISTING, 0, (HANDLE)NULL);
      vim_ignored = _open_osfhandle((intptr_t)conin, _O_RDONLY);
#endif
    }
  }

  if (tmpname != NULL) {
    os_remove(tmpname);  // delete converted file
    xfree(tmpname);
  }
  no_wait_return--;                     // may wait for return now

  // In recovery mode everything but autocommands is skipped.
  if (!recoverymode) {
    // need to delete the last line, which comes from the empty buffer
    if (newfile && wasempty && !(curbuf->b_ml.ml_flags & ML_EMPTY)) {
      ml_delete(curbuf->b_ml.ml_line_count, false);
      linecnt--;
    }
    curbuf->deleted_bytes = 0;
    curbuf->deleted_bytes2 = 0;
    curbuf->deleted_codepoints = 0;
    curbuf->deleted_codeunits = 0;
    linecnt = curbuf->b_ml.ml_line_count - linecnt;
    if (filesize == 0) {
      linecnt = 0;
    }
    if (newfile || read_buffer) {
      redraw_curbuf_later(UPD_NOT_VALID);
      // After reading the text into the buffer the diff info needs to
      // be updated.
      diff_invalidate(curbuf);
      // All folds in the window are invalid now.  Mark them for update
      // before triggering autocommands.
      foldUpdateAll(curwin);
    } else if (linecnt) {               // appended at least one line
      appended_lines_mark(from, linecnt);
    }

    if (got_int) {
      if (!(flags & READ_DUMMY)) {
        filemess(curbuf, sfname, _(e_interr));
        if (newfile) {
          curbuf->b_p_ro = true;                // must use "w!" now
        }
      }
      msg_scroll = msg_save;
      check_marks_read();
      retval = OK;        // an interrupt isn't really an error
      goto theend;
    }

    if (!filtering && !(flags & READ_DUMMY) && !silent) {
      add_quoted_fname(IObuff, IOSIZE, curbuf, sfname);
      c = false;

#ifdef UNIX
      if (S_ISFIFO(perm)) {             // fifo
        xstrlcat(IObuff, _("[fifo]"), IOSIZE);
        c = true;
      }
      if (S_ISSOCK(perm)) {            // or socket
        xstrlcat(IObuff, _("[socket]"), IOSIZE);
        c = true;
      }
# ifdef OPEN_CHR_FILES
      if (S_ISCHR(perm)) {                          // or character special
        xstrlcat(IObuff, _("[character special]"), IOSIZE);
        c = true;
      }
# endif
#endif
      if (curbuf->b_p_ro) {
        xstrlcat(IObuff, shortmess(SHM_RO) ? _("[RO]") : _("[readonly]"), IOSIZE);
        c = true;
      }
      if (read_no_eol_lnum) {
        xstrlcat(IObuff, _("[noeol]"), IOSIZE);
        c = true;
      }
      if (ff_error == EOL_DOS) {
        xstrlcat(IObuff, _("[CR missing]"), IOSIZE);
        c = true;
      }
      if (split) {
        xstrlcat(IObuff, _("[long lines split]"), IOSIZE);
        c = true;
      }
      if (notconverted) {
        xstrlcat(IObuff, _("[NOT converted]"), IOSIZE);
        c = true;
      } else if (converted) {
        xstrlcat(IObuff, _("[converted]"), IOSIZE);
        c = true;
      }
      if (conv_error != 0) {
        snprintf(IObuff + strlen(IObuff), IOSIZE - strlen(IObuff),
                 _("[CONVERSION ERROR in line %" PRId64 "]"), (int64_t)conv_error);
        c = true;
      } else if (illegal_byte > 0) {
        snprintf(IObuff + strlen(IObuff), IOSIZE - strlen(IObuff),
                 _("[ILLEGAL BYTE in line %" PRId64 "]"), (int64_t)illegal_byte);
        c = true;
      } else if (error) {
        xstrlcat(IObuff, _("[READ ERRORS]"), IOSIZE);
        c = true;
      }
      if (msg_add_fileformat(fileformat)) {
        c = true;
      }

      msg_add_lines(c, linecnt, filesize);

      XFREE_CLEAR(keep_msg);
      p = NULL;
      msg_scrolled_ign = true;

      if (!read_stdin && !read_buffer) {
        if (msg_col > 0) {
          msg_putchar('\r');  // overwrite previous message
        }
        p = (uint8_t *)msg_trunc(IObuff, false, 0);
      }

      if (read_stdin || read_buffer || restart_edit != 0
          || (msg_scrolled != 0 && !need_wait_return)) {
        // Need to repeat the message after redrawing when:
        // - When reading from stdin (the screen will be cleared next).
        // - When restart_edit is set (otherwise there will be a delay before
        //   redrawing).
        // - When the screen was scrolled but there is no wait-return prompt.
        set_keep_msg((char *)p, 0);
      }
      msg_scrolled_ign = false;
    }

    // with errors writing the file requires ":w!"
    if (newfile && (error
                    || conv_error != 0
                    || (illegal_byte > 0 && bad_char_behavior != BAD_KEEP))) {
      curbuf->b_p_ro = true;
    }

    u_clearline(curbuf);   // cannot use "U" command after adding lines

    // In Ex mode: cursor at last new line.
    // Otherwise: cursor at first new line.
    if (exmode_active) {
      curwin->w_cursor.lnum = from + linecnt;
    } else {
      curwin->w_cursor.lnum = from + 1;
    }
    check_cursor_lnum(curwin);
    beginline(BL_WHITE | BL_FIX);           // on first non-blank

    if ((cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
      // Set '[ and '] marks to the newly read lines.
      curbuf->b_op_start.lnum = from + 1;
      curbuf->b_op_start.col = 0;
      curbuf->b_op_end.lnum = from + linecnt;
      curbuf->b_op_end.col = 0;
    }
  }
  msg_scroll = msg_save;

  // Get the marks before executing autocommands, so they can be used there.
  check_marks_read();

  // We remember if the last line of the read didn't have
  // an eol even when 'binary' is off, to support turning 'fixeol' off,
  // or writing the read again with 'binary' on.  The latter is required
  // for ":autocmd FileReadPost *.gz set bin|'[,']!gunzip" to work.
  curbuf->b_no_eol_lnum = read_no_eol_lnum;

  // When reloading a buffer put the cursor at the first line that is
  // different.
  if (flags & READ_KEEP_UNDO) {
    u_find_first_changed();
  }

  // When opening a new file locate undo info and read it.
  if (read_undo_file) {
    uint8_t hash[UNDO_HASH_SIZE];

    sha256_finish(&sha_ctx, hash);
    u_read_undo(NULL, hash, fname);
  }

  if (!read_stdin && !read_fifo && (!read_buffer || sfname != NULL)) {
    int m = msg_scroll;
    int n = msg_scrolled;

    // Save the fileformat now, otherwise the buffer will be considered
    // modified if the format/encoding was automatically detected.
    if (set_options) {
      save_file_ff(curbuf);
    }

    // The output from the autocommands should not overwrite anything and
    // should not be overwritten: Set msg_scroll, restore its value if no
    // output was done.
    msg_scroll = true;
    if (filtering) {
      apply_autocmds_exarg(EVENT_FILTERREADPOST, NULL, sfname,
                           false, curbuf, eap);
    } else if (newfile || (read_buffer && sfname != NULL)) {
      apply_autocmds_exarg(EVENT_BUFREADPOST, NULL, sfname,
                           false, curbuf, eap);
      if (!curbuf->b_au_did_filetype && *curbuf->b_p_ft != NUL) {
        // EVENT_FILETYPE was not triggered but the buffer already has a
        // filetype.  Trigger EVENT_FILETYPE using the existing filetype.
        apply_autocmds(EVENT_FILETYPE, curbuf->b_p_ft, curbuf->b_fname, true, curbuf);
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

  if (!(recoverymode && error)) {
    retval = OK;
  }

theend:
  if (curbuf->b_ml.ml_mfp != NULL
      && curbuf->b_ml.ml_mfp->mf_dirty == MF_DIRTY_YES_NOSYNC) {
    // OK to sync the swap file now
    curbuf->b_ml.ml_mfp->mf_dirty = MF_DIRTY_YES;
  }

  return retval;
}

#ifdef OPEN_CHR_FILES
/// Returns true if the file name argument is of the form "/dev/fd/\d\+",
/// which is the name of files used for process substitution output by
/// some shells on some operating systems, e.g., bash on SunOS.
/// Do not accept "/dev/fd/[012]", opening these may hang Vim.
///
/// @param fname file name to check
bool is_dev_fd_file(char *fname)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  return strncmp(fname, "/dev/fd/", 8) == 0
         && ascii_isdigit((uint8_t)fname[8])
         && *skipdigits(fname + 9) == NUL
         && (fname[9] != NUL
             || (fname[8] != '0' && fname[8] != '1' && fname[8] != '2'));
}
#endif

/// From the current line count and characters read after that, estimate the
/// line number where we are now.
/// Used for error messages that include a line number.
///
/// @param linecnt  line count before reading more bytes
/// @param p        start of more bytes read
/// @param endp     end of more bytes read
static linenr_T readfile_linenr(linenr_T linecnt, char *p, const char *endp)
{
  linenr_T lnum = curbuf->b_ml.ml_line_count - linecnt + 1;
  for (char *s = p; s < endp; s++) {
    if (*s == '\n') {
      lnum++;
    }
  }
  return lnum;
}

/// Fill "*eap" to force the 'fileencoding', 'fileformat' and 'binary' to be
/// equal to the buffer "buf".  Used for calling readfile().
void prep_exarg(exarg_T *eap, const buf_T *buf)
  FUNC_ATTR_NONNULL_ALL
{
  const size_t cmd_len = 15 + strlen(buf->b_p_fenc);
  eap->cmd = xmalloc(cmd_len);

  snprintf(eap->cmd, cmd_len, "e ++enc=%s", buf->b_p_fenc);
  eap->force_enc = 8;
  eap->bad_char = buf->b_bad_char;
  eap->force_ff = (unsigned char)(*buf->b_p_ff);

  eap->force_bin = buf->b_p_bin ? FORCE_BIN : FORCE_NOBIN;
  eap->read_edit = false;
  eap->forceit = false;
}

/// Set default or forced 'fileformat' and 'binary'.
void set_file_options(bool set_options, exarg_T *eap)
{
  // set default 'fileformat'
  if (set_options) {
    if (eap != NULL && eap->force_ff != 0) {
      set_fileformat(get_fileformat_force(curbuf, eap), OPT_LOCAL);
    } else if (*p_ffs != NUL) {
      set_fileformat(default_fileformat(), OPT_LOCAL);
    }
  }

  // set or reset 'binary'
  if (eap != NULL && eap->force_bin != 0) {
    int oldval = curbuf->b_p_bin;

    curbuf->b_p_bin = (eap->force_bin == FORCE_BIN);
    set_options_bin(oldval, curbuf->b_p_bin, OPT_LOCAL);
  }
}

/// Set forced 'fileencoding'.
void set_forced_fenc(exarg_T *eap)
{
  if (eap->force_enc == 0) {
    return;
  }

  char *fenc = enc_canonize(eap->cmd + eap->force_enc);
  set_option_direct(kOptFileencoding, CSTR_AS_OPTVAL(fenc), OPT_LOCAL, 0);
  xfree(fenc);
}

/// Find next fileencoding to use from 'fileencodings'.
/// "pp" points to fenc_next.  It's advanced to the next item.
/// When there are no more items, an empty string is returned and *pp is set to
/// NULL.
/// When *pp is not set to NULL, the result is in allocated memory and "alloced"
/// is set to true.
static char *next_fenc(char **pp, bool *alloced)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  char *r;

  *alloced = false;
  if (**pp == NUL) {
    *pp = NULL;
    return "";
  }
  char *p = vim_strchr(*pp, ',');
  if (p == NULL) {
    r = enc_canonize(*pp);
    *pp += strlen(*pp);
  } else {
    r = xmemdupz(*pp, (size_t)(p - *pp));
    *pp = p + 1;
    p = enc_canonize(r);
    xfree(r);
    r = p;
  }
  *alloced = true;
  return r;
}

/// Convert a file with the 'charconvert' expression.
/// This closes the file which is to be read, converts it and opens the
/// resulting file for reading.
///
/// @param fname  name of input file
/// @param fenc   converted from
/// @param fdp    in/out: file descriptor of file
///
/// @return       name of the resulting converted file (the caller should delete it after reading it).
///               Returns NULL if the conversion failed ("*fdp" is not set) .
static char *readfile_charconvert(char *fname, char *fenc, int *fdp)
{
  char *errmsg = NULL;

  char *tmpname = vim_tempname();
  if (tmpname == NULL) {
    errmsg = _("Can't find temp file for conversion");
  } else {
    close(*fdp);                // close the input file, ignore errors
    *fdp = -1;
    if (eval_charconvert(fenc, "utf-8",
                         fname, tmpname) == FAIL) {
      errmsg = _("Conversion with 'charconvert' failed");
    }
    if (errmsg == NULL && (*fdp = os_open(tmpname, O_RDONLY, 0)) < 0) {
      errmsg = _("can't read output of 'charconvert'");
    }
  }

  if (errmsg != NULL) {
    // Don't use emsg(), it breaks mappings, the retry with
    // another type of conversion might still work.
    msg(errmsg, 0);
    if (tmpname != NULL) {
      os_remove(tmpname);  // delete converted file
      XFREE_CLEAR(tmpname);
    }
  }

  // If the input file is closed, open it (caller should check for error).
  if (*fdp < 0) {
    *fdp = os_open(fname, O_RDONLY, 0);
  }

  return tmpname;
}

/// Read marks for the current buffer from the ShaDa file, when we support
/// buffer marks and the buffer has a name.
static void check_marks_read(void)
{
  if (!curbuf->b_marks_read && get_shada_parameter('\'') > 0
      && curbuf->b_ffname != NULL) {
    shada_read_marks();
  }

  // Always set b_marks_read; needed when 'shada' is changed to include
  // the ' parameter after opening a buffer.
  curbuf->b_marks_read = true;
}

/// Set the name of the current buffer.  Use when the buffer doesn't have a
/// name and a ":r" or ":w" command with a file name is used.
int set_rw_fname(char *fname, char *sfname)
{
  buf_T *buf = curbuf;

  // It's like the unnamed buffer is deleted....
  if (curbuf->b_p_bl) {
    apply_autocmds(EVENT_BUFDELETE, NULL, NULL, false, curbuf);
  }
  apply_autocmds(EVENT_BUFWIPEOUT, NULL, NULL, false, curbuf);
  if (aborting()) {         // autocmds may abort script processing
    return FAIL;
  }
  if (curbuf != buf) {
    // We are in another buffer now, don't do the renaming.
    emsg(_(e_auchangedbuf));
    return FAIL;
  }

  if (setfname(curbuf, fname, sfname, false) == OK) {
    curbuf->b_flags |= BF_NOTEDITED;
  }

  // ....and a new named one is created
  apply_autocmds(EVENT_BUFNEW, NULL, NULL, false, curbuf);
  if (curbuf->b_p_bl) {
    apply_autocmds(EVENT_BUFADD, NULL, NULL, false, curbuf);
  }
  if (aborting()) {         // autocmds may abort script processing
    return FAIL;
  }

  // Do filetype detection now if 'filetype' is empty.
  if (*curbuf->b_p_ft == NUL) {
    if (augroup_exists("filetypedetect")) {
      do_doautocmd("filetypedetect BufRead", false, NULL);
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
void add_quoted_fname(char *const ret_buf, const size_t buf_len, const buf_T *const buf,
                      const char *fname)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (fname == NULL) {
    fname = "-stdin-";
  }
  ret_buf[0] = '"';
  home_replace(buf, fname, ret_buf + 1, buf_len - 4, true);
  xstrlcat(ret_buf, "\" ", buf_len);
}

/// Append message for text mode to IObuff.
///
/// @param eol_type line ending type
///
/// @return true if something was appended.
bool msg_add_fileformat(int eol_type)
{
#ifndef USE_CRNL
  if (eol_type == EOL_DOS) {
    xstrlcat(IObuff, _("[dos]"), IOSIZE);
    return true;
  }
#endif
  if (eol_type == EOL_MAC) {
    xstrlcat(IObuff, _("[mac]"), IOSIZE);
    return true;
  }
#ifdef USE_CRNL
  if (eol_type == EOL_UNIX) {
    xstrlcat(IObuff, _("[unix]"), IOSIZE);
    return true;
  }
#endif
  return false;
}

/// Append line and character count to IObuff.
void msg_add_lines(int insert_space, linenr_T lnum, off_T nchars)
{
  char *p = IObuff + strlen(IObuff);

  if (insert_space) {
    *p++ = ' ';
  }
  if (shortmess(SHM_LINES)) {
    vim_snprintf(p, (size_t)(IOSIZE - (p - IObuff)), "%" PRId64 "L, %" PRId64 "B",
                 (int64_t)lnum, (int64_t)nchars);
  } else {
    vim_snprintf(p, (size_t)(IOSIZE - (p - IObuff)),
                 NGETTEXT("%" PRId64 " line, ", "%" PRId64 " lines, ", lnum),
                 (int64_t)lnum);
    p += strlen(p);
    vim_snprintf(p, (size_t)(IOSIZE - (p - IObuff)),
                 NGETTEXT("%" PRId64 " byte", "%" PRId64 " bytes", nchars),
                 (int64_t)nchars);
  }
}

bool time_differs(const FileInfo *file_info, int64_t mtime, int64_t mtime_ns)
  FUNC_ATTR_CONST
{
#if defined(__linux__) || defined(MSWIN)
  return file_info->stat.st_mtim.tv_nsec != mtime_ns
         // On a FAT filesystem, esp. under Linux, there are only 5 bits to store
         // the seconds.  Since the roundoff is done when flushing the inode, the
         // time may change unexpectedly by one second!!!
         || file_info->stat.st_mtim.tv_sec - mtime > 1
         || mtime - file_info->stat.st_mtim.tv_sec > 1;
#else
  return file_info->stat.st_mtim.tv_nsec != mtime_ns
         || file_info->stat.st_mtim.tv_sec != mtime;
#endif
}

/// Return true if file encoding "fenc" requires conversion from or to
/// 'encoding'.
///
/// @param fenc file encoding to check
///
/// @return true if conversion is required
bool need_conversion(const char *fenc)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  bool same_encoding;
  int fenc_flags;

  if (*fenc == NUL || strcmp(p_enc, fenc) == 0) {
    same_encoding = true;
    fenc_flags = 0;
  } else {
    // Ignore difference between "ansi" and "latin1", "ucs-4" and
    // "ucs-4be", etc.
    int enc_flags = get_fio_flags(p_enc);
    fenc_flags = get_fio_flags(fenc);
    same_encoding = (enc_flags != 0 && fenc_flags == enc_flags);
  }
  if (same_encoding) {
    // Specified file encoding matches UTF-8.
    return false;
  }

  // Encodings differ.  However, conversion is not needed when 'enc' is any
  // Unicode encoding and the file is UTF-8.
  return !(fenc_flags == FIO_UTF8);
}

/// Return the FIO_ flags needed for the internal conversion if 'name' was
/// unicode or latin1, otherwise 0. If "name" is an empty string,
/// use 'encoding'.
///
/// @param name string to check for encoding
int get_fio_flags(const char *name)
{
  if (*name == NUL) {
    name = p_enc;
  }
  int prop = enc_canon_props(name);
  if (prop & ENC_UNICODE) {
    if (prop & ENC_2BYTE) {
      if (prop & ENC_ENDIAN_L) {
        return FIO_UCS2 | FIO_ENDIAN_L;
      }
      return FIO_UCS2;
    }
    if (prop & ENC_4BYTE) {
      if (prop & ENC_ENDIAN_L) {
        return FIO_UCS4 | FIO_ENDIAN_L;
      }
      return FIO_UCS4;
    }
    if (prop & ENC_2WORD) {
      if (prop & ENC_ENDIAN_L) {
        return FIO_UTF16 | FIO_ENDIAN_L;
      }
      return FIO_UTF16;
    }
    return FIO_UTF8;
  }
  if (prop & ENC_LATIN1) {
    return FIO_LATIN1;
  }
  // must be ENC_DBCS, requires iconv()
  return 0;
}

/// Check for a Unicode BOM (Byte Order Mark) at the start of p[size].
/// "size" must be at least 2.
///
/// @return  the name of the encoding and set "*lenp" to the length or,
///          NULL when no BOM found.
static char *check_for_bom(const char *p_in, int size, int *lenp, int flags)
{
  const uint8_t *p = (const uint8_t *)p_in;
  char *name = NULL;
  int len = 2;

  if (p[0] == 0xef && p[1] == 0xbb && size >= 3 && p[2] == 0xbf
      && (flags == FIO_ALL || flags == FIO_UTF8 || flags == 0)) {
    name = "utf-8";             // EF BB BF
    len = 3;
  } else if (p[0] == 0xff && p[1] == 0xfe) {
    if (size >= 4 && p[2] == 0 && p[3] == 0
        && (flags == FIO_ALL || flags == (FIO_UCS4 | FIO_ENDIAN_L))) {
      name = "ucs-4le";         // FF FE 00 00
      len = 4;
    } else if (flags == (FIO_UCS2 | FIO_ENDIAN_L)) {
      name = "ucs-2le";         // FF FE
    } else if (flags == FIO_ALL
               || flags == (FIO_UTF16 | FIO_ENDIAN_L)) {
      // utf-16le is preferred, it also works for ucs-2le text
      name = "utf-16le";        // FF FE
    }
  } else if (p[0] == 0xfe && p[1] == 0xff
             && (flags == FIO_ALL || flags == FIO_UCS2 || flags ==
                 FIO_UTF16)) {
    // Default to utf-16, it works also for ucs-2 text.
    if (flags == FIO_UCS2) {
      name = "ucs-2";           // FE FF
    } else {
      name = "utf-16";          // FE FF
    }
  } else if (size >= 4 && p[0] == 0 && p[1] == 0 && p[2] == 0xfe
             && p[3] == 0xff && (flags == FIO_ALL || flags == FIO_UCS4)) {
    name = "ucs-4";             // 00 00 FE FF
    len = 4;
  }

  *lenp = len;
  return name;
}

/// Shorten filename of a buffer.
///
/// @param force  when true: Use full path from now on for files currently being
///               edited, both for file name and swap file name.  Try to shorten the file
///               names a bit, if safe to do so.
///               when false: Only try to shorten absolute file names.
///
/// For buffers that have buftype "nofile" or "scratch": never change the file
/// name.
void shorten_buf_fname(buf_T *buf, char *dirname, int force)
{
  if (buf->b_fname != NULL
      && !bt_nofilename(buf)
      && !path_with_url(buf->b_fname)
      && (force
          || buf->b_sfname == NULL
          || path_is_absolute(buf->b_sfname))) {
    if (buf->b_sfname != buf->b_ffname) {
      XFREE_CLEAR(buf->b_sfname);
    }
    char *p = path_shorten_fname(buf->b_ffname, dirname);
    if (p != NULL) {
      buf->b_sfname = xstrdup(p);
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
  char dirname[MAXPATHL];

  os_dirname(dirname, MAXPATHL);
  FOR_ALL_BUFFERS(buf) {
    shorten_buf_fname(buf, dirname, force);

    // Always make the swap file name a full path, a "nofile" buffer may
    // also have a swap file.
    mf_fullname(buf->b_ml.ml_mfp);
  }
  status_redraw_all();
  redraw_tabline = true;
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
    if (os_dirname(retval, MAXPATHL) == FAIL
        || strlen(retval) == 0) {
      xfree(retval);
      return NULL;
    }
    add_pathsep(retval);
    fnamelen = strlen(retval);
    prepend_dot = false;  // nothing to prepend a dot to
  } else {
    fnamelen = strlen(fname);
    retval = xmalloc(fnamelen + extlen + 3);
    strcpy(retval, fname);  // NOLINT(runtime/printf)
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
    ptr[BASENAMELEN] = NUL;
  }

  char *s = ptr + strlen(ptr);

  // Append the extension.
  // ext can start with '.' and cannot exceed 3 more characters.
  strcpy(s, ext);  // NOLINT(runtime/printf)

  char *e;
  // Prepend the dot if needed.
  if (prepend_dot && *(e = path_tail(retval)) != '.') {
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
bool vim_fgets(char *buf, int size, FILE *fp)
  FUNC_ATTR_NONNULL_ALL
{
  char *retval;

  assert(size > 0);
  buf[size - 2] = NUL;

  do {
    errno = 0;
    retval = fgets(buf, size, fp);
  } while (retval == NULL && errno == EINTR && ferror(fp));

  if (buf[size - 2] != NUL && buf[size - 2] != '\n') {
    char tbuf[200];

    buf[size - 1] = NUL;  // Truncate the line.

    // Now throw away the rest of the line:
    do {
      tbuf[sizeof(tbuf) - 2] = NUL;
      errno = 0;
      retval = fgets(tbuf, sizeof(tbuf), fp);
      if (retval == NULL && (feof(fp) || errno != EINTR)) {
        break;
      }
    } while (tbuf[sizeof(tbuf) - 2] != NUL && tbuf[sizeof(tbuf) - 2] != '\n');
  }
  return retval == NULL;
}

/// Read 2 bytes from "fd" and turn them into an int, MSB first.
///
/// @return  -1 when encountering EOF.
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
///
/// @return  -1 when encountering EOF.
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
///
/// @return  -1 when encountering EOF.
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
///
/// @return  -1 when encountering EOF.
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
///
/// @return  pointer to the string or NULL when unable to read that many bytes.
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
///
/// @return  false in case of an error.
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
///
/// @return  FAIL when the write failed.
int put_time(FILE *fd, time_t time_)
{
  uint8_t buf[8];
  time_to_bytes(time_, buf);
  return fwrite(buf, sizeof(uint8_t), ARRAY_SIZE(buf), fd) == 1 ? OK : FAIL;
}

static int rename_with_tmp(const char *const from, const char *const to)
{
  // Find a name that doesn't exist and is in the same directory.
  // Rename "from" to "tempname" and then rename "tempname" to "to".
  if (strlen(from) >= MAXPATHL - 5) {
    return -1;
  }

  char tempname[MAXPATHL + 1];
  STRCPY(tempname, from);
  for (int n = 123; n < 99999; n++) {
    char *tail = path_tail(tempname);
    snprintf(tail, (size_t)((MAXPATHL + 1) - (tail - tempname)), "%d", n);

    if (!os_path_exists(tempname)) {
      if (os_rename(from, tempname) == OK) {
        if (os_rename(tempname, to) == OK) {
          return 0;
        }
        // Strange, the second step failed.  Try moving the
        // file back and return failure.
        os_rename(tempname, from);
        return -1;
      }
      // If it fails for one temp name it will most likely fail
      // for any temp name, give up.
      return -1;
    }
  }
  return -1;
}

/// os_rename() only works if both files are on the same file system, this
/// function will (attempts to?) copy the file across if rename fails -- webb
///
/// @return  -1 for failure, 0 for success
int vim_rename(const char *from, const char *to)
  FUNC_ATTR_NONNULL_ALL
{
  bool use_tmp_file = false;

  // When the names are identical, there is nothing to do.  When they refer
  // to the same file (ignoring case and slash/backslash differences) but
  // the file name differs we need to go through a temp file.
  if (path_fnamecmp(from, to) == 0) {
    if (p_fic && (strcmp(path_tail(from), path_tail(to)) != 0)) {
      use_tmp_file = true;
    } else {
      return 0;
    }
  }

  // Fail if the "from" file doesn't exist. Avoids that "to" is deleted.
  FileInfo from_info;
  if (!os_fileinfo(from, &from_info)) {
    return -1;
  }

  // It's possible for the source and destination to be the same file.
  // This happens when "from" and "to" differ in case and are on a FAT32
  // filesystem. In that case go through a temp file name.
  FileInfo to_info;
  if (os_fileinfo(to, &to_info) && os_fileinfo_id_equal(&from_info,  &to_info)) {
    use_tmp_file = true;
  }

  if (use_tmp_file) {
    return rename_with_tmp(from, to);
  }

  // Delete the "to" file, this is required on some systems to make the
  // os_rename() work, on other systems it makes sure that we don't have
  // two files when the os_rename() fails.

  os_remove(to);

  // First try a normal rename, return if it works.
  if (os_rename(from, to) == OK) {
    return 0;
  }

  // Rename() failed, try copying the file.
  int ret = vim_copyfile(from, to);
  if (ret != OK) {
    return -1;
  }

  if (os_fileinfo(from, &from_info)) {
    os_remove(from);
  }

  return 0;
}

/// Create the new file with same permissions as the original.
/// Return FAIL for failure, OK for success.
int vim_copyfile(const char *from, const char *to)
{
  char *errmsg = NULL;

#ifdef HAVE_READLINK
  FileInfo from_info;
  if (os_fileinfo_link(from, &from_info) && S_ISLNK(from_info.stat.st_mode)) {
    int ret = -1;

    char linkbuf[MAXPATHL + 1];
    ssize_t len = readlink(from, linkbuf, MAXPATHL);
    if (len > 0) {
      linkbuf[len] = NUL;

      // Create link
      ret = symlink(linkbuf, to);
    }

    return ret == 0 ? OK : FAIL;
  }
#endif

  // For systems that support ACL: get the ACL from the original file.
  vim_acl_T acl = os_get_acl(from);

  if (os_copy(from, to, UV_FS_COPYFILE_EXCL) != 0) {
    os_free_acl(acl);
    return FAIL;
  }

  os_set_acl(to, acl);
  os_free_acl(acl);
  if (errmsg != NULL) {
    semsg(errmsg, to);
    return FAIL;
  }
  return OK;
}

static bool already_warned = false;

/// Check if any not hidden buffer has been changed.
/// Postpone the check if there are characters in the stuff buffer, a global
/// command is being executed, a mapping is being executed or an autocommand is
/// busy.
///
/// @param focus  called for GUI focus event
///
/// @return       true if some message was written (screen should be redrawn and cursor positioned).
int check_timestamps(int focus)
{
  // Don't check timestamps while system() or another low-level function may
  // cause us to lose and gain focus.
  if (no_check_timestamps > 0) {
    return false;
  }

  // Avoid doing a check twice.  The OK/Reload dialog can cause a focus
  // event and we would keep on checking if the file is steadily growing.
  // Do check again after typing something.
  if (focus && did_check_timestamps) {
    need_check_timestamps = true;
    return false;
  }

  int didit = 0;

  if (!stuff_empty() || global_busy || !typebuf_typed()
      || autocmd_busy || curbuf->b_ro_locked > 0
      || allbuf_lock > 0) {
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
        const int n = buf_check_timestamp(buf);
        didit = MAX(didit, n);
        if (n > 0 && !bufref_valid(&bufref)) {
          // Autocommands have removed the buffer, start at the first one again.
          buf = firstbuf;
          continue;
        }
      }
    }
    no_wait_return--;
    need_check_timestamps = false;
    if (need_wait_return && didit == 2) {
      // make sure msg isn't overwritten
      msg_puts("\n");
      ui_flush();
    }
  }
  return didit;
}

/// Move all the lines from buffer "frombuf" to buffer "tobuf".
///
/// @return  OK or FAIL.
///          When FAIL "tobuf" is incomplete and/or "frombuf" is not empty.
static int move_lines(buf_T *frombuf, buf_T *tobuf)
{
  buf_T *tbuf = curbuf;
  int retval = OK;

  // Copy the lines in "frombuf" to "tobuf".
  curbuf = tobuf;
  for (linenr_T lnum = 1; lnum <= frombuf->b_ml.ml_line_count; lnum++) {
    char *p = xstrdup(ml_get_buf(frombuf, lnum));
    if (ml_append(lnum - 1, p, 0, false) == FAIL) {
      xfree(p);
      retval = FAIL;
      break;
    }
    xfree(p);
  }

  // Delete all the lines in "frombuf".
  if (retval != FAIL) {
    curbuf = frombuf;
    for (linenr_T lnum = curbuf->b_ml.ml_line_count; lnum > 0; lnum--) {
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

/// Check if buffer "buf" has been changed.
/// Also check if the file for a new buffer unexpectedly appeared.
///
/// @return  1 if a changed buffer was found or,
///          2 if a message has been displayed or,
///          0 otherwise.
int buf_check_timestamp(buf_T *buf)
  FUNC_ATTR_NONNULL_ALL
{
  int retval = 0;
  char *mesg = NULL;
  char *mesg2 = "";
  bool helpmesg = false;

  enum {
    RELOAD_NONE,
    RELOAD_NORMAL,
    RELOAD_DETECT,
  } reload = RELOAD_NONE;

  bool can_reload = false;
  uint64_t orig_size = buf->b_orig_size;
  int orig_mode = buf->b_orig_mode;
  static bool busy = false;

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
      || busy) {
    return 0;
  }

  FileInfo file_info;
  bool file_info_ok;
  if (!(buf->b_flags & BF_NOTEDITED)
      && buf->b_mtime != 0
      && (!(file_info_ok = os_fileinfo(buf->b_ffname, &file_info))
          || time_differs(&file_info, buf->b_mtime, buf->b_mtime_ns)
          || (int)file_info.stat.st_mode != buf->b_orig_mode)) {
    const int64_t prev_b_mtime = buf->b_mtime;

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

    if (os_isdir(buf->b_fname)) {
      // Don't do anything for a directory.  Might contain the file explorer.
    } else if ((buf->b_p_ar >= 0 ? buf->b_p_ar : p_ar)
               && !bufIsChanged(buf) && file_info_ok) {
      // If 'autoread' is set, the buffer has no changes and the file still
      // exists, reload the buffer.  Use the buffer-local option value if it
      // was set, the global option value otherwise.
      reload = RELOAD_NORMAL;
    } else {
      char *reason;
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
      bool n = apply_autocmds(EVENT_FILECHANGEDSHELL, buf->b_fname, buf->b_fname, false, buf);
      allbuf_lock--;
      busy = false;
      if (n) {
        if (!bufref_valid(&bufref)) {
          emsg(_("E246: FileChangedShell autocommand deleted buffer"));
        }
        char *s = get_vim_var_str(VV_FCS_CHOICE);
        if (strcmp(s, "reload") == 0 && *reason != 'd') {
          reload = RELOAD_NORMAL;
        } else if (strcmp(s, "edit") == 0) {
          reload = RELOAD_DETECT;
        } else if (strcmp(s, "ask") == 0) {
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
            mesg =
              _("W12: Warning: File \"%s\" has changed and the buffer was changed in Vim as well");
            mesg2 = _("See \":help W12\" for more info.");
          } else if (reason[1] == 'h') {
            mesg = _("W11: Warning: File \"%s\" has changed since editing started");
            mesg2 = _("See \":help W11\" for more info.");
          } else if (*reason == 'm') {
            mesg = _("W16: Warning: Mode of file \"%s\" has changed since editing started");
            mesg2 = _("See \":help W16\" for more info.");
          } else {
            // Only timestamp changed, store it to avoid a warning
            // in check_mtime() later.
            buf->b_mtime_read = buf->b_mtime;
            buf->b_mtime_read_ns = buf->b_mtime_ns;
          }
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
    char *path = home_replace_save(buf, buf->b_fname);
    if (!helpmesg) {
      mesg2 = "";
    }
    const size_t tbuf_len = strlen(path) + strlen(mesg) + strlen(mesg2) + 2;
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
      switch (do_dialog(VIM_WARNING, _("Warning"), tbuf,
                        _("&OK\n&Load File\nLoad File &and Options"),
                        1, NULL, true)) {
      case 2:
        reload = RELOAD_NORMAL;
        break;
      case 3:
        reload = RELOAD_DETECT;
        break;
      }
    } else if (State > MODE_NORMAL_BUSY || (State & MODE_CMDLINE) || already_warned) {
      if (*mesg2 != NUL) {
        xstrlcat(tbuf, "; ", tbuf_len - 1);
        xstrlcat(tbuf, mesg2, tbuf_len - 1);
      }
      emsg(tbuf);
      retval = 2;
    } else {
      if (!autocmd_busy) {
        msg_start();
        msg_puts_hl(tbuf, HLF_E, true);
        if (*mesg2 != NUL) {
          msg_puts_hl(mesg2, HLF_W, true);
        }
        msg_clr_eos();
        msg_end();
        if (emsg_silent == 0 && !in_assert_fails) {
          ui_flush();
          // give the user some time to think about it
          os_delay(1004, true);

          // don't redraw and erase the message
          redraw_cmdline = false;
        }
      }
      already_warned = true;
    }

    xfree(path);
    xfree(tbuf);
  }

  if (reload != RELOAD_NONE) {
    // Reload the buffer.
    buf_reload(buf, orig_mode, reload == RELOAD_DETECT);
    if (buf->b_p_udf && buf->b_ffname != NULL) {
      uint8_t hash[UNDO_HASH_SIZE];

      // Any existing undo file is unusable, write it now.
      u_compute_hash(buf, hash);
      u_write_undo(NULL, false, buf, hash);
    }
  }

  // Trigger FileChangedShell when the file was changed in any way.
  if (bufref_valid(&bufref) && retval != 0) {
    apply_autocmds(EVENT_FILECHANGEDSHELLPOST, buf->b_fname, buf->b_fname, false, buf);
  }
  return retval;
}

/// Reload a buffer that is already loaded.
/// Used when the file was changed outside of Vim.
/// "orig_mode" is buf->b_orig_mode before the need for reloading was detected.
/// buf->b_orig_mode may have been reset already.
void buf_reload(buf_T *buf, int orig_mode, bool reload_options)
{
  exarg_T ea;
  int old_ro = buf->b_p_ro;
  buf_T *savebuf;
  bufref_T bufref;
  int saved = OK;
  aco_save_T aco;
  int flags = READ_NEW;

  // Set curwin/curbuf for "buf" and save some things.
  aucmd_prepbuf(&aco, buf);

  // Unless reload_options is set, we only want to read the text from the
  // file, not reset the syntax highlighting, clear marks, diff status, etc.
  // Force the fileformat and encoding to be the same.
  if (reload_options) {
    CLEAR_FIELD(ea);
  } else {
    prep_exarg(&ea, buf);
  }

  pos_T old_cursor = curwin->w_cursor;
  linenr_T old_topline = curwin->w_topline;

  if (p_ur < 0 || curbuf->b_ml.ml_line_count <= p_ur) {
    // Save all the text, so that the reload can be undone.
    // Sync first so that this is a separate undo-able action.
    u_sync(false);
    saved = u_savecommon(curbuf, 0, curbuf->b_ml.ml_line_count + 1, 0, true);
    flags |= READ_KEEP_UNDO;
  }

  // To behave like when a new file is edited (matters for
  // BufReadPost autocommands) we first need to delete the current
  // buffer contents.  But if reading the file fails we should keep
  // the old contents.  Can't use memory only, the file might be
  // too big.  Use a hidden buffer to move the buffer contents to.
  if (buf_is_empty(curbuf) || saved == FAIL) {
    savebuf = NULL;
  } else {
    // Allocate a buffer without putting it in the buffer list.
    savebuf = buflist_new(NULL, NULL, 1, BLN_DUMMY);
    set_bufref(&bufref, savebuf);
    if (savebuf != NULL && buf == curbuf) {
      // Open the memline.
      curbuf = savebuf;
      curwin->w_buffer = savebuf;
      saved = ml_open(curbuf);
      curbuf = buf;
      curwin->w_buffer = buf;
    }
    if (savebuf == NULL || saved == FAIL || buf != curbuf
        || move_lines(buf, savebuf) == FAIL) {
      semsg(_("E462: Could not prepare for reloading \"%s\""),
            buf->b_fname);
      saved = FAIL;
    }
  }

  if (saved == OK) {
    curbuf->b_flags |= BF_CHECK_RO;           // check for RO again
    curbuf->b_keep_filetype = true;           // don't detect 'filetype'
    if (readfile(buf->b_ffname, buf->b_fname, 0, 0,
                 (linenr_T)MAXLNUM, &ea, flags, shortmess(SHM_FILEINFO)) != OK) {
      if (!aborting()) {
        semsg(_("E321: Could not reload \"%s\""), buf->b_fname);
      }
      if (savebuf != NULL && bufref_valid(&bufref) && buf == curbuf) {
        // Put the text back from the save buffer.  First
        // delete any lines that readfile() added.
        while (!buf_is_empty(curbuf)) {
          if (ml_delete(buf->b_ml.ml_line_count, false) == FAIL) {
            break;
          }
        }
        move_lines(savebuf, buf);
      }
    } else if (buf == curbuf) {  // "buf" still valid.
      // Mark the buffer as unmodified and free undo info.
      unchanged(buf, true, true);
      if ((flags & READ_KEEP_UNDO) == 0) {
        u_clearallandblockfree(buf);
      } else {
        // Mark all undo states as changed.
        u_unchanged(curbuf);
      }
      buf_updates_unload(curbuf, true);
      curbuf->b_mod_set = true;
    }
  }
  xfree(ea.cmd);

  if (savebuf != NULL && bufref_valid(&bufref)) {
    wipe_buffer(savebuf, false);
  }

  // Invalidate diff info if necessary.
  diff_invalidate(curbuf);

  // Restore the topline and cursor position and check it (lines may
  // have been removed).
  curwin->w_topline = MIN(old_topline, curbuf->b_ml.ml_line_count);
  curwin->w_cursor = old_cursor;
  check_cursor(curwin);
  update_topline(curwin);
  curbuf->b_keep_filetype = false;

  // Update folds unless they are defined manually.
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp->w_buffer == curwin->w_buffer
        && !foldmethodIsManual(wp)) {
      foldUpdateAll(wp);
    }
  }

  // If the mode didn't change and 'readonly' was set, keep the old
  // value; the user probably used the ":view" command.  But don't
  // reset it, might have had a read error.
  if (orig_mode == curbuf->b_orig_mode) {
    curbuf->b_p_ro |= old_ro;
  }

  // Modelines must override settings done by autocommands.
  do_modelines(0);

  // restore curwin/curbuf and a few other things
  aucmd_restbuf(&aco);
  // Careful: autocommands may have made "buf" invalid!
}

void buf_store_file_info(buf_T *buf, FileInfo *file_info)
  FUNC_ATTR_NONNULL_ALL
{
  buf->b_mtime = file_info->stat.st_mtim.tv_sec;
  buf->b_mtime_ns = file_info->stat.st_mtim.tv_nsec;
  buf->b_orig_size = os_fileinfo_size(file_info);
  buf->b_orig_mode = (int)file_info->stat.st_mode;
}

/// Adjust the line with missing eol, used for the next write.
/// Used for do_filter(), when the input lines for the filter are deleted.
void write_lnum_adjust(linenr_T offset)
{
  if (curbuf->b_no_eol_lnum != 0) {     // only if there is a missing eol
    curbuf->b_no_eol_lnum += offset;
  }
}

#if defined(BACKSLASH_IN_FILENAME)
/// Convert all backslashes in fname to forward slashes in-place,
/// unless when it looks like a URL.
void forward_slash(char *fname)
{
  if (path_with_url(fname)) {
    return;
  }
  for (char *p = fname; *p != NUL; p++) {
    if (*p == '\\') {
      *p = '/';
    }
  }
}
#endif

/// Path to Nvim's own temp dir. Ends in a slash.
static char *vim_tempdir = NULL;
#ifdef HAVE_DIRFD_AND_FLOCK
DIR *vim_tempdir_dp = NULL;  ///< File descriptor of temp dir
#endif

/// Creates a directory for private use by this instance of Nvim, trying each of
/// `TEMP_DIR_NAMES` until one succeeds.
///
/// Only done once, the same directory is used for all temp files.
/// This method avoids security problems because of symlink attacks et al.
/// It's also a bit faster, because we only need to check for an existing
/// file when creating the directory and not for each temp file.
static void vim_mktempdir(void)
{
  static const char *temp_dirs[] = TEMP_DIR_NAMES;  // Try each of these until one succeeds.
  char tmp[TEMP_FILE_PATH_MAXLEN];
  char path[TEMP_FILE_PATH_MAXLEN];
  char user[40] = { 0 };

  os_get_username(user, sizeof(user));
  // Usernames may contain slashes! #19240
  memchrsub(user, '/', '_', sizeof(user));
  memchrsub(user, '\\', '_', sizeof(user));

  // Make sure the umask doesn't remove the executable bit.
  // "repl" has been reported to use "0177".
  mode_t umask_save = umask(0077);
  for (size_t i = 0; i < ARRAY_SIZE(temp_dirs); i++) {
    // Expand environment variables, leave room for "/tmp/nvim.<user>/XXXXXX/999999999".
    expand_env((char *)temp_dirs[i], tmp, TEMP_FILE_PATH_MAXLEN - 64);
    if (!os_isdir(tmp)) {
      if (strequal("$TMPDIR", temp_dirs[i])) {
        if (!os_getenv("TMPDIR")) {
          DLOG("$TMPDIR is unset");
        } else {
          WLOG("$TMPDIR tempdir not a directory (or does not exist): \"%s\"", tmp);
        }
      }
      continue;
    }

    // "/tmp/" exists, now try to create "/tmp/nvim.<user>/".
    add_pathsep(tmp);
    xstrlcat(tmp, "nvim.", sizeof(tmp));
    xstrlcat(tmp, user, sizeof(tmp));
    os_mkdir(tmp, 0700);  // Always create, to avoid a race.
    bool owned = os_file_owned(tmp);
    bool isdir = os_isdir(tmp);
#ifdef UNIX
    int perm = os_getperm(tmp);  // XDG_RUNTIME_DIR must be owned by the user, mode 0700.
    bool valid = isdir && owned && 0700 == (perm & 0777);
#else
    bool valid = isdir && owned;  // TODO(justinmk): Windows ACL?
#endif
    if (valid) {
      add_pathsep(tmp);
    } else {
      if (!owned) {
        ELOG("tempdir root not owned by current user (%s): %s", user, tmp);
      } else if (!isdir) {
        ELOG("tempdir root not a directory: %s", tmp);
      }
#ifdef UNIX
      if (0700 != (perm & 0777)) {
        ELOG("tempdir root has invalid permissions (%o): %s", perm, tmp);
      }
#endif
      // If our "root" tempdir is invalid or fails, proceed without "<user>/".
      // Else user1 could break user2 by creating "/tmp/nvim.user2/".
      tmp[strlen(tmp) - strlen(user)] = NUL;
    }

    // Now try to create "/tmp/nvim.<user>/XXXXXX".
    xstrlcat(tmp, "XXXXXX", sizeof(tmp));  // mkdtemp "template", will be replaced with random alphanumeric chars.
    int r = os_mkdtemp(tmp, path);
    if (r != 0) {
      WLOG("tempdir create failed: %s: %s", os_strerror(r), tmp);
      continue;
    }

    if (vim_settempdir(path)) {
      // Successfully created and set temporary directory so stop trying.
      break;
    }
    // Couldn't set `vim_tempdir` to `path` so remove created directory.
    os_rmdir(path);
  }
  umask(umask_save);
}

/// Core part of "readdir()" function.
/// Retrieve the list of files/directories of "path" into "gap".
///
/// @return  OK for success, FAIL for failure.
int readdir_core(garray_T *gap, const char *path, void *context, CheckItem checkitem)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  ga_init(gap, (int)sizeof(char *), 20);

  Directory dir;
  if (!os_scandir(&dir, path)) {
    smsg(0, _(e_notopen), path);
    return FAIL;
  }

  while (true) {
    const char *p = os_scandir_next(&dir);
    if (p == NULL) {
      break;
    }

    bool ignore = (p[0] == '.' && (p[1] == NUL || (p[1] == '.' && p[2] == NUL)));
    if (!ignore && checkitem != NULL) {
      varnumber_T r = checkitem(context, p);
      if (r < 0) {
        break;
      }
      if (r == 0) {
        ignore = true;
      }
    }

    if (!ignore) {
      ga_grow(gap, 1);
      ((char **)gap->ga_data)[gap->ga_len++] = xstrdup(p);
    }
  }

  os_closedir(&dir);

  if (gap->ga_len > 0) {
    sort_strings(gap->ga_data, gap->ga_len);
  }

  return OK;
}

/// Delete "name" and everything in it, recursively.
///
/// @param name  The path which should be deleted.
///
/// @return  0 for success, -1 if some file was not deleted.
int delete_recursive(const char *name)
  FUNC_ATTR_NONNULL_ALL
{
  int result = 0;

  if (os_isrealdir(name)) {
    char *exp = xstrdup(name);
    garray_T ga;
    if (readdir_core(&ga, exp, NULL, NULL) == OK) {
      for (int i = 0; i < ga.ga_len; i++) {
        vim_snprintf(NameBuff, MAXPATHL, "%s/%s", exp, ((char **)ga.ga_data)[i]);
        if (delete_recursive(NameBuff) != 0) {
          // Remember the failure but continue deleting any further
          // entries.
          result = -1;
        }
      }
      ga_clear_strings(&ga);
      if (os_rmdir(exp) != 0) {
        result = -1;
      }
    } else {
      result = -1;
    }
    xfree(exp);
  } else {
    // Delete symlink only.
    result = os_remove(name) == 0 ? 0 : -1;
  }

  return result;
}

#ifdef HAVE_DIRFD_AND_FLOCK
/// Open temporary directory and take file lock to prevent
/// to be auto-cleaned.
static void vim_opentempdir(void)
{
  if (vim_tempdir_dp != NULL) {
    return;
  }

  DIR *dp = opendir(vim_tempdir);
  if (dp == NULL) {
    return;
  }

  vim_tempdir_dp = dp;
  flock(dirfd(vim_tempdir_dp), LOCK_SH);
}

/// Close temporary directory - it automatically release file lock.
static void vim_closetempdir(void)
{
  if (vim_tempdir_dp == NULL) {
    return;
  }

  closedir(vim_tempdir_dp);
  vim_tempdir_dp = NULL;
}
#endif

/// Delete the temp directory and all files it contains.
void vim_deltempdir(void)
{
  if (vim_tempdir == NULL) {
    return;
  }

#ifdef HAVE_DIRFD_AND_FLOCK
  vim_closetempdir();
#endif
  // remove the trailing path separator
  path_tail(vim_tempdir)[-1] = NUL;
  delete_recursive(vim_tempdir);
  XFREE_CLEAR(vim_tempdir);
}

/// Gets path to Nvim's own temp dir (ending with slash).
///
/// Creates the directory on the first call.
char *vim_gettempdir(void)
{
  static int notfound = 0;
  if (vim_tempdir == NULL || !os_isdir(vim_tempdir)) {
    if (vim_tempdir != NULL) {
      notfound++;
      if (notfound == 1) {
        ELOG("tempdir disappeared (antivirus or broken cleanup job?): %s", vim_tempdir);
      }
      if (notfound > 1) {
        msg_schedule_semsg("E5431: tempdir disappeared (%d times)", notfound);
      }
      XFREE_CLEAR(vim_tempdir);
    }
    vim_mktempdir();
  }
  return vim_tempdir;
}

/// Sets Nvim's own temporary directory name to `tempdir`. This directory must
/// already exist. Expands the name to a full path and put it in `vim_tempdir`.
/// This avoids that using `:cd` would confuse us.
///
/// @param tempdir must be no longer than MAXPATHL.
///
/// @return false if we run out of memory.
static bool vim_settempdir(char *tempdir)
{
  char *buf = verbose_try_malloc(MAXPATHL + 2);
  if (buf == NULL) {
    return false;
  }

  vim_FullName(tempdir, buf, MAXPATHL, false);
  add_pathsep(buf);
  vim_tempdir = xstrdup(buf);
#ifdef HAVE_DIRFD_AND_FLOCK
  vim_opentempdir();
#endif
  xfree(buf);
  return true;
}

/// Return a unique name that can be used for a temp file.
///
/// @note The temp file is NOT created.
///
/// @return  pointer to the temp file name or NULL if Nvim can't create
///          temporary directory for its own temporary files.
char *vim_tempname(void)
{
  // Temp filename counter.
  static uint64_t temp_count;

  char *tempdir = vim_gettempdir();
  if (!tempdir) {
    return NULL;
  }

  // There is no need to check if the file exists, because we own the directory
  // and nobody else creates a file in it.
  char templ[TEMP_FILE_PATH_MAXLEN];
  snprintf(templ, TEMP_FILE_PATH_MAXLEN, "%s%" PRIu64, tempdir, temp_count++);
  return xstrdup(templ);
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
bool match_file_pat(char *pattern, regprog_T **prog, char *fname, char *sfname, char *tail,
                    int allow_dirs)
{
  regmatch_T regmatch;
  bool result = false;

  regmatch.rm_ic = p_fic;   // ignore case if 'fileignorecase' is set
  regmatch.regprog = prog != NULL ? *prog : vim_regcomp(pattern, RE_MAGIC);

  // Try for a match with the pattern with:
  // 1. the full file name, when the pattern has a '/'.
  // 2. the short file name, when the pattern has a '/'.
  // 3. the tail of the file name, when the pattern has no '/'.
  if (regmatch.regprog != NULL
      && ((allow_dirs
           && (vim_regexec(&regmatch, fname, 0)
               || (sfname != NULL
                   && vim_regexec(&regmatch, sfname, 0))))
          || (!allow_dirs && vim_regexec(&regmatch, tail, 0)))) {
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
bool match_file_list(char *list, char *sfname, char *ffname)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(1, 3)
{
  char *tail = path_tail(sfname);

  // try all patterns in 'wildignore'
  char *p = list;
  while (*p) {
    char buf[MAXPATHL];
    copy_option_part(&p, buf, ARRAY_SIZE(buf), ",");
    char allow_dirs;
    char *regpat = file_pat_to_reg_pat(buf, NULL, &allow_dirs, false);
    if (regpat == NULL) {
      break;
    }
    bool match = match_file_pat(regpat, NULL, ffname, sfname, tail, (int)allow_dirs);
    xfree(regpat);
    if (match) {
      return true;
    }
  }
  return false;
}

/// Convert the given pattern "pat" which has shell style wildcards in it, into
/// a regular expression, and return the result in allocated memory.  If there
/// is a directory path separator to be matched, then true is put in
/// allow_dirs, otherwise false is put there -- webb.
/// Handle backslashes before special characters, like "\*" and "\ ".
///
/// @param pat_end     first char after pattern or NULL
/// @param allow_dirs  Result passed back out in here
/// @param no_bslash   Don't use a backward slash as pathsep
///                    (only makes a difference when BACKSLASH_IN_FILENAME in defined)
///
/// @return            NULL on failure.
char *file_pat_to_reg_pat(const char *pat, const char *pat_end, char *allow_dirs, int no_bslash)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (allow_dirs != NULL) {
    *allow_dirs = false;
  }

  if (pat_end == NULL) {
    pat_end = pat + strlen(pat);
  }

  if (pat_end == pat) {
    return xstrdup("^$");
  }

  size_t size = 2;  // '^' at start, '$' at end.

  for (const char *p = pat; p < pat_end; p++) {
    switch (*p) {
    case '*':
    case '.':
    case ',':
    case '{':
    case '}':
    case '~':
      size += 2;                // extra backslash
      break;
#ifdef BACKSLASH_IN_FILENAME
    case '\\':
    case '/':
      size += 4;                // could become "[\/]"
      break;
#endif
    default:
      size++;
      break;
    }
  }
  char *reg_pat = xmalloc(size + 1);

  size_t i = 0;

  if (pat[0] == '*') {
    while (pat[0] == '*' && pat < pat_end - 1) {
      pat++;
    }
  } else {
    reg_pat[i++] = '^';
  }
  const char *endp = pat_end - 1;
  bool add_dollar = true;
  if (endp >= pat && *endp == '*') {
    while (endp - pat > 0 && *endp == '*') {
      endp--;
    }
    add_dollar = false;
  }
  int nested = 0;
  for (const char *p = pat; *p && nested >= 0 && p <= endp; p++) {
    switch (*p) {
    case '*':
      reg_pat[i++] = '.';
      reg_pat[i++] = '*';
      while (p[1] == '*') {  // "**" matches like "*"
        p++;
      }
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
      if (p[1] == NUL) {
        break;
      }
#ifdef BACKSLASH_IN_FILENAME
      if (!no_bslash) {
        // translate:
        // "\x" to "\\x"  e.g., "dir\file"
        // "\*" to "\\.*" e.g., "dir\*.c"
        // "\?" to "\\."  e.g., "dir\??.c"
        // "\+" to "\+"   e.g., "fileX\+.c"
        if ((vim_isfilec((uint8_t)p[1]) || p[1] == '*' || p[1] == '?')
            && p[1] != '+') {
          reg_pat[i++] = '[';
          reg_pat[i++] = '\\';
          reg_pat[i++] = '/';
          reg_pat[i++] = ']';
          if (allow_dirs != NULL) {
            *allow_dirs = true;
          }
          break;
        }
      }
#endif
      // Undo escaping from ExpandEscape():
      // foo\?bar -> foo?bar
      // foo\%bar -> foo%bar
      // foo\,bar -> foo,bar
      // foo\ bar -> foo bar
      // Don't unescape \, * and others that are also special in a
      // regexp.
      // An escaped { must be unescaped since we use magic not
      // verymagic.  Use "\\\{n,m\}"" to get "\{n,m}".
      if (*++p == '?' && (!BACKSLASH_IN_FILENAME_BOOL || no_bslash)) {
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
            && (!BACKSLASH_IN_FILENAME_BOOL || (!no_bslash || *p != '\\'))) {
          *allow_dirs = true;
        }
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
      if (allow_dirs != NULL) {
        *allow_dirs = true;
      }
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
      nested--;
      break;
    case ',':
      if (nested) {
        reg_pat[i++] = '\\';
        reg_pat[i++] = '|';
      } else {
        reg_pat[i++] = ',';
      }
      break;
    default:
      if (allow_dirs != NULL && vim_ispathsep(*p)) {
        *allow_dirs = true;
      }
      reg_pat[i++] = *p;
      break;
    }
  }
  if (add_dollar) {
    reg_pat[i++] = '$';
  }
  reg_pat[i] = NUL;
  if (nested != 0) {
    if (nested < 0) {
      emsg(_("E219: Missing {."));
    } else {
      emsg(_("E220: Missing }."));
    }
    XFREE_CLEAR(reg_pat);
  }
  return reg_pat;
}

#if defined(EINTR)

/// Version of read() that retries when interrupted by EINTR (possibly
/// by a SIGWINCH).
int read_eintr(int fd, void *buf, size_t bufsize)
{
  ssize_t ret;

  while (true) {
    ret = read(fd, buf, (unsigned)bufsize);
    if (ret >= 0 || errno != EINTR) {
      break;
    }
  }
  return (int)ret;
}

/// Version of write() that retries when interrupted by EINTR (possibly
/// by a SIGWINCH).
int write_eintr(int fd, void *buf, size_t bufsize)
{
  int ret = 0;

  // Repeat the write() so long it didn't fail, other than being interrupted
  // by a signal.
  while (ret < (int)bufsize) {
    ssize_t wlen = write(fd, (char *)buf + ret, (unsigned)(bufsize - (size_t)ret));
    if (wlen < 0) {
      if (errno != EINTR) {
        break;
      }
    } else {
      ret += (int)wlen;
    }
  }
  return ret;
}
#endif
