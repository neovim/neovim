#ifdef USE_KLEE
# include <klee/klee.h>
#else
# include <string.h>
# include <stdio.h>
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
#include "nvim/keymap.c"
#include "nvim/viml/parser/expressions.c"

#define INPUT_SIZE 7

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
  int flags;
  avoid_optimizing_out = argc;

#ifndef USE_KLEE
  sscanf(argv[2], "%d", &flags);
#endif

#ifdef USE_KLEE
  klee_make_symbolic(input, sizeof(input), "input");
  klee_make_symbolic(&shift, sizeof(shift), "shift");
  klee_make_symbolic(&flags, sizeof(flags), "flags");
  klee_assume(shift < INPUT_SIZE);
  klee_assume(flags <= (kELFlagPeek|kELFlagAllowFloat|kELFlagForbidEOC
                        |kELFlagForbidScope|kELFlagIsNotCmp));
#endif

  ParserLine plines[] = {
    {
#ifdef USE_KLEE
      .data = &input[shift],
      .size = sizeof(input) - shift,
#else
      .data = (const char *)argv[1],
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

  ParserState pstate = {
    .reader = {
      .get_line = simple_get_line,
      .cookie = &cur_pline,
      .lines = KV_INITIAL_VALUE,
      .conv.vc_type = CONV_NONE,
    },
    .pos = { 0, 0 },
    .colors = NULL,
    .can_continuate = false,
  };
  kvi_init(pstate.reader.lines);

  allocated_memory_limit = 0;
  LexExprToken token = viml_pexpr_next_token(&pstate, flags);
  if (flags & kELFlagPeek) {
    assert(pstate.pos.line == 0 && pstate.pos.col == 0);
  } else {
    assert((pstate.pos.line == 0)
           ? (pstate.pos.col > 0)
           : (pstate.pos.line == 1 && pstate.pos.col == 0));
  }
  assert(allocated_memory == 0);
  assert(ever_allocated_memory == 0);
#ifndef USE_KLEE
  fprintf(stderr, "tkn: %s\n", viml_pexpr_repr_token(&pstate, token, NULL));
#endif
}
