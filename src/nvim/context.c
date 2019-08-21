// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// Context: snapshot of the entire editor state as one big object/map

#include "nvim/context.h"
#include "nvim/eval/encode.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_docmd.h"
#include "nvim/option.h"
#include "nvim/shada.h"
#include "nvim/api/vim.h"
#include "nvim/api/private/helpers.h"
#include "nvim/msgpack_rpc/helpers.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "context.c.generated.h"
#endif

int kCtxAll = (kCtxRegs | kCtxJumps | kCtxBuflist | kCtxSVars | kCtxGVars
               | kCtxBVars | kCtxWVars | kCtxTVars | kCtxLVars | kCtxSFuncs
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
  if (ctx->regs.size) {
    msgpack_sbuffer_destroy(&ctx->regs);
  }
  if (ctx->jumps.size) {
    msgpack_sbuffer_destroy(&ctx->jumps);
  }
  if (ctx->buflist.size) {
    msgpack_sbuffer_destroy(&ctx->buflist);
  }
  if (ctx->vars.size) {
    msgpack_sbuffer_destroy(&ctx->vars);
  }
  if (ctx->funcs.items) {
    api_free_array(ctx->funcs);
  }
  *ctx = CONTEXT_INIT;
}

/// Saves the editor state to a context.
///
/// If "context" is NULL, pushes context on context stack.
/// Use "flags" to select particular types of context.
///
/// @param[in]  ctx    Save to this context, or push on context stack if NULL.
/// @param[in]  flags  Flags, see ContextTypeFlags enum.
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

  if ((flags & kCtxSVars) && (current_sctx.sc_sid > 0)
      && (current_sctx.sc_sid <= ga_scripts.ga_len)) {
    ctx_save_vars(&SCRIPT_VARS(current_sctx.sc_sid), ctx, "s:");
  }

  if (flags & kCtxGVars) {
    ctx_save_vars(&globvarht, ctx, "g:");
  }

  if (flags & kCtxBVars) {
    ctx_save_vars(&curbuf->b_vars->dv_hashtab, ctx, "b:");
  }

  if (flags & kCtxWVars) {
    ctx_save_vars(&curwin->w_vars->dv_hashtab, ctx, "w:");
  }

  if (flags & kCtxTVars) {
    ctx_save_vars(&curtab->tp_vars->dv_hashtab, ctx, "t:");
  }

  hashtab_T *funccal_local_ht = get_funccal_local_ht();
  if ((flags & kCtxLVars) && funccal_local_ht) {
    ctx_save_vars(funccal_local_ht, ctx, "l:");
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
/// @param[in]   ctx    Restore from this context.
///                     Pop from context stack if NULL.
/// @param[out]  err    Error details, if any.
void ctx_restore(Context *ctx, Error *err)
{
  bool free_ctx = false;
  if (ctx == NULL) {
    if (ctx_stack.size == 0) {
      api_set_error(err, kErrorTypeValidation, "Context stack is empty");
      return;
    }
    ctx = &kv_pop(ctx_stack);
    free_ctx = true;
  }

  try_start();

  char_u *op_shada;
  get_option_value((char_u *)"shada", NULL, &op_shada, OPT_GLOBAL);
  set_option_value("shada", 0L, "!,'100,%", OPT_GLOBAL);

  ctx_restore_regs(ctx);
  ctx_restore_jumps(ctx);
  ctx_restore_buflist(ctx);
  ctx_restore_vars(ctx);
  ctx_restore_funcs(ctx);

  if (free_ctx) {
    ctx_free(ctx);
  }

  set_option_value("shada", 0L, (char *)op_shada, OPT_GLOBAL);
  xfree(op_shada);

  try_end(err);
}

/// Saves the global registers to a context.
///
/// @param[in]  ctx    Save to this context.
static inline void ctx_save_regs(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  msgpack_sbuffer_init(&ctx->regs);
  shada_encode_regs(&ctx->regs);
}

/// Restores the global registers from a context.
///
/// @param[in]  ctx   Restore from this context.
static inline void ctx_restore_regs(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  shada_read_sbuf(&ctx->regs, kShaDaWantInfo | kShaDaForceit);
}

/// Saves the jumplist to a context.
///
/// @param[in]  ctx  Save to this context.
static inline void ctx_save_jumps(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  msgpack_sbuffer_init(&ctx->jumps);
  shada_encode_jumps(&ctx->jumps);
}

/// Restores the jumplist from a context.
///
/// @param[in]  ctx  Restore from this context.
static inline void ctx_restore_jumps(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  shada_read_sbuf(&ctx->jumps, kShaDaWantInfo | kShaDaForceit);
}

/// Saves the buffer list to a context.
///
/// @param[in]  ctx  Save to this context.
static inline void ctx_save_buflist(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  msgpack_sbuffer_init(&ctx->buflist);
  shada_encode_buflist(&ctx->buflist);
}

/// Restores the buffer list from a context.
///
/// @param[in]  ctx  Restore from this context.
static inline void ctx_restore_buflist(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  shada_read_sbuf(&ctx->buflist, kShaDaWantInfo | kShaDaForceit);
}

/// Saves variables from given hashtable to a context.
///
/// @param[in]  ht      Hashtable to read variables from.
/// @param[in]  ctx     Save to this context.
/// @param[in]  prefix  String to be prefixed to variable names or NULL.
static inline void ctx_save_vars(const hashtab_T *ht, Context *ctx,
                                 const char *prefix)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  if (ctx->vars.size == 0) {
    msgpack_sbuffer_init(&ctx->vars);
  }
  shada_encode_vars(ht, &ctx->vars, prefix);
}

