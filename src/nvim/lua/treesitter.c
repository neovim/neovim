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
#include "nvim/buffer.h"

#define TS_META_PARSER "treesitter_parser"
#define TS_META_TREE "treesitter_tree"
#define TS_META_NODE "treesitter_node"
#define TS_META_QUERY "treesitter_query"
#define TS_META_QUERYCURSOR "treesitter_querycursor"
#define TS_META_TREECURSOR "treesitter_treecursor"

typedef struct {
  TSQueryCursor *cursor;
  int predicated_match;
} TSLua_cursor;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua/treesitter.c.generated.h"
#endif

static struct luaL_Reg parser_meta[] = {
  { "__gc", parser_gc },
  { "__tostring", parser_tostring },
  { "parse", parser_parse },
  { "set_included_ranges", parser_set_ranges },
  { "included_ranges", parser_get_ranges },
  { NULL, NULL }
};

static struct luaL_Reg tree_meta[] = {
  { "__gc", tree_gc },
  { "__tostring", tree_tostring },
  { "root", tree_root },
  { "edit", tree_edit },
  { "copy", tree_copy },
  { NULL, NULL }
};

static struct luaL_Reg node_meta[] = {
  { "__tostring", node_tostring },
  { "__eq", node_eq },
  { "__len", node_child_count },
  { "id", node_id },
  { "range", node_range },
  { "start", node_start },
  { "end_", node_end },
  { "type", node_type },
  { "symbol", node_symbol },
  { "field", node_field },
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
  { "iter_children", node_iter_children },
  { "_rawquery", node_rawquery },
  { NULL, NULL }
};

static struct luaL_Reg query_meta[] = {
  { "__gc", query_gc },
  { "__tostring", query_tostring },
  { "inspect", query_inspect },
  { NULL, NULL }
};

// cursors are not exposed, but still needs garbage collection
static struct luaL_Reg querycursor_meta[] = {
  { "__gc", querycursor_gc },
  { NULL, NULL }
};

static struct luaL_Reg treecursor_meta[] = {
  { "__gc", treecursor_gc },
  { NULL, NULL }
};

static PMap(cstr_t) *langs;

static void build_meta(lua_State *L, const char *tname, const luaL_Reg *meta)
{
  if (luaL_newmetatable(L, tname)) {  // [meta]
    luaL_register(L, NULL, meta);

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
  build_meta(L, TS_META_PARSER, parser_meta);
  build_meta(L, TS_META_TREE, tree_meta);
  build_meta(L, TS_META_NODE, node_meta);
  build_meta(L, TS_META_QUERY, query_meta);
  build_meta(L, TS_META_QUERYCURSOR, querycursor_meta);
  build_meta(L, TS_META_TREECURSOR, treecursor_meta);
}

int tslua_has_language(lua_State *L)
{
  const char *lang_name = luaL_checkstring(L, 1);
  lua_pushboolean(L, pmap_has(cstr_t)(langs, lang_name));
  return 1;
}

int tslua_add_language(lua_State *L)
{
  const char *path = luaL_checkstring(L, 1);
  const char *lang_name = luaL_checkstring(L, 2);

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
    return luaL_error(L, "Failed to load parser %s: internal error", path);
  }

  uint32_t lang_version = ts_language_version(lang);
  if (lang_version < TREE_SITTER_MIN_COMPATIBLE_LANGUAGE_VERSION
      || lang_version > TREE_SITTER_LANGUAGE_VERSION) {
    return luaL_error(
        L,
        "ABI version mismatch for %s: supported between %d and %d, found %d",
        path,
        TREE_SITTER_MIN_COMPATIBLE_LANGUAGE_VERSION,
        TREE_SITTER_LANGUAGE_VERSION, lang_version);
  }

  pmap_put(cstr_t)(langs, xstrdup(lang_name), lang);

  lua_pushboolean(L, true);
  return 1;
}

