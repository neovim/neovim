#pragma once

#include "nvim/api/private/defs.h"  // IWYU pragma: keep

/// Structured info for a key chord.
///
/// XXX: The `key`/`key_alt` strings may point into `key_mem` or into a static buffer owned by
/// str2special()/get_special_key(). All are only valid until the next such call.
struct keychord {
  int mods;         ///< Modifier mask (see `mod_mask_table`), e.g. `<C-A>` yields Ctrl and Shift.
  char key_mem;     ///< Backing storage for a single-byte `key`/`key_alt` (see above).
  String key;       ///< Key without modifiers, normalized, e.g. `<C-A>` => `a`, `<lt>` => `<`.
  String key_alt;   ///< Alternative spelling of `key`, e.g. `lt` for `<`. Empty (NULL) if same.
};
