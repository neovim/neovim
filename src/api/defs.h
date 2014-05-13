#ifndef NEOVIM_API_DEFS_H
#define NEOVIM_API_DEFS_H

#include <stdint.h>
#include <string.h>

// Basic types
typedef struct {
  char msg[256];
  bool set;
} Error;

typedef struct {
  char *data;
  size_t size;
} String;

typedef uint16_t Buffer;
typedef uint16_t Window;
typedef uint16_t Tabpage;

typedef struct object Object;

typedef struct {
  String *items;
  size_t size;
} StringArray;

typedef struct {
  uint16_t row, col;
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
  kObjectTypeBool,
  kObjectTypeInt,
  kObjectTypeFloat,
  kObjectTypeString,
  kObjectTypeArray,
  kObjectTypeDictionary
} ObjectType;

struct object {
  ObjectType type;
  union {
    bool boolean;
    int64_t integer;
    double floating_point;
    String string;
    Array array;
    Dictionary dictionary;
  } data;
};

struct key_value_pair {
  String key;
  Object value;
};


#endif  // NEOVIM_API_DEFS_H

