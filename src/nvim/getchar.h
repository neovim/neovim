#ifndef NVIM_GETCHAR_H
#define NVIM_GETCHAR_H

#include "nvim/os/fileio.h"
#include "nvim/types.h"
#include "nvim/buffer_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/vim.h"

/// Values for "noremap" argument of ins_typebuf()
///
/// Also used for map->m_noremap and menu->noremap[].
enum {
  REMAP_YES = 0,  ///< Allow remapping.
  REMAP_NONE = -1,  ///< No remapping.
  REMAP_SCRIPT = -2,  ///< Remap script-local mappings only.
  REMAP_SKIP = -3,  ///< No remapping for first char.
} RemapValues;

// Argument for flush_buffers().
typedef enum {
  FLUSH_MINIMAL,
  FLUSH_TYPEAHEAD,  // flush current typebuf contents
  FLUSH_INPUT       // flush typebuf and inchar() input
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

#define KEYLEN_PART_KEY -1  // keylen value for incomplete key-code
#define KEYLEN_PART_MAP -2  // keylen value for incomplete mapping

/// Maximum number of streams to read script from
enum { NSCRIPT = 15 };

/// Streams to read script from
extern FileDescriptor *scriptin[NSCRIPT];

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "getchar.h.generated.h"
#endif
#endif  // NVIM_GETCHAR_H
