/*
 * This module exports three classes, and each instance of those classes has its
 * own private registry for temporary reference storage(keeping state between
 * calls). A private registry makes managing memory much easier since all we
 * have to do is call luaL_unref passing the registry reference when the
 * instance is collected by the __gc metamethod.
 *
 * This private registry is manipulated with `lmpack_ref` / `lmpack_unref` /
 * `lmpack_geti`, which are analogous to `luaL_ref` / `luaL_unref` /
 * `lua_rawgeti` but operate on the private registry passed as argument.
 *
 * In order to simplify debug registry leaks during normal operation(with the
 * leak_test.lua script), these `lmpack_*` registry functions will target the
 * normal lua registry when MPACK_DEBUG_REGISTRY_LEAK is defined during
 * compilation.
 */
#define LUA_LIB
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include <lauxlib.h>
#include <lua.h>
#include <luaconf.h>

#include "nvim/macros_defs.h"

#include "lmpack.h"

#include "rpc.h"

#define UNPACKER_META_NAME "mpack.Unpacker"
#define UNPACK_FN_NAME "decode"
#define PACKER_META_NAME "mpack.Packer"
#define PACK_FN_NAME "encode"
#define SESSION_META_NAME "mpack.Session"
#define NIL_NAME "mpack.NIL"
#define EMPTY_DICT_NAME "mpack.empty_dict"

/* 
 * TODO(tarruda): When targeting lua 5.3 and being compiled with `long long`
 * support(not -ansi), we should make use of lua 64 bit integers for
 * representing msgpack integers, since `double` can't represent the full range.
 */

#ifndef luaL_reg
/* Taken from Lua5.1's lauxlib.h */
#define luaL_reg    luaL_Reg
#endif

#if LUA_VERSION_NUM > 501
#ifndef luaL_register
#define luaL_register(L,n,f) luaL_setfuncs(L,f,0)
#endif
#endif

typedef struct {
  lua_State *L;
  mpack_parser_t *parser;
  int reg, ext, unpacking, mtdict;
  char *string_buffer;
} Unpacker;

typedef struct {
  lua_State *L;
  mpack_parser_t *parser;
  int reg, ext, root, packing, mtdict;
  int is_bin, is_bin_fn;
} Packer;

typedef struct {
  lua_State *L;
  int reg;
  mpack_rpc_session_t *session;
  struct {
    int type;
    mpack_rpc_message_t msg;
    int method_or_error;
    int args_or_result;
  } unpacked;
  int unpacker;
} Session;

static int lmpack_ref(lua_State *L, int reg)
{
#ifdef MPACK_DEBUG_REGISTRY_LEAK
  return luaL_ref(L, LUA_REGISTRYINDEX);
#else
  int rv;
  lua_rawgeti(L, LUA_REGISTRYINDEX, reg);
  lua_pushvalue(L, -2);
  rv = luaL_ref(L, -2);
  lua_pop(L, 2);
  return rv;
#endif
}

static void lmpack_unref(lua_State *L, int reg, int ref)
{
#ifdef MPACK_DEBUG_REGISTRY_LEAK
  luaL_unref(L, LUA_REGISTRYINDEX, ref);
#else
  lua_rawgeti(L, LUA_REGISTRYINDEX, reg);
  luaL_unref(L, -1, ref);
  lua_pop(L, 1);
#endif
}

static void lmpack_geti(lua_State *L, int reg, int ref)
{
#ifdef MPACK_DEBUG_REGISTRY_LEAK
  lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
#else
  lua_rawgeti(L, LUA_REGISTRYINDEX, reg);
  lua_rawgeti(L, -1, ref);
  lua_replace(L, -2);
#endif
}

/* make a shallow copy of the table on stack and remove it after the copy is
 * done */
static void lmpack_shallow_copy(lua_State *L)
{
  lua_newtable(L);
  lua_pushnil(L);
  while (lua_next(L, -3)) {
    lua_pushvalue(L, -2);
    lua_insert(L, -2);
    lua_settable(L, -4);
  }
  lua_remove(L, -2);
}

static mpack_parser_t *lmpack_grow_parser(mpack_parser_t *parser)
{
  mpack_parser_t *old = parser;
  mpack_uint32_t new_capacity = old->capacity * 2;
  parser = malloc(MPACK_PARSER_STRUCT_SIZE(new_capacity));
  if (!parser) goto end;
  mpack_parser_init(parser, new_capacity);
  mpack_parser_copy(parser, old);
  free(old);
end:
  return parser;
}

static mpack_rpc_session_t *lmpack_grow_session(mpack_rpc_session_t *session)
{
  mpack_rpc_session_t *old = session;
  mpack_uint32_t new_capacity = old->capacity * 2;
  session = malloc(MPACK_RPC_SESSION_STRUCT_SIZE(new_capacity));
  if (!session) goto end;
  mpack_rpc_session_init(session, new_capacity);
  mpack_rpc_session_copy(session, old);
  free(old);
end:
  return session;
}

static Unpacker *lmpack_check_unpacker(lua_State *L, int index)
{
  return luaL_checkudata(L, index, UNPACKER_META_NAME);
}

static Packer *lmpack_check_packer(lua_State *L, int index)
{
  return luaL_checkudata(L, index, PACKER_META_NAME);
}

