#pragma once

#include <stdint.h>

// dummy to pass an ACL to a function
typedef void *vim_acl_T;

// if data[0] is 0xFF, then data[1..4] is a 24-bit index (in machine endianness)
// otherwise it must be a UTF-8 string of length maximum 4 (no NUL when n=4)
typedef uint32_t schar_T;
typedef int32_t sattr_T;
// must be at least as big as the biggest of schar_T, sattr_T, colnr_T
typedef int32_t sscratch_T;

// Includes final NUL. MAX_MCO is no longer used, but at least 4*(MAX_MCO+1)+1=29
// ensures we can fit all composed chars which did fit before.
#define MAX_SCHAR_SIZE 32

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

typedef uint64_t proftime_T;

typedef enum {
  kNone  = -1,
  kFalse = 0,
  kTrue  = 1,
} TriState;

#define TRISTATE_TO_BOOL(val, \
                         default) ((val) == kTrue ? true : ((val) == kFalse ? false : (default)))

#define TRISTATE_FROM_INT(val) ((val) == 0 ? kFalse : ((val) >= 1 ? kTrue : kNone))

typedef int64_t OptInt;

enum { SIGN_WIDTH = 2, };  ///< Number of display cells for a sign in the signcolumn

typedef struct file_buffer buf_T;
typedef struct loop Loop;
typedef struct regprog regprog_T;
typedef struct syn_state synstate_T;
typedef struct terminal Terminal;
typedef struct window_S win_T;

typedef struct {
  uint32_t nitems;
  uint32_t nbytes;
  char data[];
} AdditionalData;
