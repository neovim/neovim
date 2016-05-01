/// @file eval/typval_convert.h
///
/// Contains set of macros used to convert (possibly recursive) typval_T into
/// something else. For these macros to work the following macros must be
/// defined:

/// @def TYPVAL_ENCODE_CONV_NIL
/// @brief Macros used to convert NIL value
///
/// Is called both for special dictionary (unless #TYPVAL_ENCODE_ALLOW_SPECIALS
/// is false) and `v:null`. Accepts no arguments, but still must be
/// a function-like macros.

/// @def TYPVAL_ENCODE_CONV_BOOL
/// @brief Macros used to convert boolean value
///
/// Is called both for special dictionary (unless #TYPVAL_ENCODE_ALLOW_SPECIALS
/// is false) and `v:true`/`v:false`.
///
/// @param  num  Boolean value to convert. Value is an expression which
///              evaluates to some integer.

/// @def TYPVAL_ENCODE_CONV_NUMBER
/// @brief Macros used to convert integer
///
/// @param  num  Integer to convert, must accept both varnumber_T and int64_t.

/// @def TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER
/// @brief Macros used to convert unsigned integer
///
/// Not used if #TYPVAL_ENCODE_ALLOW_SPECIALS is false, but still must be
/// defined.
///
/// @param  num  Integer to convert, must accept uint64_t.

/// @def TYPVAL_ENCODE_CONV_FLOAT
/// @brief Macros used to convert floating-point number
///
/// @param  flt  Number to convert, must accept float_T.

/// @def TYPVAL_ENCODE_CONV_STRING
/// @brief Macros used to convert plain string
///
/// Is used to convert VAR_STRING objects as well as BIN strings represented as
/// special dictionary.
///
/// @param  buf  String to convert. Is a char[] buffer, not NUL-terminated.
/// @param  len  String length.

/// @def TYPVAL_ENCODE_CONV_STR_STRING
/// @brief Like #TYPVAL_ENCODE_CONV_STRING, but for STR strings
///
/// Is used to convert dictionary keys and STR strings represented as special
/// dictionaries.

/// @def TYPVAL_ENCODE_CONV_EXT_STRING
/// @brief Macros used to convert EXT string
///
/// Is used to convert EXT strings represented as special dictionaries. Never
/// actually used if #TYPVAL_ENCODE_ALLOW_SPECIALS is false, but still must be
/// defined.
///
/// @param  buf  String to convert. Is a char[] buffer, not NUL-terminated.
/// @param  len  String length.
/// @param  type  EXT type.

/// @def TYPVAL_ENCODE_CONV_FUNC
/// @brief Macros used to convert a function reference
///
/// @param  fun  Function name.

/// @def TYPVAL_ENCODE_CONV_EMPTY_LIST
/// @brief Macros used to convert an empty list
///
/// Accepts no arguments, but still must be a function-like macros.

/// @def TYPVAL_ENCODE_CONV_EMPTY_DICT
/// @brief Macros used to convert an empty dictionary
///
/// Accepts no arguments, but still must be a function-like macros.

/// @def TYPVAL_ENCODE_CONV_LIST_START
/// @brief Macros used before starting to convert non-empty list
///
/// @param  len  List length. Is an expression which evaluates to an integer.

/// @def TYPVAL_ENCODE_CONV_LIST_BETWEEN_ITEMS
/// @brief Macros used after finishing converting non-last list item
///
/// Accepts no arguments, but still must be a function-like macros.

/// @def TYPVAL_ENCODE_CONV_LIST_END
/// @brief Macros used after converting non-empty list
///
/// Accepts no arguments, but still must be a function-like macros.

/// @def TYPVAL_ENCODE_CONV_DICT_START
/// @brief Macros used before starting to convert non-empty dictionary
///
/// @param  len  Dictionary length. Is an expression which evaluates to an
///              integer.

