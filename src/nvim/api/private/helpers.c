// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/api/private/helpers.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/handle.h"
#include "nvim/msgpack_rpc/helpers.h"
#include "nvim/ascii.h"
#include "nvim/assert.h"
#include "nvim/vim.h"
#include "nvim/buffer.h"
#include "nvim/window.h"
#include "nvim/memory.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/map_defs.h"
#include "nvim/map.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/version.h"
#include "nvim/lib/kvec.h"
#include "nvim/getchar.h"
#include "nvim/ui.h"

/// Helper structure for vim_to_object
typedef struct {
  kvec_t(Object) stack;  ///< Object stack.
} EncodedData;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/helpers.c.generated.h"
# include "api/private/funcs_metadata.generated.h"
# include "api/private/ui_events_metadata.generated.h"
#endif

/// Start block that may cause VimL exceptions while evaluating another code
///
/// Used when caller is supposed to be operating when other VimL code is being
/// processed and that “other VimL code” must not be affected.
///
/// @param[out]  tstate  Location where try state should be saved.
void try_enter(TryState *const tstate)
{
  // TODO(ZyX-I): Check whether try_enter()/try_leave() may use
  //              enter_cleanup()/leave_cleanup(). Or
  //              save_dbg_stuff()/restore_dbg_stuff().
  *tstate = (TryState) {
    .current_exception = current_exception,
    .msg_list = (const struct msglist *const *)msg_list,
    .private_msg_list = NULL,
    .trylevel = trylevel,
    .got_int = got_int,
    .need_rethrow = need_rethrow,
    .did_emsg = did_emsg,
  };
  msg_list = &tstate->private_msg_list;
  current_exception = NULL;
  trylevel = 1;
  got_int = false;
  need_rethrow = false;
  did_emsg = false;
}

/// End try block, set the error message if any and restore previous state
///
/// @warning Return is consistent with most functions (false on error), not with
///          try_end (true on error).
///
/// @param[in]  tstate  Previous state to restore.
/// @param[out]  err  Location where error should be saved.
///
/// @return false if error occurred, true otherwise.
bool try_leave(const TryState *const tstate, Error *const err)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const bool ret = !try_end(err);
  assert(trylevel == 0);
  assert(!need_rethrow);
  assert(!got_int);
  assert(!did_emsg);
  assert(msg_list == &tstate->private_msg_list);
  assert(*msg_list == NULL);
  assert(current_exception == NULL);
  msg_list = (struct msglist **)tstate->msg_list;
  current_exception = tstate->current_exception;
  trylevel = tstate->trylevel;
  got_int = tstate->got_int;
  need_rethrow = tstate->need_rethrow;
  did_emsg = tstate->did_emsg;
  return ret;
}

/// Start block that may cause vimscript exceptions
///
/// Each try_start() call should be mirrored by try_end() call.
///
/// To be used as a replacement of `:try … catch … endtry` in C code, in cases
/// when error flag could not already be set. If there may be pending error
/// state at the time try_start() is executed which needs to be preserved,
/// try_enter()/try_leave() pair should be used instead.
void try_start(void)
{
  ++trylevel;
}

/// End try block, set the error message if any and return true if an error
/// occurred.
///
/// @param err Pointer to the stack-allocated error object
/// @return true if an error occurred
bool try_end(Error *err)
{
  // Note: all globals manipulated here should be saved/restored in
  // try_enter/try_leave.
  trylevel--;

  // Without this it stops processing all subsequent VimL commands and
  // generates strange error messages if I e.g. try calling Test() in a
  // cycle
  did_emsg = false;

  if (got_int) {
    if (current_exception) {
      // If we got an interrupt, discard the current exception
      discard_current_exception();
    }

    api_set_error(err, kErrorTypeException, "Keyboard interrupt");
    got_int = false;
  } else if (msg_list != NULL && *msg_list != NULL) {
    int should_free;
    char *msg = (char *)get_exception_string(*msg_list,
                                             ET_ERROR,
                                             NULL,
                                             &should_free);
    api_set_error(err, kErrorTypeException, "%s", msg);
    free_global_msglist();

    if (should_free) {
      xfree(msg);
    }
  } else if (current_exception) {
    api_set_error(err, kErrorTypeException, "%s", current_exception->value);
    discard_current_exception();
  }

  return ERROR_SET(err);
}

/// Recursively expands a vimscript value in a dict
///
/// @param dict The vimscript dict
/// @param key The key
/// @param[out] err Details of an error that may have occurred
Object dict_get_value(dict_T *dict, String key, Error *err)
{
  dictitem_T *const di = tv_dict_find(dict, key.data, (ptrdiff_t)key.size);

  if (di == NULL) {
    api_set_error(err, kErrorTypeValidation, "Key '%s' not found", key.data);
    return (Object)OBJECT_INIT;
  }

  return vim_to_object(&di->di_tv);
}

