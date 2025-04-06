#pragma once

#include <assert.h>
#include <stdbool.h>
#include <stddef.h>

#include "klib/kvec.h"
#include "nvim/mbyte_defs.h"

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
