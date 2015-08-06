#include <stdlib.h>
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
#include "nvim/fileio.h"
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
KHASH_SET_INIT_STR(strset)

#define copy_option_part(src, dest, ...) \
    ((char *) copy_option_part((char_u **) src, (char_u *) dest, __VA_ARGS__))
#define find_shada_parameter(...) \
    ((const char *) find_shada_parameter(__VA_ARGS__))
#define emsg2(a, b) emsg2((char_u *) a, (char_u *) b)
#define emsg3(a, b, c) emsg3((char_u *) a, (char_u *) b, (char_u *) c)
#define emsgu(a, ...) emsgu((char_u *) a, __VA_ARGS__)
#define home_replace_save(a, b) \
    ((char *)home_replace_save(a, (char_u *)b))
#define vim_rename(a, b) \
    (vim_rename((char_u *)a, (char_u *)b))
#define has_non_ascii(a) (has_non_ascii((char_u *)a))
#define string_convert(a, b, c) \
      ((char *)string_convert((vimconv_T *)a, (char_u *)b, c))
#define path_shorten_fname_if_possible(b) \
    ((char *)path_shorten_fname_if_possible((char_u *)b))
#define buflist_new(ffname, sfname, ...) \
    (buflist_new((char_u *)ffname, (char_u *)sfname, __VA_ARGS__))
#define convert_setup(vcp, from, to) \
    (convert_setup(vcp, (char_u *)from, (char_u *)to))
#define os_getperm(f) \
    (os_getperm((char_u *) f))
#define os_isdir(f) (os_isdir((char_u *) f))
#define path_tail_with_sep(f) ((char *) path_tail_with_sep((char_u *)f))

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

#define SEARCH_KEY_MAGIC "sm"
#define SEARCH_KEY_SMARTCASE "sc"
#define SEARCH_KEY_HAS_LINE_OFFSET "sl"
#define SEARCH_KEY_PLACE_CURSOR_AT_END "se"
#define SEARCH_KEY_IS_LAST_USED "su"
#define SEARCH_KEY_IS_SUBSTITUTE_PATTERN "ss"
#define SEARCH_KEY_HIGHLIGHTED "sh"
#define SEARCH_KEY_OFFSET "so"
#define SEARCH_KEY_PAT "sp"

#define REG_KEY_TYPE "rt"
#define REG_KEY_WIDTH "rw"
#define REG_KEY_CONTENTS "rc"

#define KEY_LNUM "l"
#define KEY_COL "c"
#define KEY_FILE "f"
#define KEY_NAME_CHAR "n"

// Error messages formerly used by viminfo code:
//   E136: viminfo: Too many errors, skipping rest of file
//   E137: Viminfo file is not writable: %s
//   E138: Can't write viminfo file %s!
//   E195: Cannot open ShaDa file for reading
//   E574: Unknown register type %d
//   E575: Illegal starting char
//   E576: Missing '>'
//   E577: Illegal register name
//   E886: Can't rename viminfo file to %s!
// Now only five of them are used:
//   E137: ShaDa file is not writeable (for pre-open checks)
//   E138: All %s.tmp.X files exist, cannot write ShaDa file!
//   RCERR (E576) for critical read errors.
//   RNERR (E136) for various errors when renaming.
//   RERR (E575) for various errors inside read ShaDa file.
//   SERR (E886) for various “system” errors (always contains output of 
//   strerror)

/// Common prefix for all errors inside ShaDa file
///
/// I.e. errors occurred while parsing, but not system errors occurred while 
/// reading.
#define RERR "E575: "

/// Common prefix for critical read errors
///
/// I.e. errors that make shada_read_next_item return kSDReadStatusNotShaDa.
#define RCERR "E576: "

/// Common prefix for all “system” errors
#define SERR "E886: "

/// Common prefix for all “rename” errors
#define RNERR "E136: "

/// Flags for shada_read_file and children
enum {
  kShaDaWantInfo = 1,       ///< Load non-mark information
  kShaDaWantMarks = 2,      ///< Load local file marks and change list
  kShaDaForceit = 4,        ///< Overwrite info already read
  kShaDaGetOldfiles = 8,    ///< Load v:oldfiles.
  kShaDaMissingError = 16,  ///< Error out when os_open returns -ENOENT.
};

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

/// Possible results when reading ShaDa file
typedef enum {
  kSDReadStatusSuccess,    ///< Reading was successfull.
  kSDReadStatusFinished,   ///< Nothing more to read.
  kSDReadStatusReadError,  ///< Failed to read from file.
  kSDReadStatusNotShaDa,   ///< Input is most likely not a ShaDa file.
  kSDReadStatusMalformed,  ///< Error in the currently read item.
} ShaDaReadResult;

/// Possible results of shada_write function.
typedef enum {
  kSDWriteSuccessfull,   ///< Writing was successfull.
  kSDWriteReadNotShada,  ///< Writing was successfull, but when reading it 
                         ///< attempted to read file that did not look like 
                         ///< a ShaDa file.
  kSDWriteFailed,        ///< Writing was not successfull (e.g. because there 
                         ///< was no space left on device).
} ShaDaWriteResult;

/// Flags for shada_read_next_item
enum SRNIFlags {
  kSDReadHeader = (1 << kSDItemHeader),  ///< Determines whether header should
                                         ///< be read (it is usually ignored).
  kSDReadUndisableableData = (
    (1 << kSDItemSearchPattern)
    | (1 << kSDItemSubString)
    | (1 << kSDItemJump)
  ), ///< Data reading which cannot be disabled by &shada or other options 
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
                                              ///< removing ! from &shada).
  kSDReadBufferList = (1 << kSDItemBufferList),  ///< Determines whether buffer 
                                                 ///< list should be read 
                                                 ///< (disabled by removing 
                                                 ///< % entry from &shada).
  kSDReadUnknown = (1 << (SHADA_LAST_ENTRY + 1)),  ///< Determines whether 
                                                   ///< unknown items should be 
                                                   ///< read (usually disabled).
  kSDReadGlobalMarks = (1 << kSDItemGlobalMark),  ///< Determines whether global 
                                                  ///< marks should be read. Can 
                                                  ///< only be disabled by 
                                                  ///< having f0 in &shada when 
                                                  ///< writing.
  kSDReadLocalMarks = (1 << kSDItemLocalMark),  ///< Determines whether local 
                                                ///< marks should be read. Can 
                                                ///< only be disabled by 
                                                ///< disabling &shada or putting 
                                                ///< '0 there. Is also used for 
                                                ///< v:oldfiles.
  kSDReadChanges = (1 << kSDItemChange),  ///< Determines whether change list 
                                          ///< should be read. Can only be 
                                          ///< disabled by disabling &shada or 
                                          ///< putting '0 there.
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
      dict_T *additional_data;
    } filemark;
    struct search_pattern {
      bool magic;
      bool smartcase;
      bool has_line_offset;
      bool place_cursor_at_end;
      int64_t offset;
      bool is_last_used;
      bool is_substitute_pattern;
      bool highlighted;
      char *pat;
      dict_T *additional_data;
    } search_pattern;
    struct history_item {
      uint8_t histtype;
      char *string;
      char sep;
      list_T *additional_elements;
    } history_item;
    struct reg {
      char name;
      uint8_t type;
      char **contents;
      size_t contents_size;
      size_t width;
      dict_T *additional_data;
    } reg;
    struct global_var {
      char *name;
      typval_T value;
      list_T *additional_elements;
    } global_var;
    struct {
      uint64_t type;
      char *contents;
      size_t size;
    } unknown_item;
    struct sub_string {
      char *sub;
      list_T *additional_elements;
    } sub_string;
    struct buffer_list {
      size_t size;
      struct buffer_list_buffer {
        pos_T pos;
        char *fname;
        dict_T *additional_data;
      } *buffers;
    } buffer_list;
  } data;
} ShadaEntry;

struct hm_llist_entry;

/// One entry in sized linked list
typedef struct hm_llist_entry {
  ShadaEntry data;              ///< Entry data.
  bool can_free_entry;          ///< True if data can be freed.
  struct hm_llist_entry *next;  ///< Pointer to next entry or NULL.
  struct hm_llist_entry *prev;  ///< Pointer to previous entry or NULL.
} HMLListEntry;

/// Sized linked list structure for history merger
typedef struct {
  HMLListEntry *entries;  ///< Pointer to the start of the allocated array of 
                          ///< entries.
  HMLListEntry *first;    ///< First entry in the list (is not necessary start 
                          ///< of the array) or NULL.
  HMLListEntry *last;     ///< Last entry in the list or NULL.
  HMLListEntry **free_entries;  ///< Free array entries.
  HMLListEntry *last_free_element;  ///< Last free array element.
  size_t size;            ///< Number of allocated entries.
  size_t free_entries_size;  ///< Number of non-NULL entries in free_entries.
  size_t num_entries;     ///< Number of entries already used.
} HMLList;

typedef struct {
  HMLList hmll;
  bool do_merge;
  bool reading;
  const void *iter;
  ShadaEntry last_hist_entry;
  uint8_t history_type;
} HistoryMergerState;

/// ShadaEntry structure that knows whether it should be freed
typedef struct {
  ShadaEntry data;      ///< ShadaEntry data.
  bool can_free_entry;  ///< True if entry can be freed.
} PossiblyFreedShadaEntry;

/// Structure that holds one file marks.
typedef struct {
  PossiblyFreedShadaEntry marks[NLOCALMARKS];  ///< All file marks.
  PossiblyFreedShadaEntry changes[JUMPLISTSIZE];  ///< All file changes.
  size_t changes_size;  ///< Number of changes occupied.
  ShadaEntry *additional_marks;  ///< All marks with unknown names.
  size_t additional_marks_size;  ///< Size of the additional_marks array.
  Timestamp greatest_timestamp;  ///< Greatest timestamp among marks.
  bool is_local_entry;  ///< True if structure comes from the current session.
} FileMarks;

KHASH_MAP_INIT_STR(file_marks, FileMarks)

/// State structure used by shada_write
///
/// Before actually writing most of the data is read to this structure.
typedef struct {
  HistoryMergerState hms[HIST_COUNT];  ///< Structures for history merging.
  PossiblyFreedShadaEntry global_marks[NGLOBALMARKS];  ///< All global marks.
  PossiblyFreedShadaEntry registers[NUM_SAVED_REGISTERS];  ///< All registers.
  PossiblyFreedShadaEntry jumps[JUMPLISTSIZE];  ///< All dumped jumps.
  size_t jumps_size;  ///< Number of jumps occupied.
  PossiblyFreedShadaEntry search_pattern;  ///< Last search pattern.
  PossiblyFreedShadaEntry sub_search_pattern;  ///< Last s/ search pattern.
  PossiblyFreedShadaEntry replacement;  ///< Last s// replacement string.
  khash_t(strset) dumped_variables;  ///< Names of already dumped variables.
  khash_t(file_marks) file_marks;  ///< All file marks.
} WriteMergerState;

struct sd_read_def;

/// Function used to close files defined by ShaDaReadDef
typedef void (*ShaDaReadCloser)(struct sd_read_def *const sd_reader)
  REAL_FATTR_NONNULL_ALL;

/// Function used to read ShaDa files
typedef ptrdiff_t (*ShaDaFileReader)(struct sd_read_def *const sd_reader,
                                     void *const dest,
                                     const size_t size)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_WARN_UNUSED_RESULT;

/// Structure containing necessary pointers for reading ShaDa files
typedef struct sd_read_def {
  ShaDaFileReader read;   ///< Reader function.
  ShaDaReadCloser close;  ///< Close function.
  void *cookie;           ///< Reader function last argument.
  bool eof;               ///< True if reader reached end of file.
  char *error;            ///< Error message in case of error.
  uintmax_t fpos;         ///< Current position (amount of bytes read since 
                          ///< reader structure initialization). May overflow.
  vimconv_T sd_conv;      ///< Structure used for converting encodings of some
                          ///< items.
} ShaDaReadDef;

struct sd_write_def;

/// Function used to close files defined by ShaDaWriteDef
typedef void (*ShaDaWriteCloser)(struct sd_write_def *const sd_writer)
  REAL_FATTR_NONNULL_ALL;

/// Function used to write ShaDa files
typedef ptrdiff_t (*ShaDaFileWriter)(struct sd_write_def *const sd_writer,
                                     const void *const src,
                                     const size_t size)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_WARN_UNUSED_RESULT;

/// Structure containing necessary pointers for writing ShaDa files
typedef struct sd_write_def {
  ShaDaFileWriter write;   ///< Writer function.
  ShaDaWriteCloser close;  ///< Close function.
  void *cookie;            ///< Writer function last argument.
  char *error;             ///< Error message in case of error.
  vimconv_T sd_conv;       ///< Structure used for converting encodings of some
                           ///< items.
} ShaDaWriteDef;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "shada.c.generated.h"
#endif

/// Initialize new linked list
///
/// @param[out]  hmll       List to initialize.
/// @param[in]   size       Maximum size of the list.
static inline void hmll_init(HMLList *const hmll, const size_t size)
  FUNC_ATTR_NONNULL_ALL
{
  *hmll = (HMLList) {
    .entries = xcalloc(size, sizeof(hmll->entries[0])),
    .first = NULL,
    .last = NULL,
    .free_entries = NULL,
    .size = size,
    .free_entries_size = 0,
    .num_entries = 0,
  };
  hmll->last_free_element = hmll->entries;
}

