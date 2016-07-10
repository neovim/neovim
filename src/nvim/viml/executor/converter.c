#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <assert.h>
#include <stdint.h>
#include <stdbool.h>

#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/func_attr.h"
#include "nvim/memory.h"
#include "nvim/assert.h"
// FIXME: vim.h is not actually needed, but otherwise it states MAXPATHL is
//        redefined
#include "nvim/vim.h"
#include "nvim/globals.h"
#include "nvim/message.h"
#include "nvim/eval_defs.h"
#include "nvim/ascii.h"

#include "nvim/lib/kvec.h"
#include "nvim/eval/decode.h"

#include "nvim/viml/executor/converter.h"
#include "nvim/viml/executor/executor.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/executor/converter.c.generated.h"
#endif

/// Helper structure for nlua_pop_typval
typedef struct {
  typval_T *tv;  ///< Location where conversion result is saved.
  bool container;  ///< True if tv is a container.
  bool special;  ///< If true then tv is a _VAL part of special dictionary
                 ///< that represents mapping.
} PopStackItem;

/// Convert lua object to VimL typval_T
///
/// Should pop exactly one value from lua stack.
///
/// @param  lstate  Lua state.
/// @param[out]  ret_tv Where to put the result.
///
/// @return `true` in case of success, `false` in case of failure. Error is
///         reported automatically.
bool nlua_pop_typval(lua_State *lstate, typval_T *ret_tv)
{
  bool ret = true;
#ifndef NDEBUG
  const int initial_size = lua_gettop(lstate);
#endif
  kvec_t(PopStackItem) stack = KV_INITIAL_VALUE;
  kv_push(stack, ((PopStackItem) { ret_tv, false, false }));
  while (ret && kv_size(stack)) {
    if (!lua_checkstack(lstate, lua_gettop(lstate) + 3)) {
      emsgf(_("E1502: Lua failed to grow stack to %i"), lua_gettop(lstate) + 3);
      ret = false;
      break;
    }
    PopStackItem cur = kv_pop(stack);
    if (cur.container) {
      if (cur.special || cur.tv->v_type == VAR_DICT) {
        assert(cur.tv->v_type == (cur.special ? VAR_LIST : VAR_DICT));
        if (lua_next(lstate, -2)) {
          assert(lua_type(lstate, -2) == LUA_TSTRING);
          size_t len;
          const char *s = lua_tolstring(lstate, -2, &len);
          if (cur.special) {
            list_T *const kv_pair = list_alloc();
            list_append_list(cur.tv->vval.v_list, kv_pair);
            listitem_T *const key = listitem_alloc();
            key->li_tv = decode_string(s, len, kTrue, false);
            list_append(kv_pair, key);
            if (key->li_tv.v_type == VAR_UNKNOWN) {
              ret = false;
              list_unref(kv_pair);
              continue;
            }
            listitem_T *const  val = listitem_alloc();
            list_append(kv_pair, val);
            kv_push(stack, cur);
            cur = (PopStackItem) { &val->li_tv, false, false };
          } else {
            dictitem_T *const di = dictitem_alloc_len(s, len);
            if (dict_add(cur.tv->vval.v_dict, di) == FAIL) {
              assert(false);
            }
            kv_push(stack, cur);
            cur = (PopStackItem) { &di->di_tv, false, false };
          }
        } else {
          lua_pop(lstate, 1);
          continue;
        }
      } else {
        assert(cur.tv->v_type == VAR_LIST);
        lua_rawgeti(lstate, -1, cur.tv->vval.v_list->lv_len + 1);
        if (lua_isnil(lstate, -1)) {
          lua_pop(lstate, 1);
          lua_pop(lstate, 1);
          continue;
        }
        listitem_T *li = listitem_alloc();
        list_append(cur.tv->vval.v_list, li);
        kv_push(stack, cur);
        cur = (PopStackItem) { &li->li_tv, false, false };
      }
    }
    assert(!cur.container);
    memset(cur.tv, 0, sizeof(*cur.tv));
    switch (lua_type(lstate, -1)) {
      case LUA_TNIL: {
        cur.tv->v_type = VAR_SPECIAL;
        cur.tv->vval.v_special = kSpecialVarNull;
        break;
      }
      case LUA_TBOOLEAN: {
        cur.tv->v_type = VAR_SPECIAL;
        cur.tv->vval.v_special = (lua_toboolean(lstate, -1)
                                  ? kSpecialVarTrue
                                  : kSpecialVarFalse);
        break;
      }
      case LUA_TSTRING: {
        size_t len;
        const char *s = lua_tolstring(lstate, -1, &len);
        *cur.tv = decode_string(s, len, kNone, true);
        if (cur.tv->v_type == VAR_UNKNOWN) {
          ret = false;
        }
        break;
      }
      case LUA_TNUMBER: {
        const lua_Number n = lua_tonumber(lstate, -1);
        if (n > (lua_Number)VARNUMBER_MAX || n < (lua_Number)VARNUMBER_MIN
            || ((lua_Number)((varnumber_T)n)) != n) {
          cur.tv->v_type = VAR_FLOAT;
          cur.tv->vval.v_float = (float_T)n;
        } else {
          cur.tv->v_type = VAR_NUMBER;
          cur.tv->vval.v_number = (varnumber_T)n;
        }
        break;
      }
      case LUA_TTABLE: {
        bool has_string = false;
        bool has_string_with_nul = false;
        bool has_other = false;
        size_t maxidx = 0;
        size_t tsize = 0;
        lua_pushnil(lstate);
        while (lua_next(lstate, -2)) {
          switch (lua_type(lstate, -2)) {
            case LUA_TSTRING: {
              size_t len;
              const char *s = lua_tolstring(lstate, -2, &len);
              if (memchr(s, NUL, len) != NULL) {
                has_string_with_nul = true;
              }
              has_string = true;
              break;
            }
            case LUA_TNUMBER: {
              const lua_Number n = lua_tonumber(lstate, -2);
              if (n > (lua_Number)SIZE_MAX || n <= 0
                  || ((lua_Number)((size_t)n)) != n) {
                has_other = true;
              } else {
                const size_t idx = (size_t)n;
                if (idx > maxidx) {
                  maxidx = idx;
                }
              }
              break;
            }
            default: {
              has_other = true;
              break;
            }
          }
          tsize++;
          lua_pop(lstate, 1);
        }

        if (tsize == 0) {
          // Assuming empty list
          cur.tv->v_type = VAR_LIST;
          cur.tv->vval.v_list = list_alloc();
          cur.tv->vval.v_list->lv_refcount++;
        } else if (tsize == maxidx && !has_other && !has_string) {
          // Assuming array
          cur.tv->v_type = VAR_LIST;
          cur.tv->vval.v_list = list_alloc();
          cur.tv->vval.v_list->lv_refcount++;
          cur.container = true;
          kv_push(stack, cur);
        } else if (has_string && !has_other && maxidx == 0) {
          // Assuming dictionary
          cur.special = has_string_with_nul;
          if (has_string_with_nul) {
            decode_create_map_special_dict(cur.tv);
            assert(cur.tv->v_type = VAR_DICT);
            dictitem_T *const val_di = dict_find(cur.tv->vval.v_dict,
                                                 (char_u *)"_VAL", 4);
            assert(val_di != NULL);
            cur.tv = &val_di->di_tv;
            assert(cur.tv->v_type == VAR_LIST);
          } else {
            cur.tv->v_type = VAR_DICT;
            cur.tv->vval.v_dict = dict_alloc();
            cur.tv->vval.v_dict->dv_refcount++;
          }
          cur.container = true;
          kv_push(stack, cur);
          lua_pushnil(lstate);
        } else {
          EMSG(_("E5100: Cannot convert given lua table: table "
                 "should either have a sequence of positive integer keys "
                 "or contain only string keys"));
          ret = false;
        }
        break;
      }
      default: {
        EMSG(_("E5101: Cannot convert given lua type"));
        ret = false;
        break;
      }
    }
    if (!cur.container) {
      lua_pop(lstate, 1);
    }
  }
  kv_destroy(stack);
  if (!ret) {
    clear_tv(ret_tv);
    memset(ret_tv, 0, sizeof(*ret_tv));
    lua_pop(lstate, lua_gettop(lstate) - initial_size + 1);
  }
  assert(lua_gettop(lstate) == initial_size - 1);
  return ret;
}

