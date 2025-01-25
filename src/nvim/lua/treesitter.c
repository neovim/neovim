// lua bindings for treesitter.
// NB: this file mostly contains a generic lua interface for treesitter
// trees and nodes, and could be broken out as a reusable lua package

#include <assert.h>
#include <ctype.h>
#include <lauxlib.h>
#include <limits.h>
#include <lua.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <tree_sitter/api.h>
#include <uv.h>

#ifdef HAVE_WASMTIME
# include <wasm.h>

# include "nvim/os/fs.h"
#endif

#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/globals.h"
#include "nvim/lua/treesitter.h"
#include "nvim/macros_defs.h"
#include "nvim/map_defs.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/pos_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"

#define TS_META_PARSER "treesitter_parser"
#define TS_META_TREE "treesitter_tree"
#define TS_META_NODE "treesitter_node"
#define TS_META_QUERY "treesitter_query"
#define TS_META_QUERYCURSOR "treesitter_querycursor"
#define TS_META_QUERYMATCH "treesitter_querymatch"

typedef struct {
  LuaRef cb;
  lua_State *lstate;
  bool lex;
  bool parse;
} TSLuaLoggerOpts;

typedef struct {
  TSTree *tree;
} TSLuaTree;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua/treesitter.c.generated.h"
#endif

static PMap(cstr_t) langs = MAP_INIT;

#ifdef HAVE_WASMTIME
static wasm_engine_t *wasmengine;
static TSWasmStore *ts_wasmstore;
#endif

// TSLanguage

int tslua_has_language(lua_State *L)
{
  const char *lang_name = luaL_checkstring(L, 1);
  lua_pushboolean(L, map_has(cstr_t, &langs, lang_name));
  return 1;
}

#ifdef HAVE_WASMTIME
static char *read_file(const char *path, size_t *len)
  FUNC_ATTR_MALLOC
{
  FILE *file = os_fopen(path, "r");
  if (file == NULL) {
    return NULL;
  }
  fseek(file, 0L, SEEK_END);
  *len = (size_t)ftell(file);
  fseek(file, 0L, SEEK_SET);
  char *data = xmalloc(*len);
  if (fread(data, *len, 1, file) != 1) {
    xfree(data);
    fclose(file);
    return NULL;
  }
  fclose(file);
  return data;
}

static const char *wasmerr_to_str(TSWasmErrorKind werr)
{
  switch (werr) {
  case TSWasmErrorKindParse:
    return "PARSE";
  case TSWasmErrorKindCompile:
    return "COMPILE";
  case TSWasmErrorKindInstantiate:
    return "INSTANTIATE";
  case TSWasmErrorKindAllocate:
    return "ALLOCATE";
  default:
    return "UNKNOWN";
  }
}
#endif

int tslua_add_language_from_wasm(lua_State *L)
{
  return add_language(L, true);
}

// Creates the language into the internal language map.
//
// Returns true if the language is correctly loaded in the language map
int tslua_add_language_from_object(lua_State *L)
{
  return add_language(L, false);
}

static const TSLanguage *load_language_from_object(lua_State *L, const char *path,
                                                   const char *lang_name, const char *symbol)
{
  uv_lib_t lib;
  if (uv_dlopen(path, &lib)) {
    xstrlcpy(IObuff, uv_dlerror(&lib), sizeof(IObuff));
    uv_dlclose(&lib);
    luaL_error(L, "Failed to load parser for language '%s': uv_dlopen: %s", lang_name, IObuff);
  }

  char symbol_buf[128];
  snprintf(symbol_buf, sizeof(symbol_buf), "tree_sitter_%s", symbol);

  TSLanguage *(*lang_parser)(void);
  if (uv_dlsym(&lib, symbol_buf, (void **)&lang_parser)) {
    xstrlcpy(IObuff, uv_dlerror(&lib), sizeof(IObuff));
    uv_dlclose(&lib);
    luaL_error(L, "Failed to load parser: uv_dlsym: %s", IObuff);
  }

  TSLanguage *lang = lang_parser();

  if (lang == NULL) {
    uv_dlclose(&lib);
    luaL_error(L, "Failed to load parser %s: internal error", path);
  }

  return lang;
}

static const TSLanguage *load_language_from_wasm(lua_State *L, const char *path,
                                                 const char *lang_name)
{
#ifndef HAVE_WASMTIME
  luaL_error(L, "Not supported");
  return NULL;
#else
  if (wasmengine == NULL) {
    wasmengine = wasm_engine_new();
  }
  assert(wasmengine != NULL);

  TSWasmError werr = { 0 };
  if (ts_wasmstore == NULL) {
    ts_wasmstore = ts_wasm_store_new(wasmengine, &werr);
  }

  if (werr.kind > 0) {
    luaL_error(L, "Error creating wasm store: (%s) %s", wasmerr_to_str(werr.kind), werr.message);
  }

  size_t file_size = 0;
  char *data = read_file(path, &file_size);

  if (data == NULL) {
    luaL_error(L, "Unable to read file", path);
  }

  const TSLanguage *lang = ts_wasm_store_load_language(ts_wasmstore, lang_name, data,
                                                       (uint32_t)file_size, &werr);

  xfree(data);

  if (werr.kind > 0) {
    luaL_error(L, "Failed to load WASM parser %s: (%s) %s", path, wasmerr_to_str(werr.kind),
               werr.message);
  }

  if (lang == NULL) {
    luaL_error(L, "Failed to load parser %s: internal error", path);
  }

  return lang;
#endif
}

static int add_language(lua_State *L, bool is_wasm)
{
  const char *path = luaL_checkstring(L, 1);
  const char *lang_name = luaL_checkstring(L, 2);
  const char *symbol_name = lang_name;

  if (!is_wasm && lua_gettop(L) >= 3 && !lua_isnil(L, 3)) {
    symbol_name = luaL_checkstring(L, 3);
  }

  if (map_has(cstr_t, &langs, lang_name)) {
    lua_pushboolean(L, true);
    return 1;
  }

  const TSLanguage *lang = is_wasm
                           ? load_language_from_wasm(L, path, lang_name)
                           : load_language_from_object(L, path, lang_name, symbol_name);

  uint32_t lang_version = ts_language_abi_version(lang);
  if (lang_version < TREE_SITTER_MIN_COMPATIBLE_LANGUAGE_VERSION
      || lang_version > TREE_SITTER_LANGUAGE_VERSION) {
    return luaL_error(L,
                      "ABI version mismatch for %s: supported between %d and %d, found %d",
                      path,
                      TREE_SITTER_MIN_COMPATIBLE_LANGUAGE_VERSION,
                      TREE_SITTER_LANGUAGE_VERSION, lang_version);
  }

  pmap_put(cstr_t)(&langs, xstrdup(lang_name), (TSLanguage *)lang);

  lua_pushboolean(L, true);
  return 1;
}

