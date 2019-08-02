// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// Context: snapshot of the entire editor state as one big object/map

#include "nvim/context.h"
#include "nvim/eval/encode.h"
#include "nvim/ex_docmd.h"
#include "nvim/option.h"
#include "nvim/shada.h"
#include "nvim/api/vim.h"
#include "nvim/api/private/helpers.h"
#include "nvim/msgpack_rpc/helpers.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "context.c.generated.h"
#endif

int kCtxAll = (kCtxRegs | kCtxJumps | kCtxBuflist | kCtxGVars | kCtxSFuncs
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
{
  return kv_size(ctx_stack);
}

/// Returns pointer to Context object with given zero-based index from the top
/// of context stack or NULL if index is out of bounds.
Context *ctx_get(size_t index)
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
  if (ctx->buflist.data) {
    msgpack_sbuffer_destroy(&ctx->buflist);
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

  if (flags & kCtxBuflist) {
    ctx_save_buflist(ctx);
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

  char_u *op_shada;
  get_option_value((char_u *)"shada", NULL, &op_shada, OPT_GLOBAL);
  set_option_value("shada", 0L, "!,'100,%", OPT_GLOBAL);

  if (flags & kCtxRegs) {
    ctx_restore_regs(ctx);
  }

  if (flags & kCtxJumps) {
    ctx_restore_jumps(ctx);
  }

  if (flags & kCtxBuflist) {
    ctx_restore_buflist(ctx);
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

  set_option_value("shada", 0L, (char *)op_shada, OPT_GLOBAL);
  xfree(op_shada);

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
static inline void ctx_save_buflist(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  msgpack_sbuffer_init(&ctx->buflist);
  shada_encode_buflist(&ctx->buflist);
}

/// Restores the buffer list from a context.
///
/// @param  ctx  Restore from this context.
static inline void ctx_restore_buflist(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  shada_read_sbuf(&ctx->buflist, kShaDaWantInfo | kShaDaForceit);
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

  HASHTAB_ITER(&func_hashtab, hi, {
    const char_u *const name = hi->hi_key;
    bool islambda = (STRNCMP(name, "<lambda>", 8) == 0);
    bool isscript = (name[0] == K_SPECIAL);

    if (!islambda && (!scriptonly || isscript)) {
      size_t cmd_len = sizeof("func! ") + STRLEN(name);
      char *cmd = xmalloc(cmd_len);
      snprintf(cmd, cmd_len, "func! %s", name);
      String func_body = nvim_command_output(cstr_as_string(cmd), &err);
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

/// Unpack a msgpack_sbuffer into an Array of API Objects.
///
/// @param[in]  sbuf  msgpack_sbuffer to read from.
///
/// @return Array of API Objects unpacked from given msgpack_sbuffer.
static inline Array sbuf_to_array(msgpack_sbuffer sbuf)
{
  Array rv = ARRAY_DICT_INIT;

  if (sbuf.size == 0) {
    return rv;
  }

  msgpack_unpacker *const unpacker = msgpack_unpacker_new(IOSIZE);
  if (unpacker == NULL) {
    EMSG(_(e_outofmem));
    return rv;
  }

  msgpack_unpacked unpacked;
  msgpack_unpacked_init(&unpacked);

  if (!msgpack_unpacker_reserve_buffer(unpacker, IOSIZE)) {
    EMSG(_(e_outofmem));
    goto exit;
  }

  bool did_try_to_free = false;
  size_t offset = 0;
  while (offset < sbuf.size) {
    size_t read_bytes = MIN(IOSIZE, sbuf.size - offset);
    memcpy(msgpack_unpacker_buffer(unpacker), sbuf.data + offset, read_bytes);
    msgpack_unpacker_buffer_consumed(unpacker, read_bytes);
    while (unpacker->off < unpacker->used) {
      Object obj = OBJECT_INIT;
      msgpack_unpack_return ret = msgpack_unpacker_next(unpacker, &unpacked);
      switch (ret) {
        case MSGPACK_UNPACK_SUCCESS:
          msgpack_rpc_to_object(&unpacked.data, &obj);
          ADD(rv, obj);
          break;
        case MSGPACK_UNPACK_CONTINUE:
          EMSG("Incomplete msgpack string");
          goto exit;
        case MSGPACK_UNPACK_EXTRA_BYTES:
          EMSG("Extra bytes in msgpack string");
          goto exit;
        case MSGPACK_UNPACK_PARSE_ERROR:
          EMSG("Failed to parse msgpack string");
          goto exit;
        case MSGPACK_UNPACK_NOMEM_ERROR:
          if (!did_try_to_free) {
            did_try_to_free = true;
            try_to_free_memory();
          } else {
            EMSG(_(e_outofmem));
            goto exit;
          }
          break;
      }
    }
    offset += read_bytes;
  }

exit:
  msgpack_unpacked_destroy(&unpacked);
  msgpack_unpacker_free(unpacker);
  return rv;
}

/// Pack API Objects from an Array into a msgpack_sbuffer.
///
/// @param[in]  array  Array of API Objects to pack.
///
/// @return msgpack_sbuffer with packed objects.
static inline msgpack_sbuffer array_to_sbuf(Array array)
{
  msgpack_sbuffer sbuf;
  msgpack_sbuffer_init(&sbuf);
  msgpack_packer *packer = msgpack_packer_new(&sbuf, msgpack_sbuffer_write);

  for (size_t i = 0; i < array.size; i++) {
    Error err = ERROR_INIT;
    typval_T tv = TV_INITIAL_VALUE;
    // TODO(abdelhakeem): refactor ShaDa module to avoid stuff like this
    if (object_to_vim(array.items[i], &tv, &err)) {
      encode_vim_to_msgpack(packer, &tv, "");
      tv_clear(&tv);
    }
    api_clear_error(&err);
  }

  msgpack_packer_free(packer);
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
  PUT(rv, "buflist", ARRAY_OBJ(sbuf_to_array(ctx->buflist)));
  PUT(rv, "gvars", ARRAY_OBJ(sbuf_to_array(ctx->gvars)));
  PUT(rv, "funcs", ARRAY_OBJ(copy_array(ctx->funcs)));

  return rv;
}

/// Converts Dictionary representation of Context back to Context object.
///
/// @param[in]   dict  Context Dictionary representation.
/// @param[out]  ctx   Context object to store conversion result into.
///
/// @return true on success, false otherwise
bool ctx_from_dict(Dictionary dict, Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  assert(ctx != NULL);

  int save_did_emsg = did_emsg;
  did_emsg = false;

  for (size_t i = 0; i < dict.size; i++) {
    KeyValuePair item = dict.items[i];
    if (item.value.type != kObjectTypeArray) {
      continue;
    }
    if (strequal(item.key.data, "regs")) {
      ctx->regs = array_to_sbuf(item.value.data.array);
    } else if (strequal(item.key.data, "jumps")) {
      ctx->jumps = array_to_sbuf(item.value.data.array);
    } else if (strequal(item.key.data, "buflist")) {
      ctx->buflist = array_to_sbuf(item.value.data.array);
    } else if (strequal(item.key.data, "gvars")) {
      ctx->gvars = array_to_sbuf(item.value.data.array);
    } else if (strequal(item.key.data, "funcs")) {
      ctx->funcs = copy_object(item.value).data.array;
    }
  }

  bool result = !did_emsg;
  did_emsg = save_did_emsg;
  return result;
}