static Session *lmpack_check_session(lua_State *L, int index)
{
  return luaL_checkudata(L, index, SESSION_META_NAME);
}

static int lmpack_isnil(lua_State *L, int index)
{
  int rv;
  if (!lua_isuserdata(L, index)) return 0;
  lua_getfield(L, LUA_REGISTRYINDEX, NIL_NAME);
  rv = lua_rawequal(L, -1, -2);
  lua_pop(L, 1);
  return rv;
}

static int lmpack_isunpacker(lua_State *L, int index)
{
  int rv;
  if (!lua_isuserdata(L, index) || !lua_getmetatable(L, index)) return 0;
  luaL_getmetatable(L, UNPACKER_META_NAME);
  rv = lua_rawequal(L, -1, -2);
  lua_pop(L, 2);
  return rv;
}

static void lmpack_pushnil(lua_State *L)
{
  lua_getfield(L, LUA_REGISTRYINDEX, NIL_NAME);
}

/* adapted from
 * https://github.com/antirez/lua-cmsgpack/blob/master/lua_cmsgpack.c */
static mpack_uint32_t lmpack_objlen(lua_State *L, int *is_array)
{
  size_t len, max;
  int isarr;
  lua_Number n;
#ifndef NDEBUG
  int top = lua_gettop(L);
  assert(top);
#endif

  if ((lua_type(L, -1)) != LUA_TTABLE) {
#if LUA_VERSION_NUM >= 502
    len = lua_rawlen(L, -1);
#elif LUA_VERSION_NUM == 501
    len = lua_objlen(L, -1);
#else
    #error You have either broken or too old Lua installation. This library requires Lua>=5.1
#endif
    goto end;
  }

  /* count the number of keys and determine if it is an array */
  len = 0;
  max = 0;
  isarr = 1;
  lua_pushnil(L);

  while (lua_next(L, -2)) {
    lua_pop(L, 1);  /* pop value */
    isarr = isarr
      && lua_type(L, -1) == LUA_TNUMBER /* lua number */
      && (n = lua_tonumber(L, -1)) > 0  /* greater than 0 */
      && (size_t)n == n;                /* and integer */
    max = isarr && (size_t)n > max ? (size_t)n : max;
    len++;
  }

  // when len==0, the caller should guess the type!
  if (len > 0) {
    *is_array = isarr && max == len;
  }

end:
  if ((size_t)-1 > (mpack_uint32_t)-1 && len > (mpack_uint32_t)-1)
    /* msgpack spec doesn't allow lengths > 32 bits */
    len = (mpack_uint32_t)-1;
  assert(top == lua_gettop(L));
  return (mpack_uint32_t)len;
}

static int lmpack_unpacker_new(lua_State *L)
{
  Unpacker *rv;

  if (lua_gettop(L) > 1)
    return luaL_error(L, "expecting at most 1 table argument"); 

  rv = lua_newuserdata(L, sizeof(*rv));
  rv->parser = malloc(sizeof(*rv->parser));
  if (!rv->parser) return luaL_error(L, "Failed to allocate memory");
  mpack_parser_init(rv->parser, 0);
  rv->parser->data.p = rv;
  rv->string_buffer = NULL;
  rv->L = L;
  rv->unpacking = 0;
  luaL_getmetatable(L, UNPACKER_META_NAME);
  lua_setmetatable(L, -2);

#ifndef MPACK_DEBUG_REGISTRY_LEAK
  lua_newtable(L);
  rv->reg = luaL_ref(L, LUA_REGISTRYINDEX);
#endif
  rv->ext = LUA_NOREF;

  lua_getfield(L, LUA_REGISTRYINDEX, EMPTY_DICT_NAME);
  rv->mtdict = lmpack_ref(L, rv->reg);

  if (lua_istable(L, 1)) {
    /* parse options */
    lua_getfield(L, 1, "ext");
    if (!lua_isnil(L, -1)) {
      if (!lua_istable(L, -1))
        return luaL_error(L, "\"ext\" option must be a table"); 
      lmpack_shallow_copy(L);
    }
    rv->ext = lmpack_ref(L, rv->reg);
  }

  return 1;
}

static int lmpack_unpacker_delete(lua_State *L)
{
  Unpacker *unpacker = lmpack_check_unpacker(L, 1);
  if (unpacker->ext != LUA_NOREF)
    lmpack_unref(L, unpacker->reg, unpacker->ext);
#ifndef MPACK_DEBUG_REGISTRY_LEAK
  luaL_unref(L, LUA_REGISTRYINDEX, unpacker->reg);
#endif
  free(unpacker->parser);
  return 0;
}

