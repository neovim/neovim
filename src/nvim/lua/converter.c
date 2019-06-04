// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

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
#include "nvim/eval/typval.h"
#include "nvim/ascii.h"
#include "nvim/macros.h"

#include "nvim/lib/kvec.h"
#include "nvim/eval/decode.h"

#include "nvim/lua/converter.h"
#include "nvim/lua/executor.h"

/// Determine, which keys lua table contains
typedef struct {
  size_t maxidx;  ///< Maximum positive integral value found.
  size_t string_keys_num;  ///< Number of string keys.
  bool has_string_with_nul;  ///< True if there is string key with NUL byte.
  ObjectType type;  ///< If has_type_key is true then attached value. Otherwise
                    ///< either kObjectTypeNil, kObjectTypeDictionary or
                    ///< kObjectTypeArray, depending on other properties.
  lua_Number val;  ///< If has_val_key and val_type == LUA_TNUMBER: value.
  bool has_type_key;  ///< True if type key is present.
} LuaTableProps;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua/converter.c.generated.h"
#endif

#define TYPE_IDX_VALUE true
#define VAL_IDX_VALUE false

#define LUA_PUSH_STATIC_STRING(lstate, s) \
    lua_pushlstring(lstate, s, sizeof(s) - 1)

static LuaTableProps nlua_traverse_table(lua_State *const lstate)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  size_t tsize = 0;  // Total number of keys.
  int val_type = 0;  // If has_val_key: lua type of the value.
  bool has_val_key = false;  // True if val key was found,
                             // @see nlua_push_val_idx().
  size_t other_keys_num = 0;  // Number of keys that are not string, integral
                              // or type keys.
  LuaTableProps ret;
  memset(&ret, 0, sizeof(ret));
  if (!lua_checkstack(lstate, lua_gettop(lstate) + 3)) {
    emsgf(_("E1502: Lua failed to grow stack to %i"), lua_gettop(lstate) + 2);
    ret.type = kObjectTypeNil;
    return ret;
  }
  lua_pushnil(lstate);
  while (lua_next(lstate, -2)) {
    switch (lua_type(lstate, -2)) {
      case LUA_TSTRING: {
        size_t len;
        const char *s = lua_tolstring(lstate, -2, &len);
        if (memchr(s, NUL, len) != NULL) {
          ret.has_string_with_nul = true;
        }
        ret.string_keys_num++;
        break;
      }
      case LUA_TNUMBER: {
        const lua_Number n = lua_tonumber(lstate, -2);
        if (n > (lua_Number)SIZE_MAX || n <= 0
            || ((lua_Number)((size_t)n)) != n) {
          other_keys_num++;
        } else {
          const size_t idx = (size_t)n;
          if (idx > ret.maxidx) {
            ret.maxidx = idx;
          }
        }
        break;
      }
      case LUA_TBOOLEAN: {
        const bool b = lua_toboolean(lstate, -2);
        if (b == TYPE_IDX_VALUE) {
          if (lua_type(lstate, -1) == LUA_TNUMBER) {
            lua_Number n = lua_tonumber(lstate, -1);
            if (n == (lua_Number)kObjectTypeFloat
                || n == (lua_Number)kObjectTypeArray
                || n == (lua_Number)kObjectTypeDictionary) {
              ret.has_type_key = true;
              ret.type = (ObjectType)n;
            } else {
              other_keys_num++;
            }
          } else {
            other_keys_num++;
          }
        } else {
          has_val_key = true;
          val_type = lua_type(lstate, -1);
          if (val_type == LUA_TNUMBER) {
            ret.val = lua_tonumber(lstate, -1);
          }
        }
        break;
      }
      default: {
        other_keys_num++;
        break;
      }
    }
    tsize++;
    lua_pop(lstate, 1);
  }
  if (ret.has_type_key) {
    if (ret.type == kObjectTypeFloat
        && (!has_val_key || val_type != LUA_TNUMBER)) {
      ret.type = kObjectTypeNil;
    } else if (ret.type == kObjectTypeArray) {
      // Determine what is the last number in a *sequence* of keys.
      // This condition makes sure that Neovim will not crash when it gets table
      // {[vim.type_idx]=vim.types.array, [SIZE_MAX]=1}: without it maxidx will
      // be SIZE_MAX, with this condition it should be zero and [SIZE_MAX] key
      // should be ignored.
      if (ret.maxidx != 0
          && ret.maxidx != (tsize
                            - ret.has_type_key
                            - other_keys_num
                            - has_val_key
                            - ret.string_keys_num)) {
        for (ret.maxidx = 0;; ret.maxidx++) {
          lua_rawgeti(lstate, -1, (int)ret.maxidx + 1);
          if (lua_isnil(lstate, -1)) {
            lua_pop(lstate, 1);
            break;
          }
          lua_pop(lstate, 1);
        }
      }
    }
  } else {
    if (tsize == 0
        || (tsize == ret.maxidx
            && other_keys_num == 0
            && ret.string_keys_num == 0)) {
      ret.type = kObjectTypeArray;
    } else if (ret.string_keys_num == tsize) {
      ret.type = kObjectTypeDictionary;
    } else {
      ret.type = kObjectTypeNil;
    }
  }
  return ret;
}