#define TYPVAL_ENCODE_ALLOW_SPECIALS true

#define TYPVAL_ENCODE_CONV_NIL(tv) \
    lua_pushnil(lstate)

#define TYPVAL_ENCODE_CONV_BOOL(tv, num) \
    lua_pushboolean(lstate, (bool)(num))

#define TYPVAL_ENCODE_CONV_NUMBER(tv, num) \
    lua_pushnumber(lstate, (lua_Number)(num))

#define TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER TYPVAL_ENCODE_CONV_NUMBER

#define TYPVAL_ENCODE_CONV_FLOAT(tv, flt) \
    TYPVAL_ENCODE_CONV_NUMBER(tv, flt)

#define TYPVAL_ENCODE_CONV_STRING(tv, str, len) \
    lua_pushlstring(lstate, (const char *)(str), (len))

#define TYPVAL_ENCODE_CONV_STR_STRING TYPVAL_ENCODE_CONV_STRING

#define TYPVAL_ENCODE_CONV_EXT_STRING(tv, str, len, type) \
    TYPVAL_ENCODE_CONV_NIL()

#define TYPVAL_ENCODE_CONV_FUNC_START(tv, fun) \
    do { \
      TYPVAL_ENCODE_CONV_NIL(tv); \
      goto typval_encode_stop_converting_one_item; \
    } while (0)