static void lmpack_parse_enter(mpack_parser_t *parser, mpack_node_t *node)
{
  Unpacker *unpacker = parser->data.p;
  lua_State *L = unpacker->L;

  switch (node->tok.type) {
    case MPACK_TOKEN_NIL:
      lmpack_pushnil(L); break;
    case MPACK_TOKEN_BOOLEAN:
      lua_pushboolean(L, (int)mpack_unpack_boolean(node->tok)); break;
    case MPACK_TOKEN_UINT:
    case MPACK_TOKEN_SINT:
    case MPACK_TOKEN_FLOAT:
      lua_pushnumber(L, mpack_unpack_number(node->tok)); break;
    case MPACK_TOKEN_CHUNK:
      assert(unpacker->string_buffer);
      memcpy(unpacker->string_buffer + MPACK_PARENT_NODE(node)->pos,
          node->tok.data.chunk_ptr, node->tok.length);
      break;
    case MPACK_TOKEN_BIN:
    case MPACK_TOKEN_STR:
    case MPACK_TOKEN_EXT:
      unpacker->string_buffer = malloc(node->tok.length);
      if (!unpacker->string_buffer) luaL_error(L, "Failed to allocate memory");
      break;
    case MPACK_TOKEN_ARRAY:
    case MPACK_TOKEN_MAP:
      lua_newtable(L);
      node->data[0].i = lmpack_ref(L, unpacker->reg);
      break;
  }
}

static void lmpack_parse_exit(mpack_parser_t *parser, mpack_node_t *node)
{
  Unpacker *unpacker = parser->data.p;
  lua_State *L = unpacker->L;
  mpack_node_t *parent = MPACK_PARENT_NODE(node);

  switch (node->tok.type) {
    case MPACK_TOKEN_BIN:
    case MPACK_TOKEN_STR:
    case MPACK_TOKEN_EXT:
      lua_pushlstring(L, unpacker->string_buffer, node->tok.length);
      free(unpacker->string_buffer);
      unpacker->string_buffer = NULL;
      if (node->tok.type == MPACK_TOKEN_EXT && unpacker->ext != LUA_NOREF) {
        /* check if there's a handler for this type */
        lmpack_geti(L, unpacker->reg, unpacker->ext);
        lua_rawgeti(L, -1, node->tok.data.ext_type);
        if (lua_isfunction(L, -1)) {
          /* stack:
           *
           * -1: ext unpacker function
           * -2: ext unpackers table 
           * -3: ext string 
           *
           * We want to call the ext unpacker function with the type and string
           * as arguments, so push those now
           */
          lua_pushinteger(L, node->tok.data.ext_type);
          lua_pushvalue(L, -4);
          lua_call(L, 2, 1);
          /* stack:
           *
           * -1: returned object
           * -2: ext unpackers table
           * -3: ext string 
           */
          lua_replace(L, -3);
        } else {
          /* the last lua_rawgeti should have pushed nil on the stack,
           * remove it */
          lua_pop(L, 1);
        }
        /* pop the ext unpackers table */
        lua_pop(L, 1);
      }
      break;
    case MPACK_TOKEN_ARRAY:
    case MPACK_TOKEN_MAP:
      lmpack_geti(L, unpacker->reg, (int)node->data[0].i);
      lmpack_unref(L, unpacker->reg, (int)node->data[0].i);
      if (node->key_visited == 0 && node->tok.type == MPACK_TOKEN_MAP) {
        lmpack_geti(L, unpacker->reg, unpacker->mtdict); // [table, mtdict]
        lua_setmetatable(L, -2); // [table]
      }

      break;
    default:
      break;
  }

  if (parent && parent->tok.type < MPACK_TOKEN_BIN) {
    /* At this point the parsed object is on the stack. Add it to the parent
     * container. First put the container on the stack. */
    lmpack_geti(L, unpacker->reg, (int)parent->data[0].i);

    if (parent->tok.type == MPACK_TOKEN_ARRAY) {
      /* Array, save the value on key equal to `parent->pos` */
      lua_pushnumber(L, (lua_Number)parent->pos);
      lua_pushvalue(L, -3);
      lua_settable(L, -3);
    } else {
      assert(parent->tok.type == MPACK_TOKEN_MAP);
      if (parent->key_visited) {
        /* save the key on the registry */ 
        lua_pushvalue(L, -2);
        parent->data[1].i = lmpack_ref(L, unpacker->reg);
      } else {
        /* set the key/value pair */
        lmpack_geti(L, unpacker->reg, (int)parent->data[1].i);
        lmpack_unref(L, unpacker->reg, (int)parent->data[1].i);
        lua_pushvalue(L, -3);
        lua_settable(L, -3);
      }
    }
    lua_pop(L, 2);  /* pop the container/object */
  }
}

static int lmpack_unpacker_unpack_str(lua_State *L, Unpacker *unpacker,
    const char **str, size_t *len)
{
  int rv;

  if (unpacker->unpacking) {
    return luaL_error(L, "Unpacker instance already working. Use another "
                         "Unpacker or mpack." UNPACK_FN_NAME "() if you "
                         "need to " UNPACK_FN_NAME " from the ext handler");
  }
  
  do {
    unpacker->unpacking = 1;
    rv = mpack_parse(unpacker->parser, str, len, lmpack_parse_enter,
        lmpack_parse_exit);
    unpacker->unpacking = 0;

    if (rv == MPACK_NOMEM) {
      unpacker->parser = lmpack_grow_parser(unpacker->parser);
      if (!unpacker->parser) {
        return luaL_error(L, "failed to grow Unpacker capacity");
      }
    }
  } while (rv == MPACK_NOMEM);

  if (rv == MPACK_ERROR)
    return luaL_error(L, "invalid msgpack string");

  return rv;
}