/// Helper structure for nlua_pop_typval
typedef struct {
  typval_T *tv;  ///< Location where conversion result is saved.
  bool container;  ///< True if tv is a container.
  bool special;  ///< If true then tv is a _VAL part of special dictionary
                 ///< that represents mapping.
  int idx;  ///< Container index (used to detect self-referencing structures).
} TVPopStackItem;

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
  const int initial_size = lua_gettop(lstate);
  kvec_t(TVPopStackItem) stack = KV_INITIAL_VALUE;
  kv_push(stack, ((TVPopStackItem) { ret_tv, false, false, 0 }));
  while (ret && kv_size(stack)) {
    if (!lua_checkstack(lstate, lua_gettop(lstate) + 3)) {
      emsgf(_("E1502: Lua failed to grow stack to %i"), lua_gettop(lstate) + 3);
      ret = false;
      break;
    }
    TVPopStackItem cur = kv_pop(stack);
    if (cur.container) {
      if (cur.special || cur.tv->v_type == VAR_DICT) {
        assert(cur.tv->v_type == (cur.special ? VAR_LIST : VAR_DICT));
        bool next_key_found = false;
        while (lua_next(lstate, -2)) {
          if (lua_type(lstate, -2) == LUA_TSTRING) {
            next_key_found = true;
            break;
          }
          lua_pop(lstate, 1);
        }
        if (next_key_found) {
          size_t len;
          const char *s = lua_tolstring(lstate, -2, &len);
          if (cur.special) {
            list_T *const kv_pair = tv_list_alloc(2);

            typval_T s_tv = decode_string(s, len, kTrue, false, false);
            if (s_tv.v_type == VAR_UNKNOWN) {
              ret = false;
              tv_list_unref(kv_pair);
              continue;
            }
            tv_list_append_owned_tv(kv_pair, s_tv);

            // Value: not populated yet, need to create list item to push.
            tv_list_append_owned_tv(kv_pair, (typval_T) {
              .v_type = VAR_UNKNOWN,
            });
            kv_push(stack, cur);
            tv_list_append_list(cur.tv->vval.v_list, kv_pair);
            cur = (TVPopStackItem) {
              .tv = TV_LIST_ITEM_TV(tv_list_last(kv_pair)),
              .container = false,
              .special = false,
              .idx = 0,
            };
          } else {
            dictitem_T *const di = tv_dict_item_alloc_len(s, len);
            if (tv_dict_add(cur.tv->vval.v_dict, di) == FAIL) {
              assert(false);
            }
            kv_push(stack, cur);
            cur = (TVPopStackItem) { &di->di_tv, false, false, 0 };
          }
        } else {
          lua_pop(lstate, 1);
          continue;
        }
      } else {
        assert(cur.tv->v_type == VAR_LIST);
        lua_rawgeti(lstate, -1, tv_list_len(cur.tv->vval.v_list) + 1);
        if (lua_isnil(lstate, -1)) {
          lua_pop(lstate, 2);
          continue;
        }
        // Not populated yet, need to create list item to push.
        tv_list_append_owned_tv(cur.tv->vval.v_list, (typval_T) {
          .v_type = VAR_UNKNOWN,
        });
        kv_push(stack, cur);
        // TODO(ZyX-I): Use indexes, here list item *will* be reallocated.
        cur = (TVPopStackItem) {
          .tv = TV_LIST_ITEM_TV(tv_list_last(cur.tv->vval.v_list)),
          .container = false,
          .special = false,
          .idx = 0,
        };
      }
    }
    assert(!cur.container);
    *cur.tv = (typval_T) {
      .v_type = VAR_NUMBER,
      .v_lock = VAR_UNLOCKED,
      .vval = { .v_number = 0 },
    };
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
        *cur.tv = decode_string(s, len, kNone, true, false);
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
        const LuaTableProps table_props = nlua_traverse_table(lstate);

        for (size_t i = 0; i < kv_size(stack); i++) {
          const TVPopStackItem item = kv_A(stack, i);
          if (item.container && lua_rawequal(lstate, -1, item.idx)) {
            tv_copy(item.tv, cur.tv);
            cur.container = false;
            goto nlua_pop_typval_table_processing_end;
          }
        }

        switch (table_props.type) {
          case kObjectTypeArray: {
            cur.tv->v_type = VAR_LIST;
            cur.tv->vval.v_list = tv_list_alloc((ptrdiff_t)table_props.maxidx);
            tv_list_ref(cur.tv->vval.v_list);
            if (table_props.maxidx != 0) {
              cur.container = true;
              cur.idx = lua_gettop(lstate);
              kv_push(stack, cur);
            }
            break;
          }
          case kObjectTypeDictionary: {
            if (table_props.string_keys_num == 0) {
              cur.tv->v_type = VAR_DICT;
              cur.tv->vval.v_dict = tv_dict_alloc();
              cur.tv->vval.v_dict->dv_refcount++;
            } else {
              cur.special = table_props.has_string_with_nul;
              if (table_props.has_string_with_nul) {
                decode_create_map_special_dict(
                    cur.tv, (ptrdiff_t)table_props.string_keys_num);
                assert(cur.tv->v_type == VAR_DICT);
                dictitem_T *const val_di = tv_dict_find(cur.tv->vval.v_dict,
                                                        S_LEN("_VAL"));
                assert(val_di != NULL);
                cur.tv = &val_di->di_tv;
                assert(cur.tv->v_type == VAR_LIST);
              } else {
                cur.tv->v_type = VAR_DICT;
                cur.tv->vval.v_dict = tv_dict_alloc();
                cur.tv->vval.v_dict->dv_refcount++;
              }
              cur.container = true;
              cur.idx = lua_gettop(lstate);
              kv_push(stack, cur);
              lua_pushnil(lstate);
            }
            break;
          }
          case kObjectTypeFloat: {
            cur.tv->v_type = VAR_FLOAT;
            cur.tv->vval.v_float = (float_T)table_props.val;
            break;
          }
          case kObjectTypeNil: {
            EMSG(_("E5100: Cannot convert given lua table: table "
                   "should either have a sequence of positive integer keys "
                   "or contain only string keys"));
            ret = false;
            break;
          }
          default: {
            assert(false);
          }
        }
nlua_pop_typval_table_processing_end:
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
    tv_clear(ret_tv);
    *ret_tv = (typval_T) {
      .v_type = VAR_NUMBER,
      .v_lock = VAR_UNLOCKED,
      .vval = { .v_number = 0 },
    };
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
    TYPVAL_ENCODE_CONV_NIL(tv)

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
    nlua_create_typed_table(lstate, 0, 0, kObjectTypeDictionary)

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
              ? (void *)mpval.data.d.dict == (void *)(val) \
              : (void *)mpval.data.l.list == (void *)(val)) { \
            lua_pushvalue(lstate, \
                          -((int)((kv_size(*mpstack) - backref + 1) * 2))); \
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
  if (!lua_checkstack(lstate, initial_size + 2)) {
    emsgf(_("E1502: Lua failed to grow stack to %i"), initial_size + 4);
    return false;
  }
  if (encode_vim_to_lua(lstate, tv, "nlua_push_typval argument") == FAIL) {
    return false;
  }
  assert(lua_gettop(lstate) == initial_size + 1);
  return true;
}

