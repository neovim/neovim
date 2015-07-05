#include <stddef.h>
#include <stdbool.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>
#include <errno.h>
#include <unistd.h>
#include <assert.h>
#if defined (__GLIBC__)
# ifndef _BSD_SOURCE
#  define _BSD_SOURCE 1
# endif
# ifndef _DEFAULT_SOURCE
#  define _DEFAULT_SOURCE 1
# endif
# include <endian.h>
#endif

#include <msgpack.h>

#include "nvim/os/os.h"
#include "nvim/os/time.h"
#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/shada.h"
#include "nvim/message.h"
#include "nvim/globals.h"
#include "nvim/memory.h"
#include "nvim/mark.h"
#include "nvim/ops.h"
#include "nvim/garray.h"
#include "nvim/option.h"
#include "nvim/msgpack_rpc/helpers.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/globals.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/misc2.h"
#include "nvim/ex_getln.h"
#include "nvim/search.h"
#include "nvim/eval.h"
#include "nvim/eval_defs.h"
#include "nvim/version.h"
#include "nvim/path.h"
#include "nvim/lib/ringbuf.h"
#include "nvim/strings.h"
#include "nvim/lib/khash.h"
#include "nvim/lib/kvec.h"

// Note: when using bufset hash pointers are intentionally casted to uintptr_t 
// and not to khint32_t or khint64_t: this way compiler must give a warning 
// (-Wconversion) when types change.
#ifdef ARCH_32
KHASH_SET_INIT_INT(bufset)
#elif defined(ARCH_64)
KHASH_SET_INIT_INT64(bufset)
#else
# error Not a 64- or 32-bit architecture
#endif
KHASH_MAP_INIT_STR(fnamebufs, buf_T *)

#define copy_option_part(src, dest, ...) \
    ((char *) copy_option_part((char_u **) src, (char_u *) dest, __VA_ARGS__))
#define find_viminfo_parameter(...) \
    ((const char *) find_viminfo_parameter(__VA_ARGS__))
#define emsg2(a, b) emsg2((char_u *) a, (char_u *) b)
#define emsg3(a, b, c) emsg3((char_u *) a, (char_u *) b, (char_u *) c)
#define emsgu(a, ...) emsgu((char_u *) a, __VA_ARGS__)
#define home_replace_save(a, b) \
    ((char *)home_replace_save(a, (char_u *)b))
#define has_non_ascii(a) (has_non_ascii((char_u *)a))
#define string_convert(a, b, c) \
      ((char *)string_convert((vimconv_T *)a, (char_u *)b, c))
#define path_shorten_fname_if_possible(b) \
    ((char *)path_shorten_fname_if_possible((char_u *)b))
#define buflist_new(ffname, sfname, ...) \
    (buflist_new((char_u *)ffname, (char_u *)sfname, __VA_ARGS__))
#define convert_setup(vcp, from, to) \
    (convert_setup(vcp, (char_u *)from, (char_u *)to))

// From http://www.boost.org/doc/libs/1_43_0/boost/detail/endian.hpp + some 
// additional checks done after examining `{compiler} -dM -E - < /dev/null` 
// output.
#if defined (__GLIBC__)
# if (__BYTE_ORDER == __BIG_ENDIAN)
#  define SHADA_BIG_ENDIAN
# endif
#elif defined(_BIG_ENDIAN) || defined(_LITTLE_ENDIAN)
# if defined(_BIG_ENDIAN) && !defined(_LITTLE_ENDIAN)
#  define SHADA_BIG_ENDIAN
# endif
// clang-specific
#elif defined(__BIG_ENDIAN__) || defined(__LITTLE_ENDIAN__)
# if defined(_BIG_ENDIAN) && !defined(_LITTLE_ENDIAN)
#  define SHADA_BIG_ENDIAN
# endif
// pcc-, gcc- and clang-specific
#elif defined(__BYTE_ORDER__) && defined(__ORDER_BIG_ENDIAN__)
# if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
#  define SHADA_BIG_ENDIAN
# endif
#elif defined(__sparc) || defined(__sparc__) \
   || defined(_POWER) || defined(__powerpc__) \
   || defined(__ppc__) || defined(__hpux) || defined(__hppa) \
   || defined(_MIPSEB) || defined(_POWER) \
   || defined(__s390__)
# define SHADA_BIG_ENDIAN
#elif defined(__i386__) || defined(__alpha__) \
   || defined(__ia64) || defined(__ia64__) \
   || defined(_M_IX86) || defined(_M_IA64) \
   || defined(_M_ALPHA) || defined(__amd64) \
   || defined(__amd64__) || defined(_M_AMD64) \
   || defined(__x86_64) || defined(__x86_64__) \
   || defined(_M_X64) || defined(__bfin__)
// Define nothing
#endif

/// Possible ShaDa entry types
///
/// @warning Enum values are part of the API and must not be altered.
///
/// All values that are not in enum are ignored.
typedef enum {
  kSDItemUnknown = -1,       ///< Unknown item.
  kSDItemMissing = 0,        ///< Missing value. Should never appear in a file.
  kSDItemHeader = 1,         ///< Header. Present for debugging purposes.
  kSDItemSearchPattern = 2,  ///< Last search pattern (*not* history item).
                             ///< Comes from user searches (e.g. when typing 
                             ///< "/pat") or :substitute command calls.
  kSDItemSubString = 3,      ///< Last substitute replacement string.
  kSDItemHistoryEntry = 4,   ///< History item.
  kSDItemRegister = 5,       ///< Register.
  kSDItemVariable = 6,       ///< Global variable.
  kSDItemGlobalMark = 7,     ///< Global mark definition.
  kSDItemJump = 8,           ///< Item from jump list.
  kSDItemBufferList = 9,     ///< Buffer list.
  kSDItemLocalMark = 10,     ///< Buffer-local mark.
  kSDItemChange = 11,        ///< Item from buffer change list.
#define SHADA_LAST_ENTRY ((uint64_t) kSDItemChange)
} ShadaEntryType;

/// Flags for shada_read_next_item
enum SRNIFlags {
  kSDReadHeader = (1 << kSDItemHeader),  ///< Determines whether header should
                                         ///< be read (it is usually ignored).
  kSDReadUndisableableData = (
    (1 << kSDItemSearchPattern)
    | (1 << kSDItemSubString)
    | (1 << kSDItemGlobalMark)
    | (1 << kSDItemJump)
  ), ///< Data reading which cannot be disabled by &viminfo or other options 
     ///< except for disabling reading ShaDa as a whole.
  kSDReadRegisters = (1 << kSDItemRegister),  ///< Determines whether registers 
                                              ///< should be read (may only be 
                                              ///< disabled when writing, but 
                                              ///< not when reading).
  kSDReadHistory = (1 << kSDItemHistoryEntry),  ///< Determines whether history
                                                ///< should be read (can only be 
                                                ///< disabled by &history).
  kSDReadVariables = (1 << kSDItemVariable),  ///< Determines whether variables 
                                              ///< should be read (disabled by 
                                              ///< removing ! from &viminfo).
  kSDReadBufferList = (1 << kSDItemBufferList),  ///< Determines whether buffer 
                                                 ///< list should be read 
                                                 ///< (disabled by removing 
                                                 ///< % entry from viminfo).
  kSDReadUnknown = (1 << (SHADA_LAST_ENTRY + 1)),  ///< Determines whether 
                                                   ///< unknown items should be 
                                                   ///< read (usually disabled).
  kSDReadLocalMarks = (
    (1 << kSDItemLocalMark)
    | (1 << kSDItemChange)
  ),  ///< Determines whether local marks and change list should be read. Can 
      ///< only be disabled by disabling &viminfo or putting '0 there.
};
// Note: SRNIFlags enum name was created only to make it possible to reference 
// it. This name is not actually used anywhere outside of the documentation.

/// Structure defining a single ShaDa file entry
typedef struct {
  ShadaEntryType type;
  Timestamp timestamp;
  union {
    Dictionary header;
    struct shada_filemark {
      char name;
      pos_T mark;
      char *fname;
      Dictionary *additional_data;
    } filemark;
    struct search_pattern {
      bool magic;
      bool smartcase;
      bool has_line_offset;
      bool place_cursor_at_end;
      int64_t offset;
      bool is_last_used;
      bool is_substitute_pattern;
      char *pat;
      Dictionary *additional_data;
    } search_pattern;
    struct history_item {
      uint8_t histtype;
      char *string;
      char sep;
      bool canfree;
      Array *additional_elements;
    } history_item;
    struct reg {
      char name;
      uint8_t type;
      char **contents;
      size_t contents_size;
      size_t width;
      Dictionary *additional_data;
    } reg;
    struct global_var {
      char *name;
      Object value;
      Array *additional_elements;
    } global_var;
    struct {
      uint64_t type;
      char *contents;
      size_t size;
    } unknown_item;
    struct sub_string {
      char *sub;
      Array *additional_elements;
    } sub_string;
    struct buffer_list {
      size_t size;
      struct buffer_list_buffer {
        pos_T pos;
        char *fname;
        Dictionary *additional_data;
      } *buffers;
    } buffer_list;
  } data;
} ShadaEntry;

RINGBUF_TYPEDEF(HM, ShadaEntry)

typedef struct {
  HMRingBuffer hmrb;
  bool do_merge;
  const void *iter;
  ShadaEntry last_hist_entry;
  uint8_t history_type;
} HistoryMergerState;

struct sd_read_def;

/// Function used to read ShaDa files
typedef ptrdiff_t (*ShaDaFileReader)(struct sd_read_def *const sd_reader,
                                     void *const dest,
                                     const size_t size)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_WARN_UNUSED_RESULT;

/// Structure containing necessary pointers for reading ShaDa files
typedef struct sd_read_def {
  ShaDaFileReader read;  ///< Reader function.
  void *cookie;          ///< Reader function last argument.
  bool eof;              ///< True if reader reached end of file.
  char *error;           ///< Error message in case of error.
  uintmax_t fpos;        ///< Current position (amount of bytes read since 
                         ///< reader structure initialization). May overflow.
  vimconv_T sd_conv;     ///< Structure used for converting encodings of some
                         ///< items.
} ShaDaReadDef;

struct sd_write_def;

/// Function used to write ShaDa files
typedef ptrdiff_t (*ShaDaFileWriter)(struct sd_write_def *const sd_writer,
                                     const void *const src,
                                     const size_t size)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_WARN_UNUSED_RESULT;

/// Structure containing necessary pointers for writing ShaDa files
typedef struct sd_write_def {
  ShaDaFileWriter write;  ///< Writer function.
  void *cookie;           ///< Writer function last argument.
  char *error;            ///< Error message in case of error.
  vimconv_T sd_conv;      ///< Structure used for converting encodings of some
                          ///< items.
} ShaDaWriteDef;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "shada.c.generated.h"
#endif

RINGBUF_INIT(HM, hm, ShadaEntry, shada_free_shada_entry)

/// Wrapper for reading from file descriptors
///
/// @return true if read was successfull, false otherwise.
static ptrdiff_t read_file(ShaDaReadDef *const sd_reader, void *const dest,
                           const size_t size)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  size_t read_bytes = 0;
  bool did_try_to_free = false;
  while (read_bytes != size) {
    const ptrdiff_t cur_read_bytes = read((int)(intptr_t) sd_reader->cookie,
                                          ((char *) dest) + read_bytes,
                                          size - read_bytes);
    if (cur_read_bytes > 0) {
      read_bytes += (size_t) cur_read_bytes;
      sd_reader->fpos += (uintmax_t) cur_read_bytes;
      assert(read_bytes <= size);
    }
    if (errno) {
      if (errno == EINTR || errno == EAGAIN) {
        errno = 0;
        continue;
      } else if (errno == ENOMEM && !did_try_to_free) {
        try_to_free_memory();
        did_try_to_free = true;
        errno = 0;
        continue;
      } else {
        sd_reader->error = strerror(errno);
        errno = 0;
        return -1;
      }
    }
    if (cur_read_bytes == 0) {
      sd_reader->eof = true;
      break;
    }
  }
  return (ptrdiff_t) read_bytes;
}

/// Read one character
static int read_char(ShaDaReadDef *const sd_reader)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  uint8_t ret;
  ptrdiff_t read_bytes = sd_reader->read(sd_reader, &ret, 1);
  if (read_bytes != 1) {
    return EOF;
  }
  return (int) ret;
}

/// Wrapper for writing to file descriptors
///
/// @return true if read was successfull, false otherwise.
static ptrdiff_t write_file(ShaDaWriteDef *const sd_writer,
                            const void *const dest,
                            const size_t size)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  size_t written_bytes = 0;
  while (written_bytes != size) {
    const ptrdiff_t cur_written_bytes = write((int)(intptr_t) sd_writer->cookie,
                                              (char *) dest + written_bytes,
                                              size - written_bytes);
    if (cur_written_bytes > 0) {
      written_bytes += (size_t) cur_written_bytes;
    }
    if (errno) {
      if (errno == EINTR || errno == EAGAIN) {
        errno = 0;
        continue;
      } else {
        sd_writer->error = strerror(errno);
        errno = 0;
        return -1;
      }
    }
    if (cur_written_bytes == 0) {
      sd_writer->error = "Zero bytes written.";
      return -1;
    }
  }
  return (ptrdiff_t) written_bytes;
}

/// Wrapper for opening file descriptors
///
/// All arguments are passed to os_open().
///
/// @return file descriptor or -1 on failure.
static int open_file(const char *const fname, const int flags, const int mode)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  bool did_try_to_free = false;
  int fd;
open_file_start:
  fd = os_open(fname, flags, mode);

  if (fd < 0) {
    if (-fd == ENOENT) {
      return -1;
    }
    if (-fd == ENOMEM && !did_try_to_free) {
      try_to_free_memory();
      did_try_to_free = true;
      goto open_file_start;
    }
    if (-fd == EINTR) {
      goto open_file_start;
    }
    emsg3("System error while opening ShaDa file %s: %s",
          fname, strerror(-fd));
    return -1;
  }
  return fd;
}

/// Open ShaDa file for reading
///
/// @param[in]   fname      File name to open.
/// @param[out]  sd_reader  Location where reader structure will be saved.
///
/// @return OK in case of success, FAIL otherwise.
static int open_shada_file_for_reading(const char *const fname,
                                       ShaDaReadDef *sd_reader)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  const intptr_t fd = (intptr_t) open_file(fname, O_RDONLY, 0);

  if (fd == -1) {
    return FAIL;
  }

  *sd_reader = (ShaDaReadDef) {
    .read = &read_file,
    .error = NULL,
    .eof = false,
    .fpos = 0,
    .cookie = (void *) fd,
  };

  return OK;
}

/// Wrapper for closing file descriptors
static void close_file(int fd)
{
close_file_start:
  if (close(fd) == -1) {
    if (errno == EINTR) {
      errno = 0;
      goto close_file_start;
    } else {
      emsg2("System error while closing ShaDa file: %s",
            strerror(errno));
      errno = 0;
    }
  }
}

/// Check whether buffer is in the given set
///
/// @param[in]  set  Set to check within.
/// @param[in]  buf  Buffer to find.
///
/// @return true or false.
static inline bool in_bufset(const khash_t(bufset) *const set, const buf_T *buf)
  FUNC_ATTR_PURE
{
  return kh_get(bufset, set, (uintptr_t) buf) != kh_end(set);
}

/// Check whether buffer is on removable media
///
/// Uses pre-populated set with buffers on removable media named removable_bufs.
///
/// @param[in]  buf  Buffer to check.
///
/// @return true or false.
#define SHADA_REMOVABLE(buf) in_bufset(removable_bufs, buf)

/// Msgpack callback for writing to ShaDaWriteDef*
static int msgpack_sd_writer_write(void *data, const char *buf, size_t len)
{
  ShaDaWriteDef *const sd_writer = (ShaDaWriteDef *) data;
  ptrdiff_t written_bytes = sd_writer->write(sd_writer, buf, len);
  if (written_bytes == -1) {
    emsg2("System error while writing ShaDa file: %s", sd_writer->error);
    return -1;
  }
  return 0;
}

/// Check whether writing to shada file was disabled with -i NONE
///
/// @return true if it was disabled, false otherwise.
static bool shada_disabled(void)
  FUNC_ATTR_PURE
{
  return used_shada_file != NULL && STRCMP(used_shada_file, "NONE") == 0;
}

/// Read ShaDa file
///
/// @param[in]  file   File to read or NULL to use default name.
/// @param[in]  flags  Flags, see kShaDa enum values in shada.h.
///
/// @return FAIL if reading failed for some reason and OK otherwise.
int shada_read_file(const char *const file, const int flags)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (shada_disabled()) {
    return FAIL;
  }

  char *const fname = shada_filename(file);

  ShaDaReadDef sd_reader;
  const int of_ret = open_shada_file_for_reading(fname, &sd_reader);

  if (p_verbose > 0) {
    verbose_enter();
    smsg(_("Reading viminfo file \"%s\"%s%s%s"),
        fname,
        (flags & kShaDaWantInfo) ? _(" info") : "",
        (flags & kShaDaWantMarks) ? _(" marks") : "",
        (flags & kShaDaGetOldfiles) ? _(" oldfiles") : "",
        of_ret != OK ? _(" FAILED") : "");
    verbose_leave();
  }

  xfree(fname);
  if (of_ret != OK) {
    return of_ret;
  }

  convert_setup(&sd_reader.sd_conv, "utf-8", p_enc);

  shada_read(&sd_reader, flags);

  close_file((int)(intptr_t) sd_reader.cookie);
  return OK;
}

/// Wrapper for hist_iter() function which produces ShadaEntry values
///
/// @warning Zeroes original items in process.
static const void *shada_hist_iter(const void *const iter,
                                   const uint8_t history_type,
                                   const bool zero,
                                   ShadaEntry *const hist)
  FUNC_ATTR_NONNULL_ARG(4) FUNC_ATTR_WARN_UNUSED_RESULT
{
  histentry_T hist_he;
  const void *const ret = hist_iter(iter, history_type, zero, &hist_he);
  if (hist_he.hisstr == NULL) {
    *hist = (ShadaEntry) { .type = kSDItemMissing };
  } else {
    *hist = (ShadaEntry) {
      .type = kSDItemHistoryEntry,
      .timestamp = hist_he.timestamp,
      .data = {
        .history_item = {
          .histtype = history_type,
          .string = (char *) hist_he.hisstr,
          .sep = (char) (history_type == HIST_SEARCH
                        ? (char) hist_he.hisstr[STRLEN(hist_he.hisstr) + 1]
                        : 0),
          .additional_elements = hist_he.additional_elements,
          .canfree = zero,
        }
      }
    };
  }
  return ret;
}