int tslua_remove_lang(lua_State *L)
{
  const char *lang_name = luaL_checkstring(L, 1);
  bool present = map_has(cstr_t, &langs, lang_name);
  if (present) {
    cstr_t key;
    pmap_del(cstr_t)(&langs, lang_name, &key);
    xfree((void *)key);
  }
  lua_pushboolean(L, present);
  return 1;
}

static TSLanguage *lang_check(lua_State *L, int index)
{
  const char *lang_name = luaL_checkstring(L, index);
  TSLanguage *lang = pmap_get(cstr_t)(&langs, lang_name);
  if (!lang) {
    luaL_error(L, "no such language: %s", lang_name);
  }
  return lang;
}

int tslua_inspect_lang(lua_State *L)
{
  TSLanguage *lang = lang_check(L, 1);

  lua_createtable(L, 0, 2);  // [retval]

  uint32_t nsymbols = ts_language_symbol_count(lang);
  assert(nsymbols < INT_MAX);

  lua_createtable(L, (int)(nsymbols - 1), 1);  // [retval, symbols]
  for (uint32_t i = 0; i < nsymbols; i++) {
    TSSymbolType t = ts_language_symbol_type(lang, (TSSymbol)i);
    if (t == TSSymbolTypeAuxiliary) {
      // not used by the API
      continue;
    }
    const char *name = ts_language_symbol_name(lang, (TSSymbol)i);
    bool named = t != TSSymbolTypeAnonymous;
    lua_pushboolean(L, named);  // [retval, symbols, is_named]
    if (!named) {
      char buf[256];
      snprintf(buf, sizeof(buf), "\"%s\"", name);
      lua_setfield(L, -2, buf);  // [retval, symbols]
    } else {
      lua_setfield(L, -2, name);  // [retval, symbols]
    }
  }

  lua_setfield(L, -2, "symbols");  // [retval]

  uint32_t nfields = ts_language_field_count(lang);
  lua_createtable(L, (int)nfields, 1);  // [retval, fields]
  // Field IDs go from 1 to nfields inclusive (extra index 0 maps to NULL)
  for (uint32_t i = 1; i <= nfields; i++) {
    lua_pushstring(L, ts_language_field_name_for_id(lang, (TSFieldId)i));
    lua_rawseti(L, -2, (int)i);  // [retval, fields]
  }

  lua_setfield(L, -2, "fields");  // [retval]

  lua_pushboolean(L, ts_language_is_wasm(lang));
  lua_setfield(L, -2, "_wasm");

  lua_pushinteger(L, ts_language_abi_version(lang));  // [retval, version]
  lua_setfield(L, -2, "_abi_version");

  return 1;
}

// TSParser

static struct luaL_Reg parser_meta[] = {
  { "__gc", parser_gc },
  { "__tostring", parser_tostring },
  { "parse", parser_parse },
  { "reset", parser_reset },
  { "set_included_ranges", parser_set_ranges },
  { "included_ranges", parser_get_ranges },
  { "set_timeout", parser_set_timeout },
  { "timeout", parser_get_timeout },
  { "_set_logger", parser_set_logger },
  { "_logger", parser_get_logger },
  { NULL, NULL }
};

int tslua_push_parser(lua_State *L)
{
  TSLanguage *lang = lang_check(L, 1);

  TSParser **parser = lua_newuserdata(L, sizeof(TSParser *));
  *parser = ts_parser_new();

#ifdef HAVE_WASMTIME
  if (ts_language_is_wasm(lang)) {
    assert(wasmengine != NULL);
    ts_parser_set_wasm_store(*parser, ts_wasmstore);
  }
#endif

  if (!ts_parser_set_language(*parser, lang)) {
    ts_parser_delete(*parser);
    const char *lang_name = luaL_checkstring(L, 1);
    return luaL_error(L, "Failed to load language : %s", lang_name);
  }

  lua_getfield(L, LUA_REGISTRYINDEX, TS_META_PARSER);  // [udata, meta]
  lua_setmetatable(L, -2);  // [udata]
  return 1;
}

static TSParser *parser_check(lua_State *L, uint16_t index)
{
  TSParser **ud = luaL_checkudata(L, index, TS_META_PARSER);
  luaL_argcheck(L, *ud, index, "TSParser expected");
  return *ud;
}

static void logger_gc(TSLogger logger)
{
  if (!logger.log) {
    return;
  }

  TSLuaLoggerOpts *opts = (TSLuaLoggerOpts *)logger.payload;
  luaL_unref(opts->lstate, LUA_REGISTRYINDEX, opts->cb);
  xfree(opts);
}

static int parser_gc(lua_State *L)
{
  TSParser *p = parser_check(L, 1);
  logger_gc(ts_parser_logger(p));
  ts_parser_delete(p);
  return 0;
}

static int parser_tostring(lua_State *L)
{
  lua_pushstring(L, "<parser>");
  return 1;
}