/// Set a value in a scope dict. Objects are recursively expanded into their
/// vimscript equivalents.
///
/// @param dict The vimscript dict
/// @param key The key
/// @param value The new value
/// @param del Delete key in place of setting it. Argument `value` is ignored in
///            this case.
/// @param retval If true the old value will be converted and returned.
/// @param[out] err Details of an error that may have occurred
/// @return The old value if `retval` is true and the key was present, else NIL
Object dict_set_var(dict_T *dict, String key, Object value, bool del,
                    bool retval, Error *err)
{
  Object rv = OBJECT_INIT;

  if (dict->dv_lock) {
    api_set_error(err, kErrorTypeException, "Dictionary is locked");
    return rv;
  }

  if (key.size == 0) {
    api_set_error(err, kErrorTypeValidation,
                  "Empty variable names aren't allowed");
    return rv;
  }

  if (key.size > INT_MAX) {
    api_set_error(err, kErrorTypeValidation, "Key length is too high");
    return rv;
  }

  dictitem_T *di = tv_dict_find(dict, key.data, (ptrdiff_t)key.size);

  if (di != NULL) {
    if (di->di_flags & DI_FLAGS_RO) {
      api_set_error(err, kErrorTypeException, "Key is read-only: %s", key.data);
      return rv;
    } else if (di->di_flags & DI_FLAGS_FIX) {
      api_set_error(err, kErrorTypeException, "Key is fixed: %s", key.data);
      return rv;
    } else if (di->di_flags & DI_FLAGS_LOCK) {
      api_set_error(err, kErrorTypeException, "Key is locked: %s", key.data);
      return rv;
    }
  }

  if (del) {
    // Delete the key
    if (di == NULL) {
      // Doesn't exist, fail
      api_set_error(err, kErrorTypeValidation, "Key does not exist: %s",
                    key.data);
    } else {
      // Return the old value
      if (retval) {
        rv = vim_to_object(&di->di_tv);
      }
      // Delete the entry
      tv_dict_item_remove(dict, di);
    }
  } else {
    // Update the key
    typval_T tv;

    // Convert the object to a vimscript type in the temporary variable
    if (!object_to_vim(value, &tv, err)) {
      return rv;
    }

    if (di == NULL) {
      // Need to create an entry
      di = tv_dict_item_alloc_len(key.data, key.size);
      tv_dict_add(dict, di);
    } else {
      // Return the old value
      if (retval) {
        rv = vim_to_object(&di->di_tv);
      }
      tv_clear(&di->di_tv);
    }

    // Update the value
    tv_copy(&tv, &di->di_tv);
    // Clear the temporary variable
    tv_clear(&tv);
  }

  return rv;
}

/// Gets the value of a global or local(buffer, window) option.
///
/// @param from If `type` is `SREQ_WIN` or `SREQ_BUF`, this must be a pointer
///        to the window or buffer.
/// @param type One of `SREQ_GLOBAL`, `SREQ_WIN` or `SREQ_BUF`
/// @param name The option name
/// @param[out] err Details of an error that may have occurred
/// @return the option value
Object get_option_from(void *from, int type, String name, Error *err)
{
  Object rv = OBJECT_INIT;

  if (name.size == 0) {
    api_set_error(err, kErrorTypeValidation, "Empty option name");
    return rv;
  }

  // Return values
  int64_t numval;
  char *stringval = NULL;
  int flags = get_option_value_strict(name.data, &numval, &stringval,
                                      type, from);

  if (!flags) {
    api_set_error(err,
                  kErrorTypeValidation,
                  "Invalid option name \"%s\"",
                  name.data);
    return rv;
  }

  if (flags & SOPT_BOOL) {
    rv.type = kObjectTypeBoolean;
    rv.data.boolean = numval ? true : false;
  } else if (flags & SOPT_NUM) {
    rv.type = kObjectTypeInteger;
    rv.data.integer = numval;
  } else if (flags & SOPT_STRING) {
    if (stringval) {
      rv.type = kObjectTypeString;
      rv.data.string.data = stringval;
      rv.data.string.size = strlen(stringval);
    } else {
      api_set_error(err,
                    kErrorTypeException,
                    "Unable to get value for option \"%s\"",
                    name.data);
    }
  } else {
    api_set_error(err,
                  kErrorTypeException,
                  "Unknown type for option \"%s\"",
                  name.data);
  }

  return rv;
}

