// Context: snapshot of the entire editor state as one big object/map

#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "nvim/api/keysets_defs.h"
#include "nvim/api/private/converter.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/vimscript.h"
#include "nvim/context.h"
#include "nvim/eval/encode.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/userfunc.h"
#include "nvim/ex_docmd.h"
#include "nvim/hashtab.h"
#include "nvim/keycodes.h"
#include "nvim/memory.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/shada.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "context.c.generated.h"
#endif

int kCtxAll = (kCtxRegs | kCtxJumps | kCtxBufs | kCtxGVars | kCtxSFuncs
               | kCtxFuncs);

static ContextVec ctx_stack = KV_INITIAL_VALUE;

/// Clears and frees the context stack
void ctx_free_all(void)
{
  for (size_t i = 0; i < kv_size(ctx_stack); i++) {
    ctx_free(&kv_A(ctx_stack, i));
  }
  kv_destroy(ctx_stack);
}

/// Returns the size of the context stack.
size_t ctx_size(void)
  FUNC_ATTR_PURE
{
  return kv_size(ctx_stack);
}

/// Returns pointer to Context object with given zero-based index from the top
/// of context stack or NULL if index is out of bounds.
Context *ctx_get(size_t index)
  FUNC_ATTR_PURE
{
  if (index < kv_size(ctx_stack)) {
    return &kv_Z(ctx_stack, index);
  }
  return NULL;
}

/// Free resources used by Context object.
///
/// param[in]  ctx  pointer to Context object to free.
void ctx_free(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  api_free_string(ctx->regs);
  api_free_string(ctx->jumps);
  api_free_string(ctx->bufs);
  api_free_string(ctx->gvars);
  api_free_array(ctx->funcs);
}

/// Saves the editor state to a context.
///
/// If "context" is NULL, pushes context on context stack.
/// Use "flags" to select particular types of context.
///
/// @param  ctx    Save to this context, or push on context stack if NULL.
/// @param  flags  Flags, see ContextTypeFlags enum.
void ctx_save(Context *ctx, const int flags)
{
  if (ctx == NULL) {
    kv_push(ctx_stack, CONTEXT_INIT);
    ctx = &kv_last(ctx_stack);
  }

  if (flags & kCtxRegs) {
    ctx->regs = shada_encode_regs();
  }

  if (flags & kCtxJumps) {
    ctx->jumps = shada_encode_jumps();
  }

  if (flags & kCtxBufs) {
    ctx->bufs = shada_encode_buflist();
  }

  if (flags & kCtxGVars) {
    ctx->gvars = shada_encode_gvars();
  }

  if (flags & kCtxFuncs) {
    ctx_save_funcs(ctx, false);
  } else if (flags & kCtxSFuncs) {
    ctx_save_funcs(ctx, true);
  }
}

/// Restores the editor state from a context.
///
/// If "context" is NULL, pops context from context stack.
/// Use "flags" to select particular types of context.
///
/// @param  ctx    Restore from this context. Pop from context stack if NULL.
/// @param  flags  Flags, see ContextTypeFlags enum.
///
/// @return true on success, false otherwise (i.e.: empty context stack).
bool ctx_restore(Context *ctx, const int flags)
{
  bool free_ctx = false;
  if (ctx == NULL) {
    if (ctx_stack.size == 0) {
      return false;
    }
    ctx = &kv_pop(ctx_stack);
    free_ctx = true;
  }

  OptVal op_shada = get_option_value(kOptShada, OPT_GLOBAL);
  set_option_value(kOptShada, STATIC_CSTR_AS_OPTVAL("!,'100,%"), OPT_GLOBAL);

  if (flags & kCtxRegs) {
    ctx_restore_regs(ctx);
  }

  if (flags & kCtxJumps) {
    ctx_restore_jumps(ctx);
  }

  if (flags & kCtxBufs) {
    ctx_restore_bufs(ctx);
  }

  if (flags & kCtxGVars) {
    ctx_restore_gvars(ctx);
  }

  if (flags & kCtxFuncs) {
    ctx_restore_funcs(ctx);
  }

  if (free_ctx) {
    ctx_free(ctx);
  }

  set_option_value(kOptShada, op_shada, OPT_GLOBAL);
  optval_free(op_shada);

  return true;
}

/// Restores the global registers from a context.
///
/// @param  ctx   Restore from this context.
static inline void ctx_restore_regs(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  shada_read_string(ctx->regs, kShaDaWantInfo | kShaDaForceit);
}

/// Restores the jumplist from a context.
///
/// @param  ctx  Restore from this context.
static inline void ctx_restore_jumps(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  shada_read_string(ctx->jumps, kShaDaWantInfo | kShaDaForceit);
}

/// Restores the buffer list from a context.
///
/// @param  ctx  Restore from this context.
static inline void ctx_restore_bufs(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  shada_read_string(ctx->bufs, kShaDaWantInfo | kShaDaForceit);
}

