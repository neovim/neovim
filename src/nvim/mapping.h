#ifndef NVIM_MAPPING_H
#define NVIM_MAPPING_H

#include "nvim/buffer_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/types.h"
#include "nvim/vim.h"

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
  bool replace_keycodes;

  /// The {lhs} of the mapping.
  ///
  /// vim limits this to MAXMAPLEN characters, allowing us to use a static
  /// buffer. Setting lhs_len to a value larger than MAXMAPLEN can signal
  /// that {lhs} was too long and truncated.
  char_u lhs[MAXMAPLEN + 1];
  size_t lhs_len;

  /// Unsimplifed {lhs} of the mapping. If no simplification has been done then alt_lhs_len is 0.
  char_u alt_lhs[MAXMAPLEN + 1];
  size_t alt_lhs_len;

  char *rhs;  /// The {rhs} of the mapping.
  size_t rhs_len;
  LuaRef rhs_lua;  /// lua function as {rhs}
  bool rhs_is_noop;  /// True when the {rhs} should be <Nop>.

  char_u *orig_rhs;  /// The original text of the {rhs}.
  size_t orig_rhs_len;
  char *desc;  /// map description
};
typedef struct map_arguments MapArguments;
#define MAP_ARGUMENTS_INIT { false, false, false, false, false, false, false, false, \
                             { 0 }, 0, { 0 }, 0, NULL, 0, LUA_NOREF, false, NULL, 0, NULL }

// Used for the first argument of do_map()
#define MAPTYPE_MAP      0
#define MAPTYPE_UNMAP    1
#define MAPTYPE_NOREMAP  2

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mapping.h.generated.h"
#endif
#endif  // NVIM_MAPPING_H
