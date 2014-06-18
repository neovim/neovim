#ifndef NVIM_API_PRIVATE_HELPERS_H
#define NVIM_API_PRIVATE_HELPERS_H

#include <stdbool.h>

#include "nvim/api/private/defs.h"
#include "nvim/vim.h"
#include "nvim/memory.h"
#include "nvim/lib/kvec.h"

#define set_api_error(message, err)                \
  do {                                             \
    xstrlcpy(err->msg, message, sizeof(err->msg)); \
    err->set = true;                               \
  } while (0)

#define BOOL_OBJ(b) ((Object) {                                               \
  .type = kObjectTypeBoolean,                                                 \
  .data.boolean = b                                                           \
  })

#define INTEGER_OBJ(i) ((Object) {                                            \
  .type = kObjectTypeInteger,                                                 \
  .data.integer = i                                                           \
  })

#define STRING_OBJ(s) ((Object) {                                             \
  .type = kObjectTypeString,                                                  \
  .data.string = cstr_to_string(s)                                            \
  })

#define STRINGL_OBJ(d, s) ((Object) {                                         \
  .type = kObjectTypeString,                                                  \
  .data.string = (String) {                                                   \
    .size = s,                                                                \
    .data = xmemdup(d, s)                                                     \
  }})

#define ARRAY_OBJ(a) ((Object) {                                              \
  .type = kObjectTypeArray,                                                   \
  .data.array = a                                                             \
  })

#define DICTIONARY_OBJ(d) ((Object) {                                         \
  .type = kObjectTypeDictionary,                                              \
  .data.dictionary = d                                                        \
  })

#define NIL ((Object) {.type = kObjectTypeNil})

#define PUT(dict, k, v)                                                       \
  kv_push(KeyValuePair,                                                       \
          dict,                                                               \
          ((KeyValuePair) {.key = cstr_to_string(k), .value = v}))

#define ADD(array, item)                                                      \
  kv_push(Object, array, item)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/helpers.h.generated.h"
#endif
#endif  // NVIM_API_PRIVATE_HELPERS_H
