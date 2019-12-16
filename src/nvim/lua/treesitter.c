// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// lua bindings for tree-sitter.
// NB: this file mostly contains a generic lua interface for tree-sitter
// trees and nodes, and could be broken out as a reusable lua package

#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <assert.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include "tree_sitter/api.h"

#include "nvim/lua/treesitter.h"
#include "nvim/api/private/handle.h"
#include "nvim/memline.h"

typedef struct {
  TSParser *parser;
  TSTree *tree;  // internal tree, used for editing/reparsing
} TSLua_parser;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua/treesitter.c.generated.h"
#endif

static struct luaL_Reg parser_meta[] = {
  { "__gc", parser_gc },
  { "__tostring", parser_tostring },
  { "parse_buf", parser_parse_buf },
  { "edit", parser_edit },
  { "tree", parser_tree },
  { NULL, NULL }
};

static struct luaL_Reg tree_meta[] = {
  { "__gc", tree_gc },
  { "__tostring", tree_tostring },
  { "root", tree_root },
  { NULL, NULL }
};

static struct luaL_Reg node_meta[] = {
  { "__tostring", node_tostring },
  { "__eq", node_eq },
  { "__len", node_child_count },
  { "range", node_range },
  { "start", node_start },
  { "end_", node_end },
  { "type", node_type },
  { "symbol", node_symbol },
  { "named", node_named },
  { "missing", node_missing },
  { "has_error", node_has_error },
  { "sexpr", node_sexpr },
  { "child_count", node_child_count },
  { "named_child_count", node_named_child_count },
  { "child", node_child },
  { "named_child", node_named_child },
  { "descendant_for_range", node_descendant_for_range },
  { "named_descendant_for_range", node_named_descendant_for_range },
  { "parent", node_parent },
  { NULL, NULL }
};

static PMap(cstr_t) *langs;

static void build_meta(lua_State *L, const char *tname, const luaL_Reg *meta)
{
  if (luaL_newmetatable(L, tname)) {  // [meta]
    for (size_t i = 0; meta[i].name != NULL; i++) {
      lua_pushcfunction(L, meta[i].func);  // [meta, func]
      lua_setfield(L, -2, meta[i].name);  // [meta]
    }

    lua_pushvalue(L, -1);  // [meta, meta]
    lua_setfield(L, -2, "__index");  // [meta]
  }
  lua_pop(L, 1);  // [] (don't use it now)
}

/// init the tslua library
///
/// all global state is stored in the regirstry of the lua_State
void tslua_init(lua_State *L)
{
  langs = pmap_new(cstr_t)();

  // type metatables
  build_meta(L, "treesitter_parser", parser_meta);
  build_meta(L, "treesitter_tree", tree_meta);
  build_meta(L, "treesitter_node", node_meta);
}

int tslua_register_lang(lua_State *L)
{
  if (lua_gettop(L) < 2 || !lua_isstring(L, 1) || !lua_isstring(L, 2)) {
    return luaL_error(L, "string expected");
  }

  const char *path = lua_tostring(L, 1);
  const char *lang_name = lua_tostring(L, 2);

  if (pmap_has(cstr_t)(langs, lang_name)) {
    return 0;
  }

#define BUFSIZE 128
  char symbol_buf[BUFSIZE];
  snprintf(symbol_buf, BUFSIZE, "tree_sitter_%s", lang_name);
#undef BUFSIZE

  uv_lib_t lib;
  if (uv_dlopen(path, &lib)) {
    snprintf((char *)IObuff, IOSIZE, "Failed to load parser: uv_dlopen: %s",
             uv_dlerror(&lib));
    uv_dlclose(&lib);
    lua_pushstring(L, (char *)IObuff);
    return lua_error(L);
  }

  TSLanguage *(*lang_parser)(void);
  if (uv_dlsym(&lib, symbol_buf, (void **)&lang_parser)) {
    snprintf((char *)IObuff, IOSIZE, "Failed to load parser: uv_dlsym: %s",
             uv_dlerror(&lib));
    uv_dlclose(&lib);
    lua_pushstring(L, (char *)IObuff);
    return lua_error(L);
  }

  TSLanguage *lang = lang_parser();
  if (lang == NULL) {
    return luaL_error(L, "Failed to load parser: internal error");
  }

  pmap_put(cstr_t)(langs, xstrdup(lang_name), lang);

  lua_pushboolean(L, true);
  return 1;
}