static const char *input_cb(void *payload, uint32_t byte_index, TSPoint position,
                            uint32_t *bytes_read)
{
  buf_T *bp = payload;
#define BUFSIZE 256
  static char buf[BUFSIZE];

  if ((linenr_T)position.row >= bp->b_ml.ml_line_count) {
    *bytes_read = 0;
    return "";
  }
  char *line = ml_get_buf(bp, (linenr_T)position.row + 1);
  size_t len = (size_t)ml_get_buf_len(bp, (linenr_T)position.row + 1);
  if (position.column > len) {
    *bytes_read = 0;
    return "";
  }
  size_t tocopy = MIN(len - position.column, BUFSIZE);

  memcpy(buf, line + position.column, tocopy);
  // Translate embedded \n to NUL
  memchrsub(buf, '\n', NUL, tocopy);
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

static void push_ranges(lua_State *L, const TSRange *ranges, const size_t length,
                        bool include_bytes)
{
  lua_createtable(L, (int)length, 0);
  for (size_t i = 0; i < length; i++) {
    lua_createtable(L, include_bytes ? 6 : 4, 0);
    int j = 1;
    lua_pushinteger(L, ranges[i].start_point.row);
    lua_rawseti(L, -2, j++);
    lua_pushinteger(L, ranges[i].start_point.column);
    lua_rawseti(L, -2, j++);
    if (include_bytes) {
      lua_pushinteger(L, ranges[i].start_byte);
      lua_rawseti(L, -2, j++);
    }
    lua_pushinteger(L, ranges[i].end_point.row);
    lua_rawseti(L, -2, j++);
    lua_pushinteger(L, ranges[i].end_point.column);
    lua_rawseti(L, -2, j++);
    if (include_bytes) {
      lua_pushinteger(L, ranges[i].end_byte);
      lua_rawseti(L, -2, j++);
    }

    lua_rawseti(L, -2, (int)(i + 1));
  }
}

static int parser_parse(lua_State *L)
{
  TSParser *p = parser_check(L, 1);
  TSTree *old_tree = NULL;
  if (!lua_isnil(L, 2)) {
    TSLuaTree *ud = luaL_checkudata(L, 2, TS_META_TREE);
    old_tree = ud ? ud->tree : NULL;
  }

  TSTree *new_tree = NULL;
  size_t len;
  const char *str;
  handle_T bufnr;
  buf_T *buf;
  TSInput input;

  // This switch is necessary because of the behavior of lua_isstring, that
  // consider numbers as strings...
  switch (lua_type(L, 3)) {
  case LUA_TSTRING:
    str = lua_tolstring(L, 3, &len);
    new_tree = ts_parser_parse_string(p, old_tree, str, (uint32_t)len);
    break;

  case LUA_TNUMBER:
    bufnr = (handle_T)lua_tointeger(L, 3);
    buf = handle_get_buffer(bufnr);

    if (!buf) {
#define BUFSIZE 256
      char ebuf[BUFSIZE] = { 0 };
      vim_snprintf(ebuf, BUFSIZE, "invalid buffer handle: %d", bufnr);
      return luaL_argerror(L, 3, ebuf);
#undef BUFSIZE
    }

    input = (TSInput){ (void *)buf, input_cb, TSInputEncodingUTF8, NULL };
    new_tree = ts_parser_parse(p, old_tree, input);

    break;

  default:
    return luaL_argerror(L, 3, "expected either string or buffer handle");
  }

  bool include_bytes = (lua_gettop(L) >= 4) && lua_toboolean(L, 4);

  // Sometimes parsing fails (timeout, or wrong parser ABI)
  // In those case, just return an error.
  if (!new_tree) {
    if (ts_parser_timeout_micros(p) == 0) {
      // No timeout set, must have had an error
      return luaL_error(L, "An error occurred when parsing.");
    }
    return 0;
  }

  // The new tree will be pushed to the stack, without copy, ownership is now to the lua GC.
  // Old tree is owned by lua GC since before
  uint32_t n_ranges = 0;
  TSRange *changed = old_tree ? ts_tree_get_changed_ranges(old_tree, new_tree, &n_ranges) : NULL;

  push_tree(L, new_tree);  // [tree]

  push_ranges(L, changed, n_ranges, include_bytes);  // [tree, ranges]

  xfree(changed);
  return 2;
}

static int parser_reset(lua_State *L)
{
  TSParser *p = parser_check(L, 1);
  ts_parser_reset(p);
  return 0;
}

static void range_err(lua_State *L)
{
  luaL_error(L, "Ranges can only be made from 6 element long tables or nodes.");
}

// Use the top of the stack (without popping it) to create a TSRange, it can be
// either a lua table or a TSNode
static void range_from_lua(lua_State *L, TSRange *range)
{
  TSNode node;

  if (lua_istable(L, -1)) {
    // should be a table of 6 elements
    if (lua_objlen(L, -1) != 6) {
      range_err(L);
    }

    lua_rawgeti(L, -1, 1);  // [ range, start_row]
    uint32_t start_row = (uint32_t)luaL_checkinteger(L, -1);
    lua_pop(L, 1);

    lua_rawgeti(L, -1, 2);  // [ range, start_col]
    uint32_t start_col = (uint32_t)luaL_checkinteger(L, -1);
    lua_pop(L, 1);

    lua_rawgeti(L, -1, 3);  // [ range, start_byte]
    uint32_t start_byte = (uint32_t)luaL_checkinteger(L, -1);
    lua_pop(L, 1);

    lua_rawgeti(L, -1, 4);  // [ range, end_row]
    uint32_t end_row = (uint32_t)luaL_checkinteger(L, -1);
    lua_pop(L, 1);

    lua_rawgeti(L, -1, 5);  // [ range, end_col]
    uint32_t end_col = (uint32_t)luaL_checkinteger(L, -1);
    lua_pop(L, 1);

    lua_rawgeti(L, -1, 6);  // [ range, end_byte]
    uint32_t end_byte = (uint32_t)luaL_checkinteger(L, -1);
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
  } else if (node_check_opt(L, -1, &node)) {
    *range = (TSRange) {
      .start_point = ts_node_start_point(node),
      .end_point = ts_node_end_point(node),
      .start_byte = ts_node_start_byte(node),
      .end_byte = ts_node_end_byte(node)
    };
  } else {
    range_err(L);
  }
}

static int parser_set_ranges(lua_State *L)
{
  if (lua_gettop(L) < 2) {
    return luaL_error(L, "not enough args to parser:set_included_ranges()");
  }

  TSParser *p = parser_check(L, 1);

  luaL_argcheck(L, lua_istable(L, 2), 2, "table expected.");

  size_t tbl_len = lua_objlen(L, 2);
  TSRange *ranges = xmalloc(sizeof(TSRange) * tbl_len);

  // [ parser, ranges ]
  for (size_t index = 0; index < tbl_len; index++) {
    lua_rawgeti(L, 2, (int)index + 1);  // [ parser, ranges, range ]
    range_from_lua(L, ranges + index);
    lua_pop(L, 1);
  }

  // This memcpies ranges, thus we can free it afterwards
  ts_parser_set_included_ranges(p, ranges, (uint32_t)tbl_len);
  xfree(ranges);

  return 0;
}

static int parser_get_ranges(lua_State *L)
{
  TSParser *p = parser_check(L, 1);

  bool include_bytes = (lua_gettop(L) >= 2) && lua_toboolean(L, 2);

  uint32_t len;
  const TSRange *ranges = ts_parser_included_ranges(p, &len);

  push_ranges(L, ranges, len, include_bytes);
  return 1;
}

static int parser_set_timeout(lua_State *L)
{
  TSParser *p = parser_check(L, 1);

  if (lua_gettop(L) < 2) {
    luaL_error(L, "integer expected");
  }

  uint32_t timeout = (uint32_t)luaL_checkinteger(L, 2);
  ts_parser_set_timeout_micros(p, timeout);
  return 0;
}

static int parser_get_timeout(lua_State *L)
{
  TSParser *p = parser_check(L, 1);
  lua_pushinteger(L, (lua_Integer)ts_parser_timeout_micros(p));
  return 1;
}

static void logger_cb(void *payload, TSLogType logtype, const char *s)
{
  TSLuaLoggerOpts *opts = (TSLuaLoggerOpts *)payload;
  if ((!opts->lex && logtype == TSLogTypeLex)
      || (!opts->parse && logtype == TSLogTypeParse)) {
    return;
  }

  lua_State *lstate = opts->lstate;

  lua_rawgeti(lstate, LUA_REGISTRYINDEX, opts->cb);
  lua_pushstring(lstate, logtype == TSLogTypeParse ? "parse" : "lex");
  lua_pushstring(lstate, s);
  if (lua_pcall(lstate, 2, 0, 0)) {
    luaL_error(lstate, "Error executing treesitter logger callback");
  }
}

static int parser_set_logger(lua_State *L)
{
  TSParser *p = parser_check(L, 1);

  luaL_argcheck(L, lua_isboolean(L, 2), 2, "boolean expected");
  luaL_argcheck(L, lua_isboolean(L, 3), 3, "boolean expected");
  luaL_argcheck(L, lua_isfunction(L, 4), 4, "function expected");

  TSLuaLoggerOpts *opts = xmalloc(sizeof(TSLuaLoggerOpts));
  lua_pushvalue(L, 4);
  LuaRef ref = luaL_ref(L, LUA_REGISTRYINDEX);

  *opts = (TSLuaLoggerOpts){
    .lex = lua_toboolean(L, 2),
    .parse = lua_toboolean(L, 3),
    .cb = ref,
    .lstate = L
  };

  TSLogger logger = {
    .payload = (void *)opts,
    .log = logger_cb
  };

  ts_parser_set_logger(p, logger);
  return 0;
}

static int parser_get_logger(lua_State *L)
{
  TSParser *p = parser_check(L, 1);
  TSLogger logger = ts_parser_logger(p);
  if (logger.log) {
    TSLuaLoggerOpts *opts = (TSLuaLoggerOpts *)logger.payload;
    lua_rawgeti(L, LUA_REGISTRYINDEX, opts->cb);
  } else {
    lua_pushnil(L);
  }

  return 1;
}

// TSTree

static struct luaL_Reg tree_meta[] = {
  { "__gc", tree_gc },
  { "__tostring", tree_tostring },
  { "root", tree_root },
  { "edit", tree_edit },
  { "included_ranges", tree_get_ranges },
  { "copy", tree_copy },
  { NULL, NULL }
};

/// Push tree interface on to the lua stack.
///
/// The tree is not copied. Ownership of the tree is transferred from C to
/// Lua. If needed use ts_tree_copy() in the caller
static void push_tree(lua_State *L, TSTree *tree)
{
  if (tree == NULL) {
    lua_pushnil(L);
    return;
  }

  TSLuaTree *ud = lua_newuserdata(L, sizeof(TSLuaTree));  // [udata]

  ud->tree = tree;

  lua_getfield(L, LUA_REGISTRYINDEX, TS_META_TREE);  // [udata, meta]
  lua_setmetatable(L, -2);  // [udata]

  // To prevent the tree from being garbage collected, create a reference to it
  // in the fenv which will be passed to userdata nodes of the tree.
  // Note: environments (fenvs) associated with userdata have no meaning in Lua
  // and are only used to associate a table.
  lua_createtable(L, 1, 0);  // [udata, reftable]
  lua_pushvalue(L, -2);  // [udata, reftable, udata]
  lua_rawseti(L, -2, 1);  // [udata, reftable]
  lua_setfenv(L, -2);  // [udata]
}

static int tree_copy(lua_State *L)
{
  TSLuaTree *ud = luaL_checkudata(L, 1, TS_META_TREE);
  TSTree *copy = ts_tree_copy(ud->tree);
  push_tree(L, copy);  // [tree]

  return 1;
}

static int tree_edit(lua_State *L)
{
  if (lua_gettop(L) < 10) {
    lua_pushstring(L, "not enough args to tree:edit()");
    return lua_error(L);
  }

  TSLuaTree *ud = luaL_checkudata(L, 1, TS_META_TREE);

  uint32_t start_byte = (uint32_t)luaL_checkint(L, 2);
  uint32_t old_end_byte = (uint32_t)luaL_checkint(L, 3);
  uint32_t new_end_byte = (uint32_t)luaL_checkint(L, 4);
  TSPoint start_point = { (uint32_t)luaL_checkint(L, 5), (uint32_t)luaL_checkint(L, 6) };
  TSPoint old_end_point = { (uint32_t)luaL_checkint(L, 7), (uint32_t)luaL_checkint(L, 8) };
  TSPoint new_end_point = { (uint32_t)luaL_checkint(L, 9), (uint32_t)luaL_checkint(L, 10) };

  TSInputEdit edit = { start_byte, old_end_byte, new_end_byte,
                       start_point, old_end_point, new_end_point };

  ts_tree_edit(ud->tree, &edit);

  return 0;
}

static int tree_get_ranges(lua_State *L)
{
  TSLuaTree *ud = luaL_checkudata(L, 1, TS_META_TREE);

  bool include_bytes = (lua_gettop(L) >= 2) && lua_toboolean(L, 2);

  uint32_t len;
  TSRange *ranges = ts_tree_included_ranges(ud->tree, &len);

  push_ranges(L, ranges, len, include_bytes);

  xfree(ranges);
  return 1;
}

static int tree_gc(lua_State *L)
{
  TSLuaTree *ud = luaL_checkudata(L, 1, TS_META_TREE);
  ts_tree_delete(ud->tree);
  return 0;
}

static int tree_tostring(lua_State *L)
{
  lua_pushstring(L, "<tree>");
  return 1;
}

static int tree_root(lua_State *L)
{
  TSLuaTree *ud = luaL_checkudata(L, 1, TS_META_TREE);
  TSNode root = ts_tree_root_node(ud->tree);
  push_node(L, root, 1);
  return 1;
}

// TSNode
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
  { "extra", node_extra },
  { "has_changes", node_has_changes },
  { "has_error", node_has_error },
  { "sexpr", node_sexpr },
  { "child_count", node_child_count },
  { "named_child_count", node_named_child_count },
  { "child", node_child },
  { "named_child", node_named_child },
  { "descendant_for_range", node_descendant_for_range },
  { "named_descendant_for_range", node_named_descendant_for_range },
  { "parent", node_parent },
  { "__has_ancestor", __has_ancestor },
  { "child_with_descendant", node_child_with_descendant },
  { "iter_children", node_iter_children },
  { "next_sibling", node_next_sibling },
  { "prev_sibling", node_prev_sibling },
  { "next_named_sibling", node_next_named_sibling },
  { "prev_named_sibling", node_prev_named_sibling },
  { "named_children", node_named_children },
  { "root", node_root },
  { "tree", node_tree },
  { "byte_length", node_byte_length },
  { "equal", node_equal },

  { NULL, NULL }
};

