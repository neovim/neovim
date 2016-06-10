#ifndef NVIM_API_PRIVATE_HELPERS_H
#define NVIM_API_PRIVATE_HELPERS_H

#include <stdbool.h>

#include "nvim/api/private/defs.h"
#include "nvim/vim.h"
#include "nvim/memory.h"
#include "nvim/lib/kvec.h"

#define api_set_error(err, errtype, ...) \
  do { \
    snprintf((err)->msg, \
             sizeof((err)->msg), \
             __VA_ARGS__); \
    (err)->set = true; \
    (err)->type = kErrorType##errtype; \
  } while (0)

#define OBJECT_OBJ(o) o

#define BOOLEAN_OBJ(b) ((Object) { \
    .type = kObjectTypeBoolean, \
    .data.boolean = b })

#define INTEGER_OBJ(i) ((Object) { \
    .type = kObjectTypeInteger, \
    .data.integer = i })

#define STRING_OBJ(s) ((Object) { \
    .type = kObjectTypeString, \
    .data.string = s })

#define BUFFER_OBJ(s) ((Object) { \
    .type = kObjectTypeBuffer, \
    .data.buffer = s })

#define WINDOW_OBJ(s) ((Object) { \
    .type = kObjectTypeWindow, \
    .data.window = s })

#define TABPAGE_OBJ(s) ((Object) { \
    .type = kObjectTypeTabpage, \
    .data.tabpage = s })

#define ARRAY_OBJ(a) ((Object) { \
    .type = kObjectTypeArray, \
    .data.array = a })

#define DICTIONARY_OBJ(d) ((Object) { \
    .type = kObjectTypeDictionary, \
    .data.dictionary = d })

#define NIL ((Object) {.type = kObjectTypeNil})

#define PUT(dict, k, v) \
  kv_push(dict, ((KeyValuePair) { .key = cstr_to_string(k), .value = v }))

#define ADD(array, item) \
  kv_push(array, item)

#define STATIC_CSTR_AS_STRING(s) ((String) {.data = s, .size = sizeof(s) - 1})

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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/helpers.h.generated.h"
#endif
#endif  // NVIM_API_PRIVATE_HELPERS_H