int tslua_inspect_lang(lua_State *L)
{
  if (lua_gettop(L) < 1 || !lua_isstring(L, 1)) {
    return luaL_error(L, "string expected");
  }
  const char *lang_name = lua_tostring(L, 1);

  TSLanguage *lang = pmap_get(cstr_t)(langs, lang_name);
  if (!lang) {
    return luaL_error(L, "no such language: %s", lang_name);
  }

  lua_createtable(L, 0, 2);  // [retval]

  size_t nsymbols = (size_t)ts_language_symbol_count(lang);

  lua_createtable(L, nsymbols-1, 1);  // [retval, symbols]
  for (size_t i = 0; i < nsymbols; i++) {
    TSSymbolType t = ts_language_symbol_type(lang, i);
    if (t == TSSymbolTypeAuxiliary) {
      // not used by the API
      continue;
    }
    lua_createtable(L, 2, 0);  // [retval, symbols, elem]
    lua_pushstring(L, ts_language_symbol_name(lang, i));
    lua_rawseti(L, -2, 1);
    lua_pushboolean(L, t == TSSymbolTypeRegular);
    lua_rawseti(L, -2, 2);  // [retval, symbols, elem]
    lua_rawseti(L, -2, i);  // [retval, symbols]
  }

  lua_setfield(L, -2, "symbols");  // [retval]

  size_t nfields = (size_t)ts_language_field_count(lang);
  lua_createtable(L, nfields-1, 1);  // [retval, fields]
  for (size_t i = 0; i < nfields; i++) {
    lua_pushstring(L, ts_language_field_name_for_id(lang, i));
    lua_rawseti(L, -2, i);  // [retval, fields]
  }

  lua_setfield(L, -2, "fields");  // [retval]
  return 1;
}

int tslua_push_parser(lua_State *L, const char *lang_name)
{
  TSLanguage *lang = pmap_get(cstr_t)(langs, lang_name);
  if (!lang) {
    return luaL_error(L, "no such language: %s", lang_name);
  }

  TSParser *parser = ts_parser_new();
  ts_parser_set_language(parser, lang);
  TSLua_parser *p = lua_newuserdata(L, sizeof(TSLua_parser));  // [udata]
  p->parser = parser;
  p->tree = NULL;

  lua_getfield(L, LUA_REGISTRYINDEX, "treesitter_parser");  // [udata, meta]
  lua_setmetatable(L, -2);  // [udata]
  return 1;
}

static TSLua_parser *parser_check(lua_State *L)
{
  return luaL_checkudata(L, 1, "treesitter_parser");
}

static int parser_gc(lua_State *L)
{
  TSLua_parser *p = parser_check(L);
  if (!p) {
    return 0;
  }

  ts_parser_delete(p->parser);
  if (p->tree) {
    ts_tree_delete(p->tree);
  }

  return 0;
}

static int parser_tostring(lua_State *L)
{
  lua_pushstring(L, "<parser>");
  return 1;
}

static const char *input_cb(void *payload, uint32_t byte_index,
                            TSPoint position, uint32_t *bytes_read)
{
  buf_T *bp  = payload;
#define BUFSIZE 256
  static char buf[BUFSIZE];

  if ((linenr_T)position.row >= bp->b_ml.ml_line_count) {
    *bytes_read = 0;
    return "";
  }
  char_u *line = ml_get_buf(bp, position.row+1, false);
  size_t len = STRLEN(line);
  size_t tocopy = MIN(len-position.column, BUFSIZE);

  memcpy(buf, line+position.column, tocopy);
  // Translate embedded \n to NUL
  memchrsub(buf, '\n', '\0', tocopy);
  *bytes_read = (uint32_t)tocopy;
  if (tocopy < BUFSIZE) {
    // now add the final \n. If it didn't fit, input_cb will be called again
    // on the same line with advanced column.
    buf[tocopy] = '\n';
    (*bytes_read)++;
  }
  return buf;
#undef BUFSIZE
}

static int parser_parse_buf(lua_State *L)
{
  TSLua_parser *p = parser_check(L);
  if (!p) {
    return 0;
  }

  long bufnr = lua_tointeger(L, 2);
  void *payload = handle_get_buffer(bufnr);
  if (!payload) {
    return luaL_error(L, "invalid buffer handle: %d", bufnr);
  }
  TSInput input = { payload, input_cb, TSInputEncodingUTF8 };
  TSTree *new_tree = ts_parser_parse(p->parser, p->tree, input);
  if (p->tree) {
    ts_tree_delete(p->tree);
  }
  p->tree = new_tree;

  tslua_push_tree(L, p->tree);
  return 1;
}

static int parser_tree(lua_State *L)
{
  TSLua_parser *p = parser_check(L);
  if (!p) {
    return 0;
  }

  tslua_push_tree(L, p->tree);
  return 1;
}