/// Sets the value of a global or local(buffer, window) option.
///
/// @param to If `type` is `SREQ_WIN` or `SREQ_BUF`, this must be a pointer
///        to the window or buffer.
/// @param type One of `SREQ_GLOBAL`, `SREQ_WIN` or `SREQ_BUF`
/// @param name The option name
/// @param[out] err Details of an error that may have occurred
void set_option_to(void *to, int type, String name, Object value, Error *err)
{
  if (name.size == 0) {
    api_set_error(err, kErrorTypeValidation, "Empty option name");
    return;
  }

  int flags = get_option_value_strict(name.data, NULL, NULL, type, to);

  if (flags == 0) {
    api_set_error(err,
                  kErrorTypeValidation,
                  "Invalid option name \"%s\"",
                  name.data);
    return;
  }

  if (value.type == kObjectTypeNil) {
    if (type == SREQ_GLOBAL) {
      api_set_error(err,
                    kErrorTypeException,
                    "Unable to unset option \"%s\"",
                    name.data);
      return;
    } else if (!(flags & SOPT_GLOBAL)) {
      api_set_error(err,
                    kErrorTypeException,
                    "Cannot unset option \"%s\" "
                    "because it doesn't have a global value",
                    name.data);
      return;
    } else {
      unset_global_local_option(name.data, to);
      return;
    }
  }

  int opt_flags = (type == SREQ_GLOBAL) ? OPT_GLOBAL : OPT_LOCAL;

  if (flags & SOPT_BOOL) {
    if (value.type != kObjectTypeBoolean) {
      api_set_error(err,
                    kErrorTypeValidation,
                    "Option \"%s\" requires a boolean value",
                    name.data);
      return;
    }

    bool val = value.data.boolean;
    set_option_value_for(name.data, val, NULL, opt_flags, type, to, err);
  } else if (flags & SOPT_NUM) {
    if (value.type != kObjectTypeInteger) {
      api_set_error(err,
                    kErrorTypeValidation,
                    "Option \"%s\" requires an integer value",
                    name.data);
      return;
    }

    if (value.data.integer > INT_MAX || value.data.integer < INT_MIN) {
      api_set_error(err,
                    kErrorTypeValidation,
                    "Value for option \"%s\" is outside range",
                    name.data);
      return;
    }

    int val = (int) value.data.integer;
    set_option_value_for(name.data, val, NULL, opt_flags, type, to, err);
  } else {
    if (value.type != kObjectTypeString) {
      api_set_error(err,
                    kErrorTypeValidation,
                    "Option \"%s\" requires a string value",
                    name.data);
      return;
    }

    set_option_value_for(name.data, 0, value.data.string.data,
            opt_flags, type, to, err);
  }
}

#define TYPVAL_ENCODE_ALLOW_SPECIALS false

#define TYPVAL_ENCODE_CONV_NIL(tv) \
    kv_push(edata->stack, NIL)

#define TYPVAL_ENCODE_CONV_BOOL(tv, num) \
    kv_push(edata->stack, BOOLEAN_OBJ((Boolean)(num)))

#define TYPVAL_ENCODE_CONV_NUMBER(tv, num) \
    kv_push(edata->stack, INTEGER_OBJ((Integer)(num)))

#define TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER TYPVAL_ENCODE_CONV_NUMBER

#define TYPVAL_ENCODE_CONV_FLOAT(tv, flt) \
    kv_push(edata->stack, FLOAT_OBJ((Float)(flt)))

#define TYPVAL_ENCODE_CONV_STRING(tv, str, len) \
    do { \
      const size_t len_ = (size_t)(len); \
      const char *const str_ = (const char *)(str); \
      assert(len_ == 0 || str_ != NULL); \
      kv_push(edata->stack, STRING_OBJ(((String) { \
        .data = xmemdupz((len_?str_:""), len_), \
        .size = len_ \
      }))); \
    } while (0)

#define TYPVAL_ENCODE_CONV_STR_STRING TYPVAL_ENCODE_CONV_STRING

#define TYPVAL_ENCODE_CONV_EXT_STRING(tv, str, len, type) \
    TYPVAL_ENCODE_CONV_NIL(tv)

#define TYPVAL_ENCODE_CONV_FUNC_START(tv, fun) \
    do { \
      TYPVAL_ENCODE_CONV_NIL(tv); \
      goto typval_encode_stop_converting_one_item; \
    } while (0)

#define TYPVAL_ENCODE_CONV_FUNC_BEFORE_ARGS(tv, len)
#define TYPVAL_ENCODE_CONV_FUNC_BEFORE_SELF(tv, len)
#define TYPVAL_ENCODE_CONV_FUNC_END(tv)

#define TYPVAL_ENCODE_CONV_EMPTY_LIST(tv) \
    kv_push(edata->stack, ARRAY_OBJ(((Array) { .capacity = 0, .size = 0 })))