/// Insert history entry
///
/// Inserts history entry at the end of the ring buffer (may insert earlier 
/// according to the timestamp). If entry was already in the ring buffer 
/// existing entry will be removed unless it has greater timestamp.
///
/// Before the new entry entries from the current NeoVim history will be 
/// inserted unless `do_iter` argument is false.
///
/// @param[in,out]  hms_p    Ring buffer and associated structures.
/// @param[in]      entry    Inserted entry.
/// @param[in]      do_iter  Determines whether NeoVim own history should be 
///                          used.
static void insert_history_entry(HistoryMergerState *const hms_p,
                                 const ShadaEntry entry,
                                 const bool no_iter)
{
  HMRingBuffer *const rb = &(hms_p->hmrb);
  RINGBUF_FORALL(rb, ShadaEntry, cur_entry) {
    if (STRCMP(cur_entry->data.history_item.string,
               entry.data.history_item.string) == 0) {
      if (entry.timestamp > cur_entry->timestamp) {
        hm_rb_remove(rb, (size_t) hm_rb_find_idx(rb, cur_entry));
      } else {
        return;
      }
    }
  }
  if (!no_iter) {
    if (hms_p->iter == NULL) {
      if (hms_p->last_hist_entry.type != kSDItemMissing
          && hms_p->last_hist_entry.timestamp < entry.timestamp) {
        insert_history_entry(hms_p, hms_p->last_hist_entry, false);
        hms_p->last_hist_entry.type = kSDItemMissing;
      }
    } else {
      while (hms_p->iter != NULL
            && hms_p->last_hist_entry.type != kSDItemMissing
            && hms_p->last_hist_entry.timestamp < entry.timestamp) {
        insert_history_entry(hms_p, hms_p->last_hist_entry, false);
        hms_p->iter = shada_hist_iter(hms_p->iter, hms_p->history_type, true,
                                      &(hms_p->last_hist_entry));
      }
    }
  }
  ShadaEntry *insert_after;
  RINGBUF_ITER_BACK(rb, ShadaEntry, insert_after) {
    if (insert_after->timestamp <= entry.timestamp) {
      break;
    }
  }
  hm_rb_insert(rb, (size_t) (hm_rb_find_idx(rb, insert_after) + 1), entry);
}

/// Find buffer for given buffer name (cached)
///
/// @param[in,out]  fname_bufs  Cache containing fname to buffer mapping.
/// @param[in]      fname       File name to find.
///
/// @return Pointer to the buffer or NULL.
static buf_T *find_buffer(khash_t(fnamebufs) *const fname_bufs,
                          const char *const fname)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  int kh_ret;
  khint_t k = kh_put(fnamebufs, fname_bufs, fname, &kh_ret);
  if (!kh_ret) {
    return kh_val(fname_bufs, k);
  }
  kh_key(fname_bufs, k) = xstrdup(fname);
  FOR_ALL_BUFFERS(buf) {
    if (buf->b_ffname != NULL) {
      if (fnamecmp(fname, buf->b_ffname) == 0) {
        kh_val(fname_bufs, k) = buf;
        return buf;
      }
    }
  }
  kh_val(fname_bufs, k) = NULL;
  return NULL;
}

/// Compare two marks
static inline bool marks_equal(const pos_T a, const pos_T b)
{
  return (a.lnum == b.lnum) && (a.col == b.col);
}

/// Read data from ShaDa file
///
/// @param[in]  sd_reader  Structure containing file reader definition.
/// @param[in]  flags      What to read.
static void shada_read(ShaDaReadDef *const sd_reader, const int flags)
  FUNC_ATTR_NONNULL_ALL
{
  unsigned srni_flags = 0;
  if (flags & kShaDaWantInfo) {
    srni_flags |= kSDReadUndisableableData | kSDReadRegisters;
    if (p_hi) {
      srni_flags |= kSDReadHistory;
    }
    if (find_viminfo_parameter('!') != NULL) {
      srni_flags |= kSDReadVariables;
    }
    if (find_viminfo_parameter('%') != NULL && ARGCOUNT == 0) {
      srni_flags |= kSDReadBufferList;
    }
  }
  if (flags & kShaDaWantMarks) {
    if (get_viminfo_parameter('\'') > 0) {
      srni_flags |= kSDReadLocalMarks;
    }
  }
  if (srni_flags == 0) {
    // Nothing to do.
    return;
  }
  const bool force = flags & kShaDaForceit;
  HistoryMergerState hms[HIST_COUNT];
  if (srni_flags & kSDReadHistory) {
    for (uint8_t i = 0; i < HIST_COUNT; i++) {
      hms[i].hmrb = hm_rb_new((size_t) p_hi);
      hms[i].do_merge = true;
      hms[i].iter = shada_hist_iter(NULL, i, true, &(hms[i].last_hist_entry));
      hms[i].history_type = i;
    }
  }
  ShadaEntry cur_entry;
  khash_t(bufset) *cl_bufs = kh_init(bufset);
  khash_t(fnamebufs) *fname_bufs = kh_init(fnamebufs);
  while (shada_read_next_item(sd_reader, &cur_entry, srni_flags) == NOTDONE) {
    switch (cur_entry.type) {
      case kSDItemMissing: {
        assert(false);
      }
      case kSDItemUnknown: {
        break;
      }
      case kSDItemHeader: {
        shada_free_shada_entry(&cur_entry);
        break;
      }
      case kSDItemSearchPattern: {
        (cur_entry.data.search_pattern.is_substitute_pattern
         ? &set_substitute_pattern
         : &set_search_pattern)((SearchPattern) {
          .magic = cur_entry.data.search_pattern.magic,
          .no_scs = !cur_entry.data.search_pattern.smartcase,
          .off = {
            .line = cur_entry.data.search_pattern.has_line_offset,
            .end = cur_entry.data.search_pattern.place_cursor_at_end,
            .off = cur_entry.data.search_pattern.offset,
          },
          .pat = (char_u *) cur_entry.data.search_pattern.pat,
          .additional_data = cur_entry.data.search_pattern.additional_data,
          .timestamp = cur_entry.timestamp,
        });
        if (cur_entry.data.search_pattern.is_last_used) {
          set_last_used_pattern(
              cur_entry.data.search_pattern.is_substitute_pattern);
        }
        // Do not free shada entry: its allocated memory was saved above.
        break;
      }
      case kSDItemSubString: {
        sub_set_replacement((SubReplacementString) {
          .sub = cur_entry.data.sub_string.sub,
          .timestamp = cur_entry.timestamp,
          .additional_elements = cur_entry.data.sub_string.additional_elements,
        });
        // Do not free shada entry: its allocated memory was saved above.
        break;
      }
      case kSDItemHistoryEntry: {
        if (cur_entry.data.history_item.histtype >= HIST_COUNT) {
          shada_free_shada_entry(&cur_entry);
          break;
        }
        insert_history_entry(hms + cur_entry.data.history_item.histtype,
                             cur_entry, true);
        // Do not free shada entry: its allocated memory was saved above.
        break;
      }
      case kSDItemRegister: {
        if (cur_entry.data.reg.type != MCHAR
            && cur_entry.data.reg.type != MLINE
            && cur_entry.data.reg.type != MBLOCK) {
          shada_free_shada_entry(&cur_entry);
          break;
        }
        register_set(cur_entry.data.reg.name, (yankreg_T) {
          .y_array = (char_u **) cur_entry.data.reg.contents,
          .y_size = (linenr_T) cur_entry.data.reg.contents_size,
          .y_type = cur_entry.data.reg.type,
          .y_width = (colnr_T) cur_entry.data.reg.width,
          .timestamp = cur_entry.timestamp,
          .additional_data = cur_entry.data.reg.additional_data,
        });
        // Do not free shada entry: its allocated memory was saved above.
        break;
      }
      case kSDItemVariable: {
        typval_T vartv;
        Error err;
        if (!object_to_vim(cur_entry.data.global_var.value, &vartv, &err)) {
          if (err.set) {
            emsg3("Error while reading ShaDa file: "
                  "failed to read value for variable %s: %s",
                  cur_entry.data.global_var.name, err.msg);
          }
          break;
        }
        var_set_global(cur_entry.data.global_var.name, vartv);
        shada_free_shada_entry(&cur_entry);
        break;
      }
      case kSDItemJump:
      case kSDItemGlobalMark: {
        buf_T *buf = find_buffer(fname_bufs, cur_entry.data.filemark.fname);
        if (buf != NULL) {
          xfree(cur_entry.data.filemark.fname);
          cur_entry.data.filemark.fname = NULL;
        }
        xfmark_T fm = (xfmark_T) {
          .fname = (char_u *) (buf == NULL
                               ? cur_entry.data.filemark.fname
                               : NULL),
          .fmark = {
            .mark = cur_entry.data.filemark.mark,
            .fnum = (buf == NULL ? 0 : buf->b_fnum),
            .timestamp = cur_entry.timestamp,
            .additional_data = cur_entry.data.filemark.additional_data,
          },
        };
        if (cur_entry.type == kSDItemGlobalMark) {
          mark_set_global(cur_entry.data.filemark.name, fm, !force);
        } else {
          if (force) {
            if (curwin->w_jumplistlen == JUMPLISTSIZE) {
              // Jump list items are ignored in this case.
              free_xfmark(fm);
            } else {
              memmove(&curwin->w_jumplist[1], &curwin->w_jumplist[0],
                      sizeof(curwin->w_jumplist[0])
                      * (size_t) curwin->w_jumplistlen);
              curwin->w_jumplistidx++;
              curwin->w_jumplistlen++;
              curwin->w_jumplist[0] = fm;
            }
          } else {
            const int jl_len = curwin->w_jumplistlen;
            int i;
            for (i = 0; i < jl_len; i++) {
              const xfmark_T jl_fm = curwin->w_jumplist[i];
              if (jl_fm.fmark.timestamp >= cur_entry.timestamp) {
                if (marks_equal(fm.fmark.mark, jl_fm.fmark.mark)
                    && (buf == NULL
                        ? (jl_fm.fname != NULL
                           && STRCMP(fm.fname, jl_fm.fname) == 0)
                        : fm.fmark.fnum == jl_fm.fmark.fnum)) {
                  i = -1;
                }
                break;
              }
            }
            if (i != -1) {
              if (i < jl_len) {
                if (jl_len == JUMPLISTSIZE) {
                  free_xfmark(curwin->w_jumplist[0]);
                  memmove(&curwin->w_jumplist[0], &curwin->w_jumplist[1],
                          sizeof(curwin->w_jumplist[0]) * (size_t) i);
                } else {
                  memmove(&curwin->w_jumplist[i + 1], &curwin->w_jumplist[i],
                          sizeof(curwin->w_jumplist[0])
                          * (size_t) (jl_len - i));
                }
              } else if (i == jl_len) {
                if (jl_len == JUMPLISTSIZE) {
                  i = -1;
                } else if (jl_len > 0) {
                  memmove(&curwin->w_jumplist[1], &curwin->w_jumplist[0],
                          sizeof(curwin->w_jumplist[0])
                          * (size_t) jl_len);
                }
              }
            }
            if (i != -1) {
              curwin->w_jumplist[i] = fm;
              if (jl_len < JUMPLISTSIZE) {
                curwin->w_jumplistlen++;
              }
              if (curwin->w_jumplistidx > i
                  && curwin->w_jumplistidx + 1 < curwin->w_jumplistlen) {
                curwin->w_jumplistidx++;
              }
            } else {
              shada_free_shada_entry(&cur_entry);
            }
          }
        }
        // Do not free shada entry: its allocated memory was saved above.
        break;
      }
      case kSDItemBufferList: {
        for (size_t i = 0; i < cur_entry.data.buffer_list.size; i++) {
          char *const sfname = path_shorten_fname_if_possible(
              cur_entry.data.buffer_list.buffers[i].fname);
          buf_T *const buf = buflist_new(
              cur_entry.data.buffer_list.buffers[i].fname, sfname, 0,
              BLN_LISTED);
          if (buf != NULL) {
            RESET_FMARK(&buf->b_last_cursor,
                        cur_entry.data.buffer_list.buffers[i].pos, 0);
            buflist_setfpos(buf, curwin, buf->b_last_cursor.mark.lnum,
                            buf->b_last_cursor.mark.col, false);
          }
        }
        shada_free_shada_entry(&cur_entry);
        break;
      }
      case kSDItemChange:
      case kSDItemLocalMark: {
        buf_T *buf = find_buffer(fname_bufs, cur_entry.data.filemark.fname);
        if (buf == NULL) {
          shada_free_shada_entry(&cur_entry);
          break;
        }
        const fmark_T fm = (fmark_T) {
          .mark = cur_entry.data.filemark.mark,
          .fnum = 0,
          .timestamp = cur_entry.timestamp,
          .additional_data = cur_entry.data.filemark.additional_data,
        };
        if (cur_entry.type == kSDItemLocalMark) {
          mark_set_local(cur_entry.data.filemark.name, buf, fm, !force);
        } else {
          int kh_ret;
          (void) kh_put(bufset, cl_bufs, (uintptr_t) buf, &kh_ret);
          if (force) {
            if (buf->b_changelistlen == JUMPLISTSIZE) {
              free_fmark(buf->b_changelist[0]);
              memmove(buf->b_changelist, buf->b_changelist + 1,
                      sizeof(buf->b_changelist[0]) * (JUMPLISTSIZE - 1));
            } else {
              buf->b_changelistlen++;
            }
            buf->b_changelist[buf->b_changelistlen - 1] = fm;
          } else {
            const int cl_len = buf->b_changelistlen;
            int i;
            for (i = cl_len; i > 0; i--) {
              const fmark_T cl_fm = buf->b_changelist[i - 1];
              if (cl_fm.timestamp <= cur_entry.timestamp) {
                if (marks_equal(fm.mark, cl_fm.mark)) {
                  i = -1;
                }
                break;
              }
            }
            if (i > 0) {
              if (cl_len == JUMPLISTSIZE) {
                free_fmark(buf->b_changelist[0]);
                memmove(&buf->b_changelist[0], &buf->b_changelist[1],
                        sizeof(buf->b_changelist[0]) * (size_t) i);
              } else {
                memmove(&buf->b_changelist[i + 1], &buf->b_changelist[i],
                        sizeof(buf->b_changelist[0])
                        * (size_t) (cl_len - i));
              }
            } else if (i == 0) {
              if (cl_len == JUMPLISTSIZE) {
                i = -1;
              } else if (cl_len > 0) {
                memmove(&buf->b_changelist[1], &buf->b_changelist[0],
                        sizeof(buf->b_changelist[0])
                        * (size_t) cl_len);
              }
            }
            if (i != -1) {
              buf->b_changelist[i] = fm;
              if (cl_len < JUMPLISTSIZE) {
                buf->b_changelistlen++;
              }
            } else {
              shada_free_shada_entry(&cur_entry);
              cur_entry.data.filemark.fname = NULL;
            }
          }
        }
        // Do not free shada entry: except for fname, its allocated memory (i.e. 
        // additional_data attribute contents if non-NULL) was saved above.
        xfree(cur_entry.data.filemark.fname);
        break;
      }
    }
  }
  // Warning: shada_hist_iter returns ShadaEntry elements which use strings from 
  //          original history list. This means that once such entry is removed 
  //          from the history NeoVim array will no longer be valid. To reduce 
  //          amount of memory allocations ShaDa file reader allocates enough 
  //          memory for the history string itself and separator character which 
  //          may be assigned right away.
  if (srni_flags & kSDReadHistory) {
    for (uint8_t i = 0; i < HIST_COUNT; i++) {
      if (hms[i].last_hist_entry.type != kSDItemMissing) {
        insert_history_entry(&(hms[i]), hms[i].last_hist_entry, false);
      }
      while (hms[i].iter != NULL
            && hms[i].last_hist_entry.type != kSDItemMissing) {
        hms[i].iter = shada_hist_iter(hms[i].iter, hms[i].history_type, true,
                                      &(hms[i].last_hist_entry));
        insert_history_entry(&(hms[i]), hms[i].last_hist_entry, false);
      }
      clr_history(i);
      int *new_hisidx;
      int *new_hisnum;
      histentry_T *hist = hist_get_array(i, &new_hisidx, &new_hisnum);
      if (hist != NULL) {
        histentry_T *const hist_init = hist;
        RINGBUF_FORALL(&(hms[i].hmrb), ShadaEntry, cur_entry) {
          hist->timestamp = cur_entry->timestamp;
          hist->hisnum = (int) (hist - hist_init) + 1;
          hist->hisstr = (char_u *) cur_entry->data.history_item.string;
          hist->additional_elements =
              cur_entry->data.history_item.additional_elements;
          hist++;
        }
        *new_hisnum = (int) hm_rb_length(&(hms[i].hmrb));
        *new_hisidx = *new_hisnum - 1;
      }
      hm_rb_dealloc(&(hms[i].hmrb));
    }
  }
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    (void) tp;
    if (in_bufset(cl_bufs, wp->w_buffer)) {
      wp->w_changelistidx = wp->w_buffer->b_changelistlen;
    }
  }
  kh_destroy(bufset, cl_bufs);
  const char *key;
  kh_foreach_key(fname_bufs, key, {
    xfree((void *) key);
  })
  kh_destroy(fnamebufs, fname_bufs);
}

/// Get the ShaDa file name to use
///
/// If "file" is given and not empty, use it (has already been expanded by 
/// cmdline functions). Otherwise use "-i file_name", value from 'viminfo' or 
/// the default, and expand environment variables.
///
/// @param[in]  file  Forced file name or NULL.
///
/// @return An allocated string containing shada file name.
static char *shada_filename(const char *file)
  FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (file == NULL || *file == NUL) {
    if (used_shada_file != NULL) {
      file = used_shada_file;
    } else if ((file = find_viminfo_parameter('n')) == NULL || *file == NUL) {
#ifdef SHADA_FILE2
      // don't use $HOME when not defined (turned into "c:/"!).
      if (os_getenv((char_u *)"HOME") == NULL) {
        // don't use $VIM when not available.
        expand_env((char_u *)"$VIM", NameBuff, MAXPATHL);
        if (STRCMP("$VIM", NameBuff) != 0) {  // $VIM was expanded
          file = SHADA_FILE2;
        } else {
          file = SHADA_FILE;
        }
      } else {
#endif
        file =  SHADA_FILE;
#ifdef SHADA_FILE2
      }
#endif
      // XXX It used to be one level lower, so that whatever is in 
      //     `used_shada_file` was expanded. I intentionally moved it here 
      //     because various expansions must have already be done by the shell. 
      //     If shell is not performing them then they should be done in main.c 
      //     where arguments are parsed, *not here*.
      expand_env((char_u *)file, &(NameBuff[0]), MAXPATHL);
      file = (const char *) &(NameBuff[0]);
    }
  }
  return xstrdup(file);
}

#define PACK_STATIC_STR(s) \
    do { \
      msgpack_pack_str(spacker, sizeof(s) - 1); \
      msgpack_pack_str_body(spacker, s, sizeof(s) - 1); \
    } while (0)

