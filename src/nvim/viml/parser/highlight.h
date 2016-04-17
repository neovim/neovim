#ifndef NVIM_VIML_PARSER_HIGHLIGHT_H
#define NVIM_VIML_PARSER_HIGHLIGHT_H

#include "nvim/garray.h"

#include "nvim/viml/parser/expressions.h"

/// A structure for holding command position
///
/// Intended for debugging purposes later
typedef struct {
  size_t lnr;
  size_t col;
} CommandPosition;

/// Possible token types
typedef enum {
  kTokCommandBuiltin,
  kTokCommandModifier,
  kTokCommandUser,
  kTokCommandColon,
  kTokBang,
} HighlightType;

/// Structure for saving highlighted token
typedef struct {
  HighlightType type;     ///< Token type.
  CommandPosition start;  ///< Start of the token.
  CommandPosition end;    ///< End of the token.
} HighlightedToken;

typedef garray_T HighlightedTokens;

#define HLTOKENS_EMPTY_INIT_VALUE GA_EMPTY_INIT_VALUE

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/parser/highlight.h.generated.h"
#endif
#endif  // NVIM_VIML_PARSER_HIGHLIGHT_H