/// Iterate over HMLList in forward direction
///
/// @param  hmll       Pointer to the list.
/// @param  cur_entry  Name of the variable to iterate over.
///
/// @return `for` cycle header (use `HMLL_FORALL(hmll, cur_entry) {body}`).
#define HMLL_FORALL(hmll, cur_entry) \
    for (HMLListEntry *cur_entry = (hmll)->first; cur_entry != NULL; \
         cur_entry = cur_entry->next)

/// Remove entry from the linked list
///
/// @param  hmll        List to remove from.
/// @param  hmll_entry  Entry to remove.
static inline void hmll_remove(HMLList *const hmll,
                               HMLListEntry *const hmll_entry)
  FUNC_ATTR_NONNULL_ALL
{
  if (hmll->free_entries == NULL) {
    if (hmll_entry == hmll->last_free_element) {
      hmll->last_free_element--;
    } else {
      hmll->free_entries = xcalloc(hmll->size, sizeof(hmll->free_entries[0]));
      hmll->free_entries[hmll->free_entries_size++] = hmll_entry;
    }
  } else {
    hmll->free_entries[hmll->free_entries_size++] = hmll_entry;
  }
  if (hmll_entry->next == NULL) {
    hmll->last = hmll_entry->prev;
  } else {
    hmll_entry->next->prev = hmll_entry->prev;
  }
  if (hmll_entry->prev == NULL) {
    hmll->first = hmll_entry->next;
  } else {
    hmll_entry->prev->next = hmll_entry->next;
  }
  hmll->num_entries--;
  if (hmll_entry->can_free_entry) {
    shada_free_shada_entry(&hmll_entry->data);
  }
}


/// Insert entry to the linked list
///
/// @param[out]  hmll            List to insert to.
/// @param[in]   hmll_entry      Entry to insert after or NULL if it is needed 
///                              to insert at the first entry.
/// @param[in]   data            Data to insert.
/// @param[in]   can_free_entry  True if data can be freed.
static inline void hmll_insert(HMLList *const hmll,
                               HMLListEntry *hmll_entry,
                               const ShadaEntry data,
                               const bool can_free_entry)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (hmll->num_entries == hmll->size) {
    if (hmll_entry == hmll->first) {
      hmll_entry = NULL;
    }
    hmll_remove(hmll, hmll->first);
  }
  HMLListEntry *target_entry;
  if (hmll->free_entries == NULL) {
    assert((size_t) (hmll->last_free_element - hmll->entries)
           == hmll->num_entries);
    target_entry = hmll->last_free_element++;
  } else {
    target_entry = hmll->free_entries[--hmll->free_entries_size];
  }
  target_entry->data = data;
  target_entry->can_free_entry = can_free_entry;
  hmll->num_entries++;
  target_entry->prev = hmll_entry;
  if (hmll_entry == NULL) {
    target_entry->next = hmll->first;
    hmll->first = target_entry;
  } else {
    target_entry->next = hmll_entry->next;
    hmll_entry->next = target_entry;
  }
  if (target_entry->next == NULL) {
    hmll->last = target_entry;
  } else {
    target_entry->next->prev = target_entry;
  }
}

/// Iterate over HMLList in backward direction
///
/// @param  hmll       Pointer to the list.
/// @param  cur_entry  Name of the variable to iterate over, must be already 
///                    defined.
///
/// @return `for` cycle header (use `HMLL_FORALL(hmll, cur_entry) {body}`).
#define HMLL_ITER_BACK(hmll, cur_entry) \
    for (cur_entry = (hmll)->last; cur_entry != NULL; \
         cur_entry = cur_entry->prev)

/// Free linked list
///
/// @param[in]  hmll  List to free.
static inline void hmll_dealloc(HMLList *const hmll)
  FUNC_ATTR_NONNULL_ALL
{
  xfree(hmll->entries);
  xfree(hmll->free_entries);
}

/// Wrapper for reading from file descriptors
///
/// @return true if read was successfull, false otherwise.
static ptrdiff_t read_file(ShaDaReadDef *const sd_reader, void *const dest,
                           const size_t size)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  size_t read_bytes = 0;
  bool did_try_to_free = false;
  const int fd = (int)(intptr_t) sd_reader->cookie;
  while (read_bytes != size) {
    const ptrdiff_t cur_read_bytes = read(fd, ((char *) dest) + read_bytes,
                                          size - read_bytes);
    if (cur_read_bytes > 0) {
      read_bytes += (size_t) cur_read_bytes;
      sd_reader->fpos += (uintmax_t) cur_read_bytes;
      assert(read_bytes <= size);
    }
    if (cur_read_bytes < 0) {
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
  const int fd = (int)(intptr_t) sd_writer->cookie;
  while (written_bytes != size) {
    const ptrdiff_t cur_written_bytes = write(fd, (char *) dest + written_bytes,
                                              size - written_bytes);
    if (cur_written_bytes > 0) {
      written_bytes += (size_t) cur_written_bytes;
    }
    if (cur_written_bytes < 0) {
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

/// Wrapper for closing file descriptors opened for reading
static void close_sd_reader(ShaDaReadDef *const sd_reader)
  FUNC_ATTR_NONNULL_ALL
{
  close_file((int)(intptr_t) sd_reader->cookie);
}

/// Wrapper for closing file descriptors opened for writing
static void close_sd_writer(ShaDaWriteDef *const sd_writer)
  FUNC_ATTR_NONNULL_ALL
{
  const int fd = (int)(intptr_t) sd_writer->cookie;
  if (fsync(fd) < 0) {
    emsg2(_(SERR "System error while synchronizing ShaDa file: %s"),
          strerror(errno));
    errno = 0;
  }
  close_file(fd);
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
      return fd;
    }
    if (-fd == ENOMEM && !did_try_to_free) {
      try_to_free_memory();
      did_try_to_free = true;
      goto open_file_start;
    }
    if (-fd != EEXIST) {
      emsg3(_(SERR "System error while opening ShaDa file %s: %s"),
            fname, os_strerror(fd));
    }
    return fd;
  }
  return fd;
}

/// Open ShaDa file for reading
///
/// @param[in]   fname      File name to open.
/// @param[out]  sd_reader  Location where reader structure will be saved.
///
/// @return -errno in case of error, 0 otherwise.
static int open_shada_file_for_reading(const char *const fname,
                                       ShaDaReadDef *sd_reader)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  const intptr_t fd = (intptr_t) open_file(fname, O_RDONLY, 0);

  if (fd < 0) {
    return (int) fd;
  }

  *sd_reader = (ShaDaReadDef) {
    .read = &read_file,
    .close = &close_sd_reader,
    .error = NULL,
    .eof = false,
    .fpos = 0,
    .cookie = (void *) fd,
  };

  convert_setup(&sd_reader->sd_conv, "utf-8", p_enc);

  return 0;
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
      emsg2(_(SERR "System error while closing ShaDa file: %s"),
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

/// Check whether string is in the given set
///
/// @param[in]  set  Set to check within.
/// @param[in]  buf  Buffer to find.
///
/// @return true or false.
static inline bool in_strset(const khash_t(strset) *const set, char *str)
  FUNC_ATTR_PURE
{
  return kh_get(strset, set, str) != kh_end(set);
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
    emsg2(_(SERR "System error while writing ShaDa file: %s"),
          sd_writer->error);
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
static int shada_read_file(const char *const file, const int flags)
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
    smsg(_("Reading ShaDa file \"%s\"%s%s%s"),
        fname,
        (flags & kShaDaWantInfo) ? _(" info") : "",
        (flags & kShaDaWantMarks) ? _(" marks") : "",
        (flags & kShaDaGetOldfiles) ? _(" oldfiles") : "",
        of_ret != 0 ? _(" FAILED") : "");
    verbose_leave();
  }

  if (of_ret != 0) {
    if (-of_ret == ENOENT && (flags & kShaDaMissingError)) {
      emsg3(_(SERR "System error while opening ShaDa file %s for reading: %s"),
            fname, os_strerror(of_ret));
    }
    xfree(fname);
    return FAIL;
  }
  xfree(fname);

  shada_read(&sd_reader, flags);
  sd_reader.close(&sd_reader);

  return OK;
}

/// Wrapper for hist_iter() function which produces ShadaEntry values
///
/// @param[in]   iter          Current iteration state.
/// @param[in]   history_type  Type of the history (HIST_*).
/// @param[in]   zero          If true, then item is removed from instance 
///                            memory upon reading.
/// @param[out]  hist          Location where iteration results should be saved.
///
/// @return Next iteration state.
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
/// @param[in,out]  hms_p           Ring buffer and associated structures.
/// @param[in]      entry           Inserted entry.
/// @param[in]      do_iter         Determines whether NeoVim own history should 
///                                 be used.
/// @param[in]      can_free_entry  True if entry can be freed.
static void hms_insert(HistoryMergerState *const hms_p, const ShadaEntry entry,
                       const bool no_iter, const bool can_free_entry)
{
  HMLList *const hmll = &hms_p->hmll;
  HMLL_FORALL(hmll, cur_entry) {
    if (STRCMP(cur_entry->data.data.history_item.string,
               entry.data.history_item.string) == 0) {
      if (entry.timestamp > cur_entry->data.timestamp) {
        hmll_remove(hmll, cur_entry);
      } else {
        return;
      }
    }
  }
  if (!no_iter) {
    if (hms_p->iter == NULL) {
      if (hms_p->last_hist_entry.type != kSDItemMissing
          && hms_p->last_hist_entry.timestamp < entry.timestamp) {
        hms_insert(hms_p, hms_p->last_hist_entry, false, hms_p->reading);
        hms_p->last_hist_entry.type = kSDItemMissing;
      }
    } else {
      while (hms_p->iter != NULL
            && hms_p->last_hist_entry.type != kSDItemMissing
            && hms_p->last_hist_entry.timestamp < entry.timestamp) {
        hms_insert(hms_p, hms_p->last_hist_entry, false, hms_p->reading);
        hms_p->iter = shada_hist_iter(hms_p->iter, hms_p->history_type,
                                      hms_p->reading,
                                      &(hms_p->last_hist_entry));
      }
    }
  }
  HMLListEntry *insert_after;
  HMLL_ITER_BACK(hmll, insert_after) {
    if (insert_after->data.timestamp <= entry.timestamp) {
      break;
    }
  }
  hmll_insert(hmll, insert_after, entry, can_free_entry);
}

/// Initialize the history merger
///
/// @param[out]  hms_p         Structure to be initialized.
/// @param[in]   history_type  History type (one of HIST_\* values).
/// @param[in]   num_elements  Number of elements in the result.
/// @param[in]   do_merge      Prepare structure for merging elements.
/// @param[in]   reading       If true, then merger is reading history for use 
///                            in NeoVim.
static inline void hms_init(HistoryMergerState *const hms_p,
                            const uint8_t history_type,
                            const size_t num_elements,
                            const bool do_merge,
                            const bool reading)
  FUNC_ATTR_NONNULL_ALL
{
  hmll_init(&hms_p->hmll, num_elements);
  hms_p->do_merge = do_merge;
  hms_p->reading = reading;
  hms_p->iter = shada_hist_iter(NULL, history_type, hms_p->reading,
                                &hms_p->last_hist_entry);
  hms_p->history_type = history_type;
}

/// Merge in all remaining NeoVim own history entries
///
/// @param[in,out]  hms_p  Merger structure into which history should be 
///                        inserted.
static inline void hms_insert_whole_neovim_history(
    HistoryMergerState *const hms_p)
  FUNC_ATTR_NONNULL_ALL
{
  if (hms_p->last_hist_entry.type != kSDItemMissing) {
    hms_insert(hms_p, hms_p->last_hist_entry, false, hms_p->reading);
  }
  while (hms_p->iter != NULL
        && hms_p->last_hist_entry.type != kSDItemMissing) {
    hms_p->iter = shada_hist_iter(hms_p->iter, hms_p->history_type,
                                  hms_p->reading,
                                  &(hms_p->last_hist_entry));
    hms_insert(hms_p, hms_p->last_hist_entry, false, hms_p->reading);
  }
}

/// Convert merger structure to NeoVim internal structure for history
///
/// @param[in]   hms_p       Converted merger structure.
/// @param[out]  hist_array  Array with the results.
/// @param[out]  new_hisidx  New last history entry index.
/// @param[out]  new_hisnum  Amount of history items in merger structure.
static inline void hms_to_he_array(const HistoryMergerState *const hms_p,
                                   histentry_T *const hist_array,
                                   int *const new_hisidx,
                                   int *const new_hisnum)
  FUNC_ATTR_NONNULL_ALL
{
  histentry_T *hist = hist_array;
  HMLL_FORALL(&hms_p->hmll, cur_entry) {
    hist->timestamp = cur_entry->data.timestamp;
    hist->hisnum = (int) (hist - hist_array) + 1;
    hist->hisstr = (char_u *) cur_entry->data.data.history_item.string;
    hist->additional_elements =
        cur_entry->data.data.history_item.additional_elements;
    hist++;
  }
  *new_hisnum = (int) (hist - hist_array);
  *new_hisidx = *new_hisnum - 1;
}

/// Free history merger structure
///
/// @param[in]  hms_p  Structure to be freed.
static inline void hms_dealloc(HistoryMergerState *const hms_p)
  FUNC_ATTR_NONNULL_ALL
{
  hmll_dealloc(&hms_p->hmll);
}

/// Iterate over all history entries in history merger, in order
///
/// @param[in]   hms_p      Merger structure to iterate over.
/// @param[out]  cur_entry  Name of the iterator variable.
///
/// @return for cycle header. Use `HMS_ITER(hms_p, cur_entry) {body}`.
#define HMS_ITER(hms_p, cur_entry) \
    HMLL_FORALL(&((hms_p)->hmll), cur_entry)

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
  list_T *oldfiles_list = get_vim_var_list(VV_OLDFILES);
  const bool force = flags & kShaDaForceit;
  const bool get_old_files = (flags & (kShaDaGetOldfiles | kShaDaForceit)
                              && (force || oldfiles_list == NULL
                                  || oldfiles_list->lv_len == 0));
  const bool want_marks = flags & kShaDaWantMarks;
  const unsigned srni_flags = ((flags & kShaDaWantInfo
                                ? (kSDReadUndisableableData
                                   | kSDReadRegisters
                                   | kSDReadGlobalMarks
                                   | (p_hi ? kSDReadHistory : 0)
                                   | (find_shada_parameter('!') != NULL
                                      ? kSDReadVariables
                                      : 0)
                                   | (find_shada_parameter('%') != NULL
                                      && ARGCOUNT == 0
                                      ? kSDReadBufferList
                                      : 0))
                                : 0)
                               | (want_marks && get_shada_parameter('\'') > 0
                                  ? kSDReadLocalMarks | kSDReadChanges
                                  : 0)
                               | (get_old_files
                                  ? kSDReadLocalMarks
                                  : 0));
  if (srni_flags == 0) {
    // Nothing to do.
    return;
  }
  HistoryMergerState hms[HIST_COUNT];
  if (srni_flags & kSDReadHistory) {
    for (uint8_t i = 0; i < HIST_COUNT; i++) {
      hms_init(&hms[i], i, (size_t) p_hi, true, true);
    }
  }
  ShadaEntry cur_entry;
  khash_t(bufset) *cl_bufs = NULL;
  if (srni_flags & kSDReadChanges) {
    cl_bufs = kh_init(bufset);
  }
  khash_t(fnamebufs) *fname_bufs = NULL;
  if (srni_flags & (kSDReadUndisableableData
                    | kSDReadChanges
                    | kSDReadLocalMarks)) {
    fname_bufs = kh_init(fnamebufs);
  }
  khash_t(strset) *oldfiles_set = NULL;
  if (get_old_files) {
    oldfiles_set = kh_init(strset);
    if (oldfiles_list == NULL) {
      oldfiles_list = list_alloc();
      set_vim_var_list(VV_OLDFILES, oldfiles_list);
    }
  }
  ShaDaReadResult srni_ret;
  while ((srni_ret = shada_read_next_item(sd_reader, &cur_entry, srni_flags, 0))
         != kSDReadStatusFinished) {
    switch (srni_ret) {
      case kSDReadStatusSuccess: {
        break;
      }
      case kSDReadStatusFinished: {
        // Should be handled by the while condition.
        assert(false);
      }
      case kSDReadStatusNotShaDa:
      case kSDReadStatusReadError: {
        goto shada_read_main_cycle_end;
      }
      case kSDReadStatusMalformed: {
        continue;
      }
    }
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
        if (!force) {
          SearchPattern pat;
          (cur_entry.data.search_pattern.is_substitute_pattern
           ? &get_substitute_pattern
           : &get_search_pattern)(&pat);
          if (pat.pat != NULL && pat.timestamp >= cur_entry.timestamp) {
            shada_free_shada_entry(&cur_entry);
            break;
          }
        }
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
        if (!cur_entry.data.search_pattern.is_substitute_pattern) {
          SET_NO_HLSEARCH(!cur_entry.data.search_pattern.highlighted);
        }
        // Do not free shada entry: its allocated memory was saved above.
        break;
      }
      case kSDItemSubString: {
        if (!force) {
          SubReplacementString sub;
          sub_get_replacement(&sub);
          if (sub.sub != NULL && sub.timestamp >= cur_entry.timestamp) {
            shada_free_shada_entry(&cur_entry);
            break;
          }
        }
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
        hms_insert(hms + cur_entry.data.history_item.histtype, cur_entry, true,
                   true);
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
        if (!register_set(cur_entry.data.reg.name, (yankreg_T) {
          .y_array = (char_u **) cur_entry.data.reg.contents,
          .y_size = (linenr_T) cur_entry.data.reg.contents_size,
          .y_type = cur_entry.data.reg.type,
          .y_width = (colnr_T) cur_entry.data.reg.width,
          .timestamp = cur_entry.timestamp,
          .additional_data = cur_entry.data.reg.additional_data,
        })) {
          shada_free_shada_entry(&cur_entry);
        }
        // Do not free shada entry: its allocated memory was saved above.
        break;
      }
      case kSDItemVariable: {
        var_set_global(cur_entry.data.global_var.name,
                       cur_entry.data.global_var.value);
        cur_entry.data.global_var.value.v_type = VAR_UNKNOWN;
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
          if (!mark_set_global(cur_entry.data.filemark.name, fm, !force)) {
            shada_free_shada_entry(&cur_entry);
            break;
          }
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
            buf->additional_data =
                cur_entry.data.buffer_list.buffers[i].additional_data;
            cur_entry.data.buffer_list.buffers[i].additional_data = NULL;
          }
        }
        shada_free_shada_entry(&cur_entry);
        break;
      }
      case kSDItemChange:
      case kSDItemLocalMark: {
        if (oldfiles_set != NULL
            && !in_strset(oldfiles_set, cur_entry.data.filemark.fname)) {
          char *fname = cur_entry.data.filemark.fname;
          if (want_marks) {
            // Do not bother with allocating memory for the string if already 
            // allocated string from cur_entry can be used. It cannot be used if 
            // want_marks is set because this way it may be used for a mark.
            fname = xstrdup(fname);
          }
          int kh_ret;
          (void) kh_put(strset, oldfiles_set, fname, &kh_ret);
          list_append_allocated_string(oldfiles_list, fname);
          if (!want_marks) {
            // Avoid free because this string was already used.
            cur_entry.data.filemark.fname = NULL;
          }
        }
        if (!want_marks) {
          shada_free_shada_entry(&cur_entry);
          break;
        }
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
          if (!mark_set_local(cur_entry.data.filemark.name, buf, fm, !force)) {
            shada_free_shada_entry(&cur_entry);
            break;
          }
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
shada_read_main_cycle_end:
  // Warning: shada_hist_iter returns ShadaEntry elements which use strings from 
  //          original history list. This means that once such entry is removed 
  //          from the history NeoVim array will no longer be valid. To reduce 
  //          amount of memory allocations ShaDa file reader allocates enough 
  //          memory for the history string itself and separator character which 
  //          may be assigned right away.
  if (srni_flags & kSDReadHistory) {
    for (uint8_t i = 0; i < HIST_COUNT; i++) {
      hms_insert_whole_neovim_history(&hms[i]);
      clr_history(i);
      int *new_hisidx;
      int *new_hisnum;
      histentry_T *hist = hist_get_array(i, &new_hisidx, &new_hisnum);
      if (hist != NULL) {
        hms_to_he_array(&hms[i], hist, new_hisidx, new_hisnum);
      }
      hms_dealloc(&hms[i]);
    }
  }
  if (cl_bufs != NULL) {
    FOR_ALL_TAB_WINDOWS(tp, wp) {
      (void) tp;
      if (in_bufset(cl_bufs, wp->w_buffer)) {
        wp->w_changelistidx = wp->w_buffer->b_changelistlen;
      }
    }
    kh_destroy(bufset, cl_bufs);
  }
  if (fname_bufs != NULL) {
    const char *key;
    kh_foreach_key(fname_bufs, key, {
      xfree((void *) key);
    })
    kh_destroy(fnamebufs, fname_bufs);
  }
  if (oldfiles_set != NULL) {
    kh_destroy(strset, oldfiles_set);
  }
}

