#include <stddef.h>
#include <assert.h>
#include "nvim/api/private/defs.h"
#include "nvim/memory.h"

#include "nvim/viml/viml.h"
#include "nvim/viml/parser/ex_commands.h"
#include "nvim/viml/translator/translator.h"
#include "nvim/viml/executor/executor.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/viml.c.generated.h"
#endif

/// Execute viml string
///
/// @param[in]  s  String which will be executed.
///
/// @return OK in case of success, FAIL otherwise.
Object execute_viml(const char *const s)
  FUNC_ATTR_NONNULL_ALL
{
  CommandParserOptions o = {
    .flags = 0,            // FIXME add CPO, RL and ALTKEYMAP options
    .early_return = false
  };
  char *const dup = xstrdup(s);

  ParserResult *pres = parse_string(o, "<:execute string>", NULL,
                                    (VimlLineGetter) &do_fgetline_allocated,
                                    (void *) &dup);
  if (pres == NULL) {
    return (Object) { .type = kObjectTypeNil };
  }

  size_t len = stranslate_len(kTransUser, pres);
  String lua_str = {
    .size = len,
    .data = xcalloc(len, 1)
  };
  char *p = lua_str.data;
  stranslate(kTransUser, pres, &p);
  free_parser_result(pres);
  assert(p - lua_str.data <= (ptrdiff_t) lua_str.size);
  lua_str.size = (size_t) (p - lua_str.data);

  Error err = {
    .set = false
  };
  Object lua_ret = eval_lua(lua_str, &err);
  xfree(lua_str.data);
  if (err.set) {
    return (Object) { .type = kObjectTypeNil };
  }

  return lua_ret;
}