/// Write single ShaDa entry
///
/// @param[in]  packer     Packer used to write entry.
/// @param[in]  entry      Entry written.
/// @param[in]  max_kbyte  Maximum size of an item in KiB. Zero means no 
///                        restrictions.
static void shada_pack_entry(msgpack_packer *const packer,
                             const ShadaEntry entry,
                             const size_t max_kbyte)
  FUNC_ATTR_NONNULL_ALL
{
  if (entry.type == kSDItemMissing) {
    return;
  }
  msgpack_sbuffer sbuf;
  msgpack_sbuffer_init(&sbuf);
  msgpack_packer *spacker = msgpack_packer_new(&sbuf, &msgpack_sbuffer_write);
  switch (entry.type) {
    case kSDItemMissing: {
      assert(false);
    }
    case kSDItemUnknown: {
      msgpack_pack_uint64(packer, (uint64_t) entry.data.unknown_item.size);
      packer->callback(packer->data, entry.data.unknown_item.contents,
                       (unsigned) entry.data.unknown_item.size);
      break;
    }
    case kSDItemHistoryEntry: {
      const bool is_hist_search =
          entry.data.history_item.histtype == HIST_SEARCH;
      const size_t arr_size = 2 + (size_t) is_hist_search + (
          entry.data.history_item.additional_elements == NULL
          ? 0
          : entry.data.history_item.additional_elements->size);
      msgpack_pack_array(spacker, arr_size);
      msgpack_pack_uint8(spacker, entry.data.history_item.histtype);
      msgpack_rpc_from_string(cstr_as_string(entry.data.history_item.string),
                              spacker);
      if (is_hist_search) {
        msgpack_pack_uint8(spacker, (uint8_t) entry.data.history_item.sep);
      }
      for (size_t i = 0; i < arr_size - 2 - (size_t) is_hist_search; i++) {
        msgpack_rpc_from_object(
            entry.data.history_item.additional_elements->items[i], spacker);
      }
      break;
    }
    case kSDItemVariable: {
      const size_t arr_size = 2 + (
          entry.data.global_var.additional_elements == NULL
          ? 0
          : entry.data.global_var.additional_elements->size);
      msgpack_pack_array(spacker, arr_size);
      msgpack_rpc_from_string(cstr_as_string(entry.data.global_var.name),
                              spacker);
      msgpack_rpc_from_object(entry.data.global_var.value, spacker);
      for (size_t i = 0; i < arr_size - 2; i++) {
        msgpack_rpc_from_object(
            entry.data.global_var.additional_elements->items[i], spacker);
      }
      break;
    }
    case kSDItemSubString: {
      const size_t arr_size = 1 + (
          entry.data.sub_string.additional_elements == NULL
          ? 0
          : entry.data.sub_string.additional_elements->size);
      msgpack_pack_array(spacker, arr_size);
      msgpack_rpc_from_string(cstr_as_string(entry.data.sub_string.sub),
                              spacker);
      for (size_t i = 0; i < arr_size - 1; i++) {
        msgpack_rpc_from_object(
            entry.data.sub_string.additional_elements->items[i], spacker);
      }
      break;
    }
    case kSDItemSearchPattern: {
      const size_t map_size = (size_t) (
          1 // Search pattern is always present
          // Following items default to true:
          + !entry.data.search_pattern.magic
          + !entry.data.search_pattern.is_last_used
          // Following items default to false:
          + entry.data.search_pattern.smartcase
          + entry.data.search_pattern.has_line_offset
          + entry.data.search_pattern.place_cursor_at_end
          + entry.data.search_pattern.is_substitute_pattern
          // offset defaults to zero:
          + (entry.data.search_pattern.offset != 0)
          // finally, additional data:
          + (entry.data.search_pattern.additional_data
             ? entry.data.search_pattern.additional_data->size
             : 0)
      );
      msgpack_pack_map(spacker, map_size);
      PACK_STATIC_STR("pat");
      msgpack_rpc_from_string(cstr_as_string(entry.data.search_pattern.pat),
                              spacker);
#define PACK_BOOL(name, attr, nondef_value) \
      do { \
        if (entry.data.search_pattern.attr == nondef_value) { \
          PACK_STATIC_STR(name); \
          msgpack_pack_##nondef_value(spacker); \
        } \
      } while (0)
      PACK_BOOL("magic", magic, false);
      PACK_BOOL("islast", is_last_used, false);
      PACK_BOOL("smartcase", smartcase, true);
      PACK_BOOL("lineoff", has_line_offset, true);
      PACK_BOOL("curatend", place_cursor_at_end, true);
      PACK_BOOL("sub", is_substitute_pattern, true);
      if (entry.data.search_pattern.offset) {
        PACK_STATIC_STR("off");
        msgpack_pack_int64(spacker, entry.data.search_pattern.offset);
      }
#undef PACK_BOOL
      if (entry.data.search_pattern.additional_data != NULL) {
        for (size_t i = 0; i < entry.data.search_pattern.additional_data->size;
            i++) {
          msgpack_rpc_from_string(
              entry.data.search_pattern.additional_data->items[i].key, spacker);
          msgpack_rpc_from_object(
              entry.data.search_pattern.additional_data->items[i].value,
              spacker);
        }
      }
      break;
    }
    case kSDItemChange:
    case kSDItemGlobalMark:
    case kSDItemLocalMark:
    case kSDItemJump: {
      const size_t map_size = (size_t) (
          1  // File name
          // Line: defaults to 1
          + (entry.data.filemark.mark.lnum != 1)
          // Column: defaults to zero:
          + (entry.data.filemark.mark.col != 0)
          // Mark name: defaults to '"'
          + (entry.type != kSDItemJump
             && entry.type != kSDItemChange
             && entry.data.filemark.name != '"')
          // Additional entries, if any:
          + (entry.data.filemark.additional_data == NULL
             ? 0
             : entry.data.filemark.additional_data->size)
      );
      msgpack_pack_map(spacker, map_size);
      PACK_STATIC_STR("file");
      msgpack_rpc_from_string(cstr_as_string(entry.data.filemark.fname),
                              spacker);
      if (entry.data.filemark.mark.lnum != 1) {
        PACK_STATIC_STR("line");
        msgpack_pack_long(spacker, entry.data.filemark.mark.lnum);
      }
      if (entry.data.filemark.mark.col != 0) {
        PACK_STATIC_STR("col");
        msgpack_pack_long(spacker, entry.data.filemark.mark.col);
      }
      if (entry.data.filemark.name != '"' && entry.type != kSDItemJump
          && entry.type != kSDItemChange) {
        PACK_STATIC_STR("name");
        msgpack_pack_uint8(spacker, (uint8_t) entry.data.filemark.name);
      }
      if (entry.data.filemark.additional_data != NULL) {
        for (size_t i = 0; i < entry.data.filemark.additional_data->size;
            i++) {
          msgpack_rpc_from_string(
              entry.data.filemark.additional_data->items[i].key, spacker);
          msgpack_rpc_from_object(
              entry.data.filemark.additional_data->items[i].value, spacker);
        }
      }
      break;
    }
    case kSDItemRegister: {
      const size_t map_size = (size_t) (
          2  // Register contents and name
          // Register type: defaults to MCHAR
          + (entry.data.reg.type != MCHAR)
          // Register width: defaults to zero
          + (entry.data.reg.width != 0)
          // Additional entries, if any:
          + (entry.data.reg.additional_data == NULL
             ? 0
             : entry.data.reg.additional_data->size)
      );
      msgpack_pack_map(spacker, map_size);
      PACK_STATIC_STR("contents");
      msgpack_pack_array(spacker, entry.data.reg.contents_size);
      for (size_t i = 0; i < entry.data.reg.contents_size; i++) {
        msgpack_rpc_from_string(cstr_as_string(entry.data.reg.contents[i]),
                                spacker);
      }
      PACK_STATIC_STR("name");
      msgpack_pack_char(spacker, entry.data.reg.name);
      if (entry.data.reg.type != MCHAR) {
        PACK_STATIC_STR("type");
        msgpack_pack_uint8(spacker, entry.data.reg.type);
      }
      if (entry.data.reg.width != 0) {
        PACK_STATIC_STR("width");
        msgpack_pack_uint64(spacker, (uint64_t) entry.data.reg.width);
      }
      if (entry.data.reg.additional_data != NULL) {
        for (size_t i = 0; i < entry.data.reg.additional_data->size;
            i++) {
          msgpack_rpc_from_string(entry.data.reg.additional_data->items[i].key,
                                  spacker);
          msgpack_rpc_from_object(
              entry.data.reg.additional_data->items[i].value, spacker);
        }
      }
      break;
    }
    case kSDItemBufferList: {
      msgpack_pack_array(spacker, entry.data.buffer_list.size);
      for (size_t i = 0; i < entry.data.buffer_list.size; i++) {
        const size_t map_size = (size_t) (
            1  // Buffer name
            // Line number: defaults to 1
            + (entry.data.buffer_list.buffers[i].pos.lnum != 1)
            // Column number: defaults to 0
            + (entry.data.buffer_list.buffers[i].pos.col != 0)
            // Additional entries, if any:
            + (entry.data.buffer_list.buffers[i].additional_data == NULL
               ? 0
               : entry.data.buffer_list.buffers[i].additional_data->size)
        );
        msgpack_pack_map(spacker, map_size);
        PACK_STATIC_STR("file");
        msgpack_rpc_from_string(
            cstr_as_string(entry.data.buffer_list.buffers[i].fname), spacker);
        if (entry.data.buffer_list.buffers[i].pos.lnum != 1) {
          PACK_STATIC_STR("line");
          msgpack_pack_uint64(
              spacker, (uint64_t) entry.data.buffer_list.buffers[i].pos.lnum);
        }
        if (entry.data.buffer_list.buffers[i].pos.col != 0) {
          PACK_STATIC_STR("col");
          msgpack_pack_uint64(
              spacker, (uint64_t) entry.data.buffer_list.buffers[i].pos.col);
        }
        if (entry.data.buffer_list.buffers[i].additional_data != NULL) {
          for (size_t j = 0;
               j < entry.data.buffer_list.buffers[i].additional_data->size;
               j++) {
            msgpack_rpc_from_string(
              entry.data.buffer_list.buffers[i].additional_data->items[j].key,
              spacker);
            msgpack_rpc_from_object(
              entry.data.buffer_list.buffers[i].additional_data->items[j].value,
              spacker);
          }
        }
      }
      break;
    }
    case kSDItemHeader: {
      msgpack_rpc_from_dictionary(entry.data.header, spacker);
      break;
    }
  }
  if (!max_kbyte || sbuf.size <= max_kbyte * 1024) {
    if (entry.type == kSDItemUnknown) {
      msgpack_pack_uint64(packer, (uint64_t) entry.data.unknown_item.type);
    } else {
      msgpack_pack_uint64(packer, (uint64_t) entry.type);
    }
    msgpack_pack_uint64(packer, (uint64_t) entry.timestamp);
    if (sbuf.size > 0) {
      msgpack_pack_uint64(packer, (uint64_t) sbuf.size);
      packer->callback(packer->data, sbuf.data, (unsigned) sbuf.size);
    }
  }
  msgpack_packer_free(spacker);
  msgpack_sbuffer_destroy(&sbuf);
}

/// Write ShaDa file
///
/// @param[in]  sd_writer  Structure containing file writer definition.
/// @param[in]  sd_reader  Structure containing file reader definition. If it is 
///                        not NULL then contents of this file will be merged 
///                        with current NeoVim runtime.
static void shada_write(ShaDaWriteDef *const sd_writer,
                        ShaDaReadDef *const sd_reader)
  FUNC_ATTR_NONNULL_ARG(1)
{
  khash_t(bufset) *const removable_bufs = kh_init(bufset);
  int max_kbyte_i = get_viminfo_parameter('s');
  if (max_kbyte_i < 0) {
    max_kbyte_i = 10;
  }
  if (max_kbyte_i == 0) {
    return;
  }
  const size_t max_kbyte = (size_t) max_kbyte_i;

  msgpack_packer *packer = msgpack_packer_new(sd_writer,
                                              &msgpack_sd_writer_write);

  FOR_ALL_BUFFERS(buf) {
    if (buf->b_ffname != NULL && shada_removable((char *) buf->b_ffname)) {
      int kh_ret;
      (void) kh_put(bufset, removable_bufs, (uintptr_t) buf, &kh_ret);
    }
  }

  // TODO(ZyX-I): Iterate over sd_reader, keeping “replaced” values in a set.

  // First write values that do not require merging
  // 1. Header
  shada_pack_entry(packer, (ShadaEntry) {
    .type = kSDItemHeader,
    .timestamp = os_time(),
    .data = {
      .header = {
        .size = 4,
        .capacity = 4,
        .items = ((KeyValuePair []) {
          { STATIC_CSTR_AS_STRING("version"),
            STRING_OBJ(cstr_as_string(longVersion)) },
          { STATIC_CSTR_AS_STRING("max_kbyte"),
            INTEGER_OBJ((Integer) max_kbyte) },
          { STATIC_CSTR_AS_STRING("pid"),
            INTEGER_OBJ((Integer) os_get_pid()) },
          { STATIC_CSTR_AS_STRING("encoding"),
            STRING_OBJ(cstr_as_string((char *) p_enc)) },
        }),
      }
    }
  }, 0);

  // 2. Buffer list
  if (find_viminfo_parameter('%') != NULL) {
    size_t buf_count = 0;
    FOR_ALL_BUFFERS(buf) {
      if (buf->b_ffname != NULL && !SHADA_REMOVABLE(buf)) {
        buf_count++;
      }
    }

    ShadaEntry buflist_entry = (ShadaEntry) {
      .type = kSDItemBufferList,
      .timestamp = os_time(),
      .data = {
        .buffer_list = {
          .size = buf_count,
          .buffers = xmalloc(buf_count
                             * sizeof(*buflist_entry.data.buffer_list.buffers)),
        },
      },
    };
    size_t i = 0;
    FOR_ALL_BUFFERS(buf) {
      if (buf->b_ffname == NULL || SHADA_REMOVABLE(buf)) {
        continue;
      }
      buflist_entry.data.buffer_list.buffers[i] = (struct buffer_list_buffer) {
        .pos = buf->b_last_cursor.mark,
        .fname = (char *) buf->b_ffname,
        .additional_data = buf->additional_data,
      };
      i++;
    }
    shada_pack_entry(packer, buflist_entry, 0);
    xfree(buflist_entry.data.buffer_list.buffers);
  }

  // 3. Jump list
  const void *jump_iter = NULL;
  do {
    xfmark_T fm;
    cleanup_jumplist();
    jump_iter = mark_jumplist_iter(jump_iter, curwin, &fm);
    const buf_T *const buf = (fm.fmark.fnum == 0
                              ? NULL
                              : buflist_findnr(fm.fmark.fnum));
    if (buf != NULL
        ? SHADA_REMOVABLE(buf)
        : fm.fmark.fnum != 0) {
      continue;
    }
    const char *const fname = (char *) (fm.fmark.fnum == 0
                                        ? (fm.fname == NULL
                                           ? NULL
                                           : fm.fname)
                                        : buf->b_ffname);
    shada_pack_entry(packer, (ShadaEntry) {
      .type = kSDItemJump,
      .timestamp = fm.fmark.timestamp,
      .data = {
        .filemark = {
          .name = NUL,
          .mark = fm.fmark.mark,
          .fname = (char *) fname,
          .additional_data = fm.fmark.additional_data,
        }
      }
    }, max_kbyte);
  } while (jump_iter != NULL);

  // FIXME No merging currently

#define RUN_WITH_CONVERTED_STRING(cstr, code) \
  do { \
    bool did_convert = false; \
    if (sd_writer->sd_conv.vc_type != CONV_NONE && has_non_ascii((cstr))) { \
      char *const converted_string = string_convert(&sd_writer->sd_conv, \
                                                    (cstr), NULL); \
      if (converted_string != NULL) { \
        (cstr) = converted_string; \
        did_convert = true; \
      } \
    } \
    code \
    if (did_convert) { \
      xfree((cstr)); \
    } \
  } while (0)
  // 4. History
  HistoryMergerState hms[HIST_COUNT];
  for (uint8_t i = 0; i < HIST_COUNT; i++) {
    long num_saved = get_viminfo_parameter(hist_type2char(i));
    if (num_saved == -1) {
      num_saved = p_hi;
    }
    if (num_saved > 0) {
      HistoryMergerState *hms_p = &(hms[i]);
      hms_p->hmrb = hm_rb_new((size_t) num_saved);
      hms_p->do_merge = false;
      hms_p->iter = shada_hist_iter(NULL, i, false, &(hms[i].last_hist_entry));
      hms_p->history_type = i;
      if (hms_p->last_hist_entry.type != kSDItemMissing) {
        hm_rb_push(&(hms_p->hmrb), hms_p->last_hist_entry);
        while (hms_p->iter != NULL) {
          hms_p->iter = shada_hist_iter(hms_p->iter, hms_p->history_type, false,
                                        &(hms_p->last_hist_entry));
          if (hms_p->last_hist_entry.type != kSDItemMissing) {
            hm_rb_push(&(hms_p->hmrb), hms_p->last_hist_entry);
          } else {
            break;
          }
        }
      }
      RINGBUF_FORALL(&(hms_p->hmrb), ShadaEntry, cur_entry) {
        RUN_WITH_CONVERTED_STRING(cur_entry->data.history_item.string, {
          shada_pack_entry(packer, *cur_entry, max_kbyte);
        });
      }
      hm_rb_dealloc(&hms_p->hmrb);
    }
  }

  // 5. Search patterns
  {
    SearchPattern pat;
    get_search_pattern(&pat);
    ShadaEntry sp_entry = (ShadaEntry) {
      .type = kSDItemSearchPattern,
      .timestamp = pat.timestamp,
      .data = {
        .search_pattern = {
          .magic = pat.magic,
          .smartcase = !pat.no_scs,
          .has_line_offset = pat.off.line,
          .place_cursor_at_end = pat.off.end,
          .offset = pat.off.off,
          .is_last_used = search_was_last_used(),
          .is_substitute_pattern = false,
          .pat = (char *) pat.pat,
          .additional_data = pat.additional_data,
        }
      }
    };
    RUN_WITH_CONVERTED_STRING(sp_entry.data.search_pattern.pat, {
      shada_pack_entry(packer, sp_entry, max_kbyte);
    });
  }
  {
    SearchPattern pat;
    get_substitute_pattern(&pat);
    ShadaEntry sp_entry = (ShadaEntry) {
      .type = kSDItemSearchPattern,
      .timestamp = pat.timestamp,
      .data = {
        .search_pattern = {
          .magic = pat.magic,
          .smartcase = !pat.no_scs,
          .has_line_offset = false,
          .place_cursor_at_end = false,
          .offset = 0,
          .is_last_used = !search_was_last_used(),
          .is_substitute_pattern = true,
          .pat = (char *) pat.pat,
          .additional_data = pat.additional_data,
        }
      }
    };
    RUN_WITH_CONVERTED_STRING(sp_entry.data.search_pattern.pat, {
      shada_pack_entry(packer, sp_entry, max_kbyte);
    });
  }

  // 6. Substitute string
  {
    SubReplacementString sub;
    sub_get_replacement(&sub);
    ShadaEntry sub_entry = (ShadaEntry) {
      .type = kSDItemSubString,
      .timestamp = sub.timestamp,
      .data = {
        .sub_string = {
          .sub = (char *) sub.sub,
          .additional_elements = sub.additional_elements,
        }
      }
    };
    RUN_WITH_CONVERTED_STRING(sub_entry.data.sub_string.sub, {
      shada_pack_entry(packer, sub_entry, max_kbyte);
    });
  }

  // 7. Global marks
  if (get_viminfo_parameter('f') != 0) {
    ShadaEntry *const global_marks = list_global_marks(removable_bufs);
    for (ShadaEntry *mark = global_marks; mark->type != kSDItemMissing;
         mark++) {
      shada_pack_entry(packer, *mark, max_kbyte);
    }
    xfree(global_marks);
  }

  // 8. Buffer marks and buffer change list
  FOR_ALL_BUFFERS(buf) {
    if (buf->b_ffname == NULL || SHADA_REMOVABLE(buf)) {
      continue;
    }
    ShadaEntry *const buffer_marks = list_buffer_marks(buf);
    for (ShadaEntry *mark = buffer_marks; mark->type != kSDItemMissing;
         mark++) {
      shada_pack_entry(packer, *mark, max_kbyte);
    }
    xfree(buffer_marks);

    for (int i = 0; i < buf->b_changelistlen; i++) {
      const fmark_T fm = buf->b_changelist[i];
      shada_pack_entry(packer, (ShadaEntry) {
        .type = kSDItemChange,
        .timestamp = fm.timestamp,
        .data = {
          .filemark = {
            .mark = fm.mark,
            .fname = (char *) buf->b_ffname,
            .additional_data = fm.additional_data,
          }
        }
      }, max_kbyte);
    }
  }
  // FIXME: Copy previous marks, up to num_marked_files
  // size_t num_marked_files = get_viminfo_parameter('\'');

  // 9. Registers
  int max_num_lines_i = get_viminfo_parameter('<');
  if (max_num_lines_i < 0) {
    max_num_lines_i = get_viminfo_parameter('"');
  }
  if (max_num_lines_i != 0) {
    const size_t max_num_lines = (max_num_lines_i < 0
                                  ? 0
                                  : (size_t) max_num_lines_i);
    ShadaEntry *const registers = list_registers(max_num_lines);
    for (ShadaEntry *reg = registers; reg->type != kSDItemMissing; reg++) {
      bool did_convert = false;
      if (sd_writer->sd_conv.vc_type != CONV_NONE) {
        did_convert = true;
        reg->data.reg.contents = xmemdup(reg->data.reg.contents,
                                         (reg->data.reg.contents_size
                                          * sizeof(reg->data.reg.contents)));
        for (size_t i = 0; i < reg->data.reg.contents_size; i++) {
          reg->data.reg.contents[i] = get_converted_string(
              &sd_writer->sd_conv,
              reg->data.reg.contents[i], strlen(reg->data.reg.contents[i]));
        }
      }
      shada_pack_entry(packer, *reg, max_kbyte);
      if (did_convert) {
        for (size_t i = 0; i < reg->data.reg.contents_size; i++) {
          xfree(reg->data.reg.contents[i]);
        }
        xfree(reg->data.reg.contents);
      }
    }
    xfree(registers);
  }

  // 10. Variables
  if (find_viminfo_parameter('!') != NULL) {
    const void *var_iter = NULL;
    const Timestamp cur_timestamp = os_time();
    do {
      typval_T vartv;
      const char *name;
      var_iter = var_shada_iter(var_iter, &name, &vartv);
      if (var_iter == NULL && vartv.v_type == VAR_UNKNOWN) {
        break;
      }
      Object obj = vim_to_object(&vartv);
      if (sd_writer->sd_conv.vc_type != CONV_NONE) {
        convert_object(&sd_writer->sd_conv, &obj);
      }
      shada_pack_entry(packer, (ShadaEntry) {
        .type = kSDItemVariable,
        .timestamp = cur_timestamp,
        .data = {
          .global_var = {
            .name = (char *) name,
            .value = obj,
            .additional_elements = NULL,
          }
        }
      }, max_kbyte);
      api_free_object(obj);
      clear_tv(&vartv);
    } while (var_iter != NULL);
  }
#undef RUN_WITH_CONVERTED_STRING

  kh_destroy(bufset, removable_bufs);
  msgpack_packer_free(packer);
}