/// Push value which is a type index
///
/// Used for all “typed” tables: i.e. for all tables which represent VimL
/// values.
static inline void nlua_push_type_idx(lua_State *lstate)
  FUNC_ATTR_NONNULL_ALL
{
  lua_pushboolean(lstate, TYPE_IDX_VALUE);
}

/// Push value which is a value index
///
/// Used for tables which represent scalar values, like float value.
static inline void nlua_push_val_idx(lua_State *lstate)
  FUNC_ATTR_NONNULL_ALL
{
  lua_pushboolean(lstate, VAL_IDX_VALUE);
}

/// Push type
///
/// Type is a value in vim.types table.
///
/// @param[out]  lstate  Lua state.
/// @param[in]   type    Type to push.
static inline void nlua_push_type(lua_State *lstate, ObjectType type)
  FUNC_ATTR_NONNULL_ALL
{
  lua_pushnumber(lstate, (lua_Number)type);
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
                                           const ObjectType type)
  FUNC_ATTR_NONNULL_ALL
{
  lua_createtable(lstate, (int)narr, (int)(1 + nrec));
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
  lua_pushnumber(lstate, (lua_Number)n);
}

/// Convert given Float to lua table
///
/// Leaves converted table on top of the stack.
void nlua_push_Float(lua_State *lstate, const Float f)
  FUNC_ATTR_NONNULL_ALL
{
  nlua_create_typed_table(lstate, 0, 1, kObjectTypeFloat);
  nlua_push_val_idx(lstate);
  lua_pushnumber(lstate, (lua_Number)f);
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

/// Convert given Dictionary to lua table
///
/// Leaves converted table on top of the stack.
void nlua_push_Dictionary(lua_State *lstate, const Dictionary dict)
  FUNC_ATTR_NONNULL_ALL
{
  if (dict.size == 0) {
    nlua_create_typed_table(lstate, 0, 0, kObjectTypeDictionary);
  } else {
    lua_createtable(lstate, 0, (int)dict.size);
  }
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
  lua_createtable(lstate, (int)array.size, 0);
  for (size_t i = 0; i < array.size; i++) {
    nlua_push_Object(lstate, array.items[i]);
    lua_rawseti(lstate, -2, (int)i + 1);
  }
}

#define GENERATE_INDEX_FUNCTION(type) \
void nlua_push_##type(lua_State *lstate, const type item) \
  FUNC_ATTR_NONNULL_ALL \
{ \
  lua_pushnumber(lstate, (lua_Number)(item)); \
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
    case kObjectTypeLuaRef: {
      nlua_pushref(lstate, obj.data.luaref);
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
  if (lua_type(lstate, -1) != LUA_TSTRING) {
    lua_pop(lstate, 1);
    api_set_error(err, kErrorTypeValidation, "Expected lua string");
    return (String) { .size = 0, .data = NULL };
  }
  String ret;

  ret.data = (char *)lua_tolstring(lstate, -1, &(ret.size));
  assert(ret.data != NULL);
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
  if (lua_type(lstate, -1) != LUA_TNUMBER) {
    lua_pop(lstate, 1);
    api_set_error(err, kErrorTypeValidation, "Expected lua number");
    return 0;
  }
  const lua_Number n = lua_tonumber(lstate, -1);
  lua_pop(lstate, 1);
  if (n > (lua_Number)API_INTEGER_MAX || n < (lua_Number)API_INTEGER_MIN
      || ((lua_Number)((Integer)n)) != n) {
    api_set_error(err, kErrorTypeException, "Number is not integral");
    return 0;
  }
  return (Integer)n;
}

/// Convert lua value to boolean
///
/// Always pops one value from the stack.
Boolean nlua_pop_Boolean(lua_State *lstate, Error *err)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const Boolean ret = lua_toboolean(lstate, -1);
  lua_pop(lstate, 1);
  return ret;
}

/// Check whether typed table on top of the stack has given type
///
/// @param[in]  lstate  Lua state.
/// @param[out]  err  Location where error will be saved. May be NULL.
/// @param[in]  type  Type to check.
///
/// @return @see nlua_traverse_table().
static inline LuaTableProps nlua_check_type(lua_State *const lstate,
                                            Error *const err,
                                            const ObjectType type)
  FUNC_ATTR_NONNULL_ARG(1) FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (lua_type(lstate, -1) != LUA_TTABLE) {
    if (err) {
      api_set_error(err, kErrorTypeValidation, "Expected lua table");
    }
    return (LuaTableProps) { .type = kObjectTypeNil };
  }
  LuaTableProps table_props = nlua_traverse_table(lstate);

  if (type == kObjectTypeDictionary && table_props.type == kObjectTypeArray
      && table_props.maxidx == 0 && !table_props.has_type_key) {
    table_props.type = kObjectTypeDictionary;
  }

  if (table_props.type != type) {
    if (err) {
      api_set_error(err, kErrorTypeValidation, "Unexpected type");
    }
  }

  return table_props;
}