/// @def TYPVAL_ENCODE_CONV_SPECIAL_DICT_KEY_CHECK
/// @brief Macros used to check special dictionary key
///
/// @param  label  Label for goto in case check was not successfull.
/// @param  kv_pair  List with two elements: key and value.

/// @def TYPVAL_ENCODE_CONV_DICT_AFTER_KEY
/// @brief Macros used after finishing converting dictionary key
///
/// Accepts no arguments, but still must be a function-like macros.

/// @def TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS
/// @brief Macros used after finishing converting non-last dictionary value
///
/// Accepts no arguments, but still must be a function-like macros.

/// @def TYPVAL_ENCODE_CONV_DICT_END
/// @brief Macros used after converting non-empty dictionary
///
/// Accepts no arguments, but still must be a function-like macros.

/// @def TYPVAL_ENCODE_CONV_RECURSE
/// @brief Macros used when self-containing container is detected
///
/// @param  val  Container for which this situation was detected.
/// @param  conv_type  Type of the stack entry, @see MPConvStackValType.

/// @def TYPVAL_ENCODE_ALLOW_SPECIALS
/// @brief Macros that specifies whether special dictionaries are special
///
/// Must be something that evaluates to boolean, most likely `true` or `false`.
/// If it is false then special dictionaries are not treated specially.
#ifndef NVIM_EVAL_TYPVAL_ENCODE_H
#define NVIM_EVAL_TYPVAL_ENCODE_H

#include <stddef.h>
#include <inttypes.h>
#include <assert.h>

#include "nvim/lib/kvec.h"
#include "nvim/eval_defs.h"
#include "nvim/eval/encode.h"
#include "nvim/func_attr.h"

/// Type of the stack entry
typedef enum {
  kMPConvDict,   ///< Convert dict_T *dictionary.
  kMPConvList,   ///< Convert list_T *list.
  kMPConvPairs,  ///< Convert mapping represented as a list_T* of pairs.
} MPConvStackValType;

/// Structure representing current VimL to messagepack conversion state
typedef struct {
  MPConvStackValType type;  ///< Type of the stack entry.
  union {
    struct {
      dict_T *dict;    ///< Currently converted dictionary.
      hashitem_T *hi;  ///< Currently converted dictionary item.
      size_t todo;     ///< Amount of items left to process.
    } d;  ///< State of dictionary conversion.
    struct {
      list_T *list;    ///< Currently converted list.
      listitem_T *li;  ///< Currently converted list item.
    } l;  ///< State of list or generic mapping conversion.
  } data;  ///< Data to convert.
} MPConvStackVal;

/// Stack used to convert VimL values to messagepack.
typedef kvec_t(MPConvStackVal) MPConvStack;

// Defines for MPConvStack
#define _mp_size kv_size
#define _mp_init kv_init
#define _mp_destroy kv_destroy
#define _mp_push kv_push
#define _mp_pop kv_pop
#define _mp_last kv_last

/// Code for checking whether container references itself
///
/// @param[in,out]  val  Container to check.
/// @param  copyID_attr  Name of the container attribute that holds copyID.
///                      After checking whether value of this attribute is
///                      copyID (variable) it is set to copyID.
#define _TYPVAL_ENCODE_CHECK_SELF_REFERENCE(val, copyID_attr, conv_type) \
    do { \
      if ((val)->copyID_attr == copyID) { \
        TYPVAL_ENCODE_CONV_RECURSE((val), conv_type); \
      } \
      (val)->copyID_attr = copyID; \
    } while (0)

/// Length of the string stored in typval_T
///
/// @param[in]  tv  String for which to compute length for. Must be typval_T
///                 with VAR_STRING.
///
/// @return Length of the string stored in typval_T, including 0 for NULL
///         string.
static inline size_t tv_strlen(const typval_T *const tv)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
  FUNC_ATTR_NONNULL_ALL
{
  assert(tv->v_type == VAR_STRING);
  return (tv->vval.v_string == NULL
          ? 0
          : strlen((char *) tv->vval.v_string));
}