static int lmpack_unpacker_unpack(lua_State *L)
{
  int result, argc;
  lua_Number startpos;
  size_t len, offset;
  const char *str, *str_init;
  Unpacker *unpacker;
  
  if ((argc = lua_gettop(L)) > 3 || argc < 2)
    return luaL_error(L, "expecting between 2 and 3 arguments"); 

  unpacker = lmpack_check_unpacker(L, 1);
  unpacker->L = L;

  str_init = str = luaL_checklstring(L, 2, &len);
  startpos = lua_gettop(L) == 3 ? luaL_checknumber(L, 3) : 1;

  luaL_argcheck(L, startpos > 0, 3,
      "start position must be greater than zero");
  luaL_argcheck(L, (size_t)startpos == startpos, 3,
      "start position must be an integer");
  luaL_argcheck(L, (size_t)startpos <= len, 3,
      "start position must be less than or equal to the input string length");

  offset = (size_t)startpos - 1 ;
  str += offset;
  len -= offset;
  result = lmpack_unpacker_unpack_str(L, unpacker, &str, &len);

  if (result == MPACK_EOF)
    /* if we hit EOF, return nil as the object */
    lua_pushnil(L);

  /* also return the new position in the input string */
  lua_pushinteger(L, str - str_init + 1);
  assert(lua_gettop(L) == argc + 2);
  return 2;
}

static int lmpack_packer_new(lua_State *L)
{
  Packer *rv;

  if (lua_gettop(L) > 1)
    return luaL_error(L, "expecting at most 1 table argument"); 

  rv = lua_newuserdata(L, sizeof(*rv));
  rv->parser = malloc(sizeof(*rv->parser));
  if (!rv->parser) return luaL_error(L, "failed to allocate parser memory");
  mpack_parser_init(rv->parser, 0);
  rv->parser->data.p = rv;
  rv->L = L;
  rv->packing = 0;
  rv->is_bin = 0;
  rv->is_bin_fn = LUA_NOREF;
  luaL_getmetatable(L, PACKER_META_NAME);
  lua_setmetatable(L, -2);

#ifndef MPACK_DEBUG_REGISTRY_LEAK
  lua_newtable(L);
  rv->reg = luaL_ref(L, LUA_REGISTRYINDEX);
#endif
  rv->ext = LUA_NOREF;

  lua_getfield(L, LUA_REGISTRYINDEX, EMPTY_DICT_NAME);
  rv->mtdict = lmpack_ref(L, rv->reg);

  if (lua_istable(L, 1)) {
    /* parse options */
    lua_getfield(L, 1, "ext");
    if (!lua_isnil(L, -1)) {
      if (!lua_istable(L, -1))
        return luaL_error(L, "\"ext\" option must be a table"); 
      lmpack_shallow_copy(L);
    }
    rv->ext = lmpack_ref(L, rv->reg);
    lua_getfield(L, 1, "is_bin");
    if (!lua_isnil(L, -1)) {
      if (!lua_isboolean(L, -1) && !lua_isfunction(L, -1))
        return luaL_error(L,
            "\"is_bin\" option must be a boolean or function"); 
      rv->is_bin = lua_toboolean(L, -1);
      if (lua_isfunction(L, -1)) rv->is_bin_fn = lmpack_ref(L, rv->reg);
      else lua_pop(L, 1);
    } else {
      lua_pop(L, 1);
    }

  }

  return 1;
}

static int lmpack_packer_delete(lua_State *L)
{
  Packer *packer = lmpack_check_packer(L, 1);
  if (packer->ext != LUA_NOREF)
    lmpack_unref(L, packer->reg, packer->ext);
#ifndef MPACK_DEBUG_REGISTRY_LEAK
  luaL_unref(L, LUA_REGISTRYINDEX, packer->reg);
#endif
  free(packer->parser);
  return 0;
}

