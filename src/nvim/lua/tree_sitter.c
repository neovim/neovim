// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// lua bindings for tree-siter.
// NB: this file should contain a generic lua interface for
// tree-sitter trees and nodes, and could be broken out as a reusable library

#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <assert.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include "tree_sitter/api.h"

// NOT state-safe, delete when GC is confimed working:
static int debug_n_trees = 0, debug_n_cursors = 0;

#define REG_KEY "tree_sitter-private"

#include "nvim/lua/tree_sitter.h"
#include "nvim/api/private/handle.h"
#include "nvim/memline.h"

typedef struct {
    TSParser *parser;
    TSTree *tree;
} Tslua_parser;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua/tree_sitter.c.generated.h"
#endif

static struct luaL_Reg parser_meta[] = {
  {"__gc", parser_gc},
  {"__tostring", parser_tostring},
  {"parse_buf", parser_parse_buf},
  {"edit", parser_edit},
  {"tree", parser_tree},
  {NULL, NULL}
};

static struct luaL_Reg tree_meta[] = {
  {"__gc", tree_gc},
  {"__tostring", tree_tostring},
  {"root", tree_root},
  {NULL, NULL}
};

static struct luaL_Reg node_meta[] = {
  {"__tostring", node_tostring},
  {"__len", node_child_count},
  {"range", node_range},
  {"start", node_start},
  {"type", node_type},
  {"symbol", node_symbol},
  {"child_count", node_child_count},
  {"child", node_child},
  {"descendant_for_point_range", node_descendant_for_point_range},
  {"parent", node_parent},
  {NULL, NULL}
};

PMap(cstr_t) *langs;

void build_meta(lua_State *L, const luaL_Reg *meta)
{
  // [env, target]
  for (size_t i = 0; meta[i].name != NULL; i++) {
    lua_pushcfunction(L, meta[i].func);  // [env, target, func]
    lua_pushvalue(L, -3);  // [env, target, func, env]
    lua_setfenv(L, -2);  // [env, target, func]
    lua_setfield(L, -2, meta[i].name);  // [env, target]
  }

  lua_pushvalue(L, -1);  // [env, target, target]
  lua_setfield(L, -2, "__index");  // [env, target]
}



/// init the tslua library
///
/// all global state is stored in the regirstry of the lua_State
void tslua_init(lua_State *L)
{

  langs = pmap_new(cstr_t)();

  lua_createtable(L, 0, 0);

  // type metatables
  lua_createtable(L, 0, 0);
  build_meta(L, parser_meta);
  lua_setfield(L, -2, "parser-meta");

  lua_createtable(L, 0, 0);
  build_meta(L, tree_meta);
  lua_setfield(L, -2, "tree-meta");

  lua_createtable(L, 0, 0);
  build_meta(L, node_meta);
  lua_setfield(L, -2, "node-meta");

  lua_setfield(L, LUA_REGISTRYINDEX, REG_KEY);

  lua_pushcfunction(L, tslua_debug);
  lua_setglobal(L, "_tslua_debug");
}

static int tslua_debug(lua_State *L)
{
  lua_pushinteger(L, debug_n_trees);
  lua_pushinteger(L, debug_n_cursors);
  return 2;
}


int ts_lua_register_lang(lua_State *L)
{
  if (lua_gettop(L) < 2 || !lua_isstring(L, 1) || !lua_isstring(L, 2)) {
    return luaL_error(L, "string expected");
  }

  const char *path = lua_tostring(L,1);
  const char *lang_name = lua_tostring(L,2);

  if (pmap_has(cstr_t)(langs, lang_name)) {
    return 0;
  }

  // TODO: unsafe!
  char symbol_buf[128] = "tree_sitter_";
  STRCAT(symbol_buf, lang_name);

  // TODO: we should maybe keep the uv_lib_t around, and close them
  // at exit, to keep LeakSanitizer happy.
  uv_lib_t lib;
  if (uv_dlopen(path, &lib)) {
    return luaL_error(L, "Failed to load parser: uv_dlopen: %s", uv_dlerror(&lib));
  }

  TSLanguage *(*lang_parser)(void);
  if (uv_dlsym(&lib, symbol_buf, (void **)&lang_parser)) {
    return luaL_error(L, "Failed to load parser: uv_dlsym: %s", uv_dlerror(&lib));
  }

  TSLanguage *lang = lang_parser();
  if (lang == NULL) {
    return luaL_error(L, "Failed to load parser: internal error");
  }

  pmap_put(cstr_t)(langs, xstrdup(lang_name), lang);

  lua_pushboolean(L, true);
  return 1;
}

int tslua_push_parser(lua_State *L, const char *lang_name)
{
  TSParser *parser = ts_parser_new();
  TSLanguage *lang = pmap_get(cstr_t)(langs, lang_name);
  if (!lang) {
    return luaL_error(L, "no such language: %s", lang_name);
  }

  ts_parser_set_language(parser, lang);
  Tslua_parser *p = lua_newuserdata(L, sizeof(Tslua_parser));  // [udata]
  p->parser = parser;
  p->tree = NULL;

  lua_getfield(L, LUA_REGISTRYINDEX, REG_KEY);  // [udata, env]
  lua_getfield(L, -1, "parser-meta");  // [udata, env, meta]
  lua_setmetatable(L, -3);  // [udata, env]
  lua_pop(L, 1);  // [udata]
  return 1;
}

