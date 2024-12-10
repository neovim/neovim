// bufwrite.c: functions for writing a buffer

#include <fcntl.h>
#include <iconv.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <uv.h>

#include "auto/config.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/bufwrite.h"
#include "nvim/change.h"
#include "nvim/drawscreen.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_eval.h"
#include "nvim/fileio.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/iconv_defs.h"
#include "nvim/input.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memline_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option.h"
#include "nvim/option_vars.h"
#include "nvim/os/fs.h"
#include "nvim/os/fs_defs.h"
#include "nvim/os/input.h"
#include "nvim/os/os_defs.h"
#include "nvim/path.h"
#include "nvim/pos_defs.h"
#include "nvim/sha256.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/undo_defs.h"
#include "nvim/vim_defs.h"

static const char *err_readonly = "is read-only (cannot override: \"W\" in 'cpoptions')";
static const char e_patchmode_cant_touch_empty_original_file[]
  = N_("E206: Patchmode: can't touch empty original file");
static const char e_write_error_conversion_failed_make_fenc_empty_to_override[]
  = N_("E513: Write error, conversion failed (make 'fenc' empty to override)");
static const char e_write_error_conversion_failed_in_line_nr_make_fenc_empty_to_override[]
  = N_("E513: Write error, conversion failed in line %" PRIdLINENR
       " (make 'fenc' empty to override)");
static const char e_write_error_file_system_full[]
  = N_("E514: Write error (file system full?)");
static const char e_no_matching_autocommands_for_buftype_str_buffer[]
  = N_("E676: No matching autocommands for buftype=%s buffer");

typedef struct {
  const char *num;
  char *msg;
  int arg;
  bool alloc;
} Error_T;

#define SMALLBUFSIZE 256     // size of emergency write buffer