#define TYPVAL_ENCODE_CONV_FUNC_BEFORE_ARGS(tv, len)
#define TYPVAL_ENCODE_CONV_FUNC_BEFORE_SELF(tv, len)
#define TYPVAL_ENCODE_CONV_FUNC_END(tv)

#define TYPVAL_ENCODE_CONV_EMPTY_LIST(tv) \
    lua_createtable(lstate, 0, 0)

#define TYPVAL_ENCODE_CONV_EMPTY_DICT(tv, dict) \
    TYPVAL_ENCODE_CONV_EMPTY_LIST()

#define TYPVAL_ENCODE_CONV_LIST_START(tv, len) \
    do { \
      if (!lua_checkstack(lstate, lua_gettop(lstate) + 3)) { \
        emsgf(_("E5102: Lua failed to grow stack to %i"), \
              lua_gettop(lstate) + 3); \
        return false; \
      } \
      lua_createtable(lstate, (int)(len), 0); \
      lua_pushnumber(lstate, 1); \
    } while (0)

#define TYPVAL_ENCODE_CONV_REAL_LIST_AFTER_START(tv, mpsv)

#define TYPVAL_ENCODE_CONV_LIST_BETWEEN_ITEMS(tv) \
    do { \
      lua_Number idx = lua_tonumber(lstate, -2); \
      lua_rawset(lstate, -3); \
      lua_pushnumber(lstate, idx + 1); \
    } while (0)

#define TYPVAL_ENCODE_CONV_LIST_END(tv) \
    lua_rawset(lstate, -3)

#define TYPVAL_ENCODE_CONV_DICT_START(tv, dict, len) \
    do { \
      if (!lua_checkstack(lstate, lua_gettop(lstate) + 3)) { \
        emsgf(_("E5102: Lua failed to grow stack to %i"), \
              lua_gettop(lstate) + 3); \
        return false; \
      } \
      lua_createtable(lstate, 0, (int)(len)); \
    } while (0)

#define TYPVAL_ENCODE_SPECIAL_DICT_KEY_CHECK(label, kv_pair)

#define TYPVAL_ENCODE_CONV_REAL_DICT_AFTER_START(tv, dict, mpsv)

#define TYPVAL_ENCODE_CONV_DICT_AFTER_KEY(tv, dict)

#define TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS(tv, dict) \
    lua_rawset(lstate, -3)

#define TYPVAL_ENCODE_CONV_DICT_END(tv, dict) \
    TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS(tv, dict)

#define TYPVAL_ENCODE_CONV_RECURSE(val, conv_type) \
    do { \
      for (size_t backref = kv_size(*mpstack); backref; backref--) { \
        const MPConvStackVal mpval = kv_A(*mpstack, backref - 1); \
        if (mpval.type == conv_type) { \
          if (conv_type == kMPConvDict \
              ? (void *) mpval.data.d.dict == (void *) (val) \
              : (void *) mpval.data.l.list == (void *) (val)) { \
            lua_pushvalue(lstate, \
                          1 - ((int)((kv_size(*mpstack) - backref + 1) * 2))); \
            break; \
          } \
        } \
      } \
    } while (0)

