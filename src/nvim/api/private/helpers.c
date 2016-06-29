#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/api/private/helpers.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/handle.h"
#include "nvim/ascii.h"
#include "nvim/vim.h"
#include "nvim/buffer.h"
#include "nvim/window.h"
#include "nvim/memory.h"
#include "nvim/eval.h"
#include "nvim/map_defs.h"
#include "nvim/map.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/eval/typval_encode.h"
#include "nvim/lib/kvec.h"

/// Helper structure for vim_to_object
typedef struct {
  kvec_t(Object) stack;  ///< Object stack.
} EncodedData;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/helpers.c.generated.h"
#endif

/// Start block that may cause vimscript exceptions
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
  --trylevel;

  // Without this it stops processing all subsequent VimL commands and
  // generates strange error messages if I e.g. try calling Test() in a
  // cycle
  did_emsg = false;

  if (got_int) {
    if (did_throw) {
      // If we got an interrupt, discard the current exception
      discard_current_exception();
    }

    api_set_error(err, Exception, _("Keyboard interrupt"));
    got_int = false;
  } else if (msg_list != NULL && *msg_list != NULL) {
    int should_free;
    char *msg = (char *)get_exception_string(*msg_list,
                                             ET_ERROR,
                                             NULL,
                                             &should_free);
    xstrlcpy(err->msg, msg, sizeof(err->msg));
    err->set = true;
    free_global_msglist();

    if (should_free) {
      xfree(msg);
    }
  } else if (did_throw) {
    api_set_error(err, Exception, "%s", current_exception->value);
    discard_current_exception();
  }

  return err->set;
}

/// Recursively expands a vimscript value in a dict
///
/// @param dict The vimscript dict
/// @param key The key
/// @param[out] err Details of an error that may have occurred
Object dict_get_value(dict_T *dict, String key, Error *err)
{
  hashitem_T *hi = hash_find(&dict->dv_hashtab, (uint8_t *) key.data);

  if (HASHITEM_EMPTY(hi)) {
    api_set_error(err, Validation, _("Key not found"));
    return (Object) OBJECT_INIT;
  }

  dictitem_T *di = dict_lookup(hi);
  return vim_to_object(&di->di_tv);
}