// Structure to pass arguments from buf_write() to buf_write_bytes().
struct bw_info {
  int bw_fd;                      // file descriptor
  char *bw_buf;                   // buffer with data to be written
  int bw_len;                     // length of data
  int bw_flags;                   // FIO_ flags
  uint8_t bw_rest[CONV_RESTLEN];  // not converted bytes
  int bw_restlen;                 // nr of bytes in bw_rest[]
  int bw_first;                   // first write call
  char *bw_conv_buf;              // buffer for writing converted chars
  size_t bw_conv_buflen;          // size of bw_conv_buf
  int bw_conv_error;              // set for conversion error
  linenr_T bw_conv_error_lnum;    // first line with error or zero
  linenr_T bw_start_lnum;         // line number at start of buffer
  iconv_t bw_iconv_fd;            // descriptor for iconv() or -1
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "bufwrite.c.generated.h"
#endif

/// Convert a Unicode character to bytes.
///
/// @param c character to convert
/// @param[in,out] pp pointer to store the result at
/// @param flags FIO_ flags that specify which encoding to use
///
/// @return true for an error, false when it's OK.
static bool ucs2bytes(unsigned c, char **pp, int flags)
  FUNC_ATTR_NONNULL_ALL
{
  uint8_t *p = (uint8_t *)(*pp);
  bool error = false;

  if (flags & FIO_UCS4) {
    if (flags & FIO_ENDIAN_L) {
      *p++ = (uint8_t)c;
      *p++ = (uint8_t)(c >> 8);
      *p++ = (uint8_t)(c >> 16);
      *p++ = (uint8_t)(c >> 24);
    } else {
      *p++ = (uint8_t)(c >> 24);
      *p++ = (uint8_t)(c >> 16);
      *p++ = (uint8_t)(c >> 8);
      *p++ = (uint8_t)c;
    }
  } else if (flags & (FIO_UCS2 | FIO_UTF16)) {
    if (c >= 0x10000) {
      if (flags & FIO_UTF16) {
        // Make two words, ten bits of the character in each.  First
        // word is 0xd800 - 0xdbff, second one 0xdc00 - 0xdfff
        c -= 0x10000;
        if (c >= 0x100000) {
          error = true;
        }
        int cc = (int)(((c >> 10) & 0x3ff) + 0xd800);
        if (flags & FIO_ENDIAN_L) {
          *p++ = (uint8_t)cc;
          *p++ = (uint8_t)(cc >> 8);
        } else {
          *p++ = (uint8_t)(cc >> 8);
          *p++ = (uint8_t)cc;
        }
        c = (c & 0x3ff) + 0xdc00;
      } else {
        error = true;
      }
    }
    if (flags & FIO_ENDIAN_L) {
      *p++ = (uint8_t)c;
      *p++ = (uint8_t)(c >> 8);
    } else {
      *p++ = (uint8_t)(c >> 8);
      *p++ = (uint8_t)c;
    }
  } else {  // Latin1
    if (c >= 0x100) {
      error = true;
      *p++ = 0xBF;
    } else {
      *p++ = (uint8_t)c;
    }
  }

  *pp = (char *)p;
  return error;
}

static int buf_write_convert_with_iconv(struct bw_info *ip, char **bufp, int *lenp)
{
  const char *from;
  size_t fromlen;
  size_t tolen;

  int len = *lenp;

  // Convert with iconv().
  if (ip->bw_restlen > 0) {
    // Need to concatenate the remainder of the previous call and
    // the bytes of the current call.  Use the end of the
    // conversion buffer for this.
    fromlen = (size_t)len + (size_t)ip->bw_restlen;
    char *fp = ip->bw_conv_buf + ip->bw_conv_buflen - fromlen;
    memmove(fp, ip->bw_rest, (size_t)ip->bw_restlen);
    memmove(fp + ip->bw_restlen, *bufp, (size_t)len);
    from = fp;
    tolen = ip->bw_conv_buflen - fromlen;
  } else {
    from = *bufp;
    fromlen = (size_t)len;
    tolen = ip->bw_conv_buflen;
  }
  char *to = ip->bw_conv_buf;

  if (ip->bw_first) {
    size_t save_len = tolen;

    // output the initial shift state sequence
    iconv(ip->bw_iconv_fd, NULL, NULL, &to, &tolen);

    // There is a bug in iconv() on Linux (which appears to be
    // wide-spread) which sets "to" to NULL and messes up "tolen".
    if (to == NULL) {
      to = ip->bw_conv_buf;
      tolen = save_len;
    }
    ip->bw_first = false;
  }

  // If iconv() has an error or there is not enough room, fail.
  if ((iconv(ip->bw_iconv_fd, (void *)&from, &fromlen, &to, &tolen)
       == (size_t)-1 && ICONV_ERRNO != ICONV_EINVAL)
      || fromlen > CONV_RESTLEN) {
    ip->bw_conv_error = true;
    return FAIL;
  }

  // copy remainder to ip->bw_rest[] to be used for the next call.
  if (fromlen > 0) {
    memmove(ip->bw_rest, (void *)from, fromlen);
  }
  ip->bw_restlen = (int)fromlen;

  *bufp = ip->bw_conv_buf;
  *lenp = (int)(to - ip->bw_conv_buf);

  return OK;
}

static int buf_write_convert(struct bw_info *ip, char **bufp, int *lenp)
{
  int flags = ip->bw_flags;  // extra flags

  if (flags & FIO_UTF8) {
    // Convert latin1 in the buffer to UTF-8 in the file.
    char *p = ip->bw_conv_buf;              // translate to buffer
    for (int wlen = 0; wlen < *lenp; wlen++) {
      p += utf_char2bytes((uint8_t)(*bufp)[wlen], p);
    }
    *bufp = ip->bw_conv_buf;
    *lenp = (int)(p - ip->bw_conv_buf);
  } else if (flags & (FIO_UCS4 | FIO_UTF16 | FIO_UCS2 | FIO_LATIN1)) {
    unsigned c;
    int n = 0;
    // Convert UTF-8 bytes in the buffer to UCS-2, UCS-4, UTF-16 or
    // Latin1 chars in the file.
    // translate in-place (can only get shorter) or to buffer
    char *p = flags & FIO_LATIN1 ? *bufp : ip->bw_conv_buf;
    for (int wlen = 0; wlen < *lenp; wlen += n) {
      if (wlen == 0 && ip->bw_restlen != 0) {
        // Use remainder of previous call.  Append the start of
        // buf[] to get a full sequence.  Might still be too
        // short!
        int l = MIN(*lenp, CONV_RESTLEN - ip->bw_restlen);
        memmove(ip->bw_rest + ip->bw_restlen, *bufp, (size_t)l);
        n = utf_ptr2len_len((char *)ip->bw_rest, ip->bw_restlen + l);
        if (n > ip->bw_restlen + *lenp) {
          // We have an incomplete byte sequence at the end to
          // be written.  We can't convert it without the
          // remaining bytes.  Keep them for the next call.
          if (ip->bw_restlen + *lenp > CONV_RESTLEN) {
            return FAIL;
          }
          ip->bw_restlen += *lenp;
          break;
        }
        c = (n > 1) ? (unsigned)utf_ptr2char((char *)ip->bw_rest)
                    : ip->bw_rest[0];
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
        n = utf_ptr2len_len(*bufp + wlen, *lenp - wlen);
        if (n > *lenp - wlen) {
          // We have an incomplete byte sequence at the end to
          // be written.  We can't convert it without the
          // remaining bytes.  Keep them for the next call.
          if (*lenp - wlen > CONV_RESTLEN) {
            return FAIL;
          }
          ip->bw_restlen = *lenp - wlen;
          memmove(ip->bw_rest, *bufp + wlen,
                  (size_t)ip->bw_restlen);
          break;
        }
        c = n > 1 ? (unsigned)utf_ptr2char(*bufp + wlen)
                  : (uint8_t)(*bufp)[wlen];
      }

      if (ucs2bytes(c, &p, flags) && !ip->bw_conv_error) {
        ip->bw_conv_error = true;
        ip->bw_conv_error_lnum = ip->bw_start_lnum;
      }
      if (c == NL) {
        ip->bw_start_lnum++;
      }
    }
    if (flags & FIO_LATIN1) {
      *lenp = (int)(p - *bufp);
    } else {
      *bufp = ip->bw_conv_buf;
      *lenp = (int)(p - ip->bw_conv_buf);
    }
  }

  if (ip->bw_iconv_fd != (iconv_t)-1) {
    if (buf_write_convert_with_iconv(ip, bufp, lenp) == FAIL) {
      return FAIL;
    }
  }

  return OK;
}

/// Call write() to write a number of bytes to the file.
/// Handles 'encoding' conversion.
///
/// @return  FAIL for failure, OK otherwise.
static int buf_write_bytes(struct bw_info *ip)
{
  char *buf = ip->bw_buf;    // data to write
  int len = ip->bw_len;      // length of data
  int flags = ip->bw_flags;  // extra flags

  // Skip conversion when writing the BOM.
  if (!(flags & FIO_NOCONVERT)) {
    if (buf_write_convert(ip, &buf, &len) == FAIL) {
      return FAIL;
    }
  }

  if (ip->bw_fd < 0) {
    // Only checking conversion, which is OK if we get here.
    return OK;
  }
  int wlen = write_eintr(ip->bw_fd, buf, (size_t)len);
  return (wlen < len) ? FAIL : OK;
}

/// Check modification time of file, before writing to it.
/// The size isn't checked, because using a tool like "gzip" takes care of
/// using the same timestamp but can't set the size.
static int check_mtime(buf_T *buf, FileInfo *file_info)
{
  if (buf->b_mtime_read != 0
      && time_differs(file_info, buf->b_mtime_read, buf->b_mtime_read_ns)) {
    msg_scroll = true;  // Don't overwrite messages here.
    msg_silent = 0;     // Must give this prompt.
    // Don't use emsg() here, don't want to flush the buffers.
    msg(_("WARNING: The file has been changed since reading it!!!"), HLF_E);
    if (ask_yesno(_("Do you really want to write to it"), true) == 'n') {
      return FAIL;
    }
    msg_scroll = false;  // Always overwrite the file message now.
  }
  return OK;
}

/// Generate a BOM in "buf[4]" for encoding "name".
///
/// @return  the length of the BOM (zero when no BOM).
static int make_bom(char *buf_in, char *name)
{
  uint8_t *buf = (uint8_t *)buf_in;
  int flags = get_fio_flags(name);

  // Can't put a BOM in a non-Unicode file.
  if (flags == FIO_LATIN1 || flags == 0) {
    return 0;
  }

  if (flags == FIO_UTF8) {      // UTF-8
    buf[0] = 0xef;
    buf[1] = 0xbb;
    buf[2] = 0xbf;
    return 3;
  }
  char *p = (char *)buf;
  ucs2bytes(0xfeff, &p, flags);
  return (int)((uint8_t *)p - buf);
}

static int buf_write_do_autocmds(buf_T *buf, char **fnamep, char **sfnamep, char **ffnamep,
                                 linenr_T start, linenr_T *endp, exarg_T *eap, bool append,
                                 bool filtering, bool reset_changed, bool overwriting, bool whole,
                                 const pos_T orig_start, const pos_T orig_end)
{
  linenr_T old_line_count = buf->b_ml.ml_line_count;
  int msg_save = msg_scroll;

  aco_save_T aco;
  bool did_cmd = false;
  bool nofile_err = false;
  bool empty_memline = buf->b_ml.ml_mfp == NULL;
  bufref_T bufref;

  char *sfname = *sfnamep;

  // Apply PRE autocommands.
  // Set curbuf to the buffer to be written.
  // Careful: The autocommands may call buf_write() recursively!
  bool buf_ffname = *ffnamep == buf->b_ffname;
  bool buf_sfname = sfname == buf->b_sfname;
  bool buf_fname_f = *fnamep == buf->b_ffname;
  bool buf_fname_s = *fnamep == buf->b_sfname;

  // Set curwin/curbuf to buf and save a few things.
  aucmd_prepbuf(&aco, buf);
  set_bufref(&bufref, buf);

  if (append) {
    did_cmd = apply_autocmds_exarg(EVENT_FILEAPPENDCMD, sfname, sfname, false, curbuf, eap);
    if (!did_cmd) {
      if (overwriting && bt_nofilename(curbuf)) {
        nofile_err = true;
      } else {
        apply_autocmds_exarg(EVENT_FILEAPPENDPRE,
                             sfname, sfname, false, curbuf, eap);
      }
    }
  } else if (filtering) {
    apply_autocmds_exarg(EVENT_FILTERWRITEPRE,
                         NULL, sfname, false, curbuf, eap);
  } else if (reset_changed && whole) {
    bool was_changed = curbufIsChanged();

    did_cmd = apply_autocmds_exarg(EVENT_BUFWRITECMD, sfname, sfname, false, curbuf, eap);
    if (did_cmd) {
      if (was_changed && !curbufIsChanged()) {
        // Written everything correctly and BufWriteCmd has reset
        // 'modified': Correct the undo information so that an
        // undo now sets 'modified'.
        u_unchanged(curbuf);
        u_update_save_nr(curbuf);
      }
    } else {
      if (overwriting && bt_nofilename(curbuf)) {
        nofile_err = true;
      } else {
        apply_autocmds_exarg(EVENT_BUFWRITEPRE,
                             sfname, sfname, false, curbuf, eap);
      }
    }
  } else {
    did_cmd = apply_autocmds_exarg(EVENT_FILEWRITECMD, sfname, sfname, false, curbuf, eap);
    if (!did_cmd) {
      if (overwriting && bt_nofilename(curbuf)) {
        nofile_err = true;
      } else {
        apply_autocmds_exarg(EVENT_FILEWRITEPRE,
                             sfname, sfname, false, curbuf, eap);
      }
    }
  }

  // restore curwin/curbuf and a few other things
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
      || aborting()) {
    if (buf != NULL && (cmdmod.cmod_flags & CMOD_LOCKMARKS)) {
      // restore the original '[ and '] positions
      buf->b_op_start = orig_start;
      buf->b_op_end = orig_end;
    }

    no_wait_return--;
    msg_scroll = msg_save;
    if (nofile_err) {
      semsg(_(e_no_matching_autocommands_for_buftype_str_buffer), curbuf->b_p_bt);
    }

    if (nofile_err || aborting()) {
      // An aborting error, interrupt or exception in the
      // autocommands.
      return FAIL;
    }
    if (did_cmd) {
      if (buf == NULL) {
        // The buffer was deleted.  We assume it was written
        // (can't retry anyway).
        return OK;
      }
      if (overwriting) {
        // Assume the buffer was written, update the timestamp.
        ml_timestamp(buf);
        if (append) {
          buf->b_flags &= ~BF_NEW;
        } else {
          buf->b_flags &= ~BF_WRITE_MASK;
        }
      }
      if (reset_changed && buf->b_changed && !append
          && (overwriting || vim_strchr(p_cpo, CPO_PLUS) != NULL)) {
        // Buffer still changed, the autocommands didn't work properly.
        return FAIL;
      }
      return OK;
    }
    if (!aborting()) {
      emsg(_("E203: Autocommands deleted or unloaded buffer to be written"));
    }
    return FAIL;
  }

