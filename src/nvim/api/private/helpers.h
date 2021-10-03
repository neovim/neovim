#ifndef NVIM_API_PRIVATE_HELPERS_H
#define NVIM_API_PRIVATE_HELPERS_H

#include <stdbool.h>

#include "nvim/api/private/defs.h"
#include "nvim/vim.h"
#include "nvim/getchar.h"
#include "nvim/memory.h"
#include "nvim/decoration.h"
#include "nvim/ex_eval.h"
#include "nvim/lib/kvec.h"

#define OBJECT_OBJ(o) o

#define BOOLEAN_OBJ(b) ((Object) { \
    .type = kObjectTypeBoolean, \
    .data.boolean = b })
#define BOOL(b) BOOLEAN_OBJ(b)

#define INTEGER_OBJ(i) ((Object) { \
    .type = kObjectTypeInteger, \
    .data.integer = i })

#define FLOAT_OBJ(f) ((Object) { \
    .type = kObjectTypeFloat, \
    .data.floating = f })

#define STRING_OBJ(s) ((Object) { \
    .type = kObjectTypeString, \
    .data.string = s })

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

#define PUT_BOOL(dict, name, condition) PUT(dict, name, BOOLEAN_OBJ(condition));

#define ADD(array, item) \
  kv_push(array, item)

#define FIXED_TEMP_ARRAY(name, fixsize) \
  Array name = ARRAY_DICT_INIT; \
  Object name##__items[fixsize]; \
  name.size = fixsize; \
  name.items = name##__items; \

#define STATIC_CSTR_AS_STRING(s) ((String) {.data = s, .size = sizeof(s) - 1})

/// Create a new String instance, putting data in allocated memory
///
/// @param[in]  s  String to work with. Must be a string literal.
#define STATIC_CSTR_TO_STRING(s) ((String){ \
    .data = xmemdupz(s, sizeof(s) - 1), \
    .size = sizeof(s) - 1 })

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

EXTERN PMap(handle_T) buffer_handles INIT(= MAP_INIT);
EXTERN PMap(handle_T) window_handles INIT(= MAP_INIT);
EXTERN PMap(handle_T) tabpage_handles INIT(= MAP_INIT);

#define handle_get_buffer(h) pmap_get(handle_T)(&buffer_handles, (h))
#define handle_get_window(h) pmap_get(handle_T)(&window_handles, (h))
#define handle_get_tabpage(h) pmap_get(handle_T)(&tabpage_handles, (h))

/// Structure used for saving state for :try
///
/// Used when caller is supposed to be operating when other VimL code is being
/// processed and that “other VimL code” must not be affected.
typedef struct {
  except_T *current_exception;
  struct msglist *private_msg_list;
  const struct msglist *const *msg_list;
  int trylevel;
  int got_int;
  int need_rethrow;
  int did_emsg;
} TryState;

// `msg_list` controls the collection of abort-causing non-exception errors,
// which would otherwise be ignored.  This pattern is from do_cmdline().
//
// TODO(bfredl): prepare error-handling at "top level" (nv_event).
#define TRY_WRAP(code) \
  do { \
    struct msglist **saved_msg_list = msg_list; \
    struct msglist *private_msg_list; \
    msg_list = &private_msg_list; \
    private_msg_list = NULL; \
    code \
    msg_list = saved_msg_list;  /* Restore the exception context. */ \
  } while (0)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "keysets.h.generated.h"
# include "api/private/helpers.h.generated.h"
#endif


#endif  // NVIM_API_PRIVATE_HELPERS_H
