#ifndef NVIM_API_PRIVATE_HELPERS_H
#define NVIM_API_PRIVATE_HELPERS_H

#include <stdbool.h>
#include <stddef.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/decoration.h"
#include "nvim/ex_eval_defs.h"
#include "nvim/getchar.h"
#include "nvim/globals.h"
#include "nvim/macros.h"
#include "nvim/map.h"
#include "nvim/memory.h"
#include "nvim/vim.h"

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

#define DICTIONARY_OBJ(d) ((Object) { \
    .type = kObjectTypeDictionary, \
    .data.dictionary = d })

#define LUAREF_OBJ(r) ((Object) { \
    .type = kObjectTypeLuaRef, \
    .data.luaref = r })

#define NIL ((Object)OBJECT_INIT)
#define NULL_STRING ((String)STRING_INIT)

// currently treat key=vim.NIL as if the key was missing
#define HAS_KEY(o) ((o).type != kObjectTypeNil)

#define PUT(dict, k, v) \
  kv_push(dict, ((KeyValuePair) { .key = cstr_to_string(k), .value = v }))

#define PUT_C(dict, k, v) \
  kv_push_c(dict, ((KeyValuePair) { .key = cstr_as_string(k), .value = v }))

#define PUT_BOOL(dict, name, condition) PUT(dict, name, BOOLEAN_OBJ(condition));

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
  Dictionary name = ARRAY_DICT_INIT; \
  KeyValuePair name##__items[maxsize]; \
  name.capacity = maxsize; \
  name.items = name##__items; \

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
#define api_init_dictionary = ARRAY_DICT_INIT

#define api_free_boolean(value)
#define api_free_integer(value)
#define api_free_float(value)
#define api_free_buffer(value)
#define api_free_window(value)
#define api_free_tabpage(value)

EXTERN PMap(int) buffer_handles INIT(= MAP_INIT);
EXTERN PMap(int) window_handles INIT(= MAP_INIT);
EXTERN PMap(int) tabpage_handles INIT(= MAP_INIT);

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
  int trylevel;
  int got_int;
  bool did_throw;
  int need_rethrow;
  int did_emsg;
} TryState;

// `msg_list` controls the collection of abort-causing non-exception errors,
// which would otherwise be ignored.  This pattern is from do_cmdline().
//
// TODO(bfredl): prepare error-handling at "top level" (nv_event).
#define TRY_WRAP(err, code) \
  do { \
    msglist_T **saved_msg_list = msg_list; \
    msglist_T *private_msg_list; \
    msg_list = &private_msg_list; \
    private_msg_list = NULL; \
    try_start(); \
    code; \
    try_end(err); \
    msg_list = saved_msg_list;  /* Restore the exception context. */ \
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

#endif  // NVIM_API_PRIVATE_HELPERS_H
