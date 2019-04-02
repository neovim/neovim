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

#include <tree_sitter/api.h>

#define REG_KEY "tree_sitter-private"

#include "nvim/lib/kvec.h"
#include "nvim/lua/tree_sitter.h"
#include "nvim/buffer.h" // for nvim_ts_read_cb

typedef struct {
  TSParser *parser;
  TSTree *tree;
} Tslua_parser;

typedef struct {
  int kind_id;
  int next_state_id;
  int child_index;
  int regex_index;
} KindTransition;

typedef struct  {
  int default_next_state_id;
  int property_id;
  kvec_t(KindTransition) kind_trans;
  int *kind_first_trans;
} PropertyState;

typedef struct {
  PropertyState *states;
  int n_states;
  int n_kinds;
} Tslua_propertysheet;

typedef struct {
  TSTreeCursor cursor;
  Tslua_propertysheet *sheet;
  int state_id[32];
  int child_index[32];
  int level;
  //Buffer source;
} Tslua_cursor;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua/tree_sitter.c.generated.h"
#endif

static struct luaL_Reg parser_meta[] = {
  {"__gc", parser_gc},
  {"__tostring", parser_tostring},
  {"parse_buf", parser_parse_buf},
  {"edit", parser_edit},
  {"tree", parser_tree},
  {"symbols", parser_symbols},
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
  {"end_byte", node_end_byte},
  {"type", node_type},
  {"symbol", node_symbol},
  {"child_count", node_child_count},
  {"child", node_child},
  {"descendant_for_point_range", node_descendant_for_point_range},
  {"parent", node_parent},
  {"to_cursor", node_to_cursor},
  {NULL, NULL}
};

static struct luaL_Reg cursor_meta[] = {
  {"__gc", cursor_gc},
  {"__tostring", cursor_tostring},
  //{"node", cursor_node},
  {"forward", cursor_forward},
  {"debug", cursor_debug},
  {NULL, NULL}
};

static struct luaL_Reg propertysheet_meta[] = {
  {"__gc", propertysheet_gc},
  {"__tostring", propertysheet_tostring},
  {"add_state", propertysheet_add_state},
  {"add_transition", propertysheet_add_transition},
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

  lua_createtable(L, 0, 0);
  build_meta(L, cursor_meta);
  lua_setfield(L, -2, "cursor-meta");

  lua_createtable(L, 0, 0);
  build_meta(L, propertysheet_meta);
  lua_setfield(L, -2, "propertysheet-meta");

  lua_setfield(L, LUA_REGISTRYINDEX, REG_KEY);
}