/// Get the ShaDa file name to use
///
/// If "file" is given and not empty, use it (has already been expanded by 
/// cmdline functions). Otherwise use "-i file_name", value from 'shada' or the 
/// default, and expand environment variables.
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
    } else if ((file = find_shada_parameter('n')) == NULL || *file == NUL) {
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
static bool shada_pack_entry(msgpack_packer *const packer,
                             ShadaEntry entry,
                             const size_t max_kbyte)
  FUNC_ATTR_NONNULL_ALL
{
  msgpack_sbuffer sbuf;
  msgpack_sbuffer_init(&sbuf);
  msgpack_packer *spacker = msgpack_packer_new(&sbuf, &msgpack_sbuffer_write);
#define DUMP_ADDITIONAL_ELEMENTS(src) \
  do { \
    if ((src) != NULL) { \
      for (listitem_T *li = (src)->lv_first; li != NULL; li = li->li_next) { \
        if (vim_to_msgpack(spacker, &li->li_tv) == FAIL) { \
          return false; \
        } \
      } \
    } \
  } while (0)
#define DUMP_ADDITIONAL_DATA(src) \
  do { \
    dict_T *const d = (src); \
    if (d != NULL) { \
      size_t todo = d->dv_hashtab.ht_used; \
      for (const hashitem_T *hi= d->dv_hashtab.ht_array; todo; hi++) { \
        if (!HASHITEM_EMPTY(hi)) { \
          todo--; \
          dictitem_T *const di = HI2DI(hi); \
          const size_t key_len = strlen((const char *) hi->hi_key); \
          msgpack_pack_str(spacker, key_len); \
          msgpack_pack_str_body(spacker, (const char *) hi->hi_key, key_len); \
          if (vim_to_msgpack(spacker, &di->di_tv) == FAIL) { \
            return false; \
          } \
        } \
      } \
    } \
  } while (0)
  switch (entry.type) {
    case kSDItemMissing: {
      assert(false);
    }
    case kSDItemUnknown: {
      if ((msgpack_pack_uint64(packer, (uint64_t) entry.data.unknown_item.size)
           == -1)
          || (packer->callback(packer->data, entry.data.unknown_item.contents,
                               (unsigned) entry.data.unknown_item.size)
              == -1)) {
        return false;
      }
      break;
    }
    case kSDItemHistoryEntry: {
      const bool is_hist_search =
          entry.data.history_item.histtype == HIST_SEARCH;
      const size_t arr_size = 2 + (size_t) is_hist_search + (size_t) (
          entry.data.history_item.additional_elements == NULL
          ? 0
          : entry.data.history_item.additional_elements->lv_len);
      msgpack_pack_array(spacker, arr_size);
      msgpack_pack_uint8(spacker, entry.data.history_item.histtype);
      msgpack_rpc_from_string(cstr_as_string(entry.data.history_item.string),
                              spacker);
      if (is_hist_search) {
        msgpack_pack_uint8(spacker, (uint8_t) entry.data.history_item.sep);
      }
      DUMP_ADDITIONAL_ELEMENTS(entry.data.history_item.additional_elements);
      break;
    }
    case kSDItemVariable: {
      const size_t arr_size = 2 + (size_t) (
          entry.data.global_var.additional_elements == NULL
          ? 0
          : entry.data.global_var.additional_elements->lv_len);
      msgpack_pack_array(spacker, arr_size);
      msgpack_rpc_from_string(cstr_as_string(entry.data.global_var.name),
                              spacker);
      if (vim_to_msgpack(spacker, &entry.data.global_var.value) == FAIL) {
        return false;
      }
      DUMP_ADDITIONAL_ELEMENTS(entry.data.global_var.additional_elements);
      break;
    }
    case kSDItemSubString: {
      const size_t arr_size = 1 + (size_t) (
          entry.data.sub_string.additional_elements == NULL
          ? 0
          : entry.data.sub_string.additional_elements->lv_len);
      msgpack_pack_array(spacker, arr_size);
      msgpack_rpc_from_string(cstr_as_string(entry.data.sub_string.sub),
                              spacker);
      DUMP_ADDITIONAL_ELEMENTS(entry.data.sub_string.additional_elements);
      break;
    }
    case kSDItemSearchPattern: {
      const size_t map_size = (size_t) (
          1 // Search pattern is always present
          // Following items default to true:
          + (size_t) !entry.data.search_pattern.magic
          + (size_t) !entry.data.search_pattern.is_last_used
          // Following items default to false:
          + (size_t) entry.data.search_pattern.smartcase
          + (size_t) entry.data.search_pattern.has_line_offset
          + (size_t) entry.data.search_pattern.place_cursor_at_end
          + (size_t) entry.data.search_pattern.is_substitute_pattern
          + (size_t) entry.data.search_pattern.highlighted
          // offset defaults to zero:
          + (size_t) (entry.data.search_pattern.offset != 0)
          // finally, additional data:
          + (size_t) (
              entry.data.search_pattern.additional_data
              ? entry.data.search_pattern.additional_data->dv_hashtab.ht_used
              : 0)
      );
      msgpack_pack_map(spacker, map_size);
      PACK_STATIC_STR(SEARCH_KEY_PAT);
      msgpack_rpc_from_string(cstr_as_string(entry.data.search_pattern.pat),
                              spacker);
#define PACK_BOOL(name, attr, nondef_value) \
      do { \
        if (entry.data.search_pattern.attr == nondef_value) { \
          PACK_STATIC_STR(name); \
          msgpack_pack_##nondef_value(spacker); \
        } \
      } while (0)
      PACK_BOOL(SEARCH_KEY_MAGIC, magic, false);
      PACK_BOOL(SEARCH_KEY_IS_LAST_USED, is_last_used, false);
      PACK_BOOL(SEARCH_KEY_SMARTCASE, smartcase, true);
      PACK_BOOL(SEARCH_KEY_HAS_LINE_OFFSET, has_line_offset, true);
      PACK_BOOL(SEARCH_KEY_PLACE_CURSOR_AT_END, place_cursor_at_end, true);
      PACK_BOOL(SEARCH_KEY_IS_SUBSTITUTE_PATTERN, is_substitute_pattern, true);
      PACK_BOOL(SEARCH_KEY_HIGHLIGHTED, highlighted, true);
      if (entry.data.search_pattern.offset) {
        PACK_STATIC_STR(SEARCH_KEY_OFFSET);
        msgpack_pack_int64(spacker, entry.data.search_pattern.offset);
      }
#undef PACK_BOOL
      DUMP_ADDITIONAL_DATA(entry.data.search_pattern.additional_data);
      break;
    }
    case kSDItemChange:
    case kSDItemGlobalMark:
    case kSDItemLocalMark:
    case kSDItemJump: {
      const size_t map_size = (size_t) (
          1  // File name
          // Line: defaults to 1
          + (size_t) (entry.data.filemark.mark.lnum != 1)
          // Column: defaults to zero:
          + (size_t) (entry.data.filemark.mark.col != 0)
          // Mark name: defaults to '"'
          + (size_t) (entry.type != kSDItemJump
                      && entry.type != kSDItemChange
                      && entry.data.filemark.name != '"')
          // Additional entries, if any:
          + (size_t) (
              entry.data.filemark.additional_data == NULL
              ? 0
              : entry.data.filemark.additional_data->dv_hashtab.ht_used)
      );
      msgpack_pack_map(spacker, map_size);
      PACK_STATIC_STR(KEY_FILE);
      msgpack_rpc_from_string(cstr_as_string(entry.data.filemark.fname),
                              spacker);
      if (entry.data.filemark.mark.lnum != 1) {
        PACK_STATIC_STR(KEY_LNUM);
        msgpack_pack_long(spacker, entry.data.filemark.mark.lnum);
      }
      if (entry.data.filemark.mark.col != 0) {
        PACK_STATIC_STR(KEY_COL);
        msgpack_pack_long(spacker, entry.data.filemark.mark.col);
      }
      if (entry.data.filemark.name != '"' && entry.type != kSDItemJump
          && entry.type != kSDItemChange) {
        PACK_STATIC_STR(KEY_NAME_CHAR);
        msgpack_pack_uint8(spacker, (uint8_t) entry.data.filemark.name);
      }
      DUMP_ADDITIONAL_DATA(entry.data.filemark.additional_data);
      break;
    }
    case kSDItemRegister: {
      const size_t map_size = (size_t) (
          2  // Register contents and name
          // Register type: defaults to MCHAR
          + (size_t) (entry.data.reg.type != MCHAR)
          // Register width: defaults to zero
          + (size_t) (entry.data.reg.width != 0)
          // Additional entries, if any:
          + (size_t) (entry.data.reg.additional_data == NULL
                      ? 0
                      : entry.data.reg.additional_data->dv_hashtab.ht_used)
      );
      msgpack_pack_map(spacker, map_size);
      PACK_STATIC_STR(REG_KEY_CONTENTS);
      msgpack_pack_array(spacker, entry.data.reg.contents_size);
      for (size_t i = 0; i < entry.data.reg.contents_size; i++) {
        msgpack_rpc_from_string(cstr_as_string(entry.data.reg.contents[i]),
                                spacker);
      }
      PACK_STATIC_STR(KEY_NAME_CHAR);
      msgpack_pack_char(spacker, entry.data.reg.name);
      if (entry.data.reg.type != MCHAR) {
        PACK_STATIC_STR(REG_KEY_TYPE);
        msgpack_pack_uint8(spacker, entry.data.reg.type);
      }
      if (entry.data.reg.width != 0) {
        PACK_STATIC_STR(REG_KEY_WIDTH);
        msgpack_pack_uint64(spacker, (uint64_t) entry.data.reg.width);
      }
      DUMP_ADDITIONAL_DATA(entry.data.reg.additional_data);
      break;
    }
    case kSDItemBufferList: {
      msgpack_pack_array(spacker, entry.data.buffer_list.size);
      for (size_t i = 0; i < entry.data.buffer_list.size; i++) {
        const size_t map_size = (size_t) (
            1  // Buffer name
            // Line number: defaults to 1
            + (size_t) (entry.data.buffer_list.buffers[i].pos.lnum != 1)
            // Column number: defaults to 0
            + (size_t) (entry.data.buffer_list.buffers[i].pos.col != 0)
            // Additional entries, if any:
            + (size_t) (
                entry.data.buffer_list.buffers[i].additional_data == NULL
                ? 0
                : (entry.data.buffer_list.buffers[i].additional_data
                   ->dv_hashtab.ht_used))
        );
        msgpack_pack_map(spacker, map_size);
        PACK_STATIC_STR(KEY_FILE);
        msgpack_rpc_from_string(
            cstr_as_string(entry.data.buffer_list.buffers[i].fname), spacker);
        if (entry.data.buffer_list.buffers[i].pos.lnum != 1) {
          PACK_STATIC_STR(KEY_LNUM);
          msgpack_pack_uint64(
              spacker, (uint64_t) entry.data.buffer_list.buffers[i].pos.lnum);
        }
        if (entry.data.buffer_list.buffers[i].pos.col != 0) {
          PACK_STATIC_STR(KEY_COL);
          msgpack_pack_uint64(
              spacker, (uint64_t) entry.data.buffer_list.buffers[i].pos.col);
        }
        DUMP_ADDITIONAL_DATA(entry.data.buffer_list.buffers[i].additional_data);
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
      if (msgpack_pack_uint64(packer, (uint64_t) entry.data.unknown_item.type)
          == -1) {
        return false;
      }
    } else {
      if (msgpack_pack_uint64(packer, (uint64_t) entry.type) == -1) {
        return false;
      }
    }
    if (msgpack_pack_uint64(packer, (uint64_t) entry.timestamp) == -1) {
      return false;
    }
    if (sbuf.size > 0) {
      if ((msgpack_pack_uint64(packer, (uint64_t) sbuf.size) == -1)
          || (packer->callback(packer->data, sbuf.data,
                               (unsigned) sbuf.size) == -1)) {
        return false;
      }
    }
  }
  msgpack_packer_free(spacker);
  msgpack_sbuffer_destroy(&sbuf);
  return true;
}

/// Write single ShaDa entry, converting it if needed
///
/// @warning Frees entry after packing.
///
/// @param[in]  packer     Packer used to write entry.
/// @param[in]  sd_conv    Conversion definitions.
/// @param[in]  entry      Entry written. If entry.can_free_entry is false then 
///                        it assumes that entry was not converted, otherwise it 
///                        is assumed that entry was already converted.
/// @param[in]  max_kbyte  Maximum size of an item in KiB. Zero means no 
///                        restrictions.
static bool shada_pack_encoded_entry(msgpack_packer *const packer,
                                     const vimconv_T *const sd_conv,
                                     PossiblyFreedShadaEntry entry,
                                     const size_t max_kbyte)
  FUNC_ATTR_NONNULL_ALL
{
  bool ret = true;
  if (entry.can_free_entry) {
    ret = shada_pack_entry(packer, entry.data, max_kbyte);
    shada_free_shada_entry(&entry.data);
    return ret;
  }
#define RUN_WITH_CONVERTED_STRING(cstr, code) \
  do { \
    bool did_convert = false; \
    if (sd_conv->vc_type != CONV_NONE && has_non_ascii((cstr))) { \
      char *const converted_string = string_convert(sd_conv, (cstr), NULL); \
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
  switch (entry.data.type) {
    case kSDItemUnknown:
    case kSDItemMissing: {
      assert(false);
    }
    case kSDItemSearchPattern: {
      RUN_WITH_CONVERTED_STRING(entry.data.data.search_pattern.pat, {
        ret = shada_pack_entry(packer, entry.data, max_kbyte);
      });
      break;
    }
    case kSDItemHistoryEntry: {
      RUN_WITH_CONVERTED_STRING(entry.data.data.history_item.string, {
        ret = shada_pack_entry(packer, entry.data, max_kbyte);
      });
      break;
    }
    case kSDItemSubString: {
      RUN_WITH_CONVERTED_STRING(entry.data.data.sub_string.sub, {
        ret = shada_pack_entry(packer, entry.data, max_kbyte);
      });
      break;
    }
    case kSDItemVariable: {
      if (sd_conv->vc_type != CONV_NONE) {
        typval_T tgttv;
        var_item_copy(sd_conv, &entry.data.data.global_var.value, &tgttv,
                      true, 0);
        clear_tv(&entry.data.data.global_var.value);
        entry.data.data.global_var.value = tgttv;
      }
      ret = shada_pack_entry(packer, entry.data, max_kbyte);
      break;
    }
    case kSDItemRegister: {
      bool did_convert = false;
      if (sd_conv->vc_type != CONV_NONE) {
        size_t first_non_ascii = 0;
        for (size_t i = 0; i < entry.data.data.reg.contents_size; i++) {
          if (has_non_ascii(entry.data.data.reg.contents[i])) {
            first_non_ascii = i;
            did_convert = true;
            break;
          }
        }
        if (did_convert) {
          entry.data.data.reg.contents =
              xmemdup(entry.data.data.reg.contents,
                      (entry.data.data.reg.contents_size
                       * sizeof(entry.data.data.reg.contents)));
          for (size_t i = 0; i < entry.data.data.reg.contents_size; i++) {
            if (i >= first_non_ascii) {
              entry.data.data.reg.contents[i] = get_converted_string(
                  sd_conv,
                  entry.data.data.reg.contents[i],
                  strlen(entry.data.data.reg.contents[i]));
            } else {
              entry.data.data.reg.contents[i] =
                  xstrdup(entry.data.data.reg.contents[i]);
            }
          }
        }
      }
      ret = shada_pack_entry(packer, entry.data, max_kbyte);
      if (did_convert) {
        for (size_t i = 0; i < entry.data.data.reg.contents_size; i++) {
          xfree(entry.data.data.reg.contents[i]);
        }
        xfree(entry.data.data.reg.contents);
      }
      break;
    }
    case kSDItemHeader:
    case kSDItemGlobalMark:
    case kSDItemJump:
    case kSDItemBufferList:
    case kSDItemLocalMark:
    case kSDItemChange: {
      ret = shada_pack_entry(packer, entry.data, max_kbyte);
      break;
    }
  }
#undef RUN_WITH_CONVERTED_STRING
  return ret;
}

/// Compare two FileMarks structure to order them by greatest_timestamp
///
/// Order is reversed: structure with greatest greatest_timestamp comes first. 
/// Function signature is compatible with qsort.
static int compare_file_marks(const void *a, const void *b)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  const FileMarks *const *const a_fms = a;
  const FileMarks *const *const b_fms = b;
  return ((*a_fms)->greatest_timestamp == (*b_fms)->greatest_timestamp
          ? 0
          : ((*a_fms)->greatest_timestamp > (*b_fms)->greatest_timestamp
             ? -1
             : 1));
}

/// Write ShaDa file
///
/// @param[in]  sd_writer  Structure containing file writer definition.
/// @param[in]  sd_reader  Structure containing file reader definition. If it is 
///                        not NULL then contents of this file will be merged 
///                        with current NeoVim runtime.
static ShaDaWriteResult shada_write(ShaDaWriteDef *const sd_writer,
                                    ShaDaReadDef *const sd_reader)
  FUNC_ATTR_NONNULL_ARG(1)
{
  ShaDaWriteResult ret = kSDWriteSuccessfull;
  int max_kbyte_i = get_shada_parameter('s');
  if (max_kbyte_i < 0) {
    max_kbyte_i = 10;
  }
  if (max_kbyte_i == 0) {
    return ret;
  }

  WriteMergerState *const wms = xcalloc(1, sizeof(*wms));
  bool dump_one_history[HIST_COUNT];
  const bool dump_global_vars = (find_shada_parameter('!') != NULL);
  int max_reg_lines = get_shada_parameter('<');
  if (max_reg_lines < 0) {
    max_reg_lines = get_shada_parameter('"');
  }
  const bool limit_reg_lines = max_reg_lines >= 0;
  const bool dump_registers = (max_reg_lines != 0);
  khash_t(bufset) *const removable_bufs = kh_init(bufset);
  const size_t max_kbyte = (size_t) max_kbyte_i;
  const size_t num_marked_files = (size_t) get_shada_parameter('\'');
  const bool dump_global_marks = get_shada_parameter('f') != 0;
  bool dump_history = false;

  // Initialize history merger
  for (uint8_t i = 0; i < HIST_COUNT; i++) {
    long num_saved = get_shada_parameter(hist_type2char(i));
    if (num_saved == -1) {
      num_saved = p_hi;
    }
    if (num_saved > 0) {
      dump_history = true;
      dump_one_history[i] = true;
      hms_init(&wms->hms[i], i, (size_t) num_saved, sd_reader != NULL, false);
    } else {
      dump_one_history[i] = false;
    }
  }

  const unsigned srni_flags = (
    kSDReadUndisableableData
    | kSDReadUnknown
    | (dump_history ? kSDReadHistory : 0)
    | (dump_registers ? kSDReadRegisters : 0)
    | (dump_global_vars ? kSDReadVariables : 0)
    | (dump_global_marks ? kSDReadGlobalMarks : 0)
    | (num_marked_files ? kSDReadLocalMarks | kSDReadChanges : 0)
  );

  msgpack_packer *const packer = msgpack_packer_new(sd_writer,
                                                    &msgpack_sd_writer_write);

  FOR_ALL_BUFFERS(buf) {
    if (buf->b_ffname != NULL && shada_removable((char *) buf->b_ffname)) {
      int kh_ret;
      (void) kh_put(bufset, removable_bufs, (uintptr_t) buf, &kh_ret);
    }
  }

  // Write header
  if (!shada_pack_entry(packer, (ShadaEntry) {
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
  }, 0)) {
    ret = kSDWriteFailed;
    goto shada_write_exit;
  }

  // Write buffer list
  if (find_shada_parameter('%') != NULL) {
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
    if (!shada_pack_entry(packer, buflist_entry, 0)) {
      xfree(buflist_entry.data.buffer_list.buffers);
      ret = kSDWriteFailed;
      goto shada_write_exit;
    }
    xfree(buflist_entry.data.buffer_list.buffers);
  }

  // Write some of the variables
  if (dump_global_vars) {
    const void *var_iter = NULL;
    const Timestamp cur_timestamp = os_time();
    do {
      typval_T vartv;
      const char *name;
      var_iter = var_shada_iter(var_iter, &name, &vartv);
      if (var_iter == NULL && vartv.v_type == VAR_UNKNOWN) {
        break;
      }
      typval_T tgttv;
      if (sd_writer->sd_conv.vc_type != CONV_NONE) {
        var_item_copy(&sd_writer->sd_conv, &vartv, &tgttv, true, 0);
      } else {
        copy_tv(&vartv, &tgttv);
      }
      if (!shada_pack_entry(packer, (ShadaEntry) {
        .type = kSDItemVariable,
        .timestamp = cur_timestamp,
        .data = {
          .global_var = {
            .name = (char *) name,
            .value = tgttv,
            .additional_elements = NULL,
          }
        }
      }, max_kbyte)) {
        clear_tv(&vartv);
        clear_tv(&tgttv);
        ret = kSDWriteFailed;
        goto shada_write_exit;
      }
      clear_tv(&vartv);
      clear_tv(&tgttv);
      int kh_ret;
      (void) kh_put(strset, &wms->dumped_variables, name, &kh_ret);
    } while (var_iter != NULL);
  }

  // Initialize search pattern
  {
    SearchPattern pat;
    get_search_pattern(&pat);
    wms->search_pattern = (PossiblyFreedShadaEntry) {
      .can_free_entry = false,
      .data = {
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
            .highlighted = (!no_hlsearch && find_shada_parameter('h') != NULL),
            .pat = (char *) pat.pat,
            .additional_data = pat.additional_data,
          }
        }
      }
    };
  }

  // Initialize substitute search pattern
  {
    SearchPattern pat;
    get_substitute_pattern(&pat);
    wms->sub_search_pattern = (PossiblyFreedShadaEntry) {
      .can_free_entry = false,
      .data = {
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
            .highlighted = false,
            .pat = (char *) pat.pat,
            .additional_data = pat.additional_data,
          }
        }
      }
    };
  }

  // Initialize substitute replacement string
  {
    SubReplacementString sub;
    sub_get_replacement(&sub);
    wms->replacement = (PossiblyFreedShadaEntry) {
      .can_free_entry = false,
      .data = {
        .type = kSDItemSubString,
        .timestamp = sub.timestamp,
        .data = {
          .sub_string = {
            .sub = (char *) sub.sub,
            .additional_elements = sub.additional_elements,
          }
        }
      }
    };
  }

  // Initialize jump list
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
    if (fname == NULL) {
      continue;
    }
    wms->jumps[wms->jumps_size++] = (PossiblyFreedShadaEntry) {
      .can_free_entry = false,
      .data = {
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
      }
    };
  } while (jump_iter != NULL);

  // Initialize global marks
  if (dump_global_marks) {
    const void *global_mark_iter = NULL;
    do {
      char name;
      xfmark_T fm;
      global_mark_iter = mark_global_iter(global_mark_iter, &name, &fm);
      if (fm.fmark.mark.lnum == 0) {
        break;
      }
      const char *fname;
      if (fm.fmark.fnum == 0) {
        assert(fm.fname != NULL);
        if (shada_removable((const char *) fm.fname)) {
          continue;
        }
        fname = (const char *) fm.fname;
      } else {
        const buf_T *const buf = buflist_findnr(fm.fmark.fnum);
        if (buf == NULL || buf->b_ffname == NULL || SHADA_REMOVABLE(buf)) {
          continue;
        }
        fname = (const char *) buf->b_ffname;
      }
      wms->global_marks[mark_global_index(name)] = (PossiblyFreedShadaEntry) {
        .can_free_entry = false,
        .data = {
          .type = kSDItemGlobalMark,
          .timestamp = fm.fmark.timestamp,
          .data = {
            .filemark = {
              .mark = fm.fmark.mark,
              .name = name,
              .additional_data = fm.fmark.additional_data,
              .fname = (char *) fname,
            }
          }
        },
      };
    } while(global_mark_iter != NULL);
  }

  // Initialize registers
  if (dump_registers) {
    const void *reg_iter = NULL;
    do {
      yankreg_T reg;
      char name;
      reg_iter = op_register_iter(reg_iter, &name, &reg);
      if (reg.y_array == NULL) {
        break;
      }
      if (limit_reg_lines && reg.y_size > max_reg_lines) {
        continue;
      }
      wms->registers[op_reg_index(name)] = (PossiblyFreedShadaEntry) {
        .can_free_entry = false,
        .data = {
          .type = kSDItemRegister,
          .timestamp = reg.timestamp,
          .data = {
            .reg = {
              .contents = (char **) reg.y_array,
              .contents_size = (size_t) reg.y_size,
              .type = (uint8_t) reg.y_type,
              .width = (size_t) (reg.y_type == MBLOCK ? reg.y_width : 0),
              .additional_data = reg.additional_data,
              .name = name,
            }
          }
        }
      };
    } while(reg_iter != NULL);
  }

  // Initialize buffers
  if (num_marked_files > 0) {
    FOR_ALL_BUFFERS(buf) {
      if (buf->b_ffname == NULL || SHADA_REMOVABLE(buf)) {
        continue;
      }
      const void *local_marks_iter = NULL;
      const char *const fname = (const char *) buf->b_ffname;
      khiter_t k;
      int kh_ret;
      k = kh_put(file_marks, &wms->file_marks, fname, &kh_ret);
      FileMarks *const filemarks = &kh_val(&wms->file_marks, k);
      if (kh_ret > 0) {
        kh_key(&wms->file_marks, k) = xstrdup(fname);
        memset(filemarks, 0, sizeof(*filemarks));
      }
      filemarks->is_local_entry = true;
      do {
        fmark_T fm;
        char name;
        local_marks_iter = mark_buffer_iter(local_marks_iter, buf, &name, &fm);
        if (fm.mark.lnum == 0) {
          break;
        }
        filemarks->marks[mark_local_index(name)] = (PossiblyFreedShadaEntry) {
          .can_free_entry = false,
          .data = {
            .type = kSDItemLocalMark,
            .timestamp = fm.timestamp,
            .data = {
              .filemark = {
                .mark = fm.mark,
                .name = name,
                .fname = (char *) fname,
                .additional_data = fm.additional_data,
              }
            }
          }
        };
        if (fm.timestamp > filemarks->greatest_timestamp) {
          filemarks->greatest_timestamp = fm.timestamp;
        }
      } while(local_marks_iter != NULL);
      for (int i = 0; i < buf->b_changelistlen; i++) {
        const fmark_T fm = buf->b_changelist[i];
        filemarks->changes[i] = (PossiblyFreedShadaEntry) {
          .can_free_entry = false,
          .data = {
            .type = kSDItemChange,
            .timestamp = fm.timestamp,
            .data = {
              .filemark = {
                .mark = fm.mark,
                .fname = (char *) fname,
                .additional_data = fm.additional_data,
              }
            }
          }
        };
        if (fm.timestamp > filemarks->greatest_timestamp) {
          filemarks->greatest_timestamp = fm.timestamp;
        }
      }
      filemarks->changes_size = (size_t) buf->b_changelistlen;
    }
  }

  if (sd_reader == NULL) {
    goto shada_write_main_cycle_end;
  }

  ShadaEntry entry;
  ShaDaReadResult srni_ret;
  while ((srni_ret = shada_read_next_item(sd_reader, &entry, srni_flags,
                                          max_kbyte))
         != kSDReadStatusFinished) {
    switch (srni_ret) {
      case kSDReadStatusSuccess: {
        break;
      }
      case kSDReadStatusFinished: {
        // Should be handled by the while condition.
        assert(false);
      }
      case kSDReadStatusNotShaDa: {
        ret = kSDWriteReadNotShada;
        // fallthrough
      }
      case kSDReadStatusReadError: {
        goto shada_write_main_cycle_end;
      }
      case kSDReadStatusMalformed: {
        continue;
      }
    }
#define COMPARE_WITH_ENTRY(wms_entry_, entry) \
    do { \
      PossiblyFreedShadaEntry *const wms_entry = (wms_entry_); \
      if (wms_entry->data.type != kSDItemMissing) { \
        if (wms_entry->data.timestamp >= (entry).timestamp) { \
          shada_free_shada_entry(&(entry)); \
          break; \
        } \
        if (wms_entry->can_free_entry) { \
          shada_free_shada_entry(&wms_entry->data); \
        } \
      } \
      wms_entry->can_free_entry = true; \
      wms_entry->data = (entry); \
    } while (0)
    switch (entry.type) {
      case kSDItemMissing: {
        break;
      }
      case kSDItemHeader:
      case kSDItemBufferList: {
        assert(false);
      }
      case kSDItemUnknown: {
        if (!shada_pack_entry(packer, entry, 0)) {
          ret = kSDWriteFailed;
        }
        shada_free_shada_entry(&entry);
        break;
      }
      case kSDItemSearchPattern: {
        COMPARE_WITH_ENTRY((entry.data.search_pattern.is_substitute_pattern
                            ? &wms->sub_search_pattern
                            : &wms->search_pattern), entry);
        break;
      }
      case kSDItemSubString: {
        COMPARE_WITH_ENTRY(&wms->replacement, entry);
        break;
      }
      case kSDItemHistoryEntry: {
        if (entry.data.history_item.histtype >= HIST_COUNT) {
          if (!shada_pack_entry(packer, entry, 0)) {
            ret = kSDWriteFailed;
          }
          shada_free_shada_entry(&entry);
          break;
        }
        hms_insert(&wms->hms[entry.data.history_item.histtype], entry, true,
                   true);
        break;
      }
      case kSDItemRegister: {
        const int idx = op_reg_index(entry.data.reg.name);
        if (idx < 0) {
          if (!shada_pack_entry(packer, entry, 0)) {
            ret = kSDWriteFailed;
          }
          shada_free_shada_entry(&entry);
          break;
        }
        COMPARE_WITH_ENTRY(&wms->registers[idx], entry);
        break;
      }
      case kSDItemVariable: {
        if (!in_strset(&wms->dumped_variables, entry.data.global_var.name)) {
          if (!shada_pack_entry(packer, entry, 0)) {
            ret = kSDWriteFailed;
          }
        }
        shada_free_shada_entry(&entry);
        break;
      }
      case kSDItemGlobalMark: {
        const int idx = mark_global_index(entry.data.filemark.name);
        if (idx < 0) {
          if (!shada_pack_entry(packer, entry, 0)) {
            ret = kSDWriteFailed;
          }
          shada_free_shada_entry(&entry);
          break;
        }
        COMPARE_WITH_ENTRY(&wms->global_marks[idx], entry);
        break;
      }
      case kSDItemChange:
      case kSDItemLocalMark: {
        if (shada_removable(entry.data.filemark.fname)) {
          shada_free_shada_entry(&entry);
          break;
        }
        const char *const fname = (const char *) entry.data.filemark.fname;
        khiter_t k;
        int kh_ret;
        k = kh_put(file_marks, &wms->file_marks, fname, &kh_ret);
        FileMarks *const filemarks = &kh_val(&wms->file_marks, k);
        if (kh_ret > 0) {
          kh_key(&wms->file_marks, k) = xstrdup(fname);
          memset(filemarks, 0, sizeof(*filemarks));
        }
        if (entry.timestamp > filemarks->greatest_timestamp) {
          filemarks->greatest_timestamp = entry.timestamp;
        }
        if (entry.type == kSDItemLocalMark) {
          const int idx = mark_local_index(entry.data.filemark.name);
          if (idx < 0) {
            filemarks->additional_marks = xrealloc(
                filemarks->additional_marks,
                (++filemarks->additional_marks_size
                 * sizeof(filemarks->additional_marks[0])));
            filemarks->additional_marks[filemarks->additional_marks_size - 1] =
                entry;
          } else {
            COMPARE_WITH_ENTRY(&filemarks->marks[idx], entry);
          }
        } else {
          if (filemarks->is_local_entry) {
            shada_free_shada_entry(&entry);
          } else {
            const int cl_len = (int) filemarks->changes_size;
            int i;
            for (i = cl_len; i > 0; i--) {
              const ShadaEntry old_entry = filemarks->changes[i - 1].data;
              if (old_entry.timestamp <= entry.timestamp) {
                if (marks_equal(old_entry.data.filemark.mark,
                                entry.data.filemark.mark)) {
                  i = -1;
                }
                break;
              }
            }
            if (i > 0) {
              if (cl_len == JUMPLISTSIZE) {
                if (filemarks->changes[0].can_free_entry) {
                  shada_free_shada_entry(&filemarks->changes[0].data);
                }
                memmove(&filemarks->changes[0], &filemarks->changes[1],
                        sizeof(filemarks->changes[0]) * (size_t) i);
              } else if (i == 0) {
                if (cl_len == JUMPLISTSIZE) {
                  i = -1;
                } else {
                  memmove(&filemarks->changes[1], &filemarks->changes[0],
                          sizeof(filemarks->changes[0]) * (size_t) cl_len);
                }
              }
            }
            if (i != -1) {
              filemarks->changes[i] = (PossiblyFreedShadaEntry) {
                .can_free_entry = true,
                .data = entry
              };
              if (cl_len < JUMPLISTSIZE) {
                filemarks->changes_size++;
              }
            } else {
              shada_free_shada_entry(&entry);
            }
          }
        }
        break;
      }
      case kSDItemJump: {
        const int jl_len = (int) wms->jumps_size;
        int i;
        for (i = 0; i < jl_len; i++) {
          const ShadaEntry old_entry = wms->jumps[i].data;
          if (old_entry.timestamp >= entry.timestamp) {
            if (marks_equal(old_entry.data.filemark.mark,
                            entry.data.filemark.mark)
                && strcmp(old_entry.data.filemark.fname,
                          entry.data.filemark.fname) == 0) {
              i = -1;
            }
            break;
          }
        }
        if (i != -1) {
          if (i < jl_len) {
            if (jl_len == JUMPLISTSIZE) {
              if (wms->jumps[0].can_free_entry) {
                shada_free_shada_entry(&wms->jumps[0].data);
              }
              memmove(&wms->jumps[0], &wms->jumps[1],
                      sizeof(wms->jumps[0]) * (size_t) i);
            } else {
              memmove(&wms->jumps[i + 1], &wms->jumps[i],
                      sizeof(wms->jumps[0]) * (size_t) (jl_len - i));
            }
          } else if (i == jl_len) {
            if (jl_len == JUMPLISTSIZE) {
              i = -1;
            } else if (jl_len > 0) {
              memmove(&wms->jumps[1], &wms->jumps[0],
                      sizeof(wms->jumps[0]) * (size_t) jl_len);
            }
          }
        }
        if (i != -1) {
          wms->jumps[i] = (PossiblyFreedShadaEntry) {
            .can_free_entry = true,
            .data = entry,
          };
          if (jl_len < JUMPLISTSIZE) {
            wms->jumps_size++;
          }
        } else {
          shada_free_shada_entry(&entry);
        }
        break;
      }
    }
  }
