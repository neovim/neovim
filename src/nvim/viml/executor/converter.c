#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <assert.h>

#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/func_attr.h"
#include "nvim/memory.h"
#include "nvim/assert.h"

#include "nvim/viml/executor/converter.h"
#include "nvim/viml/executor/executor.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/executor/converter.c.generated.h"
#endif

#define NLUA_PUSH_IDX(lstate, type, idx) \
  do { \
    STATIC_ASSERT(sizeof(type) == sizeof(lua_Number), \
                  "Number sizes do not match"); \
    union { \
      type src; \
      lua_Number tgt; \
    } tmp; \
    tmp.src = idx; \
    lua_pushnumber(lstate, tmp.tgt); \
  } while (0)

#define NLUA_POP_IDX(lstate, type, stack_idx, idx) \
  do { \
    STATIC_ASSERT(sizeof(type) == sizeof(lua_Number), \
                  "Number sizes do not match"); \
    union { \
      type tgt; \
      lua_Number src; \
    } tmp; \
    tmp.src = lua_tonumber(lstate, stack_idx); \
    idx = tmp.tgt; \
  } while (0)

/// Push value which is a type index
///
/// Used for all “typed” tables: i.e. for all tables which represent VimL
/// values.
static inline void nlua_push_type_idx(lua_State *lstate)
  FUNC_ATTR_NONNULL_ALL
{
  lua_pushboolean(lstate, true);
}

/// Push value which is a locks index
///
/// Used for containers tables.
static inline void nlua_push_locks_idx(lua_State *lstate)
  FUNC_ATTR_NONNULL_ALL
{
  lua_pushboolean(lstate, false);
}

/// Push value which is a value index
///
/// Used for tables which represent scalar values, like float value.
static inline void nlua_push_val_idx(lua_State *lstate)
  FUNC_ATTR_NONNULL_ALL
{
  lua_pushnumber(lstate, (lua_Number) 0);
}

/// Push type
///
/// Type is a value in vim.types table.
///
/// @param[out]  lstate  Lua state.
/// @param[in]   type    Type to push (key in vim.types table).
static inline void nlua_push_type(lua_State *lstate, const char *const type)
{
  lua_getglobal(lstate, "vim");
  lua_getfield(lstate, -1, "types");
  lua_remove(lstate, -2);
  lua_getfield(lstate, -1, type);
  lua_remove(lstate, -2);
}

/// Create lua table which has an entry that determines its VimL type
///
/// @param[out]  lstate  Lua state.
/// @param[in]   narr    Number of “array” entries to be populated later.
/// @param[in]   nrec    Number of “dictionary” entries to be populated later.
/// @param[in]   type    Type of the table.
static inline void nlua_create_typed_table(lua_State *lstate,
                                           const size_t narr,
                                           const size_t nrec,
                                           const char *const type)
  FUNC_ATTR_NONNULL_ALL
{
  lua_createtable(lstate, (int) narr, (int) (1 + nrec));
  nlua_push_type_idx(lstate);
  nlua_push_type(lstate, type);
  lua_rawset(lstate, -3);
}


/// Convert given String to lua string
///
/// Leaves converted string on top of the stack.
void nlua_push_String(lua_State *lstate, const String s)
  FUNC_ATTR_NONNULL_ALL
{
  lua_pushlstring(lstate, s.data, s.size);
}

/// Convert given Integer to lua number
///
/// Leaves converted number on top of the stack.
void nlua_push_Integer(lua_State *lstate, const Integer n)
  FUNC_ATTR_NONNULL_ALL
{
  lua_pushnumber(lstate, (lua_Number) n);
}

/// Convert given Float to lua table
///
/// Leaves converted table on top of the stack.
void nlua_push_Float(lua_State *lstate, const Float f)
  FUNC_ATTR_NONNULL_ALL
{
  nlua_create_typed_table(lstate, 0, 1, "float");
  nlua_push_val_idx(lstate);
  lua_pushnumber(lstate, (lua_Number) f);
  lua_rawset(lstate, -3);
}

