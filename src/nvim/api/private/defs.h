#ifndef NVIM_API_PRIVATE_DEFS_H
#define NVIM_API_PRIVATE_DEFS_H

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#define ARRAY_DICT_INIT {.size = 0, .capacity = 0, .items = NULL}
#define STRING_INIT {.data = NULL, .size = 0}
#define OBJECT_INIT { .type = kObjectTypeNil }
#define ERROR_INIT { .set = false }
#define FUNCTION_INIT {                                   \
  .data = {.name = NULL, .channel = 0, .async = false},   \
  .ptr = NULL                                             \
}

#define REMOTE_TYPE(type) typedef uint64_t type

#ifdef INCLUDE_GENERATED_DECLARATIONS
  #define ArrayOf(...) Array
  #define DictionaryOf(...) Dictionary
#endif

// Basic types
typedef enum {
  kErrorTypeException,
  kErrorTypeValidation
} ErrorType;

typedef struct {
  ErrorType type;
  char msg[1024];
  bool set;
} Error;

typedef bool Boolean;
typedef int64_t Integer;
typedef double Float;

typedef struct {
  char *data;
  size_t size;
} String;

REMOTE_TYPE(Buffer);
REMOTE_TYPE(Window);
REMOTE_TYPE(Tabpage);

typedef struct function Function;
typedef struct object Object;

typedef struct {
  Object *items;
  size_t size, capacity;
} Array;

typedef struct key_value_pair KeyValuePair;

typedef struct {
  KeyValuePair *items;
  size_t size, capacity;
} Dictionary;

typedef struct {
  char *name;
  uint64_t channel;
  bool async;
} FunctionData;

struct function {
  Object (*ptr)(FunctionData *data, Array args, Error *err);
  FunctionData data;
};

typedef enum {
  kObjectTypeBuffer,
  kObjectTypeWindow,
  kObjectTypeTabpage,
  kObjectTypeFunction,
  kObjectTypeNil,
  kObjectTypeBoolean,
  kObjectTypeInteger,
  kObjectTypeFloat,
  kObjectTypeString,
  kObjectTypeArray,
  kObjectTypeDictionary,
} ObjectType;

struct object {
  ObjectType type;
  union {
    Buffer buffer;
    Window window;
    Tabpage tabpage;
    Function function;
    Boolean boolean;
    Integer integer;
    Float floating;
    String string;
    Array array;
    Dictionary dictionary;
  } data;
};

struct key_value_pair {
  String key;
  Object value;
};

#endif  // NVIM_API_PRIVATE_DEFS_H

