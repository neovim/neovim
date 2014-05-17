#ifndef NVIM_API_DEFS_H
#define NVIM_API_DEFS_H

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

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

typedef Integer Buffer;
typedef Integer Window;
typedef Integer Tabpage;

typedef struct object Object;

typedef struct {
  String *items;
  size_t size;
} StringArray;

typedef struct {
  Integer row, col;
} Position;

typedef struct {
  Object *items;
  size_t size;
} Array;

typedef struct key_value_pair KeyValuePair;

typedef struct {
  KeyValuePair *items;
  size_t size;
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


#endif  // NVIM_API_DEFS_H

