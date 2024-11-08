#pragma once

#include <stdint.h>  // IWYU pragma: keep
#include <stdio.h>  // IWYU pragma: keep

#include "nvim/api/keysets_defs.h"  // IWYU pragma: keep
#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/cmdexpand_defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/mapping_defs.h"  // IWYU pragma: keep
#include "nvim/option_defs.h"  // IWYU pragma: keep
#include "nvim/regexp_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mapping.h.generated.h"
#endif

/// Used for the first argument of do_map()
enum {
  MAPTYPE_MAP       = 0,
  MAPTYPE_UNMAP     = 1,
  MAPTYPE_NOREMAP   = 2,
  MAPTYPE_UNMAP_LHS = 3,
};

/// Adjust chars in a language according to 'langmap' option.
/// NOTE that there is no noticeable overhead if 'langmap' is not set.
/// When set the overhead for characters < 256 is small.
/// Don't apply 'langmap' if the character comes from the Stuff buffer or from a
/// mapping and the langnoremap option was set.
/// The do-while is just to ignore a ';' after the macro.
#define LANGMAP_ADJUST(c, condition) \
  do { \
    if (*p_langmap \
        && (condition) \
        && (p_lrm || (vgetc_busy ? typebuf_maplen() == 0 : KeyTyped)) \
        && !KeyStuffed \
        && (c) >= 0) \
    { \
      if ((c) < 256) \
      c = langmap_mapchar[c]; \
      else \
      c = langmap_adjust_mb(c); \
    } \
  } while (0)