#define TYPVAL_ENCODE_CONV_EMPTY_DICT(tv, dict) \
    kv_push(edata->stack, \
            DICTIONARY_OBJ(((Dictionary) { .capacity = 0, .size = 0 })))

static inline void typval_encode_list_start(EncodedData *const edata,
                                            const size_t len)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL
{
  kv_push(edata->stack, ARRAY_OBJ(((Array) {
    .capacity = len,
    .size = 0,
    .items = xmalloc(len * sizeof(*((Object)OBJECT_INIT).data.array.items)),
  })));
}

#define TYPVAL_ENCODE_CONV_LIST_START(tv, len) \
    typval_encode_list_start(edata, (size_t)(len))

#define TYPVAL_ENCODE_CONV_REAL_LIST_AFTER_START(tv, mpsv)

static inline void typval_encode_between_list_items(EncodedData *const edata)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL
{
  Object item = kv_pop(edata->stack);
  Object *const list = &kv_last(edata->stack);
  assert(list->type == kObjectTypeArray);
  assert(list->data.array.size < list->data.array.capacity);
  list->data.array.items[list->data.array.size++] = item;
}

#define TYPVAL_ENCODE_CONV_LIST_BETWEEN_ITEMS(tv) \
    typval_encode_between_list_items(edata)

static inline void typval_encode_list_end(EncodedData *const edata)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL
{
  typval_encode_between_list_items(edata);
#ifndef NDEBUG
  const Object *const list = &kv_last(edata->stack);
  assert(list->data.array.size == list->data.array.capacity);
#endif
}

#define TYPVAL_ENCODE_CONV_LIST_END(tv) \
    typval_encode_list_end(edata)

static inline void typval_encode_dict_start(EncodedData *const edata,
                                            const size_t len)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL
{
  kv_push(edata->stack, DICTIONARY_OBJ(((Dictionary) {
    .capacity = len,
    .size = 0,
    .items = xmalloc(len * sizeof(
        *((Object)OBJECT_INIT).data.dictionary.items)),
  })));
}

#define TYPVAL_ENCODE_CONV_DICT_START(tv, dict, len) \
    typval_encode_dict_start(edata, (size_t)(len))

#define TYPVAL_ENCODE_CONV_REAL_DICT_AFTER_START(tv, dict, mpsv)

#define TYPVAL_ENCODE_SPECIAL_DICT_KEY_CHECK(label, kv_pair)

static inline void typval_encode_after_key(EncodedData *const edata)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL
{
  Object key = kv_pop(edata->stack);
  Object *const dict = &kv_last(edata->stack);
  assert(dict->type == kObjectTypeDictionary);
  assert(dict->data.dictionary.size < dict->data.dictionary.capacity);
  if (key.type == kObjectTypeString) {
    dict->data.dictionary.items[dict->data.dictionary.size].key
        = key.data.string;
  } else {
    api_free_object(key);
    dict->data.dictionary.items[dict->data.dictionary.size].key
        = STATIC_CSTR_TO_STRING("__INVALID_KEY__");
  }
}

#define TYPVAL_ENCODE_CONV_DICT_AFTER_KEY(tv, dict) \
    typval_encode_after_key(edata)

static inline void typval_encode_between_dict_items(EncodedData *const edata)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL
{
  Object val = kv_pop(edata->stack);
  Object *const dict = &kv_last(edata->stack);
  assert(dict->type == kObjectTypeDictionary);
  assert(dict->data.dictionary.size < dict->data.dictionary.capacity);
  dict->data.dictionary.items[dict->data.dictionary.size++].value = val;
}

#define TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS(tv, dict) \
    typval_encode_between_dict_items(edata)

static inline void typval_encode_dict_end(EncodedData *const edata)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL
{
  typval_encode_between_dict_items(edata);
#ifndef NDEBUG
  const Object *const dict = &kv_last(edata->stack);
  assert(dict->data.dictionary.size == dict->data.dictionary.capacity);
#endif
}

#define TYPVAL_ENCODE_CONV_DICT_END(tv, dict) \
    typval_encode_dict_end(edata)

#define TYPVAL_ENCODE_CONV_RECURSE(val, conv_type) \
    TYPVAL_ENCODE_CONV_NIL(val)

#define TYPVAL_ENCODE_SCOPE static
#define TYPVAL_ENCODE_NAME object
#define TYPVAL_ENCODE_FIRST_ARG_TYPE EncodedData *const
#define TYPVAL_ENCODE_FIRST_ARG_NAME edata
#include "nvim/eval/typval_encode.c.h"
#undef TYPVAL_ENCODE_SCOPE
#undef TYPVAL_ENCODE_NAME
#undef TYPVAL_ENCODE_FIRST_ARG_TYPE
#undef TYPVAL_ENCODE_FIRST_ARG_NAME