#undef COMPARE_WITH_ENTRY

  // Write the rest
shada_write_main_cycle_end:
#define PACK_WMS_ARRAY(wms_array) \
  do { \
    for (size_t i_ = 0; i_ < ARRAY_SIZE(wms_array); i_++) { \
      if (wms_array[i_].data.type != kSDItemMissing) { \
        if (!shada_pack_encoded_entry(packer, &sd_writer->sd_conv, \
                                      wms_array[i_], \
                                      max_kbyte)) { \
          ret = kSDWriteFailed; \
          goto shada_write_exit; \
        } \
      } \
    } \
  } while (0)
  PACK_WMS_ARRAY(wms->global_marks);
  PACK_WMS_ARRAY(wms->registers);
  for (size_t i = 0; i < wms->jumps_size; i++) {
    if (!shada_pack_encoded_entry(packer, &sd_writer->sd_conv, wms->jumps[i],
                                  max_kbyte)) {
      ret = kSDWriteFailed;
      goto shada_write_exit;
    }
  }
#define PACK_WMS_ENTRY(wms_entry) \
  do { \
    if (wms_entry.data.type != kSDItemMissing) { \
      if (!shada_pack_encoded_entry(packer, &sd_writer->sd_conv, wms_entry, \
                                    max_kbyte)) { \
        ret = kSDWriteFailed; \
        goto shada_write_exit; \
      } \
    } \
  } while (0)
  PACK_WMS_ENTRY(wms->search_pattern);
  PACK_WMS_ENTRY(wms->sub_search_pattern);
  PACK_WMS_ENTRY(wms->replacement);
