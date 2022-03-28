#ifndef NVIM_GETCHAR_H
#define NVIM_GETCHAR_H

#include "nvim/buffer_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/os/fileio.h"
#include "nvim/types.h"
#include "nvim/vim.h"

/// Values for "noremap" argument of ins_typebuf()
///
/// Also used for map->m_noremap and menu->noremap[].
enum RemapValues {
  REMAP_YES = 0,  ///< Allow remapping.
  REMAP_NONE = -1,  ///< No remapping.
  REMAP_SCRIPT = -2,  ///< Remap script-local mappings only.
  REMAP_SKIP = -3,  ///< No remapping for first char.
};

// Argument for flush_buffers().
typedef enum {
  FLUSH_MINIMAL,
  FLUSH_TYPEAHEAD,  // flush current typebuf contents
  FLUSH_INPUT,  // flush typebuf and inchar() input
} flush_buffers_T;

/// All possible |:map-arguments| usable in a |:map| command.
///
/// The <special> argument has no effect on mappings and is excluded from this
/// struct declaration. |noremap| is included, since it behaves like a map
/// argument when used in a mapping.
///
/// @see mapblock_T
struct map_arguments {
  bool buffer;
  bool expr;
  bool noremap;
  bool nowait;
  bool script;
  bool silent;
  bool unique;
  bool is_abbrev;
  bool has_lhs;
  bool has_rhs;

  int modes;

  /// The {lhs} of the mapping.
  ///
  /// vim limits this to MAXMAPLEN characters, allowing us to use a static
  /// buffer. Setting lhs_len to a value larger than MAXMAPLEN can signal
  /// that {lhs} was too long and truncated.
  char_u lhs[MAXMAPLEN + 1];
  size_t lhs_len;

  char_u *rhs;  /// The {rhs} of the mapping.
  size_t rhs_len;
  LuaRef rhs_lua;  /// lua function as rhs
  bool rhs_is_noop;  /// True when the {orig_rhs} is <nop>.

  char_u *orig_rhs;  /// The original text of the {rhs}.
  size_t orig_rhs_len;
  char *desc;  /// map description
};
typedef struct map_arguments MapArguments;
#define MAP_ARGUMENTS_INIT {  \
  .buffer =       false,      \
  .expr =         false,      \
  .noremap =      false,      \
  .nowait =       false,      \
  .script =       false,      \
  .silent =       false,      \
  .unique =       false,      \
  .is_abbrev =    false,      \
  .has_lhs =      false,      \
  .has_rhs =      false,      \
  .modes =        0,          \
  .lhs =          { 0 },      \
  .lhs_len =      0,          \
  .rhs =          NULL,       \
  .rhs_len =      0,          \
  .rhs_lua =      LUA_NOREF,  \
  .rhs_is_noop =  false,      \
  .orig_rhs =     NULL,       \
  .orig_rhs_len = 0,          \
  .desc =         NULL,       \
}

// legacy argument type for the legacy function do_map():
typedef enum map_type {
  MapType_map = 0,     // |:map|
  MapType_unmap = 1,   // |:unmap|
  MapType_noremap = 2, // |:noremap|
} MapType;

/// Possible result codes from do_map():
typedef enum do_map_result {
  DoMap_unknown_error        = -1,
  DoMap_success              =  0,
  DoMap_invalid_arguments    =  1,
  DoMap_no_match             =  2,
  DoMap_entry_is_not_unique  =  5,
} DoMapResult;

typedef enum StringCompare {
  StringCompare_unequal,     // The strings do not match.
  StringCompare_exact_match, // The strings match exactly.
  StringCompare_lhs_matches_initial_chars_of_rhs,  // e.g. foo vs foobar
  StringCompare_rhs_matches_initial_chars_of_lhs,  // e.g. foobar vs foo
} StringCompare;

#define KEYLEN_PART_KEY -1  // keylen value for incomplete key-code
#define KEYLEN_PART_MAP -2  // keylen value for incomplete mapping

/// Maximum number of streams to read script from
enum { NSCRIPT = 15, };

/// Streams to read script from
extern FileDescriptor *scriptin[NSCRIPT];

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "getchar.h.generated.h"
#endif
#endif  // NVIM_GETCHAR_H