#undef TYPVAL_ENCODE_CONV_STRING
#undef TYPVAL_ENCODE_CONV_STR_STRING
#undef TYPVAL_ENCODE_CONV_EXT_STRING
#undef TYPVAL_ENCODE_CONV_NUMBER
#undef TYPVAL_ENCODE_CONV_FLOAT
#undef TYPVAL_ENCODE_CONV_FUNC_START
#undef TYPVAL_ENCODE_CONV_FUNC_BEFORE_ARGS
#undef TYPVAL_ENCODE_CONV_FUNC_BEFORE_SELF
#undef TYPVAL_ENCODE_CONV_FUNC_END
#undef TYPVAL_ENCODE_CONV_EMPTY_LIST
#undef TYPVAL_ENCODE_CONV_LIST_START
#undef TYPVAL_ENCODE_CONV_REAL_LIST_AFTER_START
#undef TYPVAL_ENCODE_CONV_EMPTY_DICT
#undef TYPVAL_ENCODE_CONV_NIL
#undef TYPVAL_ENCODE_CONV_BOOL
#undef TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER
#undef TYPVAL_ENCODE_CONV_DICT_START
#undef TYPVAL_ENCODE_CONV_REAL_DICT_AFTER_START
#undef TYPVAL_ENCODE_CONV_DICT_END
#undef TYPVAL_ENCODE_CONV_DICT_AFTER_KEY
#undef TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS
#undef TYPVAL_ENCODE_SPECIAL_DICT_KEY_CHECK
#undef TYPVAL_ENCODE_CONV_LIST_END
#undef TYPVAL_ENCODE_CONV_LIST_BETWEEN_ITEMS
#undef TYPVAL_ENCODE_CONV_RECURSE
#undef TYPVAL_ENCODE_ALLOW_SPECIALS

/// Convert a vim object to an `Object` instance, recursively expanding
/// Arrays/Dictionaries.
///
/// @param obj The source object
/// @return The converted value
Object vim_to_object(typval_T *obj)
{
  EncodedData edata = { .stack = KV_INITIAL_VALUE };
  const int evo_ret = encode_vim_to_object(&edata, obj,
                                           "vim_to_object argument");
  (void)evo_ret;
  assert(evo_ret == OK);
  Object ret = kv_A(edata.stack, 0);
  assert(kv_size(edata.stack) == 1);
  kv_destroy(edata.stack);
  return ret;
}

buf_T *find_buffer_by_handle(Buffer buffer, Error *err)
{
  if (buffer == 0) {
    return curbuf;
  }

  buf_T *rv = handle_get_buffer(buffer);

  if (!rv) {
    api_set_error(err, kErrorTypeValidation, "Invalid buffer id");
  }

  return rv;
}

win_T *find_window_by_handle(Window window, Error *err)
{
  if (window == 0) {
    return curwin;
  }

  win_T *rv = handle_get_window(window);

  if (!rv) {
    api_set_error(err, kErrorTypeValidation, "Invalid window id");
  }

  return rv;
}

tabpage_T *find_tab_by_handle(Tabpage tabpage, Error *err)
{
  if (tabpage == 0) {
    return curtab;
  }

  tabpage_T *rv = handle_get_tabpage(tabpage);

  if (!rv) {
    api_set_error(err, kErrorTypeValidation, "Invalid tabpage id");
  }

  return rv;
}

/// Allocates a String consisting of a single char. Does not support multibyte
/// characters. The resulting string is also NUL-terminated, to facilitate
/// interoperating with code using C strings.
///
/// @param char the char to convert
/// @return the resulting String, if the input char was NUL, an
///         empty String is returned
String cchar_to_string(char c)
{
  char buf[] = { c, NUL };
  return (String) {
    .data = xmemdupz(buf, 1),
    .size = (c != NUL) ? 1 : 0
  };
}

/// Copies a C string into a String (binary safe string, characters + length).
/// The resulting string is also NUL-terminated, to facilitate interoperating
/// with code using C strings.
///
/// @param str the C string to copy
/// @return the resulting String, if the input string was NULL, an
///         empty String is returned
String cstr_to_string(const char *str)
{
    if (str == NULL) {
        return (String) STRING_INIT;
    }

    size_t len = strlen(str);
    return (String) {
        .data = xmemdupz(str, len),
        .size = len
    };
}

/// Copies buffer to an allocated String.
/// The resulting string is also NUL-terminated, to facilitate interoperating
/// with code using C strings.
///
/// @param buf the buffer to copy
/// @param size length of the buffer
/// @return the resulting String, if the input string was NULL, an
///         empty String is returned
String cbuf_to_string(const char *buf, size_t size)
  FUNC_ATTR_NONNULL_ALL
{
  return (String) {
    .data = xmemdupz(buf, size),
    .size = size
  };
}