  // The autocommands may have changed the number of lines in the file.
  // When writing the whole file, adjust the end.
  // When writing part of the file, assume that the autocommands only
  // changed the number of lines that are to be written (tricky!).
  if (buf->b_ml.ml_line_count != old_line_count) {
    if (whole) {                                              // write all
      *endp = buf->b_ml.ml_line_count;
    } else if (buf->b_ml.ml_line_count > old_line_count) {           // more lines
      *endp += buf->b_ml.ml_line_count - old_line_count;
    } else {                                                    // less lines
      *endp -= old_line_count - buf->b_ml.ml_line_count;
      if (*endp < start) {
        no_wait_return--;
        msg_scroll = msg_save;
        emsg(_("E204: Autocommand changed number of lines in unexpected way"));
        return FAIL;
      }
    }
  }

  // The autocommands may have changed the name of the buffer, which may
  // be kept in fname, ffname and sfname.
  if (buf_ffname) {
    *ffnamep = buf->b_ffname;
  }
  if (buf_sfname) {
    *sfnamep = buf->b_sfname;
  }
  if (buf_fname_f) {
    *fnamep = buf->b_ffname;
  }
  if (buf_fname_s) {
    *fnamep = buf->b_sfname;
  }
  return NOTDONE;
}

static void buf_write_do_post_autocmds(buf_T *buf, char *fname, exarg_T *eap, bool append,
                                       bool filtering, bool reset_changed, bool whole)
{
  aco_save_T aco;

  curbuf->b_no_eol_lnum = 0;      // in case it was set by the previous read

  // Apply POST autocommands.
  // Careful: The autocommands may call buf_write() recursively!
  aucmd_prepbuf(&aco, buf);

  if (append) {
    apply_autocmds_exarg(EVENT_FILEAPPENDPOST, fname, fname,
                         false, curbuf, eap);
  } else if (filtering) {
    apply_autocmds_exarg(EVENT_FILTERWRITEPOST, NULL, fname,
                         false, curbuf, eap);
  } else if (reset_changed && whole) {
    apply_autocmds_exarg(EVENT_BUFWRITEPOST, fname, fname,
                         false, curbuf, eap);
  } else {
    apply_autocmds_exarg(EVENT_FILEWRITEPOST, fname, fname,
                         false, curbuf, eap);
  }

  // restore curwin/curbuf and a few other things
  aucmd_restbuf(&aco);
}

static inline Error_T set_err_num(const char *num, const char *msg)
{
  return (Error_T){ .num = num, .msg = (char *)msg, .arg = 0 };
}

static inline Error_T set_err(const char *msg)
{
  return (Error_T){ .num = NULL, .msg = (char *)msg, .arg = 0 };
}

static inline Error_T set_err_arg(const char *msg, int arg)
{
  return (Error_T){ .num = NULL, .msg = (char *)msg, .arg = arg };
}

static void emit_err(Error_T *e)
{
  if (e->num != NULL) {
    if (e->arg != 0) {
      semsg("%s: %s%s: %s", e->num, IObuff, e->msg, os_strerror(e->arg));
    } else {
      semsg("%s: %s%s", e->num, IObuff, e->msg);
    }
  } else if (e->arg != 0) {
    semsg(e->msg, os_strerror(e->arg));
  } else {
    emsg(e->msg);
  }
  if (e->alloc) {
    xfree(e->msg);
  }
}

#if defined(UNIX)

static int get_fileinfo_os(char *fname, FileInfo *file_info_old, bool overwriting, int *perm,
                           bool *device, bool *newfile, Error_T *err)
{
  *perm = -1;
  if (!os_fileinfo(fname, file_info_old)) {
    *newfile = true;
  } else {
    *perm = (int)file_info_old->stat.st_mode;
    if (!S_ISREG(file_info_old->stat.st_mode)) {             // not a file
      if (S_ISDIR(file_info_old->stat.st_mode)) {
        *err = set_err_num("E502", _("is a directory"));
        return FAIL;
      }
      if (os_nodetype(fname) != NODE_WRITABLE) {
        *err = set_err_num("E503", _("is not a file or writable device"));
        return FAIL;
      }
      // It's a device of some kind (or a fifo) which we can write to
      // but for which we can't make a backup.
      *device = true;
      *newfile = true;
      *perm = -1;
    }
  }
  return OK;
}

#else

static int get_fileinfo_os(char *fname, FileInfo *file_info_old, bool overwriting, int *perm,
                           bool *device, bool *newfile, Error_T *err)
{
  // Check for a writable device name.
  char nodetype = fname == NULL ? NODE_OTHER : (char)os_nodetype(fname);
  if (nodetype == NODE_OTHER) {
    *err = set_err_num("E503", _("is not a file or writable device"));
    return FAIL;
  }
  if (nodetype == NODE_WRITABLE) {
    *device = true;
    *newfile = true;
    *perm = -1;
  } else {
    *perm = os_getperm(fname);
    if (*perm < 0) {
      *newfile = true;
    } else if (os_isdir(fname)) {
      *err = set_err_num("E502", _("is a directory"));
      return FAIL;
    }
    if (overwriting) {
      os_fileinfo(fname, file_info_old);
    }
  }
  return OK;
}