static void lmpack_unparse_enter(mpack_parser_t *parser, mpack_node_t *node)
{
  int type;
  Packer *packer = parser->data.p;
  lua_State *L = packer->L;
  mpack_node_t *parent = MPACK_PARENT_NODE(node);

  if (parent) {
    /* get the parent */
    lmpack_geti(L, packer->reg, (int)parent->data[0].i);

    if (parent->tok.type > MPACK_TOKEN_MAP) {
      /* strings are a special case, they are packed as single child chunk
       * node */
      const char *str = lua_tolstring(L, -1, NULL);
      node->tok = mpack_pack_chunk(str, parent->tok.length);
      lua_pop(L, 1);
      return;
    }

    if (parent->tok.type == MPACK_TOKEN_ARRAY) {
      /* push the next index */
      lua_pushnumber(L, (lua_Number)(parent->pos + 1));
      /* push the element */
      lua_gettable(L, -2);
    } else if (parent->tok.type == MPACK_TOKEN_MAP) {
      int result;
      /* push the previous key */
      lmpack_geti(L, packer->reg, (int)parent->data[1].i);
      /* push the pair */
      result = lua_next(L, -2);
      assert(result);  /* should not be here if the map was fully processed */
      (void)result; /* ignore unused warning */
      if (parent->key_visited) {
        /* release the current key */
        lmpack_unref(L, packer->reg, (int)parent->data[1].i);
        /* push key to the top */
        lua_pushvalue(L, -2);
        /* set the key for the next iteration, leaving value on top */
        parent->data[1].i = lmpack_ref(L, packer->reg);
        /* replace key by the value */
        lua_replace(L, -2);
      } else {
        /* pop value */
        lua_pop(L, 1);
      }
    }
    /* remove parent, leaving only the object which will be serialized */
    lua_remove(L, -2);
  } else {
    /* root object */
    lmpack_geti(L, packer->reg, packer->root);
  }

  type = lua_type(L, -1);

  switch (type) {
    case LUA_TBOOLEAN:
      node->tok = mpack_pack_boolean((unsigned)lua_toboolean(L, -1));
      break;
    case LUA_TNUMBER:
      node->tok = mpack_pack_number(lua_tonumber(L, -1));
      break;
    case LUA_TSTRING: {
      int is_bin = packer->is_bin;
      if (is_bin && packer->is_bin_fn != LUA_NOREF) {
        lmpack_geti(L, packer->reg, packer->is_bin_fn);
        lua_pushvalue(L, -2);
        lua_call(L, 1, 1);
        is_bin = lua_toboolean(L, -1);
        lua_pop(L, 1);
      }
      if (is_bin) node->tok = mpack_pack_bin(lmpack_objlen(L, NULL));
      else node->tok = mpack_pack_str(lmpack_objlen(L, NULL));
      break;
    }
    case LUA_TTABLE: {
      mpack_uint32_t len;
      mpack_node_t *n;

      int has_meta = lua_getmetatable(L, -1);
      int has_mtdict = false;
      if (has_meta && packer->mtdict != LUA_NOREF) {
          lmpack_geti(L, packer->reg, packer->mtdict); // [table, metatable, mtdict]
          has_mtdict = lua_rawequal(L, -1, -2);
          lua_pop(L, 1); // [table, metatable];
      }
      if (packer->ext != LUA_NOREF && has_meta && !has_mtdict) {
        /* check if there's a handler for this metatable */
        lmpack_geti(L, packer->reg, packer->ext);
        lua_pushvalue(L, -2);
        lua_gettable(L, -2);
        if (lua_isfunction(L, -1)) {
          lua_Number ext = -1;
          /* stack:
           *
           * -1: ext packer function
           * -2: ext packers table
           * -3: metatable
           * -4: original object
           *
           * We want to call the ext packer function with the original object as
           * argument, so push it on the top
           */
          lua_pushvalue(L, -4);
          /* handler should return type code and string */
          lua_call(L, 1, 2);
          if (!lua_isnumber(L, -2) || (ext = lua_tonumber(L, -2)) < 0
              || ext > 127 || (int)ext != ext)
            luaL_error(L,
                "the first result from ext packer must be an integer "
                "between 0 and 127");
          if (!lua_isstring(L, -1))
            luaL_error(L,
                "the second result from ext packer must be a string");
          node->tok = mpack_pack_ext((int)ext, lmpack_objlen(L, NULL));
          /* stack: 
           *
           * -1: ext string
           * -2: ext type
           * -3: ext packers table
           * -4: metatable
           * -5: original table 
           *
           * We want to leave only the returned ext string, so
           * replace -5 with the string and pop 3
           */
          lua_replace(L, -5);
          lua_pop(L, 3);
          break;  /* done */
        } else {
          /* stack: 
           *
           * -1: ext packers table
           * -2: metatable
           * -3: original table 
           *
           * We want to leave only the original table and metatable since they
           * will be handled below, so pop 1
           */
          lua_pop(L, 1);
        }
      }

      if (has_meta) {
        lua_pop(L, 1); // [table]
      }

      /* check for cycles */
      n = node;
      while ((n = MPACK_PARENT_NODE(n))) {
        lmpack_geti(L, packer->reg, (int)n->data[0].i);
        if (lua_rawequal(L, -1, -2)) {
          /* break out of cycles with NIL  */
          node->tok = mpack_pack_nil();
          lua_pop(L, 2);
          lmpack_pushnil(L);
          goto end;
        }
        lua_pop(L, 1);
      }

      int is_array = !has_mtdict;
      len = lmpack_objlen(L, &is_array);
      if (is_array) {
        node->tok = mpack_pack_array(len);
      } else {
        node->tok = mpack_pack_map(len);
        /* save nil as the previous key to start iteration */
        node->data[1].i = LUA_REFNIL;
      }
      break;
    }
    case LUA_TUSERDATA:
      if (lmpack_isnil(L, -1)) {
        node->tok = mpack_pack_nil();
        break;
      }
      FALLTHROUGH;
    default:
	  {
		/* #define FMT */
		char errmsg[50];
		snprintf(errmsg, 50, "can't serialize object of type %d", type);
		luaL_error(L, errmsg);
	  }
  }

end:
  node->data[0].i = lmpack_ref(L, packer->reg);
}

static void lmpack_unparse_exit(mpack_parser_t *parser, mpack_node_t *node)
{
  Packer *packer = parser->data.p;
  lua_State *L = packer->L;
  if (node->tok.type != MPACK_TOKEN_CHUNK) {
    /* release the object */
    lmpack_unref(L, packer->reg, (int)node->data[0].i);
    if (node->tok.type == MPACK_TOKEN_MAP)
      lmpack_unref(L, packer->reg, (int)node->data[1].i);
  }
}