#undef PACK_STATIC_STR

/// Write ShaDa file to a given location
///
/// @param[in]  fname    File to write to. If it is NULL or empty then default 
///                      location is used.
/// @param[in]  nomerge  If true then old file is ignored.
///
/// @return OK if writing was successfull, FAIL otherwise.
int shada_write_file(const char *const file, const bool nomerge)
{
  char *const fname = shada_filename(file);
  ShaDaWriteDef sd_writer = (ShaDaWriteDef) {
    .write = &write_file,
    .error = NULL,
  };

  const intptr_t fd = (intptr_t) open_file(fname,
                                           O_CREAT|O_WRONLY|O_NOFOLLOW|O_TRUNC,
                                           0600);

  if (p_verbose > 0) {
    verbose_enter();
    smsg(_("Writing viminfo file \"%s\""), fname);
    verbose_leave();
  }

  xfree(fname);
  if (fd == -1) {
    return FAIL;
  }

  sd_writer.cookie = (void *) fd;

  convert_setup(&sd_writer.sd_conv, p_enc, "utf-8");

  shada_write(&sd_writer, NULL);

  close_file((int)(intptr_t) sd_writer.cookie);
  return OK;
}

/// Read marks information from ShaDa file
///
/// @return OK in case of success, FAIL otherwise.
int shada_read_marks(void)
{
  return shada_read_file(NULL, kShaDaWantMarks);
}

/// Read all information from ShaDa file
///
/// @param[in]  fname    File to write to. If it is NULL or empty then default 
///
/// @return OK in case of success, FAIL otherwise.
int shada_read_everything(const char *const fname, const bool forceit)
{
  return shada_read_file(fname,
                         kShaDaWantInfo|kShaDaWantMarks|kShaDaGetOldfiles
                         |(forceit?kShaDaForceit:0));
}

static void shada_free_shada_entry(ShadaEntry *const entry)
{
  if (entry == NULL) {
    return;
  }
  switch (entry->type) {
    case kSDItemMissing: {
      break;
    }
    case kSDItemUnknown: {
      xfree(entry->data.unknown_item.contents);
      break;
    }
    case kSDItemHeader: {
      api_free_dictionary(entry->data.header);
      break;
    }
    case kSDItemChange:
    case kSDItemJump:
    case kSDItemGlobalMark:
    case kSDItemLocalMark: {
      if (entry->data.filemark.additional_data != NULL) {
        api_free_dictionary(*entry->data.filemark.additional_data);
        xfree(entry->data.filemark.additional_data);
      }
      xfree(entry->data.filemark.fname);
      break;
    }
    case kSDItemSearchPattern: {
      if (entry->data.search_pattern.additional_data != NULL) {
        api_free_dictionary(*entry->data.search_pattern.additional_data);
        xfree(entry->data.search_pattern.additional_data);
      }
      xfree(entry->data.search_pattern.pat);
      break;
    }
    case kSDItemRegister: {
      if (entry->data.reg.additional_data != NULL) {
        api_free_dictionary(*entry->data.reg.additional_data);
        xfree(entry->data.reg.additional_data);
      }
      for (size_t i = 0; i < entry->data.reg.contents_size; i++) {
        xfree(entry->data.reg.contents[i]);
      }
      xfree(entry->data.reg.contents);
      break;
    }
    case kSDItemHistoryEntry: {
      if (entry->data.history_item.canfree) {
        if (entry->data.history_item.additional_elements != NULL) {
          api_free_array(*entry->data.history_item.additional_elements);
          xfree(entry->data.history_item.additional_elements);
        }
        xfree(entry->data.history_item.string);
      }
      break;
    }
    case kSDItemVariable: {
      if (entry->data.global_var.additional_elements != NULL) {
        api_free_array(*entry->data.global_var.additional_elements);
        xfree(entry->data.global_var.additional_elements);
      }
      xfree(entry->data.global_var.name);
      api_free_object(entry->data.global_var.value);
      break;
    }
    case kSDItemSubString: {
      if (entry->data.sub_string.additional_elements != NULL) {
        api_free_array(*entry->data.sub_string.additional_elements);
        xfree(entry->data.sub_string.additional_elements);
      }
      xfree(entry->data.sub_string.sub);
      break;
    }
    case kSDItemBufferList: {
      for (size_t i = 0; i < entry->data.buffer_list.size; i++) {
        xfree(entry->data.buffer_list.buffers[i].fname);
        if (entry->data.buffer_list.buffers[i].additional_data != NULL) {
          api_free_dictionary(
              *entry->data.buffer_list.buffers[i].additional_data);
          xfree(entry->data.buffer_list.buffers[i].additional_data);
        }
      }
      xfree(entry->data.buffer_list.buffers);
      break;
    }
  }
}

#ifndef __GLIBC__
static inline uint64_t be64toh(uint64_t big_endian_64_bits)
{
#ifdef SHADA_BIG_ENDIAN
  return big_endian_64_bits;
#else
  uint8_t *buf = &big_endian_64_bits;
  uint64_t ret = 0;
  for (size_t i = 8; i; i--) {
    ret |= ((uint64_t) buf[i - 1]) << ((8 - i) * 8);
  }
  return ret;
#endif
}
#endif

/// Read given number of bytes into given buffer, display error if needed
///
/// @param[in]   sd_reader  Structure containing file reader definition.
/// @param[out]  buffer     Where to save the results. May be NULL.
/// @param[in]   length     How many bytes should be read.
///
/// @return FAIL if reading was not successfull, OK otherwise.
static int fread_len(ShaDaReadDef *const sd_reader, char *const buffer,
                     const size_t length)
  FUNC_ATTR_NONNULL_ARG(1) FUNC_ATTR_WARN_UNUSED_RESULT
{
  ptrdiff_t read_bytes = 0;
  if (buffer == NULL) {
    do {
      ptrdiff_t new_read_bytes = sd_reader->read(
          sd_reader, IObuff, (size_t) (length - (size_t) read_bytes > IOSIZE
                                       ? IOSIZE
                                       : length - (size_t) read_bytes));
      if (new_read_bytes == -1) {
        break;
      }
      read_bytes += new_read_bytes;
    } while ((size_t) read_bytes < length && !sd_reader->eof);
  } else {
    read_bytes = sd_reader->read(sd_reader, buffer, length);
  }

  if (sd_reader->error != NULL) {
    emsg2("System error while reading ShaDa file: %s", sd_reader->error);
    return FAIL;
  } else if (sd_reader->eof) {
    emsgu("Error while reading ShaDa file: "
          "last entry specified that it occupies %" PRIu64 " bytes, "
          "but file ended earlier",
          (uint64_t) length);
    return FAIL;
  }
  assert(read_bytes >= 0 && (size_t) read_bytes == length);
  return OK;
}

/// Read next unsigned integer from file
///
/// Errors out if the result is not an unsigned integer.
///
/// Unlike msgpack own function this one works with `FILE *` and reads *exactly* 
/// as much bytes as needed, making it possible to avoid both maintaining own 
/// buffer and calling `fseek`.
///
/// One byte from file stream is always consumed, even if it is not correct.
///
/// @param[in]   sd_reader  Structure containing file reader definition.
/// @param[out]  result     Location where result is saved.
///
/// @return OK if read was successfull, FAIL if it was not.
static int msgpack_read_uint64(ShaDaReadDef *const sd_reader,
                               const int first_char,
                               uint64_t *const result)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const uintmax_t fpos = sd_reader->fpos - 1;

  if (first_char == EOF) {
    if (sd_reader->error) {
      emsg2("System error while reading integer from ShaDa file: %s",
            sd_reader->error);
    } else if (sd_reader->eof) {
      emsgu("Error while reading ShaDa file: "
            "expected positive integer at position %" PRIu64
            ", but got nothing",
            (uint64_t) fpos);
    }
    return FAIL;
  }

  if (~first_char & 0x80) {
    // Positive fixnum
    *result = (uint64_t) ((uint8_t) first_char);
  } else {
    size_t length = 0;
    switch (first_char) {
      case 0xCC: { // uint8
        length = 1;
        break;
      }
      case 0xCD: { // uint16
        length = 2;
        break;
      }
      case 0xCE: { // uint32
        length = 4;
        break;
      }
      case 0xCF: { // uint64
        length = 8;
        break;
      }
      default: {
        emsgu("Error while reading ShaDa file: "
              "expected positive integer at position %" PRIu64,
              (uint64_t) fpos);
        return FAIL;
      }
    }
    uint8_t buf[sizeof(uint64_t)] = {0, 0, 0, 0, 0, 0, 0, 0};
    if (fread_len(sd_reader, (char *) &(buf[sizeof(uint64_t)-length]), length)
        != OK) {
      return FAIL;
    }
    *result = be64toh(*((uint64_t *) &(buf[0])));
  }
  return OK;
}

/// Convert all strings in one Object instance
///
/// @param[in]      sd_conv  Conversion definition.
/// @param[in,out]  obj      Object to convert.
static void convert_object(const vimconv_T *const sd_conv, Object *const obj)
  FUNC_ATTR_NONNULL_ALL
{
  kvec_t(Object *) toconv;
  kv_init(toconv);
  kv_push(Object *, toconv, obj);
  while (kv_size(toconv)) {
    Object *cur_obj = kv_pop(toconv);
#define CONVERT_STRING(str) \
    do { \
      if (!has_non_ascii((str).data)) { \
        break; \
      } \
      size_t len = (str).size; \
      char *const converted_string = string_convert(sd_conv, (str).data, \
                                                    &len); \
      if (converted_string != NULL) { \
        xfree((str).data); \
        (str).data = converted_string; \
        (str).size = len; \
      } \
    } while (0)
    switch (cur_obj->type) {
      case kObjectTypeNil:
      case kObjectTypeInteger:
      case kObjectTypeBoolean:
      case kObjectTypeFloat: {
        break;
      }
      case kObjectTypeString: {
        CONVERT_STRING(cur_obj->data.string);
        break;
      }
      case kObjectTypeArray: {
        for (size_t i = 0; i < cur_obj->data.array.size; i++) {
          Object *element = &cur_obj->data.array.items[i];
          if (element->type == kObjectTypeDictionary
              || element->type == kObjectTypeArray) {
            kv_push(Object *, toconv, element);
          } else if (element->type == kObjectTypeString) {
            CONVERT_STRING(element->data.string);
          }
        }
        break;
      }
      case kObjectTypeDictionary: {
        for (size_t i = 0; i < cur_obj->data.dictionary.size; i++) {
          CONVERT_STRING(cur_obj->data.dictionary.items[i].key);
          Object *value = &cur_obj->data.dictionary.items[i].value;
          if (value->type == kObjectTypeDictionary
              || value->type == kObjectTypeArray) {
            kv_push(Object *, toconv, value);
          } else if (value->type == kObjectTypeString) {
            CONVERT_STRING(value->data.string);
          }
        }
        break;
      }
      default: {
        assert(false);
      }
    }
#undef CONVERT_STRING
  }
  kv_destroy(toconv);
}

/// Convert or copy and return a string
///
/// @param[in]  sd_conv  Conversion definition.
/// @param[in]  str      String to convert.
/// @param[in]  len      String length.
///
/// @return [allocated] converted string or copy of the original string.
static inline char *get_converted_string(const vimconv_T *const sd_conv,
                                         const char *const str, const size_t len)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (!has_non_ascii_len(str, len)) {
    return xmemdupz(str, len);
  }
  size_t new_len = len;
  char *const new_str = string_convert(sd_conv, str, &new_len);
  if (new_str == NULL) {
    return xmemdupz(str, len);
  }
  return new_str;
}

/// Iterate over shada file contents
///
/// @param[in]   sd_reader  Structure containing file reader definition.
/// @param[out]  entry      Address where next entry contents will be saved.
/// @param[in]   flags      Flags, determining whether and which items should be 
///                         skipped (see SRNIFlags enum).
///
/// @return NOTDONE if entry was read correctly, FAIL if there were errors and 
///         OK at EOF.
static int shada_read_next_item(ShaDaReadDef *const sd_reader,
                                ShadaEntry *const entry,
                                const unsigned flags)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
shada_read_next_item_start:
  entry->type = kSDItemMissing;
  if (sd_reader->eof) {
    return OK;
  }

  // First: manually unpack type, timestamp and length.
  // This is needed to avoid both seeking and having to maintain a buffer.
  uint64_t type_u64 = (uint64_t) kSDItemMissing;
  uint64_t timestamp_u64;
  uint64_t length_u64;

  const uintmax_t initial_fpos = sd_reader->fpos;
  const int first_char = read_char(sd_reader);
  if (first_char == EOF && sd_reader->eof) {
    return OK;
  }

  if (msgpack_read_uint64(sd_reader, first_char, &type_u64) != OK
      || (msgpack_read_uint64(sd_reader, read_char(sd_reader), &timestamp_u64)
          != OK)
      || (msgpack_read_uint64(sd_reader, read_char(sd_reader), &length_u64)
          != OK)) {
    return FAIL;
  }

  const size_t length = (size_t) length_u64;
  entry->timestamp = (Timestamp) timestamp_u64;

  if ((type_u64 > SHADA_LAST_ENTRY
       ? !(flags & kSDReadUnknown)
       : !((unsigned) (1 << type_u64) & flags))) {
    if (fread_len(sd_reader, NULL, length) != OK) {
      return FAIL;
    }
    goto shada_read_next_item_start;
  }

  if (type_u64 > SHADA_LAST_ENTRY) {
    entry->type = kSDItemUnknown;
    entry->data.unknown_item.size = length;
    entry->data.unknown_item.type = type_u64;
    entry->data.unknown_item.contents = xmalloc(length);
    return fread_len(sd_reader, entry->data.unknown_item.contents, length);
  }

  msgpack_unpacker *const unpacker = msgpack_unpacker_new(length);
  if (unpacker == NULL ||
      !msgpack_unpacker_reserve_buffer(unpacker, length)) {
    EMSG(e_outofmem);
    goto shada_read_next_item_error;
  }

  if (fread_len(sd_reader, msgpack_unpacker_buffer(unpacker), length) != OK) {
    msgpack_unpacker_free(unpacker);
    return FAIL;
  }
  msgpack_unpacker_buffer_consumed(unpacker, length);

  msgpack_unpacked unpacked;
  msgpack_unpacked_init(&unpacked);

  const msgpack_unpack_return result =
      msgpack_unpacker_next(unpacker, &unpacked);
  if (result != MSGPACK_UNPACK_SUCCESS) {
    if (result == MSGPACK_UNPACK_NOMEM_ERROR) {
      EMSG(e_outofmem);
      goto shada_read_next_item_error;
    }
    if (result == MSGPACK_UNPACK_PARSE_ERROR) {
      EMSG("Failed to parse ShaDa file");
      goto shada_read_next_item_error;
    }
  }
#define CHECK_KEY(key, expected) \
  (key.via.str.size == sizeof(expected) - 1 \
   && STRNCMP(key.via.str.ptr, expected, sizeof(expected) - 1) == 0)
#define ID(s) s
#define BINDUP(b) xmemdupz(b.ptr, b.size)
#define TOINT(s) ((int) (s))
#define TOLONG(s) ((long) (s))
#define TOCHAR(s) ((char) (s))
#define TOU8(s) ((uint8_t) (s))
#define TOSIZE(s) ((size_t) (s))
#define CHECKED_ENTRY(condition, error_desc, entry_name, obj, tgt, attr, \
                      proc) \
  do { \
    if (!(condition)) { \
      emsgu("Error while reading ShaDa file: " \
            entry_name " entry at position %" PRIu64 " " \
            error_desc, \
            (uint64_t) initial_fpos); \
      ga_clear(&ad_ga); \
      goto shada_read_next_item_error; \
    } \
    tgt = proc(obj.via.attr); \
  } while (0)
#define CHECK_KEY_IS_STR(entry_name) \
  do { \
    if (unpacked.data.via.map.ptr[i].key.type != MSGPACK_OBJECT_STR) { \
      emsgu("Error while reading ShaDa file: " \
            entry_name " entry at position %" PRIu64 " " \
            "has key which is not a string", \
            (uint64_t) initial_fpos); \
      emsgu("It is %" PRIu64 " instead", \
            (uint64_t) unpacked.data.via.map.ptr[i].key.type); \
      ga_clear(&ad_ga); \
      goto shada_read_next_item_error; \
    } \
  } while (0)
#define CHECKED_KEY(entry_name, name, error_desc, tgt, condition, attr, proc) \
  if (CHECK_KEY(unpacked.data.via.map.ptr[i].key, name)) { \
    CHECKED_ENTRY( \
        condition, "has " name " key value " error_desc, \
        entry_name, unpacked.data.via.map.ptr[i].val, \
        tgt, attr, proc); \
  }
#define TYPED_KEY(entry_name, name, type_name, tgt, objtype, attr, proc) \
  CHECKED_KEY( \
      entry_name, name, " which is not " type_name, tgt, \
      unpacked.data.via.map.ptr[i].val.type == MSGPACK_OBJECT_##objtype, \
      attr, proc)
#define BOOLEAN_KEY(entry_name, name, tgt) \
  TYPED_KEY(entry_name, name, "a boolean", tgt, BOOLEAN, boolean, ID)
#define STRING_KEY(entry_name, name, tgt) \
  TYPED_KEY(entry_name, name, "a binary", tgt, BIN, bin, BINDUP)
#define CONVERTED_STRING_KEY(entry_name, name, tgt) \
  TYPED_KEY(entry_name, name, "a binary", tgt, BIN, bin, BIN_CONVERTED)
