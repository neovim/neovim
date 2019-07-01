// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// Context: snapshot of the entire editor state as one big object/map:
//    - editor state (cf. shada.c): registers, variables, ...
//    - [not implemented] cursor position
//    - [not implemented] VimL variables (g:, ...?)
//    - [not implemented] tracking edits (mark_ext.c)
//    - [not implemented] options?

#include "nvim/os/os.h"
#include "nvim/api/private/helpers.h"
#include "nvim/context.h"
#include "nvim/fileio.h"
#include "nvim/vim.h"
#include "nvim/main.h"
#include "nvim/ops.h"
#include "nvim/ui.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "context.c.generated.h"
#endif

int kCtxAll = (kCtxReg | kCtxVimscript | kCtxOptions);

// typedef struct {
//   char name;
//   MotionType type;
//   char **contents;
//   bool is_unnamed;
//   size_t contents_size;
//   size_t width;
//   dict_T *additional_data;
// } Reg;

Context last_ctx = {
  .pos = {
    .lnum = 0,
    .col = 0,
    .coladd = 0,
  },
  .reg = NULL,
};

/// Saves the editor state to a context.
///
/// If `context` is NULL, saves to a default internal store.
/// Use `flags` to select particular types of context.
///
/// @param  ctx    Save to this context, or to default store if NULL.
/// @param  flags  Flags, see ContextTypeFlags enum.
void ctx_save(Context *ctx, const int flags)
{
  if (flags & kCtxReg) {
    ctx_save_reg(ctx);
  }
  // TODO(justinmk)
  // if (flags & kCtxVimscript) {
  // }
  // if (flags & kCtxOptions) {
  // }
  // ...
}

/// Restores the editor state from a context.
///
/// If `context` is NULL, restores from the default internal store.
/// Use `flags` to select particular types of context.
///
/// @param  ctx    Save to this context, or to default store if NULL.
/// @param  flags  Flags, see ContextTypeFlags enum.
void ctx_restore(Context *ctx, const int flags)
{
  if (flags & kCtxReg) {
    ctx_restore_reg(ctx);
  }
  // TODO(justinmk)
  // if (flags & kCtxVimscript) {
  // }
  // if (flags & kCtxOptions) {
  // }
  // ...
}

/// Saves the global registers to a context. If `context` is NULL, saves to
/// a default internal store.
///
/// @param  ctx    Save to this context, or to default store if NULL.
void ctx_save_reg(Context *ctx)
{
  if (ctx == NULL) {
    ctx = &last_ctx;
  }
  if (ctx->reg == NULL) {
    ctx->reg = xmalloc(NUM_REGISTERS * sizeof(*ctx->reg));
  }
  const void *reg_iter = NULL;
  do {
    yankreg_T reg;
    char name = NUL;
    bool is_unnamed = false;
    reg_iter = op_global_reg_iter(reg_iter, &name, &reg, &is_unnamed);
    if (name == NUL) {
      // TODO(justinmk): when does this happen?
      break;
    }
    ctx->reg[op_reg_index(name)] = copy_register(name);
  } while (reg_iter != NULL);
}

/// Restores the global registers from a context.
///
/// If `context` is NULL, restores from the default internal store.
///
/// @param  ctx   Restore from this context, or from default store if NULL.
void ctx_restore_reg(Context *ctx)
{
  if (ctx == NULL) {
    ctx = &last_ctx;
  }
  assert(ctx->reg != NULL);
  const void *reg_iter = NULL;
  // Abuse op_global_reg_iter() because we don't store the register name.
  // This requires `ctx->reg` to be stored in the same order.
  do {
    yankreg_T reg;
    char name = NUL;
    bool is_unnamed = false;
    reg_iter = op_global_reg_iter(reg_iter, &name, &reg, &is_unnamed);
    if (name == NUL) {
      // TODO(justinmk): when does this happen?
      break;
    }

    yankreg_T *saved_reg = ctx->reg[op_reg_index(name)];
    if (!op_reg_set(name, *saved_reg, is_unnamed)) {
      abort();  // failed somehow?
      // xfree(saved_reg);
    }
  } while (reg_iter != NULL);
}

Dictionary ctx_to_dict(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  assert(ctx != NULL);
  Dictionary rv = ARRAY_DICT_INIT;

  Dictionary pos_dict = ARRAY_DICT_INIT;
  PUT(pos_dict, "lnum", INTEGER_OBJ(ctx->pos.lnum));
  PUT(pos_dict, "col", INTEGER_OBJ(ctx->pos.col));
  PUT(pos_dict, "coladd", INTEGER_OBJ(ctx->pos.coladd));
  PUT(rv, "pos", DICTIONARY_OBJ(pos_dict));

  Dictionary regs_dict = ARRAY_DICT_INIT;
  // PUT(rv, "reg", DICTIONARY_OBJ(pos_dict));
  // Convert registers.
  const void *reg_iter = NULL;

  // Abuse op_global_reg_iter() because we don't store the register name.
  // This requires `ctx->reg` to be stored in the same order.
  do {
    yankreg_T reg;
    char name[2] = { 0 };
    bool is_un = false;
    // reg_iter = op_register_iter(reg_iter, *(ctx->reg), &name, &reg,
    // yankreg_T *saved_reg = ctx->reg[op_reg_index(name)];
    reg_iter = op_global_reg_iter(reg_iter, &name[0], &reg, &is_un);
    if (name[0] == NUL) {
      break;
    }

    reg = *ctx->reg[op_reg_index(name[0])];
    Dictionary reg_dict = ARRAY_DICT_INIT;

    // lines
    Array lines = ARRAY_DICT_INIT;
    for (size_t i = 0; i < reg.y_size; i++) {
      // TODO: can we avoid the copy here?
      ADD(lines, STRING_OBJ(cstr_to_string((char *)reg.y_array[i])));
    }
    PUT(reg_dict, "lines", ARRAY_OBJ(lines));
    PUT(regs_dict, name, DICTIONARY_OBJ(reg_dict));
  } while (reg_iter != NULL);


  PUT(rv, "reg", DICTIONARY_OBJ(regs_dict));

  return rv;
}