/// Creates a String using the given C string. Unlike
/// cstr_to_string this function DOES NOT copy the C string.
///
/// @param str the C string to use
/// @return The resulting String, or an empty String if
///           str was NULL
String cstr_as_string(char *str) FUNC_ATTR_PURE
{
  if (str == NULL) {
    return (String) STRING_INIT;
  }
  return (String) { .data = str, .size = strlen(str) };
}

/// Converts from type Object to a VimL value.
///
/// @param obj  Object to convert from.
/// @param tv   Conversion result is placed here. On failure member v_type is
///             set to VAR_UNKNOWN (no allocation was made for this variable).
/// returns     true if conversion is successful, otherwise false.
bool object_to_vim(Object obj, typval_T *tv, Error *err)
{
  tv->v_type = VAR_UNKNOWN;
  tv->v_lock = VAR_UNLOCKED;

  switch (obj.type) {
    case kObjectTypeNil:
      tv->v_type = VAR_SPECIAL;
      tv->vval.v_special = kSpecialVarNull;
      break;

    case kObjectTypeBoolean:
      tv->v_type = VAR_SPECIAL;
      tv->vval.v_special = obj.data.boolean? kSpecialVarTrue: kSpecialVarFalse;
      break;

    case kObjectTypeBuffer:
    case kObjectTypeWindow:
    case kObjectTypeTabpage:
    case kObjectTypeInteger:
      STATIC_ASSERT(sizeof(obj.data.integer) <= sizeof(varnumber_T),
                    "Integer size must be <= VimL number size");
      tv->v_type = VAR_NUMBER;
      tv->vval.v_number = (varnumber_T)obj.data.integer;
      break;

    case kObjectTypeFloat:
      tv->v_type = VAR_FLOAT;
      tv->vval.v_float = obj.data.floating;
      break;

    case kObjectTypeString:
      tv->v_type = VAR_STRING;
      if (obj.data.string.data == NULL) {
        tv->vval.v_string = NULL;
      } else {
        tv->vval.v_string = xmemdupz(obj.data.string.data,
                                     obj.data.string.size);
      }
      break;

    case kObjectTypeArray: {
      list_T *const list = tv_list_alloc((ptrdiff_t)obj.data.array.size);

      for (uint32_t i = 0; i < obj.data.array.size; i++) {
        Object item = obj.data.array.items[i];
        typval_T li_tv;

        if (!object_to_vim(item, &li_tv, err)) {
          tv_list_free(list);
          return false;
        }

        tv_list_append_owned_tv(list, li_tv);
      }
      tv_list_ref(list);

      tv->v_type = VAR_LIST;
      tv->vval.v_list = list;
      break;
    }

    case kObjectTypeDictionary: {
      dict_T *const dict = tv_dict_alloc();

      for (uint32_t i = 0; i < obj.data.dictionary.size; i++) {
        KeyValuePair item = obj.data.dictionary.items[i];
        String key = item.key;

        if (key.size == 0) {
          api_set_error(err, kErrorTypeValidation,
                        "Empty dictionary keys aren't allowed");
          // cleanup
          tv_dict_free(dict);
          return false;
        }

        dictitem_T *const di = tv_dict_item_alloc(key.data);

        if (!object_to_vim(item.value, &di->di_tv, err)) {
          // cleanup
          tv_dict_item_free(di);
          tv_dict_free(dict);
          return false;
        }

        tv_dict_add(dict, di);
      }
      dict->dv_refcount++;

      tv->v_type = VAR_DICT;
      tv->vval.v_dict = dict;
      break;
    }
    default:
      abort();
  }

  return true;
}

void api_free_string(String value)
{
  if (!value.data) {
    return;
  }

  xfree(value.data);
}

void api_free_object(Object value)
{
  switch (value.type) {
    case kObjectTypeNil:
    case kObjectTypeBoolean:
    case kObjectTypeInteger:
    case kObjectTypeFloat:
    case kObjectTypeBuffer:
    case kObjectTypeWindow:
    case kObjectTypeTabpage:
      break;

    case kObjectTypeString:
      api_free_string(value.data.string);
      break;

    case kObjectTypeArray:
      api_free_array(value.data.array);
      break;

    case kObjectTypeDictionary:
      api_free_dictionary(value.data.dictionary);
      break;

    default:
      abort();
  }
}

void api_free_array(Array value)
{
  for (size_t i = 0; i < value.size; i++) {
    api_free_object(value.items[i]);
  }

  xfree(value.items);
}

void api_free_dictionary(Dictionary value)
{
  for (size_t i = 0; i < value.size; i++) {
    api_free_string(value.items[i].key);
    api_free_object(value.items[i].value);
  }

  xfree(value.items);
}