void tslua_push_parser(lua_State *L, TSLanguage *lang)
{
  TSParser *parser = ts_parser_new();
  ts_parser_set_language(parser, lang);
  Tslua_parser *p = lua_newuserdata(L, sizeof(Tslua_parser));  // [udata]
  p->parser = parser;
  p->tree = NULL;

  lua_getfield(L, LUA_REGISTRYINDEX, REG_KEY);  // [udata, env]
  lua_getfield(L, -1, "parser-meta");  // [udata, env, meta]
  lua_setmetatable(L, -3);  // [udata, env]
  lua_pop(L, 1);  // [udata]
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

static int parser_parse_buf(lua_State *L)
{
  Tslua_parser *p = parser_check(L);
  if (!p) {
    return 0;
  }

  long num = lua_tointeger(L, 2);
  void *payload = nvim_ts_read_payload(num);
  TSInput input = {payload, nvim_ts_read_cb, TSInputEncodingUTF8};
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
    return lua_error(L);
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

static int parser_symbols(lua_State *L)
{
  Tslua_parser *p = parser_check(L);  // [parser]
  if (!p) {
    return 0;
  }

  const TSLanguage *lang = ts_parser_language(p->parser);

  size_t nsymb = (size_t)ts_language_symbol_count(lang);

  lua_createtable(L, nsymb-1, 1);  // [parser, result]
  for (size_t i = 0; i < nsymb; i++) {
    lua_createtable(L, 2, 0);  // [parser, result, elem]
    lua_pushstring(L, ts_language_symbol_name(lang, i));
    lua_rawseti(L, -2, 1);
    TSSymbolType t= ts_language_symbol_type(lang, i);
    lua_pushstring(L, (t == TSSymbolTypeRegular
                       ? "named" : (t == TSSymbolTypeAnonymous
                                    ? "anonymous" : "auxiliary")));
    lua_rawseti(L, -2, 2); // [parser, result, elem]
    lua_rawseti(L, -2, i); // [parser, result]
  }

  return 1;
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

  // ts_tree_delete(tree);
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
  //lua_getfenv(L, -2);  // [src, udata, reftable]
  //lua_setfenv(L, -2);  // [src, udata]
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

static int node_end_byte(lua_State *L)
{
  TSNode node;
  if (!node_check(L, &node)) {
    return 0;
  }
  uint32_t end_byte = ts_node_end_byte(node);
  lua_pushnumber(L, end_byte);
  return 1;
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
  Tslua_propertysheet *sheet = NULL;

  if (lua_gettop(L) >= 2) {
    if (!lua_isuserdata(L, 2)) {
      return 0;
    }
    // TODO: typecheck!
    sheet = lua_touserdata(L, 2);
  }


  if (ts_node_is_null(node)) {
    lua_pushnil(L); // [src, nil]
    return 1;
  }
  Tslua_cursor *c = lua_newuserdata(L, sizeof(Tslua_cursor));  // [src, udata]
  c->cursor = ts_tree_cursor_new(node);
  c->sheet = sheet; // TODO: GC ref for sheet!
  if (c->sheet) {
    c->state_id[0] = 0;
    c->level = 1;
    c->child_index[c->level] = 0;
    c->state_id[c->level] = cursor_next_state(c);
  }
  lua_getfield(L, LUA_ENVIRONINDEX, "cursor-meta");  // [src, udata, meta]
  lua_setmetatable(L, -2);  // [src, udata]
  lua_getfenv(L, 1);  // [src, udata, reftable]
  lua_setfenv(L, -2);  // [src, udata]
  return 1;
}


static int cursor_gc(lua_State *L)
{
  Tslua_cursor *cursor = cursor_check(L);
  if (!cursor) {
    return 0;
  }

  ts_tree_cursor_delete(&cursor->cursor);
  return 0;
}

static Tslua_cursor *cursor_check(lua_State *L)
{
  if (!lua_gettop(L)) {
    return NULL;
  }
  if (!lua_isuserdata(L, 1)) {
    return NULL;
  }
  // TODO: typecheck!
  Tslua_cursor *ud = lua_touserdata(L, 1);
  return ud;
}


static int cursor_tostring(lua_State *L)
{
  Tslua_cursor *c = cursor_check(L);
  if (!c) {
    return 0;
  }
  TSNode node = ts_tree_cursor_current_node(&c->cursor);
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

static int cursor_next_state(Tslua_cursor *c)
{
  int state_id = c->state_id[c->level-1];
  int child_index = c->child_index[c->level];
  PropertyState *s = &c->sheet->states[state_id];
  TSNode current = ts_tree_cursor_current_node(&c->cursor);
  int kind_id = (int)ts_node_symbol(current);

  int i = s->kind_first_trans[kind_id];
  if (i == -1) {
    return s->default_next_state_id;
  }

  for (; i < (int)kv_size(s->kind_trans); i++) {
    KindTransition *t = &kv_A(s->kind_trans, i);
    if (t->kind_id != kind_id) {
      break;
    }

    //if (t->regex_id) {
    //}

    if (t->child_index >= 0 && t->child_index != child_index) {
      continue;
    }
    return t->next_state_id;
  }

  return s->default_next_state_id;
}

static bool cursor_goto_first_child(Tslua_cursor *c)
{
  if (!ts_tree_cursor_goto_first_child(&c->cursor)) {
    return false;
  }
  if (c->sheet) {
    c->level++;
    c->child_index[c->level] = 0;
    c->state_id[c->level] = cursor_next_state(c);
  }
  return true;
}

static bool cursor_goto_next_sibling(Tslua_cursor *c)
{
  if (!ts_tree_cursor_goto_next_sibling(&c->cursor)) {
    return false;
  }
  if (c->sheet) {
    c->child_index[c->level]++;
    c->state_id[c->level] = cursor_next_state(c);
  }
  return true;
}

static bool cursor_goto_parent(Tslua_cursor *c)
{
  if (!ts_tree_cursor_goto_parent(&c->cursor)) {
    return false;
  }
  if (c->sheet) {
    c->level--;
  }
  return true;
}

static int cursor_forward(lua_State *L)
{
  Tslua_cursor *c = cursor_check(L);
  if (!c) {
    return 0;
  }
  TSTreeCursor *cursor = &c->cursor;

  bool status = false;

  int narg = lua_gettop(L);
  uint32_t byte_index = 0;
  if (narg >= 1) {
    byte_index = (uint32_t)lua_tointeger(L, 2);
  }

  if (c->sheet && c->level >= 31) {
    lua_pushstring(L,"DEPTH EXCEEDED");
    return lua_error(L);
  }

  // TODO: use this and use child index from cursor
  //status = ts_tree_cursor_goto_first_child_for_byte(cursor, byte_index) != -1;
  status = cursor_goto_first_child(c);

  if (status) {
    if (byte_index > 0) {
      while (true) {
        TSNode node = ts_tree_cursor_current_node(cursor);
        if (ts_node_end_byte(node) >= byte_index) {
          break;
        }
        // TODO: for a compound node like statement-list, where highlighting
        // of each element doesn't depend on previous siblings, this is inefficient
        // internal ts_tree_cursor_goto_first_child_for_byte uses binary search.
        // we could check what states doesn't have child_index rules.
        if(!cursor_goto_next_sibling(c)) {
          // if the parent node was in range, we expect some child node to be
          lua_pushstring(L, "UNEXPECTED STATE");
          return lua_error(L);
        }
      }

    }

    goto ret;
  }

  while (true) {
    status = cursor_goto_next_sibling(c);
    if (status) {
      break;
    }

    // Current node was last a child, look for sibling on higher
    // level
    status = cursor_goto_parent(c);
    if (!status) { // past end of root node
      break;
    } 
  }

ret:
  if (status) {
    push_node(L, ts_tree_cursor_current_node(cursor));
    if (c->sheet) {
      lua_pushnumber(L, c->sheet->states[c->state_id[c->level]].property_id);
      return 2;
    } else {
      return 1;
    }
  } else {
    return 0;
  }
}

static int cursor_debug(lua_State *L)
{
  Tslua_cursor *c = cursor_check(L);
  if (!c) {
    return 0;
  }

  lua_createtable(L, 0, 0);
  for (int i = 0; i <= c->level; i++) {
    lua_pushinteger(L, c->state_id[i]);
    lua_rawseti(L, -2, i);
  }
  return 1;
}

// Propertysheet functions
void tslua_push_propertysheet(lua_State *L, int n_states, int n_kinds)
{
  Tslua_propertysheet *sheet = lua_newuserdata(L, sizeof(Tslua_propertysheet));
  sheet->n_states = n_states;
  sheet->n_kinds = n_kinds;
  sheet->states = xcalloc(n_states, sizeof(*sheet->states));
  for (int i = 0; i < n_states; i++) {
    PropertyState *s = &sheet->states[i];
    s->kind_first_trans = xmalloc(n_kinds * sizeof(*s->kind_first_trans));
    memset(s->kind_first_trans, -1,
           sheet->n_kinds * sizeof(*s->kind_first_trans));
    kv_init(s->kind_trans);
  }

  lua_getfield(L, LUA_REGISTRYINDEX, REG_KEY);  // [udata, env]
  lua_getfield(L, -1, "propertysheet-meta");  // [udata, env, meta]
  lua_setmetatable(L, -3);  // [udata, env]
  lua_pop(L, 1);  // [udata]
}

static Tslua_propertysheet *propertysheet_check(lua_State *L)
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

static int propertysheet_gc(lua_State *L)
{
  Tslua_propertysheet *sheet = propertysheet_check(L);
  if (!sheet) {
    return 0;
  }

  // TODO
  return 0;
}

static int propertysheet_tostring(lua_State *L)
{
  Tslua_propertysheet *c = propertysheet_check(L);
  if (!c) {
    return 0;
  }

  lua_pushstring(L, "<propertysheet>");
  return 1;
}

static int propertysheet_add_state(lua_State *L)
{
  Tslua_propertysheet *sheet = propertysheet_check(L);
  if (!sheet) {
    return 0;
  }

  int state_id = lua_tointeger(L, 2);
  int default_next_id = lua_tointeger(L, 3);
  int property_id = lua_tointeger(L, 4);

  if (state_id >= sheet->n_states) {
    lua_pushstring(L, "out of bounds");
    return lua_error(L);
  }

  PropertyState *state = &sheet->states[state_id];

  state->default_next_state_id = default_next_id;
  state->property_id = property_id;

  return 0;
}

static int propertysheet_add_transition(lua_State *L)
{
  Tslua_propertysheet *sheet = propertysheet_check(L);
  if (!sheet) {
    return 0;
  }

  int state_id = lua_tointeger(L, 2);
  int kind_id = lua_tointeger(L, 3);
  int next_state_id = lua_tointeger(L, 4);
  int child_index = lua_isnil(L, 5) ? -1 : lua_tointeger(L, 5);

  if (state_id >= sheet->n_states || kind_id >= sheet->n_kinds) {
    lua_pushstring(L, "out of bounds!!");
    return lua_error(L);
  }

  PropertyState *state = &sheet->states[state_id];
  if (state->kind_first_trans[kind_id] == -1) {
    state->kind_first_trans[kind_id] = kv_size(state->kind_trans);
  } else {
    if (kv_Z(state->kind_trans, 0).kind_id != kind_id) {
      lua_pushstring(L, "disorder!!");
      return lua_error(L);
    }
  }

  kv_push(state->kind_trans, ((KindTransition){
    .kind_id = kind_id,
    .next_state_id = next_state_id,
    .child_index = child_index,
    .regex_index = -1,
  }));

  return 0;
}

