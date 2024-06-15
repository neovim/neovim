#pragma once

#include <msgpack/pack.h>
#include <string.h>

#include "nvim/eval/typval_defs.h"
#include "nvim/garray_defs.h"
#include "nvim/msgpack_rpc/packer_defs.h"

/// Convert Vimscript value to msgpack string
///
/// @param[out]  packer  Packer to save results in.
/// @param[in]  tv  Dumped value.
/// @param[in]  objname  Object name, used for error message.
///
/// @return OK in case of success, FAIL otherwise.
int encode_vim_to_msgpack(PackerBuffer *packer, typval_T *tv, const char *objname);

/// Convert Vimscript value to :echo output
///
/// @param[out]  packer  Packer to save results in.
/// @param[in]  tv  Dumped value.
/// @param[in]  objname  Object name, used for error message.
///
/// @return OK in case of success, FAIL otherwise.
int encode_vim_to_echo(garray_T *packer, typval_T *tv, const char *objname);

/// Structure defining state for read_from_list()
typedef struct {
  const list_T *const list;  ///< List being currently read.
  const listitem_T *li;  ///< Item currently read.
  size_t offset;  ///< Byte offset inside the read item.
  size_t li_length;  ///< Length of the string inside the read item.
} ListReaderState;

/// Array mapping values from SpecialVarValue enum to names
extern const char *const encode_bool_var_names[];
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
