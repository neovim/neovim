#pragma once

#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/register_defs.h"

/// Used by TextPutPost/TextPutPre autocommands for the '.' register. If
/// "add_last_insert" is == 1, then "stuff_inserted" will add the last inserted
/// text to "last_insert_ga".
EXTERN garray_T last_insert_ga INIT( = { 0, 0, 1, 64, NULL });
EXTERN int add_last_insert INIT( = 0);

#include "register.h.generated.h"
#include "register.h.inline.generated.h"

/// @see get_yank_register
/// @return  true when register should be inserted literally
/// (selection or clipboard)
static inline bool is_literal_register(const int regname)
  FUNC_ATTR_CONST
{
  return regname == '*' || regname == '+' || ASCII_ISALNUM(regname);
}

/// Convert register name into register index
///
/// @param[in]  regname  Register name.
///
/// @return Index in y_regs array or -1 if register name was not recognized.
static inline int op_reg_index(const int regname)
  FUNC_ATTR_CONST
{
  if (ascii_isdigit(regname)) {
    return regname - '0';
  } else if (ASCII_ISLOWER(regname)) {
    return CHAR_ORD_LOW(regname) + 10;
  } else if (ASCII_ISUPPER(regname)) {
    return CHAR_ORD_UP(regname) + 10;
  } else if (regname == '-') {
    return DELETION_REGISTER;
  } else if (regname == '*') {
    return STAR_REGISTER;
  } else if (regname == '+') {
    return PLUS_REGISTER;
  } else {
    return -1;
  }
}

static inline bool is_append_register(int regname)
  FUNC_ATTR_CONST
{
  return ASCII_ISUPPER(regname);
}

/// @return  the character name of the register with the given number
static inline int get_register_name(int num)
  FUNC_ATTR_CONST
{
  if (num == -1) {
    return '"';
  } else if (num < 10) {
    return num + '0';
  } else if (num == DELETION_REGISTER) {
    return '-';
  } else if (num == STAR_REGISTER) {
    return '*';
  } else if (num == PLUS_REGISTER) {
    return '+';
  } else {
    return num + 'a' - 10;
  }
}

/// Build the |RegisterChanged| value of a special register - "/, "=, ": or ". -
/// whose contents are a single NUL-terminated line.
///
/// NULL is the unset value, which is reported as an empty list: a special
/// register cannot distinguish "unset" from "empty", and a handler must treat
/// the two renderings as the same state.
///
/// The String has to outlive the call, so this takes one the caller owns. Use
/// the REG_VALUE_CSTR() wrapper, which supplies a compound literal for it.
static inline RegValue reg_value_cstr(String *s)
  FUNC_ATTR_NONNULL_ALL
{
  if (s->data == NULL) {
    return (RegValue){ .type = kMTCharWise };
  }
  s->size = strlen(s->data);
  return (RegValue){ .lines = s, .count = 1, .type = kMTCharWise };
}

/// @see reg_value_cstr
#define REG_VALUE_CSTR(s) reg_value_cstr(&(String){ .data = (char *)(s) })

/// Check whether register is empty
static inline bool reg_empty(const yankreg_T *const reg)
  FUNC_ATTR_PURE
{
  return (reg->y_array == NULL
          || reg->y_size == 0
          || (reg->y_size == 1
              && reg->y_type == kMTCharWise
              && reg->y_array[0].size == 0));
}