#define INT_KEY(entry_name, name, tgt, proc) \
  CHECKED_KEY( \
      entry_name, name, " which is not an integer", tgt, \
      (unpacked.data.via.map.ptr[i].val.type \
              == MSGPACK_OBJECT_POSITIVE_INTEGER \
       || unpacked.data.via.map.ptr[i].val.type \
              == MSGPACK_OBJECT_NEGATIVE_INTEGER), \
      i64, proc)
#define INTEGER_KEY(entry_name, name, tgt) \
  INT_KEY(entry_name, name, tgt, TOINT)
#define LONG_KEY(entry_name, name, tgt) \
  INT_KEY(entry_name, name, tgt, TOLONG)
#define ADDITIONAL_KEY \
  { \
    ga_grow(&ad_ga, 1); \
    memcpy(((char *)ad_ga.ga_data) + ((size_t) ad_ga.ga_len \
                                      * sizeof(*unpacked.data.via.map.ptr)),\
           unpacked.data.via.map.ptr + i, \
           sizeof(*unpacked.data.via.map.ptr)); \
    ad_ga.ga_len++; \
  }
#define CONVERTED(str, len) \
  (sd_reader->sd_conv.vc_type != CONV_NONE \
   ? get_converted_string(&sd_reader->sd_conv, (str), (len)) \
   : xmemdupz((str), (len)))
