#ifndef NVIM_EX_MAP_H
#define NVIM_EX_MAP_H

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

  /// The {lhs} of the mapping.
  ///
  /// vim limits this to MAXMAPLEN characters, allowing us to use a static
  /// buffer. Setting lhs_len to a value larger than MAXMAPLEN can signal
  /// that {lhs} was too long and truncated.
  char_u lhs[MAXMAPLEN + 1];
  size_t lhs_len;

  char_u *rhs;  /// The {rhs} of the mapping.
  size_t rhs_len;
  bool rhs_is_noop;  /// True when the {orig_rhs} is <nop>.

  char_u *orig_rhs;  /// The original text of the {rhs}.
  size_t orig_rhs_len;
};
typedef struct map_arguments MapArguments;
#define MAP_ARGUMENTS_INIT { false, false, false, false, false, false, false, \
                             { 0 }, 0, NULL, 0, false, NULL, 0 }

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_map.h.generated.h"
#endif
#endif  // NVIM_EX_MAP_H