/// Convert given Float to lua boolean
///
/// Leaves converted value on top of the stack.
void nlua_push_Boolean(lua_State *lstate, const Boolean b)
  FUNC_ATTR_NONNULL_ALL
{
  lua_pushboolean(lstate, b);
}

static inline void nlua_add_locks_table(lua_State *lstate)
{
  nlua_push_locks_idx(lstate);
  lua_newtable(lstate);
  lua_rawset(lstate, -3);
}

/// Convert given Dictionary to lua table
///
/// Leaves converted table on top of the stack.
void nlua_push_Dictionary(lua_State *lstate, const Dictionary dict)
  FUNC_ATTR_NONNULL_ALL
{
  nlua_create_typed_table(lstate, 0, 1 + dict.size, "dict");
  nlua_add_locks_table(lstate);
  for (size_t i = 0; i < dict.size; i++) {
    nlua_push_String(lstate, dict.items[i].key);
    nlua_push_Object(lstate, dict.items[i].value);
    lua_rawset(lstate, -3);
  }
}

/// Convert given Array to lua table
///
/// Leaves converted table on top of the stack.
void nlua_push_Array(lua_State *lstate, const Array array)
  FUNC_ATTR_NONNULL_ALL
{
  nlua_create_typed_table(lstate, array.size, 1, "float");
  nlua_add_locks_table(lstate);
  for (size_t i = 0; i < array.size; i++) {
    nlua_push_Object(lstate, array.items[i]);
    lua_rawseti(lstate, -3, (int) i + 1);
  }
}

#define GENERATE_INDEX_FUNCTION(type) \
void nlua_push_##type(lua_State *lstate, const type item) \
  FUNC_ATTR_NONNULL_ALL \
{ \
  NLUA_PUSH_IDX(lstate, type, item); \
}

GENERATE_INDEX_FUNCTION(Buffer)
GENERATE_INDEX_FUNCTION(Window)
GENERATE_INDEX_FUNCTION(Tabpage)

#undef GENERATE_INDEX_FUNCTION

/// Convert given Object to lua value
///
/// Leaves converted value on top of the stack.
void nlua_push_Object(lua_State *lstate, const Object obj)
  FUNC_ATTR_NONNULL_ALL
{
  switch (obj.type) {
    case kObjectTypeNil: {
      lua_pushnil(lstate);
      break;
    }
#define ADD_TYPE(type, data_key) \
    case kObjectType##type: { \
      nlua_push_##type(lstate, obj.data.data_key); \
      break; \
    }
    ADD_TYPE(Boolean,      boolean)
    ADD_TYPE(Integer,      integer)
    ADD_TYPE(Float,        floating)
    ADD_TYPE(String,       string)
    ADD_TYPE(Buffer,       buffer)
    ADD_TYPE(Window,       window)
    ADD_TYPE(Tabpage,      tabpage)
    ADD_TYPE(Array,        array)
    ADD_TYPE(Dictionary,   dictionary)
#undef ADD_TYPE
  }
}


/// Convert lua value to string
///
/// Always pops one value from the stack.
String nlua_pop_String(lua_State *lstate, Error *err)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  String ret;

  ret.data = (char *) lua_tolstring(lstate, -1, &(ret.size));

  if (ret.data == NULL) {
    lua_pop(lstate, 1);
    set_api_error("Expected lua string", err);
    return (String) { .size = 0, .data = NULL };
  }

  ret.data = xmemdupz(ret.data, ret.size);
  lua_pop(lstate, 1);

  return ret;
}

/// Convert lua value to integer
///
/// Always pops one value from the stack.
Integer nlua_pop_Integer(lua_State *lstate, Error *err)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  Integer ret = 0;

  if (!lua_isnumber(lstate, -1)) {
    lua_pop(lstate, 1);
    set_api_error("Expected lua integer", err);
    return ret;
  }
  ret = (Integer) lua_tonumber(lstate, -1);
  lua_pop(lstate, 1);

  return ret;
}

