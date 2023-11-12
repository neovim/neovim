#include "nvim/viml/parser/parser.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/parser/parser.c.generated.h"  // IWYU pragma: export
#endif

void parser_simple_get_line(void *cookie, ParserLine *ret_pline)
{
  ParserLine **plines_p = (ParserLine **)cookie;
  *ret_pline = **plines_p;
  (*plines_p)++;
}