int tslua_inspect_lang(lua_State *L)
{
  const char *lang_name = luaL_checkstring(L, 1);

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

int tslua_push_parser(lua_State *L)
{
  // Gather language name
  const char *lang_name = luaL_checkstring(L, 1);

  TSLanguage *lang = pmap_get(cstr_t)(langs, lang_name);
  if (!lang) {
    return luaL_error(L, "no such language: %s", lang_name);
  }

  TSParser **parser = lua_newuserdata(L, sizeof(TSParser *));
  *parser = ts_parser_new();

  if (!ts_parser_set_language(*parser, lang)) {
    ts_parser_delete(*parser);
    return luaL_error(L, "Failed to load language : %s", lang_name);
  }

  lua_getfield(L, LUA_REGISTRYINDEX, TS_META_PARSER);  // [udata, meta]
  lua_setmetatable(L, -2);  // [udata]
  return 1;
}

static TSParser ** parser_check(lua_State *L, uint16_t index)
{
  return luaL_checkudata(L, index, TS_META_PARSER);
}

static int parser_gc(lua_State *L)
{
  TSParser **p = parser_check(L, 1);
  if (!p) {
    return 0;
  }

  ts_parser_delete(*p);
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
  if (position.column > len) {
    *bytes_read = 0;
    return "";
  }
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

static void push_ranges(lua_State *L,
                        const TSRange *ranges,
                        const unsigned int length)
{
  lua_createtable(L, length, 0);
  for (size_t i = 0; i < length; i++) {
    lua_createtable(L, 4, 0);
    lua_pushinteger(L, ranges[i].start_point.row);
    lua_rawseti(L, -2, 1);
    lua_pushinteger(L, ranges[i].start_point.column);
    lua_rawseti(L, -2, 2);
    lua_pushinteger(L, ranges[i].end_point.row);
    lua_rawseti(L, -2, 3);
    lua_pushinteger(L, ranges[i].end_point.column);
    lua_rawseti(L, -2, 4);

    lua_rawseti(L, -2, i+1);
  }
}

static int parser_parse(lua_State *L)
{
  TSParser **p = parser_check(L, 1);
  if (!p || !(*p)) {
    return 0;
  }

  TSTree *old_tree = NULL;
  if (!lua_isnil(L, 2)) {
    TSTree **tmp = tree_check(L, 2);
    old_tree = tmp ? *tmp : NULL;
  }

  TSTree *new_tree = NULL;
  size_t len;
  const char *str;
  long bufnr;
  buf_T *buf;
  TSInput input;

  // This switch is necessary because of the behavior of lua_isstring, that
  // consider numbers as strings...
  switch (lua_type(L, 3)) {
    case LUA_TSTRING:
      str = lua_tolstring(L, 3, &len);
      new_tree = ts_parser_parse_string(*p, old_tree, str, len);
      break;

    case LUA_TNUMBER:
      bufnr = lua_tointeger(L, 3);
      buf = handle_get_buffer(bufnr);

      if (!buf) {
        return luaL_error(L, "invalid buffer handle: %d", bufnr);
      }

      input = (TSInput){ (void *)buf, input_cb, TSInputEncodingUTF8 };
      new_tree = ts_parser_parse(*p, old_tree, input);

      break;

    default:
      return luaL_error(L, "invalid argument to parser:parse()");
  }

  // Sometimes parsing fails (timeout, or wrong parser ABI)
  // In those case, just return an error.
  if (!new_tree) {
    return luaL_error(L, "An error occured when parsing.");
  }

  // The new tree will be pushed to the stack, without copy, owwership is now to
  // the lua GC.
  // Old tree is still owned by the lua GC.
  uint32_t n_ranges = 0;
  TSRange *changed = old_tree ?  ts_tree_get_changed_ranges(
      old_tree, new_tree, &n_ranges) : NULL;

  push_tree(L, new_tree, false);  // [tree]

  push_ranges(L, changed, n_ranges);  // [tree, ranges]

  xfree(changed);
  return 2;
}

static int tree_copy(lua_State *L)
{
  TSTree **tree = tree_check(L, 1);
  if (!(*tree)) {
    return 0;
  }

  push_tree(L, *tree, true);  // [tree]

  return 1;
}

static int tree_edit(lua_State *L)
{
  if (lua_gettop(L) < 10) {
    lua_pushstring(L, "not enough args to tree:edit()");
    return lua_error(L);
  }

  TSTree **tree = tree_check(L, 1);
  if (!(*tree)) {
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

  ts_tree_edit(*tree, &edit);

  return 0;
}

// Use the top of the stack (without popping it) to create a TSRange, it can be
// either a lua table or a TSNode
static void range_from_lua(lua_State *L, TSRange *range)
{
  TSNode node;

  if (lua_istable(L, -1)) {
    // should be a table of 6 elements
    if (lua_objlen(L, -1) != 6) {
      goto error;
    }

    uint32_t start_row, start_col, start_byte, end_row, end_col, end_byte;
    lua_rawgeti(L, -1, 1);  // [ range, start_row]
    start_row = luaL_checkinteger(L, -1);
    lua_pop(L, 1);

    lua_rawgeti(L, -1, 2);  // [ range, start_col]
    start_col = luaL_checkinteger(L, -1);
    lua_pop(L, 1);

    lua_rawgeti(L, -1, 3);  // [ range, start_byte]
    start_byte = luaL_checkinteger(L, -1);
    lua_pop(L, 1);

    lua_rawgeti(L, -1, 4);  // [ range, end_row]
    end_row = luaL_checkinteger(L, -1);
    lua_pop(L, 1);

    lua_rawgeti(L, -1, 5);  // [ range, end_col]
    end_col = luaL_checkinteger(L, -1);
    lua_pop(L, 1);

    lua_rawgeti(L, -1, 6);  // [ range, end_byte]
    end_byte = luaL_checkinteger(L, -1);
    lua_pop(L, 1);  // [ range ]

    *range = (TSRange) {
      .start_point = (TSPoint) {
        .row = start_row,
        .column = start_col
      },
      .end_point = (TSPoint) {
        .row = end_row,
        .column = end_col
      },
      .start_byte = start_byte,
      .end_byte = end_byte,
    };
  } else if (node_check(L, -1, &node)) {
    *range = (TSRange) {
      .start_point = ts_node_start_point(node),
      .end_point = ts_node_end_point(node),
      .start_byte = ts_node_start_byte(node),
      .end_byte = ts_node_end_byte(node)
    };
  } else {
    goto error;
  }
  return;
error:
  luaL_error(
      L,
      "Ranges can only be made from 6 element long tables or nodes.");
}

static int parser_set_ranges(lua_State *L)
{
  if (lua_gettop(L) < 2) {
    return luaL_error(
        L,
        "not enough args to parser:set_included_ranges()");
  }

  TSParser **p = parser_check(L, 1);
  if (!p) {
    return 0;
  }

  if (!lua_istable(L, 2)) {
    return luaL_error(
        L,
        "argument for parser:set_included_ranges() should be a table.");
  }

  size_t tbl_len = lua_objlen(L, 2);
  TSRange *ranges = xmalloc(sizeof(TSRange) * tbl_len);


  // [ parser, ranges ]
  for (size_t index = 0; index < tbl_len; index++) {
    lua_rawgeti(L, 2, index + 1);  // [ parser, ranges, range ]
    range_from_lua(L, ranges + index);
    lua_pop(L, 1);
  }

  // This memcpies ranges, thus we can free it afterwards
  ts_parser_set_included_ranges(*p, ranges, tbl_len);
  xfree(ranges);

  return 0;
}

static int parser_get_ranges(lua_State *L)
{
  TSParser **p = parser_check(L, 1);
  if (!p) {
    return 0;
  }

  unsigned int len;
  const TSRange *ranges = ts_parser_included_ranges(*p, &len);

  push_ranges(L, ranges, len);
  return 1;
}


// Tree methods

/// push tree interface on lua stack.
///
/// This makes a copy of the tree, so ownership of the argument is unaffected.
void push_tree(lua_State *L, TSTree *tree, bool do_copy)
{
  if (tree == NULL) {
    lua_pushnil(L);
    return;
  }
  TSTree **ud = lua_newuserdata(L, sizeof(TSTree *));  // [udata]

  if (do_copy) {
    *ud = ts_tree_copy(tree);
  } else {
    *ud = tree;
  }

  lua_getfield(L, LUA_REGISTRYINDEX, TS_META_TREE);  // [udata, meta]
  lua_setmetatable(L, -2);  // [udata]

  // table used for node wrappers to keep a reference to tree wrapper
  // NB: in lua 5.3 the uservalue for the node could just be the tree, but
  // in lua 5.1 the uservalue (fenv) must be a table.
  lua_createtable(L, 1, 0);  // [udata, reftable]
  lua_pushvalue(L, -2);  // [udata, reftable, udata]
  lua_rawseti(L, -2, 1);  // [udata, reftable]
  lua_setfenv(L, -2);  // [udata]
}

static TSTree **tree_check(lua_State *L, uint16_t index)
{
  TSTree **ud = luaL_checkudata(L, index, TS_META_TREE);
  return ud;
}

static int tree_gc(lua_State *L)
{
  TSTree **tree = tree_check(L, 1);
  if (!tree) {
    return 0;
  }

  ts_tree_delete(*tree);
  return 0;
}

static int tree_tostring(lua_State *L)
{
  lua_pushstring(L, "<tree>");
  return 1;
}

static int tree_root(lua_State *L)
{
  TSTree **tree = tree_check(L, 1);
  if (!tree) {
    return 0;
  }
  TSNode root = ts_tree_root_node(*tree);
  push_node(L, root, 1);
  return 1;
}

// Node methods

/// push node interface on lua stack
///
/// top of stack must either be the tree this node belongs to or another node
/// of the same tree! This value is not popped. Can only be called inside a
/// cfunction with the tslua environment.
static void push_node(lua_State *L, TSNode node, int uindex)
{
  assert(uindex > 0 || uindex < -LUA_MINSTACK);
  if (ts_node_is_null(node)) {
    lua_pushnil(L);  // [nil]
    return;
  }
  TSNode *ud = lua_newuserdata(L, sizeof(TSNode));  // [udata]
  *ud = node;
  lua_getfield(L, LUA_REGISTRYINDEX, TS_META_NODE);  // [udata, meta]
  lua_setmetatable(L, -2);  // [udata]
  lua_getfenv(L, uindex);  // [udata, reftable]
  lua_setfenv(L, -2);  // [udata]
}

static bool node_check(lua_State *L, int index, TSNode *res)
{
  TSNode *ud = luaL_checkudata(L, index, TS_META_NODE);
  if (ud) {
    *res = *ud;
    return true;
  }
  return false;
}


static int node_tostring(lua_State *L)
{
  TSNode node;
  if (!node_check(L, 1, &node)) {
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
  if (!node_check(L, 1, &node)) {
    return 0;
  }

  TSNode node2;
  if (!node_check(L, 2, &node2)) {
    return 0;
  }

  lua_pushboolean(L, ts_node_eq(node, node2));
  return 1;
}

static int node_id(lua_State *L)
{
  TSNode node;
  if (!node_check(L, 1, &node)) {
    return 0;
  }

  lua_pushlstring(L, (const char *)&node.id, sizeof node.id);
  return 1;
}

static int node_range(lua_State *L)
{
  TSNode node;
  if (!node_check(L, 1, &node)) {
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
  if (!node_check(L, 1, &node)) {
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
  if (!node_check(L, 1, &node)) {
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
  if (!node_check(L, 1, &node)) {
    return 0;
  }
  uint32_t count = ts_node_child_count(node);
  lua_pushnumber(L, count);
  return 1;
}

static int node_named_child_count(lua_State *L)
{
  TSNode node;
  if (!node_check(L, 1, &node)) {
    return 0;
  }
  uint32_t count = ts_node_named_child_count(node);
  lua_pushnumber(L, count);
  return 1;
}

static int node_type(lua_State *L)
{
  TSNode node;
  if (!node_check(L, 1, &node)) {
    return 0;
  }
  lua_pushstring(L, ts_node_type(node));
  return 1;
}

static int node_symbol(lua_State *L)
{
  TSNode node;
  if (!node_check(L, 1, &node)) {
    return 0;
  }
  TSSymbol symbol = ts_node_symbol(node);
  lua_pushnumber(L, symbol);
  return 1;
}

static int node_field(lua_State *L)
{
  TSNode node;
  if (!node_check(L, 1, &node)) {
    return 0;
  }

  size_t name_len;
  const char *field_name = luaL_checklstring(L, 2, &name_len);

  TSTreeCursor cursor = ts_tree_cursor_new(node);

  lua_newtable(L);  // [table]
  unsigned int curr_index = 0;

  if (ts_tree_cursor_goto_first_child(&cursor)) {
    do {
      const char *current_field = ts_tree_cursor_current_field_name(&cursor);

      if (current_field != NULL && !STRCMP(field_name, current_field)) {
        push_node(L, ts_tree_cursor_current_node(&cursor), 1);  // [table, node]
        lua_rawseti(L, -2, ++curr_index);
      }
    } while (ts_tree_cursor_goto_next_sibling(&cursor));
  }

  ts_tree_cursor_delete(&cursor);
  return 1;
}

static int node_named(lua_State *L)
{
  TSNode node;
  if (!node_check(L, 1, &node)) {
    return 0;
  }
  lua_pushboolean(L, ts_node_is_named(node));
  return 1;
}

static int node_sexpr(lua_State *L)
{
  TSNode node;
  if (!node_check(L, 1, &node)) {
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
  if (!node_check(L, 1, &node)) {
    return 0;
  }
  lua_pushboolean(L, ts_node_is_missing(node));
  return 1;
}

static int node_has_error(lua_State *L)
{
  TSNode node;
  if (!node_check(L, 1, &node)) {
    return 0;
  }
  lua_pushboolean(L, ts_node_has_error(node));
  return 1;
}

static int node_child(lua_State *L)
{
  TSNode node;
  if (!node_check(L, 1, &node)) {
    return 0;
  }
  long num = lua_tointeger(L, 2);
  TSNode child = ts_node_child(node, (uint32_t)num);

  push_node(L, child, 1);
  return 1;
}

static int node_named_child(lua_State *L)
{
  TSNode node;
  if (!node_check(L, 1, &node)) {
    return 0;
  }
  long num = lua_tointeger(L, 2);
  TSNode child = ts_node_named_child(node, (uint32_t)num);

  push_node(L, child, 1);
  return 1;
}

static int node_descendant_for_range(lua_State *L)
{
  TSNode node;
  if (!node_check(L, 1, &node)) {
    return 0;
  }
  TSPoint start = { (uint32_t)lua_tointeger(L, 2),
                   (uint32_t)lua_tointeger(L, 3) };
  TSPoint end = { (uint32_t)lua_tointeger(L, 4),
                 (uint32_t)lua_tointeger(L, 5) };
  TSNode child = ts_node_descendant_for_point_range(node, start, end);

  push_node(L, child, 1);
  return 1;
}

static int node_named_descendant_for_range(lua_State *L)
{
  TSNode node;
  if (!node_check(L, 1, &node)) {
    return 0;
  }
  TSPoint start = { (uint32_t)lua_tointeger(L, 2),
                   (uint32_t)lua_tointeger(L, 3) };
  TSPoint end = { (uint32_t)lua_tointeger(L, 4),
                 (uint32_t)lua_tointeger(L, 5) };
  TSNode child = ts_node_named_descendant_for_point_range(node, start, end);

  push_node(L, child, 1);
  return 1;
}

static int node_next_child(lua_State *L)
{
  TSTreeCursor *ud = luaL_checkudata(
      L, lua_upvalueindex(1), TS_META_TREECURSOR);
  if (!ud) {
    return 0;
  }

  TSNode source;
  if (!node_check(L, lua_upvalueindex(2), &source)) {
    return 0;
  }

  // First call should return first child
  if (ts_node_eq(source, ts_tree_cursor_current_node(ud))) {
    if (ts_tree_cursor_goto_first_child(ud)) {
      goto push;
    } else {
      goto end;
    }
  }

  if (ts_tree_cursor_goto_next_sibling(ud)) {
push:
      push_node(
          L,
          ts_tree_cursor_current_node(ud),
          lua_upvalueindex(2));  // [node]

      const char * field = ts_tree_cursor_current_field_name(ud);

      if (field != NULL) {
        lua_pushstring(L, ts_tree_cursor_current_field_name(ud));
      } else {
        lua_pushnil(L);
      }  // [node, field_name_or_nil]
      return 2;
  }

end:
  return 0;
}

static int node_iter_children(lua_State *L)
{
  TSNode source;
  if (!node_check(L, 1, &source)) {
    return 0;
  }

  TSTreeCursor *ud = lua_newuserdata(L, sizeof(TSTreeCursor));  // [udata]
  *ud = ts_tree_cursor_new(source);

  lua_getfield(L, LUA_REGISTRYINDEX, TS_META_TREECURSOR);  // [udata, mt]
  lua_setmetatable(L, -2);  // [udata]
  lua_pushvalue(L, 1);  // [udata, source_node]
  lua_pushcclosure(L, node_next_child, 2);

  return 1;
}

static int treecursor_gc(lua_State *L)
{
  TSTreeCursor *ud = luaL_checkudata(L, 1, TS_META_TREECURSOR);
  ts_tree_cursor_delete(ud);
  return 0;
}

static int node_parent(lua_State *L)
{
  TSNode node;
  if (!node_check(L, 1, &node)) {
    return 0;
  }
  TSNode parent = ts_node_parent(node);
  push_node(L, parent, 1);
  return 1;
}

/// assumes the match table being on top of the stack
static void set_match(lua_State *L, TSQueryMatch *match, int nodeidx)
{
  for (int i = 0; i < match->capture_count; i++) {
    push_node(L, match->captures[i].node, nodeidx);
    lua_rawseti(L, -2, match->captures[i].index+1);
  }
}

static int query_next_match(lua_State *L)
{
  TSLua_cursor *ud = lua_touserdata(L, lua_upvalueindex(1));
  TSQueryCursor *cursor = ud->cursor;

  TSQuery *query = query_check(L, lua_upvalueindex(3));
  TSQueryMatch match;
  if (ts_query_cursor_next_match(cursor, &match)) {
    lua_pushinteger(L, match.pattern_index+1);  // [index]
    lua_createtable(L, ts_query_capture_count(query), 2);  // [index, match]
    set_match(L, &match, lua_upvalueindex(2));
    return 2;
  }
  return 0;
}


static int query_next_capture(lua_State *L)
{
  TSLua_cursor *ud = lua_touserdata(L, lua_upvalueindex(1));
  TSQueryCursor *cursor = ud->cursor;

  TSQuery *query = query_check(L, lua_upvalueindex(3));

  if (ud->predicated_match > -1) {
    lua_getfield(L, lua_upvalueindex(4), "active");
    bool active = lua_toboolean(L, -1);
    lua_pop(L, 1);
    if (!active) {
      ts_query_cursor_remove_match(cursor, ud->predicated_match);
    }
    ud->predicated_match = -1;
  }

  TSQueryMatch match;
  uint32_t capture_index;
  if (ts_query_cursor_next_capture(cursor, &match, &capture_index)) {
    TSQueryCapture capture = match.captures[capture_index];

    lua_pushinteger(L, capture.index+1);  // [index]
    push_node(L, capture.node, lua_upvalueindex(2));  // [index, node]

    uint32_t n_pred;
    ts_query_predicates_for_pattern(query, match.pattern_index, &n_pred);
    if (n_pred > 0 && capture_index == 0) {
      lua_pushvalue(L, lua_upvalueindex(4));  // [index, node, match]
      set_match(L, &match, lua_upvalueindex(2));
      lua_pushinteger(L, match.pattern_index+1);
      lua_setfield(L, -2, "pattern");

      if (match.capture_count > 1) {
        ud->predicated_match = match.id;
        lua_pushboolean(L, false);
        lua_setfield(L, -2, "active");
      }
      return 3;
    }
    return 2;
  }
  return 0;
}

static int node_rawquery(lua_State *L)
{
  TSNode node;
  if (!node_check(L, 1, &node)) {
    return 0;
  }
  TSQuery *query = query_check(L, 2);
  // TODO(bfredl): these are expensive allegedly,
  // use a reuse list later on?
  TSQueryCursor *cursor = ts_query_cursor_new();
  ts_query_cursor_exec(cursor, query, node);

  bool captures = lua_toboolean(L, 3);

  if (lua_gettop(L) >= 4) {
    int start = luaL_checkinteger(L, 4);
    int end = lua_gettop(L) >= 5 ? luaL_checkinteger(L, 5) : MAXLNUM;
    ts_query_cursor_set_point_range(cursor,
                                    (TSPoint){ start, 0 }, (TSPoint){ end, 0 });
  }

  TSLua_cursor *ud = lua_newuserdata(L, sizeof(*ud));  // [udata]
  ud->cursor = cursor;
  ud->predicated_match = -1;

  lua_getfield(L, LUA_REGISTRYINDEX, TS_META_QUERYCURSOR);
  lua_setmetatable(L, -2);  // [udata]
  lua_pushvalue(L, 1);  // [udata, node]

  // include query separately, as to keep a ref to it for gc
  lua_pushvalue(L, 2);  // [udata, node, query]

  if (captures) {
    // placeholder for match state
    lua_createtable(L, ts_query_capture_count(query), 2);  // [u, n, q, match]
    lua_pushcclosure(L, query_next_capture, 4);  // [closure]
  } else {
    lua_pushcclosure(L, query_next_match, 3);  // [closure]
  }

  return 1;
}

static int querycursor_gc(lua_State *L)
{
  TSLua_cursor *ud = luaL_checkudata(L, 1, TS_META_QUERYCURSOR);
  ts_query_cursor_delete(ud->cursor);
  return 0;
}

// Query methods

int ts_lua_parse_query(lua_State *L)
{
  if (lua_gettop(L) < 2 || !lua_isstring(L, 1) || !lua_isstring(L, 2)) {
    return luaL_error(L, "string expected");
  }

  const char *lang_name = lua_tostring(L, 1);
  TSLanguage *lang = pmap_get(cstr_t)(langs, lang_name);
  if (!lang) {
    return luaL_error(L, "no such language: %s", lang_name);
  }

  size_t len;
  const char *src = lua_tolstring(L, 2, &len);

  uint32_t error_offset;
  TSQueryError error_type;
  TSQuery *query = ts_query_new(lang, src, len, &error_offset, &error_type);

  if (!query) {
    return luaL_error(L, "query: %s at position %d",
                      query_err_string(error_type), (int)error_offset);
  }

  TSQuery **ud = lua_newuserdata(L, sizeof(TSQuery *));  // [udata]
  *ud = query;
  lua_getfield(L, LUA_REGISTRYINDEX, TS_META_QUERY);  // [udata, meta]
  lua_setmetatable(L, -2);  // [udata]
  return 1;
}


static const char *query_err_string(TSQueryError err) {
  switch (err) {
    case TSQueryErrorSyntax: return "invalid syntax";
    case TSQueryErrorNodeType: return "invalid node type";
    case TSQueryErrorField: return "invalid field";
    case TSQueryErrorCapture: return "invalid capture";
    default: return "error";
  }
}

static TSQuery *query_check(lua_State *L, int index)
{
  TSQuery **ud = luaL_checkudata(L, index, TS_META_QUERY);
  return *ud;
}

static int query_gc(lua_State *L)
{
  TSQuery *query = query_check(L, 1);
  if (!query) {
    return 0;
  }

  ts_query_delete(query);
  return 0;
}

static int query_tostring(lua_State *L)
{
  lua_pushstring(L, "<query>");
  return 1;
}

static int query_inspect(lua_State *L)
{
  TSQuery *query = query_check(L, 1);
  if (!query) {
    return 0;
  }

  uint32_t n_pat = ts_query_pattern_count(query);
  lua_createtable(L, 0, 2);  // [retval]
  lua_createtable(L, n_pat, 1);  // [retval, patterns]
  for (size_t i = 0; i < n_pat; i++) {
    uint32_t len;
    const TSQueryPredicateStep *step = ts_query_predicates_for_pattern(query,
                                                                       i, &len);
    if (len == 0) {
      continue;
    }
    lua_createtable(L, len/4, 1);  // [retval, patterns, pat]
    lua_createtable(L, 3, 0);  // [retval, patterns, pat, pred]
    int nextpred = 1;
    int nextitem = 1;
    for (size_t k = 0; k < len; k++) {
      if (step[k].type == TSQueryPredicateStepTypeDone) {
        lua_rawseti(L, -2, nextpred++);  // [retval, patterns, pat]
        lua_createtable(L, 3, 0);  // [retval, patterns, pat, pred]
        nextitem = 1;
        continue;
      }

      if (step[k].type == TSQueryPredicateStepTypeString) {
        uint32_t strlen;
        const char *str = ts_query_string_value_for_id(query, step[k].value_id,
                                                       &strlen);
        lua_pushlstring(L, str, strlen);  // [retval, patterns, pat, pred, item]
      } else if (step[k].type == TSQueryPredicateStepTypeCapture) {
        lua_pushnumber(L, step[k].value_id+1);  // [..., pat, pred, item]
      } else {
        abort();
      }
      lua_rawseti(L, -2, nextitem++);  // [retval, patterns, pat, pred]
    }
    // last predicate should have ended with TypeDone
    lua_pop(L, 1);  // [retval, patters, pat]
    lua_rawseti(L, -2, i+1);  // [retval, patterns]
  }
  lua_setfield(L, -2, "patterns");  // [retval]

  uint32_t n_captures = ts_query_capture_count(query);
  lua_createtable(L, n_captures, 0);  // [retval, captures]
  for (size_t i = 0; i < n_captures; i++) {
    uint32_t strlen;
    const char *str = ts_query_capture_name_for_id(query, i, &strlen);
    lua_pushlstring(L, str, strlen);  // [retval, captures, capture]
    lua_rawseti(L, -2, i+1);
  }
  lua_setfield(L, -2, "captures");  // [retval]

  return 1;
}
