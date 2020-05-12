// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include "nvim/viml/parser/parser.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/parser/parser.c.generated.h"
#endif


void parser_simple_get_line(void *cookie, ParserLine *ret_pline)
{
  ParserLine **plines_p = (ParserLine **)cookie;
  *ret_pline = **plines_p;
  (*plines_p)++;
}