#endif

/// @param buf
/// @param fname          File name
/// @param overwriting
/// @param forceit
/// @param[out] file_info_old
/// @param[out] perm
/// @param[out] device
/// @param[out] newfile
/// @param[out] readonly
static int get_fileinfo(buf_T *buf, char *fname, bool overwriting, bool forceit,
                        FileInfo *file_info_old, int *perm, bool *device, bool *newfile,
                        bool *readonly, Error_T *err)
{
  if (get_fileinfo_os(fname, file_info_old, overwriting, perm, device, newfile, err) == FAIL) {
    return FAIL;
  }

  *readonly = false;  // overwritten file is read-only

  if (!*device && !*newfile) {
    // Check if the file is really writable (when renaming the file to
    // make a backup we won't discover it later).
    *readonly = !os_file_is_writable(fname);

    if (!forceit && *readonly) {
      if (vim_strchr(p_cpo, CPO_FWRITE) != NULL) {
        *err = set_err_num("E504", _(err_readonly));
      } else {
        *err = set_err_num("E505", _("is read-only (add ! to override)"));
      }
      return FAIL;
    }

    // If 'forceit' is false, check if the timestamp hasn't changed since reading the file.
    if (overwriting && !forceit) {
      int retval = check_mtime(buf, file_info_old);
      if (retval == FAIL) {
        return FAIL;
      }
    }
  }
  return OK;
}

static int buf_write_make_backup(char *fname, bool append, FileInfo *file_info_old, vim_acl_T acl,
                                 int perm, unsigned bkc, bool file_readonly, bool forceit,
                                 bool *backup_copyp, char **backupp, Error_T *err)
{
  FileInfo file_info;
  const bool no_prepend_dot = false;

  if ((bkc & kOptBkcFlagYes) || append) {       // "yes"
    *backup_copyp = true;
  } else if ((bkc & kOptBkcFlagAuto)) {          // "auto"
    // Don't rename the file when:
    // - it's a hard link
    // - it's a symbolic link
    // - we don't have write permission in the directory
    if (os_fileinfo_hardlinks(file_info_old) > 1
        || !os_fileinfo_link(fname, &file_info)
        || !os_fileinfo_id_equal(&file_info, file_info_old)) {
      *backup_copyp = true;
    } else {
      // Check if we can create a file and set the owner/group to
      // the ones from the original file.
      // First find a file name that doesn't exist yet (use some
      // arbitrary numbers).
      xstrlcpy(IObuff, fname, IOSIZE);
      for (int i = 4913;; i += 123) {
        char *tail = path_tail(IObuff);
        size_t size = (size_t)(tail - IObuff);
        snprintf(tail, IOSIZE - size, "%d", i);
        if (!os_fileinfo_link(IObuff, &file_info)) {
          break;
        }
      }
      int fd = os_open(IObuff,
                       O_CREAT|O_WRONLY|O_EXCL|O_NOFOLLOW, perm);
      if (fd < 0) {           // can't write in directory
        *backup_copyp = true;
      } else {
#ifdef UNIX
        os_fchown(fd, (uv_uid_t)file_info_old->stat.st_uid, (uv_gid_t)file_info_old->stat.st_gid);
        if (!os_fileinfo(IObuff, &file_info)
            || file_info.stat.st_uid != file_info_old->stat.st_uid
            || file_info.stat.st_gid != file_info_old->stat.st_gid
            || (int)file_info.stat.st_mode != perm) {
          *backup_copyp = true;
        }
#endif
        // Close the file before removing it, on MS-Windows we
        // can't delete an open file.
        close(fd);
        os_remove(IObuff);
      }
    }
  }

  // Break symlinks and/or hardlinks if we've been asked to.
  if ((bkc & kOptBkcFlagBreaksymlink) || (bkc & kOptBkcFlagBreakhardlink)) {
#ifdef UNIX
    bool file_info_link_ok = os_fileinfo_link(fname, &file_info);

    // Symlinks.
    if ((bkc & kOptBkcFlagBreaksymlink)
        && file_info_link_ok
        && !os_fileinfo_id_equal(&file_info, file_info_old)) {
      *backup_copyp = false;
    }

    // Hardlinks.
    if ((bkc & kOptBkcFlagBreakhardlink)
        && os_fileinfo_hardlinks(file_info_old) > 1
        && (!file_info_link_ok
            || os_fileinfo_id_equal(&file_info, file_info_old))) {
      *backup_copyp = false;
    }
#endif
  }

  // make sure we have a valid backup extension to use
  char *backup_ext = *p_bex == NUL ? ".bak" : p_bex;

  if (*backup_copyp) {
    bool some_error = false;

    // Try to make the backup in each directory in the 'bdir' option.
    //
    // Unix semantics has it, that we may have a writable file,
    // that cannot be recreated with a simple open(..., O_CREAT, ) e.g:
    //  - the directory is not writable,
    //  - the file may be a symbolic link,
    //  - the file may belong to another user/group, etc.
    //
    // For these reasons, the existing writable file must be truncated
    // and reused. Creation of a backup COPY will be attempted.
    char *dirp = p_bdir;
    while (*dirp) {
      // Isolate one directory name, using an entry in 'bdir'.
      size_t dir_len = copy_option_part(&dirp, IObuff, IOSIZE, ",");
      char *p = IObuff + dir_len;
      if (*dirp == NUL && !os_isdir(IObuff)) {
        int ret;
        char *failed_dir;
        if ((ret = os_mkdir_recurse(IObuff, 0755, &failed_dir, NULL)) != 0) {
          semsg(_("E303: Unable to create directory \"%s\" for backup file: %s"),
                failed_dir, os_strerror(ret));
          xfree(failed_dir);
        }
      }
      if (after_pathsep(IObuff, p) && p[-1] == p[-2]) {
        // Ends with '//', Use Full path
        if ((p = make_percent_swname(IObuff, p, fname))
            != NULL) {
          *backupp = modname(p, backup_ext, no_prepend_dot);
          xfree(p);
        }
      }

      char *rootname = get_file_in_dir(fname, IObuff);
      if (rootname == NULL) {
        some_error = true;                // out of memory
        goto nobackup;
      }

      FileInfo file_info_new;
      {
        //
        // Make the backup file name.
        //
        if (*backupp == NULL) {
          *backupp = modname(rootname, backup_ext, no_prepend_dot);
        }

        if (*backupp == NULL) {
          xfree(rootname);
          some_error = true;                          // out of memory
          goto nobackup;
        }

        // Check if backup file already exists.
        if (os_fileinfo(*backupp, &file_info_new)) {
          if (os_fileinfo_id_equal(&file_info_new, file_info_old)) {
            //
            // Backup file is same as original file.
            // May happen when modname() gave the same file back (e.g. silly
            // link). If we don't check here, we either ruin the file when
            // copying or erase it after writing.
            //
            XFREE_CLEAR(*backupp);              // no backup file to delete
          } else if (!p_bk) {
            // We are not going to keep the backup file, so don't
            // delete an existing one, and try to use another name instead.
            // Change one character, just before the extension.
            //
            char *wp = *backupp + strlen(*backupp) - 1 - strlen(backup_ext);
            wp = MAX(wp, *backupp);  // empty file name ???
            *wp = 'z';
            while (*wp > 'a' && os_fileinfo(*backupp, &file_info_new)) {
              (*wp)--;
            }
            // They all exist??? Must be something wrong.
            if (*wp == 'a') {
              XFREE_CLEAR(*backupp);
            }
          }
        }
      }
      xfree(rootname);

      // Try to create the backup file
      if (*backupp != NULL) {
        // remove old backup, if present
        os_remove(*backupp);

        // copy the file
        if (os_copy(fname, *backupp, UV_FS_COPYFILE_FICLONE) != 0) {
          *err = set_err(_("E509: Cannot create backup file (add ! to override)"));
          XFREE_CLEAR(*backupp);
          *backupp = NULL;
          continue;
        }

        // set file protection same as original file, but
        // strip s-bit.
        os_setperm(*backupp, perm & 0777);

#ifdef UNIX
        // Try to set the group of the backup same as the original file. If
        // this fails, set the protection bits for the group same as the
        // protection bits for others.
        if (file_info_new.stat.st_gid != file_info_old->stat.st_gid
            && os_chown(*backupp, (uv_uid_t)-1, (uv_gid_t)file_info_old->stat.st_gid) != 0) {
          os_setperm(*backupp, (perm & 0707) | ((perm & 07) << 3));
        }
        os_file_settime(*backupp,
                        (double)file_info_old->stat.st_atim.tv_sec,
                        (double)file_info_old->stat.st_mtim.tv_sec);
#endif

        os_set_acl(*backupp, acl);
#ifdef HAVE_XATTR
        os_copy_xattr(fname, *backupp);
#endif
        *err = set_err(NULL);
        break;
      }
    }

nobackup:
    if (*backupp == NULL && err->msg == NULL) {
      *err = set_err(_("E509: Cannot create backup file (add ! to override)"));
    }
    // Ignore errors when forceit is true.
    if ((some_error || err->msg != NULL) && !forceit) {
      return FAIL;
    }
    *err = set_err(NULL);
  } else {
    // Make a backup by renaming the original file.

    // If 'cpoptions' includes the "W" flag, we don't want to
    // overwrite a read-only file.  But rename may be possible
    // anyway, thus we need an extra check here.
    if (file_readonly && vim_strchr(p_cpo, CPO_FWRITE) != NULL) {
      *err = set_err_num("E504", _(err_readonly));
      return FAIL;
    }

    // Form the backup file name - change path/fo.o.h to
    // path/fo.o.h.bak Try all directories in 'backupdir', first one
    // that works is used.
    char *dirp = p_bdir;
    while (*dirp) {
      // Isolate one directory name and make the backup file name.
      size_t dir_len = copy_option_part(&dirp, IObuff, IOSIZE, ",");
      char *p = IObuff + dir_len;
      if (*dirp == NUL && !os_isdir(IObuff)) {
        int ret;
        char *failed_dir;
        if ((ret = os_mkdir_recurse(IObuff, 0755, &failed_dir, NULL)) != 0) {
          semsg(_("E303: Unable to create directory \"%s\" for backup file: %s"),
                failed_dir, os_strerror(ret));
          xfree(failed_dir);
        }
      }
      if (after_pathsep(IObuff, p) && p[-1] == p[-2]) {
        // path ends with '//', use full path
        if ((p = make_percent_swname(IObuff, p, fname))
            != NULL) {
          *backupp = modname(p, backup_ext, no_prepend_dot);
          xfree(p);
        }
      }

      if (*backupp == NULL) {
        char *rootname = get_file_in_dir(fname, IObuff);
        if (rootname == NULL) {
          *backupp = NULL;
        } else {
          *backupp = modname(rootname, backup_ext, no_prepend_dot);
          xfree(rootname);
        }
      }

      if (*backupp != NULL) {
        // If we are not going to keep the backup file, don't
        // delete an existing one, try to use another name.
        // Change one character, just before the extension.
        if (!p_bk && os_path_exists(*backupp)) {
          p = *backupp + strlen(*backupp) - 1 - strlen(backup_ext);
          p = MAX(p, *backupp);  // empty file name ???
          *p = 'z';
          while (*p > 'a' && os_path_exists(*backupp)) {
            (*p)--;
          }
          // They all exist??? Must be something wrong!
          if (*p == 'a') {
            XFREE_CLEAR(*backupp);
          }
        }
      }
      if (*backupp != NULL) {
        // Delete any existing backup and move the current version
        // to the backup. For safety, we don't remove the backup
        // until the write has finished successfully. And if the
        // 'backup' option is set, leave it around.

        // If the renaming of the original file to the backup file
        // works, quit here.
        ///
        if (vim_rename(fname, *backupp) == 0) {
          break;
        }

        XFREE_CLEAR(*backupp);             // don't do the rename below
      }
    }
    if (*backupp == NULL && !forceit) {
      *err = set_err(_("E510: Can't make backup file (add ! to override)"));
      return FAIL;
    }
  }
  return OK;
}

