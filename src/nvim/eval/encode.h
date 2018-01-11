#ifndef NVIM_EVAL_ENCODE_H
#define NVIM_EVAL_ENCODE_H

#include <stddef.h>

#include <msgpack.h>

#include "nvim/eval.h"
#include "nvim/garray.h"
#include "nvim/vim.h"  // For STRLEN

/// Convert VimL value to msgpack string
///
/// @param[out]  packer  Packer to save results in.
/// @param[in]  tv  Dumped value.
/// @param[in]  objname  Object name, used for error message.
///
/// @return OK in case of success, FAIL otherwise.
int encode_vim_to_msgpack(msgpack_packer *const packer,
                          typval_T *const tv,
                          const char *const objname);

/// Convert VimL value to :echo output
///
/// @param[out]  packer  Packer to save results in.
/// @param[in]  tv  Dumped value.
/// @param[in]  objname  Object name, used for error message.
///
/// @return OK in case of success, FAIL otherwise.
int encode_vim_to_echo(garray_T *const packer,
                       typval_T *const tv,
                       const char *const objname);

/// Structure defining state for read_from_list()
typedef struct {
  const list_T *const list;  ///< List being currently read.
  const listitem_T *li;  ///< Item currently read.
  size_t offset;  ///< Byte offset inside the read item.
  size_t li_length;  ///< Length of the string inside the read item.
} ListReaderState;

/// Initialize ListReaderState structure
static inline ListReaderState encode_init_lrstate(const list_T *const list)
  FUNC_ATTR_NONNULL_ALL
{
  return (ListReaderState) {
    .list = list,
    .li = tv_list_first(list),
    .offset = 0,
    .li_length = (TV_LIST_ITEM_TV(tv_list_first(list))->vval.v_string == NULL
                  ? 0
                  : STRLEN(TV_LIST_ITEM_TV(
                      tv_list_first(list))->vval.v_string)),
  };
}

/// Array mapping values from SpecialVarValue enum to names
extern const char *const encode_special_var_names[];

/// First codepoint in high surrogates block
#define SURROGATE_HI_START 0xD800

/// Last codepoint in high surrogates block
#define SURROGATE_HI_END   0xDBFF

/// First codepoint in low surrogates block
#define SURROGATE_LO_START 0xDC00

/// Last codepoint in low surrogates block
#define SURROGATE_LO_END   0xDFFF

/// First character that needs to be encoded as surrogate pair
#define SURROGATE_FIRST_CHAR 0x10000

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/encode.h.generated.h"
#endif
#endif  // NVIM_EVAL_ENCODE_H
