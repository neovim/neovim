#pragma once

#include <stdbool.h>
#include <stddef.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/buffer_defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/ex_eval_defs.h"
#include "nvim/macros_defs.h"
#include "nvim/map_defs.h"
#include "nvim/message_defs.h"  // IWYU pragma: keep

#define OBJECT_OBJ(o) o

#define BOOLEAN_OBJ(b) ((Object) { \
    .type = kObjectTypeBoolean, \
    .data.boolean = b })

#define INTEGER_OBJ(i) ((Object) { \
    .type = kObjectTypeInteger, \
    .data.integer = i })

#define FLOAT_OBJ(f) ((Object) { \
    .type = kObjectTypeFloat, \
    .data.floating = f })

#define STRING_OBJ(s) ((Object) { \
    .type = kObjectTypeString, \
    .data.string = s })

#define CSTR_AS_OBJ(s) STRING_OBJ(cstr_as_string(s))
#define CSTR_TO_OBJ(s) STRING_OBJ(cstr_to_string(s))
#define CSTR_TO_ARENA_STR(arena, s) arena_string(arena, cstr_as_string(s))
#define CSTR_TO_ARENA_OBJ(arena, s) STRING_OBJ(CSTR_TO_ARENA_STR(arena, s))
#define CBUF_TO_ARENA_STR(arena, s, len) arena_string(arena, cbuf_as_string((char *)(s), len))
#define CBUF_TO_ARENA_OBJ(arena, s, len) STRING_OBJ(CBUF_TO_ARENA_STR(arena, s, len))

#define BUFFER_OBJ(s) ((Object) { \
    .type = kObjectTypeBuffer, \
    .data.integer = s })

#define WINDOW_OBJ(s) ((Object) { \
    .type = kObjectTypeWindow, \
    .data.integer = s })

#define TABPAGE_OBJ(s) ((Object) { \
    .type = kObjectTypeTabpage, \
    .data.integer = s })

#define ARRAY_OBJ(a) ((Object) { \
    .type = kObjectTypeArray, \
    .data.array = a })

#define DICT_OBJ(d) ((Object) { \
    .type = kObjectTypeDict, \
    .data.dict = d })

#define LUAREF_OBJ(r) ((Object) { \
    .type = kObjectTypeLuaRef, \
    .data.luaref = r })

#define NIL ((Object)OBJECT_INIT)
#define NULL_STRING ((String)STRING_INIT)

#define HAS_KEY(d, typ, key) (((d)->is_set__##typ##_ & (1 << KEYSET_OPTIDX_##typ##__##key)) != 0)

#define GET_BOOL_OR_TRUE(d, typ, key) (HAS_KEY(d, typ, key) ? (d)->key : true)

#define PUT(dict, k, v) \
  kv_push(dict, ((KeyValuePair) { .key = cstr_to_string(k), .value = v }))

#define PUT_C(dict, k, v) \
  kv_push_c(dict, ((KeyValuePair) { .key = cstr_as_string(k), .value = v }))

#define PUT_KEY(d, typ, key, v) \
  do { (d).is_set__##typ##_ |= (1 << KEYSET_OPTIDX_##typ##__##key); (d).key = v; } while (0)

#define ADD(array, item) \
  kv_push(array, item)

#define ADD_C(array, item) \
  kv_push_c(array, item)

#define MAXSIZE_TEMP_ARRAY(name, maxsize) \
  Array name = ARRAY_DICT_INIT; \
  Object name##__items[maxsize]; \
  name.capacity = maxsize; \
  name.items = name##__items; \

#define MAXSIZE_TEMP_DICT(name, maxsize) \
  Dict name = ARRAY_DICT_INIT; \
  KeyValuePair name##__items[maxsize]; \
  name.capacity = maxsize; \
  name.items = name##__items; \

typedef kvec_withinit_t(Object, 16) ArrayBuilder;

#define cbuf_as_string(d, s) ((String) { .data = d, .size = s })

#define STATIC_CSTR_AS_STRING(s) ((String) { .data = s, .size = sizeof("" s) - 1 })

/// Create a new String instance, putting data in allocated memory
///
/// @param[in]  s  String to work with. Must be a string literal.
#define STATIC_CSTR_TO_STRING(s) ((String){ \
    .data = xmemdupz(s, sizeof(s) - 1), \
    .size = sizeof(s) - 1 })

#define STATIC_CSTR_AS_OBJ(s) STRING_OBJ(STATIC_CSTR_AS_STRING(s))
#define STATIC_CSTR_TO_OBJ(s) STRING_OBJ(STATIC_CSTR_TO_STRING(s))

#define API_CLEAR_STRING(s) \
  do { \
    XFREE_CLEAR(s.data); \
    s.size = 0; \
  } while (0)

// Helpers used by the generated msgpack-rpc api wrappers
#define api_init_boolean
#define api_init_integer
#define api_init_float
#define api_init_string = STRING_INIT
#define api_init_buffer
#define api_init_window
#define api_init_tabpage
#define api_init_object = NIL
#define api_init_array = ARRAY_DICT_INIT
#define api_init_dict = ARRAY_DICT_INIT

#define KEYDICT_INIT { 0 }

EXTERN PMap(int) buffer_handles INIT( = MAP_INIT);
EXTERN PMap(int) window_handles INIT( = MAP_INIT);
EXTERN PMap(int) tabpage_handles INIT( = MAP_INIT);

#define handle_get_buffer(h) pmap_get(int)(&buffer_handles, (h))
#define handle_get_window(h) pmap_get(int)(&window_handles, (h))
#define handle_get_tabpage(h) pmap_get(int)(&tabpage_handles, (h))

/// Structure used for saving state for :try
///
/// Used when caller is supposed to be operating when other Vimscript code is being
/// processed and that “other Vimscript code” must not be affected.
typedef struct {
  except_T *current_exception;
  msglist_T *private_msg_list;
  const msglist_T *const *msg_list;
  int got_int;
  bool did_throw;
  int need_rethrow;
  int did_emsg;
} TryState;

// TODO(bfredl): prepare error-handling at "top level" (nv_event).
#define TRY_WRAP(err, code) \
  do { \
    TryState tstate; \
    try_enter(&tstate); \
    code; \
    try_leave(&tstate, err); \
  } while (0)

// Execute code with cursor position saved and restored and textlock active.
#define TEXTLOCK_WRAP(code) \
  do { \
    const pos_T save_cursor = curwin->w_cursor; \
    textlock++; \
    code; \
    textlock--; \
    curwin->w_cursor = save_cursor; \
  } while (0)

// Useful macro for executing some `code` for each item in an array.
#define FOREACH_ITEM(a, __foreach_item, code) \
  for (size_t (__foreach_item##_index) = 0; (__foreach_item##_index) < (a).size; \
       (__foreach_item##_index)++) { \
    Object __foreach_item = (a).items[__foreach_item##_index]; \
    code; \
  }

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/helpers.h.generated.h"
#endif

#define WITH_SCRIPT_CONTEXT(channel_id, code) \
  do { \
    const sctx_T save_current_sctx = current_sctx; \
    const uint64_t save_channel_id = current_channel_id; \
    current_sctx.sc_sid = \
      (channel_id) == LUA_INTERNAL_CALL ? SID_LUA : SID_API_CLIENT; \
    current_sctx.sc_lnum = 0; \
    current_channel_id = channel_id; \
    code; \
    current_channel_id = save_channel_id; \
    current_sctx = save_current_sctx; \
  } while (0);