/// Push node interface on to the Lua stack
///
/// Top of stack must either be the tree this node belongs to or another node
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

  // Copy the fenv which contains the nodes tree.
  lua_getfenv(L, uindex);  // [udata, reftable]
  lua_setfenv(L, -2);  // [udata]
}

static bool node_check_opt(lua_State *L, int index, TSNode *res)
{
  TSNode *ud = luaL_checkudata(L, index, TS_META_NODE);
  if (ud) {
    *res = *ud;
    return true;
  }
  return false;
}

static TSNode node_check(lua_State *L, int index)
{
  TSNode *ud = luaL_checkudata(L, index, TS_META_NODE);
  return *ud;
}

static int node_tostring(lua_State *L)
{
  TSNode node = node_check(L, 1);
  lua_pushstring(L, "<node ");
  lua_pushstring(L, ts_node_type(node));
  lua_pushstring(L, ">");
  lua_concat(L, 3);
  return 1;
}

static int node_eq(lua_State *L)
{
  TSNode node = node_check(L, 1);
  TSNode node2 = node_check(L, 2);
  lua_pushboolean(L, ts_node_eq(node, node2));
  return 1;
}

static int node_id(lua_State *L)
{
  TSNode node = node_check(L, 1);
  lua_pushlstring(L, (const char *)&node.id, sizeof node.id);
  return 1;
}

