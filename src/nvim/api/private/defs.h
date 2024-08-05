#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/types_defs.h"

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
# define DictHash(name) KeyDict_##name##_get_field
# define DictKey(name)
# include "api/private/defs.h.inline.generated.h"
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

/// Check whether call is internal
///
/// @param[in]  channel_id  Channel id.
///
/// @return true if channel_id refers to internal channel.
static inline bool is_internal_call(const uint64_t channel_id)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_CONST
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

typedef kvec_t(String) StringArray;

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

typedef enum {
  kUnpackTypeStringArray = -1,
} UnpackType;

/// Value by which objects represented as EXT type are shifted
///
/// Subtracted when packing, added when unpacking. Used to allow moving
/// buffer/window/tabpage block inside ObjectType enum. This block yet cannot be
/// split or reordered.
#define EXT_OBJECT_TYPE_SHIFT kObjectTypeBuffer
#define EXT_OBJECT_TYPE_MAX (kObjectTypeTabpage - EXT_OBJECT_TYPE_SHIFT)

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

typedef uint64_t OptionalKeys;
typedef Integer HLGroupID;

// this is the prefix of all keysets with optional keys
typedef struct {
  OptionalKeys is_set_;
} OptKeySet;

typedef struct {
  char *str;
  size_t ptr_off;
  int type;  // ObjectType or UnpackType. kObjectTypeNil == untyped
  int opt_index;
  bool is_hlgroup;
} KeySetLink;

typedef KeySetLink *(*FieldHashfn)(const char *str, size_t len);