/// Restores global variables from a context.
///
/// @param  ctx  Restore from this context.
static inline void ctx_restore_gvars(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  shada_read_string(ctx->gvars, kShaDaWantInfo | kShaDaForceit);
}

/// Saves functions to a context.
///
/// @param  ctx         Save to this context.
/// @param  scriptonly  Save script-local (s:) functions only.
static inline void ctx_save_funcs(Context *ctx, bool scriptonly)
  FUNC_ATTR_NONNULL_ALL
{
  ctx->funcs = (Array)ARRAY_DICT_INIT;
  Error err = ERROR_INIT;

  HASHTAB_ITER(func_tbl_get(), hi, {
    const char *const name = hi->hi_key;
    bool islambda = (strncmp(name, "<lambda>", 8) == 0);
    bool isscript = ((uint8_t)name[0] == K_SPECIAL);

    if (!islambda && (!scriptonly || isscript)) {
      size_t cmd_len = sizeof("func! ") + strlen(name);
      char *cmd = xmalloc(cmd_len);
      snprintf(cmd, cmd_len, "func! %s", name);
      Dict(exec_opts) opts = { .output = true };
      String func_body = exec_impl(VIML_INTERNAL_CALL, cstr_as_string(cmd),
                                   &opts, &err);
      xfree(cmd);
      if (!ERROR_SET(&err)) {
        ADD(ctx->funcs, STRING_OBJ(func_body));
      }
      api_clear_error(&err);
    }
  });
}

/// Restores functions from a context.
///
/// @param  ctx  Restore from this context.
static inline void ctx_restore_funcs(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  for (size_t i = 0; i < ctx->funcs.size; i++) {
    do_cmdline_cmd(ctx->funcs.items[i].data.string.data);
  }
}

/// Convert readfile()-style array to String
///
/// @param[in]  array  readfile()-style array to convert.
/// @param[out]  err   Error object.
///
/// @return String with conversion result.
static inline String array_to_string(Array array, Error *err)
  FUNC_ATTR_NONNULL_ALL
{
  String sbuf = STRING_INIT;

  typval_T list_tv;
  object_to_vim(ARRAY_OBJ(array), &list_tv, err);

  assert(list_tv.v_type == VAR_LIST);
  if (!encode_vim_list_to_buf(list_tv.vval.v_list, &sbuf.size, &sbuf.data)) {
    api_set_error(err, kErrorTypeException, "%s",
                  "E474: Failed to convert list to msgpack string buffer");
  }

  tv_clear(&list_tv);
  return sbuf;
}

/// Converts Context to Dict representation.
///
/// @param[in]  ctx  Context to convert.
///
/// @return Dict representing "ctx".
Dict ctx_to_dict(Context *ctx, Arena *arena)
  FUNC_ATTR_NONNULL_ALL
{
  assert(ctx != NULL);

  Dict rv = arena_dict(arena, 5);

  PUT_C(rv, "regs", ARRAY_OBJ(string_to_array(ctx->regs, false, arena)));
  PUT_C(rv, "jumps", ARRAY_OBJ(string_to_array(ctx->jumps, false, arena)));
  PUT_C(rv, "bufs", ARRAY_OBJ(string_to_array(ctx->bufs, false, arena)));
  PUT_C(rv, "gvars", ARRAY_OBJ(string_to_array(ctx->gvars, false, arena)));
  PUT_C(rv, "funcs", ARRAY_OBJ(copy_array(ctx->funcs, arena)));

  return rv;
}

/// Converts Dict representation of Context back to Context object.
///
/// @param[in]   dict  Context Dict representation.
/// @param[out]  ctx   Context object to store conversion result into.
/// @param[out]  err   Error object.
///
/// @return types of included context items.
int ctx_from_dict(Dict dict, Context *ctx, Error *err)
  FUNC_ATTR_NONNULL_ALL
{
  assert(ctx != NULL);

  int types = 0;
  for (size_t i = 0; i < dict.size && !ERROR_SET(err); i++) {
    KeyValuePair item = dict.items[i];
    if (item.value.type != kObjectTypeArray) {
      continue;
    }
    if (strequal(item.key.data, "regs")) {
      types |= kCtxRegs;
      ctx->regs = array_to_string(item.value.data.array, err);
    } else if (strequal(item.key.data, "jumps")) {
      types |= kCtxJumps;
      ctx->jumps = array_to_string(item.value.data.array, err);
    } else if (strequal(item.key.data, "bufs")) {
      types |= kCtxBufs;
      ctx->bufs = array_to_string(item.value.data.array, err);
    } else if (strequal(item.key.data, "gvars")) {
      types |= kCtxGVars;
      ctx->gvars = array_to_string(item.value.data.array, err);
    } else if (strequal(item.key.data, "funcs")) {
      types |= kCtxFuncs;
      ctx->funcs = copy_object(item.value, NULL).data.array;
    }
  }

  return types;
}
