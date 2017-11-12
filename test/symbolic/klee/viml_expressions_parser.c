#ifdef USE_KLEE
# include <klee/klee.h>
#else
# include <string.h>
#endif
#include <stddef.h>
#include <stdint.h>
#include <assert.h>

#include "nvim/viml/parser/expressions.h"
#include "nvim/viml/parser/parser.h"
#include "nvim/mbyte.h"

#include "nvim/memory.c"
#include "nvim/mbyte.c"
#include "nvim/charset.c"
#include "nvim/garray.c"
#include "nvim/gettext.c"
#include "nvim/viml/parser/expressions.c"
#include "nvim/keymap.c"

#define INPUT_SIZE 50

uint8_t avoid_optimizing_out;

void simple_get_line(void *cookie, ParserLine *ret_pline)
{
  ParserLine **plines_p = (ParserLine **)cookie;
  *ret_pline = **plines_p;
  (*plines_p)++;
}

int main(const int argc, const char *const *const argv,
         const char *const *const environ)
{
  char input[INPUT_SIZE];
  uint8_t shift;
  unsigned flags;
  const bool peek = false;
  avoid_optimizing_out = argc;

#ifndef USE_KLEE
  sscanf(argv[2], "%d", &flags);
#endif

#ifdef USE_KLEE
  klee_make_symbolic(input, sizeof(input), "input");
  klee_make_symbolic(&shift, sizeof(shift), "shift");
  klee_make_symbolic(&flags, sizeof(flags), "flags");
  klee_assume(shift < INPUT_SIZE);
  klee_assume(
      flags <= (kExprFlagsMulti|kExprFlagsDisallowEOC|kExprFlagsParseLet));
#endif

  ParserLine plines[] = {
    {
#ifdef USE_KLEE
      .data = &input[shift],
      .size = sizeof(input) - shift,
#else
      .data = argv[1],
      .size = strlen(argv[1]),
#endif
      .allocated = false,
    },
    {
      .data = NULL,
      .size = 0,
      .allocated = false,
    },
  };
#ifdef USE_KLEE
  assert(plines[0].size <= INPUT_SIZE);
  assert((plines[0].data[0] != 5) | (plines[0].data[0] != argc));
#endif
  ParserLine *cur_pline = &plines[0];

  ParserHighlight colors;
  kvi_init(colors);

  ParserState pstate = {
    .reader = {
      .get_line = simple_get_line,
      .cookie = &cur_pline,
      .lines = KV_INITIAL_VALUE,
      .conv.vc_type = CONV_NONE,
    },
    .pos = { 0, 0 },
    .colors = &colors,
    .can_continuate = false,
  };
  kvi_init(pstate.reader.lines);

  const ExprAST ast = viml_pexpr_parse(&pstate, (int)flags);
  assert(ast.root != NULL || ast.err.msg);
  if (flags & kExprFlagsParseLet) {
    assert(ast.err.msg != NULL
           || ast.root->type == kExprNodeAssignment
           || (ast.root->type == kExprNodeListLiteral
               && ast.root->children != NULL)
           || ast.root->type == kExprNodeComplexIdentifier
           || ast.root->type == kExprNodeCurlyBracesIdentifier
           || ast.root->type == kExprNodePlainIdentifier
           || ast.root->type == kExprNodeRegister
           || ast.root->type == kExprNodeEnvironment
           || ast.root->type == kExprNodeOption
           || ast.root->type == kExprNodeSubscript
           || ast.root->type == kExprNodeConcatOrSubscript);
  }
  // Can’t possibly have more highlight tokens then there are bytes in string.
  assert(kv_size(colors) <= INPUT_SIZE - shift);
  kvi_destroy(colors);
  // Not destroying pstate.reader.lines because there is no way it could exceed
  // its limits in the current circumstances.
  viml_pexpr_free_ast(ast);
  assert(allocated_memory == 0);
}
