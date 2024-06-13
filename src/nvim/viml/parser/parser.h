#pragma once

#include <assert.h>
#include <stdbool.h>
#include <stddef.h>

#include "klib/kvec.h"
#include "nvim/mbyte_defs.h"
#include "nvim/viml/parser/parser_defs.h"  // IWYU pragma: keep

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/parser/parser.h.generated.h"
# include "viml/parser/parser.h.inline.generated.h"
#endif

/// Initialize a new parser state instance
///
/// @param[out]  ret_pstate  Parser state to initialize.
/// @param[in]  get_line  Line getter function.
/// @param[in]  cookie  Argument for the get_line function.
/// @param[in]  colors  Where to save highlighting. May be NULL if it is not
///                     needed.
static inline void viml_parser_init(ParserState *const ret_pstate, const ParserLineGetter get_line,
                                    void *const cookie, ParserHighlight *const colors)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ARG(1, 2)
{
  *ret_pstate = (ParserState) {
    .reader = {
      .get_line = get_line,
      .cookie = cookie,
      .conv = MBYTE_NONE_CONV,
    },
    .pos = { 0, 0 },
    .colors = colors,
    .can_continuate = false,
  };
  kvi_init(ret_pstate->reader.lines);
  kvi_init(ret_pstate->stack);
}

/// Advance position by a given number of bytes
///
/// At maximum advances to the next line.
///
/// @param  pstate  Parser state to advance.
/// @param[in]  len  Number of bytes to advance.
static inline void viml_parser_advance(ParserState *const pstate, const size_t len)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL
{
  assert(pstate->pos.line == kv_size(pstate->reader.lines) - 1);
  const ParserLine pline = kv_last(pstate->reader.lines);
  if (pstate->pos.col + len >= pline.size) {
    pstate->pos.line++;
    pstate->pos.col = 0;
  } else {
    pstate->pos.col += len;
  }
}

/// Record highlighting of some region of text
///
/// @param  pstate  Parser state to work with.
/// @param[in]  start  Start position of the highlight.
/// @param[in]  len  Highlighting chunk length.
/// @param[in]  group  Highlight group.
static inline void viml_parser_highlight(ParserState *const pstate, const ParserPosition start,
                                         const size_t len, const char *const group)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL
{
  if (pstate->colors == NULL || len == 0) {
    return;
  }
  assert(kv_size(*pstate->colors) == 0
         || kv_Z(*pstate->colors, 0).start.line < start.line
         || kv_Z(*pstate->colors, 0).end_col <= start.col);
  kvi_push(*pstate->colors, ((ParserHighlightChunk) {
    .start = start,
    .end_col = start.col + len,
    .group = group,
  }));
}