/// Convert lua value to boolean
///
/// Always pops one value from the stack.
Boolean nlua_pop_Boolean(lua_State *lstate, Error *err)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  Boolean ret = lua_toboolean(lstate, -1);
  lua_pop(lstate, 1);
  return ret;
}

static inline bool nlua_check_type(lua_State *lstate, Error *err,
                                   const char *const type)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (lua_type(lstate, -1) != LUA_TTABLE) {
    set_api_error("Expected lua table", err);
    return true;
  }

  nlua_push_type_idx(lstate);
  lua_rawget(lstate, -2);
  nlua_push_type(lstate, type);
  if (!lua_rawequal(lstate, -2, -1)) {
    lua_pop(lstate, 2);
    set_api_error("Expected lua table with float type", err);
    return true;
  }
  lua_pop(lstate, 2);

  return false;
}

/// Convert lua table to float
///
/// Always pops one value from the stack.
Float nlua_pop_Float(lua_State *lstate, Error *err)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  Float ret = 0;

  if (nlua_check_type(lstate, err, "float")) {
    lua_pop(lstate, 1);
    return 0;
  }

  nlua_push_val_idx(lstate);
  lua_rawget(lstate, -2);

  if (!lua_isnumber(lstate, -1)) {
    lua_pop(lstate, 2);
    set_api_error("Value field should be lua number", err);
    return ret;
  }
  ret = lua_tonumber(lstate, -1);
  lua_pop(lstate, 2);

  return ret;
}

/// Convert lua table to array
///
/// Always pops one value from the stack.
Array nlua_pop_Array(lua_State *lstate, Error *err)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  Array ret = { .size = 0, .items = NULL };

  if (nlua_check_type(lstate, err, "list")) {
    lua_pop(lstate, 1);
    return ret;
  }

  for (int i = 1; ; i++, ret.size++) {
    lua_rawgeti(lstate, -1, i);

    if (lua_isnil(lstate, -1)) {
      lua_pop(lstate, 1);
      break;
    }
    lua_pop(lstate, 1);
  }

  if (ret.size == 0) {
    lua_pop(lstate, 1);
    return ret;
  }

  ret.items = xcalloc(ret.size, sizeof(*ret.items));
  for (size_t i = 1; i <= ret.size; i++) {
    Object val;

    lua_rawgeti(lstate, -1, (int) i);

    val = nlua_pop_Object(lstate, err);
    if (err->set) {
      ret.size = i;
      lua_pop(lstate, 1);
      api_free_array(ret);
      return (Array) { .size = 0, .items = NULL };
    }
    ret.items[i - 1] = val;
  }
  lua_pop(lstate, 1);

  return ret;
}

/// Convert lua table to dictionary
///
/// Always pops one value from the stack. Does not check whether
/// `vim.is_dict(table[type_idx])` or whether topmost value on the stack is
/// a table.
Dictionary nlua_pop_Dictionary_unchecked(lua_State *lstate, Error *err)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  Dictionary ret = { .size = 0, .items = NULL };

  lua_pushnil(lstate);

  while (lua_next(lstate, -2)) {
    if (lua_type(lstate, -2) == LUA_TSTRING) {
      ret.size++;
    }
    lua_pop(lstate, 1);
  }

  if (ret.size == 0) {
    lua_pop(lstate, 1);
    return ret;
  }
  ret.items = xcalloc(ret.size, sizeof(*ret.items));

  lua_pushnil(lstate);
  for (size_t i = 0; lua_next(lstate, -2);) {
    // stack: dict, key, value

    if (lua_type(lstate, -2) == LUA_TSTRING) {
      lua_pushvalue(lstate, -2);
      // stack: dict, key, value, key

      ret.items[i].key = nlua_pop_String(lstate, err);
      // stack: dict, key, value

      if (!err->set) {
        ret.items[i].value = nlua_pop_Object(lstate, err);
        // stack: dict, key
      } else {
        lua_pop(lstate, 1);
        // stack: dict, key
      }

      if (err->set) {
        ret.size = i;
        api_free_dictionary(ret);
        lua_pop(lstate, 2);
        // stack:
        return (Dictionary) { .size = 0, .items = NULL };
      }
      i++;
    } else {
      lua_pop(lstate, 1);
      // stack: dict, key
    }
  }
  lua_pop(lstate, 1);

  return ret;
}

