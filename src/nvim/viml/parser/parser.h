#ifndef NVIM_VIML_PARSER_PARSER_H
#define NVIM_VIML_PARSER_PARSER_H

#include <stdbool.h>
#include <stddef.h>
#include <assert.h>

#include "nvim/lib/kvec.h"
#include "nvim/func_attr.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"

/// One parsed line
typedef struct {
  const char *data;  ///< Parsed line pointer
  size_t size;  ///< Parsed line size
  bool allocated;  ///< True if line may be freed.
} ParserLine;

/// Line getter type for parser
///
/// Line getter must return {NULL, 0} for EOF.
typedef void (*ParserLineGetter)(void *cookie, ParserLine *ret_pline);

/// Parser position in the input
typedef struct {
  size_t line;  ///< Line index in ParserInputReader.lines.
  size_t col;  ///< Byte index in the line.
} ParserPosition;

/// Parser state item.
typedef struct {
  enum {
    kPTopStateParsingCommand = 0,
    kPTopStateParsingExpression,
  } type;
  union {
    struct {
      enum {
        kExprUnknown = 0,
      } type;
    } expr;
  } data;
} ParserStateItem;

/// Structure defining input reader
typedef struct {
  /// Function used to get next line.
  ParserLineGetter get_line;
  /// Data for get_line function.
  void *cookie;
  /// All lines obtained by get_line.
  kvec_withinit_t(ParserLine, 4) lines;
  /// Conversion, for :scriptencoding.
  vimconv_T conv;
} ParserInputReader;

/// Highlighted region definition
///
/// Note: one chunk may highlight only one line.
typedef struct {
  ParserPosition start;  ///< Start of the highlight: line and column.
  size_t end_col;  ///< End column, points to the start of the next character.
  const char *group;  ///< Highlight group.
} ParserHighlightChunk;

/// Highlighting defined by a parser
typedef kvec_withinit_t(ParserHighlightChunk, 16) ParserHighlight;

/// Structure defining parser state
typedef struct {
  /// Line reader.
  ParserInputReader reader;
  /// Position up to which input was parsed.
  ParserPosition pos;
  /// Parser state stack.
  kvec_withinit_t(ParserStateItem, 16) stack;
  /// Highlighting support.
  ParserHighlight *colors;
  /// True if line continuation can be used.
  bool can_continuate;
} ParserState;

static inline void viml_parser_init(
    ParserState *const ret_pstate,
    const ParserLineGetter get_line, void *const cookie,
    ParserHighlight *const colors)
  REAL_FATTR_ALWAYS_INLINE REAL_FATTR_NONNULL_ARG(1, 2);

/// Initialize a new parser state instance
///
/// @param[out]  ret_pstate  Parser state to initialize.
/// @param[in]  get_line  Line getter function.
/// @param[in]  cookie  Argument for the get_line function.
/// @param[in]  colors  Where to save highlighting. May be NULL if it is not
///                     needed.
static inline void viml_parser_init(
    ParserState *const ret_pstate,
    const ParserLineGetter get_line, void *const cookie,
    ParserHighlight *const colors)
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

static inline void viml_parser_destroy(ParserState *const pstate)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_ALWAYS_INLINE;

/// Free all memory allocated by the parser on heap
///
/// @param  pstate  Parser state to free.
static inline void viml_parser_destroy(ParserState *const pstate)
{
  for (size_t i = 0; i < kv_size(pstate->reader.lines); i++) {
    ParserLine pline = kv_A(pstate->reader.lines, i);
    if (pline.allocated) {
      xfree((void *)pline.data);
    }
  }
  kvi_destroy(pstate->reader.lines);
  kvi_destroy(pstate->stack);
}

static inline void viml_preader_get_line(ParserInputReader *const preader,
                                         ParserLine *const ret_pline)
  REAL_FATTR_NONNULL_ALL;

/// Get one line from ParserInputReader
static inline void viml_preader_get_line(ParserInputReader *const preader,
                                         ParserLine *const ret_pline)
{
  ParserLine pline;
  preader->get_line(preader->cookie, &pline);
  if (preader->conv.vc_type != CONV_NONE && pline.size) {
    ParserLine cpline = {
      .allocated = true,
      .size = pline.size,
    };
    cpline.data = (char *)string_convert(&preader->conv,
                                         (char_u *)pline.data,
                                         &cpline.size);
    if (pline.allocated) {
      xfree((void *)pline.data);
    }
    pline = cpline;
  }
  kvi_push(preader->lines, pline);
  *ret_pline = pline;
}

static inline bool viml_parser_get_remaining_line(ParserState *const pstate,
                                                  ParserLine *const ret_pline)
  REAL_FATTR_ALWAYS_INLINE REAL_FATTR_WARN_UNUSED_RESULT REAL_FATTR_NONNULL_ALL;

/// Get currently parsed line, shifted to pstate->pos.col
///
/// @param  pstate  Parser state to operate on.
///
/// @return True if there is a line, false in case of EOF.
static inline bool viml_parser_get_remaining_line(ParserState *const pstate,
                                                  ParserLine *const ret_pline)
{
  const size_t num_lines = kv_size(pstate->reader.lines);
  if (pstate->pos.line == num_lines) {
    viml_preader_get_line(&pstate->reader, ret_pline);
  } else {
    *ret_pline = kv_last(pstate->reader.lines);
  }
  assert(pstate->pos.line == kv_size(pstate->reader.lines) - 1);
  if (ret_pline->data != NULL) {
    ret_pline->data += pstate->pos.col;
    ret_pline->size -= pstate->pos.col;
  }
  return ret_pline->data != NULL;
}

static inline void viml_parser_advance(ParserState *const pstate,
                                       const size_t len)
  REAL_FATTR_ALWAYS_INLINE REAL_FATTR_NONNULL_ALL;

/// Advance position by a given number of bytes
///
/// At maximum advances to the next line.
///
/// @param  pstate  Parser state to advance.
/// @param[in]  len  Number of bytes to advance.
static inline void viml_parser_advance(ParserState *const pstate,
                                       const size_t len)
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

static inline void viml_parser_highlight(ParserState *const pstate,
                                         const ParserPosition start,
                                         const size_t end_col,
                                         const char *const group)
  REAL_FATTR_ALWAYS_INLINE REAL_FATTR_NONNULL_ALL;

/// Record highlighting of some region of text
///
/// @param  pstate  Parser state to work with.
/// @param[in]  start  Start position of the highlight.
/// @param[in]  len  Highlighting chunk length.
/// @param[in]  group  Highlight group.
static inline void viml_parser_highlight(ParserState *const pstate,
                                         const ParserPosition start,
                                         const size_t len,
                                         const char *const group)
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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/parser/parser.h.generated.h"
#endif

#endif  // NVIM_VIML_PARSER_PARSER_H
