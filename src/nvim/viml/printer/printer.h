#ifndef NVIM_VIML_PRINTER_PRINTER_H
#define NVIM_VIML_PRINTER_PRINTER_H

#include <stddef.h>
#include "nvim/viml/parser/expressions.h"

typedef struct {
  size_t before;
  size_t after;
} _BeforeAfterSpaces;

typedef struct {
  size_t after_start;
  size_t before_end;
} _StartEndSpaces;

// XXX Never defined: not needed: it should crash in case branch with
//     _error_spaces is reached.
const _BeforeAfterSpaces _error_spaces;
typedef struct {
  struct expression_options {
    struct {
      _BeforeAfterSpaces logical[LOGICAL_LENGTH];
      _BeforeAfterSpaces comparison[COMPARISON_LENGTH];
      _BeforeAfterSpaces arithmetic[ARITHMETIC_LENGTH];
      struct {
        _BeforeAfterSpaces concat;
      } string;
      _BeforeAfterSpaces unary[UNARY_LENGTH];
      struct {
        _BeforeAfterSpaces condition;
        _BeforeAfterSpaces values;
      } ternary;
    } operators;
    struct {
      _StartEndSpaces braces;
      _BeforeAfterSpaces item;
      bool trailing_comma;
    } list;
    struct {
      _StartEndSpaces curly_braces;
      _BeforeAfterSpaces key;
      _BeforeAfterSpaces item;
      bool trailing_comma;
    } dictionary;
    _StartEndSpaces curly_name;
    struct {
      _BeforeAfterSpaces slice;
      _StartEndSpaces brackets;
    } subscript;
    struct {
      size_t before_subscript;
      _StartEndSpaces call;
      _BeforeAfterSpaces argument;
    } function_call;
  } expression;
  struct {
    char *indent;
    struct {
      _BeforeAfterSpaces assign;
      _BeforeAfterSpaces add;
      _BeforeAfterSpaces subtract;
      _BeforeAfterSpaces concat;
    } let;
    struct {
      size_t before_subscript;
      _StartEndSpaces call;
      _BeforeAfterSpaces argument;
      size_t before_attribute;
    } function;
    struct {
      size_t before_inline;
      size_t before_text;
    } comment;
    struct {
      bool ast_glob;
    } glob;
    struct {
      bool display_short;
    } set;
    struct {
      bool use_ampersand;
    } substitute;
    struct {
      const char *cmd_separator;
    } do_cmd;
    struct {
      const char *cmd_separator;
    } autocmd;
    struct {
      bool explicit_nargs;
      const char *cmd_separator;
    } command;
    struct {
      bool use_character;
    } history;
    struct {
      const char *cmd_separator;
    } global;
  } command;
  bool magic;
  struct {
    const char *string;
    size_t len;
  } newline;
} StyleOptions;

typedef struct expression_options ExprStyleOptions;
const StyleOptions default_po;

#endif  // NVIM_VIML_PRINTER_PRINTER_H