#undef PACK_WMS_ENTRY

  const size_t file_markss_size = kh_size(&wms->file_marks);
  FileMarks **const all_file_markss =
      xmalloc(file_markss_size * sizeof(*all_file_markss));
  FileMarks **cur_file_marks = all_file_markss;
  for (khint_t i = kh_begin(&wms->file_marks);
       i != kh_end(&wms->file_marks);
       i++) {
    if (kh_exist(&wms->file_marks, i)) {
      *cur_file_marks++ = &kh_val(&wms->file_marks, i);
      xfree((void *) kh_key(&wms->file_marks, i));
    }
  }
  qsort((void *) all_file_markss, file_markss_size, sizeof(*all_file_markss),
        &compare_file_marks);
  const size_t file_markss_to_dump = MIN(num_marked_files, file_markss_size);
  for (size_t i = 0; i < file_markss_to_dump; i++) {
    PACK_WMS_ARRAY(all_file_markss[i]->marks);
    for (size_t j = 0; j < all_file_markss[i]->changes_size; j++) {
      if (!shada_pack_encoded_entry(packer, &sd_writer->sd_conv,
                                    all_file_markss[i]->changes[j],
                                    max_kbyte)) {
        ret = kSDWriteFailed;
        goto shada_write_exit;
      }
    }
    for (size_t j = 0; j < all_file_markss[i]->additional_marks_size; j++) {
      if (!shada_pack_entry(packer, all_file_markss[i]->additional_marks[j],
                            0)) {
        shada_free_shada_entry(&all_file_markss[i]->additional_marks[j]);
        ret = kSDWriteFailed;
        goto shada_write_exit;
      }
      shada_free_shada_entry(&all_file_markss[i]->additional_marks[j]);
    }
    xfree(all_file_markss[i]->additional_marks);
  }
  xfree(all_file_markss);