static int node_range(lua_State *L)
{
  TSNode node = node_check(L, 1);

  bool include_bytes = (lua_gettop(L) >= 2) && lua_toboolean(L, 2);

  TSPoint start = ts_node_start_point(node);
  TSPoint end = ts_node_end_point(node);

  if (include_bytes) {
    lua_pushinteger(L, start.row);
    lua_pushinteger(L, start.column);
    lua_pushinteger(L, ts_node_start_byte(node));
    lua_pushinteger(L, end.row);
    lua_pushinteger(L, end.column);
    lua_pushinteger(L, ts_node_end_byte(node));
    return 6;
  }

  lua_pushinteger(L, start.row);
  lua_pushinteger(L, start.column);
  lua_pushinteger(L, end.row);
  lua_pushinteger(L, end.column);
  return 4;
}

static int node_start(lua_State *L)
{
  TSNode node = node_check(L, 1);
  TSPoint start = ts_node_start_point(node);
  uint32_t start_byte = ts_node_start_byte(node);
  lua_pushinteger(L, start.row);
  lua_pushinteger(L, start.column);
  lua_pushinteger(L, start_byte);
  return 3;
}

static int node_end(lua_State *L)
{
  TSNode node = node_check(L, 1);
  TSPoint end = ts_node_end_point(node);
  uint32_t end_byte = ts_node_end_byte(node);
  lua_pushinteger(L, end.row);
  lua_pushinteger(L, end.column);
  lua_pushinteger(L, end_byte);
  return 3;
}

static int node_child_count(lua_State *L)
{
  TSNode node = node_check(L, 1);
  uint32_t count = ts_node_child_count(node);
  lua_pushinteger(L, count);
  return 1;
}

static int node_named_child_count(lua_State *L)
{
  TSNode node = node_check(L, 1);
  uint32_t count = ts_node_named_child_count(node);
  lua_pushinteger(L, count);
  return 1;
}

static int node_type(lua_State *L)
{
  TSNode node = node_check(L, 1);
  lua_pushstring(L, ts_node_type(node));
  return 1;
}

static int node_symbol(lua_State *L)
{
  TSNode node = node_check(L, 1);
  TSSymbol symbol = ts_node_symbol(node);
  lua_pushinteger(L, symbol);
  return 1;
}

static int node_field(lua_State *L)
{
  TSNode node = node_check(L, 1);

  size_t name_len;
  const char *field_name = luaL_checklstring(L, 2, &name_len);

  lua_newtable(L);  // [table]

  TSNode field = ts_node_child_by_field_name(node, field_name, (uint32_t)name_len);
  if (!ts_node_is_null(field)) {
    push_node(L, field, 1);  // [table, node]
    lua_rawseti(L, -2, 1);
  }

  return 1;
}

static int node_named(lua_State *L)
{
  TSNode node = node_check(L, 1);
  lua_pushboolean(L, ts_node_is_named(node));
  return 1;
}

static int node_sexpr(lua_State *L)
{
  TSNode node = node_check(L, 1);
  char *allocated = ts_node_string(node);
  lua_pushstring(L, allocated);
  xfree(allocated);
  return 1;
}

static int node_missing(lua_State *L)
{
  TSNode node = node_check(L, 1);
  lua_pushboolean(L, ts_node_is_missing(node));
  return 1;
}

static int node_extra(lua_State *L)
{
  TSNode node = node_check(L, 1);
  lua_pushboolean(L, ts_node_is_extra(node));
  return 1;
}