/// Convert lua table to dictionary
///
/// Always pops one value from the stack.
Dictionary nlua_pop_Dictionary(lua_State *lstate, Error *err)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (nlua_check_type(lstate, err, "dict")) {
    lua_pop(lstate, 1);
    return (Dictionary) { .size = 0, .items = NULL };
  }

  return nlua_pop_Dictionary_unchecked(lstate, err);
}

/// Convert lua table to object
///
/// Always pops one value from the stack.
Object nlua_pop_Object(lua_State *lstate, Error *err)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  Object ret = { .type = kObjectTypeNil };

  switch (lua_type(lstate, -1)) {
    case LUA_TNIL: {
      ret.type = kObjectTypeNil;
      lua_pop(lstate, 1);
      break;
    }
    case LUA_TSTRING: {
      ret.type = kObjectTypeString;
      ret.data.string = nlua_pop_String(lstate, err);
      break;
    }
    case LUA_TNUMBER: {
      ret.type = kObjectTypeInteger;
      ret.data.integer = nlua_pop_Integer(lstate, err);
      break;
    }
    case LUA_TBOOLEAN: {
      ret.type = kObjectTypeBoolean;
      ret.data.boolean = nlua_pop_Boolean(lstate, err);
      break;
    }
    case LUA_TTABLE: {
      lua_getglobal(lstate, "vim");
      // stack: obj, vim
#define CHECK_TYPE(Type, key, vim_type) \
      lua_getfield(lstate, -1, "is_" #vim_type); \
      /* stack: obj, vim, checker */ \
      lua_pushvalue(lstate, -3); \
      /* stack: obj, vim, checker, obj */ \
      lua_call(lstate, 1, 1); \
      /* stack: obj, vim, result */ \
      if (lua_toboolean(lstate, -1)) { \
        lua_pop(lstate, 2); \
        /* stack: obj */ \
        ret.type = kObjectType##Type; \
        ret.data.key = nlua_pop_##Type(lstate, err); \
        /* stack: */ \
        break; \
      } \
      lua_pop(lstate, 1); \
      // stack: obj, vim
      CHECK_TYPE(Float, floating, float)
      CHECK_TYPE(Array, array, list)
      CHECK_TYPE(Dictionary, dictionary, dict)
#undef CHECK_TYPE
      lua_pop(lstate, 1);
      // stack: obj
      ret.type = kObjectTypeDictionary;
      ret.data.dictionary = nlua_pop_Dictionary_unchecked(lstate, err);
      break;
    }
    default: {
      lua_pop(lstate, 1);
      set_api_error("Cannot convert given lua type", err);
      break;
    }
  }
  if (err->set) {
    ret.type = kObjectTypeNil;
  }

  return ret;
}

#define GENERATE_INDEX_FUNCTION(type) \
type nlua_pop_##type(lua_State *lstate, Error *err) \
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT \
{ \
  type ret; \
  NLUA_POP_IDX(lstate, type, -1, ret); \
  lua_pop(lstate, 1); \
  return ret; \
}

GENERATE_INDEX_FUNCTION(Buffer)
GENERATE_INDEX_FUNCTION(Window)
GENERATE_INDEX_FUNCTION(Tabpage)

#undef GENERATE_INDEX_FUNCTION
