#ifndef NVIM_API_PRIVATE_DEFS_H
#define NVIM_API_PRIVATE_DEFS_H

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/func_attr.h"
#include "nvim/types.h"

#define ARRAY_DICT_INIT KV_INITIAL_VALUE
#define STRING_INIT { .data = NULL, .size = 0 }
#define OBJECT_INIT { .type = kObjectTypeNil }
#define ERROR_INIT ((Error) { .type = kErrorTypeNone, .msg = NULL })
#define REMOTE_TYPE(type) typedef handle_T type

#define ERROR_SET(e) ((e)->type != kErrorTypeNone)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# define ArrayOf(...) Array
# define DictionaryOf(...) Dictionary
# define Dict(name) KeyDict_##name
#endif

// Basic types
typedef enum {
  kErrorTypeNone = -1,
  kErrorTypeException,
  kErrorTypeValidation,
} ErrorType;

typedef enum {
  kMessageTypeUnknown = -1,
  // Per msgpack-rpc spec.
  kMessageTypeRequest = 0,
  kMessageTypeResponse = 1,
  kMessageTypeNotification = 2,
  kMessageTypeRedrawEvent = 3,
} MessageType;

/// Mask for all internal calls
#define INTERNAL_CALL_MASK (((uint64_t)1) << (sizeof(uint64_t) * 8 - 1))

/// Internal call from Vimscript code
#define VIML_INTERNAL_CALL INTERNAL_CALL_MASK

/// Internal call from Lua code
#define LUA_INTERNAL_CALL (VIML_INTERNAL_CALL + 1)

static inline bool is_internal_call(uint64_t channel_id)
  REAL_FATTR_ALWAYS_INLINE REAL_FATTR_CONST;

/// Check whether call is internal
///
/// @param[in]  channel_id  Channel id.
///
/// @return true if channel_id refers to internal channel.
static inline bool is_internal_call(const uint64_t channel_id)
{
  return !!(channel_id & INTERNAL_CALL_MASK);
}

typedef struct {
  ErrorType type;
  char *msg;
} Error;

typedef bool Boolean;
typedef int64_t Integer;
typedef double Float;

/// Maximum value of an Integer
#define API_INTEGER_MAX INT64_MAX

/// Minimum value of an Integer
#define API_INTEGER_MIN INT64_MIN

typedef struct {
  char *data;
  size_t size;
} String;

REMOTE_TYPE(Buffer);
REMOTE_TYPE(Window);
REMOTE_TYPE(Tabpage);

typedef struct object Object;
typedef kvec_t(Object) Array;

typedef struct key_value_pair KeyValuePair;
typedef kvec_t(KeyValuePair) Dictionary;

typedef enum {
  kObjectTypeNil = 0,
  kObjectTypeBoolean,
  kObjectTypeInteger,
  kObjectTypeFloat,
  kObjectTypeString,
  kObjectTypeArray,
  kObjectTypeDictionary,
  kObjectTypeLuaRef,
  // EXT types, cannot be split or reordered, see #EXT_OBJECT_TYPE_SHIFT
  kObjectTypeBuffer,
  kObjectTypeWindow,
  kObjectTypeTabpage,
} ObjectType;

struct object {
  ObjectType type;
  union {
    Boolean boolean;
    Integer integer;
    Float floating;
    String string;
    Array array;
    Dictionary dictionary;
    LuaRef luaref;
  } data;
};

struct key_value_pair {
  String key;
  Object value;
};

typedef Object *(*field_hash)(void *retval, const char *str, size_t len);
typedef struct {
  char *str;
  size_t ptr_off;
} KeySetLink;

#endif  // NVIM_API_PRIVATE_DEFS_H