void api_clear_error(Error *value)
  FUNC_ATTR_NONNULL_ALL
{
  if (!ERROR_SET(value)) {
    return;
  }
  xfree(value->msg);
  value->msg = NULL;
  value->type = kErrorTypeNone;
}

Dictionary api_metadata(void)
{
  static Dictionary metadata = ARRAY_DICT_INIT;

  if (!metadata.size) {
    PUT(metadata, "version", DICTIONARY_OBJ(version_dict()));
    init_function_metadata(&metadata);
    init_ui_event_metadata(&metadata);
    init_error_type_metadata(&metadata);
    init_type_metadata(&metadata);
  }

  return copy_object(DICTIONARY_OBJ(metadata)).data.dictionary;
}

static void init_function_metadata(Dictionary *metadata)
{
  msgpack_unpacked unpacked;
  msgpack_unpacked_init(&unpacked);
  if (msgpack_unpack_next(&unpacked,
                          (const char *)funcs_metadata,
                          sizeof(funcs_metadata),
                          NULL) != MSGPACK_UNPACK_SUCCESS) {
    abort();
  }
  Object functions;
  msgpack_rpc_to_object(&unpacked.data, &functions);
  msgpack_unpacked_destroy(&unpacked);
  PUT(*metadata, "functions", functions);
}

static void init_ui_event_metadata(Dictionary *metadata)
{
  msgpack_unpacked unpacked;
  msgpack_unpacked_init(&unpacked);
  if (msgpack_unpack_next(&unpacked,
                          (const char *)ui_events_metadata,
                          sizeof(ui_events_metadata),
                          NULL) != MSGPACK_UNPACK_SUCCESS) {
    abort();
  }
  Object ui_events;
  msgpack_rpc_to_object(&unpacked.data, &ui_events);
  msgpack_unpacked_destroy(&unpacked);
  PUT(*metadata, "ui_events", ui_events);
  Array ui_options = ARRAY_DICT_INIT;
  ADD(ui_options, STRING_OBJ(cstr_to_string("rgb")));
  for (UIExtension i = 0; i < kUIExtCount; i++) {
    ADD(ui_options, STRING_OBJ(cstr_to_string(ui_ext_names[i])));
  }
  PUT(*metadata, "ui_options", ARRAY_OBJ(ui_options));
}

static void init_error_type_metadata(Dictionary *metadata)
{
  Dictionary types = ARRAY_DICT_INIT;

  Dictionary exception_metadata = ARRAY_DICT_INIT;
  PUT(exception_metadata, "id", INTEGER_OBJ(kErrorTypeException));

  Dictionary validation_metadata = ARRAY_DICT_INIT;
  PUT(validation_metadata, "id", INTEGER_OBJ(kErrorTypeValidation));

  PUT(types, "Exception", DICTIONARY_OBJ(exception_metadata));
  PUT(types, "Validation", DICTIONARY_OBJ(validation_metadata));

  PUT(*metadata, "error_types", DICTIONARY_OBJ(types));
}

static void init_type_metadata(Dictionary *metadata)
{
  Dictionary types = ARRAY_DICT_INIT;

  Dictionary buffer_metadata = ARRAY_DICT_INIT;
  PUT(buffer_metadata, "id",
      INTEGER_OBJ(kObjectTypeBuffer - EXT_OBJECT_TYPE_SHIFT));
  PUT(buffer_metadata, "prefix", STRING_OBJ(cstr_to_string("nvim_buf_")));

  Dictionary window_metadata = ARRAY_DICT_INIT;
  PUT(window_metadata, "id",
      INTEGER_OBJ(kObjectTypeWindow - EXT_OBJECT_TYPE_SHIFT));
  PUT(window_metadata, "prefix", STRING_OBJ(cstr_to_string("nvim_win_")));

  Dictionary tabpage_metadata = ARRAY_DICT_INIT;
  PUT(tabpage_metadata, "id",
      INTEGER_OBJ(kObjectTypeTabpage - EXT_OBJECT_TYPE_SHIFT));
  PUT(tabpage_metadata, "prefix", STRING_OBJ(cstr_to_string("nvim_tabpage_")));

  PUT(types, "Buffer", DICTIONARY_OBJ(buffer_metadata));
  PUT(types, "Window", DICTIONARY_OBJ(window_metadata));
  PUT(types, "Tabpage", DICTIONARY_OBJ(tabpage_metadata));

  PUT(*metadata, "types", DICTIONARY_OBJ(types));
}

String copy_string(String str)
{
  if (str.data != NULL) {
    return (String){ .data = xmemdupz(str.data, str.size), .size = str.size };
  } else {
    return (String)STRING_INIT;
  }
}