#define BIN_CONVERTED(b) CONVERTED(b.ptr, b.size)
  switch ((ShadaEntryType) type_u64) {
    case kSDItemHeader: {
      if (!msgpack_rpc_to_dictionary(&(unpacked.data), &(entry->data.header))) {
        emsgu("Error while reading ShaDa file: "
              "header entry at position %" PRIu64 " is not a dictionary",
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      break;
    }
    case kSDItemSearchPattern: {
      if (unpacked.data.type != MSGPACK_OBJECT_MAP) {
        emsgu("Error while reading ShaDa file: "
              "search pattern entry at position %" PRIu64 " "
              "is not a dictionary",
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      entry->data.search_pattern = (struct search_pattern) {
        .magic = true,
        .smartcase = false,
        .has_line_offset = false,
        .place_cursor_at_end = false,
        .offset = 0,
        .is_last_used = true,
        .is_substitute_pattern = false,
        .pat = NULL,
        .additional_data = NULL,
      };
      garray_T ad_ga;
      ga_init(&ad_ga, sizeof(*(unpacked.data.via.map.ptr)), 1);
      for (size_t i = 0; i < unpacked.data.via.map.size; i++) {
        CHECK_KEY_IS_STR("search pattern");
        BOOLEAN_KEY("search pattern", "magic", entry->data.search_pattern.magic)
        else BOOLEAN_KEY("search pattern", "smartcase",
                         entry->data.search_pattern.smartcase)
        else BOOLEAN_KEY("search pattern", "lineoff",
                         entry->data.search_pattern.has_line_offset)
        else BOOLEAN_KEY("search pattern", "curatend",
                         entry->data.search_pattern.place_cursor_at_end)
        else BOOLEAN_KEY("search pattern", "islast",
                         entry->data.search_pattern.is_last_used)
        else BOOLEAN_KEY("search pattern", "sub",
                         entry->data.search_pattern.is_substitute_pattern)
        else INTEGER_KEY("search pattern", "off",
                         entry->data.search_pattern.offset)
        else CONVERTED_STRING_KEY("search pattern", "pat",
                                  entry->data.search_pattern.pat)
        else ADDITIONAL_KEY
      }
      if (entry->data.search_pattern.pat == NULL) {
        emsgu("Error while reading ShaDa file: "
              "search pattern entry at position %" PRIu64 " "
              "has no pattern",
              (uint64_t) initial_fpos);
        ga_clear(&ad_ga);
        goto shada_read_next_item_error;
      }
      if (ad_ga.ga_len) {
        msgpack_object obj = {
          .type = MSGPACK_OBJECT_MAP,
          .via = {
            .map = {
              .size = (uint32_t) ad_ga.ga_len,
              .ptr = ad_ga.ga_data,
            }
          }
        };
        entry->data.search_pattern.additional_data =
            xmalloc(sizeof(Dictionary));
        if (!msgpack_rpc_to_dictionary(
                &obj, entry->data.search_pattern.additional_data)) {
          emsgu("Error while reading ShaDa file: "
                "search pattern entry at position %" PRIu64 " "
                "cannot be converted to a Dictionary",
                (uint64_t) initial_fpos);
          ga_clear(&ad_ga);
          goto shada_read_next_item_error;
        }
      }
      ga_clear(&ad_ga);
      break;
    }
    case kSDItemChange:
    case kSDItemJump:
    case kSDItemGlobalMark:
    case kSDItemLocalMark: {
      if (unpacked.data.type != MSGPACK_OBJECT_MAP) {
        emsgu("Error while reading ShaDa file: "
              "mark entry at position %" PRIu64 " "
              "is not a dictionary",
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      entry->data.filemark = (struct shada_filemark) {
        .name = '"',
        .mark = (pos_T) {1, 0, 0},
        .fname = NULL,
        .additional_data = NULL,
      };
      garray_T ad_ga;
      ga_init(&ad_ga, sizeof(*(unpacked.data.via.map.ptr)), 1);
      for (size_t i = 0; i < unpacked.data.via.map.size; i++) {
        CHECK_KEY_IS_STR("mark");
        CHECKED_KEY(
            "mark", "name", " which is not an unsigned integer",
            entry->data.filemark.name,
            (type_u64 != kSDItemJump
             && type_u64 != kSDItemChange
             && unpacked.data.via.map.ptr[i].val.type
                == MSGPACK_OBJECT_POSITIVE_INTEGER),
            u64, TOCHAR)
        else LONG_KEY("mark", "line", entry->data.filemark.mark.lnum)
        else INTEGER_KEY("mark", "col", entry->data.filemark.mark.col)
        else STRING_KEY("mark", "file", entry->data.filemark.fname)
        else ADDITIONAL_KEY
      }
      if (entry->data.filemark.mark.lnum == 0) {
        emsgu("Error while reading ShaDa file: "
              "mark entry at position %" PRIu64 " "
              "is missing line number",
              (uint64_t) initial_fpos);
        ga_clear(&ad_ga);
        goto shada_read_next_item_error;
      }
      if (ad_ga.ga_len) {
        msgpack_object obj = {
          .type = MSGPACK_OBJECT_MAP,
          .via = {
            .map = {
              .size = (uint32_t) ad_ga.ga_len,
              .ptr = ad_ga.ga_data,
            }
          }
        };
        entry->data.filemark.additional_data = xmalloc(sizeof(Dictionary));
        if (!msgpack_rpc_to_dictionary(
                &obj, entry->data.filemark.additional_data)) {
          emsgu("Error while reading ShaDa file: "
                "mark entry at position %" PRIu64 " "
                "cannot be converted to a Dictionary",
                (uint64_t) initial_fpos);
          ga_clear(&ad_ga);
          goto shada_read_next_item_error;
        }
      }
      ga_clear(&ad_ga);
      break;
    }
    case kSDItemRegister: {
      if (unpacked.data.type != MSGPACK_OBJECT_MAP) {
        emsgu("Error while reading ShaDa file: "
              "register entry at position %" PRIu64 " "
              "is not a dictionary",
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      entry->data.reg = (struct reg) {
        .name = NUL,
        .type = MCHAR,
        .contents = NULL,
        .contents_size = 0,
        .width = 0,
        .additional_data = NULL,
      };
      garray_T ad_ga;
      ga_init(&ad_ga, sizeof(*(unpacked.data.via.map.ptr)), 1);
      for (size_t i = 0; i < unpacked.data.via.map.size; i++) {
        CHECK_KEY_IS_STR("register");
        TYPED_KEY("register", "type", "an unsigned integer",
                  entry->data.reg.type, POSITIVE_INTEGER, u64, TOU8)
        else TYPED_KEY("register", "name", "an unsigned integer",
                       entry->data.reg.name, POSITIVE_INTEGER, u64, TOCHAR)
        else TYPED_KEY("register", "width", "an unsigned integer",
                       entry->data.reg.width, POSITIVE_INTEGER, u64, TOSIZE)
        else if (CHECK_KEY(unpacked.data.via.map.ptr[i].key, "contents")) {
          if (unpacked.data.via.map.ptr[i].val.type != MSGPACK_OBJECT_ARRAY) {
            emsgu("Error while reading ShaDa file: "
                  "register entry at position %" PRIu64 " "
                  "has contents key with non-array value",
                  (uint64_t) initial_fpos);
            ga_clear(&ad_ga);
            goto shada_read_next_item_error;
          }
          if (unpacked.data.via.map.ptr[i].val.via.array.size == 0) {
            emsgu("Error while reading ShaDa file: "
                  "register entry at position %" PRIu64 " "
                  "has contents key with empty array",
                  (uint64_t) initial_fpos);
            ga_clear(&ad_ga);
            goto shada_read_next_item_error;
          }
          const msgpack_object_array arr =
              unpacked.data.via.map.ptr[i].val.via.array;
          for (size_t i = 0; i < arr.size; i++) {
            if (arr.ptr[i].type != MSGPACK_OBJECT_BIN) {
              emsgu("Error while reading ShaDa file: "
                    "register entry at position %" PRIu64 " "
                    "has contents array with non-string value",
                    (uint64_t) initial_fpos);
              ga_clear(&ad_ga);
              goto shada_read_next_item_error;
            }
          }
          entry->data.reg.contents_size = arr.size;
          entry->data.reg.contents = xmalloc(arr.size * sizeof(char *));
          for (size_t i = 0; i < arr.size; i++) {
            entry->data.reg.contents[i] = BIN_CONVERTED(arr.ptr[i].via.bin);
          }
        } else ADDITIONAL_KEY
      }
      if (entry->data.reg.contents == NULL) {
        emsgu("Error while reading ShaDa file: "
              "register entry at position %" PRIu64 " "
              "has missing contents array",
              (uint64_t) initial_fpos);
        ga_clear(&ad_ga);
        goto shada_read_next_item_error;
      }
      if (ad_ga.ga_len) {
        msgpack_object obj = {
          .type = MSGPACK_OBJECT_MAP,
          .via = {
            .map = {
              .size = (uint32_t) ad_ga.ga_len,
              .ptr = ad_ga.ga_data,
            }
          }
        };
        entry->data.reg.additional_data = xmalloc(sizeof(Dictionary));
        if (!msgpack_rpc_to_dictionary(
                &obj, entry->data.reg.additional_data)) {
          emsgu("Error while reading ShaDa file: "
                "register entry at position %" PRIu64 " "
                "cannot be converted to a Dictionary",
                (uint64_t) initial_fpos);
          ga_clear(&ad_ga);
          goto shada_read_next_item_error;
        }
      }
      ga_clear(&ad_ga);
      break;
    }
    case kSDItemHistoryEntry: {
      if (unpacked.data.type != MSGPACK_OBJECT_ARRAY) {
        emsgu("Error while reading ShaDa file: "
              "history entry at position %" PRIu64 " "
              "is not an array",
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      entry->data.history_item = (struct history_item) {
        .histtype = 0,
        .string = NULL,
        .sep = 0,
        .additional_elements = NULL,
      };
      if (unpacked.data.via.array.size < 2) {
        emsgu("Error while reading ShaDa file: "
              "history entry at position %" PRIu64 " "
              "does not have enough elements",
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      if (unpacked.data.via.array.ptr[0].type
          != MSGPACK_OBJECT_POSITIVE_INTEGER) {
        emsgu("Error while reading ShaDa file: "
              "history entry at position %" PRIu64 " "
              "has wrong history type type",
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      if (unpacked.data.via.array.ptr[1].type
          != MSGPACK_OBJECT_BIN) {
        emsgu("Error while reading ShaDa file: "
              "history entry at position %" PRIu64 " "
              "has wrong history string type",
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      if (memchr(unpacked.data.via.array.ptr[1].via.bin.ptr, 0,
                 unpacked.data.via.array.ptr[1].via.bin.size) != NULL) {
        emsgu("Error while reading ShaDa file: "
              "history entry at position %" PRIu64 " "
              "contains string with zero byte inside",
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      entry->data.history_item.histtype =
          (uint8_t) unpacked.data.via.array.ptr[0].via.u64;
      const bool is_hist_search =
          entry->data.history_item.histtype == HIST_SEARCH;
      if (is_hist_search) {
        if (unpacked.data.via.array.size < 3) {
          emsgu("Error while reading ShaDa file: "
                "search history entry at position %" PRIu64 " "
                "does not have separator character",
                (uint64_t) initial_fpos);
          goto shada_read_next_item_error;
        }
        if (unpacked.data.via.array.ptr[2].type
            != MSGPACK_OBJECT_POSITIVE_INTEGER) {
          emsgu("Error while reading ShaDa file: "
                "search history entry at position %" PRIu64 " "
                "has wrong history separator type",
                (uint64_t) initial_fpos);
          goto shada_read_next_item_error;
        }
        entry->data.history_item.sep =
            (char) unpacked.data.via.array.ptr[2].via.u64;
      }
      size_t strsize;
      if (sd_reader->sd_conv.vc_type == CONV_NONE
          || !has_non_ascii_len(unpacked.data.via.array.ptr[1].via.bin.ptr,
                                unpacked.data.via.array.ptr[1].via.bin.size)) {
shada_read_next_item_hist_no_conv:
        strsize = (
            unpacked.data.via.array.ptr[1].via.bin.size
            + 1 // Zero byte
            + 1 // Separator character
        );
        entry->data.history_item.string = xmalloc(strsize);
        memcpy(entry->data.history_item.string,
              unpacked.data.via.array.ptr[1].via.bin.ptr,
              unpacked.data.via.array.ptr[1].via.bin.size);
      } else {
        size_t len = unpacked.data.via.array.ptr[1].via.bin.size;
        char *const converted = string_convert(
            &sd_reader->sd_conv, unpacked.data.via.array.ptr[1].via.bin.ptr,
            &len);
        if (converted != NULL) {
          strsize = len + 2;
          entry->data.history_item.string = xrealloc(converted, strsize);
        } else {
          goto shada_read_next_item_hist_no_conv;
        }
      }
      entry->data.history_item.string[strsize - 2] = 0;
      entry->data.history_item.string[strsize - 1] =
          entry->data.history_item.sep;
      if (unpacked.data.via.array.size > (size_t) (2 + is_hist_search)) {
        msgpack_object obj = {
          .type = MSGPACK_OBJECT_ARRAY,
          .via = {
            .array = {
              .size = (unpacked.data.via.array.size
                       - (uint32_t) (2 + is_hist_search)),
              .ptr = unpacked.data.via.array.ptr + (2 + is_hist_search),
            }
          }
        };
        entry->data.history_item.additional_elements = xmalloc(sizeof(Array));
        if (!msgpack_rpc_to_array(
                &obj, entry->data.history_item.additional_elements)) {
          emsgu("Error while reading ShaDa file: "
                "history entry at position %" PRIu64 " "
                "cannot be converted to an Array",
                (uint64_t) initial_fpos);
          goto shada_read_next_item_error;
        }
      }
      break;
    }
    case kSDItemVariable: {
      if (unpacked.data.type != MSGPACK_OBJECT_ARRAY) {
        emsgu("Error while reading ShaDa file: "
              "variable entry at position %" PRIu64 " "
              "is not an array",
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      entry->data.global_var = (struct global_var) {
        .name = NULL,
        .value = {
          .type = kObjectTypeNil,
        },
        .additional_elements = NULL
      };
      if (unpacked.data.via.array.size < 2) {
        emsgu("Error while reading ShaDa file: "
              "variable entry at position %" PRIu64 " "
              "does not have enough elements",
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      if (unpacked.data.via.array.ptr[0].type != MSGPACK_OBJECT_BIN) {
        emsgu("Error while reading ShaDa file: "
              "variable entry at position %" PRIu64 " "
              "has wrong variable name type",
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      if (unpacked.data.via.array.ptr[1].type == MSGPACK_OBJECT_NIL
          || unpacked.data.via.array.ptr[1].type == MSGPACK_OBJECT_EXT) {
        emsgu("Error while reading ShaDa file: "
              "variable entry at position %" PRIu64 " "
              "has wrong variable value type",
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      entry->data.global_var.name =
          xmemdupz(unpacked.data.via.array.ptr[0].via.bin.ptr,
                   unpacked.data.via.array.ptr[0].via.bin.size);
      if (!msgpack_rpc_to_object(&(unpacked.data.via.array.ptr[1]),
                                 &(entry->data.global_var.value))) {
        emsgu("Error while reading ShaDa file: "
              "variable entry at position %" PRIu64 " "
              "has value that cannot be converted to the object",
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      if (sd_reader->sd_conv.vc_type != CONV_NONE) {
        convert_object(&sd_reader->sd_conv, &entry->data.global_var.value);
      }
      if (unpacked.data.via.array.size > 2) {
        msgpack_object obj = {
          .type = MSGPACK_OBJECT_ARRAY,
          .via = {
            .array = {
              .size = unpacked.data.via.array.size - 2,
              .ptr = unpacked.data.via.array.ptr + 2,
            }
          }
        };
        entry->data.global_var.additional_elements = xmalloc(sizeof(Array));
        if (!msgpack_rpc_to_array(
                &obj, entry->data.global_var.additional_elements)) {
          emsgu("Error while reading ShaDa file: "
                "variable entry at position %" PRIu64 " "
                "cannot be converted to an Array",
                (uint64_t) initial_fpos);
          goto shada_read_next_item_error;
        }
      }
      break;
    }
    case kSDItemSubString: {
      if (unpacked.data.type != MSGPACK_OBJECT_ARRAY) {
        emsgu("Error while reading ShaDa file: "
              "sub string entry at position %" PRIu64 " "
              "is not an array",
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      entry->data.sub_string = (struct sub_string) {
        .sub = NULL,
        .additional_elements = NULL
      };
      if (unpacked.data.via.array.size < 1) {
        emsgu("Error while reading ShaDa file: "
              "sub string entry at position %" PRIu64 " "
              "does not have enough elements",
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      if (unpacked.data.via.array.ptr[0].type != MSGPACK_OBJECT_BIN) {
        emsgu("Error while reading ShaDa file: "
              "sub string entry at position %" PRIu64 " "
              "has wrong sub string type",
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      entry->data.sub_string.sub =
          BIN_CONVERTED(unpacked.data.via.array.ptr[0].via.bin);
      if (unpacked.data.via.array.size > 1) {
        msgpack_object obj = {
          .type = MSGPACK_OBJECT_ARRAY,
          .via = {
            .array = {
              .size = unpacked.data.via.array.size - 1,
              .ptr = unpacked.data.via.array.ptr + 1,
            }
          }
        };
        entry->data.sub_string.additional_elements = xmalloc(sizeof(Array));
        if (!msgpack_rpc_to_array(
                &obj, entry->data.sub_string.additional_elements)) {
          emsgu("Error while reading ShaDa file: "
                "sub string entry at position %" PRIu64 " "
                "cannot be converted to an Array",
                (uint64_t) initial_fpos);
          goto shada_read_next_item_error;
        }
      }
      break;
    }
    case kSDItemBufferList: {
      if (unpacked.data.type != MSGPACK_OBJECT_ARRAY) {
        emsgu("Error while reading ShaDa file: "
              "buffer list entry at position %" PRIu64 " "
              "is not an array",
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      entry->data.buffer_list = (struct buffer_list) {
        .size = 0,
        .buffers = NULL,
      };
      if (unpacked.data.via.array.size == 0) {
        break;
      }
      entry->data.buffer_list.buffers =
          xcalloc(unpacked.data.via.array.size,
                  sizeof(*entry->data.buffer_list.buffers));
      for (size_t i = 0; i < unpacked.data.via.array.size; i++) {
        entry->data.buffer_list.size++;
        msgpack_unpacked unpacked_2 = (msgpack_unpacked) {
          .data = unpacked.data.via.array.ptr[i],
        };
        {
          msgpack_unpacked unpacked = unpacked_2;
          if (unpacked.data.type != MSGPACK_OBJECT_MAP) {
            emsgu("Error while reading ShaDa file: "
                  "buffer list at position %" PRIu64 " "
                  "contains entry that is not a dictionary",
                  (uint64_t) initial_fpos);
            goto shada_read_next_item_error;
          }
          entry->data.buffer_list.buffers[i].pos.lnum = 1;
          garray_T ad_ga;
          ga_init(&ad_ga, sizeof(*(unpacked.data.via.map.ptr)), 1);
          {
            const size_t j = i;
            {
              for (size_t i = 0; i < unpacked.data.via.map.size; i++) {
                CHECK_KEY_IS_STR("buffer list entry");
                LONG_KEY("buffer list entry", "line",
                        entry->data.buffer_list.buffers[j].pos.lnum)
                else INTEGER_KEY("buffer list entry", "col",
                                entry->data.buffer_list.buffers[j].pos.col)
                else STRING_KEY("buffer list entry", "file",
                                entry->data.buffer_list.buffers[j].fname)
                else ADDITIONAL_KEY
              }
            }
          }
          if (entry->data.buffer_list.buffers[i].fname == NULL) {
            emsgu("Error while reading ShaDa file: "
                  "buffer list at position %" PRIu64 " "
                  "contains entry that does not have a file name",
                  (uint64_t) initial_fpos);
            ga_clear(&ad_ga);
            goto shada_read_next_item_error;
          }
          if (ad_ga.ga_len) {
            msgpack_object obj = {
              .type = MSGPACK_OBJECT_MAP,
              .via = {
                .map = {
                  .size = (uint32_t) ad_ga.ga_len,
                  .ptr = ad_ga.ga_data,
                }
              }
            };
            entry->data.buffer_list.buffers[i].additional_data =
                xmalloc(sizeof(Dictionary));
            if (!msgpack_rpc_to_dictionary(
                    &obj, entry->data.buffer_list.buffers[i].additional_data)) {
              emsgu("Error while reading ShaDa file: "
                    "buffer list at position %" PRIu64 " "
                    "contains entry that cannot be converted to a Dictionary",
                    (uint64_t) initial_fpos);
              ga_clear(&ad_ga);
              goto shada_read_next_item_error;
            }
          }
          ga_clear(&ad_ga);
        }
      }
      break;
    }
    case kSDItemMissing: {
      emsgu("Error while reading ShaDa file: "
            "there is an item at position %" PRIu64 " "
            "that must not be there: Missing items are "
            "for internal uses only",
            (uint64_t) initial_fpos);
      goto shada_read_next_item_error;
    }
    case kSDItemUnknown: {
      assert(false);
    }
  }
  entry->type = (ShadaEntryType) type_u64;
  goto shada_read_next_item_end;
#undef BIN_CONVERTED
#undef CONVERTED
#undef CHECK_KEY
#undef BOOLEAN_KEY
#undef CONVERTED_STRING_KEY
#undef STRING_KEY
#undef ADDITIONAL_KEY
#undef ID
#undef BINDUP
#undef TOCHAR
#undef TOINT
#undef TOLONG
#undef TYPED_KEY
#undef INT_KEY
#undef INTEGER_KEY
#undef LONG_KEY
#undef TOU8
#undef TOSIZE
shada_read_next_item_error:
  msgpack_unpacked_destroy(&unpacked);
  msgpack_unpacker_free(unpacker);
  entry->type = (ShadaEntryType) type_u64;
  shada_free_shada_entry(entry);
  entry->type = kSDItemMissing;
  return FAIL;
shada_read_next_item_end:
  msgpack_unpacked_destroy(&unpacked);
  msgpack_unpacker_free(unpacker);
  return NOTDONE;
}

/// Return a list with all global marks set in current NeoVim instance
///
/// List is not sorted.
///
/// @warning Listed marks must be used before any buffer- or mark-editing 
///          function is run.
///
/// @param[in]  removable_bufs  Set of buffers on removable media.
///
/// @return Array of ShadaEntry values, last one has type kSDItemMissing.
///
///         @warning Resulting ShadaEntry values must not be freed. Returned 
///                  array must be freed with `xfree()`.
static ShadaEntry *list_global_marks(
    const khash_t(bufset) *const removable_bufs)
{
  const void *iter = NULL;
  const size_t nummarks = mark_global_amount();
  ShadaEntry *const ret = xmalloc(sizeof(ShadaEntry) * (nummarks + 1));
  ShadaEntry *cur = ret;
  if (nummarks) {
    do {
      cur->type = kSDItemGlobalMark;
      xfmark_T cur_fm;
      iter = mark_global_iter(iter, &(cur->data.filemark.name), &cur_fm);
      cur->data.filemark.mark = cur_fm.fmark.mark;
      cur->data.filemark.additional_data = cur_fm.fmark.additional_data;
      cur->timestamp = cur_fm.fmark.timestamp;
      if (cur_fm.fmark.fnum == 0) {
        if (cur_fm.fname == NULL) {
          continue;
        }
        cur->data.filemark.fname = (char *) cur_fm.fname;
      } else {
        const buf_T *const buf = buflist_findnr(cur_fm.fmark.fnum);
        if (buf == NULL || buf->b_ffname == NULL || SHADA_REMOVABLE(buf)) {
          continue;
        } else {
          cur->data.filemark.fname = (char *) buf->b_ffname;
        }
      }
      cur++;
    } while(iter != NULL);
  }
  cur->type = kSDItemMissing;
  return ret;
}

/// Return a list with all buffer marks set in some buffer
///
/// List is not sorted.
///
/// @warning Listed marks must be used before any buffer- or mark-editing 
///          function is run.
///
/// @param[in]  buf  Buffer for which marks are listed.
///
/// @return Array of ShadaEntry values, last one has type kSDItemMissing.
///
///         @warning Resulting ShadaEntry values must not be freed. Returned 
///                  array must be freed with `xfree()`.
static ShadaEntry *list_buffer_marks(const buf_T *const buf)
{
  const char *const fname = (char *) buf->b_ffname;
  const void *iter = NULL;
  const size_t nummarks = mark_buffer_amount(buf);
  ShadaEntry *const ret = xmalloc(sizeof(ShadaEntry) * (nummarks + 1));
  ShadaEntry *cur = ret;
  if (nummarks) {
    do {
      cur->type = kSDItemLocalMark;
      fmark_T cur_fm;
      iter = mark_buffer_iter(iter, buf, &(cur->data.filemark.name), &cur_fm);
      cur->data.filemark.mark = cur_fm.mark;
      cur->data.filemark.fname = (char *) fname;
      cur->data.filemark.additional_data = cur_fm.additional_data;
      cur->timestamp = cur_fm.timestamp;
      if (cur->data.filemark.mark.lnum != 0) {
        cur++;
      }
    } while(iter != NULL);
  }
  cur->type = kSDItemMissing;
  return ret;
}

/// Check whether "name" is on removable media (according to 'viminfo')
///
/// @param[in]  name  Checked name.
///
/// @return True if it is, false otherwise.
bool shada_removable(const char *name)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  char  *p;
  char part[51];
  int retval = FALSE;
  size_t n;

  char *new_name = home_replace_save(NULL, name);
  for (p = (char *) p_viminfo; *p; ) {
    (void) copy_option_part(&p, part, 51, ", ");
    if (part[0] == 'r') {
      n = STRLEN(part + 1);
      if (STRNICMP(part + 1, new_name, n) == 0) {
        retval = TRUE;
        break;
      }
    }
  }
  xfree(new_name);
  return retval;
}

/// Return a list with all registers and their contents
///
/// List is not sorted.
///
/// @warning Listed registers must be used before any register-editing function 
///          is run.
///
/// @param[in]  max_num_lines  Maximum number of lines in the register. If it is 
///                            zero then all registers are listed.
///
/// @return Array of ShadaEntry values, last one has type kSDItemMissing.
///
///         @warning Resulting ShadaEntry values must not be freed. Returned 
///                  array must be freed with `xfree()`.
static ShadaEntry *list_registers(const size_t max_num_lines)
{
  const void *iter = NULL;
  const size_t numregs = op_register_amount();
  ShadaEntry *const ret = xmalloc(sizeof(ShadaEntry) * (numregs + 1));
  ShadaEntry *cur = ret;
  if (numregs) {
    do {
      cur->type = kSDItemRegister;
      yankreg_T cur_reg;
      iter = op_register_iter(iter, &(cur->data.reg.name), &cur_reg);
      if (max_num_lines && (size_t) cur_reg.y_size > max_num_lines) {
        continue;
      }
      cur->data.reg.contents = (char **) cur_reg.y_array;
      cur->data.reg.type = (uint8_t) cur_reg.y_type;
      cur->data.reg.contents_size = (size_t) cur_reg.y_size;
      if (cur_reg.y_type == MBLOCK) {
        cur->data.reg.width = (size_t) cur_reg.y_width;
      } else {
        cur->data.reg.width = 0;
      }
      cur->data.reg.additional_data = cur_reg.additional_data;
      cur->timestamp = cur_reg.timestamp;
      cur++;
    } while(iter != NULL);
  }
  cur->type = kSDItemMissing;
  return ret;
}


#if 0

static int viminfo_errcnt;

static int no_viminfo(void)
{
  /* "vim -i NONE" does not read or write a viminfo file */
  return use_viminfo != NULL && STRCMP(use_viminfo, "NONE") == 0;
}

/*
 * Report an error for reading a viminfo file.
 * Count the number of errors.	When there are more than 10, return TRUE.
 */
int viminfo_error(char *errnum, char *message, char_u *line)
{
  vim_snprintf((char *)IObuff, IOSIZE, _("%sviminfo: %s in line: "),
      errnum, message);
  STRNCAT(IObuff, line, IOSIZE - STRLEN(IObuff) - 1);
  if (IObuff[STRLEN(IObuff) - 1] == '\n')
    IObuff[STRLEN(IObuff) - 1] = NUL;
  emsg(IObuff);
  if (++viminfo_errcnt >= 10) {
    EMSG(_("E136: viminfo: Too many errors, skipping rest of file"));
    return TRUE;
  }
  return FALSE;
}

/*
 * read_viminfo() -- Read the viminfo file.  Registers etc. which are already
 * set are not over-written unless "flags" includes VIF_FORCEIT. -- webb
 */
int 
read_viminfo (
    char_u *file,          /* file name or NULL to use default name */
    int flags                  /* VIF_WANT_INFO et al. */
)
{
  FILE        *fp;
  char_u      *fname;

  if (no_viminfo())
    return FAIL;

  fname = viminfo_filename(file);       /* get file name in allocated buffer */
  fp = mch_fopen((char *)fname, READBIN);

  if (p_verbose > 0) {
    verbose_enter();
    smsg(_("Reading viminfo file \"%s\"%s%s%s"),
        fname,
        (flags & VIF_WANT_INFO) ? _(" info") : "",
        (flags & VIF_WANT_MARKS) ? _(" marks") : "",
        (flags & VIF_GET_OLDFILES) ? _(" oldfiles") : "",
        fp == NULL ? _(" FAILED") : "");
    verbose_leave();
  }

  xfree(fname);
  if (fp == NULL)
    return FAIL;

  viminfo_errcnt = 0;
  do_viminfo(fp, NULL, flags);

  fclose(fp);
  return OK;
}

/*
 * Write the viminfo file.  The old one is read in first so that effectively a
 * merge of current info and old info is done.  This allows multiple vims to
 * run simultaneously, without losing any marks etc.
 * If "forceit" is TRUE, then the old file is not read in, and only internal
 * info is written to the file.
 */
void write_viminfo(char_u *file, int forceit)
{
  char_u      *fname;
  FILE        *fp_in = NULL;    /* input viminfo file, if any */
  FILE        *fp_out = NULL;   /* output viminfo file */
  char_u      *tempname = NULL;         /* name of temp viminfo file */
  char_u      *wp;
#if defined(UNIX)
  mode_t umask_save;
#endif

  if (no_viminfo())
    return;

  fname = viminfo_filename(file);       /* may set to default if NULL */

  fp_in = mch_fopen((char *)fname, READBIN);
  if (fp_in == NULL) {
    /* if it does exist, but we can't read it, don't try writing */
    if (os_file_exists(fname))
      goto end;
#if defined(UNIX)
    /*
     * For Unix we create the .viminfo non-accessible for others,
     * because it may contain text from non-accessible documents.
     */
    umask_save = umask(077);
#endif
    fp_out = mch_fopen((char *)fname, WRITEBIN);
#if defined(UNIX)
    (void)umask(umask_save);
#endif
  } else {
    /*
     * There is an existing viminfo file.  Create a temporary file to
     * write the new viminfo into, in the same directory as the
     * existing viminfo file, which will be renamed later.
     */
#ifdef UNIX
    /*
     * For Unix we check the owner of the file.  It's not very nice to
     * overwrite a user's viminfo file after a "su root", with a
     * viminfo file that the user can't read.
     */

    FileInfo old_info;  // FileInfo of existing viminfo file
    if (os_fileinfo((char *)fname, &old_info)
        && getuid() != ROOT_UID
        && !(old_info.stat.st_uid == getuid()
             ? (old_info.stat.st_mode & 0200)
             : (old_info.stat.st_gid == getgid()
                ? (old_info.stat.st_mode & 0020)
                : (old_info.stat.st_mode & 0002)))) {
      int tt = msg_didany;

      /* avoid a wait_return for this message, it's annoying */
      EMSG2(_("E137: Viminfo file is not writable: %s"), fname);
      msg_didany = tt;
      fclose(fp_in);
      goto end;
    }
#endif

    // Make tempname
    tempname = (char_u *)modname((char *)fname, ".tmp", FALSE);
    if (tempname != NULL) {
      /*
       * Check if tempfile already exists.  Never overwrite an
       * existing file!
       */
      if (os_file_exists(tempname)) {
        /*
         * Try another name.  Change one character, just before
         * the extension.
         */
        wp = tempname + STRLEN(tempname) - 5;
        if (wp < path_tail(tempname))                 /* empty file name? */
          wp = path_tail(tempname);
        for (*wp = 'z'; os_file_exists(tempname); --*wp) {
          /*
           * They all exist?  Must be something wrong! Don't
           * write the viminfo file then.
           */
          if (*wp == 'a') {
            xfree(tempname);
            tempname = NULL;
            break;
          }
        }
      }
    }

    if (tempname != NULL) {
      int fd;

      /* Use os_open() to be able to use O_NOFOLLOW and set file
       * protection:
       * Unix: same as original file, but strip s-bit.  Reset umask to
       * avoid it getting in the way.
       * Others: r&w for user only. */
# ifdef UNIX
      umask_save = umask(0);
      fd = os_open((char *)tempname,
          O_CREAT|O_EXCL|O_WRONLY|O_NOFOLLOW,
          (int)((old_info.stat.st_mode & 0777) | 0600));
      (void)umask(umask_save);
# else
      fd = os_open((char *)tempname,
          O_CREAT|O_EXCL|O_WRONLY|O_NOFOLLOW, 0600);
# endif
      if (fd < 0)
        fp_out = NULL;
      else
        fp_out = fdopen(fd, WRITEBIN);

      /*
       * If we can't create in the same directory, try creating a
       * "normal" temp file.
       */
      if (fp_out == NULL) {
        xfree(tempname);
        if ((tempname = vim_tempname()) != NULL)
          fp_out = mch_fopen((char *)tempname, WRITEBIN);
      }

#ifdef UNIX
      /*
       * Make sure the owner can read/write it.  This only works for
       * root.
       */
      if (fp_out != NULL) {
        os_fchown(fileno(fp_out), old_info.stat.st_uid, old_info.stat.st_gid);
      }
#endif
    }
  }

  /*
   * Check if the new viminfo file can be written to.
   */
  if (fp_out == NULL) {
    EMSG2(_("E138: Can't write viminfo file %s!"),
        (fp_in == NULL || tempname == NULL) ? fname : tempname);
    if (fp_in != NULL)
      fclose(fp_in);
    goto end;
  }

  if (p_verbose > 0) {
    verbose_enter();
    smsg(_("Writing viminfo file \"%s\""), fname);
    verbose_leave();
  }

  viminfo_errcnt = 0;
  do_viminfo(fp_in, fp_out, forceit ? 0 : (VIF_WANT_INFO | VIF_WANT_MARKS));

  fclose(fp_out);           /* errors are ignored !? */
  if (fp_in != NULL) {
    fclose(fp_in);

    /* In case of an error keep the original viminfo file. Otherwise
     * rename the newly written file. Give an error if that fails. */
    if (viminfo_errcnt == 0 && vim_rename(tempname, fname) == -1) {
      viminfo_errcnt++;
      EMSG2(_("E886: Can't rename viminfo file to %s!"), fname);
    }
    if (viminfo_errcnt > 0) {
      os_remove((char *)tempname);
    }
  }

end:
  xfree(fname);
  xfree(tempname);
}

/*
 * Get the viminfo file name to use.
 * If "file" is given and not empty, use it (has already been expanded by
 * cmdline functions).
 * Otherwise use "-i file_name", value from 'viminfo' or the default, and
 * expand environment variables.
 * Returns an allocated string.
 */
static char_u *viminfo_filename(char_u *file)
{
  if (file == NULL || *file == NUL) {
    if (use_viminfo != NULL)
      file = use_viminfo;
    else if ((file = find_viminfo_parameter('n')) == NULL || *file == NUL) {
#ifdef VIMINFO_FILE2
      // don't use $HOME when not defined (turned into "c:/"!).
      if (!os_env_exists("HOME")) {
        // don't use $VIM when not available.
        expand_env((char_u *)"$VIM", NameBuff, MAXPATHL);
        if (STRCMP("$VIM", NameBuff) != 0)          /* $VIM was expanded */
          file = (char_u *)VIMINFO_FILE2;
        else
          file = (char_u *)VIMINFO_FILE;
      } else
#endif
      file = (char_u *)VIMINFO_FILE;
    }
    expand_env(file, NameBuff, MAXPATHL);
    file = NameBuff;
  }
  return vim_strsave(file);
}

/*
 * do_viminfo() -- Should only be called from read_viminfo() & write_viminfo().
 */
static void do_viminfo(FILE *fp_in, FILE *fp_out, int flags)
{
  int count = 0;
  int eof = FALSE;
  vir_T vir;
  int merge = FALSE;

  vir.vir_line = xmalloc(LSIZE);
  vir.vir_fd = fp_in;
  vir.vir_conv.vc_type = CONV_NONE;

  if (fp_in != NULL) {
    if (flags & VIF_WANT_INFO) {
      eof = read_viminfo_up_to_marks(&vir,
          flags & VIF_FORCEIT, fp_out != NULL);
      merge = TRUE;
    } else if (flags != 0)
      /* Skip info, find start of marks */
      while (!(eof = viminfo_readline(&vir))
             && vir.vir_line[0] != '>')
        ;
  }
  if (fp_out != NULL) {
    /* Write the info: */
    fprintf(fp_out, _("# This viminfo file was generated by Nvim %s.\n"),
        mediumVersion);
    fputs(_("# You may edit it if you're careful!\n\n"), fp_out);
    fputs(_("# Value of 'encoding' when this file was written\n"), fp_out);
    fprintf(fp_out, "*encoding=%s\n\n", p_enc);
    write_viminfo_search_pattern(fp_out);
    write_viminfo_sub_string(fp_out);
    write_viminfo_history(fp_out, merge);
    write_viminfo_registers(fp_out);
    write_viminfo_varlist(fp_out);
    write_viminfo_filemarks(fp_out);
    write_viminfo_bufferlist(fp_out);
    count = write_viminfo_marks(fp_out);
  }
  if (fp_in != NULL
      && (flags & (VIF_WANT_MARKS | VIF_GET_OLDFILES | VIF_FORCEIT)))
    copy_viminfo_marks(&vir, fp_out, count, eof, flags);

  xfree(vir.vir_line);
  if (vir.vir_conv.vc_type != CONV_NONE)
    convert_setup(&vir.vir_conv, NULL, NULL);
}

/*
 * read_viminfo_up_to_marks() -- Only called from do_viminfo().  Reads in the
 * first part of the viminfo file which contains everything but the marks that
 * are local to a file.  Returns TRUE when end-of-file is reached. -- webb
 */
static int read_viminfo_up_to_marks(vir_T *virp, int forceit, int writing)
{
  int eof;

  prepare_viminfo_history(forceit ? 9999 : 0, writing);
  eof = viminfo_readline(virp);
  while (!eof && virp->vir_line[0] != '>') {
    switch (virp->vir_line[0]) {
    /* Characters reserved for future expansion, ignored now */
    case '+':         /* "+40 /path/dir file", for running vim without args */
    case '|':         /* to be defined */
    case '^':         /* to be defined */
    case '<':         /* long line - ignored */
    /* A comment or empty line. */
    case NUL:
    case '\r':
    case '\n':
    case '#':
      eof = viminfo_readline(virp);
      break;
    case '*':         /* "*encoding=value" */
      eof = viminfo_encoding(virp);
      break;
    case '!':         /* global variable */
      eof = read_viminfo_varlist(virp, writing);
      break;
    case '%':         /* entry for buffer list */
      eof = read_viminfo_bufferlist(virp, writing);
      break;
    case '"':
      eof = read_viminfo_register(virp, forceit);
      break;
    case '/':               /* Search string */
    case '&':               /* Substitute search string */
    case '~':               /* Last search string, followed by '/' or '&' */
      eof = read_viminfo_search_pattern(virp, forceit);
      break;
    case '$':
      eof = read_viminfo_sub_string(virp, forceit);
      break;
    case ':':
    case '?':
    case '=':
    case '@':
      eof = read_viminfo_history(virp, writing);
      break;
    case '-':
    case '\'':
      eof = read_viminfo_filemark(virp, forceit);
      break;
    default:
      if (viminfo_error("E575: ", _("Illegal starting char"),
              virp->vir_line))
        eof = TRUE;
      else
        eof = viminfo_readline(virp);
      break;
    }
  }

  /* Finish reading history items. */
  if (!writing)
    finish_viminfo_history();

  /* Change file names to buffer numbers for fmarks. */
  FOR_ALL_BUFFERS(buf) {
    fmarks_check_names(buf);
  }

  return eof;
}

/*
 * Compare the 'encoding' value in the viminfo file with the current value of
 * 'encoding'.  If different and the 'c' flag is in 'viminfo', setup for
 * conversion of text with iconv() in viminfo_readstring().
 */
static int viminfo_encoding(vir_T *virp)
{
  char_u      *p;
  int i;

  if (get_viminfo_parameter('c') != 0) {
    p = vim_strchr(virp->vir_line, '=');
    if (p != NULL) {
      /* remove trailing newline */
      ++p;
      for (i = 0; vim_isprintc(p[i]); ++i)
        ;
      p[i] = NUL;

      convert_setup(&virp->vir_conv, p, p_enc);
    }
  }
  return viminfo_readline(virp);
}

/*
 * Read a line from the viminfo file.
 * Returns TRUE for end-of-file;
 */
int viminfo_readline(vir_T *virp)
{
  return vim_fgets(virp->vir_line, LSIZE, virp->vir_fd);
}

/*
 * check string read from viminfo file
 * remove '\n' at the end of the line
 * - replace CTRL-V CTRL-V with CTRL-V
 * - replace CTRL-V 'n'    with '\n'
 *
 * Check for a long line as written by viminfo_writestring().
 *
 * Return the string in allocated memory.
 */
char_u *
viminfo_readstring (
    vir_T *virp,
    int off,                            /* offset for virp->vir_line */
    int convert                 /* convert the string */
)
  FUNC_ATTR_NONNULL_RET
{
  char_u      *retval;
  char_u      *s, *d;

  if (virp->vir_line[off] == Ctrl_V && ascii_isdigit(virp->vir_line[off + 1])) {
    ssize_t len = atol((char *)virp->vir_line + off + 1);
    retval = xmalloc(len);
    // TODO(philix): change type of vim_fgets() size argument to size_t
    (void)vim_fgets(retval, (int)len, virp->vir_fd);
    s = retval + 1;         /* Skip the leading '<' */
  } else {
    retval = vim_strsave(virp->vir_line + off);
    s = retval;
  }

  /* Change CTRL-V CTRL-V to CTRL-V and CTRL-V n to \n in-place. */
  d = retval;
  while (*s != NUL && *s != '\n') {
    if (s[0] == Ctrl_V && s[1] != NUL) {
      if (s[1] == 'n')
        *d++ = '\n';
      else
        *d++ = Ctrl_V;
      s += 2;
    } else
      *d++ = *s++;
  }
  *d = NUL;

  if (convert && virp->vir_conv.vc_type != CONV_NONE && *retval != NUL) {
    d = string_convert(&virp->vir_conv, retval, NULL);
    if (d != NULL) {
      xfree(retval);
      retval = d;
    }
  }

  return retval;
}

/*
 * write string to viminfo file
 * - replace CTRL-V with CTRL-V CTRL-V
 * - replace '\n'   with CTRL-V 'n'
 * - add a '\n' at the end
 *
 * For a long line:
 * - write " CTRL-V <length> \n " in first line
 * - write " < <string> \n "	  in second line
 */
void viminfo_writestring(FILE *fd, char_u *p)
{
  int c;
  char_u      *s;
  int len = 0;

  for (s = p; *s != NUL; ++s) {
    if (*s == Ctrl_V || *s == '\n')
      ++len;
    ++len;
  }

  /* If the string will be too long, write its length and put it in the next
   * line.  Take into account that some room is needed for what comes before
   * the string (e.g., variable name).  Add something to the length for the
   * '<', NL and trailing NUL. */
  if (len > LSIZE / 2)
    fprintf(fd, "\026%d\n<", len + 3);

  while ((c = *p++) != NUL) {
    if (c == Ctrl_V || c == '\n') {
      putc(Ctrl_V, fd);
      if (c == '\n')
        c = 'n';
    }
    putc(c, fd);
  }
  putc('\n', fd);
}

/*
 * Write all the named marks for all buffers.
 * Return the number of buffers for which marks have been written.
 */
int write_viminfo_marks(FILE *fp_out)
{
  /*
   * Set b_last_cursor for the all buffers that have a window.
   */
  FOR_ALL_TAB_WINDOWS(tp, win) {
    set_last_cursor(win);
  }

  fputs(_("\n# History of marks within files (newest to oldest):\n"), fp_out);
  int count = 0;
  FOR_ALL_BUFFERS(buf) {
    /*
     * Only write something if buffer has been loaded and at least one
     * mark is set.
     */
    if (buf->b_marks_read) {
      bool is_mark_set = true;
      if (buf->b_last_cursor.lnum == 0) {
        is_mark_set = false;
        for (int i = 0; i < NMARKS; i++) {
          if (buf->b_namedm[i].lnum != 0) {
            is_mark_set = true;
            break;
          }
        }
      }
      if (is_mark_set && buf->b_ffname != NULL
          && buf->b_ffname[0] != NUL && !removable(buf->b_ffname)) {
        home_replace(NULL, buf->b_ffname, IObuff, IOSIZE, TRUE);
        fprintf(fp_out, "\n> ");
        viminfo_writestring(fp_out, IObuff);
        write_one_mark(fp_out, '"', &buf->b_last_cursor);
        write_one_mark(fp_out, '^', &buf->b_last_insert);
        write_one_mark(fp_out, '.', &buf->b_last_change);
        /* changelist positions are stored oldest first */
        for (int i = 0; i < buf->b_changelistlen; ++i) {
          write_one_mark(fp_out, '+', &buf->b_changelist[i]);
        }
        for (int i = 0; i < NMARKS; i++) {
          write_one_mark(fp_out, 'a' + i, &buf->b_namedm[i]);
        }
        count++;
      }
    }
  }

  return count;
}

static void write_one_mark(FILE *fp_out, int c, pos_T *pos)
{
  if (pos->lnum != 0)
    fprintf(fp_out, "\t%c\t%" PRId64 "\t%d\n", c,
            (int64_t)pos->lnum, (int)pos->col);
}

/*
 * Handle marks in the viminfo file:
 * fp_out != NULL: copy marks for buffers not in buffer list
 * fp_out == NULL && (flags & VIF_WANT_MARKS): read marks for curbuf only
 * fp_out == NULL && (flags & VIF_GET_OLDFILES | VIF_FORCEIT): fill v:oldfiles
 */
void copy_viminfo_marks(vir_T *virp, FILE *fp_out, int count, int eof, int flags)
{
  char_u      *line = virp->vir_line;
  buf_T       *buf;
  int num_marked_files;
  int load_marks;
  int copy_marks_out;
  char_u      *str;
  int i;
  char_u      *p;
  char_u      *name_buf;
  pos_T pos;
  list_T      *list = NULL;

  name_buf = xmalloc(LSIZE);
  *name_buf = NUL;

  if (fp_out == NULL && (flags & (VIF_GET_OLDFILES | VIF_FORCEIT))) {
    list = list_alloc();
    set_vim_var_list(VV_OLDFILES, list);
  }

  num_marked_files = get_viminfo_parameter('\'');
  while (!eof && (count < num_marked_files || fp_out == NULL)) {
    if (line[0] != '>') {
      if (line[0] != '\n' && line[0] != '\r' && line[0] != '#') {
        if (viminfo_error("E576: ", _("Missing '>'"), line))
          break;                /* too many errors, return now */
      }
      eof = vim_fgets(line, LSIZE, virp->vir_fd);
      continue;                 /* Skip this dud line */
    }

    /*
     * Handle long line and translate escaped characters.
     * Find file name, set str to start.
     * Ignore leading and trailing white space.
     */
    str = skipwhite(line + 1);
    str = viminfo_readstring(virp, (int)(str - virp->vir_line), FALSE);
    p = str + STRLEN(str);
    while (p != str && (*p == NUL || ascii_isspace(*p)))
      p--;
    if (*p)
      p++;
    *p = NUL;

    if (list != NULL)
      list_append_string(list, str, -1);

    /*
     * If fp_out == NULL, load marks for current buffer.
     * If fp_out != NULL, copy marks for buffers not in buflist.
     */
    load_marks = copy_marks_out = FALSE;
    if (fp_out == NULL) {
      if ((flags & VIF_WANT_MARKS) && curbuf->b_ffname != NULL) {
        if (*name_buf == NUL)               /* only need to do this once */
          home_replace(NULL, curbuf->b_ffname, name_buf, LSIZE, TRUE);
        if (fnamecmp(str, name_buf) == 0)
          load_marks = TRUE;
      }
    } else { /* fp_out != NULL */
             /* This is slow if there are many buffers!! */
      buf = NULL;
      FOR_ALL_BUFFERS(bp) {
        if (bp->b_ffname != NULL) {
          home_replace(NULL, bp->b_ffname, name_buf, LSIZE, TRUE);
          if (fnamecmp(str, name_buf) == 0) {
            buf = bp;
            break;
          }
        }
      }

      /*
       * copy marks if the buffer has not been loaded
       */
      if (buf == NULL || !buf->b_marks_read) {
        copy_marks_out = TRUE;
        fputs("\n> ", fp_out);
        viminfo_writestring(fp_out, str);
        count++;
      }
    }
    free(str);

    pos.coladd = 0;
    while (!(eof = viminfo_readline(virp)) && line[0] == TAB) {
      if (load_marks) {
        if (line[1] != NUL) {
          int64_t lnum_64;
          unsigned int u;
          sscanf((char *)line + 2, "%" SCNd64 "%u", &lnum_64, &u);
          // safely downcast to linenr_T (long); remove when linenr_T refactored
          assert(lnum_64 <= LONG_MAX); 
          pos.lnum = (linenr_T)lnum_64;
          assert(u <= INT_MAX);
          pos.col = (colnr_T)u;
          switch (line[1]) {
          case '"': curbuf->b_last_cursor = pos; break;
          case '^': curbuf->b_last_insert = pos; break;
          case '.': curbuf->b_last_change = pos; break;
          case '+':
            /* changelist positions are stored oldest
             * first */
            if (curbuf->b_changelistlen == JUMPLISTSIZE)
              /* list is full, remove oldest entry */
              memmove(curbuf->b_changelist,
                  curbuf->b_changelist + 1,
                  sizeof(pos_T) * (JUMPLISTSIZE - 1));
            else
              ++curbuf->b_changelistlen;
            curbuf->b_changelist[
              curbuf->b_changelistlen - 1] = pos;
            break;
          default:  if ((i = line[1] - 'a') >= 0 && i < NMARKS)
              curbuf->b_namedm[i] = pos;
          }
        }
      } else if (copy_marks_out)
        fputs((char *)line, fp_out);
    }
    if (load_marks) {
      FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
        if (wp->w_buffer == curbuf)
          wp->w_changelistidx = curbuf->b_changelistlen;
      }
      break;
    }
  }
  free(name_buf);
}

int read_viminfo_filemark(vir_T *virp, int force)
{
  char_u      *str;
  xfmark_T    *fm;
  int i;

  /* We only get here if line[0] == '\'' or '-'.
   * Illegal mark names are ignored (for future expansion). */
  str = virp->vir_line + 1;
  if (
    *str <= 127 &&
    ((*virp->vir_line == '\'' && (ascii_isdigit(*str) || isupper(*str)))
     || (*virp->vir_line == '-' && *str == '\''))) {
    if (*str == '\'') {
      /* If the jumplist isn't full insert fmark as oldest entry */
      if (curwin->w_jumplistlen == JUMPLISTSIZE)
        fm = NULL;
      else {
        for (i = curwin->w_jumplistlen; i > 0; --i)
          curwin->w_jumplist[i] = curwin->w_jumplist[i - 1];
        ++curwin->w_jumplistidx;
        ++curwin->w_jumplistlen;
        fm = &curwin->w_jumplist[0];
        fm->fmark.mark.lnum = 0;
        fm->fname = NULL;
      }
    } else if (ascii_isdigit(*str))
      fm = &namedfm[*str - '0' + NMARKS];
    else {  // is uppercase
      assert(*str >= 'A' && *str <= 'Z');
      fm = &namedfm[*str - 'A'];
    }
    if (fm != NULL && (fm->fmark.mark.lnum == 0 || force)) {
      str = skipwhite(str + 1);
      fm->fmark.mark.lnum = getdigits_long(&str);
      str = skipwhite(str);
      fm->fmark.mark.col = getdigits_int(&str);
      fm->fmark.mark.coladd = 0;
      fm->fmark.fnum = 0;
      str = skipwhite(str);
      free(fm->fname);
      fm->fname = viminfo_readstring(virp, (int)(str - virp->vir_line),
          FALSE);
    }
  }
  return vim_fgets(virp->vir_line, LSIZE, virp->vir_fd);
}

void write_viminfo_filemarks(FILE *fp)
{
  int i;
  char_u      *name;
  buf_T       *buf;
  xfmark_T    *fm;

  if (get_viminfo_parameter('f') == 0)
    return;

  fputs(_("\n# File marks:\n"), fp);

  /*
   * Find a mark that is the same file and position as the cursor.
   * That one, or else the last one is deleted.
   * Move '0 to '1, '1 to '2, etc. until the matching one or '9
   * Set '0 mark to current cursor position.
   */
  if (curbuf->b_ffname != NULL && !removable(curbuf->b_ffname)) {
    name = buflist_nr2name(curbuf->b_fnum, TRUE, FALSE);
    for (i = NMARKS; i < NMARKS + EXTRA_MARKS - 1; ++i)
      if (namedfm[i].fmark.mark.lnum == curwin->w_cursor.lnum
          && (namedfm[i].fname == NULL
              ? namedfm[i].fmark.fnum == curbuf->b_fnum
              : (name != NULL
                 && STRCMP(name, namedfm[i].fname) == 0)))
        break;
    free(name);

    free(namedfm[i].fname);
    for (; i > NMARKS; --i)
      namedfm[i] = namedfm[i - 1];
    namedfm[NMARKS].fmark.mark = curwin->w_cursor;
    namedfm[NMARKS].fmark.fnum = curbuf->b_fnum;
    namedfm[NMARKS].fname = NULL;
  }

  /* Write the filemarks '0 - '9 and 'A - 'Z */
  for (i = 0; i < NMARKS + EXTRA_MARKS; i++)
    write_one_filemark(fp, &namedfm[i], '\'',
        i < NMARKS ? i + 'A' : i - NMARKS + '0');

  /* Write the jumplist with -' */
  fputs(_("\n# Jumplist (newest first):\n"), fp);
  setpcmark();          /* add current cursor position */
  cleanup_jumplist();
  for (fm = &curwin->w_jumplist[curwin->w_jumplistlen - 1];
       fm >= &curwin->w_jumplist[0]; --fm) {
    if (fm->fmark.fnum == 0
        || ((buf = buflist_findnr(fm->fmark.fnum)) != NULL
            && !removable(buf->b_ffname)))
      write_one_filemark(fp, fm, '-', '\'');
  }
}

int read_viminfo_search_pattern(vir_T *virp, int force)
{
  char_u      *lp;
  int idx = -1;
  int magic = FALSE;
  int no_scs = FALSE;
  int off_line = FALSE;
  int off_end = 0;
  long off = 0;
  int setlast = FALSE;
  static int hlsearch_on = FALSE;
  char_u      *val;

  /*
   * Old line types:
   * "/pat", "&pat": search/subst. pat
   * "~/pat", "~&pat": last used search/subst. pat
   * New line types:
   * "~h", "~H": hlsearch highlighting off/on
   * "~<magic><smartcase><line><end><off><last><which>pat"
   * <magic>: 'm' off, 'M' on
   * <smartcase>: 's' off, 'S' on
   * <line>: 'L' line offset, 'l' char offset
   * <end>: 'E' from end, 'e' from start
   * <off>: decimal, offset
   * <last>: '~' last used pattern
   * <which>: '/' search pat, '&' subst. pat
   */
  lp = virp->vir_line;
  if (lp[0] == '~' && (lp[1] == 'm' || lp[1] == 'M')) { /* new line type */
    if (lp[1] == 'M')                   /* magic on */
      magic = TRUE;
    if (lp[2] == 's')
      no_scs = TRUE;
    if (lp[3] == 'L')
      off_line = TRUE;
    if (lp[4] == 'E')
      off_end = SEARCH_END;
    lp += 5;
    off = getdigits_long(&lp);
  }
  if (lp[0] == '~') {           /* use this pattern for last-used pattern */
    setlast = TRUE;
    lp++;
  }
  if (lp[0] == '/')
    idx = RE_SEARCH;
  else if (lp[0] == '&')
    idx = RE_SUBST;
  else if (lp[0] == 'h')        /* ~h: 'hlsearch' highlighting off */
    hlsearch_on = FALSE;
  else if (lp[0] == 'H')        /* ~H: 'hlsearch' highlighting on */
    hlsearch_on = TRUE;
  if (idx >= 0) {
    if (force || spats[idx].pat == NULL) {
      val = viminfo_readstring(virp, (int)(lp - virp->vir_line + 1), TRUE);
      set_last_search_pat(val, idx, magic, setlast);
      xfree(val);
      spats[idx].no_scs = no_scs;
      spats[idx].off.line = off_line;
      spats[idx].off.end = off_end;
      spats[idx].off.off = off;
      if (setlast) {
        SET_NO_HLSEARCH(!hlsearch_on);
      }
    }
  }
  return viminfo_readline(virp);
}

void write_viminfo_search_pattern(FILE *fp)
{
  if (get_viminfo_parameter('/') != 0) {
    fprintf(fp, "\n# hlsearch on (H) or off (h):\n~%c",
        (no_hlsearch || find_viminfo_parameter('h') != NULL) ? 'h' : 'H');
    wvsp_one(fp, RE_SEARCH, "", '/');
    wvsp_one(fp, RE_SUBST, _("Substitute "), '&');
  }
}

static void 
wvsp_one (
    FILE *fp,        /* file to write to */
    int idx,                /* spats[] index */
    char *s,         /* search pat */
    int sc                 /* dir char */
)
{
  if (spats[idx].pat != NULL) {
    fprintf(fp, _("\n# Last %sSearch Pattern:\n~"), s);
    /* off.dir is not stored, it's reset to forward */
    fprintf(fp, "%c%c%c%c%" PRId64 "%s%c",
        spats[idx].magic    ? 'M' : 'm',                /* magic */
        spats[idx].no_scs   ? 's' : 'S',                /* smartcase */
        spats[idx].off.line ? 'L' : 'l',                /* line offset */
        spats[idx].off.end  ? 'E' : 'e',                /* offset from end */
        (int64_t)spats[idx].off.off,                    /* offset */
        last_idx == idx     ? "~" : "",                 /* last used pat */
        sc);
    viminfo_writestring(fp, spats[idx].pat);
  }
}

/*
 * Prepare for reading the history from the viminfo file.
 * This allocates history arrays to store the read history lines.
 */
void prepare_viminfo_history(int asklen, int writing)
{
  int i;
  int num;

  init_history();
  viminfo_add_at_front = (asklen != 0 && !writing);
  if (asklen > hislen)
    asklen = hislen;

  for (int type = 0; type < HIST_COUNT; ++type) {
    /* Count the number of empty spaces in the history list.  Entries read
     * from viminfo previously are also considered empty.  If there are
     * more spaces available than we request, then fill them up. */
    for (i = 0, num = 0; i < hislen; i++)
      if (history[type][i].hisstr == NULL || history[type][i].viminfo)
        num++;
    int len = asklen;
    if (num > len)
      len = num;
    if (len <= 0)
      viminfo_history[type] = NULL;
    else
      viminfo_history[type] = xmalloc(len * sizeof(char_u *));
    if (viminfo_history[type] == NULL)
      len = 0;
    viminfo_hislen[type] = len;
    viminfo_hisidx[type] = 0;
  }
}

/*
 * Accept a line from the viminfo, store it in the history array when it's
 * new.
 */
int read_viminfo_history(vir_T *virp, int writing)
{
  int type;
  char_u      *val;

  type = hist_char2type(virp->vir_line[0]);
  if (viminfo_hisidx[type] < viminfo_hislen[type]) {
    val = viminfo_readstring(virp, 1, TRUE);
    if (val != NULL && *val != NUL) {
      int sep = (*val == ' ' ? NUL : *val);

      if (!in_history(type, val + (type == HIST_SEARCH),
              viminfo_add_at_front, sep, writing)) {
        /* Need to re-allocate to append the separator byte. */
        size_t len = STRLEN(val);
        char_u *p = xmalloc(len + 2);
        if (type == HIST_SEARCH) {
          /* Search entry: Move the separator from the first
           * column to after the NUL. */
          memmove(p, val + 1, len);
          p[len] = sep;
        } else {
          /* Not a search entry: No separator in the viminfo
           * file, add a NUL separator. */
          memmove(p, val, len + 1);
          p[len + 1] = NUL;
        }
        viminfo_history[type][viminfo_hisidx[type]++] = p;
      }
    }
    xfree(val);
  }
  return viminfo_readline(virp);
}

/*
 * Finish reading history lines from viminfo.  Not used when writing viminfo.
 */
void finish_viminfo_history(void)
{
  int idx;
  int i;
  int type;

  for (type = 0; type < HIST_COUNT; ++type) {
    if (history[type] == NULL)
      continue;
    idx = hisidx[type] + viminfo_hisidx[type];
    if (idx >= hislen)
      idx -= hislen;
    else if (idx < 0)
      idx = hislen - 1;
    if (viminfo_add_at_front)
      hisidx[type] = idx;
    else {
      if (hisidx[type] == -1)
        hisidx[type] = hislen - 1;
      do {
        if (history[type][idx].hisstr != NULL
            || history[type][idx].viminfo)
          break;
        if (++idx == hislen)
          idx = 0;
      } while (idx != hisidx[type]);
      if (idx != hisidx[type] && --idx < 0)
        idx = hislen - 1;
    }
    for (i = 0; i < viminfo_hisidx[type]; i++) {
      xfree(history[type][idx].hisstr);
      history[type][idx].hisstr = viminfo_history[type][i];
      history[type][idx].viminfo = TRUE;
      if (--idx < 0)
        idx = hislen - 1;
    }
    idx += 1;
    idx %= hislen;
    for (i = 0; i < viminfo_hisidx[type]; i++) {
      history[type][idx++].hisnum = ++hisnum[type];
      idx %= hislen;
    }
    xfree(viminfo_history[type]);
    viminfo_history[type] = NULL;
    viminfo_hisidx[type] = 0;
  }
}

/*
 * Write history to viminfo file in "fp".
 * When "merge" is TRUE merge history lines with a previously read viminfo
 * file, data is in viminfo_history[].
 * When "merge" is FALSE just write all history lines.  Used for ":wviminfo!".
 */
void write_viminfo_history(FILE *fp, int merge)
{
  int i;
  int type;
  int num_saved;
  char_u  *p;
  int c;
  int round;

  init_history();
  if (hislen == 0)
    return;
  for (type = 0; type < HIST_COUNT; ++type) {
    num_saved = get_viminfo_parameter(hist_type2char(type, FALSE));
    if (num_saved == 0)
      continue;
    if (num_saved < 0)      /* Use default */
      num_saved = hislen;
    fprintf(fp, _("\n# %s History (newest to oldest):\n"),
        type == HIST_CMD ? _("Command Line") :
        type == HIST_SEARCH ? _("Search String") :
        type == HIST_EXPR ?  _("Expression") :
        _("Input Line"));
    if (num_saved > hislen)
      num_saved = hislen;

    /*
     * Merge typed and viminfo history:
     * round 1: history of typed commands.
     * round 2: history from recently read viminfo.
     */
    for (round = 1; round <= 2; ++round) {
      if (round == 1)
        /* start at newest entry, somewhere in the list */
        i = hisidx[type];
      else if (viminfo_hisidx[type] > 0)
        /* start at newest entry, first in the list */
        i = 0;
      else
        /* empty list */
        i = -1;
      if (i >= 0)
        while (num_saved > 0
               && !(round == 2 && i >= viminfo_hisidx[type])) {
          p = round == 1 ? history[type][i].hisstr
              : viminfo_history[type] == NULL ? NULL
              : viminfo_history[type][i];
          if (p != NULL && (round == 2
                            || !merge
                            || !history[type][i].viminfo)) {
            --num_saved;
            fputc(hist_type2char(type, TRUE), fp);
            /* For the search history: put the separator in the
            * second column; use a space if there isn't one. */
            if (type == HIST_SEARCH) {
              c = p[STRLEN(p) + 1];
              putc(c == NUL ? ' ' : c, fp);
            }
            viminfo_writestring(fp, p);
          }
          if (round == 1) {
            /* Decrement index, loop around and stop when back at
             * the start. */
            if (--i < 0)
              i = hislen - 1;
            if (i == hisidx[type])
              break;
          } else {
            /* Increment index. Stop at the end in the while. */
            ++i;
          }
        }
    }
    for (i = 0; i < viminfo_hisidx[type]; ++i)
      if (viminfo_history[type] != NULL)
        xfree(viminfo_history[type][i]);
    xfree(viminfo_history[type]);
    viminfo_history[type] = NULL;
    viminfo_hisidx[type] = 0;
  }
}

int read_viminfo_register(vir_T *virp, int force)
{
  int eof;
  int do_it = TRUE;
  int size;
  int limit;
  int set_prev = FALSE;
  char_u      *str;
  char_u      **array = NULL;

  /* We only get here (hopefully) if line[0] == '"' */
  str = virp->vir_line + 1;

  /* If the line starts with "" this is the y_previous register. */
  if (*str == '"') {
    set_prev = TRUE;
    str++;
  }

  if (!ASCII_ISALNUM(*str) && *str != '-') {
    if (viminfo_error("E577: ", _("Illegal register name"), virp->vir_line))
      return TRUE;              /* too many errors, pretend end-of-file */
    do_it = FALSE;
  }
  yankreg_T *reg = get_yank_register(*str++, YREG_PUT);
  if (!force && reg->y_array != NULL)
    do_it = FALSE;

  if (*str == '@') {
    /* "x@: register x used for @@ */
    if (force || execreg_lastc == NUL)
      execreg_lastc = str[-1];
  }

  size = 0;
  limit = 100;          /* Optimized for registers containing <= 100 lines */
  if (do_it) {
    if (set_prev) {
      y_previous = reg;
    }

    free_register(reg);
    array = xmalloc(limit * sizeof(char_u *));

    str = skipwhite(skiptowhite(str));
    if (STRNCMP(str, "CHAR", 4) == 0) {
      reg->y_type = MCHAR;
    } else if (STRNCMP(str, "BLOCK", 5) == 0) {
      reg->y_type = MBLOCK;
    } else {
      reg->y_type = MLINE;
    }
    /* get the block width; if it's missing we get a zero, which is OK */
    str = skipwhite(skiptowhite(str));
    reg->y_width = getdigits_int(&str);
  }

  while (!(eof = viminfo_readline(virp))
         && (virp->vir_line[0] == TAB || virp->vir_line[0] == '<')) {
    if (do_it) {
      if (size >= limit) {
        limit *= 2;
        array = xrealloc(array, limit * sizeof(char_u *));
      }
      array[size++] = viminfo_readstring(virp, 1, TRUE);
    }
  }

  if (do_it) {
    if (size == 0) {
      xfree(array);
    } else if (size < limit) {
      reg->y_array = xrealloc(array, size * sizeof(char_u *));
    } else {
      reg->y_array = array;
    }
    reg->y_size = size;
  }
  return eof;
}

void write_viminfo_registers(FILE *fp)
{
  int i, j;
  char_u  *type;
  char_u c;
  int num_lines;
  int max_num_lines;
  int max_kbyte;
  long len;

  fputs(_("\n# Registers:\n"), fp);

  /* Get '<' value, use old '"' value if '<' is not found. */
  max_num_lines = get_viminfo_parameter('<');
  if (max_num_lines < 0)
    max_num_lines = get_viminfo_parameter('"');
  if (max_num_lines == 0)
    return;
  max_kbyte = get_viminfo_parameter('s');
  if (max_kbyte == 0)
    return;

  // don't include clipboard registers '*'/'+'
  for (i = 0; i < NUM_SAVED_REGISTERS; i++) {
    if (y_regs[i].y_array == NULL)
      continue;

    /* Skip empty registers. */
    num_lines = y_regs[i].y_size;
    if (num_lines == 0
        || (num_lines == 1 && y_regs[i].y_type == MCHAR
            && *y_regs[i].y_array[0] == NUL))
      continue;

    if (max_kbyte > 0) {
      /* Skip register if there is more text than the maximum size. */
      len = 0;
      for (j = 0; j < num_lines; j++)
        len += (long)STRLEN(y_regs[i].y_array[j]) + 1L;
      if (len > (long)max_kbyte * 1024L)
        continue;
    }

    switch (y_regs[i].y_type) {
    case MLINE:
      type = (char_u *)"LINE";
      break;
    case MCHAR:
      type = (char_u *)"CHAR";
      break;
    case MBLOCK:
      type = (char_u *)"BLOCK";
      break;
    default:
      sprintf((char *)IObuff, _("E574: Unknown register type %d"),
          y_regs[i].y_type);
      emsg(IObuff);
      type = (char_u *)"LINE";
      break;
    }
    if (y_previous == &y_regs[i])
      fprintf(fp, "\"");
    c = get_register_name(i);
    fprintf(fp, "\"%c", c);
    if (c == execreg_lastc)
      fprintf(fp, "@");
    fprintf(fp, "\t%s\t%d\n", type,
        (int)y_regs[i].y_width
        );

    /* If max_num_lines < 0, then we save ALL the lines in the register */
    if (max_num_lines > 0 && num_lines > max_num_lines)
      num_lines = max_num_lines;
    for (j = 0; j < num_lines; j++) {
      putc('\t', fp);
      viminfo_writestring(fp, y_regs[i].y_array[j]);
    }
  }
}

/*
 * Restore global vars that start with a capital from the viminfo file
 */
int read_viminfo_varlist(vir_T *virp, int writing)
{
  char_u      *tab;
  int type = VAR_NUMBER;
  typval_T tv;

  if (!writing && (find_viminfo_parameter('!') != NULL)) {
    tab = vim_strchr(virp->vir_line + 1, '\t');
    if (tab != NULL) {
      *tab++ = NUL;            /* isolate the variable name */
      switch (*tab) {
      case 'S': type = VAR_STRING; break;
      case 'F': type = VAR_FLOAT; break;
      case 'D': type = VAR_DICT; break;
      case 'L': type = VAR_LIST; break;
      }

      tab = vim_strchr(tab, '\t');
      if (tab != NULL) {
        tv.v_type = type;
        if (type == VAR_STRING || type == VAR_DICT || type == VAR_LIST)
          tv.vval.v_string = viminfo_readstring(virp,
              (int)(tab - virp->vir_line + 1), TRUE);
        else if (type == VAR_FLOAT)
          (void)string2float(tab + 1, &tv.vval.v_float);
        else
          tv.vval.v_number = atol((char *)tab + 1);
        if (type == VAR_DICT || type == VAR_LIST) {
          typval_T *etv = eval_expr(tv.vval.v_string, NULL);

          if (etv == NULL)
            /* Failed to parse back the dict or list, use it as a
             * string. */
            tv.v_type = VAR_STRING;
          else {
            free(tv.vval.v_string);
            tv = *etv;
            free(etv);
          }
        }

        set_var(virp->vir_line + 1, &tv, FALSE);

        if (tv.v_type == VAR_STRING)
          free(tv.vval.v_string);
        else if (tv.v_type == VAR_DICT || tv.v_type == VAR_LIST)
          clear_tv(&tv);
      }
    }
  }

  return viminfo_readline(virp);
}

/*
 * Write global vars that start with a capital to the viminfo file
 */
void write_viminfo_varlist(FILE *fp)
{
  hashitem_T  *hi;
  dictitem_T  *this_var;
  int todo;
  char        *s;
  char_u      *p;
  char_u      *tofree;
  char_u numbuf[NUMBUFLEN];

  if (find_viminfo_parameter('!') == NULL)
    return;

  fputs(_("\n# global variables:\n"), fp);

  todo = (int)globvarht.ht_used;
  for (hi = globvarht.ht_array; todo > 0; ++hi) {
    if (!HASHITEM_EMPTY(hi)) {
      --todo;
      this_var = HI2DI(hi);
      if (var_flavour(this_var->di_key) == VAR_FLAVOUR_VIMINFO) {
        switch (this_var->di_tv.v_type) {
        case VAR_STRING: s = "STR"; break;
        case VAR_NUMBER: s = "NUM"; break;
        case VAR_FLOAT:  s = "FLO"; break;
        case VAR_DICT:   s = "DIC"; break;
        case VAR_LIST:   s = "LIS"; break;
        default: continue;
        }
        fprintf(fp, "!%s\t%s\t", this_var->di_key, s);
        p = echo_string(&this_var->di_tv, &tofree, numbuf, 0);
        if (p != NULL)
          viminfo_writestring(fp, p);
        free(tofree);
      }
    }
  }
}

int read_viminfo_bufferlist(vir_T *virp, int writing)
{
  char_u      *tab;
  linenr_T lnum;
  colnr_T col;
  buf_T       *buf;
  char_u      *sfname;
  char_u      *xline;

  /* Handle long line and escaped characters. */
  xline = viminfo_readstring(virp, 1, FALSE);

  /* don't read in if there are files on the command-line or if writing: */
  if (xline != NULL && !writing && ARGCOUNT == 0
      && find_viminfo_parameter('%') != NULL) {
    /* Format is: <fname> Tab <lnum> Tab <col>.
     * Watch out for a Tab in the file name, work from the end. */
    lnum = 0;
    col = 0;
    tab = vim_strrchr(xline, '\t');
    if (tab != NULL) {
      *tab++ = '\0';
      col = (colnr_T)atoi((char *)tab);
      tab = vim_strrchr(xline, '\t');
      if (tab != NULL) {
        *tab++ = '\0';
        lnum = atol((char *)tab);
      }
    }

    /* Expand "~/" in the file name at "line + 1" to a full path.
     * Then try shortening it by comparing with the current directory */
    expand_env(xline, NameBuff, MAXPATHL);
    sfname = path_shorten_fname_if_possible(NameBuff);

    buf = buflist_new(NameBuff, sfname, (linenr_T)0, BLN_LISTED);
    if (buf != NULL) {          /* just in case... */
      buf->b_last_cursor.lnum = lnum;
      buf->b_last_cursor.col = col;
      buflist_setfpos(buf, curwin, lnum, col, FALSE);
    }
  }
  xfree(xline);

  return viminfo_readline(virp);
}

void write_viminfo_bufferlist(FILE *fp)
{
  char_u      *line;
  int max_buffers;

  if (find_viminfo_parameter('%') == NULL)
    return;

  /* Without a number -1 is returned: do all buffers. */
  max_buffers = get_viminfo_parameter('%');

  /* Allocate room for the file name, lnum and col. */
#define LINE_BUF_LEN (MAXPATHL + 40)
  line = xmalloc(LINE_BUF_LEN);

  FOR_ALL_TAB_WINDOWS(tp, win) {
    set_last_cursor(win);
  }

  fputs(_("\n# Buffer list:\n"), fp);
  FOR_ALL_BUFFERS(buf) {
    if (buf->b_fname == NULL
        || !buf->b_p_bl
        || bt_quickfix(buf)
        || removable(buf->b_ffname))
      continue;

    if (max_buffers-- == 0)
      break;
    putc('%', fp);
    home_replace(NULL, buf->b_ffname, line, MAXPATHL, TRUE);
    vim_snprintf_add((char *)line, LINE_BUF_LEN, "\t%" PRId64 "\t%d",
        (int64_t)buf->b_last_cursor.lnum,
        buf->b_last_cursor.col);
    viminfo_writestring(fp, line);
  }
  xfree(line);
}

int read_viminfo_sub_string(vir_T *virp, int force)
{
  if (force)
    xfree(old_sub);
  if (force || old_sub == NULL)
    old_sub = viminfo_readstring(virp, 1, TRUE);
  return viminfo_readline(virp);
}

void write_viminfo_sub_string(FILE *fp)
{
  if (get_viminfo_parameter('/') != 0 && old_sub != NULL) {
    fputs(_("\n# Last Substitute String:\n$"), fp);
    viminfo_writestring(fp, old_sub);
  }
}

/*
 * Structure used for reading from the viminfo file.
 */
typedef struct {
  char_u      *vir_line;        /* text of the current line */
  FILE        *vir_fd;          /* file descriptor */
  vimconv_T vir_conv;           /* encoding conversion */
} vir_T;
#endif