/// Set a value in a dict. Objects are recursively expanded into their
/// vimscript equivalents.
///
/// @param dict The vimscript dict
/// @param key The key
/// @param value The new value
/// @param del Delete key in place of setting it. Argument `value` is ignored in
///            this case.
/// @param[out] err Details of an error that may have occurred
/// @return the old value, if any
Object dict_set_value(dict_T *dict, String key, Object value, bool del,
                      Error *err)
{
  Object rv = OBJECT_INIT;

  if (dict->dv_lock) {
    api_set_error(err, Exception, _("Dictionary is locked"));
    return rv;
  }

  if (key.size == 0) {
    api_set_error(err, Validation, _("Empty dictionary keys aren't allowed"));
    return rv;
  }

  if (key.size > INT_MAX) {
    api_set_error(err, Validation, _("Key length is too high"));
    return rv;
  }

  dictitem_T *di = dict_find(dict, (uint8_t *)key.data, (int)key.size);

  if (del) {
    // Delete the key
    if (di == NULL) {
      // Doesn't exist, fail
      api_set_error(err, Validation, _("Key \"%s\" doesn't exist"), key.data);
    } else {
      // Return the old value
      rv = vim_to_object(&di->di_tv);
      // Delete the entry
      hashitem_T *hi = hash_find(&dict->dv_hashtab, di->di_key);
      hash_remove(&dict->dv_hashtab, hi);
      dictitem_free(di);
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
      di = dictitem_alloc((uint8_t *) key.data);
      dict_add(dict, di);
    } else {
      // Return the old value
      rv = vim_to_object(&di->di_tv);
      clear_tv(&di->di_tv);
    }

    // Update the value
    copy_tv(&tv, &di->di_tv);
    // Clear the temporary variable
    clear_tv(&tv);
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
    api_set_error(err, Validation, _("Empty option name"));
    return rv;
  }

  // Return values
  int64_t numval;
  char *stringval = NULL;
  int flags = get_option_value_strict(name.data, &numval, &stringval,
                                      type, from);

  if (!flags) {
    api_set_error(err,
                  Validation,
                  _("Invalid option name \"%s\""),
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
                    Exception,
                    _("Unable to get value for option \"%s\""),
                    name.data);
    }
  } else {
    api_set_error(err,
                  Exception,
                  _("Unknown type for option \"%s\""),
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
    api_set_error(err, Validation, _("Empty option name"));
    return;
  }

  int flags = get_option_value_strict(name.data, NULL, NULL, type, to);

  if (flags == 0) {
    api_set_error(err,
                  Validation,
                  _("Invalid option name \"%s\""),
                  name.data);
    return;
  }

  if (value.type == kObjectTypeNil) {
    if (type == SREQ_GLOBAL) {
      api_set_error(err,
                    Exception,
                    _("Unable to unset option \"%s\""),
                    name.data);
      return;
    } else if (!(flags & SOPT_GLOBAL)) {
      api_set_error(err,
                    Exception,
                    _("Cannot unset option \"%s\" "
                      "because it doesn't have a global value"),
                    name.data);
      return;
    } else {
      unset_global_local_option(name.data, to);
      return;
    }
  }

  int opt_flags = (type ? OPT_LOCAL : OPT_GLOBAL);

  if (flags & SOPT_BOOL) {
    if (value.type != kObjectTypeBoolean) {
      api_set_error(err,
                    Validation,
                    _("Option \"%s\" requires a boolean value"),
                    name.data);
      return;
    }

    bool val = value.data.boolean;
    set_option_value_for(name.data, val, NULL, opt_flags, type, to, err);
  } else if (flags & SOPT_NUM) {
    if (value.type != kObjectTypeInteger) {
      api_set_error(err,
                    Validation,
                    _("Option \"%s\" requires an integer value"),
                    name.data);
      return;
    }

    if (value.data.integer > INT_MAX || value.data.integer < INT_MIN) {
      api_set_error(err,
                    Validation,
                    _("Value for option \"%s\" is outside range"),
                    name.data);
      return;
    }

    int val = (int) value.data.integer;
    set_option_value_for(name.data, val, NULL, opt_flags, type, to, err);
  } else {
    if (value.type != kObjectTypeString) {
      api_set_error(err,
                    Validation,
                    _("Option \"%s\" requires a string value"),
                    name.data);
      return;
    }

    set_option_value_for(name.data, 0, value.data.string.data,
            opt_flags, type, to, err);
  }
}

#define TYPVAL_ENCODE_ALLOW_SPECIALS false

#define TYPVAL_ENCODE_CONV_NIL() \
    kv_push(edata->stack, NIL)

#define TYPVAL_ENCODE_CONV_BOOL(num) \
    kv_push(edata->stack, BOOLEAN_OBJ((Boolean)(num)))

#define TYPVAL_ENCODE_CONV_NUMBER(num) \
    kv_push(edata->stack, INTEGER_OBJ((Integer)(num)))

#define TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER TYPVAL_ENCODE_CONV_NUMBER

#define TYPVAL_ENCODE_CONV_FLOAT(flt) \
    kv_push(edata->stack, FLOATING_OBJ((Float)(flt)))

#define TYPVAL_ENCODE_CONV_STRING(str, len) \
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

#define TYPVAL_ENCODE_CONV_EXT_STRING(str, len, type) \
    TYPVAL_ENCODE_CONV_NIL()

#define TYPVAL_ENCODE_CONV_FUNC(fun) \
    TYPVAL_ENCODE_CONV_NIL()

#define TYPVAL_ENCODE_CONV_EMPTY_LIST() \
    kv_push(edata->stack, ARRAY_OBJ(((Array) { .capacity = 0, .size = 0 })))

#define TYPVAL_ENCODE_CONV_EMPTY_DICT() \
    kv_push(edata->stack, \
            DICTIONARY_OBJ(((Dictionary) { .capacity = 0, .size = 0 })))

static inline void typval_encode_list_start(EncodedData *const edata,
                                            const size_t len)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL
{
  const Object obj = OBJECT_INIT;
  kv_push(edata->stack, ARRAY_OBJ(((Array) {
    .capacity = len,
    .size = 0,
    .items = xmalloc(len * sizeof(*obj.data.array.items)),
  })));
}