Array copy_array(Array array)
{
  Array rv = ARRAY_DICT_INIT;
  for (size_t i = 0; i < array.size; i++) {
    ADD(rv, copy_object(array.items[i]));
  }
  return rv;
}

/// Creates a deep clone of an object
Object copy_object(Object obj)
{
  switch (obj.type) {
    case kObjectTypeNil:
    case kObjectTypeBoolean:
    case kObjectTypeInteger:
    case kObjectTypeFloat:
      return obj;

    case kObjectTypeString:
      return STRING_OBJ(copy_string(obj.data.string));

    case kObjectTypeArray:
      return ARRAY_OBJ(copy_array(obj.data.array));

    case kObjectTypeDictionary: {
      Dictionary rv = ARRAY_DICT_INIT;
      for (size_t i = 0; i < obj.data.dictionary.size; i++) {
        KeyValuePair item = obj.data.dictionary.items[i];
        PUT(rv, item.key.data, copy_object(item.value));
      }
      return DICTIONARY_OBJ(rv);
    }
    default:
      abort();
  }
}

static void set_option_value_for(char *key,
                                 int numval,
                                 char *stringval,
                                 int opt_flags,
                                 int opt_type,
                                 void *from,
                                 Error *err)
{
  win_T *save_curwin = NULL;
  tabpage_T *save_curtab = NULL;
  bufref_T save_curbuf =  { NULL, 0, 0 };

  try_start();
  switch (opt_type)
  {
    case SREQ_WIN:
      if (switch_win(&save_curwin, &save_curtab, (win_T *)from,
            win_find_tabpage((win_T *)from), false) == FAIL)
      {
        if (try_end(err)) {
          return;
        }
        api_set_error(err,
                      kErrorTypeException,
                      "Problem while switching windows");
        return;
      }
      set_option_value_err(key, numval, stringval, opt_flags, err);
      restore_win(save_curwin, save_curtab, true);
      break;
    case SREQ_BUF:
      switch_buffer(&save_curbuf, (buf_T *)from);
      set_option_value_err(key, numval, stringval, opt_flags, err);
      restore_buffer(&save_curbuf);
      break;
    case SREQ_GLOBAL:
      set_option_value_err(key, numval, stringval, opt_flags, err);
      break;
  }

  if (ERROR_SET(err)) {
    return;
  }

  try_end(err);
}


static void set_option_value_err(char *key,
                                 int numval,
                                 char *stringval,
                                 int opt_flags,
                                 Error *err)
{
  char *errmsg;

  if ((errmsg = set_option_value(key, numval, stringval, opt_flags))) {
    if (try_end(err)) {
      return;
    }

    api_set_error(err, kErrorTypeException, "%s", errmsg);
  }
}

void api_set_error(Error *err, ErrorType errType, const char *format, ...)
  FUNC_ATTR_NONNULL_ALL
{
  assert(kErrorTypeNone != errType);
  va_list args1;
  va_list args2;
  va_start(args1, format);
  va_copy(args2, args1);
  int len = vsnprintf(NULL, 0, format, args1);
  va_end(args1);
  assert(len >= 0);
  // Limit error message to 1 MB.
  size_t bufsize = MIN((size_t)len + 1, 1024 * 1024);
  err->msg = xmalloc(bufsize);
  vsnprintf(err->msg, bufsize, format, args2);
  va_end(args2);

  err->type = errType;
}

/// Get an array containing dictionaries describing mappings
/// based on mode and buffer id
///
/// @param  mode  The abbreviation for the mode
/// @param  buf  The buffer to get the mapping array. NULL for global
/// @returns An array of maparg() like dictionaries describing mappings
ArrayOf(Dictionary) keymap_array(String mode, buf_T *buf)
{
  Array mappings = ARRAY_DICT_INIT;
  dict_T *const dict = tv_dict_alloc();

  // Convert the string mode to the integer mode
  // that is stored within each mapblock
  char_u *p = (char_u *)mode.data;
  int int_mode = get_map_mode(&p, 0);

  // Determine the desired buffer value
  long buffer_value = (buf == NULL) ? 0 : buf->handle;

  for (int i = 0; i < MAX_MAPHASH; i++) {
    for (const mapblock_T *current_maphash = get_maphash(i, buf);
         current_maphash;
         current_maphash = current_maphash->m_next) {
      // Check for correct mode
      if (int_mode & current_maphash->m_mode) {
        mapblock_fill_dict(dict, current_maphash, buffer_value, false);
        ADD(mappings, vim_to_object(
            (typval_T[]) { { .v_type = VAR_DICT, .vval.v_dict = dict } }));

        tv_dict_clear(dict);
      }
    }
  }
  tv_dict_free(dict);

  return mappings;
}