/// Convert lua table to float
///
/// Always pops one value from the stack.
Float nlua_pop_Float(lua_State *lstate, Error *err)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (lua_type(lstate, -1) == LUA_TNUMBER) {
    const Float ret = (Float)lua_tonumber(lstate, -1);
    lua_pop(lstate, 1);
    return ret;
  }

  const LuaTableProps table_props = nlua_check_type(lstate, err,
                                                    kObjectTypeFloat);
  lua_pop(lstate, 1);
  if (table_props.type != kObjectTypeFloat) {
    return 0;
  } else {
    return (Float)table_props.val;
  }
}

/// Convert lua table to array without determining whether it is array
///
/// @param  lstate  Lua state.
/// @param[in]  table_props  nlua_traverse_table() output.
/// @param[out]  err  Location where error will be saved.
static Array nlua_pop_Array_unchecked(lua_State *const lstate,
                                      const LuaTableProps table_props,
                                      Error *const err)
{
  Array ret = { .size = table_props.maxidx, .items = NULL };

  if (ret.size == 0) {
    lua_pop(lstate, 1);
    return ret;
  }

  ret.items = xcalloc(ret.size, sizeof(*ret.items));
  for (size_t i = 1; i <= ret.size; i++) {
    Object val;

    lua_rawgeti(lstate, -1, (int)i);

    val = nlua_pop_Object(lstate, false, err);
    if (ERROR_SET(err)) {
      ret.size = i - 1;
      lua_pop(lstate, 1);
      api_free_array(ret);
      return (Array) { .size = 0, .items = NULL };
    }
    ret.items[i - 1] = val;
  }
  lua_pop(lstate, 1);

  return ret;
}