#define TYPVAL_ENCODE_CONV_LIST_START(len) \
    typval_encode_list_start(edata, (size_t)(len))

static inline void typval_encode_between_list_items(EncodedData *const edata)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL
{
  Object item = kv_pop(edata->stack);
  Object *const list = &kv_last(edata->stack);
  assert(list->type == kObjectTypeArray);
  assert(list->data.array.size < list->data.array.capacity);
  list->data.array.items[list->data.array.size++] = item;
}

#define TYPVAL_ENCODE_CONV_LIST_BETWEEN_ITEMS() \
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

#define TYPVAL_ENCODE_CONV_LIST_END() \
    typval_encode_list_end(edata)

static inline void typval_encode_dict_start(EncodedData *const edata,
                                            const size_t len)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL
{
  const Object obj = OBJECT_INIT;
  kv_push(edata->stack, DICTIONARY_OBJ(((Dictionary) {
    .capacity = len,
    .size = 0,
    .items = xmalloc(len * sizeof(*obj.data.dictionary.items)),
  })));
}

#define TYPVAL_ENCODE_CONV_DICT_START(len) \
    typval_encode_dict_start(edata, (size_t)(len))

#define TYPVAL_ENCODE_CONV_SPECIAL_DICT_KEY_CHECK(label, kv_pair)

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

#define TYPVAL_ENCODE_CONV_DICT_AFTER_KEY() \
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

#define TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS() \
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

#define TYPVAL_ENCODE_CONV_DICT_END() \
    typval_encode_dict_end(edata)

#define TYPVAL_ENCODE_CONV_RECURSE(val, conv_type) \
    TYPVAL_ENCODE_CONV_NIL()

TYPVAL_ENCODE_DEFINE_CONV_FUNCTIONS(static, object, EncodedData *const, edata)

#undef TYPVAL_ENCODE_CONV_STRING
#undef TYPVAL_ENCODE_CONV_STR_STRING
#undef TYPVAL_ENCODE_CONV_EXT_STRING
#undef TYPVAL_ENCODE_CONV_NUMBER
#undef TYPVAL_ENCODE_CONV_FLOAT
#undef TYPVAL_ENCODE_CONV_FUNC
#undef TYPVAL_ENCODE_CONV_EMPTY_LIST
#undef TYPVAL_ENCODE_CONV_LIST_START
#undef TYPVAL_ENCODE_CONV_EMPTY_DICT
#undef TYPVAL_ENCODE_CONV_NIL
#undef TYPVAL_ENCODE_CONV_BOOL
#undef TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER
#undef TYPVAL_ENCODE_CONV_DICT_START
#undef TYPVAL_ENCODE_CONV_DICT_END
#undef TYPVAL_ENCODE_CONV_DICT_AFTER_KEY
#undef TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS
#undef TYPVAL_ENCODE_CONV_SPECIAL_DICT_KEY_CHECK
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
  encode_vim_to_object(&edata, obj, "vim_to_object argument");
  Object ret = kv_A(edata.stack, 0);
  assert(kv_size(edata.stack) == 1);
  kv_destroy(edata.stack);
  return ret;
}

buf_T *find_buffer_by_handle(Buffer buffer, Error *err)
{
  buf_T *rv = handle_get_buffer(buffer);

  if (!rv) {
    api_set_error(err, Validation, _("Invalid buffer id"));
  }

  return rv;
}

win_T * find_window_by_handle(Window window, Error *err)
{
  win_T *rv = handle_get_window(window);

  if (!rv) {
    api_set_error(err, Validation, _("Invalid window id"));
  }

  return rv;
}

tabpage_T * find_tab_by_handle(Tabpage tabpage, Error *err)
{
  tabpage_T *rv = handle_get_tabpage(tabpage);

  if (!rv) {
    api_set_error(err, Validation, _("Invalid tabpage id"));
  }

  return rv;
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
  return (String) {.data = str, .size = strlen(str)};
}