static int lmpack_packer_pack(lua_State *L)
{
  char *b;
  size_t bl;
  int result, argc;
  Packer *packer;
  luaL_Buffer buffer;

  if ((argc = lua_gettop(L)) != 2)
    return luaL_error(L, "expecting exactly 2 arguments"); 

  packer = lmpack_check_packer(L, 1);
  packer->L = L;
  packer->root = lmpack_ref(L, packer->reg);
  luaL_buffinit(L, &buffer);
  b = luaL_prepbuffer(&buffer);
  bl = LUAL_BUFFERSIZE;

  if (packer->packing) {
    return luaL_error(L, "Packer instance already working. Use another Packer "
                         "or mpack." PACK_FN_NAME "() if you need to "
                         PACK_FN_NAME " from the ext handler");
  }

  do {
    size_t bl_init = bl;
    packer->packing = 1;
    result = mpack_unparse(packer->parser, &b, &bl, lmpack_unparse_enter,
        lmpack_unparse_exit);
    packer->packing = 0;

    if (result == MPACK_NOMEM) {
      packer->parser = lmpack_grow_parser(packer->parser);
      if (!packer->parser) {
        return luaL_error(L, "Failed to grow Packer capacity");
      }
    }

    luaL_addsize(&buffer, bl_init - bl);

    if (!bl) {
      /* buffer empty, resize */
      b = luaL_prepbuffer(&buffer);
      bl = LUAL_BUFFERSIZE;
    }
  } while (result == MPACK_EOF || result == MPACK_NOMEM);

  lmpack_unref(L, packer->reg, packer->root);
  luaL_pushresult(&buffer);
  assert(lua_gettop(L) == argc);
  return 1;
}

static int lmpack_session_new(lua_State *L)
{
  Session *rv = lua_newuserdata(L, sizeof(*rv));
  rv->session = malloc(sizeof(*rv->session));
  if (!rv->session) return luaL_error(L, "Failed to allocate memory");
  mpack_rpc_session_init(rv->session, 0);
  rv->L = L;
  luaL_getmetatable(L, SESSION_META_NAME);
  lua_setmetatable(L, -2);
#ifndef MPACK_DEBUG_REGISTRY_LEAK
  lua_newtable(L);
  rv->reg = luaL_ref(L, LUA_REGISTRYINDEX);
#endif
  rv->unpacker = LUA_REFNIL;
  rv->unpacked.args_or_result = LUA_NOREF;
  rv->unpacked.method_or_error = LUA_NOREF;
  rv->unpacked.type = MPACK_EOF;

  if (lua_istable(L, 1)) {
    /* parse options */
    lua_getfield(L, 1, "unpack");
    if (!lmpack_isunpacker(L, -1)) {
      return luaL_error(L,
          "\"unpack\" option must be a " UNPACKER_META_NAME " instance"); 
    }
    rv->unpacker = lmpack_ref(L, rv->reg);
  }

  return 1;
}

static int lmpack_session_delete(lua_State *L)
{
  Session *session = lmpack_check_session(L, 1);
  lmpack_unref(L, session->reg, session->unpacker);
#ifndef MPACK_DEBUG_REGISTRY_LEAK
  luaL_unref(L, LUA_REGISTRYINDEX, session->reg);
#endif
  free(session->session);
  return 0;
}