static int parser_edit(lua_State *L)
{
  if (lua_gettop(L) < 10) {
    lua_pushstring(L, "not enough args to parser:edit()");
    return lua_error(L);
  }

  TSLua_parser *p = parser_check(L);
  if (!p) {
    return 0;
  }

  if (!p->tree) {
    return 0;
  }

  long start_byte = lua_tointeger(L, 2);
  long old_end_byte = lua_tointeger(L, 3);
  long new_end_byte = lua_tointeger(L, 4);
  TSPoint start_point = { lua_tointeger(L, 5), lua_tointeger(L, 6) };
  TSPoint old_end_point = { lua_tointeger(L, 7), lua_tointeger(L, 8) };
  TSPoint new_end_point = { lua_tointeger(L, 9), lua_tointeger(L, 10) };

  TSInputEdit edit = { start_byte, old_end_byte, new_end_byte,
                       start_point, old_end_point, new_end_point };

  ts_tree_edit(p->tree, &edit);

  return 0;
}


// Tree methods

/// push tree interface on lua stack.
///
/// This makes a copy of the tree, so ownership of the argument is unaffected.
void tslua_push_tree(lua_State *L, TSTree *tree)
{
  if (tree == NULL) {
    lua_pushnil(L);
    return;
  }
  TSTree **ud = lua_newuserdata(L, sizeof(TSTree *));  // [udata]
  *ud = ts_tree_copy(tree);
  lua_getfield(L, LUA_REGISTRYINDEX, "treesitter_tree");  // [udata, meta]
  lua_setmetatable(L, -2);  // [udata]

  // table used for node wrappers to keep a reference to tree wrapper
  // NB: in lua 5.3 the uservalue for the node could just be the tree, but
  // in lua 5.1 the uservalue (fenv) must be a table.
  lua_createtable(L, 1, 0);  // [udata, reftable]
  lua_pushvalue(L, -2);  // [udata, reftable, udata]
  lua_rawseti(L, -2, 1);  // [udata, reftable]
  lua_setfenv(L, -2);  // [udata]
}

static TSTree *tree_check(lua_State *L)
{
  TSTree **ud = luaL_checkudata(L, 1, "treesitter_tree");
  return *ud;
}

static int tree_gc(lua_State *L)
{
  TSTree *tree = tree_check(L);
  if (!tree) {
    return 0;
  }

  ts_tree_delete(tree);
  return 0;
}

static int tree_tostring(lua_State *L)
{
  lua_pushstring(L, "<tree>");
  return 1;
}

static int tree_root(lua_State *L)
{
  TSTree *tree = tree_check(L);
  if (!tree) {
    return 0;
  }
  TSNode root = ts_tree_root_node(tree);
  push_node(L, root);
  return 1;
}

// Node methods

/// push node interface on lua stack
///
/// top of stack must either be the tree this node belongs to or another node
/// of the same tree! This value is not popped. Can only be called inside a
/// cfunction with the tslua environment.
static void push_node(lua_State *L, TSNode node)
{
  if (ts_node_is_null(node)) {
    lua_pushnil(L);  // [src, nil]
    return;
  }
  TSNode *ud = lua_newuserdata(L, sizeof(TSNode));  // [src, udata]
  *ud = node;
  lua_getfield(L, LUA_REGISTRYINDEX, "treesitter_node");  // [src, udata, meta]
  lua_setmetatable(L, -2);  // [src, udata]
  lua_getfenv(L, -2);  // [src, udata, reftable]
  lua_setfenv(L, -2);  // [src, udata]
}

static bool node_check(lua_State *L, TSNode *res)
{
  TSNode *ud = luaL_checkudata(L, 1, "treesitter_node");
  if (ud) {
    *res = *ud;
    return true;
  }
  return false;
}


static int node_tostring(lua_State *L)
{
  TSNode node;
  if (!node_check(L, &node)) {
    return 0;
  }
  lua_pushstring(L, "<node ");
  lua_pushstring(L, ts_node_type(node));
  lua_pushstring(L, ">");
  lua_concat(L, 3);
  return 1;
}

static int node_eq(lua_State *L)
{
  TSNode node;
  if (!node_check(L, &node)) {
    return 0;
  }
  // This should only be called if both x and y in "x == y" has the
  // treesitter_node metatable. So it is ok to error out otherwise.
  TSNode *ud = luaL_checkudata(L, 2, "treesitter_node");
  if (!ud) {
    return 0;
  }
  TSNode node2 = *ud;
  lua_pushboolean(L, ts_node_eq(node, node2));
  return 1;
}

static int node_range(lua_State *L)
{
  TSNode node;
  if (!node_check(L, &node)) {
    return 0;
  }
  TSPoint start = ts_node_start_point(node);
  TSPoint end = ts_node_end_point(node);
  lua_pushnumber(L, start.row);
  lua_pushnumber(L, start.column);
  lua_pushnumber(L, end.row);
  lua_pushnumber(L, end.column);
  return 4;
}