static int node_has_changes(lua_State *L)
{
  TSNode node = node_check(L, 1);
  lua_pushboolean(L, ts_node_has_changes(node));
  return 1;
}

static int node_has_error(lua_State *L)
{
  TSNode node = node_check(L, 1);
  lua_pushboolean(L, ts_node_has_error(node));
  return 1;
}

static int node_child(lua_State *L)
{
  TSNode node = node_check(L, 1);
  uint32_t num = (uint32_t)lua_tointeger(L, 2);
  TSNode child = ts_node_child(node, num);

  push_node(L, child, 1);
  return 1;
}

static int node_named_child(lua_State *L)
{
  TSNode node = node_check(L, 1);
  uint32_t num = (uint32_t)lua_tointeger(L, 2);
  TSNode child = ts_node_named_child(node, num);

  push_node(L, child, 1);
  return 1;
}

static int node_descendant_for_range(lua_State *L)
{
  TSNode node = node_check(L, 1);
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
  TSNode node = node_check(L, 1);
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
  uint32_t *child_index = lua_touserdata(L, lua_upvalueindex(1));
  TSNode source = node_check(L, lua_upvalueindex(2));

  if (*child_index >= ts_node_child_count(source)) {
    return 0;
  }

  TSNode child = ts_node_child(source, *child_index);
  push_node(L, child, lua_upvalueindex(2));

  const char *field = ts_node_field_name_for_child(source, *child_index);
  if (field != NULL) {
    lua_pushstring(L, field);
  } else {
    lua_pushnil(L);
  }  // [node, field_name_or_nil]

  (*child_index)++;

  return 2;
}

static int node_iter_children(lua_State *L)
{
  node_check(L, 1);
  uint32_t *child_index = lua_newuserdata(L, sizeof(uint32_t));  // [source_node,..., udata]
  *child_index = 0;

  lua_pushvalue(L, 1);  // [source_node, ..., udata, source_node]
  lua_pushcclosure(L, node_next_child, 2);

  return 1;
}

static int node_parent(lua_State *L)
{
  TSNode node = node_check(L, 1);
  TSNode parent = ts_node_parent(node);
  push_node(L, parent, 1);
  return 1;
}

static int __has_ancestor(lua_State *L)
{
  TSNode descendant = node_check(L, 1);
  if (lua_type(L, 2) != LUA_TTABLE) {
    lua_pushboolean(L, false);
    return 1;
  }
  int const pred_len = (int)lua_objlen(L, 2);

  TSNode node = ts_tree_root_node(descendant.tree);
  while (node.id != descendant.id && !ts_node_is_null(node)) {
    char const *node_type = ts_node_type(node);
    size_t node_type_len = strlen(node_type);

    for (int i = 3; i <= pred_len; i++) {
      lua_rawgeti(L, 2, i);
      if (lua_type(L, -1) == LUA_TSTRING) {
        size_t check_len;
        char const *check_str = lua_tolstring(L, -1, &check_len);
        if (node_type_len == check_len && memcmp(node_type, check_str, check_len) == 0) {
          lua_pushboolean(L, true);
          return 1;
        }
      }
      lua_pop(L, 1);
    }

    node = ts_node_child_with_descendant(node, descendant);
  }

  lua_pushboolean(L, false);
  return 1;
}

static int node_child_with_descendant(lua_State *L)
{
  TSNode node = node_check(L, 1);
  TSNode descendant = node_check(L, 2);
  TSNode child = ts_node_child_with_descendant(node, descendant);
  push_node(L, child, 1);
  return 1;
}

static int node_next_sibling(lua_State *L)
{
  TSNode node = node_check(L, 1);
  TSNode sibling = ts_node_next_sibling(node);
  push_node(L, sibling, 1);
  return 1;
}

static int node_prev_sibling(lua_State *L)
{
  TSNode node = node_check(L, 1);
  TSNode sibling = ts_node_prev_sibling(node);
  push_node(L, sibling, 1);
  return 1;
}

static int node_next_named_sibling(lua_State *L)
{
  TSNode node = node_check(L, 1);
  TSNode sibling = ts_node_next_named_sibling(node);
  push_node(L, sibling, 1);
  return 1;
}

static int node_prev_named_sibling(lua_State *L)
{
  TSNode node = node_check(L, 1);
  TSNode sibling = ts_node_prev_named_sibling(node);
  push_node(L, sibling, 1);
  return 1;
}

static int node_named_children(lua_State *L)
{
  TSNode source = node_check(L, 1);

  lua_newtable(L);
  int curr_index = 0;

  uint32_t n = ts_node_child_count(source);
  for (uint32_t i = 0; i < n; i++) {
    TSNode child = ts_node_child(source, i);
    if (ts_node_is_named(child)) {
      push_node(L, child, 1);
      lua_rawseti(L, -2, ++curr_index);
    }
  }

  return 1;
}

static int node_root(lua_State *L)
{
  TSNode node = node_check(L, 1);
  TSNode root = ts_tree_root_node(node.tree);
  push_node(L, root, 1);
  return 1;
}

static int node_tree(lua_State *L)
{
  node_check(L, 1);
  lua_getfenv(L, 1);  // [udata, reftable]
  lua_rawgeti(L, -1, 1);  // [udata, reftable, tree_udata]
  return 1;
}

static int node_byte_length(lua_State *L)
{
  TSNode node = node_check(L, 1);
  uint32_t start_byte = ts_node_start_byte(node);
  uint32_t end_byte = ts_node_end_byte(node);
  lua_pushinteger(L, end_byte - start_byte);
  return 1;
}

static int node_equal(lua_State *L)
{
  TSNode node1 = node_check(L, 1);
  TSNode node2 = node_check(L, 2);
  lua_pushboolean(L, ts_node_eq(node1, node2));
  return 1;
}

// TSQueryCursor

static struct luaL_Reg querycursor_meta[] = {
  { "remove_match", querycursor_remove_match },
  { "next_capture", querycursor_next_capture },
  { "next_match", querycursor_next_match },
  { "__gc", querycursor_gc },
  { NULL, NULL }
};

