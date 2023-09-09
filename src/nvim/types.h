#ifndef NVIM_TYPES_H
#define NVIM_TYPES_H

#include <stdbool.h>
#include <stdint.h>

// dummy to pass an ACL to a function
typedef void *vim_acl_T;

// Can hold one decoded UTF-8 character.
typedef uint32_t u8char_T;

// Opaque handle used by API clients to refer to various objects in vim
typedef int handle_T;

// Opaque handle to a lua value. Must be free with `api_free_luaref` when
// not needed anymore! LUA_NOREF represents missing reference, i e to indicate
// absent callback etc.
typedef int LuaRef;

/// Type used for Vimscript VAR_FLOAT values
typedef double float_T;

typedef struct MsgpackRpcRequestHandler MsgpackRpcRequestHandler;

typedef union {
  float_T (*float_func)(float_T);
  const MsgpackRpcRequestHandler *api_handler;
  void *null;
} EvalFuncData;

typedef handle_T NS;

typedef struct expand expand_T;

typedef uint64_t proftime_T;

typedef enum {
  kNone  = -1,
  kFalse = 0,
  kTrue  = 1,
} TriState;

#define TRISTATE_TO_BOOL(val, \
                         default) ((val) == kTrue ? true : ((val) == kFalse ? false : (default)))

typedef struct Decoration Decoration;

#endif  // NVIM_TYPES_H