#define TYPVAL_ENCODE_SCOPE static
#define TYPVAL_ENCODE_NAME lua
#define TYPVAL_ENCODE_FIRST_ARG_TYPE lua_State *const
#define TYPVAL_ENCODE_FIRST_ARG_NAME lstate
#include "nvim/eval/typval_encode.c.h"
#undef TYPVAL_ENCODE_SCOPE
#undef TYPVAL_ENCODE_NAME
#undef TYPVAL_ENCODE_FIRST_ARG_TYPE
#undef TYPVAL_ENCODE_FIRST_ARG_NAME

#undef TYPVAL_ENCODE_CONV_STRING
#undef TYPVAL_ENCODE_CONV_STR_STRING
#undef TYPVAL_ENCODE_CONV_EXT_STRING
#undef TYPVAL_ENCODE_CONV_NUMBER
#undef TYPVAL_ENCODE_CONV_FLOAT
#undef TYPVAL_ENCODE_CONV_FUNC_START
#undef TYPVAL_ENCODE_CONV_FUNC_BEFORE_ARGS
#undef TYPVAL_ENCODE_CONV_FUNC_BEFORE_SELF
#undef TYPVAL_ENCODE_CONV_FUNC_END
#undef TYPVAL_ENCODE_CONV_EMPTY_LIST
#undef TYPVAL_ENCODE_CONV_LIST_START
#undef TYPVAL_ENCODE_CONV_REAL_LIST_AFTER_START
#undef TYPVAL_ENCODE_CONV_EMPTY_DICT
#undef TYPVAL_ENCODE_CONV_NIL
#undef TYPVAL_ENCODE_CONV_BOOL
#undef TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER
#undef TYPVAL_ENCODE_CONV_DICT_START
#undef TYPVAL_ENCODE_CONV_REAL_DICT_AFTER_START
#undef TYPVAL_ENCODE_CONV_DICT_END
#undef TYPVAL_ENCODE_CONV_DICT_AFTER_KEY
#undef TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS
#undef TYPVAL_ENCODE_SPECIAL_DICT_KEY_CHECK
#undef TYPVAL_ENCODE_CONV_LIST_END
#undef TYPVAL_ENCODE_CONV_LIST_BETWEEN_ITEMS
#undef TYPVAL_ENCODE_CONV_RECURSE
#undef TYPVAL_ENCODE_ALLOW_SPECIALS

/// Convert VimL typval_T to lua value
///
/// Should leave single value in lua stack. May only fail if lua failed to grow
/// stack.
///
/// @param  lstate  Lua interpreter state.
/// @param[in]  tv  typval_T to convert.
///
/// @return true in case of success, false otherwise.
bool nlua_push_typval(lua_State *lstate, typval_T *const tv)
{
  const int initial_size = lua_gettop(lstate);
  if (!lua_checkstack(lstate, initial_size + 1)) {
    emsgf(_("E1502: Lua failed to grow stack to %i"), initial_size + 4);
    return false;
  }
  if (encode_vim_to_lua(lstate, tv, "nlua_push_typval argument") == FAIL) {
    return false;
  }
  assert(lua_gettop(lstate) == initial_size + 1);
  return true;
}

#define NLUA_PUSH_IDX(lstate, type, idx) \
  do { \
    STATIC_ASSERT(sizeof(type) <= sizeof(lua_Number), \
                  "Number sizes do not match"); \
    const type src = idx; \
    lua_Number tgt; \
    memset(&tgt, 0, sizeof(tgt)); \
    memcpy(&tgt, &src, sizeof(src)); \
    lua_pushnumber(lstate, tgt); \
  } while (0)

#define NLUA_POP_IDX(lstate, type, stack_idx, idx) \
  do { \
    STATIC_ASSERT(sizeof(type) <= sizeof(lua_Number), \
                  "Number sizes do not match"); \
    const lua_Number src = lua_tonumber(lstate, stack_idx); \
    type tgt; \
    memcpy(&tgt, &src, sizeof(tgt)); \
    idx = tgt; \
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
    ADD_TYPE(Array,        array)
    ADD_TYPE(Dictionary,   dictionary)
#undef ADD_TYPE
#define ADD_REMOTE_TYPE(type) \
    case kObjectType##type: { \
      nlua_push_##type(lstate, (type)obj.data.integer); \
      break; \
    }
    ADD_REMOTE_TYPE(Buffer)
    ADD_REMOTE_TYPE(Window)
    ADD_REMOTE_TYPE(Tabpage)
#undef ADD_REMOTE_TYPE
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