/// Define functions which convert VimL value to something else
///
/// Creates function `vim_to_{name}(firstargtype firstargname, typval_T *const
/// tv)` which returns OK or FAIL and helper functions.
///
/// @param  scope  Scope of the main function: either nothing or `static`.
/// @param  firstargtype  Type of the first argument. It will be used to return
///                       the results.
/// @param  firstargname  Name of the first argument.
/// @param  name  Name of the target converter.
#define TYPVAL_ENCODE_DEFINE_CONV_FUNCTIONS(scope, name, firstargtype, \
                                            firstargname) \
static int name##_convert_one_value(firstargtype firstargname, \
                                    MPConvStack *const mpstack, \
                                    typval_T *const tv, \
                                    const int copyID, \
                                    const char *const objname) \
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT \
{ \
  switch (tv->v_type) { \
    case VAR_STRING: { \
      TYPVAL_ENCODE_CONV_STRING(tv->vval.v_string, tv_strlen(tv)); \
      break; \
    } \
    case VAR_NUMBER: { \
      TYPVAL_ENCODE_CONV_NUMBER(tv->vval.v_number); \
      break; \
    } \
    case VAR_FLOAT: { \
      TYPVAL_ENCODE_CONV_FLOAT(tv->vval.v_float); \
      break; \
    } \
    case VAR_FUNC: { \
      TYPVAL_ENCODE_CONV_FUNC(tv->vval.v_string); \
      break; \
    } \
    case VAR_LIST: { \
      if (tv->vval.v_list == NULL || tv->vval.v_list->lv_len == 0) { \
        TYPVAL_ENCODE_CONV_EMPTY_LIST(); \
        break; \
      } \
      _TYPVAL_ENCODE_CHECK_SELF_REFERENCE(tv->vval.v_list, lv_copyID, \
                                          kMPConvList); \
      TYPVAL_ENCODE_CONV_LIST_START(tv->vval.v_list->lv_len); \
      _mp_push(*mpstack, ((MPConvStackVal) { \
        .type = kMPConvList, \
        .data = { \
          .l = { \
            .list = tv->vval.v_list, \
            .li = tv->vval.v_list->lv_first, \
          }, \
        }, \
      })); \
      break; \
    } \
    case VAR_SPECIAL: { \
      switch (tv->vval.v_special) { \
        case kSpecialVarNull: { \
          TYPVAL_ENCODE_CONV_NIL(); \
          break; \
        } \
        case kSpecialVarTrue: \
        case kSpecialVarFalse: { \
          TYPVAL_ENCODE_CONV_BOOL(tv->vval.v_special == kSpecialVarTrue); \
          break; \
        } \
      } \
      break; \
    } \
    case VAR_DICT: { \
      if (tv->vval.v_dict == NULL \
          || tv->vval.v_dict->dv_hashtab.ht_used == 0) { \
        TYPVAL_ENCODE_CONV_EMPTY_DICT(); \
        break; \
      } \
      const dictitem_T *type_di; \
      const dictitem_T *val_di; \
      if (TYPVAL_ENCODE_ALLOW_SPECIALS \
          && tv->vval.v_dict->dv_hashtab.ht_used == 2 \
          && (type_di = dict_find((dict_T *) tv->vval.v_dict, \
                                  (char_u *) "_TYPE", -1)) != NULL \
          && type_di->di_tv.v_type == VAR_LIST \
          && (val_di = dict_find((dict_T *) tv->vval.v_dict, \
                                 (char_u *) "_VAL", -1)) != NULL) { \
        size_t i; \
        for (i = 0; i < ARRAY_SIZE(eval_msgpack_type_lists); i++) { \
          if (type_di->di_tv.vval.v_list == eval_msgpack_type_lists[i]) { \
            break; \
          } \
        } \
        if (i == ARRAY_SIZE(eval_msgpack_type_lists)) { \
          goto name##_convert_one_value_regular_dict; \
        } \
        switch ((MessagePackType) i) { \
          case kMPNil: { \
            TYPVAL_ENCODE_CONV_NIL(); \
            break; \
          } \
          case kMPBoolean: { \
            if (val_di->di_tv.v_type != VAR_NUMBER) { \
              goto name##_convert_one_value_regular_dict; \
            } \
            TYPVAL_ENCODE_CONV_BOOL(val_di->di_tv.vval.v_number); \
            break; \
          } \
          case kMPInteger: { \
            const list_T *val_list; \
            varnumber_T sign; \
            varnumber_T highest_bits; \
            varnumber_T high_bits; \
            varnumber_T low_bits; \
            /* List of 4 integers; first is signed (should be 1 or -1, but */ \
            /* this is not checked), second is unsigned and have at most */ \
            /* one (sign is -1) or two (sign is 1) non-zero bits (number of */ \
            /* bits is not checked), other unsigned and have at most 31 */ \
            /* non-zero bits (number of bits is not checked).*/ \
            if (val_di->di_tv.v_type != VAR_LIST \
                || (val_list = val_di->di_tv.vval.v_list) == NULL \
                || val_list->lv_len != 4 \
                || val_list->lv_first->li_tv.v_type != VAR_NUMBER \
                || (sign = val_list->lv_first->li_tv.vval.v_number) == 0 \
                || val_list->lv_first->li_next->li_tv.v_type != VAR_NUMBER \
                || (highest_bits = \
                    val_list->lv_first->li_next->li_tv.vval.v_number) < 0 \
                || val_list->lv_last->li_prev->li_tv.v_type != VAR_NUMBER \
                || (high_bits = \
                    val_list->lv_last->li_prev->li_tv.vval.v_number) < 0 \
                || val_list->lv_last->li_tv.v_type != VAR_NUMBER \
                || (low_bits = val_list->lv_last->li_tv.vval.v_number) < 0) { \
              goto name##_convert_one_value_regular_dict; \
            } \
            uint64_t number = ((uint64_t) (((uint64_t) highest_bits) << 62) \
                               | (uint64_t) (((uint64_t) high_bits) << 31) \
                               | (uint64_t) low_bits); \
            if (sign > 0) { \
              TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER(number); \
            } else { \
              TYPVAL_ENCODE_CONV_NUMBER(-number); \
            } \
            break; \
          } \
          case kMPFloat: { \
            if (val_di->di_tv.v_type != VAR_FLOAT) { \
              goto name##_convert_one_value_regular_dict; \
            } \
            TYPVAL_ENCODE_CONV_FLOAT(val_di->di_tv.vval.v_float); \
            break; \
          } \
          case kMPString: \
          case kMPBinary: { \
            const bool is_string = ((MessagePackType) i == kMPString); \
            if (val_di->di_tv.v_type != VAR_LIST) { \
              goto name##_convert_one_value_regular_dict; \
            } \
            size_t len; \
            char *buf; \
            if (!encode_vim_list_to_buf(val_di->di_tv.vval.v_list, &len, \
                                        &buf)) { \
              goto name##_convert_one_value_regular_dict; \
            } \
            if (is_string) { \
              TYPVAL_ENCODE_CONV_STR_STRING(buf, len); \
            } else { \
              TYPVAL_ENCODE_CONV_STRING(buf, len); \
            } \
            xfree(buf); \
            break; \
          } \
          case kMPArray: { \
            if (val_di->di_tv.v_type != VAR_LIST) { \
              goto name##_convert_one_value_regular_dict; \
            } \
            _TYPVAL_ENCODE_CHECK_SELF_REFERENCE(val_di->di_tv.vval.v_list, \
                                                lv_copyID, kMPConvList); \
            TYPVAL_ENCODE_CONV_LIST_START(val_di->di_tv.vval.v_list->lv_len); \
            _mp_push(*mpstack, ((MPConvStackVal) { \
              .type = kMPConvList, \
              .data = { \
                .l = { \
                  .list = val_di->di_tv.vval.v_list, \
                  .li = val_di->di_tv.vval.v_list->lv_first, \
                }, \
              }, \
            })); \
            break; \
          } \
          case kMPMap: { \
            if (val_di->di_tv.v_type != VAR_LIST) { \
              goto name##_convert_one_value_regular_dict; \
            } \
            list_T *const val_list = val_di->di_tv.vval.v_list; \
            if (val_list == NULL || val_list->lv_len == 0) { \
              TYPVAL_ENCODE_CONV_EMPTY_DICT(); \
              break; \
            } \
            for (const listitem_T *li = val_list->lv_first; li != NULL; \
                 li = li->li_next) { \
              if (li->li_tv.v_type != VAR_LIST \
                  || li->li_tv.vval.v_list->lv_len != 2) { \
                goto name##_convert_one_value_regular_dict; \
              } \
            } \
            _TYPVAL_ENCODE_CHECK_SELF_REFERENCE(val_list, lv_copyID, \
                                                kMPConvPairs); \
            TYPVAL_ENCODE_CONV_DICT_START(val_list->lv_len); \
            _mp_push(*mpstack, ((MPConvStackVal) { \
              .type = kMPConvPairs, \
              .data = { \
                .l = { \
                  .list = val_list, \
                  .li = val_list->lv_first, \
                }, \
              }, \
            })); \
            break; \
          } \
          case kMPExt: { \
            const list_T *val_list; \
            varnumber_T type; \
            if (val_di->di_tv.v_type != VAR_LIST \
                || (val_list = val_di->di_tv.vval.v_list) == NULL \
                || val_list->lv_len != 2 \
                || (val_list->lv_first->li_tv.v_type != VAR_NUMBER) \
                || (type = val_list->lv_first->li_tv.vval.v_number) > INT8_MAX \
                || type < INT8_MIN \
                || (val_list->lv_last->li_tv.v_type != VAR_LIST)) { \
              goto name##_convert_one_value_regular_dict; \
            } \
            size_t len; \
            char *buf; \
            if (!encode_vim_list_to_buf(val_list->lv_last->li_tv.vval.v_list, \
                                        &len, &buf)) { \
              goto name##_convert_one_value_regular_dict; \
            } \
            TYPVAL_ENCODE_CONV_EXT_STRING(buf, len, type); \
            xfree(buf); \
            break; \
          } \
        } \
        break; \
      } \
name##_convert_one_value_regular_dict: \
      _TYPVAL_ENCODE_CHECK_SELF_REFERENCE(tv->vval.v_dict, dv_copyID, \
                                          kMPConvDict); \
      TYPVAL_ENCODE_CONV_DICT_START(tv->vval.v_dict->dv_hashtab.ht_used); \
      _mp_push(*mpstack, ((MPConvStackVal) { \
        .type = kMPConvDict, \
        .data = { \
          .d = { \
            .dict = tv->vval.v_dict, \
            .hi = tv->vval.v_dict->dv_hashtab.ht_array, \
            .todo = tv->vval.v_dict->dv_hashtab.ht_used, \
          }, \
        }, \
      })); \
      break; \
    } \
    case VAR_UNKNOWN: { \
      EMSG2(_(e_intern2), #name "_convert_one_value()"); \
      return FAIL; \
    } \
  } \
  return OK; \
} \
\
scope int encode_vim_to_##name(firstargtype firstargname, typval_T *const tv, \
                               const char *const objname) \
  FUNC_ATTR_WARN_UNUSED_RESULT \
{ \
  const int copyID = get_copyID(); \
  MPConvStack mpstack; \
  _mp_init(mpstack); \
  if (name##_convert_one_value(firstargname, &mpstack, tv, copyID, objname) \
      == FAIL) { \
    goto encode_vim_to_##name##_error_ret; \
  } \
  while (_mp_size(mpstack)) { \
    MPConvStackVal *cur_mpsv = &_mp_last(mpstack); \
    typval_T *cur_tv = NULL; \
    switch (cur_mpsv->type) { \
      case kMPConvDict: { \
        if (!cur_mpsv->data.d.todo) { \
          (void) _mp_pop(mpstack); \
          cur_mpsv->data.d.dict->dv_copyID = copyID - 1; \
          TYPVAL_ENCODE_CONV_DICT_END(); \
          continue; \
        } else if (cur_mpsv->data.d.todo \
                   != cur_mpsv->data.d.dict->dv_hashtab.ht_used) { \
          TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS(); \
        } \
        while (HASHITEM_EMPTY(cur_mpsv->data.d.hi)) { \
          cur_mpsv->data.d.hi++; \
        } \
        dictitem_T *const di = HI2DI(cur_mpsv->data.d.hi); \
        cur_mpsv->data.d.todo--; \
        cur_mpsv->data.d.hi++; \
        TYPVAL_ENCODE_CONV_STR_STRING(&di->di_key[0], \
                                      strlen((char *) &di->di_key[0])); \
        TYPVAL_ENCODE_CONV_DICT_AFTER_KEY(); \
        cur_tv = &di->di_tv; \
        break; \
      } \
      case kMPConvList: { \
        if (cur_mpsv->data.l.li == NULL) { \
          (void) _mp_pop(mpstack); \
          cur_mpsv->data.l.list->lv_copyID = copyID - 1; \
          TYPVAL_ENCODE_CONV_LIST_END(); \
          continue; \
        } else if (cur_mpsv->data.l.li != cur_mpsv->data.l.list->lv_first) { \
          TYPVAL_ENCODE_CONV_LIST_BETWEEN_ITEMS(); \
        } \
        cur_tv = &cur_mpsv->data.l.li->li_tv; \
        cur_mpsv->data.l.li = cur_mpsv->data.l.li->li_next; \
        break; \
      } \
      case kMPConvPairs: { \
        if (cur_mpsv->data.l.li == NULL) { \
          (void) _mp_pop(mpstack); \
          cur_mpsv->data.l.list->lv_copyID = copyID - 1; \
          TYPVAL_ENCODE_CONV_DICT_END(); \
          continue; \
        } else if (cur_mpsv->data.l.li != cur_mpsv->data.l.list->lv_first) { \
          TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS(); \
        } \
        const list_T *const kv_pair = cur_mpsv->data.l.li->li_tv.vval.v_list; \
        TYPVAL_ENCODE_CONV_SPECIAL_DICT_KEY_CHECK( \
            encode_vim_to_##name##_error_ret, kv_pair); \
        if (name##_convert_one_value(firstargname, &mpstack, \
                                     &kv_pair->lv_first->li_tv, copyID, \
                                     objname) == FAIL) { \
          goto encode_vim_to_##name##_error_ret; \
        } \
        TYPVAL_ENCODE_CONV_DICT_AFTER_KEY(); \
        cur_tv = &kv_pair->lv_last->li_tv; \
        cur_mpsv->data.l.li = cur_mpsv->data.l.li->li_next; \
        break; \
      } \
    } \
    assert(cur_tv != NULL); \
    if (name##_convert_one_value(firstargname, &mpstack, cur_tv, copyID, \
                                 objname) == FAIL) { \
      goto encode_vim_to_##name##_error_ret; \
    } \
  } \
  _mp_destroy(mpstack); \
  return OK; \
encode_vim_to_##name##_error_ret: \
  _mp_destroy(mpstack); \
  return FAIL; \
}

#endif  // NVIM_EVAL_TYPVAL_ENCODE_H