bool object_to_vim(Object obj, typval_T *tv, Error *err)
{
  tv->v_type = VAR_UNKNOWN;
  tv->v_lock = 0;

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
      if (obj.data.integer > INT_MAX || obj.data.integer < INT_MIN) {
        api_set_error(err, Validation, _("Integer value outside range"));
        return false;
      }

      tv->v_type = VAR_NUMBER;
      tv->vval.v_number = (int)obj.data.integer;
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

    case kObjectTypeArray:
      tv->v_type = VAR_LIST;
      tv->vval.v_list = list_alloc();

      for (uint32_t i = 0; i < obj.data.array.size; i++) {
        Object item = obj.data.array.items[i];
        listitem_T *li = listitem_alloc();

        if (!object_to_vim(item, &li->li_tv, err)) {
          // cleanup
          listitem_free(li);
          list_free(tv->vval.v_list, true);
          return false;
        }

        list_append(tv->vval.v_list, li);
      }
      tv->vval.v_list->lv_refcount++;
      break;

    case kObjectTypeDictionary:
      tv->v_type = VAR_DICT;
      tv->vval.v_dict = dict_alloc();

      for (uint32_t i = 0; i < obj.data.dictionary.size; i++) {
        KeyValuePair item = obj.data.dictionary.items[i];
        String key = item.key;

        if (key.size == 0) {
          api_set_error(err,
                        Validation,
                        _("Empty dictionary keys aren't allowed"));
          // cleanup
          dict_free(tv->vval.v_dict, true);
          return false;
        }

        dictitem_T *di = dictitem_alloc((uint8_t *) key.data);

        if (!object_to_vim(item.value, &di->di_tv, err)) {
          // cleanup
          dictitem_free(di);
          dict_free(tv->vval.v_dict, true);
          return false;
        }

        dict_add(tv->vval.v_dict, di);
      }
      tv->vval.v_dict->dv_refcount++;
      break;
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

Dictionary api_metadata(void)
{
  static Dictionary metadata = ARRAY_DICT_INIT;

  if (!metadata.size) {
    msgpack_rpc_init_function_metadata(&metadata);
    init_error_type_metadata(&metadata);
    init_type_metadata(&metadata);
  }

  return copy_object(DICTIONARY_OBJ(metadata)).data.dictionary;
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
  PUT(buffer_metadata, "id", INTEGER_OBJ(kObjectTypeBuffer));

  Dictionary window_metadata = ARRAY_DICT_INIT;
  PUT(window_metadata, "id", INTEGER_OBJ(kObjectTypeWindow));

  Dictionary tabpage_metadata = ARRAY_DICT_INIT;
  PUT(tabpage_metadata, "id", INTEGER_OBJ(kObjectTypeTabpage));

  PUT(types, "Buffer", DICTIONARY_OBJ(buffer_metadata));
  PUT(types, "Window", DICTIONARY_OBJ(window_metadata));
  PUT(types, "Tabpage", DICTIONARY_OBJ(tabpage_metadata));

  PUT(*metadata, "types", DICTIONARY_OBJ(types));
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
      return STRING_OBJ(cstr_to_string(obj.data.string.data));

    case kObjectTypeArray: {
      Array rv = ARRAY_DICT_INIT;
      for (size_t i = 0; i < obj.data.array.size; i++) {
        ADD(rv, copy_object(obj.data.array.items[i]));
      }
      return ARRAY_OBJ(rv);
    }

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
  buf_T *save_curbuf = NULL;

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
                      Exception,
                      _("Problem while switching windows"));
        return;
      }
      set_option_value_err(key, numval, stringval, opt_flags, err);
      restore_win(save_curwin, save_curtab, true);
      break;
    case SREQ_BUF:
      switch_buffer(&save_curbuf, (buf_T *)from);
      set_option_value_err(key, numval, stringval, opt_flags, err);
      restore_buffer(save_curbuf);
      break;
    case SREQ_GLOBAL:
      set_option_value_err(key, numval, stringval, opt_flags, err);
      break;
  }

  if (err->set) {
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

  if ((errmsg = (char *)set_option_value((uint8_t *)key,
                                         numval,
                                         (uint8_t *)stringval,
                                         opt_flags)))
  {
    if (try_end(err)) {
      return;
    }

    api_set_error(err, Exception, "%s", errmsg);
  }
}
