// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// lua bindings for tree-siter.
// NB: this file should contain a generic lua interface for
// tree-sitter trees and nodes, and could be broken out as a reusable library

#include <stdbool.h>
#include <string.h>
#include <inttypes.h>
#include <assert.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <tree_sitter/runtime.h>

#define REG_KEY "tree_sitter-private"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua/tree_sitter.c.generated.h"
#endif

static struct luaL_Reg tree_meta[] = {
  // {"__gc", tree_gc},
  {"__tostring", tree_tostring},
  {"root", tree_root},
  {NULL, NULL}
};

static struct luaL_Reg node_meta[] = {
  {"__tostring", node_tostring},
  {"__len", node_child_count},
  {"range", node_range},
  {"type", node_type},
  {"symbol", node_symbol},
  {"child_count", node_child_count},
  {"child", node_child},
  {"descendant_for_range", node_descendant_for_point_range},
  {"parent", node_parent},
  {"to_cursor", node_to_cursor},
  {NULL, NULL}
};

static struct luaL_Reg cursor_meta[] = {
  // {"__gc", cursor_gc},
  {"__tostring", cursor_tostring},
  //{"node", cursor_node},
  {"forward", cursor_forward},
  {NULL, NULL}
};

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
  lua_createtable(L, 0, 0);

  // Tree metatable
  lua_createtable(L, 0, 0);
  build_meta(L, tree_meta);
  lua_setfield(L, -2, "tree-meta");

  lua_createtable(L, 0, 0);
  build_meta(L, node_meta);
  lua_setfield(L, -2, "node-meta");

  lua_createtable(L, 0, 0);
  build_meta(L, cursor_meta);
  lua_setfield(L, -2, "cursor-meta");

  lua_setfield(L, LUA_REGISTRYINDEX, REG_KEY);
}

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
}

// Tree methods

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

static int node_to_cursor(lua_State *L)
{
  TSNode node;
  if (!node_check(L, &node)) {
    return 0;
  }
  push_cursor(L, node);
  return 1;
}



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

// Cursor functions

static TSTreeCursor *cursor_check(lua_State *L)
{
  if (!lua_gettop(L)) {
    return NULL;
  }
  if (!lua_isuserdata(L, 1)) {
    return NULL;
  }
  // TODO: typecheck!
  TSTreeCursor *ud = lua_touserdata(L, 1);
  return ud;
}


static int cursor_tostring(lua_State *L)
{
  TSTreeCursor *cursor = cursor_check(L);
  if (!cursor) {
    return 0;
  }
  TSNode node = ts_tree_cursor_current_node(cursor);
  if (ts_node_is_null(node)) {
    lua_pushstring(L, "<cursor nil>");
    return 1;
  }
  lua_pushstring(L, "<cursor ");
  lua_pushstring(L, ts_node_type(node));
  lua_pushstring(L, ">");
  lua_concat(L, 3);
  return 1;
}

static int cursor_forward(lua_State *L)
{
  TSTreeCursor *cursor = cursor_check(L);
  if (!cursor) {
    return 0;
  }

  bool status = false;

  int narg = lua_gettop(L);
  if (narg >= 1) {
    uint32_t byte_index = (uint32_t)lua_tointeger(L, 2);
    status = ts_tree_cursor_goto_first_child_for_byte(cursor, byte_index) != -1;
  } else {
    status = ts_tree_cursor_goto_first_child(cursor);
  }
  if (status) {
    goto ret;
  }

  while (true) {
    status = ts_tree_cursor_goto_next_sibling(cursor);
    if (status) {
      break;
    }

    // Current node was last a child, look for sibling on higher
    // level
    status = ts_tree_cursor_goto_parent(cursor);
    if (!status) { // past end of root node
      break;
    }
  }

ret:
  if (status) {
    push_node(L, ts_tree_cursor_current_node(cursor));
    return 1;
  } else {
    return 0;
  }
}

/// push cursor interface on lua stack, with node as starting point
///
/// top of stack must either be the this node or tree this node belongs to,
/// or another node of the same tree! This value is not popped.
/// Can only be called inside a cfunction with the tslua environment.
static void push_cursor(lua_State *L, TSNode node)
{
  if (ts_node_is_null(node)) {
    lua_pushnil(L); // [src, nil]
    return;
  }
  TSTreeCursor *ud = lua_newuserdata(L, sizeof(TSTreeCursor));  // [src, udata]
  *ud = ts_tree_cursor_new(node);
  lua_getfield(L, LUA_ENVIRONINDEX, "cursor-meta");  // [src, udata, meta]
  lua_setmetatable(L, -2);  // [src, udata]
  lua_getfenv(L, -2);  // [src, udata, reftable]
  lua_setfenv(L, -2);  // [src, udata]
}