/// Restores variables from a context.
///
/// @param[in]  ctx  Restore from this context.
static inline void ctx_restore_vars(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  shada_read_sbuf(&ctx->vars,
                  kShaDaWantInfo | kShaDaForceit | kShadaKeepFunccall);
}

/// Packs a context function entry.
///
/// For lambda functions, the name of the packed function is changed because
/// lambda functions cannot be defined with ":func" or directly called, hence
/// they will be prefixed with "<SNR>_lambda_" instead of "<lambda>".
///
/// @param[in]   fp   Function pointer.
/// @param[out]  err  Error details, if any.
///
/// @return Function entry as a Dictionary.
Dictionary ctx_pack_func(ufunc_T *fp, Error *err)
  FUNC_ATTR_NONNULL_ALL
{
  Dictionary entry = ARRAY_DICT_INIT;
  Array args = ARRAY_DICT_INIT;
  ADD(args, STRING_OBJ(cstr_as_string((char *)fp->uf_name)));
  Object def = EXEC_LUA_STATIC("return vim._ctx_get_func_def(...)", args, err);
  xfree(args.items);

  if (ERROR_SET(err)) {
    api_free_object(def);
    goto end;
  }

  PUT(entry, "definition", def);
  PUT(entry, "sid", INTEGER_OBJ(fp->uf_script_ctx.sc_sid));
  if (fp->uf_flags & FC_SANDBOX) {
    PUT(entry, "sandboxed", BOOLEAN_OBJ(true));
  }

end:
  return entry;
}

void ctx_set_current_SID(scid_T new_current_SID)
{
  current_sctx.sc_sid = new_current_SID;
  if (new_current_SID > 0) {
    script_items_grow();
    new_script_vars(new_current_SID);
  }
}

