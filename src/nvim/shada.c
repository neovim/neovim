// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <stdlib.h>
#include <stddef.h>
#include <stdbool.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>
#include <errno.h>
#include <assert.h>

#include <msgpack.h>
#include <uv.h>

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
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/ex_getln.h"
#include "nvim/search.h"
#include "nvim/regexp.h"
#include "nvim/eval/typval.h"
#include "nvim/version.h"
#include "nvim/path.h"
#include "nvim/fileio.h"
#include "nvim/os/fileio.h"
#include "nvim/strings.h"
#include "nvim/quickfix.h"
#include "nvim/eval/encode.h"
#include "nvim/eval/decode.h"
#include "nvim/lib/khash.h"
#include "nvim/lib/kvec.h"

#ifdef HAVE_BE64TOH
# define _BSD_SOURCE 1
# define _DEFAULT_SOURCE 1
# include ENDIAN_INCLUDE_FILE
#endif

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
#define home_replace_save(a, b) \
    ((char *)home_replace_save(a, (char_u *)b))
#define home_replace(a, b, c, d, e) \
    home_replace(a, (char_u *)b, (char_u *)c, d, e)
#define vim_rename(a, b) \
    (vim_rename((char_u *)a, (char_u *)b))
#define mb_strnicmp(a, b, c) \
    (mb_strnicmp((char_u *)a, (char_u *)b, c))
#define path_try_shorten_fname(b) \
    ((char *)path_try_shorten_fname((char_u *)b))
#define buflist_new(ffname, sfname, ...) \
    (buflist_new((char_u *)ffname, (char_u *)sfname, __VA_ARGS__))
#define os_isdir(f) (os_isdir((char_u *) f))
#define regtilde(s, m) ((char *) regtilde((char_u *) s, m))
#define path_tail_with_sep(f) ((char *) path_tail_with_sep((char_u *)f))

#define SEARCH_KEY_MAGIC "sm"
#define SEARCH_KEY_SMARTCASE "sc"
#define SEARCH_KEY_HAS_LINE_OFFSET "sl"
#define SEARCH_KEY_PLACE_CURSOR_AT_END "se"
#define SEARCH_KEY_IS_LAST_USED "su"
#define SEARCH_KEY_IS_SUBSTITUTE_PATTERN "ss"
#define SEARCH_KEY_HIGHLIGHTED "sh"
#define SEARCH_KEY_OFFSET "so"
#define SEARCH_KEY_PAT "sp"
#define SEARCH_KEY_BACKWARD "sb"

#define REG_KEY_TYPE "rt"
#define REG_KEY_WIDTH "rw"
#define REG_KEY_CONTENTS "rc"
#define REG_KEY_UNNAMED "ru"

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
//   E929: Too many viminfo temp files, like %s!
// Now only six of them are used:
//   E137: ShaDa file is not writeable (for pre-open checks)
//   E929: All %s.tmp.X files exist, cannot write ShaDa file!
//   RCERR (E576) for critical read errors.
//   RNERR (E136) for various errors when renaming.
//   RERR (E575) for various errors inside read ShaDa file.
//   SERR (E886) for various “system” errors (always contains output of
//   strerror)
//   WERR (E574) for various ignorable write errors

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

/// Common prefix for all ignorable “write” errors
#define WERR "E574: "

/// Callback function for add_search_pattern
typedef void (*SearchPatternGetter)(SearchPattern *);

/// Flags for shada_read_file and children
typedef enum {
  kShaDaWantInfo = 1,       ///< Load non-mark information
  kShaDaWantMarks = 2,      ///< Load local file marks and change list
  kShaDaForceit = 4,        ///< Overwrite info already read
  kShaDaGetOldfiles = 8,    ///< Load v:oldfiles.
  kShaDaMissingError = 16,  ///< Error out when os_open returns -ENOENT.
} ShaDaReadFileFlags;

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
  kSDWriteIgnError,      ///< Writing resulted in a error which can be ignored
                         ///< (e.g. when trying to dump a function reference or
                         ///< self-referencing container in a variable).
} ShaDaWriteResult;

/// Flags for shada_read_next_item
enum SRNIFlags {
  kSDReadHeader = (1 << kSDItemHeader),  ///< Determines whether header should
                                         ///< be read (it is usually ignored).
  kSDReadUndisableableData = (
      (1 << kSDItemSearchPattern)
      | (1 << kSDItemSubString)
      | (1 << kSDItemJump)),  ///< Data reading which cannot be disabled by
                              ///< &shada or other options except for disabling
                              ///< reading ShaDa as a whole.
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
      bool search_backward;
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
      MotionType type;
      char **contents;
      bool is_unnamed;
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

KHASH_MAP_INIT_STR(hmll_entries, HMLListEntry *)

/// Sized linked list structure for history merger
typedef struct {
  HMLListEntry *entries;  ///< Pointer to the start of the allocated array of
                          ///< entries.
  HMLListEntry *first;    ///< First entry in the list (is not necessary start
                          ///< of the array) or NULL.
  HMLListEntry *last;     ///< Last entry in the list or NULL.
  HMLListEntry *free_entry;  ///< Last free entry removed by hmll_remove.
  HMLListEntry *last_free_entry;  ///< Last unused element in entries array.
  size_t size;            ///< Number of allocated entries.
  size_t num_entries;     ///< Number of entries already used.
  khash_t(hmll_entries) contained_entries;  ///< Hash mapping all history entry
                                            ///< strings to corresponding entry
                                            ///< pointers.
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

/// Function used to skip in ShaDa files
typedef int (*ShaDaFileSkipper)(struct sd_read_def *const sd_reader,
                                const size_t offset)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_WARN_UNUSED_RESULT;

/// Structure containing necessary pointers for reading ShaDa files
typedef struct sd_read_def {
  ShaDaFileReader read;   ///< Reader function.
  ShaDaReadCloser close;  ///< Close function.
  ShaDaFileSkipper skip;  ///< Function used to skip some bytes.
  void *cookie;           ///< Data describing object read from.
  bool eof;               ///< True if reader reached end of file.
  const char *error;      ///< Error message in case of error.
  uintmax_t fpos;         ///< Current position (amount of bytes read since
                          ///< reader structure initialization). May overflow.
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
  void *cookie;            ///< Data describing object written to.
  const char *error;       ///< Error message in case of error.
} ShaDaWriteDef;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "shada.c.generated.h"
#endif

#define DEF_SDE(name, attr, ...) \
    [kSDItem##name] = { \
      .timestamp = 0, \
      .type = kSDItem##name, \
      .data = { \
        .attr = { __VA_ARGS__ } \
      } \
    }
#define DEFAULT_POS { 1, 0, 0 }
static const pos_T default_pos = DEFAULT_POS;
static const ShadaEntry sd_default_values[] = {
  [kSDItemMissing] = { .type = kSDItemMissing, .timestamp = 0 },
  DEF_SDE(Header, header, .size = 0),
  DEF_SDE(SearchPattern, search_pattern,
          .magic = true,
          .smartcase = false,
          .has_line_offset = false,
          .place_cursor_at_end = false,
          .offset = 0,
          .is_last_used = true,
          .is_substitute_pattern = false,
          .highlighted = false,
          .search_backward = false,
          .pat = NULL,
          .additional_data = NULL),
  DEF_SDE(SubString, sub_string, .sub = NULL, .additional_elements = NULL),
  DEF_SDE(HistoryEntry, history_item,
          .histtype = HIST_CMD,
          .string = NULL,
          .sep = NUL,
          .additional_elements = NULL),
  DEF_SDE(Register, reg,
          .name = NUL,
          .type = kMTCharWise,
          .contents = NULL,
          .contents_size = 0,
          .is_unnamed = false,
          .width = 0,
          .additional_data = NULL),
  DEF_SDE(Variable, global_var,
          .name = NULL,
          .value = {
            .v_type = VAR_UNKNOWN,
            .vval = { .v_string = NULL }
          },
          .additional_elements = NULL),
  DEF_SDE(GlobalMark, filemark,
          .name = '"',
          .mark = DEFAULT_POS,
          .fname = NULL,
          .additional_data = NULL),
  DEF_SDE(Jump, filemark,
          .name = NUL,
          .mark = DEFAULT_POS,
          .fname = NULL,
          .additional_data = NULL),
  DEF_SDE(BufferList, buffer_list,
          .size = 0,
          .buffers = NULL),
  DEF_SDE(LocalMark, filemark,
          .name = '"',
          .mark = DEFAULT_POS,
          .fname = NULL,
          .additional_data = NULL),
  DEF_SDE(Change, filemark,
          .name = NUL,
          .mark = DEFAULT_POS,
          .fname = NULL,
          .additional_data = NULL),
};
#undef DEFAULT_POS
#undef DEF_SDE

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
    .free_entry = NULL,
    .size = size,
    .num_entries = 0,
    .contained_entries = KHASH_EMPTY_TABLE(hmll_entries),
  };
  hmll->last_free_entry = hmll->entries;
}

/// Iterate over HMLList in forward direction
///
/// @param  hmll       Pointer to the list.
/// @param  cur_entry  Name of the variable to iterate over.
/// @param  code       Code to execute on each iteration.
///
/// @return `for` cycle header (use `HMLL_FORALL(hmll, cur_entry) {body}`).
#define HMLL_FORALL(hmll, cur_entry, code) \
    for (HMLListEntry *cur_entry = (hmll)->first; cur_entry != NULL; \
         cur_entry = cur_entry->next) { \
      code \
    } \

/// Remove entry from the linked list
///
/// @param  hmll        List to remove from.
/// @param  hmll_entry  Entry to remove.
static inline void hmll_remove(HMLList *const hmll,
                               HMLListEntry *const hmll_entry)
  FUNC_ATTR_NONNULL_ALL
{
  if (hmll_entry == hmll->last_free_entry - 1) {
    hmll->last_free_entry--;
  } else {
    assert(hmll->free_entry == NULL);
    hmll->free_entry = hmll_entry;
  }
  const khiter_t k = kh_get(hmll_entries, &hmll->contained_entries,
                            hmll_entry->data.data.history_item.string);
  assert(k != kh_end(&hmll->contained_entries));
  kh_del(hmll_entries, &hmll->contained_entries, k);
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
  if (hmll->free_entry == NULL) {
    assert((size_t) (hmll->last_free_entry - hmll->entries)
           == hmll->num_entries);
    target_entry = hmll->last_free_entry++;
  } else {
    assert((size_t) (hmll->last_free_entry - hmll->entries) - 1
           == hmll->num_entries);
    target_entry = hmll->free_entry;
    hmll->free_entry = NULL;
  }
  target_entry->data = data;
  target_entry->can_free_entry = can_free_entry;
  int kh_ret;
  const khiter_t k = kh_put(hmll_entries, &hmll->contained_entries,
                            data.data.history_item.string, &kh_ret);
  if (kh_ret > 0) {
    kh_val(&hmll->contained_entries, k) = target_entry;
  }
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
/// @param  code       Code to execute on each iteration.
///
/// @return `for` cycle header (use `HMLL_FORALL(hmll, cur_entry) {body}`).
#define HMLL_ITER_BACK(hmll, cur_entry, code) \
    for (cur_entry = (hmll)->last; cur_entry != NULL; \
         cur_entry = cur_entry->prev) { \
      code \
    }

/// Free linked list
///
/// @param[in]  hmll  List to free.
static inline void hmll_dealloc(HMLList *const hmll)
  FUNC_ATTR_NONNULL_ALL
{
  kh_dealloc(hmll_entries, &hmll->contained_entries);
  xfree(hmll->entries);
}

/// Wrapper for reading from file descriptors
///
/// @return -1 or number of bytes read.
static ptrdiff_t read_file(ShaDaReadDef *const sd_reader, void *const dest,
                           const size_t size)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const ptrdiff_t ret = file_read(sd_reader->cookie, dest, size);
  sd_reader->eof = file_eof(sd_reader->cookie);
  if (ret < 0) {
    sd_reader->error = os_strerror((int)ret);
    return -1;
  }
  sd_reader->fpos += (size_t)ret;
  return ret;
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
/// @return -1 or number of bytes written.
static ptrdiff_t write_file(ShaDaWriteDef *const sd_writer,
                            const void *const dest,
                            const size_t size)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const ptrdiff_t ret = file_write(sd_writer->cookie, dest, size);
  if (ret < 0) {
    sd_writer->error = os_strerror((int)ret);
    return -1;
  }
  return ret;
}

