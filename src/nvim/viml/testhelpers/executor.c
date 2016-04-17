#include <stddef.h>
#include <assert.h>
#include <stdio.h>
#include "nvim/types.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/memory.h"
#include "nvim/os/os.h"

#include "nvim/viml/viml.h"
#include "nvim/viml/parser/ex_commands.h"
#include "nvim/viml/translator/translator.h"
#include "nvim/viml/executor/executor.h"
#include "nvim/viml/testhelpers/object.h"
#include "nvim/viml/testhelpers/fgetline.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/testhelpers/executor.c.generated.h"
#endif

char *execute_viml_test(const char *const s)
{
  CommandParserOptions o = {
    .flags = 0,            // FIXME add CPO, RL and ALTKEYMAP options
    .early_return = false
  };
  Error err = {
    .set = false
  };
  char *const dup = xstrdup(s);

  ParserResult *pres = parse_string(o, "<:execute string>", NULL,
                                    (VimlLineGetter) &fgetline_string,
                                    (void *) &dup);
  if (pres == NULL) {
    return NULL;
  }

  String lua_str_test = {
    .data = "vim.test.start()\n"
  };
  lua_str_test.size = STRLEN(lua_str_test.data);
  Object lua_test_ret = eval_lua(lua_str_test, &err);
  if (err.set) {
    return NULL;
  }
  api_free_object(lua_test_ret);

  size_t len = stranslate_len(kTransUser, pres);
#define TEST_RET "return vim.test.finish(state)"
  String lua_str = {
    .size = len,
    .data = xcalloc(len + sizeof(TEST_RET), 1)
  };
  char *p = lua_str.data;
  stranslate(kTransUser, pres, &p);
  free_parser_result(pres);
  assert(p - lua_str.data <= (ptrdiff_t) lua_str.size);
  memcpy(p, TEST_RET, sizeof(TEST_RET));
  lua_str.size = ((size_t) (p - lua_str.data) + sizeof(TEST_RET) - 1);

  if (os_getenv("NEOVIM_SHOW_TRANSLATED_LUA") != NULL) {
    fputs("\n-------- Lua --------\n", stderr);
    fwrite(lua_str.data, 1, lua_str.size, stderr);
    fputs("\n---------------------\n", stderr);
  }
#undef TEST_RET

  Object lua_ret = eval_lua(lua_str, &err);
  xfree(lua_str.data);
  if (err.set) {
    api_free_object(lua_ret);
    return NULL;
  }

  size_t ret_len = sdump_object_len(lua_ret);
  char *ret = xcalloc(ret_len + 1, 1);
  p = ret;
  sdump_object(lua_ret, &p);

  api_free_object(lua_ret);

  return ret;
}
