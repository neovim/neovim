#ifndef NVIM_EVAL_USERFUNC_H
#define NVIM_EVAL_USERFUNC_H

#include "nvim/eval/typval.h"
#include "nvim/ex_cmds_defs.h"

// From user function to hashitem and back.
#define UF2HIKEY(fp) ((fp)->uf_name)
#define HIKEY2UF(p)  ((ufunc_T *)(p - offsetof(ufunc_T, uf_name)))
#define HI2UF(hi)    HIKEY2UF((hi)->hi_key)

// flags used in uf_flags
#define FC_ABORT    0x01          // abort function on error
#define FC_RANGE    0x02          // function accepts range
#define FC_DICT     0x04          // Dict function, uses "self"
#define FC_CLOSURE  0x08          // closure, uses outer scope variables
#define FC_DELETED  0x10          // :delfunction used while uf_refcount > 0
#define FC_REMOVED  0x20          // function redefined while uf_refcount > 0
#define FC_SANDBOX  0x40          // function defined in the sandbox
#define FC_DEAD     0x80          // function kept only for reference to dfunc
#define FC_EXPORT   0x100         // "export def Func()"
#define FC_NOARGS   0x200         // no a: variables in lambda
#define FC_VIM9     0x400         // defined in vim9 script file
#define FC_LUAREF  0x800          // luaref callback

///< Structure used by trans_function_name()
typedef struct {
  dict_T *fd_dict;  ///< Dictionary used.
  char_u *fd_newkey;  ///< New key in "dict" in allocated memory.
  dictitem_T *fd_di;  ///< Dictionary item used.
} funcdict_T;

typedef struct funccal_entry funccal_entry_T;
struct funccal_entry {
  void *top_funccal;
  funccal_entry_T *next;
};

/// errors for when calling a function
typedef enum {
  ERROR_UNKNOWN = 0,
  ERROR_TOOMANY,
  ERROR_TOOFEW,
  ERROR_SCRIPT,
  ERROR_DICT,
  ERROR_NONE,
  ERROR_OTHER,
  ERROR_BOTH,
  ERROR_DELETED,
  ERROR_NOTMETHOD,
} FnameTransError;

/// Used in funcexe_T. Returns the new argcount.
typedef int (*ArgvFunc)(int current_argcount, typval_T *argv, int argskip,
                        int called_func_argcount);

/// Structure passed between functions dealing with function call execution.
typedef struct {
  ArgvFunc argv_func;  ///< when not NULL, can be used to fill in arguments only
                       ///< when the invoked function uses them
  linenr_T firstline;  ///< first line of range
  linenr_T lastline;   ///< last line of range
  bool *doesrange;     ///< [out] if not NULL: function handled range
  bool evaluate;       ///< actually evaluate expressions
  partial_T *partial;  ///< for extra arguments
  dict_T *selfdict;    ///< Dictionary for "self"
  typval_T *basetv;    ///< base for base->method()
} funcexe_T;

#define FUNCEXE_INIT (funcexe_T) { \
  .argv_func = NULL, \
  .firstline = 0, \
  .lastline = 0, \
  .doesrange = NULL, \
  .evaluate = false, \
  .partial = NULL, \
  .selfdict = NULL, \
  .basetv = NULL, \
}

#define FUNCARG(fp, j)  ((char **)(fp->uf_args.ga_data))[j]
#define FUNCLINE(fp, j) ((char **)(fp->uf_lines.ga_data))[j]

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/userfunc.h.generated.h"
#endif
#endif  // NVIM_EVAL_USERFUNC_H