/// Wrapper for closing file descriptors opened for reading
static void close_sd_reader(ShaDaReadDef *const sd_reader)
  FUNC_ATTR_NONNULL_ALL
{
  close_file(sd_reader->cookie);
}

/// Wrapper for closing file descriptors opened for writing
static void close_sd_writer(ShaDaWriteDef *const sd_writer)
  FUNC_ATTR_NONNULL_ALL
{
  close_file(sd_writer->cookie);
}

/// Wrapper for read that reads to IObuff and ignores bytes read
///
/// Used for skipping.
///
/// @param[in,out]  sd_reader  File read.
/// @param[in]      offset     Amount of bytes to skip.
///
/// @return FAIL in case of failure, OK in case of success. May set
///         sd_reader->eof or sd_reader->error.
static int sd_reader_skip_read(ShaDaReadDef *const sd_reader,
                               const size_t offset)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const ptrdiff_t skip_bytes = file_skip(sd_reader->cookie, offset);
  if (skip_bytes < 0) {
    sd_reader->error = os_strerror((int)skip_bytes);
    return FAIL;
  } else if (skip_bytes != (ptrdiff_t)offset) {
    assert(skip_bytes < (ptrdiff_t)offset);
    sd_reader->eof = file_eof(sd_reader->cookie);
    if (!sd_reader->eof) {
      sd_reader->error = _("too few bytes read");
    }
    return FAIL;
  }
  sd_reader->fpos += (size_t)skip_bytes;
  return OK;
}

/// Wrapper for read that can be used when lseek cannot be used
///
/// E.g. when trying to read from a pipe.
///
/// @param[in,out]  sd_reader  File read.
/// @param[in]      offset     Amount of bytes to skip.
///
/// @return kSDReadStatusReadError, kSDReadStatusNotShaDa or
///         kSDReadStatusSuccess.
static ShaDaReadResult sd_reader_skip(ShaDaReadDef *const sd_reader,
                                      const size_t offset)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  if (sd_reader->skip(sd_reader, offset) != OK) {
    if (sd_reader->error != NULL) {
      emsgf(_(SERR "System error while skipping in ShaDa file: %s"),
            sd_reader->error);
      return kSDReadStatusReadError;
    } else if (sd_reader->eof) {
      emsgf(_(RCERR "Error while reading ShaDa file: "
              "last entry specified that it occupies %" PRIu64 " bytes, "
              "but file ended earlier"),
            (uint64_t) offset);
      return kSDReadStatusNotShaDa;
    }
    assert(false);
  }
  return kSDReadStatusSuccess;
}

/// Open ShaDa file for reading
///
/// @param[in]   fname      File name to open.
/// @param[out]  sd_reader  Location where reader structure will be saved.
///
/// @return libuv error in case of error, 0 otherwise.
static int open_shada_file_for_reading(const char *const fname,
                                       ShaDaReadDef *sd_reader)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  int error;

  *sd_reader = (ShaDaReadDef) {
    .read = &read_file,
    .close = &close_sd_reader,
    .skip = &sd_reader_skip_read,
    .error = NULL,
    .eof = false,
    .fpos = 0,
    .cookie = file_open_new(&error, fname, kFileReadOnly, 0),
  };
  if (sd_reader->cookie == NULL) {
    return error;
  }

  assert(STRCMP(p_enc, "utf-8") == 0);

  return 0;
}