/// buf_write() - write to file "fname" lines "start" through "end"
///
/// We do our own buffering here because fwrite() is so slow.
///
/// If "forceit" is true, we don't care for errors when attempting backups.
/// In case of an error everything possible is done to restore the original
/// file.  But when "forceit" is true, we risk losing it.
///
/// When "reset_changed" is true and "append" == false and "start" == 1 and
/// "end" == curbuf->b_ml.ml_line_count, reset curbuf->b_changed.
///
/// This function must NOT use NameBuff (because it's called by autowrite()).
///
///
/// @param eap     for forced 'ff' and 'fenc', can be NULL!
/// @param append  append to the file
///
/// @return        FAIL for failure, OK otherwise
int buf_write(buf_T *buf, char *fname, char *sfname, linenr_T start, linenr_T end, exarg_T *eap,
              bool append, bool forceit, bool reset_changed, bool filtering)
{
  int retval = OK;
  int msg_save = msg_scroll;
  bool prev_got_int = got_int;
  // writing everything
  bool whole = (start == 1 && end == buf->b_ml.ml_line_count);
  bool write_undo_file = false;
  context_sha256_T sha_ctx;
  unsigned bkc = get_bkc_flags(buf);

  if (fname == NULL || *fname == NUL) {  // safety check
    return FAIL;
  }
  if (buf->b_ml.ml_mfp == NULL) {
    // This can happen during startup when there is a stray "w" in the
    // vimrc file.
    emsg(_(e_empty_buffer));
    return FAIL;
  }

  // Disallow writing in secure mode.
  if (check_secure()) {
    return FAIL;
  }

  // Avoid a crash for a long name.
  if (strlen(fname) >= MAXPATHL) {
    emsg(_(e_longname));
    return FAIL;
  }

  // must init bw_conv_buf and bw_iconv_fd before jumping to "fail"
  struct bw_info write_info;            // info for buf_write_bytes()
  write_info.bw_conv_buf = NULL;
  write_info.bw_conv_error = false;
  write_info.bw_conv_error_lnum = 0;
  write_info.bw_restlen = 0;
  write_info.bw_iconv_fd = (iconv_t)-1;

  // After writing a file changedtick changes but we don't want to display
  // the line.
  ex_no_reprint = true;

  // If there is no file name yet, use the one for the written file.
  // BF_NOTEDITED is set to reflect this (in case the write fails).
  // Don't do this when the write is for a filter command.
  // Don't do this when appending.
  // Only do this when 'cpoptions' contains the 'F' flag.
  if (buf->b_ffname == NULL
      && reset_changed
      && whole
      && buf == curbuf
      && !bt_nofilename(buf)
      && !filtering
      && (!append || vim_strchr(p_cpo, CPO_FNAMEAPP) != NULL)
      && vim_strchr(p_cpo, CPO_FNAMEW) != NULL) {
    if (set_rw_fname(fname, sfname) == FAIL) {
      return FAIL;
    }
    buf = curbuf;           // just in case autocmds made "buf" invalid
  }

  if (sfname == NULL) {
    sfname = fname;
  }

  // For Unix: Use the short file name whenever possible.
  // Avoids problems with networks and when directory names are changed.
  // Don't do this for Windows, a "cd" in a sub-shell may have moved us to
  // another directory, which we don't detect.
  char *ffname = fname;                           // remember full fname
#ifdef UNIX
  fname = sfname;
#endif

  // true if writing over original
  bool overwriting = buf->b_ffname != NULL && path_fnamecmp(ffname, buf->b_ffname) == 0;

  no_wait_return++;                 // don't wait for return yet

  const pos_T orig_start = buf->b_op_start;
  const pos_T orig_end = buf->b_op_end;

  // Set '[ and '] marks to the lines to be written.
  buf->b_op_start.lnum = start;
  buf->b_op_start.col = 0;
  buf->b_op_end.lnum = end;
  buf->b_op_end.col = 0;

  int res = buf_write_do_autocmds(buf, &fname, &sfname, &ffname, start, &end, eap, append,
                                  filtering, reset_changed, overwriting, whole, orig_start,
                                  orig_end);
  if (res != NOTDONE) {
    return res;
  }

  if (cmdmod.cmod_flags & CMOD_LOCKMARKS) {
    // restore the original '[ and '] positions
    buf->b_op_start = orig_start;
    buf->b_op_end = orig_end;
  }

  if (shortmess(SHM_OVER) && !exiting) {
    msg_scroll = false;             // overwrite previous file message
  } else {
    msg_scroll = true;              // don't overwrite previous file message
  }
  if (!filtering) {
    msg_ext_set_kind("bufwrite");
    // show that we are busy
#ifndef UNIX
    filemess(buf, sfname, "");
#else
    filemess(buf, fname, "");
#endif
  }
  msg_scroll = false;               // always overwrite the file message now

  char *buffer = verbose_try_malloc(WRITEBUFSIZE);
  int bufsize;
  char smallbuf[SMALLBUFSIZE];
  // can't allocate big buffer, use small one (to be able to write when out of
  // memory)
  if (buffer == NULL) {
    buffer = smallbuf;
    bufsize = SMALLBUFSIZE;
  } else {
    bufsize = WRITEBUFSIZE;
  }

  Error_T err = { 0 };
  int perm;              // file permissions
  bool newfile = false;  // true if file doesn't exist yet
  bool device = false;   // writing to a device
  bool file_readonly = false;  // overwritten file is read-only
  char *backup = NULL;
  char *fenc_tofree = NULL;   // allocated "fenc"

  // Get information about original file (if there is one).
  FileInfo file_info_old;

  vim_acl_T acl = NULL;                 // ACL copied from original file to
                                        // backup or new file

  if (get_fileinfo(buf, fname, overwriting, forceit, &file_info_old, &perm, &device, &newfile,
                   &file_readonly, &err) == FAIL) {
    goto fail;
  }

  // For systems that support ACL: get the ACL from the original file.
  if (!newfile) {
    acl = os_get_acl(fname);
  }

  // If 'backupskip' is not empty, don't make a backup for some files.
  bool dobackup = (p_wb || p_bk || *p_pm != NUL);
  if (dobackup && *p_bsk != NUL && match_file_list(p_bsk, sfname, ffname)) {
    dobackup = false;
  }

  bool backup_copy = false;  // copy the original file?

  // Save the value of got_int and reset it.  We don't want a previous
  // interruption cancel writing, only hitting CTRL-C while writing should
  // abort it.
  prev_got_int = got_int;
  got_int = false;

  // Mark the buffer as 'being saved' to prevent changed buffer warnings
  buf->b_saving = true;

  // If we are not appending or filtering, the file exists, and the
  // 'writebackup', 'backup' or 'patchmode' option is set, need a backup.
  // When 'patchmode' is set also make a backup when appending.
  //
  // Do not make any backup, if 'writebackup' and 'backup' are both switched
  // off.  This helps when editing large files on almost-full disks.
  if (!(append && *p_pm == NUL) && !filtering && perm >= 0 && dobackup) {
    if (buf_write_make_backup(fname, append, &file_info_old, acl, perm, bkc, file_readonly, forceit,
                              &backup_copy, &backup, &err) == FAIL) {
      retval = FAIL;
      goto fail;
    }
  }

#if defined(UNIX)
  bool made_writable = false;  // 'w' bit has been set

  // When using ":w!" and the file was read-only: make it writable
  if (forceit && perm >= 0 && !(perm & 0200)
      && file_info_old.stat.st_uid == getuid()
      && vim_strchr(p_cpo, CPO_FWRITE) == NULL) {
    perm |= 0200;
    os_setperm(fname, perm);
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

  end = MIN(end, buf->b_ml.ml_line_count);
  if (buf->b_ml.ml_flags & ML_EMPTY) {
    start = end + 1;
  }

  char *wfname = NULL;       // name of file to write to

  // If the original file is being overwritten, there is a small chance that
  // we crash in the middle of writing. Therefore the file is preserved now.
  // This makes all block numbers positive so that recovery does not need
  // the original file.
  // Don't do this if there is a backup file and we are exiting.
  if (reset_changed && !newfile && overwriting && !(exiting && backup != NULL)) {
    ml_preserve(buf, false, !!p_fs);
    if (got_int) {
      err = set_err(_(e_interr));
      goto restore_backup;
    }
  }

  // Default: write the file directly.  May write to a temp file for
  // multi-byte conversion.
  wfname = fname;

  char *fenc;  // effective 'fileencoding'

  // Check for forced 'fileencoding' from "++opt=val" argument.
  if (eap != NULL && eap->force_enc != 0) {
    fenc = eap->cmd + eap->force_enc;
    fenc = enc_canonize(fenc);
    fenc_tofree = fenc;
  } else {
    fenc = buf->b_p_fenc;
  }

  // Check if the file needs to be converted.
  bool converted = need_conversion(fenc);
  int wb_flags = 0;

  // Check if UTF-8 to UCS-2/4 or Latin1 conversion needs to be done.  Or
  // Latin1 to Unicode conversion.  This is handled in buf_write_bytes().
  // Prepare the flags for it and allocate bw_conv_buf when needed.
  if (converted) {
    wb_flags = get_fio_flags(fenc);
    if (wb_flags & (FIO_UCS2 | FIO_UCS4 | FIO_UTF16 | FIO_UTF8)) {
      // Need to allocate a buffer to translate into.
      if (wb_flags & (FIO_UCS2 | FIO_UTF16 | FIO_UTF8)) {
        write_info.bw_conv_buflen = (size_t)bufsize * 2;
      } else {       // FIO_UCS4
        write_info.bw_conv_buflen = (size_t)bufsize * 4;
      }
      write_info.bw_conv_buf = verbose_try_malloc(write_info.bw_conv_buflen);
      if (!write_info.bw_conv_buf) {
        end = 0;
      }
    }
  }

  if (converted && wb_flags == 0) {
    // Use iconv() conversion when conversion is needed and it's not done
    // internally.
    write_info.bw_iconv_fd = (iconv_t)my_iconv_open(fenc, "utf-8");
    if (write_info.bw_iconv_fd != (iconv_t)-1) {
      // We're going to use iconv(), allocate a buffer to convert in.
      write_info.bw_conv_buflen = (size_t)bufsize * ICONV_MULT;
      write_info.bw_conv_buf = verbose_try_malloc(write_info.bw_conv_buflen);
      if (!write_info.bw_conv_buf) {
        end = 0;
      }
      write_info.bw_first = true;
    } else {
      // When the file needs to be converted with 'charconvert' after
      // writing, write to a temp file instead and let the conversion
      // overwrite the original file.
      if (*p_ccv != NUL) {
        wfname = vim_tempname();
        if (wfname == NULL) {  // Can't write without a tempfile!
          err = set_err(_("E214: Can't find temp file for writing"));
          goto restore_backup;
        }
      }
    }
  }

  bool notconverted = false;

  if (converted && wb_flags == 0
      && write_info.bw_iconv_fd == (iconv_t)-1
      && wfname == fname) {
    if (!forceit) {
      err = set_err(_("E213: Cannot convert (add ! to write without conversion)"));
      goto restore_backup;
    }
    notconverted = true;
  }

  bool no_eol = false;  // no end-of-line written
  int nchars;
  linenr_T lnum;
  int fileformat;
  bool checking_conversion;

  int fd;

  // If conversion is taking place, we may first pretend to write and check
  // for conversion errors.  Then loop again to write for real.
  // When not doing conversion this writes for real right away.
  for (checking_conversion = true;; checking_conversion = false) {
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
      // and forceit is true we delete the existing file and try to
      // create a new one. If this still fails we may have lost the
      // original file!  (this may happen when the user reached his
      // quotum for number of files).
      // Appending will fail if the file does not exist and forceit is
      // false.
      const int fflags = O_WRONLY | (append
                                     ? (forceit ? (O_APPEND | O_CREAT) : O_APPEND)
                                     : (O_CREAT | O_TRUNC));
      const int mode = perm < 0 ? 0666 : (perm & 0777);

      while ((fd = os_open(wfname, fflags, mode)) < 0) {
        // A forced write will try to create a new file if the old one
        // is still readonly. This may also happen when the directory
        // is read-only. In that case the os_remove() will fail.
        if (err.msg == NULL) {
#ifdef UNIX
          FileInfo file_info;

          // Don't delete the file when it's a hard or symbolic link.
          if ((!newfile && os_fileinfo_hardlinks(&file_info_old) > 1)
              || (os_fileinfo_link(fname, &file_info)
                  && !os_fileinfo_id_equal(&file_info, &file_info_old))) {
            err = set_err(_("E166: Can't open linked file for writing"));
          } else {
            err = set_err_arg(_("E212: Can't open file for writing: %s"), fd);
            if (forceit && vim_strchr(p_cpo, CPO_FWRITE) == NULL && perm >= 0) {
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
              if (!append) {                    // don't remove when appending
                os_remove(wfname);
              }
              continue;
            }
          }
#else
          err = set_err_arg(_("E212: Can't open file for writing: %s"), fd);
          if (forceit && vim_strchr(p_cpo, CPO_FWRITE) == NULL && perm >= 0) {
            if (!append) {                    // don't remove when appending
              os_remove(wfname);
            }
            continue;
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
                os_remove(backup);
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
    err = set_err(NULL);

    write_info.bw_buf = buffer;
    nchars = 0;

    // use "++bin", "++nobin" or 'binary'
    int write_bin;
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
    write_info.bw_flags = wb_flags;
    fileformat = get_fileformat_force(buf, eap);
    char *s = buffer;
    int len = 0;
    for (lnum = start; lnum <= end; lnum++) {
      // The next while loop is done once for each character written.
      // Keep it fast!
      char *ptr = ml_get_buf(buf, lnum) - 1;
      if (write_undo_file) {
        sha256_update(&sha_ctx, (uint8_t *)ptr + 1, (uint32_t)(strlen(ptr + 1) + 1));
      }
      char c;
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
              && ((write_bin && lnum == buf->b_no_eol_lnum)
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

    if (!buf->b_p_fixeol && buf->b_p_eof) {
      // write trailing CTRL-Z
      write_eintr(write_info.bw_fd, "\x1a", 1);
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
    // If the 'fsync' option is false, don't fsync().  Useful for laptops.
    int error;
    if (p_fs && (error = os_fsync(fd)) != 0 && !device
        // fsync not supported on this storage.
        && error != UV_ENOTSUP) {
      err = set_err_arg(e_fsync, error);
      end = 0;
    }

    if (!backup_copy) {
#ifdef HAVE_XATTR
      os_copy_xattr(backup, wfname);
#endif
    }

#ifdef UNIX
    // When creating a new file, set its owner/group to that of the original
    // file.  Get the new device and inode number.
    if (backup != NULL && !backup_copy) {
      // don't change the owner when it's already OK, some systems remove
      // permission or ACL stuff
      FileInfo file_info;
      if (!os_fileinfo(wfname, &file_info)
          || file_info.stat.st_uid != file_info_old.stat.st_uid
          || file_info.stat.st_gid != file_info_old.stat.st_gid) {
        os_fchown(fd, (uv_uid_t)file_info_old.stat.st_uid, (uv_gid_t)file_info_old.stat.st_gid);
        if (perm >= 0) {  // Set permission again, may have changed.
          os_setperm(wfname, perm);
        }
      }
      buf_set_file_id(buf);
    } else if (!buf->file_id_valid) {
      // Set the file_id when creating a new file.
      buf_set_file_id(buf);
    }
#endif

    if ((error = os_close(fd)) != 0) {
      err = set_err_arg(_("E512: Close failed: %s"), error);
      end = 0;
    }

#ifdef UNIX
    if (made_writable) {
      perm &= ~0200;              // reset 'w' bit for security reasons
    }
#endif
    if (perm >= 0) {  // Set perm. of new file same as old file.
      os_setperm(wfname, perm);
    }
    // Probably need to set the ACL before changing the user (can't set the
    // ACL on a file the user doesn't own).
    if (!backup_copy) {
      os_set_acl(wfname, acl);
    }

    if (wfname != fname) {
      // The file was written to a temp file, now it needs to be converted
      // with 'charconvert' to (overwrite) the output file.
      if (end != 0) {
        if (eval_charconvert("utf-8", fenc, wfname, fname) == FAIL) {
          write_info.bw_conv_error = true;
          end = 0;
        }
      }
      os_remove(wfname);
      xfree(wfname);
    }
  }

  if (end == 0) {
    // Error encountered.
    if (err.msg == NULL) {
      if (write_info.bw_conv_error) {
        if (write_info.bw_conv_error_lnum == 0) {
          err = set_err(_(e_write_error_conversion_failed_make_fenc_empty_to_override));
        } else {
          err = set_err(xmalloc(300));
          err.alloc = true;
          vim_snprintf(err.msg, 300,  // NOLINT(runtime/printf)
                       _(e_write_error_conversion_failed_in_line_nr_make_fenc_empty_to_override),
                       write_info.bw_conv_error_lnum);
        }
      } else if (got_int) {
        err = set_err(_(e_interr));
      } else {
        err = set_err(_(e_write_error_file_system_full));
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
          msg(_(e_interr), 0);
          ui_flush();
        }

        // copy the file.
        if (os_copy(backup, fname, UV_FS_COPYFILE_FICLONE)
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

  lnum -= start;            // compute number of written lines
  no_wait_return--;         // may wait for return now

#if !defined(UNIX)
  fname = sfname;           // use shortname now, for the messages
#endif
  if (!filtering) {
    add_quoted_fname(IObuff, IOSIZE, buf, fname);
    bool insert_space = false;
    if (write_info.bw_conv_error) {
      xstrlcat(IObuff, _(" CONVERSION ERROR"), IOSIZE);
      insert_space = true;
      if (write_info.bw_conv_error_lnum != 0) {
        vim_snprintf_add(IObuff, IOSIZE, _(" in line %" PRId64 ";"),
                         (int64_t)write_info.bw_conv_error_lnum);
      }
    } else if (notconverted) {
      xstrlcat(IObuff, _("[NOT converted]"), IOSIZE);
      insert_space = true;
    } else if (converted) {
      xstrlcat(IObuff, _("[converted]"), IOSIZE);
      insert_space = true;
    }
    if (device) {
      xstrlcat(IObuff, _("[Device]"), IOSIZE);
      insert_space = true;
    } else if (newfile) {
      xstrlcat(IObuff, _("[New]"), IOSIZE);
      insert_space = true;
    }
    if (no_eol) {
      xstrlcat(IObuff, _("[noeol]"), IOSIZE);
      insert_space = true;
    }
    // may add [unix/dos/mac]
    if (msg_add_fileformat(fileformat)) {
      insert_space = true;
    }
    msg_ext_set_kind("bufwrite");
    msg_add_lines(insert_space, lnum, nchars);       // add line/char count
    if (!shortmess(SHM_WRITE)) {
      if (append) {
        xstrlcat(IObuff, shortmess(SHM_WRI) ? _(" [a]") : _(" appended"), IOSIZE);
      } else {
        xstrlcat(IObuff, shortmess(SHM_WRI) ? _(" [w]") : _(" written"), IOSIZE);
      }
    }

    set_keep_msg(msg_trunc(IObuff, false, 0), 0);
  }

  // When written everything correctly: reset 'modified'.  Unless not
  // writing to the original file and '+' is not in 'cpoptions'.
  if (reset_changed && whole && !append
      && !write_info.bw_conv_error
      && (overwriting || vim_strchr(p_cpo, CPO_PLUS) != NULL)) {
    unchanged(buf, true, false);
    const varnumber_T changedtick = buf_get_changedtick(buf);
    if (buf->b_last_changedtick + 1 == changedtick) {
      // b:changedtick may be incremented in unchanged() but that should not
      // trigger a TextChanged event.
      buf->b_last_changedtick = changedtick;
    }
    u_unchanged(buf);
    u_update_save_nr(buf);
  }

  // If written to the current file, update the timestamp of the swap file
  // and reset the BF_WRITE_MASK flags. Also sets buf->b_mtime.
  if (overwriting) {
    ml_timestamp(buf);
    if (append) {
      buf->b_flags &= ~BF_NEW;
    } else {
      buf->b_flags &= ~BF_WRITE_MASK;
    }
  }

  // If we kept a backup until now, and we are in patch mode, then we make
  // the backup file our 'original' file.
  if (*p_pm && dobackup) {
    char *const org = modname(fname, p_pm, false);

    if (backup != NULL) {
      // If the original file does not exist yet
      // the current backup file becomes the original file
      if (org == NULL) {
        emsg(_("E205: Patchmode: can't save original file"));
      } else if (!os_path_exists(org)) {
        vim_rename(backup, org);
        XFREE_CLEAR(backup);                   // don't delete the file
#ifdef UNIX
        os_file_settime(org,
                        (double)file_info_old.stat.st_atim.tv_sec,
                        (double)file_info_old.stat.st_mtim.tv_sec);
#endif
      }
    } else {
      // If there is no backup file, remember that a (new) file was
      // created.
      int empty_fd;

      if (org == NULL
          || (empty_fd = os_open(org,
                                 O_CREAT | O_EXCL | O_NOFOLLOW,
                                 perm < 0 ? 0666 : (perm & 0777))) < 0) {
        emsg(_(e_patchmode_cant_touch_empty_original_file));
      } else {
        close(empty_fd);
      }
    }
    if (org != NULL) {
      os_setperm(org, os_getperm(fname) & 0777);
      xfree(org);
    }
  }

  // Remove the backup unless 'backup' option is set
  if (!p_bk && backup != NULL
      && !write_info.bw_conv_error
      && os_remove(backup) != 0) {
    emsg(_("E207: Can't delete backup file"));
  }

  goto nofail;

  // Finish up.  We get here either after failure or success.
fail:
  no_wait_return--;             // may wait for return now
nofail:

  // Done saving, we accept changed buffer warnings again
  buf->b_saving = false;

  xfree(backup);
  if (buffer != smallbuf) {
    xfree(buffer);
  }
  xfree(fenc_tofree);
  xfree(write_info.bw_conv_buf);
  if (write_info.bw_iconv_fd != (iconv_t)-1) {
    iconv_close(write_info.bw_iconv_fd);
    write_info.bw_iconv_fd = (iconv_t)-1;
  }
  os_free_acl(acl);

  if (err.msg != NULL) {
    // - 100 to save some space for further error message
#ifndef UNIX
    add_quoted_fname(IObuff, IOSIZE - 100, buf, sfname);
#else
    add_quoted_fname(IObuff, IOSIZE - 100, buf, fname);
#endif
    emit_err(&err);

    retval = FAIL;
    if (end == 0) {
      const int hl_id = HLF_E;  // Set highlight for error messages.
      msg_puts_hl(_("\nWARNING: Original file may be lost or damaged\n"), hl_id, true);
      msg_puts_hl(_("don't quit the editor until the file is successfully written!"), hl_id, true);

      // Update the timestamp to avoid an "overwrite changed file"
      // prompt when writing again.
      if (os_fileinfo(fname, &file_info_old)) {
        buf_store_file_info(buf, &file_info_old);
        buf->b_mtime_read = buf->b_mtime;
        buf->b_mtime_read_ns = buf->b_mtime_ns;
      }
    }
  }
  msg_scroll = msg_save;

  // When writing the whole file and 'undofile' is set, also write the undo
  // file.
  if (retval == OK && write_undo_file) {
    uint8_t hash[UNDO_HASH_SIZE];

    sha256_finish(&sha_ctx, hash);
    u_write_undo(NULL, false, buf, hash);
  }

  if (!should_abort(retval)) {
    buf_write_do_post_autocmds(buf, fname, eap, append, filtering, reset_changed, whole);
    if (aborting()) {       // autocmds may abort script processing
      retval = false;
    }
  }

  got_int |= prev_got_int;

  return retval;
}
