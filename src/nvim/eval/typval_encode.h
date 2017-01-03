/// @file eval/typval_encode.h
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

/// @def TYPVAL_ENCODE_CONV_FUNC_START
/// @brief Macros used when starting to convert a funcref or a partial
///
/// @param  fun  Function name.
/// @param  is_partial  True if converted function is a partial.
/// @param  pt  Pointer to partial or NULL.

/// @def TYPVAL_ENCODE_CONV_FUNC_BEFORE_ARGS
/// @brief Macros used before starting to convert partial arguments
///
/// @param  len  Number of arguments. Zero for absent arguments or when
///              converting a funcref.

/// @def TYPVAL_ENCODE_CONV_FUNC_BEFORE_SELF
/// @brief Macros used before starting to convert self dictionary
///
/// @param  len  Number of arguments. May be zero for empty dictionary or -1 for
///              missing self dictionary, also when converting function
///              reference.

/// @def TYPVAL_ENCODE_CONV_FUNC_END
/// @brief Macros used after converting a funcref or a partial
///
/// Accepts no arguments, but still must be a function-like macros.

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
/// @param  key  typval_T key to check.

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
#include <string.h>
#include <assert.h>

#include "nvim/lib/kvec.h"
#include "nvim/eval_defs.h"
#include "nvim/func_attr.h"

/// Type of the stack entry
typedef enum {
  kMPConvDict,  ///< Convert dict_T *dictionary.
  kMPConvList,  ///< Convert list_T *list.
  kMPConvPairs,  ///< Convert mapping represented as a list_T* of pairs.
  kMPConvPartial,  ///< Convert partial_T* partial.
  kMPConvPartialList,  ///< Convert argc/argv pair coming from a partial.
} MPConvStackValType;

/// Stage at which partial is being converted
typedef enum {
  kMPConvPartialArgs,  ///< About to convert arguments.
  kMPConvPartialSelf,  ///< About to convert self dictionary.
  kMPConvPartialEnd,  ///< Already converted everything.
} MPConvPartialStage;

/// Structure representing current VimL to messagepack conversion state
typedef struct {
  MPConvStackValType type;  ///< Type of the stack entry.
  typval_T *tv;  ///< Currently converted typval_T.
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
    struct {
      MPConvPartialStage stage;  ///< Stage at which partial is being converted.
      partial_T *pt;  ///< Currently converted partial.
    } p;  ///< State of partial conversion.
    struct {
      typval_T *arg;    ///< Currently converted argument.
      typval_T *argv;    ///< Start of the argument list.
      size_t todo;  ///< Number of items left to process.
    } a;  ///< State of list or generic mapping conversion.
  } data;  ///< Data to convert.
} MPConvStackVal;

/// Stack used to convert VimL values to messagepack.
typedef kvec_withinit_t(MPConvStackVal, 8) MPConvStack;

// Defines for MPConvStack
#define _mp_size kv_size
#define _mp_init kvi_init
#define _mp_destroy kvi_destroy
#define _mp_push kvi_push
#define _mp_pop kv_pop
#define _mp_last kv_last

static inline size_t tv_strlen(const typval_T *const tv)
  REAL_FATTR_ALWAYS_INLINE REAL_FATTR_PURE REAL_FATTR_WARN_UNUSED_RESULT
  REAL_FATTR_NONNULL_ALL;

/// Length of the string stored in typval_T
///
/// @param[in]  tv  String for which to compute length for. Must be typval_T
///                 with VAR_STRING.
///
/// @return Length of the string stored in typval_T, including 0 for NULL
///         string.
static inline size_t tv_strlen(const typval_T *const tv)
{
  assert(tv->v_type == VAR_STRING);
  return (tv->vval.v_string == NULL
          ? 0
          : strlen((char *) tv->vval.v_string));
}

/// Code for checking whether container references itself
///
/// @param[in,out]  val  Container to check.
/// @param  copyID_attr  Name of the container attribute that holds copyID.
///                      After checking whether value of this attribute is
///                      copyID (variable) it is set to copyID.
/// @param[in]  copyID  CopyID used by the caller.
/// @param  conv_type  Type of the conversion, @see MPConvStackValType.
#define _TYPVAL_ENCODE_DO_CHECK_SELF_REFERENCE(val, copyID_attr, copyID, \
                                               conv_type) \
    do { \
      const int te_csr_ret = _TYPVAL_ENCODE_CHECK_SELF_REFERENCE( \
          TYPVAL_ENCODE_FIRST_ARG_NAME, \
          (val), &(val)->copyID_attr, mpstack, copyID, conv_type, objname); \
      if (te_csr_ret != NOTDONE) { \
        return te_csr_ret; \
      } \
    } while (0)

#define _TYPVAL_ENCODE_CHECK_SELF_REFERENCE_INNER_2(name) \
    _typval_encode_##name##_check_self_reference
#define _TYPVAL_ENCODE_CHECK_SELF_REFERENCE_INNER(name) \
    _TYPVAL_ENCODE_CHECK_SELF_REFERENCE_INNER_2(name)

/// Self reference checker function name
#define _TYPVAL_ENCODE_CHECK_SELF_REFERENCE \
    _TYPVAL_ENCODE_CHECK_SELF_REFERENCE_INNER(TYPVAL_ENCODE_NAME)

#define _TYPVAL_ENCODE_ENCODE_INNER_2(name) encode_vim_to_##name
#define _TYPVAL_ENCODE_ENCODE_INNER(name) _TYPVAL_ENCODE_ENCODE_INNER_2(name)

/// Entry point function name
#define _TYPVAL_ENCODE_ENCODE _TYPVAL_ENCODE_ENCODE_INNER(TYPVAL_ENCODE_NAME)

#define _TYPVAL_ENCODE_CONVERT_ONE_VALUE_INNER_2(name) \
    _typval_encode_##name##_convert_one_value
#define _TYPVAL_ENCODE_CONVERT_ONE_VALUE_INNER(name) \
    _TYPVAL_ENCODE_CONVERT_ONE_VALUE_INNER_2(name)

/// Name of the …convert_one_value function
#define _TYPVAL_ENCODE_CONVERT_ONE_VALUE \
    _TYPVAL_ENCODE_CONVERT_ONE_VALUE_INNER(TYPVAL_ENCODE_NAME)

#define _TYPVAL_ENCODE_NODICT_VAR_INNER_2(name) \
    _typval_encode_##name##_nodict_var
#define _TYPVAL_ENCODE_NODICT_VAR_INNER(name) \
    _TYPVAL_ENCODE_NODICT_VAR_INNER_2(name)

/// Name of the dummy const dict_T *const variable
#define TYPVAL_ENCODE_NODICT_VAR \
    _TYPVAL_ENCODE_NODICT_VAR_INNER(TYPVAL_ENCODE_NAME)

#endif  // NVIM_EVAL_TYPVAL_ENCODE_H