static int lmpack_session_receive(lua_State *L)
{
  int argc, done, rcount = 3;
  lua_Number startpos;
  size_t len;
  const char *str, *str_init;
  Session *session;
  Unpacker *unpacker = NULL;

  if ((argc = lua_gettop(L)) > 3 || argc < 2)
    return luaL_error(L, "expecting between 2 and 3 arguments"); 

  session = lmpack_check_session(L, 1);
  str_init = str = luaL_checklstring(L, 2, &len);
  startpos = lua_gettop(L) == 3 ? luaL_checknumber(L, 3) : 1;

  luaL_argcheck(L, startpos > 0, 3,
      "start position must be greater than zero");
  luaL_argcheck(L, (size_t)startpos == startpos, 3,
      "start position must be an integer");
  luaL_argcheck(L, (size_t)startpos <= len, 3,
      "start position must be less than or equal to the input string length");

  size_t offset = (size_t)startpos - 1 ;
  str += offset;
  len -= offset;

  if (session->unpacker != LUA_REFNIL) {
    lmpack_geti(L, session->reg, session->unpacker);
    unpacker = lmpack_check_unpacker(L, -1);
    unpacker->L = L;
    rcount += 2;
    lua_pop(L, 1);
  }

  for (;;) {
    int result;

    if (session->unpacked.type == MPACK_EOF) {
      session->unpacked.type =
        mpack_rpc_receive(session->session, &str, &len, &session->unpacked.msg);

      if (!unpacker || session->unpacked.type == MPACK_EOF)
        break;
    }
    
    result = lmpack_unpacker_unpack_str(L, unpacker, &str, &len);

    if (result == MPACK_EOF) break;

    if (session->unpacked.method_or_error == LUA_NOREF) {
      session->unpacked.method_or_error = lmpack_ref(L, session->reg);
    } else {
      session->unpacked.args_or_result = lmpack_ref(L, session->reg);
      break;
    }
  }

  done = session->unpacked.type != MPACK_EOF
    && (session->unpacked.args_or_result != LUA_NOREF || !unpacker);

  if (!done) {
    lua_pushnil(L);
    lua_pushnil(L);
    if (unpacker) {
      lua_pushnil(L);
      lua_pushnil(L);
    }
    goto end;
  }

  switch (session->unpacked.type) {
    case MPACK_RPC_REQUEST:
      lua_pushstring(L, "request");
      lua_pushnumber(L, session->unpacked.msg.id);
      break;
    case MPACK_RPC_RESPONSE:
      lua_pushstring(L, "response");
      lmpack_geti(L, session->reg, (int)session->unpacked.msg.data.i);
      break;
    case MPACK_RPC_NOTIFICATION:
      lua_pushstring(L, "notification");
      lua_pushnil(L);
      break;
    default:
      /* In most cases the only sane thing to do when receiving invalid
       * msgpack-rpc is to close the connection, so handle all errors with
       * this generic message. Later may add more detailed information. */
      return luaL_error(L, "invalid msgpack-rpc string");
  }

  session->unpacked.type = MPACK_EOF;

  if (unpacker) {
    lmpack_geti(L, session->reg, session->unpacked.method_or_error);
    lmpack_geti(L, session->reg, session->unpacked.args_or_result);
    lmpack_unref(L, session->reg, session->unpacked.method_or_error);
    lmpack_unref(L, session->reg, session->unpacked.args_or_result);
    session->unpacked.method_or_error = LUA_NOREF;
    session->unpacked.args_or_result = LUA_NOREF;
  }

end:
  lua_pushinteger(L, str - str_init + 1);
  return rcount;
}

static int lmpack_session_request(lua_State *L)
{
  int result;
  char buf[16], *b = buf;
  size_t bl = sizeof(buf);
  Session *session;
  mpack_data_t data;

  if (lua_gettop(L) > 2 || lua_gettop(L) < 1)
    return luaL_error(L, "expecting 1 or 2 arguments"); 

  session = lmpack_check_session(L, 1);
  data.i = lua_isnoneornil(L, 2) ? LUA_NOREF : lmpack_ref(L, session->reg);
  do {
    result = mpack_rpc_request(session->session, &b, &bl, data);
    if (result == MPACK_NOMEM) {
      session->session = lmpack_grow_session(session->session);
      if (!session->session)
        return luaL_error(L, "Failed to grow Session capacity");
    }
  } while (result == MPACK_NOMEM);

  assert(result == MPACK_OK);
  lua_pushlstring(L, buf, sizeof(buf) - bl);
  return 1;
}

static int lmpack_session_reply(lua_State *L)
{
  int result;
  char buf[16], *b = buf;
  size_t bl = sizeof(buf);
  Session *session;
  lua_Number id;

  if (lua_gettop(L) != 2)
    return luaL_error(L, "expecting exactly 2 arguments"); 

  session = lmpack_check_session(L, 1);
  id = lua_tonumber(L, 2);
  luaL_argcheck(L, ((size_t)id == id && id >= 0 && id <= 0xffffffff), 2,
      "invalid request id");
  result = mpack_rpc_reply(session->session, &b, &bl, (mpack_uint32_t)id);
  assert(result == MPACK_OK);
  (void)result; /* ignore unused warning */
  lua_pushlstring(L, buf, sizeof(buf) - bl);
  return 1;
}

static int lmpack_session_notify(lua_State *L)
{
  int result;
  char buf[16], *b = buf;
  size_t bl = sizeof(buf);
  Session *session;

  if (lua_gettop(L) != 1)
    return luaL_error(L, "expecting exactly 1 argument"); 

  session = lmpack_check_session(L, 1);
  result = mpack_rpc_notify(session->session, &b, &bl);
  assert(result == MPACK_OK);
  (void)result; /* ignore unused warning */
  lua_pushlstring(L, buf, sizeof(buf) - bl);
  return 1;
}

static int lmpack_nil_tostring(lua_State* L)
{
  lua_pushfstring(L, NIL_NAME, lua_topointer(L, 1));
  return 1;
}

static int lmpack_unpack(lua_State *L)
{
  int result;
  size_t len;
  const char *str;
  Unpacker unpacker;
  mpack_parser_t parser;

  if (lua_gettop(L) != 1)
    return luaL_error(L, "expecting exactly 1 argument"); 

  str = luaL_checklstring(L, 1, &len);

  /* initialize unpacker */
  lua_newtable(L);
  unpacker.reg = luaL_ref(L, LUA_REGISTRYINDEX);
  unpacker.ext = LUA_NOREF;
  unpacker.parser = &parser;
  mpack_parser_init(unpacker.parser, 0);
  unpacker.parser->data.p = &unpacker;
  unpacker.string_buffer = NULL;
  unpacker.L = L;

  lua_getfield(L, LUA_REGISTRYINDEX, EMPTY_DICT_NAME);
  unpacker.mtdict = lmpack_ref(L, unpacker.reg);

  result = mpack_parse(&parser, &str, &len, lmpack_parse_enter,
      lmpack_parse_exit);

  luaL_unref(L, LUA_REGISTRYINDEX, unpacker.reg);

  if (result == MPACK_NOMEM)
    return luaL_error(L, "object was too deep to unpack");
  else if (result == MPACK_EOF)
    return luaL_error(L, "incomplete msgpack string");
  else if (result == MPACK_ERROR)
    return luaL_error(L, "invalid msgpack string");
  else if (result == MPACK_OK && len)
    return luaL_error(L, "trailing data in msgpack string");

  assert(result == MPACK_OK);
  return 1;
}

