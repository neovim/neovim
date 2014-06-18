#ifndef NVIM_API_PRIVATE_DEFS_H
#define NVIM_API_PRIVATE_DEFS_H

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#define ARRAY_DICT_INIT {.size = 0, .items = NULL}
#define STRING_INIT {.data = NULL, .size = 0}
#define OBJECT_INIT { .type = kObjectTypeNil }
#define POSITION_INIT { .row = 0, .col = 0 }
#define REMOTE_TYPE(type) typedef uint64_t type

#define TYPED_ARRAY_OF(type)                                                  \
  typedef struct {                                                            \
    type *items;                                                              \
    size_t size;                                                              \
  } type##Array

// Basic types
typedef struct {
  char msg[256];
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

typedef struct object Object;

TYPED_ARRAY_OF(Buffer);
TYPED_ARRAY_OF(Window);
TYPED_ARRAY_OF(Tabpage);
TYPED_ARRAY_OF(String);

typedef struct {
  Integer row, col;
} Position;

typedef struct {
  Object *items;
  size_t size, capacity;
} Array;

typedef struct key_value_pair KeyValuePair;

typedef struct {
  KeyValuePair *items;
  size_t size, capacity;
} Dictionary;

typedef enum {
  kObjectTypeNil,
  kObjectTypeBoolean,
  kObjectTypeInteger,
  kObjectTypeFloat,
  kObjectTypeString,
  kObjectTypeArray,
  kObjectTypeDictionary
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
  } data;
};

struct key_value_pair {
  String key;
  Object value;
};


#endif  // NVIM_API_PRIVATE_DEFS_H