static Tslua_parser *parser_check(lua_State *L)
{
  if (!lua_gettop(L)) {
    return 0;
  }
  if (!lua_isuserdata(L, 1)) {
    return 0;
  }
  // TODO: typecheck!
  return lua_touserdata(L, 1);
}

static int parser_gc(lua_State *L)
{
  Tslua_parser *p = parser_check(L);
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

static const char *input_cb(void *payload, uint32_t byte_index, TSPoint position, uint32_t *bytes_read)
{
   buf_T *bp  = payload;
   static char buf[200];
   if ((linenr_T)position.row >= bp->b_ml.ml_line_count) {
     *bytes_read = 0;
     return "";
   }
   char_u *line = ml_get_buf(bp, position.row+1, false);
   size_t len = STRLEN(line);
   size_t tocopy = MIN(len-position.column,200);

   // TODO: translate embedded \n to \000
   memcpy(buf, line+position.column, tocopy);
   *bytes_read = (uint32_t)tocopy;
   if (tocopy < 200) {
     buf[tocopy] = '\n';
     (*bytes_read)++;
   }
   return buf;
}

static int parser_parse_buf(lua_State *L)
{
  Tslua_parser *p = parser_check(L);
  if (!p) {
    return 0;
  }

  long bufnr = lua_tointeger(L, 2);
  void *payload = handle_get_buffer(bufnr);
  TSInput input = {payload, input_cb, TSInputEncodingUTF8};
  TSTree *new_tree = ts_parser_parse(p->parser, p->tree, input);
  if (p->tree) {
    ts_tree_delete(p->tree);
  }
  p->tree = new_tree;

  tslua_push_tree(L, ts_tree_copy(p->tree));
  return 1;
}

static int parser_tree(lua_State *L)
{
  Tslua_parser *p = parser_check(L);
  if (!p) {
    return 0;
  }

  if (p->tree) {
    tslua_push_tree(L, ts_tree_copy(p->tree));
  } else {
    lua_pushnil(L);
  }
  return 1;
}

static int parser_edit(lua_State *L)
{
  if(lua_gettop(L) < 10) {
    lua_pushstring(L, "not enough args to parser:edit()");
    lua_error(L);
    return 0; // unreachable
  }

  Tslua_parser *p = parser_check(L);
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
/// This takes "ownership" of the tree and will free it
/// when the wrapper object is garbage collected
void tslua_push_tree(lua_State *L, TSTree *tree)
{
  TSTree **ud = lua_newuserdata(L, sizeof(TSTree *));  // [udata]
  *ud = tree;
  lua_getfield(L, LUA_REGISTRYINDEX, REG_KEY);  // [udata, env]
  lua_getfield(L, -1, "tree-meta");  // [udata, env, meta]
  lua_setmetatable(L, -3);  // [udata, env]
  lua_pop(L, 1);  // [udata]

  // table used for node wrappers to keep a reference to tree wrapper
  // NB: in lua 5.3 the uservalue for the node could just be the tree, but
  // in lua 5.1 the uservalue (fenv) must be a table.
  lua_createtable(L, 1, 0); // [udata, reftable]
  lua_pushvalue(L, -2); // [udata, reftable, udata]
  lua_rawseti(L, -2, 1); // [udata, reftable]
  lua_setfenv(L, -2); // [udata]
  debug_n_trees++;
}

static TSTree *tree_check(lua_State *L)
{
  if (!lua_gettop(L)) {
    return 0;
  }
  if (!lua_isuserdata(L, 1)) {
    return 0;
  }
  // TODO: typecheck!
  TSTree **ud = lua_touserdata(L, 1);
  return *ud;
}

static int tree_gc(lua_State *L)
{
  TSTree *tree = tree_check(L);
  if (!tree) {
    return 0;
  }

  ts_tree_delete(tree);
  debug_n_trees--;
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
    lua_pushnil(L); // [src, nil]
    return;
  }
  TSNode *ud = lua_newuserdata(L, sizeof(TSNode));  // [src, udata]
  *ud = node;
  lua_getfield(L, LUA_ENVIRONINDEX, "node-meta");  // [src, udata, meta]
  lua_setmetatable(L, -2);  // [src, udata]
  lua_getfenv(L, -2);  // [src, udata, reftable]
  lua_setfenv(L, -2);  // [src, udata]
}

static bool node_check(lua_State *L, TSNode *res)
{
  if (!lua_gettop(L)) {
    return 0;
  }
  if (!lua_isuserdata(L, 1)) {
    return 0;
  }
  // TODO: typecheck!
  TSNode *ud = lua_touserdata(L, 1);
  *res = *ud;
  return true;
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

static int node_descendant_for_point_range(lua_State *L)
{
  TSNode node;
  if (!node_check(L, &node)) {
    return 0;
  }
  TSPoint start = {(uint32_t)lua_tointeger(L, 2),
                   (uint32_t)lua_tointeger(L, 3)};
  TSPoint end = {(uint32_t)lua_tointeger(L, 4),
                 (uint32_t)lua_tointeger(L, 5)};
  TSNode child = ts_node_descendant_for_point_range(node, start, end);

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

