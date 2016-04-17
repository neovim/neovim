#include "nvim/garray.h"
#include "nvim/func_attr.h"

#include "nvim/viml/parser/highlight.h"
#include "nvim/viml/parser/expressions.h"
#include "nvim/viml/parser/ex_commands.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/parser/highlight.c.generated.h"
#endif

/// Allocate new HighlightedTokens instance
HighlightedTokens *hltokens_new(void)
  FUNC_ATTR_MALLOC
{
  HighlightedTokens *ret = xmalloc(sizeof(*ret));
  hltokens_init(ret);
  return ret;
}

void hltokens_init(HighlightedTokens *const tokens)
  FUNC_ATTR_NONNULL_ALL
{
  ga_init(tokens, sizeof(HighlightedToken), 5);
}

void hltokens_free(HighlightedTokens *const tokens)
  FUNC_ATTR_NONNULL_ALL
{
  ga_clear(tokens);
}

/// Append token to an array of them
///
/// @param[out]  tokens  What to append to.
/// @param[in]  token  What to append.
void hltokens_append(HighlightedTokens *const tokens,
                     const HighlightedToken token)
{
  if (!tokens) {
    return;
  }
  GA_APPEND(HighlightedToken, tokens, token);
}

/// Append token to an array of them
///
/// @param[out]  tokens  What to append to.
/// @param[in]  lnr  Line number.
/// @param[in]  scol  Start of the token inside the line.
/// @param[in]  ecol  End of the token inside the line.
void hltokens_append_inline(HighlightedTokens *const tokens,
                            const HighlightType type, const size_t lnr,
                            const size_t scol, const size_t ecol)
{
  if (!tokens) {
    return;
  }
  GA_APPEND(HighlightedToken, tokens, ((HighlightedToken) {
    .type = type,
    .start = { lnr, scol },
    .end = { lnr, ecol },
  }));
}

/// Convert Expression structure to an array of tokens
///
/// @param[out]  tokens  Where to save the results.
/// @param[in]  expr  What to convert.
/// @param[in]  pos  Where does expression start.
void hltokens_convert_expression(HighlightedTokens *const tokens,
                                 const Expression *const expr,
                                 const CommandPosition pos)
  FUNC_ATTR_NONNULL_ALL
{
  return;
}