/// Convert lua table to array
///
/// Always pops one value from the stack.
Array nlua_pop_Array(lua_State *lstate, Error *err)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const LuaTableProps table_props = nlua_check_type(lstate, err,
                                                    kObjectTypeArray);
  if (table_props.type != kObjectTypeArray) {
    return (Array) { .size = 0, .items = NULL };
  }
  return nlua_pop_Array_unchecked(lstate, table_props, err);
}

/// Convert lua table to dictionary
///
/// Always pops one value from the stack. Does not check whether whether topmost
/// value on the stack is a table.
///
/// @param  lstate  Lua interpreter state.
/// @param[in]  table_props  nlua_traverse_table() output.
/// @param[out]  err  Location where error will be saved.
static Dictionary nlua_pop_Dictionary_unchecked(lua_State *lstate,
                                                const LuaTableProps table_props,
                                                bool ref,
                                                Error *err)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  Dictionary ret = { .size = table_props.string_keys_num, .items = NULL };

  if (ret.size == 0) {
    lua_pop(lstate, 1);
    return ret;
  }
  ret.items = xcalloc(ret.size, sizeof(*ret.items));

  lua_pushnil(lstate);
  for (size_t i = 0; lua_next(lstate, -2) && i < ret.size;) {
    // stack: dict, key, value

    if (lua_type(lstate, -2) == LUA_TSTRING) {
      lua_pushvalue(lstate, -2);
      // stack: dict, key, value, key

      ret.items[i].key = nlua_pop_String(lstate, err);
      // stack: dict, key, value

      if (!ERROR_SET(err)) {
        ret.items[i].value = nlua_pop_Object(lstate, ref, err);
        // stack: dict, key
      } else {
        lua_pop(lstate, 1);
        // stack: dict, key
      }

      if (ERROR_SET(err)) {
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
Dictionary nlua_pop_Dictionary(lua_State *lstate, bool ref, Error *err)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const LuaTableProps table_props = nlua_check_type(lstate, err,
                                                    kObjectTypeDictionary);
  if (table_props.type != kObjectTypeDictionary) {
    lua_pop(lstate, 1);
    return (Dictionary) { .size = 0, .items = NULL };
  }

  return nlua_pop_Dictionary_unchecked(lstate, table_props, ref, err);
}

/// Helper structure for nlua_pop_Object
typedef struct {
  Object *obj;  ///< Location where conversion result is saved.
  bool container;  ///< True if tv is a container.
} ObjPopStackItem;

/// Convert lua table to object
///
/// Always pops one value from the stack.
Object nlua_pop_Object(lua_State *const lstate, bool ref, Error *const err)
{
  Object ret = NIL;
  const int initial_size = lua_gettop(lstate);
  kvec_t(ObjPopStackItem) stack = KV_INITIAL_VALUE;
  kv_push(stack, ((ObjPopStackItem) { &ret, false }));
  while (!ERROR_SET(err) && kv_size(stack)) {
    if (!lua_checkstack(lstate, lua_gettop(lstate) + 3)) {
      api_set_error(err, kErrorTypeException, "Lua failed to grow stack");
      break;
    }
    ObjPopStackItem cur = kv_pop(stack);
    if (cur.container) {
      if (cur.obj->type == kObjectTypeDictionary) {
        // stack: …, dict, key
        if (cur.obj->data.dictionary.size
            == cur.obj->data.dictionary.capacity) {
          lua_pop(lstate, 2);
          continue;
        }
        bool next_key_found = false;
        while (lua_next(lstate, -2)) {
          // stack: …, dict, new key, val
          if (lua_type(lstate, -2) == LUA_TSTRING) {
            next_key_found = true;
            break;
          }
          lua_pop(lstate, 1);
          // stack: …, dict, new key
        }
        if (next_key_found) {
          // stack: …, dict, new key, val
          size_t len;
          const char *s = lua_tolstring(lstate, -2, &len);
          const size_t idx = cur.obj->data.dictionary.size++;
          cur.obj->data.dictionary.items[idx].key = (String) {
            .data = xmemdupz(s, len),
            .size = len,
          };
          kv_push(stack, cur);
          cur = (ObjPopStackItem) {
            .obj = &cur.obj->data.dictionary.items[idx].value,
            .container = false,
          };
        } else {
          // stack: …, dict
          lua_pop(lstate, 1);
          // stack: …
          continue;
        }
      } else {
        if (cur.obj->data.array.size == cur.obj->data.array.capacity) {
          lua_pop(lstate, 1);
          continue;
        }
        const size_t idx = cur.obj->data.array.size++;
        lua_rawgeti(lstate, -1, (int)idx + 1);
        if (lua_isnil(lstate, -1)) {
          lua_pop(lstate, 2);
          continue;
        }
        kv_push(stack, cur);
        cur = (ObjPopStackItem) {
          .obj = &cur.obj->data.array.items[idx],
          .container = false,
        };
      }
    }
    assert(!cur.container);
    *cur.obj = NIL;
    switch (lua_type(lstate, -1)) {
      case LUA_TNIL: {
        break;
      }
      case LUA_TBOOLEAN: {
        *cur.obj = BOOLEAN_OBJ(lua_toboolean(lstate, -1));
        break;
      }
      case LUA_TSTRING: {
        size_t len;
        const char *s = lua_tolstring(lstate, -1, &len);
        *cur.obj = STRING_OBJ(((String) {
          .data = xmemdupz(s, len),
          .size = len,
        }));
        break;
      }
      case LUA_TNUMBER: {
        const lua_Number n = lua_tonumber(lstate, -1);
        if (n > (lua_Number)API_INTEGER_MAX || n < (lua_Number)API_INTEGER_MIN
            || ((lua_Number)((Integer)n)) != n) {
          *cur.obj = FLOAT_OBJ((Float)n);
        } else {
          *cur.obj = INTEGER_OBJ((Integer)n);
        }
        break;
      }
      case LUA_TTABLE: {
        const LuaTableProps table_props = nlua_traverse_table(lstate);

        switch (table_props.type) {
          case kObjectTypeArray: {
            *cur.obj = ARRAY_OBJ(((Array) {
              .items = NULL,
              .size = 0,
              .capacity = 0,
            }));
            if (table_props.maxidx != 0) {
              cur.obj->data.array.items =
                  xcalloc(table_props.maxidx,
                          sizeof(cur.obj->data.array.items[0]));
              cur.obj->data.array.capacity = table_props.maxidx;
              cur.container = true;
              kv_push(stack, cur);
            }
            break;
          }
          case kObjectTypeDictionary: {
            *cur.obj = DICTIONARY_OBJ(((Dictionary) {
              .items = NULL,
              .size = 0,
              .capacity = 0,
            }));
            if (table_props.string_keys_num != 0) {
              cur.obj->data.dictionary.items =
                  xcalloc(table_props.string_keys_num,
                          sizeof(cur.obj->data.dictionary.items[0]));
              cur.obj->data.dictionary.capacity = table_props.string_keys_num;
              cur.container = true;
              kv_push(stack, cur);
              lua_pushnil(lstate);
            }
            break;
          }
          case kObjectTypeFloat: {
            *cur.obj = FLOAT_OBJ((Float)table_props.val);
            break;
          }
          case kObjectTypeNil: {
            api_set_error(err, kErrorTypeValidation,
                          "Cannot convert given lua table");
            break;
          }
          default: {
            assert(false);
          }
        }
        break;
      }

      case LUA_TFUNCTION: {
        if (ref) {
          *cur.obj = LUAREF_OBJ(nlua_ref(lstate, -1));
        } else {
          goto type_error;
        }
        break;
      }

      default: {
type_error:
        api_set_error(err, kErrorTypeValidation,
                      "Cannot convert given lua type");
        break;
      }
    }
    if (!cur.container) {
      lua_pop(lstate, 1);
    }
  }
  kv_destroy(stack);
  if (ERROR_SET(err)) {
    api_free_object(ret);
    ret = NIL;
    lua_pop(lstate, lua_gettop(lstate) - initial_size + 1);
  }
  assert(lua_gettop(lstate) == initial_size - 1);
  return ret;
}

#define GENERATE_INDEX_FUNCTION(type) \
type nlua_pop_##type(lua_State *lstate, Error *err) \
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT \
{ \
  type ret; \
  ret = (type)lua_tonumber(lstate, -1); \
  lua_pop(lstate, 1); \
  return ret; \
}

GENERATE_INDEX_FUNCTION(Buffer)
GENERATE_INDEX_FUNCTION(Window)
GENERATE_INDEX_FUNCTION(Tabpage)

#undef GENERATE_INDEX_FUNCTION

/// Record some auxilary values in vim module
///
/// Assumes that module table is on top of the stack.
///
/// Recorded values:
///
/// `vim.type_idx`: @see nlua_push_type_idx()
/// `vim.val_idx`: @see nlua_push_val_idx()
/// `vim.types`: table mapping possible values of `vim.type_idx` to string
///              names (i.e. `array`, `float`, `dictionary`) and back.
void nlua_init_types(lua_State *const lstate)
{
  LUA_PUSH_STATIC_STRING(lstate, "type_idx");
  nlua_push_type_idx(lstate);
  lua_rawset(lstate, -3);

  LUA_PUSH_STATIC_STRING(lstate, "val_idx");
  nlua_push_val_idx(lstate);
  lua_rawset(lstate, -3);

  LUA_PUSH_STATIC_STRING(lstate, "types");
  lua_createtable(lstate, 0, 3);

  LUA_PUSH_STATIC_STRING(lstate, "float");
  lua_pushnumber(lstate, (lua_Number)kObjectTypeFloat);
  lua_rawset(lstate, -3);
  lua_pushnumber(lstate, (lua_Number)kObjectTypeFloat);
  LUA_PUSH_STATIC_STRING(lstate, "float");
  lua_rawset(lstate, -3);

  LUA_PUSH_STATIC_STRING(lstate, "array");
  lua_pushnumber(lstate, (lua_Number)kObjectTypeArray);
  lua_rawset(lstate, -3);
  lua_pushnumber(lstate, (lua_Number)kObjectTypeArray);
  LUA_PUSH_STATIC_STRING(lstate, "array");
  lua_rawset(lstate, -3);

  LUA_PUSH_STATIC_STRING(lstate, "dictionary");
  lua_pushnumber(lstate, (lua_Number)kObjectTypeDictionary);
  lua_rawset(lstate, -3);
  lua_pushnumber(lstate, (lua_Number)kObjectTypeDictionary);
  LUA_PUSH_STATIC_STRING(lstate, "dictionary");
  lua_rawset(lstate, -3);

  lua_rawset(lstate, -3);
}