int tslua_push_querycursor(lua_State *L)
{
  TSNode node = node_check(L, 1);

  TSQuery *query = query_check(L, 2);
  TSQueryCursor *cursor = ts_query_cursor_new();
  ts_query_cursor_exec(cursor, query, node);

  if (lua_gettop(L) >= 3) {
    uint32_t start = (uint32_t)luaL_checkinteger(L, 3);
    uint32_t end = lua_gettop(L) >= 4 ? (uint32_t)luaL_checkinteger(L, 4) : MAXLNUM;
    ts_query_cursor_set_point_range(cursor, (TSPoint){ start, 0 }, (TSPoint){ end, 0 });
  }

  if (lua_gettop(L) >= 5 && !lua_isnil(L, 5)) {
    luaL_argcheck(L, lua_istable(L, 5), 5, "table expected");
    lua_pushnil(L);  // [dict, ..., nil]
    while (lua_next(L, 5)) {
      // [dict, ..., key, value]
      if (lua_type(L, -2) == LUA_TSTRING) {
        char *k = (char *)lua_tostring(L, -2);
        if (strequal("max_start_depth", k)) {
          uint32_t max_start_depth = (uint32_t)lua_tointeger(L, -1);
          ts_query_cursor_set_max_start_depth(cursor, max_start_depth);
        } else if (strequal("match_limit", k)) {
          uint32_t match_limit = (uint32_t)lua_tointeger(L, -1);
          ts_query_cursor_set_match_limit(cursor, match_limit);
        }
      }
      // pop the value; lua_next will pop the key.
      lua_pop(L, 1);  // [dict, ..., key]
    }
  }

  TSQueryCursor **ud = lua_newuserdata(L, sizeof(*ud));  // [node, query, ..., udata]
  *ud = cursor;
  lua_getfield(L, LUA_REGISTRYINDEX, TS_META_QUERYCURSOR);  // [node, query, ..., udata, meta]
  lua_setmetatable(L, -2);  // [node, query, ..., udata]

  // Copy the fenv which contains the nodes tree.
  lua_getfenv(L, 1);  // [udata, reftable]
  lua_setfenv(L, -2);  // [udata]

  return 1;
}

static int querycursor_remove_match(lua_State *L)
{
  TSQueryCursor *cursor = querycursor_check(L, 1);
  uint32_t match_id = (uint32_t)luaL_checkinteger(L, 2);
  ts_query_cursor_remove_match(cursor, match_id);
  return 0;
}

static int querycursor_next_capture(lua_State *L)
{
  TSQueryCursor *cursor = querycursor_check(L, 1);
  TSQueryMatch match;
  uint32_t capture_index;
  if (!ts_query_cursor_next_capture(cursor, &match, &capture_index)) {
    return 0;
  }

  TSQueryCapture capture = match.captures[capture_index];

  // Handle capture quantifiers here
  lua_pushinteger(L, capture.index + 1);  // [index]
  push_node(L, capture.node, 1);  // [index, node]
  push_querymatch(L, &match, 1);

  return 3;
}

static int querycursor_next_match(lua_State *L)
{
  TSQueryCursor *cursor = querycursor_check(L, 1);

  TSQueryMatch match;
  if (!ts_query_cursor_next_match(cursor, &match)) {
    return 0;
  }

  push_querymatch(L, &match, 1);

  return 1;
}

static TSQueryCursor *querycursor_check(lua_State *L, int index)
{
  TSQueryCursor **ud = luaL_checkudata(L, index, TS_META_QUERYCURSOR);
  luaL_argcheck(L, *ud, index, "TSQueryCursor expected");
  return *ud;
}

static int querycursor_gc(lua_State *L)
{
  TSQueryCursor *cursor = querycursor_check(L, 1);
  ts_query_cursor_delete(cursor);
  return 0;
}

// TSQueryMatch

static struct luaL_Reg querymatch_meta[] = {
  { "info", querymatch_info },
  { "captures", querymatch_captures },
  { NULL, NULL }
};

static void push_querymatch(lua_State *L, TSQueryMatch *match, int uindex)
{
  TSQueryMatch *ud = lua_newuserdata(L, sizeof(TSQueryMatch));  // [udata]
  *ud = *match;
  lua_getfield(L, LUA_REGISTRYINDEX, TS_META_QUERYMATCH);  // [udata, meta]
  lua_setmetatable(L, -2);  // [udata]

  // Copy the fenv which contains the nodes tree.
  lua_getfenv(L, uindex);  // [udata, reftable]
  lua_setfenv(L, -2);  // [udata]
}

static int querymatch_info(lua_State *L)
{
  TSQueryMatch *match = luaL_checkudata(L, 1, TS_META_QUERYMATCH);
  lua_pushinteger(L, match->id);
  lua_pushinteger(L, match->pattern_index + 1);
  return 2;
}

static int querymatch_captures(lua_State *L)
{
  TSQueryMatch *match = luaL_checkudata(L, 1, TS_META_QUERYMATCH);
  lua_newtable(L);  // [match, nodes, captures]
  for (size_t i = 0; i < match->capture_count; i++) {
    TSQueryCapture capture = match->captures[i];
    int index = (int)capture.index + 1;

    lua_rawgeti(L, -1, index);  // [match, node, captures]
    if (lua_isnil(L, -1)) {  // [match, node, captures, nil]
      lua_pop(L, 1);  // [match, node, captures]
      lua_newtable(L);  // [match, node, captures, nodes]
    }
    push_node(L, capture.node, 1);  // [match, node, captures, nodes, node]
    lua_rawseti(L, -2, (int)lua_objlen(L, -2) + 1);  // [match, node, captures, nodes]
    lua_rawseti(L, -2, index);  // [match, node, captures]
  }
  return 1;
}

// TSQuery

static struct luaL_Reg query_meta[] = {
  { "__gc", query_gc },
  { "__tostring", query_tostring },
  { "inspect", query_inspect },
  { NULL, NULL }
};

int tslua_parse_query(lua_State *L)
{
  if (lua_gettop(L) < 2 || !lua_isstring(L, 1) || !lua_isstring(L, 2)) {
    return luaL_error(L, "string expected");
  }

  TSLanguage *lang = lang_check(L, 1);

  size_t len;
  const char *src = lua_tolstring(L, 2, &len);

  tslua_query_parse_count++;
  uint32_t error_offset;
  TSQueryError error_type;
  TSQuery *query = ts_query_new(lang, src, (uint32_t)len, &error_offset, &error_type);

  if (!query) {
    char err_msg[IOSIZE];
    query_err_string(src, (int)error_offset, error_type, err_msg, sizeof(err_msg));
    return luaL_error(L, "%s", err_msg);
  }

  TSQuery **ud = lua_newuserdata(L, sizeof(TSQuery *));  // [udata]
  *ud = query;
  lua_getfield(L, LUA_REGISTRYINDEX, TS_META_QUERY);  // [udata, meta]
  lua_setmetatable(L, -2);  // [udata]
  return 1;
}