static int lmpack_pack(lua_State *L)
{
  char *b;
  size_t bl;
  int result;
  Packer packer;
  mpack_parser_t parser;
  luaL_Buffer buffer;

  if (lua_gettop(L) != 1)
    return luaL_error(L, "expecting exactly 1 argument"); 

  /* initialize packer */
  lua_newtable(L);
  packer.reg = luaL_ref(L, LUA_REGISTRYINDEX);
  packer.ext = LUA_NOREF;
  packer.parser = &parser;
  mpack_parser_init(packer.parser, 0);
  packer.parser->data.p = &packer;
  packer.is_bin = 0;
  packer.L = L;
  packer.root = lmpack_ref(L, packer.reg);

  lua_getfield(L, LUA_REGISTRYINDEX, EMPTY_DICT_NAME);
  packer.mtdict = lmpack_ref(L, packer.reg);


  luaL_buffinit(L, &buffer);
  b = luaL_prepbuffer(&buffer);
  bl = LUAL_BUFFERSIZE;

  do {
    size_t bl_init = bl;
    result = mpack_unparse(packer.parser, &b, &bl, lmpack_unparse_enter,
        lmpack_unparse_exit);

    if (result == MPACK_NOMEM) {
      lmpack_unref(L, packer.reg, packer.root);
      luaL_unref(L, LUA_REGISTRYINDEX, packer.reg);
      return luaL_error(L, "object was too deep to pack");
    }

    luaL_addsize(&buffer, bl_init - bl);

    if (!bl) {
      /* buffer empty, resize */
      b = luaL_prepbuffer(&buffer);
      bl = LUAL_BUFFERSIZE;
    }
  } while (result == MPACK_EOF);

  lmpack_unref(L, packer.reg, packer.root);
  luaL_unref(L, LUA_REGISTRYINDEX, packer.reg);
  luaL_pushresult(&buffer);
  return 1;
}

static const luaL_reg unpacker_methods[] = {
  {"__call", lmpack_unpacker_unpack},
  {"__gc", lmpack_unpacker_delete},
  {NULL, NULL}
};

static const luaL_reg packer_methods[] = {
  {"__call", lmpack_packer_pack},
  {"__gc", lmpack_packer_delete},
  {NULL, NULL}
};

static const luaL_reg session_methods[] = {
  {"receive", lmpack_session_receive},
  {"request", lmpack_session_request},
  {"reply", lmpack_session_reply},
  {"notify", lmpack_session_notify},
  {"__gc", lmpack_session_delete},
  {NULL, NULL}
};

static const luaL_reg mpack_functions[] = {
  {"Unpacker", lmpack_unpacker_new},
  {"Packer", lmpack_packer_new},
  {"Session", lmpack_session_new},
  {UNPACK_FN_NAME, lmpack_unpack},
  {PACK_FN_NAME, lmpack_pack},
  {NULL, NULL}
};

int luaopen_mpack(lua_State *L)
{
  /* Unpacker */
  luaL_newmetatable(L, UNPACKER_META_NAME);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
  luaL_register(L, NULL, unpacker_methods);
  lua_pop(L, 1);
  /* Packer */
  luaL_newmetatable(L, PACKER_META_NAME);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
  luaL_register(L, NULL, packer_methods);
  lua_pop(L, 1);
  /* Session */
  luaL_newmetatable(L, SESSION_META_NAME);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, "__index");
  luaL_register(L, NULL, session_methods);
  lua_pop(L, 1);
  /* NIL */
  /* Check if NIL is already stored in the registry */
  lua_getfield(L, LUA_REGISTRYINDEX, NIL_NAME);
  /* If it isn't, create it */
  if (lua_isnil(L, -1)) {
    /* Use a constant userdata to represent NIL */
    (void)lua_newuserdata(L, sizeof(void *));
    /* Create a metatable for NIL userdata */
    lua_createtable(L, 0, 1);
    lua_pushstring(L, "__tostring");
    lua_pushcfunction(L, lmpack_nil_tostring);
    lua_settable(L, -3);
    /* Assign the metatable to the userdata object */
    lua_setmetatable(L, -2);
    /* Save NIL on the registry so we can access it easily from other functions */
    lua_setfield(L, LUA_REGISTRYINDEX, NIL_NAME);
  }

  lua_pop(L, 1);

  /* module */
  lua_newtable(L);
  luaL_register(L, NULL, mpack_functions);
  /* save NIL on the module */
  lua_getfield(L, LUA_REGISTRYINDEX, NIL_NAME);
  lua_setfield(L, -2, "NIL");
  return 1;
}