static int node_start(lua_State *L)
{
  TSNode node;
  if (!node_check(L, &node)) {
    return 0;
  }
  TSPoint start = ts_node_start_point(node);
  uint32_t start_byte = ts_node_start_byte(node);
  lua_pushnumber(L, start.row);
  lua_pushnumber(L, start.column);
  lua_pushnumber(L, start_byte);
  return 3;
}

static int node_end(lua_State *L)
{
  TSNode node;
  if (!node_check(L, &node)) {
    return 0;
  }
  TSPoint end = ts_node_end_point(node);
  uint32_t end_byte = ts_node_end_byte(node);
  lua_pushnumber(L, end.row);
  lua_pushnumber(L, end.column);
  lua_pushnumber(L, end_byte);
  return 3;
}

static int node_child_count(lua_State *L)
{
  TSNode node;
  if (!node_check(L, &node)) {
    return 0;
  }
  uint32_t count = ts_node_child_count(node);
  lua_pushnumber(L, count);
  return 1;
}

static int node_named_child_count(lua_State *L)
{
  TSNode node;
  if (!node_check(L, &node)) {
    return 0;
  }
  uint32_t count = ts_node_named_child_count(node);
  lua_pushnumber(L, count);
  return 1;
}

static int node_type(lua_State *L)
{
  TSNode node;
  if (!node_check(L, &node)) {
    return 0;
  }
  lua_pushstring(L, ts_node_type(node));
  return 1;
}

static int node_symbol(lua_State *L)
{
  TSNode node;
  if (!node_check(L, &node)) {
    return 0;
  }
  TSSymbol symbol = ts_node_symbol(node);
  lua_pushnumber(L, symbol);
  return 1;
}

static int node_named(lua_State *L)
{
  TSNode node;
  if (!node_check(L, &node)) {
    return 0;
  }
  lua_pushboolean(L, ts_node_is_named(node));
  return 1;
}

static int node_sexpr(lua_State *L)
{
  TSNode node;
  if (!node_check(L, &node)) {
    return 0;
  }
  char *allocated = ts_node_string(node);
  lua_pushstring(L, allocated);
  xfree(allocated);
  return 1;
}

static int node_missing(lua_State *L)
{
  TSNode node;
  if (!node_check(L, &node)) {
    return 0;
  }
  lua_pushboolean(L, ts_node_is_missing(node));
  return 1;
}

static int node_has_error(lua_State *L)
{
  TSNode node;
  if (!node_check(L, &node)) {
    return 0;
  }
  lua_pushboolean(L, ts_node_has_error(node));
  return 1;
}

static int node_child(lua_State *L)
{
  TSNode node;
  if (!node_check(L, &node)) {
    return 0;
  }
  long num = lua_tointeger(L, 2);
  TSNode child = ts_node_child(node, (uint32_t)num);

  lua_pushvalue(L, 1);
  push_node(L, child);
  return 1;
}

static int node_named_child(lua_State *L)
{
  TSNode node;
  if (!node_check(L, &node)) {
    return 0;
  }
  long num = lua_tointeger(L, 2);
  TSNode child = ts_node_named_child(node, (uint32_t)num);

  lua_pushvalue(L, 1);
  push_node(L, child);
  return 1;
}

static int node_descendant_for_range(lua_State *L)
{
  TSNode node;
  if (!node_check(L, &node)) {
    return 0;
  }
  TSPoint start = { (uint32_t)lua_tointeger(L, 2),
                   (uint32_t)lua_tointeger(L, 3) };
  TSPoint end = { (uint32_t)lua_tointeger(L, 4),
                 (uint32_t)lua_tointeger(L, 5) };
  TSNode child = ts_node_descendant_for_point_range(node, start, end);

  lua_pushvalue(L, 1);
  push_node(L, child);
  return 1;
}

static int node_named_descendant_for_range(lua_State *L)
{
  TSNode node;
  if (!node_check(L, &node)) {
    return 0;
  }
  TSPoint start = { (uint32_t)lua_tointeger(L, 2),
                   (uint32_t)lua_tointeger(L, 3) };
  TSPoint end = { (uint32_t)lua_tointeger(L, 4),
                 (uint32_t)lua_tointeger(L, 5) };
  TSNode child = ts_node_named_descendant_for_point_range(node, start, end);

  lua_pushvalue(L, 1);
  push_node(L, child);
  return 1;
}

static int node_parent(lua_State *L)
{
  TSNode node;
  if (!node_check(L, &node)) {
    return 0;
  }
  TSNode parent = ts_node_parent(node);
  push_node(L, parent);
  return 1;
}

