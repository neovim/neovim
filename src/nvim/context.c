// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// Context: snapshot of the entire editor state as one big object/map

#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

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
#include "nvim/gettext.h"
#include "nvim/hashtab.h"
#include "nvim/keycodes.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option.h"
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
  if (ctx->regs.data) {
    msgpack_sbuffer_destroy(&ctx->regs);
  }
  if (ctx->jumps.data) {
    msgpack_sbuffer_destroy(&ctx->jumps);
  }
  if (ctx->bufs.data) {
    msgpack_sbuffer_destroy(&ctx->bufs);
  }
  if (ctx->gvars.data) {
    msgpack_sbuffer_destroy(&ctx->gvars);
  }
  if (ctx->funcs.items) {
    api_free_array(ctx->funcs);
  }
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
    ctx_save_regs(ctx);
  }

  if (flags & kCtxJumps) {
    ctx_save_jumps(ctx);
  }

  if (flags & kCtxBufs) {
    ctx_save_bufs(ctx);
  }

  if (flags & kCtxGVars) {
    ctx_save_gvars(ctx);
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

  OptVal op_shada = get_option_value("shada", NULL, OPT_GLOBAL, NULL);
  set_option_value("shada", STATIC_CSTR_AS_OPTVAL("!,'100,%"), OPT_GLOBAL);

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

  set_option_value("shada", op_shada, OPT_GLOBAL);
  optval_free(op_shada);

  return true;
}

/// Saves the global registers to a context.
///
/// @param  ctx    Save to this context.
static inline void ctx_save_regs(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  msgpack_sbuffer_init(&ctx->regs);
  shada_encode_regs(&ctx->regs);
}

/// Restores the global registers from a context.
///
/// @param  ctx   Restore from this context.
static inline void ctx_restore_regs(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  shada_read_sbuf(&ctx->regs, kShaDaWantInfo | kShaDaForceit);
}

/// Saves the jumplist to a context.
///
/// @param  ctx  Save to this context.
static inline void ctx_save_jumps(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  msgpack_sbuffer_init(&ctx->jumps);
  shada_encode_jumps(&ctx->jumps);
}

/// Restores the jumplist from a context.
///
/// @param  ctx  Restore from this context.
static inline void ctx_restore_jumps(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  shada_read_sbuf(&ctx->jumps, kShaDaWantInfo | kShaDaForceit);
}

/// Saves the buffer list to a context.
///
/// @param  ctx  Save to this context.
static inline void ctx_save_bufs(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  msgpack_sbuffer_init(&ctx->bufs);
  shada_encode_buflist(&ctx->bufs);
}

/// Restores the buffer list from a context.
///
/// @param  ctx  Restore from this context.
static inline void ctx_restore_bufs(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  shada_read_sbuf(&ctx->bufs, kShaDaWantInfo | kShaDaForceit);
}

/// Saves global variables to a context.
///
/// @param  ctx  Save to this context.
static inline void ctx_save_gvars(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  msgpack_sbuffer_init(&ctx->gvars);
  shada_encode_gvars(&ctx->gvars);
}

/// Restores global variables from a context.
///
/// @param  ctx  Restore from this context.
static inline void ctx_restore_gvars(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  shada_read_sbuf(&ctx->gvars, kShaDaWantInfo | kShaDaForceit);
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

/// Convert msgpack_sbuffer to readfile()-style array.
///
/// @param[in]  sbuf  msgpack_sbuffer to convert.
///
/// @return readfile()-style array representation of "sbuf".
static inline Array sbuf_to_array(msgpack_sbuffer sbuf)
{
  list_T *const list = tv_list_alloc(kListLenMayKnow);
  tv_list_append_string(list, "", 0);
  if (sbuf.size > 0) {
    encode_list_write(list, sbuf.data, sbuf.size);
  }

  typval_T list_tv = (typval_T) {
    .v_lock = VAR_UNLOCKED,
    .v_type = VAR_LIST,
    .vval.v_list = list
  };

  Array array = vim_to_object(&list_tv).data.array;
  tv_clear(&list_tv);
  return array;
}

/// Convert readfile()-style array to msgpack_sbuffer.
///
/// @param[in]  array  readfile()-style array to convert.
///
/// @return msgpack_sbuffer with conversion result.
static inline msgpack_sbuffer array_to_sbuf(Array array)
{
  msgpack_sbuffer sbuf;
  msgpack_sbuffer_init(&sbuf);

  typval_T list_tv;
  Error err = ERROR_INIT;
  object_to_vim(ARRAY_OBJ(array), &list_tv, &err);

  if (!encode_vim_list_to_buf(list_tv.vval.v_list, &sbuf.size, &sbuf.data)) {
    emsg(_("E474: Failed to convert list to msgpack string buffer"));
  }
  sbuf.alloc = sbuf.size;

  tv_clear(&list_tv);
  api_clear_error(&err);
  return sbuf;
}

/// Converts Context to Dictionary representation.
///
/// @param[in]  ctx  Context to convert.
///
/// @return Dictionary representing "ctx".
Dictionary ctx_to_dict(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  assert(ctx != NULL);

  Dictionary rv = ARRAY_DICT_INIT;

  PUT(rv, "regs", ARRAY_OBJ(sbuf_to_array(ctx->regs)));
  PUT(rv, "jumps", ARRAY_OBJ(sbuf_to_array(ctx->jumps)));
  PUT(rv, "bufs", ARRAY_OBJ(sbuf_to_array(ctx->bufs)));
  PUT(rv, "gvars", ARRAY_OBJ(sbuf_to_array(ctx->gvars)));
  PUT(rv, "funcs", ARRAY_OBJ(copy_array(ctx->funcs, NULL)));

  return rv;
}

/// Converts Dictionary representation of Context back to Context object.
///
/// @param[in]   dict  Context Dictionary representation.
/// @param[out]  ctx   Context object to store conversion result into.
///
/// @return types of included context items.
int ctx_from_dict(Dictionary dict, Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  assert(ctx != NULL);

  int types = 0;
  for (size_t i = 0; i < dict.size; i++) {
    KeyValuePair item = dict.items[i];
    if (item.value.type != kObjectTypeArray) {
      continue;
    }
    if (strequal(item.key.data, "regs")) {
      types |= kCtxRegs;
      ctx->regs = array_to_sbuf(item.value.data.array);
    } else if (strequal(item.key.data, "jumps")) {
      types |= kCtxJumps;
      ctx->jumps = array_to_sbuf(item.value.data.array);
    } else if (strequal(item.key.data, "bufs")) {
      types |= kCtxBufs;
      ctx->bufs = array_to_sbuf(item.value.data.array);
    } else if (strequal(item.key.data, "gvars")) {
      types |= kCtxGVars;
      ctx->gvars = array_to_sbuf(item.value.data.array);
    } else if (strequal(item.key.data, "funcs")) {
      types |= kCtxFuncs;
      ctx->funcs = copy_object(item.value, NULL).data.array;
    }
  }

  return types;
}
