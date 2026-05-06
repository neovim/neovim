#pragma once

#include <stdbool.h>
#include <stddef.h>

#include "nvim/api/private/defs.h"
#include "nvim/map_defs.h"
#include "nvim/tui/terminfo_builtin.h"
#include "nvim/tui/terminfo_defs.h"

typedef struct {
  char *name;
  ObjectType type;  // Lua type in decoded $NVIM_TERMDEFS
  size_t offset;  // offset in TerminfoEntry
} TermdefField;

// uncrustify:off
static const TermdefField termdef_field_entries[] = {
#define FIELD(n, t, off) { .name = n, .type = kObjectType##t, \
                           .offset = offsetof(TerminfoEntry, off) },
#define X(n) FIELD(#n, Boolean, n)
  XLIST_TERMINFO_BOOLS
#undef X
#define X(n) FIELD(#n, Integer, n)
  XLIST_TERMINFO_INTS
#undef X
#define X(n) FIELD(#n, String, defs[kTerm_##n])
  XLIST_TERMINFO_BUILTIN
#undef X
#define X(n, code) FIELD(#n, String, defs[kTerm_##n])
  XLIST_TERMINFO_EXT
#undef X
#define X(n) FIELD("key_" #n, String, keys[kTermKey_##n])
#define Y(n) FIELD("key_" #n, Array, keys[kTermKey_##n])
  XYLIST_TERMINFO_KEYS
#undef X
#undef Y
#define X(n, idx) FIELD("key_" #n, String, f_keys[idx])
  XLIST_TERMINFO_FKEYS
#undef X
#undef FIELD
};
// uncrustify:on

static PMap(cstr_t) termdef_fields = MAP_INIT;
static inline void init_termdef_fields(void)
{
  for (size_t i = 0; i < ARRAY_SIZE(termdef_field_entries); i++) {
    pmap_put(cstr_t)(&termdef_fields, termdef_field_entries[i].name,
                     (TermdefField *)&termdef_field_entries[i]);
  }
}