static const char *query_err_to_string(TSQueryError error_type)
{
  switch (error_type) {
  case TSQueryErrorSyntax:
    return "Invalid syntax:\n";
  case TSQueryErrorNodeType:
    return "Invalid node type ";
  case TSQueryErrorField:
    return "Invalid field name ";
  case TSQueryErrorCapture:
    return "Invalid capture name ";
  case TSQueryErrorStructure:
    return "Impossible pattern:\n";
  default:
    return "error";
  }
}

static void query_err_string(const char *src, int error_offset, TSQueryError error_type, char *err,
                             size_t errlen)
{
  int line_start = 0;
  int row = 0;
  const char *error_line = NULL;
  int error_line_len = 0;

  const char *end_str;
  do {
    const char *src_tmp = src + line_start;
    end_str = strchr(src_tmp, '\n');
    int line_length = end_str != NULL ? (int)(end_str - src_tmp) : (int)strlen(src_tmp);
    int line_end = line_start + line_length;
    if (line_end > error_offset) {
      error_line = src_tmp;
      error_line_len = line_length;
      break;
    }
    line_start = line_end + 1;
    row++;
  } while (end_str != NULL);

  int column = error_offset - line_start;

  const char *type_msg = query_err_to_string(error_type);
  snprintf(err, errlen, "Query error at %d:%d. %s", row + 1, column + 1, type_msg);
  size_t offset = strlen(err);
  errlen = errlen - offset;
  err = err + offset;

  // Error types that report names
  if (error_type == TSQueryErrorNodeType
      || error_type == TSQueryErrorField
      || error_type == TSQueryErrorCapture) {
    const char *suffix = src + error_offset;
    bool is_anonymous = error_type == TSQueryErrorNodeType && suffix[-1] == '"';
    int suffix_len = 0;
    char c = suffix[suffix_len];
    if (is_anonymous) {
      int backslashes = 0;
      // Stop when we hit an unescaped double quote
      while (c != '"' || backslashes % 2 != 0) {
        if (c == '\\') {
          backslashes += 1;
        } else {
          backslashes = 0;
        }
        c = suffix[++suffix_len];
      }
    } else {
      // Stop when we hit the end of the identifier
      while (isalnum(c) || c == '_' || c == '-' || c == '.') {
        c = suffix[++suffix_len];
      }
    }
    snprintf(err, errlen, "\"%.*s\":\n", suffix_len, suffix);
    offset = strlen(err);
    errlen = errlen - offset;
    err = err + offset;
  }

  if (!error_line) {
    snprintf(err, errlen, "Unexpected EOF\n");
    return;
  }

  snprintf(err, errlen, "%.*s\n%*s^\n", error_line_len, error_line, column, "");
}

static TSQuery *query_check(lua_State *L, int index)
{
  TSQuery **ud = luaL_checkudata(L, index, TS_META_QUERY);
  luaL_argcheck(L, *ud, index, "TSQuery expected");
  return *ud;
}

static int query_gc(lua_State *L)
{
  TSQuery *query = query_check(L, 1);
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

  // TSQueryInfo
  lua_createtable(L, 0, 2);  // [retval]

  uint32_t n_pat = ts_query_pattern_count(query);
  lua_createtable(L, (int)n_pat, 1);  // [retval, patterns]
  for (size_t i = 0; i < n_pat; i++) {
    uint32_t len;
    const TSQueryPredicateStep *step = ts_query_predicates_for_pattern(query, (uint32_t)i, &len);
    if (len == 0) {
      continue;
    }
    lua_createtable(L, (int)len/4, 1);  // [retval, patterns, pat]
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
        lua_pushinteger(L, step[k].value_id + 1);  // [..., pat, pred, item]
      } else {
        abort();
      }
      lua_rawseti(L, -2, nextitem++);  // [retval, patterns, pat, pred]
    }
    // last predicate should have ended with TypeDone
    lua_pop(L, 1);  // [retval, patterns, pat]
    lua_rawseti(L, -2, (int)i + 1);  // [retval, patterns]
  }
  lua_setfield(L, -2, "patterns");  // [retval]

  uint32_t n_captures = ts_query_capture_count(query);
  lua_createtable(L, (int)n_captures, 0);  // [retval, captures]
  for (size_t i = 0; i < n_captures; i++) {
    uint32_t strlen;
    const char *str = ts_query_capture_name_for_id(query, (uint32_t)i, &strlen);
    lua_pushlstring(L, str, strlen);  // [retval, captures, capture]
    lua_rawseti(L, -2, (int)i + 1);
  }
  lua_setfield(L, -2, "captures");  // [retval]

  return 1;
}

// Library init

static void build_meta(lua_State *L, const char *tname, const luaL_Reg *meta)
{
  if (luaL_newmetatable(L, tname)) {  // [meta]
    luaL_register(L, NULL, meta);

    lua_pushvalue(L, -1);  // [meta, meta]
    lua_setfield(L, -2, "__index");  // [meta]
  }
  lua_pop(L, 1);  // [] (don't use it now)
}

/// Init the tslua library.
///
/// All global state is stored in the registry of the lua_State.
void tslua_init(lua_State *L)
{
  // type metatables
  build_meta(L, TS_META_PARSER, parser_meta);
  build_meta(L, TS_META_TREE, tree_meta);
  build_meta(L, TS_META_NODE, node_meta);
  build_meta(L, TS_META_QUERY, query_meta);
  build_meta(L, TS_META_QUERYCURSOR, querycursor_meta);
  build_meta(L, TS_META_QUERYMATCH, querymatch_meta);

  ts_set_allocator(xmalloc, xcalloc, xrealloc, xfree);
}

void tslua_free(void)
{
#ifdef HAVE_WASMTIME
  if (wasmengine != NULL) {
    wasm_engine_delete(wasmengine);
  }
  if (ts_wasmstore != NULL) {
    ts_wasm_store_delete(ts_wasmstore);
  }
#endif
}