#undef PACK_WMS_ARRAY

  if (dump_history) {
    for (size_t i = 0; i < HIST_COUNT; i++) {
      if (dump_one_history[i]) {
        hms_insert_whole_neovim_history(&wms->hms[i]);
        HMS_ITER(&wms->hms[i], cur_entry) {
          if (!shada_pack_encoded_entry(packer, &sd_writer->sd_conv,
                                        (PossiblyFreedShadaEntry) {
                                          .data = cur_entry->data,
                                          .can_free_entry =
                                             cur_entry->can_free_entry,
                                        }, max_kbyte)) {
            ret = kSDWriteFailed;
            break;
          }
        }
        hms_dealloc(&wms->hms[i]);
        if (ret == kSDWriteFailed) {
          goto shada_write_exit;
        }
      }
    }
  }

shada_write_exit:
  kh_dealloc(file_marks, &wms->file_marks);
  kh_destroy(bufset, removable_bufs);
  msgpack_packer_free(packer);
  kh_dealloc(strset, &wms->dumped_variables);
  xfree(wms);
  return ret;
}

#undef PACK_STATIC_STR

/// Write ShaDa file to a given location
///
/// @param[in]  fname    File to write to. If it is NULL or empty then default 
///                      location is used.
/// @param[in]  nomerge  If true then old file is ignored.
///
/// @return OK if writing was successfull, FAIL otherwise.
int shada_write_file(const char *const file, bool nomerge)
{
  char *const fname = shada_filename(file);
  char *tempname = NULL;
  ShaDaWriteDef sd_writer = (ShaDaWriteDef) {
    .write = &write_file,
    .close = &close_sd_writer,
    .error = NULL,
  };
  ShaDaReadDef sd_reader;

  intptr_t fd;

  if (!nomerge) {
    if (open_shada_file_for_reading(fname, &sd_reader) != 0) {
      nomerge = true;
      goto shada_write_file_nomerge;
    }
#ifdef UNIX
    // For Unix we check the owner of the file.  It's not very nice to
    // overwrite a user’s viminfo file after a "su root", with a
    // viminfo file that the user can't read.
    FileInfo old_info;
    if (os_fileinfo((char *)fname, &old_info)
        && getuid() != ROOT_UID
        && !(old_info.stat.st_uid == getuid()
             ? (old_info.stat.st_mode & 0200)
             : (old_info.stat.st_gid == getgid()
                ? (old_info.stat.st_mode & 0020)
                : (old_info.stat.st_mode & 0002)))) {
      EMSG2(_("E137: ShaDa file is not writable: %s"), fname);
      sd_reader.close(&sd_reader);
      xfree(fname);
      return FAIL;
    }
#endif
    tempname = modname(fname, ".tmp.a", false);
    if (tempname == NULL) {
      nomerge = true;
      goto shada_write_file_nomerge;
    }

    // Save permissions from the original file, with modifications:
    int perm = (int) os_getperm(fname);
    perm = (perm >= 0) ? ((perm & 0777) | 0600) : 0600;
    //                 ^3         ^1       ^2      ^2,3
    // 1: Strip SUID bit if any.
    // 2: Make sure that user can always read and write the result.
    // 3: If somebody happened to delete the file after it was opened for 
    //    reading use u=rw permissions.
shada_write_file_open:
    fd = (intptr_t) open_file(tempname, O_CREAT|O_WRONLY|O_NOFOLLOW|O_EXCL,
                              perm);
    if (fd < 0) {
      if (-fd == EEXIST
#ifdef ELOOP
          || -fd == ELOOP
#endif
          ) {
        // File already exists, try another name
        char *const wp = tempname + strlen(tempname) - 1;
        if (*wp == 'z') {
          // Tried names from .tmp.a to .tmp.z, all failed. Something must be 
          // wrong then.
          EMSG2(_("E138: All %s.tmp.X files exist, cannot write ShaDa file!"),
                fname);
          xfree(fname);
          xfree(tempname);
          return FAIL;
        } else {
          (*wp)++;
          goto shada_write_file_open;
        }
      }
    }
  }
  if (nomerge) {
shada_write_file_nomerge: {}
    char *const tail = path_tail_with_sep(fname);
    if (tail != fname) {
      const char tail_save = *tail;
      *tail = NUL;
      if (!os_isdir(fname)) {
        int ret;
        char *failed_dir;
        if ((ret = os_mkdir_recurse(fname, 0700, &failed_dir)) != 0) {
          EMSG3(_(SERR "Failed to create directory %s "
                  "for writing ShaDa file: %s"),
                failed_dir, os_strerror(ret));
          xfree(fname);
          xfree(failed_dir);
          return FAIL;
        }
      }
      *tail = tail_save;
    }
    fd = (intptr_t) open_file(fname, O_CREAT|O_WRONLY|O_TRUNC,
                              0600);
  }

  if (p_verbose > 0) {
    verbose_enter();
    smsg(_("Writing ShaDa file \"%s\""), fname);
    verbose_leave();
  }

  if (fd < 0) {
    xfree(fname);
    xfree(tempname);
    return FAIL;
  }

  sd_writer.cookie = (void *) fd;

  convert_setup(&sd_writer.sd_conv, p_enc, "utf-8");

  const ShaDaWriteResult sw_ret = shada_write(&sd_writer, (nomerge
                                                           ? NULL
                                                           : &sd_reader));
  sd_writer.close(&sd_writer);

  if (!nomerge) {
    sd_reader.close(&sd_reader);
    if (sw_ret == kSDWriteSuccessfull) {
      if (vim_rename(tempname, fname) == -1) {
        EMSG3(_(RNERR "Can't rename ShaDa file from %s to %s!"),
              tempname, fname);
      } else {
        os_remove(tempname);
      }
    } else {
      if (sw_ret == kSDWriteReadNotShada) {
        EMSG3(_(RNERR "Did not rename %s because %s "
                "does not looks like a ShaDa file"), tempname, fname);
      } else {
        EMSG3(_(RNERR "Did not rename %s to %s because there were errors "
                "during writing it"), tempname, fname);
      }
    }
    xfree(tempname);
  }

  xfree(fname);
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
/// @param[in]  forceit  If true, use forced reading (prioritize file contents
///                      over current NeoVim state).
/// @param[in]  missing_ok  If true, do not error out when file is missing.
///
/// @return OK in case of success, FAIL otherwise.
int shada_read_everything(const char *const fname, const bool forceit,
                          const bool missing_ok)
{
  return shada_read_file(fname,
                         kShaDaWantInfo|kShaDaWantMarks|kShaDaGetOldfiles
                         |(forceit?kShaDaForceit:0)
                         |(missing_ok?0:kShaDaMissingError));
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
      dict_unref(entry->data.filemark.additional_data);
      xfree(entry->data.filemark.fname);
      break;
    }
    case kSDItemSearchPattern: {
      dict_unref(entry->data.search_pattern.additional_data);
      xfree(entry->data.search_pattern.pat);
      break;
    }
    case kSDItemRegister: {
      dict_unref(entry->data.reg.additional_data);
      for (size_t i = 0; i < entry->data.reg.contents_size; i++) {
        xfree(entry->data.reg.contents[i]);
      }
      xfree(entry->data.reg.contents);
      break;
    }
    case kSDItemHistoryEntry: {
      list_unref(entry->data.history_item.additional_elements);
      xfree(entry->data.history_item.string);
      break;
    }
    case kSDItemVariable: {
      list_unref(entry->data.global_var.additional_elements);
      xfree(entry->data.global_var.name);
      clear_tv(&entry->data.global_var.value);
      break;
    }
    case kSDItemSubString: {
      list_unref(entry->data.sub_string.additional_elements);
      xfree(entry->data.sub_string.sub);
      break;
    }
    case kSDItemBufferList: {
      for (size_t i = 0; i < entry->data.buffer_list.size; i++) {
        xfree(entry->data.buffer_list.buffers[i].fname);
        dict_unref(entry->data.buffer_list.buffers[i].additional_data);
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
/// @return kSDReadStatusSuccess if everything was OK, kSDReadStatusNotShaDa if 
///         there were not enough bytes to read or kSDReadStatusReadError if 
///         there was some error while reading.
static ShaDaReadResult fread_len(ShaDaReadDef *const sd_reader,
                                 char *const buffer,
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
    emsg2(_(SERR "System error while reading ShaDa file: %s"),
          sd_reader->error);
    return kSDReadStatusReadError;
  } else if (sd_reader->eof) {
    emsgu(_(RCERR "Error while reading ShaDa file: "
            "last entry specified that it occupies %" PRIu64 " bytes, "
            "but file ended earlier"),
          (uint64_t) length);
    return kSDReadStatusNotShaDa;
  }
  assert(read_bytes >= 0 && (size_t) read_bytes == length);
  return kSDReadStatusSuccess;
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
/// @return kSDReadStatusSuccess if reading was successfull, 
///         kSDReadStatusNotShaDa if there were not enough bytes to read or 
///         kSDReadStatusReadError if reading failed for whatever reason.
static ShaDaReadResult msgpack_read_uint64(ShaDaReadDef *const sd_reader,
                                           const int first_char,
                                           uint64_t *const result)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const uintmax_t fpos = sd_reader->fpos - 1;

  if (first_char == EOF) {
    if (sd_reader->error) {
      emsg2(_(SERR "System error while reading integer from ShaDa file: %s"),
            sd_reader->error);
      return kSDReadStatusReadError;
    } else if (sd_reader->eof) {
      emsgu(_(RCERR "Error while reading ShaDa file: "
              "expected positive integer at position %" PRIu64
              ", but got nothing"),
            (uint64_t) fpos);
      return kSDReadStatusNotShaDa;
    }
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
        emsgu(_(RCERR "Error while reading ShaDa file: "
                "expected positive integer at position %" PRIu64),
              (uint64_t) fpos);
        return kSDReadStatusNotShaDa;
      }
    }
    uint8_t buf[sizeof(uint64_t)] = {0, 0, 0, 0, 0, 0, 0, 0};
    ShaDaReadResult fl_ret;
    if ((fl_ret = fread_len(sd_reader, (char *) &(buf[sizeof(uint64_t)-length]),
                            length))
        != kSDReadStatusSuccess) {
      return fl_ret;
    }
    *result = be64toh(*((uint64_t *) &(buf[0])));
  }
  return kSDReadStatusSuccess;
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
/// @param[in]   max_kbyte  If non-zero, skip reading entries which have length 
///                         greater then given.
///
/// @return Any value from ShaDaReadResult enum.
static ShaDaReadResult shada_read_next_item(ShaDaReadDef *const sd_reader,
                                            ShadaEntry *const entry,
                                            const unsigned flags,
                                            const size_t max_kbyte)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  ShaDaReadResult ret = kSDReadStatusMalformed;
shada_read_next_item_start:
  // Set entry type to kSDItemMissing and also make sure that all pointers in 
  // data union are NULL so they are safe to xfree(). This is needed in case 
  // somebody calls goto shada_read_next_item_error before anything is set in 
  // the switch.
  memset(entry, 0, sizeof(*entry));
  if (sd_reader->eof) {
    return kSDReadStatusFinished;
  }

  // First: manually unpack type, timestamp and length.
  // This is needed to avoid both seeking and having to maintain a buffer.
  uint64_t type_u64 = (uint64_t) kSDItemMissing;
  uint64_t timestamp_u64;
  uint64_t length_u64;

  const uintmax_t initial_fpos = sd_reader->fpos;
  const int first_char = read_char(sd_reader);
  if (first_char == EOF && sd_reader->eof) {
    return kSDReadStatusFinished;
  }

  ShaDaReadResult mru_ret;
  if (((mru_ret = msgpack_read_uint64(sd_reader, first_char, &type_u64))
       != kSDReadStatusSuccess)
      || ((mru_ret = msgpack_read_uint64(sd_reader, read_char(sd_reader),
                                         &timestamp_u64))
          != kSDReadStatusSuccess)
      || ((mru_ret = msgpack_read_uint64(sd_reader, read_char(sd_reader),
                                         &length_u64))
          != kSDReadStatusSuccess)) {
    return mru_ret;
  }

  const size_t length = (size_t) length_u64;
  entry->timestamp = (Timestamp) timestamp_u64;

  if (type_u64 == 0) {
    // kSDItemUnknown cannot possibly pass that far because it is -1 and that 
    // will fail in msgpack_read_uint64. But kSDItemMissing may and it will 
    // otherwise be skipped because (1 << 0) will never appear in flags.
    emsgu(_(RCERR "Error while reading ShaDa file: "
            "there is an item at position %" PRIu64 " "
            "that must not be there: Missing items are "
            "for internal uses only"),
          (uint64_t) initial_fpos);
    return kSDReadStatusNotShaDa;
  }

  if ((type_u64 > SHADA_LAST_ENTRY
       ? !(flags & kSDReadUnknown)
       : !((unsigned) (1 << type_u64) & flags))
      || (max_kbyte && length > max_kbyte * 1024)) {
    const ShaDaReadResult fl_ret = fread_len(sd_reader, NULL, length);
    if (fl_ret != kSDReadStatusSuccess) {
      return fl_ret;
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

  char *const buf = xmalloc(length);

  {
    const ShaDaReadResult fl_ret = fread_len(sd_reader, buf, length);
    if (fl_ret != kSDReadStatusSuccess) {
      xfree(buf);
      return fl_ret;
    }
  }

  msgpack_unpacked unpacked;
  msgpack_unpacked_init(&unpacked);

  bool did_try_to_free = false;
shada_read_next_item_read_next: {}
  size_t off = 0;
  const msgpack_unpack_return result =
      msgpack_unpack_next(&unpacked, buf, length, &off);
  ret = kSDReadStatusNotShaDa;
  switch (result) {
    case MSGPACK_UNPACK_SUCCESS: {
      if (off < length) {
        goto shada_read_next_item_extra_bytes;
      }
      break;
    }
    case MSGPACK_UNPACK_PARSE_ERROR: {
      emsgu(_(RCERR "Failed to parse ShaDa file due to a msgpack parser error "
              "at position %" PRIu64),
            (uint64_t) initial_fpos);
      goto shada_read_next_item_error;
    }
    case MSGPACK_UNPACK_NOMEM_ERROR: {
      if (!did_try_to_free) {
        did_try_to_free = true;
        try_to_free_memory();
        goto shada_read_next_item_read_next;
      }
      EMSG(_(e_outofmem));
      ret = kSDReadStatusReadError;
      goto shada_read_next_item_error;
    }
    case MSGPACK_UNPACK_CONTINUE: {
      emsgu(_(RCERR "Failed to parse ShaDa file: incomplete msgpack string "
              "at position %" PRIu64),
            (uint64_t) initial_fpos);
      goto shada_read_next_item_error;
    }
    case MSGPACK_UNPACK_EXTRA_BYTES: {
shada_read_next_item_extra_bytes:
      emsgu(_(RCERR "Failed to parse ShaDa file: extra bytes in msgpack string "
              "at position %" PRIu64),
            (uint64_t) initial_fpos);
      goto shada_read_next_item_error;
    }
  }
  ret = kSDReadStatusMalformed;
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
      emsgu(_(RERR "Error while reading ShaDa file: " \
              entry_name " entry at position %" PRIu64 " " \
              error_desc), \
            (uint64_t) initial_fpos); \
      ga_clear(&ad_ga); \
      goto shada_read_next_item_error; \
    } \
    tgt = proc(obj.via.attr); \
  } while (0)
#define CHECK_KEY_IS_STR(entry_name) \
  do { \
    if (unpacked.data.via.map.ptr[i].key.type != MSGPACK_OBJECT_STR) { \
      emsgu(_(RERR "Error while reading ShaDa file: " \
              entry_name " entry at position %" PRIu64 " " \
              "has key which is not a string"), \
            (uint64_t) initial_fpos); \
      ga_clear(&ad_ga); \
      goto shada_read_next_item_error; \
    } else if (unpacked.data.via.map.ptr[i].key.via.str.size == 0) { \
      emsgu(_(RERR "Error while reading ShaDa file: " \
              entry_name " entry at position %" PRIu64 " " \
              "has empty key"), \
            (uint64_t) initial_fpos); \
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
      entry_name, name, "which is not " type_name, tgt, \
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
      entry_name, name, "which is not an integer", tgt, \
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
#define SET_ADDITIONAL_DATA(tgt, name) \
      do { \
        if (ad_ga.ga_len) { \
          msgpack_object obj = { \
            .type = MSGPACK_OBJECT_MAP, \
            .via = { \
              .map = { \
                .size = (uint32_t) ad_ga.ga_len, \
                .ptr = ad_ga.ga_data, \
              } \
            } \
          }; \
          typval_T adtv; \
          if (msgpack_to_vim(obj, &adtv) == FAIL \
              || adtv.v_type != VAR_DICT) { \
            emsgu(_(RERR "Error while reading ShaDa file: " \
                    name " entry at position %" PRIu64 " " \
                    "cannot be converted to a VimL dictionary"), \
                  (uint64_t) initial_fpos); \
            ga_clear(&ad_ga); \
            clear_tv(&adtv); \
            goto shada_read_next_item_error; \
          } \
          tgt = adtv.vval.v_dict; \
        } \
        ga_clear(&ad_ga); \
      } while (0)
#define SET_ADDITIONAL_ELEMENTS(src, src_maxsize, tgt, name) \
      do { \
        if ((src).size > (size_t) (src_maxsize)) { \
          msgpack_object obj = { \
            .type = MSGPACK_OBJECT_ARRAY, \
            .via = { \
              .array = { \
                .size = ((src).size - (uint32_t) (src_maxsize)), \
                .ptr = (src).ptr + (src_maxsize), \
              } \
            } \
          }; \
          typval_T aetv; \
          if (msgpack_to_vim(obj, &aetv) == FAIL) { \
            emsgu(_(RERR "Error while reading ShaDa file: " \
                    name " entry at position %" PRIu64 " " \
                    "cannot be converted to a VimL list"), \
                  (uint64_t) initial_fpos); \
            clear_tv(&aetv); \
            goto shada_read_next_item_error; \
          } \
          assert(aetv.v_type == VAR_LIST); \
          (tgt) = aetv.vval.v_list; \
        } \
      } while (0)
  switch ((ShadaEntryType) type_u64) {
    case kSDItemHeader: {
      if (!msgpack_rpc_to_dictionary(&(unpacked.data), &(entry->data.header))) {
        emsgu(_(RERR "Error while reading ShaDa file: "
                "header entry at position %" PRIu64 " is not a dictionary"),
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      break;
    }
    case kSDItemSearchPattern: {
      if (unpacked.data.type != MSGPACK_OBJECT_MAP) {
        emsgu(_(RERR "Error while reading ShaDa file: "
                "search pattern entry at position %" PRIu64 " "
                "is not a dictionary"),
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
        .highlighted = false,
        .pat = NULL,
        .additional_data = NULL,
      };
      garray_T ad_ga;
      ga_init(&ad_ga, sizeof(*(unpacked.data.via.map.ptr)), 1);
      for (size_t i = 0; i < unpacked.data.via.map.size; i++) {
        CHECK_KEY_IS_STR("search pattern");
        BOOLEAN_KEY("search pattern", SEARCH_KEY_MAGIC,
                    entry->data.search_pattern.magic)
        else BOOLEAN_KEY("search pattern", SEARCH_KEY_SMARTCASE,
                         entry->data.search_pattern.smartcase)
        else BOOLEAN_KEY("search pattern", SEARCH_KEY_HAS_LINE_OFFSET,
                         entry->data.search_pattern.has_line_offset)
        else BOOLEAN_KEY("search pattern", SEARCH_KEY_PLACE_CURSOR_AT_END,
                         entry->data.search_pattern.place_cursor_at_end)
        else BOOLEAN_KEY("search pattern", SEARCH_KEY_IS_LAST_USED,
                         entry->data.search_pattern.is_last_used)
        else BOOLEAN_KEY("search pattern", SEARCH_KEY_IS_SUBSTITUTE_PATTERN,
                         entry->data.search_pattern.is_substitute_pattern)
        else BOOLEAN_KEY("search pattern", SEARCH_KEY_HIGHLIGHTED,
                         entry->data.search_pattern.highlighted)
        else INTEGER_KEY("search pattern", SEARCH_KEY_OFFSET,
                         entry->data.search_pattern.offset)
        else CONVERTED_STRING_KEY("search pattern", SEARCH_KEY_PAT,
                                  entry->data.search_pattern.pat)
        else ADDITIONAL_KEY
      }
      if (entry->data.search_pattern.pat == NULL) {
        emsgu(_(RERR "Error while reading ShaDa file: "
                "search pattern entry at position %" PRIu64 " "
                "has no pattern"),
              (uint64_t) initial_fpos);
        ga_clear(&ad_ga);
        goto shada_read_next_item_error;
      }
      SET_ADDITIONAL_DATA(entry->data.search_pattern.additional_data,
                          "search pattern");
      break;
    }
    case kSDItemChange:
    case kSDItemJump:
    case kSDItemGlobalMark:
    case kSDItemLocalMark: {
      if (unpacked.data.type != MSGPACK_OBJECT_MAP) {
        emsgu(_(RERR "Error while reading ShaDa file: "
                "mark entry at position %" PRIu64 " "
                "is not a dictionary"),
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
        if (CHECK_KEY(unpacked.data.via.map.ptr[i].key, KEY_NAME_CHAR)) {
          if (type_u64 == kSDItemJump || type_u64 == kSDItemChange) {
            emsgu(_(RERR "Error while reading ShaDa file: "
                    "mark entry at position %" PRIu64 " "
                    "has n key which is only valid "
                    "for local and global mark entries"),
                  (uint64_t) initial_fpos);
            ga_clear(&ad_ga);
            goto shada_read_next_item_error;
          }
          CHECKED_ENTRY(
              (unpacked.data.via.map.ptr[i].val.type
               == MSGPACK_OBJECT_POSITIVE_INTEGER),
              "has n key value which is not an unsigned integer",
              "mark", unpacked.data.via.map.ptr[i].val,
              entry->data.filemark.name, u64, TOCHAR);
        } else LONG_KEY("mark", KEY_LNUM, entry->data.filemark.mark.lnum)
        else INTEGER_KEY("mark", KEY_COL, entry->data.filemark.mark.col)
        else STRING_KEY("mark", KEY_FILE, entry->data.filemark.fname)
        else ADDITIONAL_KEY
      }
      if (entry->data.filemark.fname == NULL) {
        emsgu(_(RERR "Error while reading ShaDa file: "
                "mark entry at position %" PRIu64 " "
                "is missing file name"),
              (uint64_t) initial_fpos);
        ga_clear(&ad_ga);
        goto shada_read_next_item_error;
      }
      if (entry->data.filemark.mark.lnum <= 0) {
        emsgu(_(RERR "Error while reading ShaDa file: "
                "mark entry at position %" PRIu64 " "
                "has invalid line number"),
              (uint64_t) initial_fpos);
        ga_clear(&ad_ga);
        goto shada_read_next_item_error;
      }
      if (entry->data.filemark.mark.col < 0) {
        emsgu(_(RERR "Error while reading ShaDa file: "
                "mark entry at position %" PRIu64 " "
                "has invalid column number"),
              (uint64_t) initial_fpos);
        ga_clear(&ad_ga);
        goto shada_read_next_item_error;
      }
      SET_ADDITIONAL_DATA(entry->data.filemark.additional_data, "mark");
      break;
    }
    case kSDItemRegister: {
      if (unpacked.data.type != MSGPACK_OBJECT_MAP) {
        emsgu(_(RERR "Error while reading ShaDa file: "
                "register entry at position %" PRIu64 " "
                "is not a dictionary"),
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
        TYPED_KEY("register", REG_KEY_TYPE, "an unsigned integer",
                  entry->data.reg.type, POSITIVE_INTEGER, u64, TOU8)
        else TYPED_KEY("register", KEY_NAME_CHAR, "an unsigned integer",
                       entry->data.reg.name, POSITIVE_INTEGER, u64, TOCHAR)
        else TYPED_KEY("register", REG_KEY_WIDTH, "an unsigned integer",
                       entry->data.reg.width, POSITIVE_INTEGER, u64, TOSIZE)
        else if (CHECK_KEY(unpacked.data.via.map.ptr[i].key,
                           REG_KEY_CONTENTS)) {
          if (unpacked.data.via.map.ptr[i].val.type != MSGPACK_OBJECT_ARRAY) {
            emsgu(_(RERR "Error while reading ShaDa file: "
                    "register entry at position %" PRIu64 " "
                    "has " REG_KEY_CONTENTS " key with non-array value"),
                  (uint64_t) initial_fpos);
            ga_clear(&ad_ga);
            goto shada_read_next_item_error;
          }
          if (unpacked.data.via.map.ptr[i].val.via.array.size == 0) {
            emsgu(_(RERR "Error while reading ShaDa file: "
                    "register entry at position %" PRIu64 " "
                    "has " REG_KEY_CONTENTS " key with empty array"),
                  (uint64_t) initial_fpos);
            ga_clear(&ad_ga);
            goto shada_read_next_item_error;
          }
          const msgpack_object_array arr =
              unpacked.data.via.map.ptr[i].val.via.array;
          for (size_t i = 0; i < arr.size; i++) {
            if (arr.ptr[i].type != MSGPACK_OBJECT_BIN) {
              emsgu(_(RERR "Error while reading ShaDa file: "
                      "register entry at position %" PRIu64 " "
                      "has " REG_KEY_CONTENTS " array with non-binary value"),
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
        emsgu(_(RERR "Error while reading ShaDa file: "
                "register entry at position %" PRIu64 " "
                "has missing " REG_KEY_CONTENTS " array"),
              (uint64_t) initial_fpos);
        ga_clear(&ad_ga);
        goto shada_read_next_item_error;
      }
      SET_ADDITIONAL_DATA(entry->data.reg.additional_data, "register");
      break;
    }
    case kSDItemHistoryEntry: {
      if (unpacked.data.type != MSGPACK_OBJECT_ARRAY) {
        emsgu(_(RERR "Error while reading ShaDa file: "
                "history entry at position %" PRIu64 " "
                "is not an array"),
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
        emsgu(_(RERR "Error while reading ShaDa file: "
                "history entry at position %" PRIu64 " "
                "does not have enough elements"),
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      if (unpacked.data.via.array.ptr[0].type
          != MSGPACK_OBJECT_POSITIVE_INTEGER) {
        emsgu(_(RERR "Error while reading ShaDa file: "
                "history entry at position %" PRIu64 " "
                "has wrong history type type"),
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      if (unpacked.data.via.array.ptr[1].type
          != MSGPACK_OBJECT_BIN) {
        emsgu(_(RERR "Error while reading ShaDa file: "
                "history entry at position %" PRIu64 " "
                "has wrong history string type"),
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      if (memchr(unpacked.data.via.array.ptr[1].via.bin.ptr, 0,
                 unpacked.data.via.array.ptr[1].via.bin.size) != NULL) {
        emsgu(_(RERR "Error while reading ShaDa file: "
                "history entry at position %" PRIu64 " "
                "contains string with zero byte inside"),
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      entry->data.history_item.histtype =
          (uint8_t) unpacked.data.via.array.ptr[0].via.u64;
      const bool is_hist_search =
          entry->data.history_item.histtype == HIST_SEARCH;
      if (is_hist_search) {
        if (unpacked.data.via.array.size < 3) {
          emsgu(_(RERR "Error while reading ShaDa file: "
                  "search history entry at position %" PRIu64 " "
                  "does not have separator character"),
                (uint64_t) initial_fpos);
          goto shada_read_next_item_error;
        }
        if (unpacked.data.via.array.ptr[2].type
            != MSGPACK_OBJECT_POSITIVE_INTEGER) {
          emsgu(_(RERR "Error while reading ShaDa file: "
                  "search history entry at position %" PRIu64 " "
                  "has wrong history separator type"),
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
      SET_ADDITIONAL_ELEMENTS(unpacked.data.via.array, (2 + is_hist_search),
                              entry->data.history_item.additional_elements,
                              "history");
      break;
    }
    case kSDItemVariable: {
      if (unpacked.data.type != MSGPACK_OBJECT_ARRAY) {
        emsgu(_(RERR "Error while reading ShaDa file: "
                "variable entry at position %" PRIu64 " "
                "is not an array"),
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      entry->data.global_var = (struct global_var) {
        .name = NULL,
        .value = {
          .v_type = VAR_UNKNOWN,
        },
        .additional_elements = NULL
      };
      if (unpacked.data.via.array.size < 2) {
        emsgu(_(RERR "Error while reading ShaDa file: "
                "variable entry at position %" PRIu64 " "
                "does not have enough elements"),
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      if (unpacked.data.via.array.ptr[0].type != MSGPACK_OBJECT_BIN) {
        emsgu(_(RERR "Error while reading ShaDa file: "
                "variable entry at position %" PRIu64 " "
                "has wrong variable name type"),
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      if (unpacked.data.via.array.ptr[1].type == MSGPACK_OBJECT_NIL
          || unpacked.data.via.array.ptr[1].type == MSGPACK_OBJECT_EXT) {
        emsgu(_(RERR "Error while reading ShaDa file: "
                "variable entry at position %" PRIu64 " "
                "has wrong variable value type"),
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      entry->data.global_var.name =
          xmemdupz(unpacked.data.via.array.ptr[0].via.bin.ptr,
                   unpacked.data.via.array.ptr[0].via.bin.size);
      if (msgpack_to_vim(unpacked.data.via.array.ptr[1],
                         &(entry->data.global_var.value)) == FAIL) {
        emsgu(_(RERR "Error while reading ShaDa file: "
                "variable entry at position %" PRIu64 " "
                "has value that cannot be converted to the VimL value"),
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      if (sd_reader->sd_conv.vc_type != CONV_NONE) {
        typval_T tgttv;
        var_item_copy(&sd_reader->sd_conv,
                      &entry->data.global_var.value,
                      &tgttv,
                      true,
                      0);
        clear_tv(&entry->data.global_var.value);
        entry->data.global_var.value = tgttv;
      }
      SET_ADDITIONAL_ELEMENTS(unpacked.data.via.array, 2,
                              entry->data.global_var.additional_elements,
                              "variable");
      break;
    }
    case kSDItemSubString: {
      if (unpacked.data.type != MSGPACK_OBJECT_ARRAY) {
        emsgu(_(RERR "Error while reading ShaDa file: "
                "sub string entry at position %" PRIu64 " "
                "is not an array"),
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      entry->data.sub_string = (struct sub_string) {
        .sub = NULL,
        .additional_elements = NULL
      };
      if (unpacked.data.via.array.size < 1) {
        emsgu(_(RERR "Error while reading ShaDa file: "
                "sub string entry at position %" PRIu64 " "
                "does not have enough elements"),
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      if (unpacked.data.via.array.ptr[0].type != MSGPACK_OBJECT_BIN) {
        emsgu(_(RERR "Error while reading ShaDa file: "
                "sub string entry at position %" PRIu64 " "
                "has wrong sub string type"),
              (uint64_t) initial_fpos);
        goto shada_read_next_item_error;
      }
      entry->data.sub_string.sub =
          BIN_CONVERTED(unpacked.data.via.array.ptr[0].via.bin);
      SET_ADDITIONAL_ELEMENTS(unpacked.data.via.array, 1,
                              entry->data.sub_string.additional_elements,
                              "sub string");
      break;
    }
    case kSDItemBufferList: {
      if (unpacked.data.type != MSGPACK_OBJECT_ARRAY) {
        emsgu(_(RERR "Error while reading ShaDa file: "
                "buffer list entry at position %" PRIu64 " "
                "is not an array"),
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
            emsgu(_(RERR "Error while reading ShaDa file: "
                    "buffer list at position %" PRIu64 " "
                    "contains entry that is not a dictionary"),
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
                LONG_KEY("buffer list entry", KEY_LNUM,
                        entry->data.buffer_list.buffers[j].pos.lnum)
                else INTEGER_KEY("buffer list entry", KEY_COL,
                                entry->data.buffer_list.buffers[j].pos.col)
                else STRING_KEY("buffer list entry", KEY_FILE,
                                entry->data.buffer_list.buffers[j].fname)
                else ADDITIONAL_KEY
              }
            }
          }
          if (entry->data.buffer_list.buffers[i].pos.lnum <= 0) {
            emsgu(_(RERR "Error while reading ShaDa file: "
                    "buffer list at position %" PRIu64 " "
                    "contains entry with invalid line number"),
                  (uint64_t) initial_fpos);
            ga_clear(&ad_ga);
            goto shada_read_next_item_error;
          }
          if (entry->data.buffer_list.buffers[i].pos.col < 0) {
            emsgu(_(RERR "Error while reading ShaDa file: "
                    "buffer list at position %" PRIu64 " "
                    "contains entry with invalid column number"),
                  (uint64_t) initial_fpos);
            ga_clear(&ad_ga);
            goto shada_read_next_item_error;
          }
          if (entry->data.buffer_list.buffers[i].fname == NULL) {
            emsgu(_(RERR "Error while reading ShaDa file: "
                    "buffer list at position %" PRIu64 " "
                    "contains entry that does not have a file name"),
                  (uint64_t) initial_fpos);
            ga_clear(&ad_ga);
            goto shada_read_next_item_error;
          }
          SET_ADDITIONAL_DATA(
              entry->data.buffer_list.buffers[i].additional_data,
              "buffer list entry");
        }
      }
      break;
    }
    case kSDItemMissing:
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
#undef SET_ADDITIONAL_DATA
#undef SET_ADDITIONAL_ELEMENTS
shada_read_next_item_error:
  msgpack_unpacked_destroy(&unpacked);
  xfree(buf);
  entry->type = (ShadaEntryType) type_u64;
  shada_free_shada_entry(entry);
  entry->type = kSDItemMissing;
  return ret;
shada_read_next_item_end:
  msgpack_unpacked_destroy(&unpacked);
  xfree(buf);
  return kSDReadStatusSuccess;
}

/// Check whether "name" is on removable media (according to 'shada')
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
  for (p = (char *) p_shada; *p; ) {
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
