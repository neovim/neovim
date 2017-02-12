/// @file eval/typval_encode_types.h
///
/// Contains common definitions for eval/typval_encode.h,
/// eval/typval_encode.c.h and its users.
#ifndef NVIM_EVAL_TYPVAL_ENCODE_TYPES_H
#define NVIM_EVAL_TYPVAL_ENCODE_TYPES_H

#include "nvim/eval_defs.h"

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
  int saved_copyID;  ///< copyID item used to have.
  union {
    struct {
      dict_T *dict;    ///< Currently converted dictionary.
      dict_T **dictp;  ///< Location where that dictionary is stored.
                       ///< Normally it is &.tv->vval.v_dict, but not when
                       ///< converting partials.
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

#endif  // NVIM_EVAL_TYPVAL_ENCODE_TYPES_H