#define CONTEXT_UNPACK_KEY(kv, _key, _type, err) \
  if (strequal((#_key), (kv)->key.data)) { \
    if ((kv)->value.type != (_type)) { \
      api_set_error((err), kErrorTypeValidation, \
                    "Invalid type for '" #_key "'"); \
      return; \
    } \
    (_key) = (kv)->value; \
    continue; \
  }

#define CONTEXT_CHECK_KEY(key, err) \
  if ((key).type == kObjectTypeNil) { \
    api_set_error((err), kErrorTypeValidation, "Missing '" #key "'"); \
    return; \
  }

void ctx_unpack_func(Dictionary func, Error *err)
  FUNC_ATTR_NONNULL_ARG(2)
{
  Object definition = OBJECT_INIT;
  Object sid = OBJECT_INIT;
  Object sandboxed = OBJECT_INIT;

  for (size_t i = 0; i < func.size; i++) {
    KeyValuePair *kv = &func.items[i];
    CONTEXT_UNPACK_KEY(kv, definition, kObjectTypeString, err);
    CONTEXT_UNPACK_KEY(kv, sid, kObjectTypeInteger, err);
    CONTEXT_UNPACK_KEY(kv, sandboxed, kObjectTypeBoolean, err);
  }

  CONTEXT_CHECK_KEY(definition, err);
  CONTEXT_CHECK_KEY(sid, err);

  // Set current_sctx.sc_sid to function SID
  scid_T save_current_SID = current_sctx.sc_sid;
  ctx_set_current_SID((int)sid.data.integer);

  // Handle sandboxed function
  if (sandboxed.type == kObjectTypeBoolean && sandboxed.data.boolean
      && definition.data.string.size > sizeof("function!")) {
    memcpy(definition.data.string.data, S_LEN("san fu!  "));
  }

  // Define function
  nvim_command(definition.data.string, err);

  // Restore previous current_sctx.sc_sid
  current_sctx.sc_sid = save_current_SID;
}

#undef CONTEXT_CHECK_KEY
#undef CONTEXT_UNPACK_KEY

/// Saves functions to a context.
///
/// @param[in]  ctx         Save to this context.
/// @param[in]  scriptonly  Save script-local (s:) functions only.
static inline void ctx_save_funcs(Context *ctx, bool scriptonly)
  FUNC_ATTR_NONNULL_ALL
{
  ctx->funcs = (Array)ARRAY_DICT_INIT;
  Error err = ERROR_INIT;

  HASHTAB_ITER(&func_hashtab, hi, {
    ufunc_T *fp = HI2UF(hi);
    bool islambda = ISLAMBDA(fp->uf_name);
    bool isscript = (fp->uf_name[0] == K_SPECIAL) && !islambda;

    if (!islambda && (!scriptonly || isscript)) {
      Dictionary func = ctx_pack_func(fp, &err);
      if (ERROR_SET(&err)) {
        EMSG2("Context: function: %s", err.msg);
        api_clear_error(&err);
        continue;
      }
      ADD(ctx->funcs, DICTIONARY_OBJ(func));
    }
  });
}

/// Restores functions from a context.
///
/// @param[in]  ctx  Restore from this context.
static inline void ctx_restore_funcs(Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  for (size_t i = 0; i < ctx->funcs.size; i++) {
    if (ctx->funcs.items[i].type != kObjectTypeDictionary) {
      EMSG("Context: invalid function entry");
      continue;
    }
    Error err = ERROR_INIT;
    ctx_unpack_func(ctx->funcs.items[i].data.dictionary, &err);
    if (ERROR_SET(&err)) {
      EMSG2("Context: function: %s", err.msg);
      api_clear_error(&err);
    }
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

  bool need_more = false;
  bool did_try_to_free = false;
  size_t offset = 0;
  while (offset < sbuf.size) {
    if (!msgpack_unpacker_reserve_buffer(unpacker, IOSIZE)) {
      EMSG(_(e_outofmem));
      goto exit;
    }
    size_t read_bytes = MIN(unpacker->free, sbuf.size - offset);
    memcpy(msgpack_unpacker_buffer(unpacker), sbuf.data + offset, read_bytes);
    offset += read_bytes;
    msgpack_unpacker_buffer_consumed(unpacker, read_bytes);
    need_more = false;
    while (!need_more && unpacker->off < unpacker->used) {
      Object obj = OBJECT_INIT;
      msgpack_unpack_return ret = msgpack_unpacker_next(unpacker, &unpacked);
      switch (ret) {
        case MSGPACK_UNPACK_SUCCESS:
          if (unpacked.data.type == MSGPACK_OBJECT_ARRAY
              || unpacked.data.type == MSGPACK_OBJECT_MAP) {
            msgpack_rpc_to_object(&unpacked.data, &obj);
            ADD(rv, obj);
          }
          break;
        case MSGPACK_UNPACK_CONTINUE:
          need_more = true;
          break;
        case MSGPACK_UNPACK_EXTRA_BYTES:
          EMSG2(_(e_intern2), "Context: extra bytes in msgpack string");
          goto exit;
        case MSGPACK_UNPACK_PARSE_ERROR:
          EMSG2(_(e_intern2), "Context: failed to parse msgpack string");
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
  }

  if (need_more) {
    EMSG("Incomplete msgpack string");
  }

exit:
  msgpack_unpacked_destroy(&unpacked);
  msgpack_unpacker_free(unpacker);
  return rv;
}

/// Pack an Object into a msgpack_sbuffer.
///
/// @param[in]  array  Object to pack.
///
/// @return msgpack_sbuffer with packed object.
static inline msgpack_sbuffer object_to_sbuf(Object obj)
{
  msgpack_sbuffer sbuf;
  msgpack_sbuffer_init(&sbuf);
  msgpack_packer *packer = msgpack_packer_new(&sbuf, msgpack_sbuffer_write);

  // msgpack_rpc_from_object packs Strings as STR, ShaDa expects BIN
  Error err = ERROR_INIT;
  typval_T tv = TV_INITIAL_VALUE;
  if (object_to_vim(obj, &tv, &err)) {
    encode_vim_to_msgpack(packer, &tv, "");
    tv_clear(&tv);
  }
  api_clear_error(&err);

  msgpack_packer_free(packer);
  return sbuf;
}

/// Pack API Objects from an Array into a ShaDa-format msgpack_sbuffer.
///
/// @param[in]  array  Array of API Objects to pack.
///
/// @return ShaDa-format msgpack_sbuffer with packed objects.
static inline msgpack_sbuffer array_to_sbuf(Array array, ShadaEntryType type)
{
  msgpack_sbuffer sbuf;
  msgpack_sbuffer_init(&sbuf);
  msgpack_packer *packer = msgpack_packer_new(&sbuf, msgpack_sbuffer_write);
  const Timestamp cur_timestamp = os_time();

  for (size_t i = 0; i < array.size; i++) {
    msgpack_sbuffer sbuf_current = object_to_sbuf(array.items[i]);
    msgpack_pack_uint64(packer, (uint64_t)type);
    msgpack_pack_uint64(packer, cur_timestamp);
    msgpack_pack_uint64(packer, sbuf_current.size);
    msgpack_pack_bin_body(packer, sbuf_current.data, sbuf_current.size);
    msgpack_sbuffer_destroy(&sbuf_current);
  }

  msgpack_packer_free(packer);
  return sbuf;
}

#define CONTEXT_MAP_KEY_DO(kv, from, to, code) \
  if (strequal((kv)->key.data, (from))) { \
    api_free_string((kv)->key); \
    (kv)->key = STATIC_CSTR_TO_STRING((to)); \
    code \
    continue; \
  }

#define CONTEXT_MAP_KEY(kv, from, to) \
  CONTEXT_MAP_KEY_DO((kv), (from), (to), {})

/// Map key names of ShaDa entries to user-friendly context key names.
///
/// "c"  -> "col"
/// "f"  -> "file"
/// "l"  -> "line"
/// "n"  -> "name"
/// "rc" -> "content"
/// "rt" -> "type"
/// "ru" -> "unnamed"
/// "rw" -> "width"
///
/// @param[in/out]  regs  Array of decoded ShaDa entries.
///
/// @return Mapped array (arr).
static inline Array ctx_keys_from_shada(Array arr)
{
  for (size_t i = 0; i < arr.size; i++) {
    if (arr.items[i].type != kObjectTypeDictionary) {
      continue;
    }

    Dictionary entry = arr.items[i].data.dictionary;
    for (size_t j = 0; j < entry.size; j++) {
      KeyValuePair *kv = &entry.items[j];
      CONTEXT_MAP_KEY(kv, "c", "col");
      CONTEXT_MAP_KEY(kv, "f", "file");
      CONTEXT_MAP_KEY(kv, "l", "line");
      CONTEXT_MAP_KEY_DO(kv, "n", "name", {
        if (kv->value.type == kObjectTypeInteger) {
          kv->value = STRING_OBJ(STATIC_CSTR_TO_STRING(
              ((char[]) { (char)kv->value.data.integer, 0 })));
        }
      });
      CONTEXT_MAP_KEY(kv, "rc", "content");
      CONTEXT_MAP_KEY(kv, "rt", "type");
      CONTEXT_MAP_KEY(kv, "ru", "unnamed");
      CONTEXT_MAP_KEY(kv, "rw", "width");
    }
  }

  return arr;
}

/// Map user-friendly key names of context entries to ShaDa key names.
///
/// "col"     -> "c"
/// "file"    -> "f"
/// "line"    -> "l"
/// "name"    -> "n"
/// "content" -> "rc"
/// "type"    -> "rt"
/// "unnamed" -> "ru"
/// "width"   -> "rw"
///
/// @param[in/out]  arr  Array of context entries.
///
/// @return Mapped array (arr).
static inline Array ctx_keys_to_shada(Array arr)
{
  for (size_t i = 0; i < arr.size; i++) {
    if (arr.items[i].type != kObjectTypeDictionary) {
      continue;
    }

    Dictionary entry = arr.items[i].data.dictionary;
    for (size_t j = 0; j < entry.size; j++) {
      KeyValuePair *kv = &entry.items[j];
      CONTEXT_MAP_KEY(kv, "col", "c");
      CONTEXT_MAP_KEY(kv, "file", "f");
      CONTEXT_MAP_KEY(kv, "line", "l");
      CONTEXT_MAP_KEY_DO(kv, "name", "n", {
        if (kv->value.type == kObjectTypeString
            && kv->value.data.string.size == 1) {
          Object value = INTEGER_OBJ(kv->value.data.string.data[0]);
          api_free_object(kv->value);
          kv->value = value;
        }
      });
      CONTEXT_MAP_KEY(kv, "content", "rc");
      CONTEXT_MAP_KEY(kv, "type", "rt");
      CONTEXT_MAP_KEY(kv, "unnamed", "ru");
      CONTEXT_MAP_KEY(kv, "width", "rw");
    }
  }

  return arr;
}

#undef CONTEXT_MAP_KEY
#undef CONTEXT_MAP_KEY_DO

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

  if (ctx->regs.size) {
    PUT(rv, "regs",
        ARRAY_OBJ(ctx_keys_from_shada(sbuf_to_array(ctx->regs))));
  }

  if (ctx->jumps.size) {
    PUT(rv, "jumps",
        ARRAY_OBJ(ctx_keys_from_shada(sbuf_to_array(ctx->jumps))));
  }

  if (ctx->buflist.size) {
    Array buflist = sbuf_to_array(ctx->buflist);
    assert(buflist.size == 1);
    assert(buflist.items[0].type == kObjectTypeArray);
    Array ctx_buflist = ctx_keys_from_shada(buflist.items[0].data.array);
    if (ctx_buflist.size) {
      PUT(rv, "buflist", ARRAY_OBJ(ctx_buflist));
    }
    xfree(buflist.items);
  }

  if (ctx->vars.size) {
    PUT(rv, "vars", ARRAY_OBJ(sbuf_to_array(ctx->vars)));
  }

  if (ctx->funcs.size) {
    PUT(rv, "funcs", ARRAY_OBJ(copy_array(ctx->funcs)));
  }

  return rv;
}

/// Converts Dictionary representation of Context back to Context object.
///
/// @param[in]   dict  Context Dictionary representation.
/// @param[out]  ctx   Context object to store conversion result into.
void ctx_from_dict(Dictionary dict, Context *ctx)
  FUNC_ATTR_NONNULL_ALL
{
  assert(ctx != NULL);

  for (size_t i = 0; i < dict.size; i++) {
    KeyValuePair item = dict.items[i];
    if (item.value.type != kObjectTypeArray) {
      continue;
    }
    if (strequal(item.key.data, "regs")) {
      ctx->regs = array_to_sbuf(ctx_keys_to_shada(item.value.data.array),
                                kSDItemRegister);
    } else if (strequal(item.key.data, "jumps")) {
      ctx->jumps = array_to_sbuf(ctx_keys_to_shada(item.value.data.array),
                                 kSDItemJump);
    } else if (strequal(item.key.data, "buflist")) {
      Array shada_buflist = (Array) {
        .size = 1,
        .capacity = 1,
        .items = (Object[]) {
          ARRAY_OBJ(ctx_keys_to_shada(item.value.data.array))
        }
      };
      ctx->buflist = array_to_sbuf(shada_buflist, kSDItemBufferList);
    } else if (strequal(item.key.data, "vars")) {
      ctx->vars = array_to_sbuf(item.value.data.array, kSDItemVariable);
    } else if (strequal(item.key.data, "funcs")) {
      ctx->funcs = copy_object(item.value).data.array;
    }
  }
}