/// Wrapper for closing file descriptors
static void close_file(void *cookie)
{
  const int error = file_free(cookie, true);
  if (error != 0) {
    emsgf(_(SERR "System error while closing ShaDa file: %s"),
          os_strerror(error));
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

/// Msgpack callback for writing to ShaDaWriteDef*
static int msgpack_sd_writer_write(void *data, const char *buf, size_t len)
{
  ShaDaWriteDef *const sd_writer = (ShaDaWriteDef *) data;
  ptrdiff_t written_bytes = sd_writer->write(sd_writer, buf, len);
  if (written_bytes == -1) {
    emsgf(_(SERR "System error while writing ShaDa file: %s"),
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
/// @param[in]  flags  Flags, see ShaDaReadFileFlags enum.
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
    if (of_ret != UV_ENOENT || (flags & kShaDaMissingError)) {
      emsgf(_(SERR "System error while opening ShaDa file %s for reading: %s"),
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
/// Before the new entry entries from the current Neovim history will be
/// inserted unless `do_iter` argument is false.
///
/// @param[in,out]  hms_p           Ring buffer and associated structures.
/// @param[in]      entry           Inserted entry.
/// @param[in]      do_iter         Determines whether Neovim own history should
///                                 be used. Must be true only if inserting
///                                 entry from current Neovim history.
/// @param[in]      can_free_entry  True if entry can be freed.
static void hms_insert(HistoryMergerState *const hms_p, const ShadaEntry entry,
                       const bool do_iter, const bool can_free_entry)
  FUNC_ATTR_NONNULL_ALL
{
  if (do_iter) {
    while (hms_p->last_hist_entry.type != kSDItemMissing
           && hms_p->last_hist_entry.timestamp < entry.timestamp) {
      hms_insert(hms_p, hms_p->last_hist_entry, false, hms_p->reading);
      if (hms_p->iter == NULL) {
        hms_p->last_hist_entry.type = kSDItemMissing;
        break;
      }
      hms_p->iter = shada_hist_iter(hms_p->iter, hms_p->history_type,
                                    hms_p->reading, &hms_p->last_hist_entry);
    }
  }
  HMLList *const hmll = &hms_p->hmll;
  const khiter_t k = kh_get(hmll_entries, &hms_p->hmll.contained_entries,
                            entry.data.history_item.string);
  if (k != kh_end(&hmll->contained_entries)) {
    HMLListEntry *const existing_entry = kh_val(&hmll->contained_entries, k);
    if (entry.timestamp > existing_entry->data.timestamp) {
      hmll_remove(hmll, existing_entry);
    } else if (!do_iter && entry.timestamp == existing_entry->data.timestamp) {
      // Prefer entry from the current Neovim instance.
      if (existing_entry->can_free_entry) {
        shada_free_shada_entry(&existing_entry->data);
      }
      existing_entry->data = entry;
      existing_entry->can_free_entry = can_free_entry;
      // Previous key was freed above, as part of freeing the ShaDa entry.
      kh_key(&hmll->contained_entries, k) = entry.data.history_item.string;
      return;
    } else {
      return;
    }
  }
  HMLListEntry *insert_after;
  HMLL_ITER_BACK(hmll, insert_after, {
    if (insert_after->data.timestamp <= entry.timestamp) {
      break;
    }
  })
  hmll_insert(hmll, insert_after, entry, can_free_entry);
}

/// Initialize the history merger
///
/// @param[out]  hms_p         Structure to be initialized.
/// @param[in]   history_type  History type (one of HIST_\* values).
/// @param[in]   num_elements  Number of elements in the result.
/// @param[in]   do_merge      Prepare structure for merging elements.
/// @param[in]   reading       If true, then merger is reading history for use
///                            in Neovim.
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

/// Merge in all remaining Neovim own history entries
///
/// @param[in,out]  hms_p  Merger structure into which history should be
///                        inserted.
static inline void hms_insert_whole_neovim_history(
    HistoryMergerState *const hms_p)
  FUNC_ATTR_NONNULL_ALL
{
  while (hms_p->last_hist_entry.type != kSDItemMissing) {
    hms_insert(hms_p, hms_p->last_hist_entry, false, hms_p->reading);
    if (hms_p->iter == NULL) {
      break;
    }
    hms_p->iter = shada_hist_iter(hms_p->iter, hms_p->history_type,
                                  hms_p->reading, &hms_p->last_hist_entry);
  }
}

/// Convert merger structure to Neovim internal structure for history
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
  HMLL_FORALL(&hms_p->hmll, cur_entry,  {
    hist->timestamp = cur_entry->data.timestamp;
    hist->hisnum = (int) (hist - hist_array) + 1;
    hist->hisstr = (char_u *) cur_entry->data.data.history_item.string;
    hist->additional_elements =
        cur_entry->data.data.history_item.additional_elements;
    hist++;
  })
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
/// @param       code       Code to execute on each iteration.
///
/// @return for cycle header. Use `HMS_ITER(hms_p, cur_entry) {body}`.
#define HMS_ITER(hms_p, cur_entry, code) \
    HMLL_FORALL(&((hms_p)->hmll), cur_entry, code)

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

#define MERGE_JUMPS(jumps_size, jumps, jumps_type, timestamp_attr, mark_attr, \
                    entry, fname_cond, free_func, fin_func, \
                    idxadj_func, afterfree_func) \
  do { \
    const int jl_len = (int) jumps_size; \
    int i; \
    for (i = jl_len; i > 0; i--) { \
      const jumps_type jl_entry = jumps[i - 1]; \
      if (jl_entry.timestamp_attr <= entry.timestamp) { \
        if (marks_equal(jl_entry.mark_attr, entry.data.filemark.mark) \
            && fname_cond) { \
          i = -1; \
        } \
        break; \
      } \
    } \
    if (i > 0) { \
      if (jl_len == JUMPLISTSIZE) { \
        free_func(jumps[0]); \
        i--; \
        if (i > 0) { \
          memmove(&jumps[0], &jumps[1], sizeof(jumps[1]) * (size_t) i); \
        } \
      } else if (i != jl_len) { \
        memmove(&jumps[i + 1], &jumps[i], \
                sizeof(jumps[0]) * (size_t) (jl_len - i)); \
      } \
    } else if (i == 0) { \
      if (jl_len == JUMPLISTSIZE) { \
        i = -1; \
      } else if (jl_len > 0) { \
        memmove(&jumps[1], &jumps[0], sizeof(jumps[0]) * (size_t) jl_len); \
      } \
    } \
    if (i != -1) { \
      jumps[i] = fin_func(entry); \
      if (jl_len < JUMPLISTSIZE) { \
        jumps_size++; \
      } \
      idxadj_func(i); \
    } else { \
      shada_free_shada_entry(&entry); \
      afterfree_func(entry); \
    } \
  } while (0)

/// Read data from ShaDa file
///
/// @param[in]  sd_reader  Structure containing file reader definition.
/// @param[in]  flags      What to read, see ShaDaReadFileFlags enum.
static void shada_read(ShaDaReadDef *const sd_reader, const int flags)
  FUNC_ATTR_NONNULL_ALL
{
  list_T *oldfiles_list = get_vim_var_list(VV_OLDFILES);
  const bool force = flags & kShaDaForceit;
  const bool get_old_files = (flags & (kShaDaGetOldfiles | kShaDaForceit)
                              && (force || tv_list_len(oldfiles_list) == 0));
  const bool want_marks = flags & kShaDaWantMarks;
  const unsigned srni_flags = (unsigned) (
      (flags & kShaDaWantInfo
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
  khash_t(bufset) cl_bufs = KHASH_EMPTY_TABLE(bufset);
  khash_t(fnamebufs) fname_bufs = KHASH_EMPTY_TABLE(fnamebufs);
  khash_t(strset) oldfiles_set = KHASH_EMPTY_TABLE(strset);
  if (get_old_files && (oldfiles_list == NULL || force)) {
    oldfiles_list = tv_list_alloc(kListLenUnknown);
    set_vim_var_list(VV_OLDFILES, oldfiles_list);
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
             .dir = cur_entry.data.search_pattern.search_backward ? '?' : '/',
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
        // Without using regtilde and without / &cpo flag previous substitute
        // string is close to useless: you can only use it with :& or :~ and
        // that’s all because s//~ is not available until the first call to
        // regtilde. Vim was not calling this for some reason.
        (void) regtilde(cur_entry.data.sub_string.sub, p_magic);
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
        if (cur_entry.data.reg.type != kMTCharWise
            && cur_entry.data.reg.type != kMTLineWise
            && cur_entry.data.reg.type != kMTBlockWise) {
          shada_free_shada_entry(&cur_entry);
          break;
        }
        if (!force) {
          const yankreg_T *const reg = op_register_get(cur_entry.data.reg.name);
          if (reg == NULL || reg->timestamp >= cur_entry.timestamp) {
            shada_free_shada_entry(&cur_entry);
            break;
          }
        }
        if (!op_register_set(cur_entry.data.reg.name, (yankreg_T) {
          .y_array = (char_u **)cur_entry.data.reg.contents,
          .y_size = cur_entry.data.reg.contents_size,
          .y_type = cur_entry.data.reg.type,
          .y_width = (colnr_T) cur_entry.data.reg.width,
          .timestamp = cur_entry.timestamp,
          .additional_data = cur_entry.data.reg.additional_data,
        }, cur_entry.data.reg.is_unnamed)) {
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
        buf_T *buf = find_buffer(&fname_bufs, cur_entry.data.filemark.fname);
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
#define SDE_TO_XFMARK(entry) fm
#define ADJUST_IDX(i) \
          if (curwin->w_jumplistidx >= i \
              && curwin->w_jumplistidx + 1 <= curwin->w_jumplistlen) { \
            curwin->w_jumplistidx++; \
          }
#define DUMMY_AFTERFREE(entry)
          MERGE_JUMPS(curwin->w_jumplistlen, curwin->w_jumplist, xfmark_T,
                      fmark.timestamp, fmark.mark, cur_entry,
                      (buf == NULL
                       ? (jl_entry.fname != NULL
                          && STRCMP(fm.fname, jl_entry.fname) == 0)
                       : fm.fmark.fnum == jl_entry.fmark.fnum),
                      free_xfmark, SDE_TO_XFMARK, ADJUST_IDX, DUMMY_AFTERFREE);
#undef SDE_TO_XFMARK
#undef ADJUST_IDX
#undef DUMMY_AFTERFREE
        }
        // Do not free shada entry: its allocated memory was saved above.
        break;
      }
      case kSDItemBufferList: {
        for (size_t i = 0; i < cur_entry.data.buffer_list.size; i++) {
          char *const sfname = path_try_shorten_fname(
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
        if (get_old_files && !in_strset(&oldfiles_set,
                                        cur_entry.data.filemark.fname)) {
          char *fname = cur_entry.data.filemark.fname;
          if (want_marks) {
            // Do not bother with allocating memory for the string if already
            // allocated string from cur_entry can be used. It cannot be used if
            // want_marks is set because this way it may be used for a mark.
            fname = xstrdup(fname);
          }
          int kh_ret;
          (void)kh_put(strset, &oldfiles_set, fname, &kh_ret);
          tv_list_append_allocated_string(oldfiles_list, fname);
          if (!want_marks) {
            // Avoid free because this string was already used.
            cur_entry.data.filemark.fname = NULL;
          }
        }
        if (!want_marks) {
          shada_free_shada_entry(&cur_entry);
          break;
        }
        buf_T *buf = find_buffer(&fname_bufs, cur_entry.data.filemark.fname);
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
          (void) kh_put(bufset, &cl_bufs, (uintptr_t) buf, &kh_ret);
#define SDE_TO_FMARK(entry) fm
#define AFTERFREE(entry) (entry).data.filemark.fname = NULL
#define DUMMY_IDX_ADJ(i)
          MERGE_JUMPS(buf->b_changelistlen, buf->b_changelist, fmark_T,
                      timestamp, mark, cur_entry, true,
                      free_fmark, SDE_TO_FMARK, DUMMY_IDX_ADJ, AFTERFREE);
#undef SDE_TO_FMARK
#undef AFTERFREE
#undef DUMMY_IDX_ADJ
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
  //          from the history Neovim array will no longer be valid. To reduce
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
  if (cl_bufs.n_occupied) {
    FOR_ALL_TAB_WINDOWS(tp, wp) {
      (void) tp;
      if (in_bufset(&cl_bufs, wp->w_buffer)) {
        wp->w_changelistidx = wp->w_buffer->b_changelistlen;
      }
    }
  }
  kh_dealloc(bufset, &cl_bufs);
  const char *key;
  kh_foreach_key(&fname_bufs, key, {
    xfree((void *) key);
  })
  kh_dealloc(fnamebufs, &fname_bufs);
  kh_dealloc(strset, &oldfiles_set);
}

/// Default shada file location: cached path
static char *default_shada_file = NULL;

/// Get the default ShaDa file
static const char *shada_get_default_file(void)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (default_shada_file == NULL) {
    char *shada_dir = stdpaths_user_data_subpath("shada", 0, false);
    default_shada_file = concat_fnames_realloc(shada_dir, "main.shada", true);
  }
  return default_shada_file;
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
    } else {
      if ((file = find_shada_parameter('n')) == NULL || *file == NUL) {
        file =  shada_get_default_file();
      }
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
#define PACK_STRING(s) \
    do { \
      const String s_ = (s); \
      msgpack_pack_str(spacker, s_.size); \
      if (s_.size) { \
        msgpack_pack_str_body(spacker, s_.data, s_.size); \
      } \
    } while (0)
#define PACK_BIN(s) \
    do { \
      const String s_ = (s); \
      msgpack_pack_bin(spacker, s_.size); \
      if (s_.size > 0) { \
        msgpack_pack_bin_body(spacker, s_.data, s_.size); \
      } \
    } while (0)

/// Write single ShaDa entry
///
/// @param[in]  packer     Packer used to write entry.
/// @param[in]  entry      Entry written.
/// @param[in]  max_kbyte  Maximum size of an item in KiB. Zero means no
///                        restrictions.
///
/// @return kSDWriteSuccessfull, kSDWriteFailed or kSDWriteIgnError.
static ShaDaWriteResult shada_pack_entry(msgpack_packer *const packer,
                                         ShadaEntry entry,
                                         const size_t max_kbyte)
  FUNC_ATTR_NONNULL_ALL
{
  ShaDaWriteResult ret = kSDWriteFailed;
  msgpack_sbuffer sbuf;
  msgpack_sbuffer_init(&sbuf);
  msgpack_packer *spacker = msgpack_packer_new(&sbuf, &msgpack_sbuffer_write);
#define DUMP_ADDITIONAL_ELEMENTS(src, what) \
  do { \
    if ((src) != NULL) { \
      TV_LIST_ITER((src), li, { \
        if (encode_vim_to_msgpack(spacker, TV_LIST_ITEM_TV(li), \
                                  _("additional elements of ShaDa " what)) \
            == FAIL) { \
          goto shada_pack_entry_error; \
        } \
      }); \
    } \
  } while (0)
#define DUMP_ADDITIONAL_DATA(src, what) \
  do { \
    dict_T *const d = (src); \
    if (d != NULL) { \
      size_t todo = d->dv_hashtab.ht_used; \
      for (const hashitem_T *hi= d->dv_hashtab.ht_array; todo; hi++) { \
        if (!HASHITEM_EMPTY(hi)) { \
          todo--; \
          dictitem_T *const di = TV_DICT_HI2DI(hi); \
          const size_t key_len = strlen((const char *)hi->hi_key); \
          msgpack_pack_str(spacker, key_len); \
          msgpack_pack_str_body(spacker, (const char *)hi->hi_key, key_len); \
          if (encode_vim_to_msgpack(spacker, &di->di_tv, \
                                    _("additional data of ShaDa " what)) \
              == FAIL) { \
            goto shada_pack_entry_error; \
          } \
        } \
      } \
    } \
  } while (0)
#define CHECK_DEFAULT(entry, attr) \
  (sd_default_values[entry.type].data.attr == entry.data.attr)
#define ONE_IF_NOT_DEFAULT(entry, attr) \
  ((size_t) (!CHECK_DEFAULT(entry, attr)))
  switch (entry.type) {
    case kSDItemMissing: {
      assert(false);
    }
    case kSDItemUnknown: {
      if (spacker->callback(spacker->data, entry.data.unknown_item.contents,
                            (unsigned) entry.data.unknown_item.size) == -1) {
        goto shada_pack_entry_error;
      }
      break;
    }
    case kSDItemHistoryEntry: {
      const bool is_hist_search =
          entry.data.history_item.histtype == HIST_SEARCH;
      const size_t arr_size = 2 + (size_t)is_hist_search + (size_t)(
          tv_list_len(entry.data.history_item.additional_elements));
      msgpack_pack_array(spacker, arr_size);
      msgpack_pack_uint8(spacker, entry.data.history_item.histtype);
      PACK_BIN(cstr_as_string(entry.data.history_item.string));
      if (is_hist_search) {
        msgpack_pack_uint8(spacker, (uint8_t)entry.data.history_item.sep);
      }
      DUMP_ADDITIONAL_ELEMENTS(entry.data.history_item.additional_elements,
                               "history entry item");
      break;
    }
    case kSDItemVariable: {
      const size_t arr_size = 2 + (size_t)(
          tv_list_len(entry.data.global_var.additional_elements));
      msgpack_pack_array(spacker, arr_size);
      const String varname = cstr_as_string(entry.data.global_var.name);
      PACK_BIN(varname);
      char vardesc[256] = "variable g:";
      memcpy(&vardesc[sizeof("variable g:") - 1], varname.data,
             varname.size + 1);
      if (encode_vim_to_msgpack(spacker, &entry.data.global_var.value, vardesc)
          == FAIL) {
        ret = kSDWriteIgnError;
        EMSG2(_(WERR "Failed to write variable %s"),
              entry.data.global_var.name);
        goto shada_pack_entry_error;
      }
      DUMP_ADDITIONAL_ELEMENTS(entry.data.global_var.additional_elements,
                               "variable item");
      break;
    }
    case kSDItemSubString: {
      const size_t arr_size = 1 + (size_t)(
          tv_list_len(entry.data.sub_string.additional_elements));
      msgpack_pack_array(spacker, arr_size);
      PACK_BIN(cstr_as_string(entry.data.sub_string.sub));
      DUMP_ADDITIONAL_ELEMENTS(entry.data.sub_string.additional_elements,
                               "sub string item");
      break;
    }
    case kSDItemSearchPattern: {
      const size_t map_size = (size_t) (
          1  // Search pattern is always present
          + ONE_IF_NOT_DEFAULT(entry, search_pattern.magic)
          + ONE_IF_NOT_DEFAULT(entry, search_pattern.is_last_used)
          + ONE_IF_NOT_DEFAULT(entry, search_pattern.smartcase)
          + ONE_IF_NOT_DEFAULT(entry, search_pattern.has_line_offset)
          + ONE_IF_NOT_DEFAULT(entry, search_pattern.place_cursor_at_end)
          + ONE_IF_NOT_DEFAULT(entry, search_pattern.is_substitute_pattern)
          + ONE_IF_NOT_DEFAULT(entry, search_pattern.highlighted)
          + ONE_IF_NOT_DEFAULT(entry, search_pattern.offset)
          + ONE_IF_NOT_DEFAULT(entry, search_pattern.search_backward)
          // finally, additional data:
          + (size_t) (
              entry.data.search_pattern.additional_data
              ? entry.data.search_pattern.additional_data->dv_hashtab.ht_used
              : 0));
      msgpack_pack_map(spacker, map_size);
      PACK_STATIC_STR(SEARCH_KEY_PAT);
      PACK_BIN(cstr_as_string(entry.data.search_pattern.pat));
#define PACK_BOOL(entry, name, attr) \
      do { \
        if (!CHECK_DEFAULT(entry, search_pattern.attr)) { \
          PACK_STATIC_STR(name); \
          if (sd_default_values[entry.type].data.search_pattern.attr) { \
            msgpack_pack_false(spacker); \
          } else { \
            msgpack_pack_true(spacker); \
          } \
        } \
      } while (0)
      PACK_BOOL(entry, SEARCH_KEY_MAGIC, magic);
      PACK_BOOL(entry, SEARCH_KEY_IS_LAST_USED, is_last_used);
      PACK_BOOL(entry, SEARCH_KEY_SMARTCASE, smartcase);
      PACK_BOOL(entry, SEARCH_KEY_HAS_LINE_OFFSET, has_line_offset);
      PACK_BOOL(entry, SEARCH_KEY_PLACE_CURSOR_AT_END, place_cursor_at_end);
      PACK_BOOL(entry, SEARCH_KEY_IS_SUBSTITUTE_PATTERN, is_substitute_pattern);
      PACK_BOOL(entry, SEARCH_KEY_HIGHLIGHTED, highlighted);
      PACK_BOOL(entry, SEARCH_KEY_BACKWARD, search_backward);
      if (!CHECK_DEFAULT(entry, search_pattern.offset)) {
        PACK_STATIC_STR(SEARCH_KEY_OFFSET);
        msgpack_pack_int64(spacker, entry.data.search_pattern.offset);
      }
#undef PACK_BOOL
      DUMP_ADDITIONAL_DATA(entry.data.search_pattern.additional_data,
                           "search pattern item");
      break;
    }
    case kSDItemChange:
    case kSDItemGlobalMark:
    case kSDItemLocalMark:
    case kSDItemJump: {
      const size_t map_size = (size_t) (
          1  // File name
          + ONE_IF_NOT_DEFAULT(entry, filemark.mark.lnum)
          + ONE_IF_NOT_DEFAULT(entry, filemark.mark.col)
          + ONE_IF_NOT_DEFAULT(entry, filemark.name)
          // Additional entries, if any:
          + (size_t) (
              entry.data.filemark.additional_data == NULL
              ? 0
              : entry.data.filemark.additional_data->dv_hashtab.ht_used));
      msgpack_pack_map(spacker, map_size);
      PACK_STATIC_STR(KEY_FILE);
      PACK_BIN(cstr_as_string(entry.data.filemark.fname));
      if (!CHECK_DEFAULT(entry, filemark.mark.lnum)) {
        PACK_STATIC_STR(KEY_LNUM);
        msgpack_pack_long(spacker, entry.data.filemark.mark.lnum);
      }
      if (!CHECK_DEFAULT(entry, filemark.mark.col)) {
        PACK_STATIC_STR(KEY_COL);
        msgpack_pack_long(spacker, entry.data.filemark.mark.col);
      }
      assert(entry.type == kSDItemJump || entry.type == kSDItemChange
             ? CHECK_DEFAULT(entry, filemark.name)
             : true);
      if (!CHECK_DEFAULT(entry, filemark.name)) {
        PACK_STATIC_STR(KEY_NAME_CHAR);
        msgpack_pack_uint8(spacker, (uint8_t) entry.data.filemark.name);
      }
      DUMP_ADDITIONAL_DATA(entry.data.filemark.additional_data,
                           "mark (change, jump, global or local) item");
      break;
    }
    case kSDItemRegister: {
      const size_t map_size = (size_t) (
          2  // Register contents and name
          + ONE_IF_NOT_DEFAULT(entry, reg.type)
          + ONE_IF_NOT_DEFAULT(entry, reg.width)
          + ONE_IF_NOT_DEFAULT(entry, reg.is_unnamed)
          // Additional entries, if any:
          + (size_t) (entry.data.reg.additional_data == NULL
                      ? 0
                      : entry.data.reg.additional_data->dv_hashtab.ht_used));
      msgpack_pack_map(spacker, map_size);
      PACK_STATIC_STR(REG_KEY_CONTENTS);
      msgpack_pack_array(spacker, entry.data.reg.contents_size);
      for (size_t i = 0; i < entry.data.reg.contents_size; i++) {
        PACK_BIN(cstr_as_string(entry.data.reg.contents[i]));
      }
      PACK_STATIC_STR(KEY_NAME_CHAR);
      msgpack_pack_char(spacker, entry.data.reg.name);
      if (!CHECK_DEFAULT(entry, reg.type)) {
        PACK_STATIC_STR(REG_KEY_TYPE);
        msgpack_pack_uint8(spacker, (uint8_t)entry.data.reg.type);
      }
      if (!CHECK_DEFAULT(entry, reg.width)) {
        PACK_STATIC_STR(REG_KEY_WIDTH);
        msgpack_pack_uint64(spacker, (uint64_t) entry.data.reg.width);
      }
      if (!CHECK_DEFAULT(entry, reg.is_unnamed)) {
        PACK_STATIC_STR(REG_KEY_UNNAMED);
        if (entry.data.reg.is_unnamed) {
          msgpack_pack_true(spacker);
        } else {
          msgpack_pack_false(spacker);
        }
      }
      DUMP_ADDITIONAL_DATA(entry.data.reg.additional_data, "register item");
      break;
    }
    case kSDItemBufferList: {
      msgpack_pack_array(spacker, entry.data.buffer_list.size);
      for (size_t i = 0; i < entry.data.buffer_list.size; i++) {
        const size_t map_size = (size_t) (
            1  // Buffer name
            + (size_t) (entry.data.buffer_list.buffers[i].pos.lnum
                        != default_pos.lnum)
            + (size_t) (entry.data.buffer_list.buffers[i].pos.col
                        != default_pos.col)
            // Additional entries, if any:
            + (size_t) (
                entry.data.buffer_list.buffers[i].additional_data == NULL
                ? 0
                : (entry.data.buffer_list.buffers[i].additional_data
                   ->dv_hashtab.ht_used)));
        msgpack_pack_map(spacker, map_size);
        PACK_STATIC_STR(KEY_FILE);
        PACK_BIN(cstr_as_string(entry.data.buffer_list.buffers[i].fname));
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
        DUMP_ADDITIONAL_DATA(entry.data.buffer_list.buffers[i].additional_data,
                             "buffer list subitem");
      }
      break;
    }
    case kSDItemHeader: {
      msgpack_pack_map(spacker, entry.data.header.size);
      for (size_t i = 0; i < entry.data.header.size; i++) {
        PACK_STRING(entry.data.header.items[i].key);
        const Object obj = entry.data.header.items[i].value;
        switch (obj.type) {
          case kObjectTypeString: {
            PACK_BIN(obj.data.string);
            break;
          }
          case kObjectTypeInteger: {
            msgpack_pack_int64(spacker, (int64_t) obj.data.integer);
            break;
          }
          default: {
            assert(false);
          }
        }
      }
      break;
    }
  }
#undef CHECK_DEFAULT
#undef ONE_IF_NOT_DEFAULT
  if (!max_kbyte || sbuf.size <= max_kbyte * 1024) {
    if (entry.type == kSDItemUnknown) {
      if (msgpack_pack_uint64(packer, entry.data.unknown_item.type) == -1) {
        goto shada_pack_entry_error;
      }
    } else {
      if (msgpack_pack_uint64(packer, (uint64_t) entry.type) == -1) {
        goto shada_pack_entry_error;
      }
    }
    if (msgpack_pack_uint64(packer, (uint64_t) entry.timestamp) == -1) {
      goto shada_pack_entry_error;
    }
    if (sbuf.size > 0) {
      if ((msgpack_pack_uint64(packer, (uint64_t) sbuf.size) == -1)
          || (packer->callback(packer->data, sbuf.data,
                               (unsigned) sbuf.size) == -1)) {
        goto shada_pack_entry_error;
      }
    }
  }
  msgpack_packer_free(spacker);
  msgpack_sbuffer_destroy(&sbuf);
  return kSDWriteSuccessfull;
shada_pack_entry_error:
  msgpack_packer_free(spacker);
  msgpack_sbuffer_destroy(&sbuf);
  return ret;
}
#undef PACK_STRING

/// Write single ShaDa entry and free it afterwards
///
/// Will not free if entry could not be freed.
///
/// @param[in]  packer     Packer used to write entry.
/// @param[in]  entry      Entry written.
/// @param[in]  max_kbyte  Maximum size of an item in KiB. Zero means no
///                        restrictions.
static inline ShaDaWriteResult shada_pack_pfreed_entry(
    msgpack_packer *const packer, PossiblyFreedShadaEntry entry,
    const size_t max_kbyte)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_ALWAYS_INLINE
{
  ShaDaWriteResult ret = kSDWriteSuccessfull;
  ret = shada_pack_entry(packer, entry.data, max_kbyte);
  if (entry.can_free_entry) {
    shada_free_shada_entry(&entry.data);
  }
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

/// Parse msgpack object that has given length
///
/// @param[in]   sd_reader     Structure containing file reader definition.
/// @param[in]   length        Object length.
/// @param[out]  ret_unpacked  Location where read result should be saved. If
///                            NULL then unpacked data will be freed. Must be
///                            NULL if `ret_buf` is NULL.
/// @param[out]  ret_buf       Buffer containing parsed string.
///
/// @return kSDReadStatusNotShaDa, kSDReadStatusReadError or
///         kSDReadStatusSuccess.
static inline ShaDaReadResult shada_parse_msgpack(
    ShaDaReadDef *const sd_reader, const size_t length,
    msgpack_unpacked *ret_unpacked, char **const ret_buf)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(1)
{
  const uintmax_t initial_fpos = sd_reader->fpos;
  char *const buf = xmalloc(length);

  const ShaDaReadResult fl_ret = fread_len(sd_reader, buf, length);
  if (fl_ret != kSDReadStatusSuccess) {
    xfree(buf);
    return fl_ret;
  }
  bool did_try_to_free = false;
shada_parse_msgpack_read_next: {}
  size_t off = 0;
  msgpack_unpacked unpacked;
  msgpack_unpacked_init(&unpacked);
  const msgpack_unpack_return result =
      msgpack_unpack_next(&unpacked, buf, length, &off);
  ShaDaReadResult ret = kSDReadStatusSuccess;
  switch (result) {
    case MSGPACK_UNPACK_SUCCESS: {
      if (off < length) {
        goto shada_parse_msgpack_extra_bytes;
      }
      break;
    }
    case MSGPACK_UNPACK_PARSE_ERROR: {
      emsgf(_(RCERR "Failed to parse ShaDa file due to a msgpack parser error "
              "at position %" PRIu64),
            (uint64_t) initial_fpos);
      ret = kSDReadStatusNotShaDa;
      break;
    }
    case MSGPACK_UNPACK_NOMEM_ERROR: {
      if (!did_try_to_free) {
        did_try_to_free = true;
        try_to_free_memory();
        goto shada_parse_msgpack_read_next;
      }
      EMSG(_(e_outofmem));
      ret = kSDReadStatusReadError;
      break;
    }
    case MSGPACK_UNPACK_CONTINUE: {
      emsgf(_(RCERR "Failed to parse ShaDa file: incomplete msgpack string "
              "at position %" PRIu64),
            (uint64_t) initial_fpos);
      ret = kSDReadStatusNotShaDa;
      break;
    }
    case MSGPACK_UNPACK_EXTRA_BYTES: {
shada_parse_msgpack_extra_bytes:
      emsgf(_(RCERR "Failed to parse ShaDa file: extra bytes in msgpack string "
              "at position %" PRIu64),
            (uint64_t) initial_fpos);
      ret = kSDReadStatusNotShaDa;
      break;
    }
  }
  if (ret_buf != NULL && ret == kSDReadStatusSuccess) {
    if (ret_unpacked == NULL) {
      msgpack_unpacked_destroy(&unpacked);
    } else {
      *ret_unpacked = unpacked;
    }
    *ret_buf = buf;
  } else {
    assert(ret_buf == NULL || ret != kSDReadStatusSuccess);
    msgpack_unpacked_destroy(&unpacked);
    xfree(buf);
  }
  return ret;
}

/// Read and merge in ShaDa file, used when writing
///
/// @param[in]      sd_reader   Structure containing file reader definition.
/// @param[in]      srni_flags  Flags determining what to read.
/// @param[in]      max_kbyte   Maximum size of one element.
/// @param[in,out]  ret_wms     Location where results are saved.
/// @param[out]     packer      MessagePack packer for entries which are not
///                             merged.
static inline ShaDaWriteResult shada_read_when_writing(
    ShaDaReadDef *const sd_reader, const unsigned srni_flags,
    const size_t max_kbyte, WriteMergerState *const wms,
    msgpack_packer *const packer)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  ShaDaWriteResult ret = kSDWriteSuccessfull;
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
        FALLTHROUGH;
      }
      case kSDReadStatusReadError: {
        return ret;
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
        ret = shada_pack_entry(packer, entry, 0);
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
          ret = shada_pack_entry(packer, entry, 0);
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
          ret = shada_pack_entry(packer, entry, 0);
          shada_free_shada_entry(&entry);
          break;
        }
        COMPARE_WITH_ENTRY(&wms->registers[idx], entry);
        break;
      }
      case kSDItemVariable: {
        if (!in_strset(&wms->dumped_variables, entry.data.global_var.name)) {
          ret = shada_pack_entry(packer, entry, 0);
        }
        shada_free_shada_entry(&entry);
        break;
      }
      case kSDItemGlobalMark: {
        const int idx = mark_global_index(entry.data.filemark.name);
        if (idx < 0) {
          ret = shada_pack_entry(packer, entry, 0);
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
            PossiblyFreedShadaEntry *const wms_entry = &filemarks->marks[idx];
            if (wms_entry->data.type != kSDItemMissing) {
              if (wms_entry->data.timestamp >= entry.timestamp) {
                shada_free_shada_entry(&entry);
                break;
              }
              if (wms_entry->can_free_entry) {
                if (kh_key(&wms->file_marks, k)
                    == wms_entry->data.data.filemark.fname) {
                  kh_key(&wms->file_marks, k) = entry.data.filemark.fname;
                }
                shada_free_shada_entry(&wms_entry->data);
              }
            }
            wms_entry->can_free_entry = true;
            wms_entry->data = entry;
          }
        } else {
#define FREE_POSSIBLY_FREED_SHADA_ENTRY(entry) \
        do { \
          if (entry.can_free_entry) { \
            shada_free_shada_entry(&entry.data); \
          } \
        } while (0)
#define SDE_TO_PFSDE(entry) \
        ((PossiblyFreedShadaEntry) { .can_free_entry = true, .data = entry })
#define AFTERFREE_DUMMY(entry)
#define DUMMY_IDX_ADJ(i)
          MERGE_JUMPS(filemarks->changes_size, filemarks->changes,
                      PossiblyFreedShadaEntry, data.timestamp,
                      data.data.filemark.mark, entry, true,
                      FREE_POSSIBLY_FREED_SHADA_ENTRY, SDE_TO_PFSDE,
                      DUMMY_IDX_ADJ, AFTERFREE_DUMMY);
        }
        break;
      }
      case kSDItemJump: {
        MERGE_JUMPS(wms->jumps_size, wms->jumps, PossiblyFreedShadaEntry,
                    data.timestamp, data.data.filemark.mark, entry,
                    strcmp(jl_entry.data.data.filemark.fname,
                           entry.data.filemark.fname) == 0,
                    FREE_POSSIBLY_FREED_SHADA_ENTRY, SDE_TO_PFSDE,
                    DUMMY_IDX_ADJ, AFTERFREE_DUMMY);
#undef FREE_POSSIBLY_FREED_SHADA_ENTRY
#undef SDE_TO_PFSDE
#undef DUMMY_IDX_ADJ
#undef AFTERFREE_DUMMY
        break;
      }
    }
  }
#undef COMPARE_WITH_ENTRY
  return ret;
}

/// Get list of buffers to write to the shada file
///
/// @param[in]  removable_bufs  Buffers which are ignored
///
/// @return  ShadaEntry  List of buffers to save, kSDItemBufferList entry.
static inline ShadaEntry shada_get_buflist(
    khash_t(bufset) *const removable_bufs)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_ALWAYS_INLINE
{
  int max_bufs = get_shada_parameter('%');
  size_t buf_count = 0;
#define IGNORE_BUF(buf)\
  (buf->b_ffname == NULL || !buf->b_p_bl || bt_quickfix(buf) \
   || in_bufset(removable_bufs, buf))  // NOLINT(whitespace/indent)
  FOR_ALL_BUFFERS(buf) {
    if (!IGNORE_BUF(buf) && (max_bufs < 0 || buf_count < (size_t)max_bufs)) {
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
    if (IGNORE_BUF(buf)) {
      continue;
    }
    if (i >= buf_count) {
      break;
    }
    buflist_entry.data.buffer_list.buffers[i] = (struct buffer_list_buffer) {
      .pos = buf->b_last_cursor.mark,
        .fname = (char *)buf->b_ffname,
        .additional_data = buf->additional_data,
    };
    i++;
  }

#undef IGNORE_BUF
  return buflist_entry;
}

/// Save search pattern to PossiblyFreedShadaEntry
///
/// @param[out]  ret_pse  Location where result will be saved.
/// @param[in]  get_pattern  Function used to get pattern.
/// @param[in]  is_substitute_pattern  True if pattern in question is substitute
///                                    pattern. Also controls whether some
///                                    fields should be initialized to default
///                                    or values from get_pattern.
/// @param[in]  search_last_used  Result of search_was_last_used().
/// @param[in]  search_highlighted  True if search pattern was highlighted by
///                                 &hlsearch and this information should be
///                                 saved.
static inline void add_search_pattern(PossiblyFreedShadaEntry *const ret_pse,
                                      const SearchPatternGetter get_pattern,
                                      const bool is_substitute_pattern,
                                      const bool search_last_used,
                                      const bool search_highlighted)
  FUNC_ATTR_ALWAYS_INLINE
{
  const ShadaEntry defaults = sd_default_values[kSDItemSearchPattern];
  SearchPattern pat;
  get_pattern(&pat);
  if (pat.pat != NULL) {
    *ret_pse = (PossiblyFreedShadaEntry) {
      .can_free_entry = false,
      .data = {
        .type = kSDItemSearchPattern,
        .timestamp = pat.timestamp,
        .data = {
          .search_pattern = {
            .magic = pat.magic,
            .smartcase = !pat.no_scs,
            .has_line_offset = (is_substitute_pattern
                                ? defaults.data.search_pattern.has_line_offset
                                : pat.off.line),
            .place_cursor_at_end = (
                is_substitute_pattern
                ? defaults.data.search_pattern.place_cursor_at_end
                : pat.off.end),
            .offset = (is_substitute_pattern
                       ? defaults.data.search_pattern.offset
                       : pat.off.off),
            .is_last_used = (is_substitute_pattern ^ search_last_used),
            .is_substitute_pattern = is_substitute_pattern,
            .highlighted = ((is_substitute_pattern ^ search_last_used)
                            && search_highlighted),
            .pat = (char *)pat.pat,
            .additional_data = pat.additional_data,
            .search_backward = (!is_substitute_pattern && pat.off.dir == '?'),
          }
        }
      }
    };
  }
}

/// Initialize registers for writing to the ShaDa file
///
/// @param[in]  wms  The WriteMergerState used when writing.
/// @param[in]  max_reg_lines  The maximum number of register lines.
static inline void shada_initialize_registers(WriteMergerState *const wms,
                                              int max_reg_lines)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_ALWAYS_INLINE
{
  const void *reg_iter = NULL;
  const bool limit_reg_lines = max_reg_lines >= 0;
  do {
    yankreg_T reg;
    char name = NUL;
    bool is_unnamed = false;
    reg_iter = op_register_iter(reg_iter, &name, &reg, &is_unnamed);
    if (name == NUL) {
      break;
    }
    if (limit_reg_lines && reg.y_size > (size_t)max_reg_lines) {
      continue;
    }
    wms->registers[op_reg_index(name)] = (PossiblyFreedShadaEntry) {
      .can_free_entry = false,
      .data = {
        .type = kSDItemRegister,
        .timestamp = reg.timestamp,
        .data = {
          .reg = {
            .contents = (char **)reg.y_array,
            .contents_size = (size_t)reg.y_size,
            .type = reg.y_type,
            .width = (size_t)(reg.y_type == kMTBlockWise ? reg.y_width : 0),
            .additional_data = reg.additional_data,
            .name = name,
            .is_unnamed = is_unnamed,
          }
        }
      }
    };
  } while (reg_iter != NULL);
}

/// Write ShaDa file
///
/// @param[in]  sd_writer  Structure containing file writer definition.
/// @param[in]  sd_reader  Structure containing file reader definition. If it is
///                        not NULL then contents of this file will be merged
///                        with current Neovim runtime.
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
  const bool dump_registers = (max_reg_lines != 0);
  khash_t(bufset) removable_bufs = KHASH_EMPTY_TABLE(bufset);
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

  const unsigned srni_flags = (unsigned) (
      kSDReadUndisableableData
      | kSDReadUnknown
      | (dump_history ? kSDReadHistory : 0)
      | (dump_registers ? kSDReadRegisters : 0)
      | (dump_global_vars ? kSDReadVariables : 0)
      | (dump_global_marks ? kSDReadGlobalMarks : 0)
      | (num_marked_files ? kSDReadLocalMarks | kSDReadChanges : 0));

  msgpack_packer *const packer = msgpack_packer_new(sd_writer,
                                                    &msgpack_sd_writer_write);

  // Set b_last_cursor for all the buffers that have a window.
  //
  // It is needed to correctly save '"' mark on exit. Has a side effect of
  // setting '"' mark in all windows on :wshada to the current cursor
  // position (basically what :wviminfo used to do).
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    set_last_cursor(wp);
  }

  FOR_ALL_BUFFERS(buf) {
    if (buf->b_ffname != NULL && shada_removable((char *) buf->b_ffname)) {
      int kh_ret;
      (void) kh_put(bufset, &removable_bufs, (uintptr_t) buf, &kh_ret);
    }
  }

  // Write header
  if (shada_pack_entry(packer, (ShadaEntry) {
    .type = kSDItemHeader,
    .timestamp = os_time(),
    .data = {
      .header = {
        .size = 5,
        .capacity = 5,
        .items = ((KeyValuePair[]) {
          { STATIC_CSTR_AS_STRING("generator"),
            STRING_OBJ(STATIC_CSTR_AS_STRING("nvim")) },
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
  }, 0) == kSDWriteFailed) {
    ret = kSDWriteFailed;
    goto shada_write_exit;
  }

  // Write buffer list
  if (find_shada_parameter('%') != NULL) {
    ShadaEntry buflist_entry = shada_get_buflist(&removable_bufs);
    if (shada_pack_entry(packer, buflist_entry, 0) == kSDWriteFailed) {
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
      const char *name = NULL;
      var_iter = var_shada_iter(var_iter, &name, &vartv);
      if (name == NULL) {
        break;
      }
      typval_T tgttv;
      tv_copy(&vartv, &tgttv);
      ShaDaWriteResult spe_ret;
      if ((spe_ret = shada_pack_entry(packer, (ShadaEntry) {
        .type = kSDItemVariable,
        .timestamp = cur_timestamp,
        .data = {
          .global_var = {
            .name = (char *) name,
            .value = tgttv,
            .additional_elements = NULL,
          }
        }
      }, max_kbyte)) == kSDWriteFailed) {
        tv_clear(&vartv);
        tv_clear(&tgttv);
        ret = kSDWriteFailed;
        goto shada_write_exit;
      }
      tv_clear(&vartv);
      tv_clear(&tgttv);
      if (spe_ret == kSDWriteSuccessfull) {
        int kh_ret;
        (void) kh_put(strset, &wms->dumped_variables, name, &kh_ret);
      }
    } while (var_iter != NULL);
  }

  const bool search_highlighted = !(no_hlsearch
                                    || find_shada_parameter('h') != NULL);
  const bool search_last_used = search_was_last_used();

  // Initialize search pattern
  add_search_pattern(&wms->search_pattern, &get_search_pattern, false,
                     search_last_used, search_highlighted);

  // Initialize substitute search pattern
  add_search_pattern(&wms->sub_search_pattern, &get_substitute_pattern, true,
                     search_last_used, search_highlighted);

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
  setpcmark();
  cleanup_jumplist();
  do {
    xfmark_T fm;
    jump_iter = mark_jumplist_iter(jump_iter, curwin, &fm);

    if (fm.fmark.mark.lnum == 0) {
      iemsgf("ShaDa: mark lnum zero (ji:%p, js:%p, len:%i)",
             (void *)jump_iter, (void *)&curwin->w_jumplist[0],
             curwin->w_jumplistlen);
      continue;
    }
    const buf_T *const buf = (fm.fmark.fnum == 0
                              ? NULL
                              : buflist_findnr(fm.fmark.fnum));
    if (buf != NULL
        ? in_bufset(&removable_bufs, buf)
        : fm.fmark.fnum != 0) {
      continue;
    }
    const char *const fname = (char *) (fm.fmark.fnum == 0
                                        ? (fm.fname == NULL ? NULL : fm.fname)
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
      char name = NUL;
      xfmark_T fm;
      global_mark_iter = mark_global_iter(global_mark_iter, &name, &fm);
      if (name == NUL) {
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
        if (buf == NULL || buf->b_ffname == NULL
            || in_bufset(&removable_bufs, buf)) {
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
    } while (global_mark_iter != NULL);
  }

  // Initialize registers
  if (dump_registers) {
    shada_initialize_registers(wms, max_reg_lines);
  }

  // Initialize buffers
  if (num_marked_files > 0) {
    FOR_ALL_BUFFERS(buf) {
      if (buf->b_ffname == NULL || in_bufset(&removable_bufs, buf)) {
        continue;
      }
      const void *local_marks_iter = NULL;
      const char *const fname = (const char *) buf->b_ffname;
      khiter_t k;
      int kh_ret;
      k = kh_put(file_marks, &wms->file_marks, fname, &kh_ret);
      FileMarks *const filemarks = &kh_val(&wms->file_marks, k);
      if (kh_ret > 0) {
        memset(filemarks, 0, sizeof(*filemarks));
      }
      do {
        fmark_T fm;
        char name = NUL;
        local_marks_iter = mark_buffer_iter(local_marks_iter, buf, &name, &fm);
        if (name == NUL) {
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
      } while (local_marks_iter != NULL);
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

  if (sd_reader != NULL) {
    const ShaDaWriteResult srww_ret = shada_read_when_writing(
        sd_reader, srni_flags, max_kbyte, wms, packer);
    if (srww_ret != kSDWriteSuccessfull) {
      ret = srww_ret;
    }
  }

  // Write the rest
#define PACK_WMS_ARRAY(wms_array) \
  do { \
    for (size_t i_ = 0; i_ < ARRAY_SIZE(wms_array); i_++) { \
      if (wms_array[i_].data.type != kSDItemMissing) { \
        if (shada_pack_pfreed_entry(packer, wms_array[i_], max_kbyte) \
            == kSDWriteFailed) { \
          ret = kSDWriteFailed; \
          goto shada_write_exit; \
        } \
      } \
    } \
  } while (0)
  PACK_WMS_ARRAY(wms->global_marks);
  PACK_WMS_ARRAY(wms->registers);
  for (size_t i = 0; i < wms->jumps_size; i++) {
    if (shada_pack_pfreed_entry(packer, wms->jumps[i], max_kbyte)
        == kSDWriteFailed) {
      ret = kSDWriteFailed;
      goto shada_write_exit;
    }
  }
#define PACK_WMS_ENTRY(wms_entry) \
  do { \
    if (wms_entry.data.type != kSDItemMissing) { \
      if (shada_pack_pfreed_entry(packer, wms_entry, max_kbyte) \
          == kSDWriteFailed) { \
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
  for (khint_t i = kh_begin(&wms->file_marks); i != kh_end(&wms->file_marks);
       i++) {
    if (kh_exist(&wms->file_marks, i)) {
      *cur_file_marks++ = &kh_val(&wms->file_marks, i);
    }
  }
  qsort((void *) all_file_markss, file_markss_size, sizeof(*all_file_markss),
        &compare_file_marks);
  const size_t file_markss_to_dump = MIN(num_marked_files, file_markss_size);
  for (size_t i = 0; i < file_markss_to_dump; i++) {
    PACK_WMS_ARRAY(all_file_markss[i]->marks);
    for (size_t j = 0; j < all_file_markss[i]->changes_size; j++) {
      if (shada_pack_pfreed_entry(packer, all_file_markss[i]->changes[j],
                                  max_kbyte) == kSDWriteFailed) {
        ret = kSDWriteFailed;
        goto shada_write_exit;
      }
    }
    for (size_t j = 0; j < all_file_markss[i]->additional_marks_size; j++) {
      if (shada_pack_entry(packer, all_file_markss[i]->additional_marks[j],
                           0) == kSDWriteFailed) {
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
        HMS_ITER(&wms->hms[i], cur_entry, {
          if (shada_pack_pfreed_entry(
              packer, (PossiblyFreedShadaEntry) {
                .data = cur_entry->data,
                .can_free_entry = cur_entry->can_free_entry,
              }, max_kbyte) == kSDWriteFailed) {
            ret = kSDWriteFailed;
            break;
          }
        })
        if (ret == kSDWriteFailed) {
          goto shada_write_exit;
        }
      }
    }
  }

shada_write_exit:
  for (size_t i = 0; i < HIST_COUNT; i++) {
    if (dump_one_history[i]) {
      hms_dealloc(&wms->hms[i]);
    }
  }
  kh_dealloc(file_marks, &wms->file_marks);
  kh_dealloc(bufset, &removable_bufs);
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
  if (shada_disabled()) {
    return FAIL;
  }

  char *const fname = shada_filename(file);
  char *tempname = NULL;
  ShaDaWriteDef sd_writer = {
    .write = &write_file,
    .close = &close_sd_writer,
    .error = NULL,
  };
  ShaDaReadDef sd_reader = { .close = NULL };

  if (!nomerge) {
    int error;
    if ((error = open_shada_file_for_reading(fname, &sd_reader)) != 0) {
      if (error != UV_ENOENT) {
        emsgf(_(SERR "System error while opening ShaDa file %s for reading "
                "to merge before writing it: %s"),
              fname, os_strerror(error));
        // Try writing the file even if opening it emerged any issues besides
        // file not existing: maybe writing will succeed nevertheless.
      }
      nomerge = true;
      goto shada_write_file_nomerge;
    }
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
shada_write_file_open: {}
    sd_writer.cookie = file_open_new(
        &error, tempname, kFileCreateOnly|kFileNoSymlink, perm);
    if (sd_writer.cookie == NULL) {
      if (error == UV_EEXIST || error == UV_ELOOP) {
        // File already exists, try another name
        char *const wp = tempname + strlen(tempname) - 1;
        if (*wp == 'z') {
          // Tried names from .tmp.a to .tmp.z, all failed. Something must be
          // wrong then.
          EMSG2(_("E138: All %s.tmp.X files exist, cannot write ShaDa file!"),
                fname);
          xfree(fname);
          xfree(tempname);
          assert(sd_reader.close != NULL);
          sd_reader.close(&sd_reader);
          return FAIL;
        } else {
          (*wp)++;
          goto shada_write_file_open;
        }
      } else {
        emsgf(_(SERR "System error while opening temporary ShaDa file %s "
                "for writing: %s"), tempname, os_strerror(error));
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
    int error;
    sd_writer.cookie = file_open_new(&error, fname, kFileCreate|kFileTruncate,
                                     0600);
    if (sd_writer.cookie == NULL) {
      emsgf(_(SERR "System error while opening ShaDa file %s for writing: %s"),
            fname, os_strerror(error));
    }
  }

  if (sd_writer.cookie == NULL) {
    xfree(fname);
    xfree(tempname);
    if (sd_reader.cookie != NULL) {
      sd_reader.close(&sd_reader);
    }
    return FAIL;
  }

  if (p_verbose > 0) {
    verbose_enter();
    smsg(_("Writing ShaDa file \"%s\""), fname);
    verbose_leave();
  }

  const ShaDaWriteResult sw_ret = shada_write(&sd_writer, (nomerge
                                                           ? NULL
                                                           : &sd_reader));
  assert(sw_ret != kSDWriteIgnError);
  if (!nomerge) {
    sd_reader.close(&sd_reader);
    bool did_remove = false;
    if (sw_ret == kSDWriteSuccessfull) {
#ifdef UNIX
      // For Unix we check the owner of the file.  It's not very nice to
      // overwrite a user’s viminfo file after a "su root", with a
      // viminfo file that the user can't read.
      FileInfo old_info;
      if (os_fileinfo((char *)fname, &old_info)) {
        if (getuid() == ROOT_UID) {
          if (old_info.stat.st_uid != ROOT_UID
              || old_info.stat.st_gid != getgid()) {
            const uv_uid_t old_uid = (uv_uid_t)old_info.stat.st_uid;
            const uv_gid_t old_gid = (uv_gid_t)old_info.stat.st_gid;
            const int fchown_ret = os_fchown(file_fd(sd_writer.cookie),
                                             old_uid, old_gid);
            if (fchown_ret != 0) {
              EMSG3(_(RNERR "Failed setting uid and gid for file %s: %s"),
                    tempname, os_strerror(fchown_ret));
              goto shada_write_file_did_not_remove;
            }
          }
        } else if (!(old_info.stat.st_uid == getuid()
                     ? (old_info.stat.st_mode & 0200)
                     : (old_info.stat.st_gid == getgid()
                        ? (old_info.stat.st_mode & 0020)
                        : (old_info.stat.st_mode & 0002)))) {
          EMSG2(_("E137: ShaDa file is not writable: %s"), fname);
          goto shada_write_file_did_not_remove;
        }
      }
#endif
      if (vim_rename(tempname, fname) == -1) {
        EMSG3(_(RNERR "Can't rename ShaDa file from %s to %s!"),
              tempname, fname);
      } else {
        did_remove = true;
        os_remove(tempname);
      }
    } else {
      if (sw_ret == kSDWriteReadNotShada) {
        EMSG3(_(RNERR "Did not rename %s because %s "
                "does not look like a ShaDa file"), tempname, fname);
      } else {
        EMSG3(_(RNERR "Did not rename %s to %s because there were errors "
                "during writing it"), tempname, fname);
      }
    }
    if (!did_remove) {
#ifdef UNIX
shada_write_file_did_not_remove:
#endif
      EMSG3(_(RNERR "Do not forget to remove %s or rename it manually to %s."),
            tempname, fname);
    }
    xfree(tempname);
  }
  sd_writer.close(&sd_writer);

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
///                      over current Neovim state).
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
      tv_dict_unref(entry->data.filemark.additional_data);
      xfree(entry->data.filemark.fname);
      break;
    }
    case kSDItemSearchPattern: {
      tv_dict_unref(entry->data.search_pattern.additional_data);
      xfree(entry->data.search_pattern.pat);
      break;
    }
    case kSDItemRegister: {
      tv_dict_unref(entry->data.reg.additional_data);
      for (size_t i = 0; i < entry->data.reg.contents_size; i++) {
        xfree(entry->data.reg.contents[i]);
      }
      xfree(entry->data.reg.contents);
      break;
    }
    case kSDItemHistoryEntry: {
      tv_list_unref(entry->data.history_item.additional_elements);
      xfree(entry->data.history_item.string);
      break;
    }
    case kSDItemVariable: {
      tv_list_unref(entry->data.global_var.additional_elements);
      xfree(entry->data.global_var.name);
      tv_clear(&entry->data.global_var.value);
      break;
    }
    case kSDItemSubString: {
      tv_list_unref(entry->data.sub_string.additional_elements);
      xfree(entry->data.sub_string.sub);
      break;
    }
    case kSDItemBufferList: {
      for (size_t i = 0; i < entry->data.buffer_list.size; i++) {
        xfree(entry->data.buffer_list.buffers[i].fname);
        tv_dict_unref(entry->data.buffer_list.buffers[i].additional_data);
      }
      xfree(entry->data.buffer_list.buffers);
      break;
    }
  }
}

#ifndef HAVE_BE64TOH
static inline uint64_t be64toh(uint64_t big_endian_64_bits)
{
#ifdef ORDER_BIG_ENDIAN
  return big_endian_64_bits;
#else
  // It may appear that when !defined(ORDER_BIG_ENDIAN) actual order is big
  // endian. This variant is suboptimal, but it works regardless of actual
  // order.
  uint8_t *buf = (uint8_t *) &big_endian_64_bits;
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
/// @param[out]  buffer     Where to save the results.
/// @param[in]   length     How many bytes should be read.
///
/// @return kSDReadStatusSuccess if everything was OK, kSDReadStatusNotShaDa if
///         there were not enough bytes to read or kSDReadStatusReadError if
///         there was some error while reading.
static ShaDaReadResult fread_len(ShaDaReadDef *const sd_reader,
                                 char *const buffer,
                                 const size_t length)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const ptrdiff_t read_bytes = sd_reader->read(sd_reader, buffer, length);

  if (read_bytes != (ptrdiff_t)length) {
    if (sd_reader->error != NULL) {
      emsgf(_(SERR "System error while reading ShaDa file: %s"),
            sd_reader->error);
      return kSDReadStatusReadError;
    } else {
      emsgf(_(RCERR "Error while reading ShaDa file: "
              "last entry specified that it occupies %" PRIu64 " bytes, "
              "but file ended earlier"),
            (uint64_t)length);
      return kSDReadStatusNotShaDa;
    }
  }
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
      emsgf(_(SERR "System error while reading integer from ShaDa file: %s"),
            sd_reader->error);
      return kSDReadStatusReadError;
    } else if (sd_reader->eof) {
      emsgf(_(RCERR "Error while reading ShaDa file: "
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
      case 0xCC: {  // uint8
        length = 1;
        break;
      }
      case 0xCD: {  // uint16
        length = 2;
        break;
      }
      case 0xCE: {  // uint32
        length = 4;
        break;
      }
      case 0xCF: {  // uint64
        length = 8;
        break;
      }
      default: {
        emsgf(_(RCERR "Error while reading ShaDa file: "
                "expected positive integer at position %" PRIu64),
              (uint64_t) fpos);
        return kSDReadStatusNotShaDa;
      }
    }
    uint64_t buf = 0;
    char *buf_u8 = (char *) &buf;
    ShaDaReadResult fl_ret;
    if ((fl_ret = fread_len(sd_reader, &(buf_u8[sizeof(buf)-length]), length))
        != kSDReadStatusSuccess) {
      return fl_ret;
    }
    *result = be64toh(buf);
  }
  return kSDReadStatusSuccess;
}

#define READERR(entry_name, error_desc) \
    RERR "Error while reading ShaDa file: " \
    entry_name " entry at position %" PRIu64 " " \
    error_desc
#define CHECK_KEY(key, expected) ( \
    key.via.str.size == sizeof(expected) - 1 \
    && STRNCMP(key.via.str.ptr, expected, sizeof(expected) - 1) == 0)
#define CLEAR_GA_AND_ERROR_OUT(ga) \
    do { \
      ga_clear(&ga); \
      goto shada_read_next_item_error; \
    } while (0)
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
      emsgf(_(READERR(entry_name, error_desc)), initial_fpos); \
      CLEAR_GA_AND_ERROR_OUT(ad_ga); \
    } \
    tgt = proc(obj.via.attr); \
  } while (0)
#define CHECK_KEY_IS_STR(entry_name) \
  if (unpacked.data.via.map.ptr[i].key.type != MSGPACK_OBJECT_STR) { \
    emsgf(_(READERR(entry_name, "has key which is not a string")), \
          initial_fpos); \
    CLEAR_GA_AND_ERROR_OUT(ad_ga); \
  } else if (unpacked.data.via.map.ptr[i].key.via.str.size == 0) { \
    emsgf(_(READERR(entry_name, "has empty key")), initial_fpos); \
    CLEAR_GA_AND_ERROR_OUT(ad_ga); \
  }
#define CHECKED_KEY(entry_name, name, error_desc, tgt, condition, attr, proc) \
  else if (CHECK_KEY( /* NOLINT(readability/braces) */ \
      unpacked.data.via.map.ptr[i].key, name)) { \
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
      ((unpacked.data.via.map.ptr[i].val.type \
        == MSGPACK_OBJECT_POSITIVE_INTEGER) \
       || (unpacked.data.via.map.ptr[i].val.type \
           == MSGPACK_OBJECT_NEGATIVE_INTEGER)), \
      i64, proc)
#define INTEGER_KEY(entry_name, name, tgt) \
  INT_KEY(entry_name, name, tgt, TOINT)
#define LONG_KEY(entry_name, name, tgt) \
  INT_KEY(entry_name, name, tgt, TOLONG)
#define ADDITIONAL_KEY \
  else { /* NOLINT(readability/braces) */ \
    ga_grow(&ad_ga, 1); \
    memcpy(((char *)ad_ga.ga_data) + ((size_t) ad_ga.ga_len \
                                      * sizeof(*unpacked.data.via.map.ptr)), \
           unpacked.data.via.map.ptr + i, \
           sizeof(*unpacked.data.via.map.ptr)); \
    ad_ga.ga_len++; \
  }
#define CONVERTED(str, len) (xmemdupz((str), (len)))
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
            emsgf(_(READERR(name, \
                            "cannot be converted to a VimL dictionary")), \
                  initial_fpos); \
            ga_clear(&ad_ga); \
            tv_clear(&adtv); \
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
            emsgf(_(READERR(name, "cannot be converted to a VimL list")), \
                  initial_fpos); \
            tv_clear(&aetv); \
            goto shada_read_next_item_error; \
          } \
          assert(aetv.v_type == VAR_LIST); \
          (tgt) = aetv.vval.v_list; \
        } \
      } while (0)

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

  const uint64_t initial_fpos = (uint64_t) sd_reader->fpos;
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

  if (length_u64 > PTRDIFF_MAX) {
    emsgf(_(RCERR "Error while reading ShaDa file: "
            "there is an item at position %" PRIu64 " "
            "that is stated to be too long"),
          initial_fpos);
    return kSDReadStatusNotShaDa;
  }

  const size_t length = (size_t)length_u64;
  entry->timestamp = (Timestamp)timestamp_u64;

  if (type_u64 == 0) {
    // kSDItemUnknown cannot possibly pass that far because it is -1 and that
    // will fail in msgpack_read_uint64. But kSDItemMissing may and it will
    // otherwise be skipped because (1 << 0) will never appear in flags.
    emsgf(_(RCERR "Error while reading ShaDa file: "
            "there is an item at position %" PRIu64 " "
            "that must not be there: Missing items are "
            "for internal uses only"),
          initial_fpos);
    return kSDReadStatusNotShaDa;
  }

  if ((type_u64 > SHADA_LAST_ENTRY
       ? !(flags & kSDReadUnknown)
       : !((unsigned) (1 << type_u64) & flags))
      || (max_kbyte && length > max_kbyte * 1024)) {
    // First entry is unknown or equal to "\n" (10)? Most likely this means that
    // current file is not a ShaDa file because first item should normally be
    // a header (excluding tests where first item is tested item). Check this by
    // parsing entry contents: in non-ShaDa files this will most likely result
    // in incomplete MessagePack string.
    if (initial_fpos == 0
        && (type_u64 == '\n' || type_u64 > SHADA_LAST_ENTRY)) {
      const ShaDaReadResult spm_ret = shada_parse_msgpack(sd_reader, length,
                                                          NULL, NULL);
      if (spm_ret != kSDReadStatusSuccess) {
        return spm_ret;
      }
    } else {
      const ShaDaReadResult srs_ret = sd_reader_skip(sd_reader, length);
      if (srs_ret != kSDReadStatusSuccess) {
        return srs_ret;
      }
    }
    goto shada_read_next_item_start;
  }

  if (type_u64 > SHADA_LAST_ENTRY) {
    entry->type = kSDItemUnknown;
    entry->data.unknown_item.size = length;
    entry->data.unknown_item.type = type_u64;
    if (initial_fpos == 0) {
      const ShaDaReadResult spm_ret = shada_parse_msgpack(
          sd_reader, length, NULL, &entry->data.unknown_item.contents);
      if (spm_ret != kSDReadStatusSuccess) {
        entry->type = kSDItemMissing;
      }
      return spm_ret;
    } else {
      entry->data.unknown_item.contents = xmalloc(length);
      const ShaDaReadResult fl_ret = fread_len(
          sd_reader, entry->data.unknown_item.contents, length);
      if (fl_ret != kSDReadStatusSuccess) {
        shada_free_shada_entry(entry);
        entry->type = kSDItemMissing;
      }
      return fl_ret;
    }
  }

  msgpack_unpacked unpacked;
  char *buf = NULL;

  const ShaDaReadResult spm_ret = shada_parse_msgpack(sd_reader, length,
                                                      &unpacked, &buf);
  if (spm_ret != kSDReadStatusSuccess) {
    ret = spm_ret;
    goto shada_read_next_item_error;
  }
  ret = kSDReadStatusMalformed;
  entry->data = sd_default_values[type_u64].data;
  switch ((ShadaEntryType) type_u64) {
    case kSDItemHeader: {
      if (!msgpack_rpc_to_dictionary(&(unpacked.data), &(entry->data.header))) {
        emsgf(_(READERR("header", "is not a dictionary")), initial_fpos);
        goto shada_read_next_item_error;
      }
      break;
    }
    case kSDItemSearchPattern: {
      if (unpacked.data.type != MSGPACK_OBJECT_MAP) {
        emsgf(_(READERR("search pattern", "is not a dictionary")),
              initial_fpos);
        goto shada_read_next_item_error;
      }
      garray_T ad_ga;
      ga_init(&ad_ga, sizeof(*(unpacked.data.via.map.ptr)), 1);
      for (size_t i = 0; i < unpacked.data.via.map.size; i++) {
        CHECK_KEY_IS_STR("search pattern")
        BOOLEAN_KEY("search pattern", SEARCH_KEY_MAGIC,
                    entry->data.search_pattern.magic)
        BOOLEAN_KEY("search pattern", SEARCH_KEY_SMARTCASE,
                    entry->data.search_pattern.smartcase)
        BOOLEAN_KEY("search pattern", SEARCH_KEY_HAS_LINE_OFFSET,
                    entry->data.search_pattern.has_line_offset)
        BOOLEAN_KEY("search pattern", SEARCH_KEY_PLACE_CURSOR_AT_END,
                    entry->data.search_pattern.place_cursor_at_end)
        BOOLEAN_KEY("search pattern", SEARCH_KEY_IS_LAST_USED,
                    entry->data.search_pattern.is_last_used)
        BOOLEAN_KEY("search pattern", SEARCH_KEY_IS_SUBSTITUTE_PATTERN,
                    entry->data.search_pattern.is_substitute_pattern)
        BOOLEAN_KEY("search pattern", SEARCH_KEY_HIGHLIGHTED,
                    entry->data.search_pattern.highlighted)
        BOOLEAN_KEY("search pattern", SEARCH_KEY_BACKWARD,
                    entry->data.search_pattern.search_backward)
        INTEGER_KEY("search pattern", SEARCH_KEY_OFFSET,
                    entry->data.search_pattern.offset)
        CONVERTED_STRING_KEY("search pattern", SEARCH_KEY_PAT,
                             entry->data.search_pattern.pat)
        ADDITIONAL_KEY
      }
      if (entry->data.search_pattern.pat == NULL) {
        emsgf(_(READERR("search pattern", "has no pattern")), initial_fpos);
        CLEAR_GA_AND_ERROR_OUT(ad_ga);
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
        emsgf(_(READERR("mark", "is not a dictionary")), initial_fpos);
        goto shada_read_next_item_error;
      }
      garray_T ad_ga;
      ga_init(&ad_ga, sizeof(*(unpacked.data.via.map.ptr)), 1);
      for (size_t i = 0; i < unpacked.data.via.map.size; i++) {
        CHECK_KEY_IS_STR("mark")
        if (CHECK_KEY(unpacked.data.via.map.ptr[i].key, KEY_NAME_CHAR)) {
          if (type_u64 == kSDItemJump || type_u64 == kSDItemChange) {
            emsgf(_(READERR("mark", "has n key which is only valid for "
                            "local and global mark entries")), initial_fpos);
            CLEAR_GA_AND_ERROR_OUT(ad_ga);
          }
          CHECKED_ENTRY(
              (unpacked.data.via.map.ptr[i].val.type
               == MSGPACK_OBJECT_POSITIVE_INTEGER),
              "has n key value which is not an unsigned integer",
              "mark", unpacked.data.via.map.ptr[i].val,
              entry->data.filemark.name, u64, TOCHAR);
        }
        LONG_KEY("mark", KEY_LNUM, entry->data.filemark.mark.lnum)
        INTEGER_KEY("mark", KEY_COL, entry->data.filemark.mark.col)
        STRING_KEY("mark", KEY_FILE, entry->data.filemark.fname)
        ADDITIONAL_KEY
      }
      if (entry->data.filemark.fname == NULL) {
        emsgf(_(READERR("mark", "is missing file name")), initial_fpos);
        CLEAR_GA_AND_ERROR_OUT(ad_ga);
      }
      if (entry->data.filemark.mark.lnum <= 0) {
        emsgf(_(READERR("mark", "has invalid line number")), initial_fpos);
        CLEAR_GA_AND_ERROR_OUT(ad_ga);
      }
      if (entry->data.filemark.mark.col < 0) {
        emsgf(_(READERR("mark", "has invalid column number")), initial_fpos);
        CLEAR_GA_AND_ERROR_OUT(ad_ga);
      }
      SET_ADDITIONAL_DATA(entry->data.filemark.additional_data, "mark");
      break;
    }
    case kSDItemRegister: {
      if (unpacked.data.type != MSGPACK_OBJECT_MAP) {
        emsgf(_(READERR("register", "is not a dictionary")), initial_fpos);
        goto shada_read_next_item_error;
      }
      garray_T ad_ga;
      ga_init(&ad_ga, sizeof(*(unpacked.data.via.map.ptr)), 1);
      for (size_t i = 0; i < unpacked.data.via.map.size; i++) {
        CHECK_KEY_IS_STR("register")
        if (CHECK_KEY(unpacked.data.via.map.ptr[i].key,
                      REG_KEY_CONTENTS)) {
          if (unpacked.data.via.map.ptr[i].val.type != MSGPACK_OBJECT_ARRAY) {
            emsgf(_(READERR("register",
                            "has " REG_KEY_CONTENTS
                            " key with non-array value")),
                  initial_fpos);
            CLEAR_GA_AND_ERROR_OUT(ad_ga);
          }
          if (unpacked.data.via.map.ptr[i].val.via.array.size == 0) {
            emsgf(_(READERR("register",
                            "has " REG_KEY_CONTENTS " key with empty array")),
                  initial_fpos);
            CLEAR_GA_AND_ERROR_OUT(ad_ga);
          }
          const msgpack_object_array arr =
              unpacked.data.via.map.ptr[i].val.via.array;
          for (size_t i = 0; i < arr.size; i++) {
            if (arr.ptr[i].type != MSGPACK_OBJECT_BIN) {
              emsgf(_(READERR("register", "has " REG_KEY_CONTENTS " array "
                              "with non-binary value")), initial_fpos);
              CLEAR_GA_AND_ERROR_OUT(ad_ga);
            }
          }
          entry->data.reg.contents_size = arr.size;
          entry->data.reg.contents = xmalloc(arr.size * sizeof(char *));
          for (size_t i = 0; i < arr.size; i++) {
            entry->data.reg.contents[i] = BIN_CONVERTED(arr.ptr[i].via.bin);
          }
        }
        BOOLEAN_KEY("register", REG_KEY_UNNAMED, entry->data.reg.is_unnamed)
        TYPED_KEY("register", REG_KEY_TYPE, "an unsigned integer",
                  entry->data.reg.type, POSITIVE_INTEGER, u64, TOU8)
        TYPED_KEY("register", KEY_NAME_CHAR, "an unsigned integer",
                  entry->data.reg.name, POSITIVE_INTEGER, u64, TOCHAR)
        TYPED_KEY("register", REG_KEY_WIDTH, "an unsigned integer",
                  entry->data.reg.width, POSITIVE_INTEGER, u64, TOSIZE)
        ADDITIONAL_KEY
      }
      if (entry->data.reg.contents == NULL) {
        emsgf(_(READERR("register", "has missing " REG_KEY_CONTENTS " array")),
              initial_fpos);
        CLEAR_GA_AND_ERROR_OUT(ad_ga);
      }
      SET_ADDITIONAL_DATA(entry->data.reg.additional_data, "register");
      break;
    }
    case kSDItemHistoryEntry: {
      if (unpacked.data.type != MSGPACK_OBJECT_ARRAY) {
        emsgf(_(READERR("history", "is not an array")), initial_fpos);
        goto shada_read_next_item_error;
      }
      if (unpacked.data.via.array.size < 2) {
        emsgf(_(READERR("history", "does not have enough elements")),
              initial_fpos);
        goto shada_read_next_item_error;
      }
      if (unpacked.data.via.array.ptr[0].type
          != MSGPACK_OBJECT_POSITIVE_INTEGER) {
        emsgf(_(READERR("history", "has wrong history type type")),
              initial_fpos);
        goto shada_read_next_item_error;
      }
      if (unpacked.data.via.array.ptr[1].type
          != MSGPACK_OBJECT_BIN) {
        emsgf(_(READERR("history", "has wrong history string type")),
              initial_fpos);
        goto shada_read_next_item_error;
      }
      if (memchr(unpacked.data.via.array.ptr[1].via.bin.ptr, 0,
                 unpacked.data.via.array.ptr[1].via.bin.size) != NULL) {
        emsgf(_(READERR("history", "contains string with zero byte inside")),
              initial_fpos);
        goto shada_read_next_item_error;
      }
      entry->data.history_item.histtype =
          (uint8_t) unpacked.data.via.array.ptr[0].via.u64;
      const bool is_hist_search =
          entry->data.history_item.histtype == HIST_SEARCH;
      if (is_hist_search) {
        if (unpacked.data.via.array.size < 3) {
          emsgf(_(READERR("search history",
                          "does not have separator character")), initial_fpos);
          goto shada_read_next_item_error;
        }
        if (unpacked.data.via.array.ptr[2].type
            != MSGPACK_OBJECT_POSITIVE_INTEGER) {
          emsgf(_(READERR("search history",
                          "has wrong history separator type")), initial_fpos);
          goto shada_read_next_item_error;
        }
        entry->data.history_item.sep =
            (char) unpacked.data.via.array.ptr[2].via.u64;
      }
      size_t strsize;
      strsize = (
          unpacked.data.via.array.ptr[1].via.bin.size
          + 1  // Zero byte
          + 1);  // Separator character
      entry->data.history_item.string = xmalloc(strsize);
      memcpy(entry->data.history_item.string,
             unpacked.data.via.array.ptr[1].via.bin.ptr,
             unpacked.data.via.array.ptr[1].via.bin.size);
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
        emsgf(_(READERR("variable", "is not an array")), initial_fpos);
        goto shada_read_next_item_error;
      }
      if (unpacked.data.via.array.size < 2) {
        emsgf(_(READERR("variable", "does not have enough elements")),
              initial_fpos);
        goto shada_read_next_item_error;
      }
      if (unpacked.data.via.array.ptr[0].type != MSGPACK_OBJECT_BIN) {
        emsgf(_(READERR("variable", "has wrong variable name type")),
              initial_fpos);
        goto shada_read_next_item_error;
      }
      entry->data.global_var.name =
          xmemdupz(unpacked.data.via.array.ptr[0].via.bin.ptr,
                   unpacked.data.via.array.ptr[0].via.bin.size);
      if (msgpack_to_vim(unpacked.data.via.array.ptr[1],
                         &(entry->data.global_var.value)) == FAIL) {
        emsgf(_(READERR("variable", "has value that cannot "
                        "be converted to the VimL value")), initial_fpos);
        goto shada_read_next_item_error;
      }
      SET_ADDITIONAL_ELEMENTS(unpacked.data.via.array, 2,
                              entry->data.global_var.additional_elements,
                              "variable");
      break;
    }
    case kSDItemSubString: {
      if (unpacked.data.type != MSGPACK_OBJECT_ARRAY) {
        emsgf(_(READERR("sub string", "is not an array")), initial_fpos);
        goto shada_read_next_item_error;
      }
      if (unpacked.data.via.array.size < 1) {
        emsgf(_(READERR("sub string", "does not have enough elements")),
              initial_fpos);
        goto shada_read_next_item_error;
      }
      if (unpacked.data.via.array.ptr[0].type != MSGPACK_OBJECT_BIN) {
        emsgf(_(READERR("sub string", "has wrong sub string type")),
              initial_fpos);
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
        emsgf(_(READERR("buffer list", "is not an array")), initial_fpos);
        goto shada_read_next_item_error;
      }
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
            emsgf(_(RERR "Error while reading ShaDa file: "
                    "buffer list at position %" PRIu64 " "
                    "contains entry that is not a dictionary"),
                  initial_fpos);
            goto shada_read_next_item_error;
          }
          entry->data.buffer_list.buffers[i].pos = default_pos;
          garray_T ad_ga;
          ga_init(&ad_ga, sizeof(*(unpacked.data.via.map.ptr)), 1);
          {
            const size_t j = i;
            {
              for (size_t i = 0; i < unpacked.data.via.map.size; i++) {
                CHECK_KEY_IS_STR("buffer list entry")
                LONG_KEY("buffer list entry", KEY_LNUM,
                         entry->data.buffer_list.buffers[j].pos.lnum)
                INTEGER_KEY("buffer list entry", KEY_COL,
                            entry->data.buffer_list.buffers[j].pos.col)
                STRING_KEY("buffer list entry", KEY_FILE,
                           entry->data.buffer_list.buffers[j].fname)
                ADDITIONAL_KEY
              }
            }
          }
          if (entry->data.buffer_list.buffers[i].pos.lnum <= 0) {
            emsgf(_(RERR "Error while reading ShaDa file: "
                    "buffer list at position %" PRIu64 " "
                    "contains entry with invalid line number"),
                  initial_fpos);
            CLEAR_GA_AND_ERROR_OUT(ad_ga);
          }
          if (entry->data.buffer_list.buffers[i].pos.col < 0) {
            emsgf(_(RERR "Error while reading ShaDa file: "
                    "buffer list at position %" PRIu64 " "
                    "contains entry with invalid column number"),
                  initial_fpos);
            CLEAR_GA_AND_ERROR_OUT(ad_ga);
          }
          if (entry->data.buffer_list.buffers[i].fname == NULL) {
            emsgf(_(RERR "Error while reading ShaDa file: "
                    "buffer list at position %" PRIu64 " "
                    "contains entry that does not have a file name"),
                  initial_fpos);
            CLEAR_GA_AND_ERROR_OUT(ad_ga);
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
  ret = kSDReadStatusSuccess;
shada_read_next_item_end:
  if (buf != NULL) {
    msgpack_unpacked_destroy(&unpacked);
    xfree(buf);
  }
  return ret;
shada_read_next_item_error:
  entry->type = (ShadaEntryType) type_u64;
  shada_free_shada_entry(entry);
  entry->type = kSDItemMissing;
  goto shada_read_next_item_end;
}
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
#undef CLEAR_GA_AND_ERROR_OUT

/// Check whether "name" is on removable media (according to 'shada')
///
/// @param[in]  name  Checked name.
///
/// @return True if it is, false otherwise.
static bool shada_removable(const char *name)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  char  *p;
  char part[MAXPATHL + 1];
  bool retval = false;

  char *new_name = home_replace_save(NULL, name);
  for (p = (char *) p_shada; *p; ) {
    (void) copy_option_part(&p, part, ARRAY_SIZE(part), ", ");
    if (part[0] == 'r') {
      home_replace(NULL, part + 1, NameBuff, MAXPATHL, true);
      size_t n = STRLEN(NameBuff);
      if (mb_strnicmp(NameBuff, new_name, n) == 0) {
        retval = true;
        break;
      }
    }
  }
  xfree(new_name);
  return retval;
}
