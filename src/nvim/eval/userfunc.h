#pragma once

#include <stdbool.h>
#include <stddef.h>

#include "nvim/cmdexpand_defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"
#include "nvim/eval_defs.h"  // IWYU pragma: keep
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/hashtab_defs.h"  // IWYU pragma: keep
#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"  // IWYU pragma: keep

// From user function to hashitem and back.
#define UF2HIKEY(fp) ((fp)->uf_name)
#define HIKEY2UF(p)  ((ufunc_T *)((p) - offsetof(ufunc_T, uf_name)))
#define HI2UF(hi)    HIKEY2UF((hi)->hi_key)

// flags used in uf_flags
#define FC_ABORT    0x01          // abort function on error
#define FC_RANGE    0x02          // function accepts range
#define FC_DICT     0x04          // Dict function, uses "self"
#define FC_CLOSURE  0x08          // closure, uses outer scope variables
#define FC_DELETED  0x10          // :delfunction used while uf_refcount > 0
#define FC_REMOVED  0x20          // function redefined while uf_refcount > 0
#define FC_SANDBOX  0x40          // function defined in the sandbox
// #define FC_DEAD     0x80          // function kept only for reference to dfunc
// #define FC_EXPORT   0x100         // "export def Func()"
#define FC_NOARGS   0x200         // no a: variables in lambda
// #define FC_VIM9     0x400         // defined in vim9 script file
#define FC_LUAREF  0x800          // luaref callback

/// Structure used by trans_function_name()
typedef struct {
  dict_T *fd_dict;    ///< Dict used.
  char *fd_newkey;    ///< New key in "dict" in allocated memory.
  dictitem_T *fd_di;  ///< Dict item used.
} funcdict_T;

typedef struct funccal_entry funccal_entry_T;
struct funccal_entry {
  void *top_funccal;
  funccal_entry_T *next;
};

/// errors for when calling a function
typedef enum {
  FCERR_UNKNOWN = 0,
  FCERR_TOOMANY = 1,
  FCERR_TOOFEW = 2,
  FCERR_SCRIPT = 3,
  FCERR_DICT = 4,
  FCERR_NONE = 5,
  FCERR_OTHER = 6,
  FCERR_DELETED = 7,
  FCERR_NOTMETHOD = 8,  ///< function cannot be used as a method
} FnameTransError;

/// Used in funcexe_T. Returns the new argcount.
typedef int (*ArgvFunc)(int current_argcount, typval_T *argv, int partial_argcount,
                        ufunc_T *called_func);

/// Structure passed between functions dealing with function call execution.
typedef struct {
  ArgvFunc fe_argv_func;  ///< when not NULL, can be used to fill in arguments only
                          ///< when the invoked function uses them
  linenr_T fe_firstline;  ///< first line of range
  linenr_T fe_lastline;   ///< last line of range
  bool *fe_doesrange;     ///< [out] if not NULL: function handled range
  bool fe_evaluate;       ///< actually evaluate expressions
  partial_T *fe_partial;  ///< for extra arguments
  dict_T *fe_selfdict;    ///< Dict for "self"
  typval_T *fe_basetv;    ///< base for base->method()
  bool fe_found_var;      ///< if the function is not found then give an
                          ///< error that a variable is not callable.
} funcexe_T;

#define FUNCEXE_INIT (funcexe_T) { \
  .fe_argv_func = NULL, \
  .fe_firstline = 0, \
  .fe_lastline = 0, \
  .fe_doesrange = NULL, \
  .fe_evaluate = false, \
  .fe_partial = NULL, \
  .fe_selfdict = NULL, \
  .fe_basetv = NULL, \
  .fe_found_var = false, \
}

#define FUNCARG(fp, j)  ((char **)(fp->uf_args.ga_data))[j]
#define FUNCLINE(fp, j) ((char **)(fp->uf_lines.ga_data))[j]

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/userfunc.h.generated.h"
#endif
