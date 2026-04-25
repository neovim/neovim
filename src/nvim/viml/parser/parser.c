#include "nvim/func_attr.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/viml/parser/parser.h"

#include "viml/parser/parser.c.generated.h"  // IWYU pragma: export

void parser_simple_get_line(void *cookie, ParserLine *ret_pline)
  FUNC_ATTR_NONNULL_ALL
{
  ParserLine **plines_p = (ParserLine **)cookie;
  *ret_pline = **plines_p;
  (*plines_p)++;
}

/// Get currently parsed line, shifted to pstate->pos.col
///
/// @param  pstate  Parser state to operate on.
///
/// @return True if there is a line, false in case of EOF.
bool viml_parser_get_remaining_line(ParserState *const pstate, ParserLine *const ret_pline)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
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

/// Get one line from ParserInputReader
static void viml_preader_get_line(ParserInputReader *const preader, ParserLine *const ret_pline)
  FUNC_ATTR_NONNULL_ALL
{
  ParserLine pline;
  preader->get_line(preader->cookie, &pline);
  if (preader->conv.vc_type != CONV_NONE && pline.size) {
    ParserLine cpline = {
      .allocated = true,
      .size = pline.size,
    };
    cpline.data = string_convert(&preader->conv, (char *)pline.data, &cpline.size);
    if (pline.allocated) {
      xfree((void *)pline.data);
    }
    pline = cpline;
  }
  kvi_push(preader->lines, pline);
  *ret_pline = pline;
}

/// Free all memory allocated by the parser on heap
///
/// @param  pstate  Parser state to free.
void viml_parser_destroy(ParserState *const pstate)
  FUNC_ATTR_NONNULL_ALL
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
