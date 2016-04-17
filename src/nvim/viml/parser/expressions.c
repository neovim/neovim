// vim: ts=8 sts=2 sw=2 tw=80
//
// NeoVim - Neo Vi IMproved
//
// Do ":help uganda"  in Vim to read copying and usage conditions.
// Do ":help credits" in Vim to see a list of people who contributed.
// See README.txt for an overview of the Vim source code.
//
// Copyright 2014 Nikolay Pavlov

// expressions.c: Expression parsing

#include <stdbool.h>
#include <stddef.h>
#include <assert.h>
#include <string.h>

#include "nvim/vim.h"
#include "nvim/memory.h"
#include "nvim/misc2.h"
#include "nvim/types.h"
#include "nvim/charset.h"
#include "nvim/ascii.h"

#include "nvim/viml/parser/expressions.h"

/// Character used as a separator in autoload function/variable names.
#define AUTOLOAD_CHAR '#'

/// maximum number of function arguments
#define MAX_FUNC_ARGS   20

/// Position relative to the start of the expression
#define POS(pos) ((size_t) (pos - eo.start))

#define UP_NODE(type, error, old_top_node, top_node, next_node) \
  do { \
    top_node = expr_alloc(type); \
    next_node = &((*old_top_node)->next); \
    top_node->children = *old_top_node; \
    *old_top_node = top_node; \
  } while (0)

#define TOP_NODE(type, error, old_top_node, top_node, next_node) \
  do { \
    top_node = expr_alloc(type); \
    *old_top_node = top_node; \
    next_node = &(top_node->children); \
  } while (0)

#define VALUE_NODE(type, error, node, pos, end_pos) \
  do { \
    *node = expr_alloc(type); \
    (*node)->start = POS(pos); \
    if (end_pos != NULL) { \
      (*node)->end = POS((char *) end_pos); \
    } \
  } while (0)

#define IS_SCOPE_CHAR(c) ((c) == 'g' || (c) == 'b' || (c) == 'w' \
                          || (c) == 't' || (c) == 'v' || (c) == 'a' \
                          || (c) == 'l' || (c) == 's')

/// Arguments common for parsing functions
#define EDEC_ARGS \
    const ExpressionOptions eo, \
    const char **arg, \
    ExpressionNode **node, \
    ExpressionParserError *error

/// Expands to a parser function definition with given additional arguments
#define EDEC(f, ...) int f(EDEC_ARGS, __VA_ARGS__)
/// Expands to a parser function definition without additional arguments
#define EDEC_NOARGS(f) int f(EDEC_ARGS)
/// Call function with additional first eo argument
#define RAW_CALL(f, ...) f(eo, __VA_ARGS__)
/// Call function with given arguments and propagate FAIL return value
#define CALL(f, ...) \
    do { \
      if (RAW_CALL(f, __VA_ARGS__) == FAIL) { \
        return FAIL; \
      } \
    } while (0)
/// Like CALL, but run err_f with err_args before returning
///
/// @note err_args must look like `(arg1, arg2)`
#define CALL_FAIL_RUN(err_f, err_args, f, ...) \
    do { \
      if (RAW_CALL(f, __VA_ARGS__) == FAIL) { \
        err_f err_args;\
        return FAIL; \
      } \
    } while (0)
/// True if parsing left side of an assignment
#define IS_LVALUE (eo.type == kExprLvalue)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/parser/expressions.c.generated.h"
#endif

#define skipwhite(arg) (char *) skipwhite((char_u *) (arg))
#define skipdigits(arg) (char *) skipdigits((char_u *) (arg))

/// Allocate new expression node and assign its type property
///
/// @param[in]  type   Node type.
///
/// @return Pointer to allocated block of memory.
static ExpressionNode *expr_alloc(ExpressionNodeType type)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT
{
  ExpressionNode *node;

  node = xcalloc(1, sizeof(ExpressionNode));

  node->type = type;

  return node;
}

void free_expr_node(ExpressionNode *node)
{
  if (node == NULL) {
    return;
  }

  free_expr_node(node->children);
  free_expr_node(node->next);
  xfree(node);
}

void free_expr(Expression *expr)
{
  if (expr == NULL) {
    return;
  }

  xfree(expr->string);
  free_expr_node(expr->node);
  xfree(expr);
}

/// Check whether given character is a valid name character
///
/// @param[in]  c  Tested character.
///
/// @return true if character can be used in a variable of function name,
///         false otherwise. Does not include '{' or '}' for magic braces.
static bool isnamechar(int c)
  FUNC_ATTR_CONST
{
  return ASCII_ISALNUM(c) || c == '_' || c == ':' || c == AUTOLOAD_CHAR;
}

/// Find the end of the name of a function or internal variable
///
/// @param[in,out]  arg  Searched argument. It is advanced to the first
///                      non-white character after the name.
///
/// @return Last character of the name if name was found (i.e. *arg - 1). NULL
///         if name was not found
static const char *find_id_end(const char **arg)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const char *p;

  // Find the end of the name.
  for (p = *arg; isnamechar(*p); p++) {
  }
  if (p == *arg) {  // no name found
    return NULL;
  }
  *arg = p;
  return p - 1;
}

/// Get length of s:/<SID>/<SNR> function name prefix
///
/// @param[in]  p  Searched string.
///
/// @return 5 if "p" starts with "<SID>" or "<SNR>" (ignoring case).
///         2 if "p" starts with "s:".
///         0 otherwise.
static int get_fname_script_len(const char *p)
  FUNC_ATTR_CONST
{
  if (p[0] == '<' && (STRNICMP(p + 1, "SID>", 4) == 0
                      || STRNICMP(p + 1, "SNR>", 4) == 0)) {
    return 5;
  }
  if (p[0] == 's' && p[1] == ':') {
    return 2;
  }
  return 0;
}

/// Parse variable/function name
///
/// @param[in,out]  arg          Parsed string. Is advanced to the first
///                              character after the name.
/// @param[out]     node         Location where results are saved.
/// @param[out]     error        Structure where errors are saved.
/// @param[in]      parse1_node  Cached results of parsing first expression in
///                              curly-braces-name ({expr}). Only expected if
///                              '{' is the first symbol (i.e. *arg == '{').
///                              Must be NULL if it is not the first symbol.
/// @param[in]      parse1_arg   Cached end of curly braces expression. Only
///                              expected under the same conditions with
///                              parse1_node.
///
/// @return FAIL if parsing failed, OK otherwise.
static EDEC(parse_name, ExpressionNode *parse1_node, const char *parse1_arg)
  FUNC_ATTR_NONNULL_ARG(2, 3, 4) FUNC_ATTR_WARN_UNUSED_RESULT
{
  int len;
  const char *p;
  const char *s;
  ExpressionNode *top_node = NULL;
  ExpressionNode **next_node = node;

  TOP_NODE(kExprVariableName, error, node, top_node, next_node);

  if (parse1_node == NULL) {
    s = *arg;
    if (   (char_u) (*arg)[0] == K_SPECIAL
        && (char_u) (*arg)[1] == KS_EXTRA
        && (char_u) (*arg)[2] == (int)KE_SNR) {
      // hard coded <SNR>, already translated
      *arg += 3;
      if ((p = find_id_end(arg)) == NULL) {
        // XXX Note: vim does not have special error message for this
        error->message = N_("E15: expected variable name");
        error->position = *arg;
        return FAIL;
      }
      (*node)->type = kExprSimpleVariableName;
      (*node)->start = POS(s);
      (*node)->end = POS(p);
      return OK;
    }

    len = get_fname_script_len(*arg);
    if (len > 0) {
      // literal "<SID>", "s:" or "<SNR>"
      *arg += len;
    }

    p = find_id_end(arg);

    if (p == NULL && len) {
      p = *arg - 1;
    }

    if (**arg != '{') {
      if (p == NULL) {
        // XXX Note: vim does not have special error message for this
        error->message = N_("E15: expected expr7 (value)");
        error->position = *arg;
        return FAIL;
      }
      (*node)->type = kExprSimpleVariableName;
      (*node)->start = POS(s);
      (*node)->end = POS(p);
      return OK;
    }
  } else {
    VALUE_NODE(kExprCurlyName, error, next_node, *arg, NULL);
    (*next_node)->children = parse1_node;
    next_node = &((*next_node)->next);
    *arg = parse1_arg + 1;
    s = *arg;
    p = find_id_end(arg);
  }

  while (**arg == '{') {
    if (p != NULL) {
      VALUE_NODE(kExprIdentifier, error, next_node, s, p);
      next_node = &((*next_node)->next);
    }

    s = *arg;
    (*arg)++;
    *arg = skipwhite(*arg);

    VALUE_NODE(kExprCurlyName, error, next_node, s, NULL);

    CALL(parse1, arg, &((*next_node)->children), error);

    if (**arg != '}') {
      // XXX Note: vim does not have special error message for this
      error->message = N_("E15: missing closing curly brace");
      error->position = *arg;
      return FAIL;
    }
    (*arg)++;
    next_node = &((*next_node)->next);
    s = *arg;
    p = find_id_end(arg);
  }

  if (p != NULL) {
    VALUE_NODE(kExprIdentifier, error, next_node, s, p);
    next_node = &((*next_node)->next);
  }

  return OK;
}

/// Parse list literal
///
/// @param[in,out]  arg    Parsed string. Is advanced to the first character
///                        after the list. Must point to the opening bracket.
/// @param[out]     node   Location where parsing results are saved.
/// @param[out]     error  Structure where errors are saved.
///
/// @return FAIL if parsing failed, OK otherwise.
static EDEC_NOARGS(parse_list)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  ExpressionNode *top_node = NULL;
  ExpressionNode **next_node = node;
  bool mustend = false;

  TOP_NODE(kExprList, error, node, top_node, next_node);

  top_node->start = POS(*arg);

  *arg = skipwhite(*arg + 1);
  while (**arg != ']' && **arg != NUL) {
    CALL(parse1, arg, next_node, error);

    next_node = &((*next_node)->next);

    if (**arg == ']') {
      break;
    }
    if (mustend) {
      return FAIL;
    } else if (IS_LVALUE && **arg == ';') {
      mustend = true;
      TOP_NODE(kExprListRest, error, next_node, top_node, next_node);
      top_node->start = POS(*arg);
    } else if (**arg != ',') {
      error->message = N_("E696: Missing comma in List");
      error->position = *arg;
      return FAIL;
    }
    *arg = skipwhite(*arg + 1);
  }

  if (**arg != ']') {
    error->message = N_("E697: Missing end of List");
    error->position = *arg;
    return FAIL;
  }

  *arg = skipwhite(*arg + 1);

  return OK;
}

/// Parse dictionary literal
///
/// @param[in,out]  arg          Parsed string. Is advanced to the first
///                              character after the dictionary. Must point to
///                              the opening curly brace.
/// @param[out]     node         Location where parsing results are saved.
/// @param[out]     error        Structure where errors are saved.
/// @param[out]     parse1_node  Location where parsing results are saved if
///                              expression proved to be curly braces name
///                              part.
/// @param[out]     parse1_arg   Location where end of curly braces name
///                              expression is saved.
///
/// @return FAIL if parsing failed, NOTDONE if curly braces name found, OK
///         otherwise.
static EDEC(parse_dictionary, ExpressionNode **parse1_node,
            const char **parse1_arg)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  ExpressionNode *top_node = NULL;
  ExpressionNode **next_node = node;
  const char *s = *arg;
  const char *start = skipwhite(*arg + 1);

  *parse1_node = NULL;

  // First check if it's not a curly-braces thing: {expr}.
  // But {} is an empty Dictionary.
  if (*start != '}') {
    *parse1_arg = start;
    CALL_FAIL_RUN(free_expr_node, (*parse1_node),
                  parse1, parse1_arg, parse1_node, error);
    if (**parse1_arg == '}') {
      return NOTDONE;
    }
  }

  top_node = expr_alloc(kExprDictionary);
  next_node = &(top_node->children);
  *node = top_node;

  top_node->start = POS(s);

  *arg = start;
  while (**arg != '}' && **arg != NUL) {
    if (*parse1_node != NULL) {
      *next_node = *parse1_node;
      *parse1_node = NULL;
      *arg = *parse1_arg;
    } else {
      CALL(parse1, arg, next_node, error);
    }

    next_node = &((*next_node)->next);

    if (**arg != ':') {
      error->message = N_("E720: Missing colon in Dictionary");
      error->position = *arg;
      return FAIL;
    }

    *arg = skipwhite(*arg + 1);
    CALL(parse1, arg, next_node, error);

    next_node = &((*next_node)->next);

    if (**arg == '}') {
      break;
    }
    if (**arg != ',') {
      error->message = N_("E722: Missing comma in Dictionary");
      error->position = *arg;
      return FAIL;
    }
    *arg = skipwhite(*arg + 1);
  }

  if (**arg != '}') {
    error->message = N_("E723: Missing end of Dictionary");
    error->position = *arg;
    return FAIL;
  }

  *arg = skipwhite(*arg + 1);

  return OK;
}

/// Skip over the name of an option ("&option", "&g:option", "&l:option")
///
/// @param[in,out]  arg  Start of the option name. It must point to option
///                      sigil (i.e. '&' or '+'). Advanced to the first
///                      character after the option name.
///
/// @return NULL if no option name found, pointer to the last character of the
///         option name otherwise (i.e. *arg - 1).
static const char *find_option_end(const char **arg)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const char *p = *arg;

  p++;
  if (*p == 'g' && p[1] == ':') {
    p += 2;
  } else if (*p == 'l' && p[1] == ':') {
    p += 2;
  }

  if (!ASCII_ISALPHA(*p)) {
    return NULL;
  }

  if (p[0] == 't' && p[1] == '_' && p[2] != NUL && p[3] != NUL) {
    p += 4;
  } else {
    while (ASCII_ISALPHA(*p)) {
      p++;
    }
  }

  *arg = p;

  return p - 1;
}

/// Parse an option literal
///
/// @param[in,out]  arg    Parsed string. It should point to "&" before the
///                        option name. Advanced to the first character after
///                        the option name.
/// @param[out]     node   Location where parsing results are saved.
/// @param[out]     error  Structure where errors are saved.
///
/// @return FAIL if parsing failed, OK otherwise.
static EDEC_NOARGS(parse_option)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const char *option_end;
  const char *s = *arg;

  if ((option_end = find_option_end(arg)) == NULL) {
    error->message = N_("E112: Option name missing");
    error->position = *arg;
    return FAIL;
  }

  VALUE_NODE(kExprOption, error, node, s + 1, option_end);
  return OK;
}

/// Skip over the name of an environment variable
///
/// @param[in,out]  arg  Start of the variable name. Advanced to the first
///                      character after the variable name.
///
/// @return NULL if no variable name found, pointer to the last character of
///         the variable name otherwise (i.e. *arg - 1).
///
/// @note Uses vim_isIDc() function: depends on &isident option.
const char *find_env_end(const char **arg)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const char *p;

  for (p = *arg; vim_isIDc(*p); p++) {
  }
  if (p == *arg) {  // no name found
    return NULL;
  }

  *arg = p;
  return p - 1;
}

/// Parse an environment variable literal
///
/// @param[in,out]  arg    Parsed string. Is expected to point to the sigil
///                        ('$'). Is advanced after the variable name.
/// @parblock
///   @note If there is no variable name after '$' it is simply assumed that
///         this name is empty.
/// @endparblock
/// @param[out]     node   Location where parsing results are saved.
/// @param[out]     error  Structure where errors are saved.
///
/// @return FAIL when out of memory, OK otherwise.
static EDEC_NOARGS(parse_environment_variable)
  FUNC_ATTR_NONNULL_ALL
{
  const char *s = *arg;
  const char *e;

  (*arg)++;
  e = find_env_end(arg);
  if (e == NULL) {
    e = s;
  }

  VALUE_NODE(kExprEnvironmentVariable, error, node, s + 1, e);

  return OK;
}

/// Parse .key subscript
///
/// @param[in,out]  arg    Parsed string. Is advanced to the first non-white
///                        character after the subscript.
/// @param[out]     node   Location where parsing results are saved.
/// @param[out]     error  Structure where errors are saved.
///
/// @return FAIL when out of memory, NOTDONE if subscript was found, OK
///         otherwise.
static EDEC_NOARGS(parse_dot_subscript)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const char *s = *arg;
  const char *e;
  ExpressionNode *top_node = NULL;

  for (e = s + 1; ASCII_ISALNUM(*e) || *e == '_'; e++) {
  }
  if (e == s + 1) {
    return OK;
  }
  // XXX Workaround for concat ambiguity: s.g:var
  if ((e - s) == 2 && *e == ':' && IS_SCOPE_CHAR(s[1])) {
    return OK;
  }
  // XXX Workaround for concat ambiguity: s:autoload#var
  if (*e == AUTOLOAD_CHAR) {
    return OK;
  }
  top_node = expr_alloc(kExprConcatOrSubscript);
  top_node->children = *node;
  top_node->start = POS(s + 1);
  top_node->end = POS(e - 1);
  *node = top_node;
  *arg = skipwhite(e);
  return NOTDONE;
}

/// Parse function call arguments
///
/// @param[in,out]  arg    Parsed string. Is advanced to the first character
///                        after the closing parenthesis of given function
///                        call.
///                        Should point to the opening parenthesis.
/// @param[out]     node   Location where parsing results are saved.
/// @param[out]     error  Structure where errors are saved.
///
/// @return FAIL if parsing failed, OK otherwise.
static EDEC_NOARGS(parse_func_call)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const char *argp;
  int argcount = 0;
  ExpressionNode *top_node = NULL;
  ExpressionNode **next_node = node;

  UP_NODE(kExprCall, error, node, top_node, next_node);

  // Get the arguments.
  argp = *arg;
  while (argcount < MAX_FUNC_ARGS) {
    argp = skipwhite(argp + 1);  // skip the '(' or ','
    if (*argp == ')' || *argp == ',' || *argp == NUL) {
      break;
    }
    CALL(parse1, &argp, next_node, error);
    next_node = &((*next_node)->next);
    argcount++;
    if (*argp != ',') {
      break;
    }
  }

  if (*argp != ')') {
    // XXX Note: vim does not have special error message for this
    error->message = N_("E116: expected closing parenthesis");
    error->position = argp;
    return FAIL;
  }

  argp++;

  *arg = skipwhite(argp);
  return OK;
}

/// Parse "[expr]" or "[expr : expr]" subscript
///
/// @param[in,out]  arg    Parsed string. Is advanced to the first character
///                        after the subscript. Is expected to point to the
///                        opening bracket.
/// @param[out]     node   Location where parsing results are saved.
/// @param[out]     error  Structure where errors are saved.
///
/// @return FAIL if parsing failed, OK otherwise.
static EDEC_NOARGS(parse_subscript)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  ExpressionNode *top_node = NULL;
  ExpressionNode **next_node = node;

  UP_NODE(kExprSubscript, error, node, top_node, next_node);

  // Get the (first) variable from inside the [].
  *arg = skipwhite(*arg + 1);  // skip the '['
  if (**arg == ':') {
    VALUE_NODE(kExprEmptySubscript, error, next_node, *arg, NULL);
  } else {
    CALL(parse1, arg, next_node, error);
  }
  next_node = &((*next_node)->next);

  // Get the second variable from inside the [:].
  if (**arg == ':') {
    *arg = skipwhite(*arg + 1);
    if (**arg == ']') {
      VALUE_NODE(kExprEmptySubscript, error, next_node, *arg, NULL);
    } else {
      CALL(parse1, arg, next_node, error);
    }
  }

  // Check for the ']'.
  if (**arg != ']') {
    error->message = N_("E111: Missing ']'");
    error->position = *arg;
    return FAIL;
  }
  *arg = skipwhite(*arg + 1);  // skip the ']'

  return OK;
}

/// Parse all following "[...]" subscripts, .key subscripts and function calls
///
/// @param[in,out]  arg    Parsed string. Is advanced to the first character
///                        after the last subscript.
/// @param[out]     node   Location where parsing results are saved.
/// @param[out]     error  Structure where errors are saved.
///
/// @return FAIL if parsing failed, OK otherwise.
static EDEC(handle_subscript, bool parse_funccall)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  while ((**arg == '[' || **arg == '.'
          || (parse_funccall && **arg == '('))
         && !ascii_iswhite(*(*arg - 1))) {
    switch (**arg) {
      case '.': {
        int ret;
        if ((*node)->type == kExprDecimalNumber
            || (*node)->type == kExprOctalNumber
            || (*node)->type == kExprHexNumber
            || (*node)->type == kExprSingleQuotedString
            || (*node)->type == kExprDoubleQuotedString) {
          return OK;
        }
        ret = RAW_CALL(parse_dot_subscript, arg, node, error);
        if (ret == FAIL) {
          return FAIL;
        }
        if (ret != NOTDONE) {
          return OK;
        }
        break;
      }
      case '(': {
        CALL(parse_func_call, arg, node, error);
        break;
      }
      case '[': {
        CALL(parse_subscript, arg, node, error);
        break;
      }
    }
  }
  return OK;
}

/// Find end of VimL number (100, 0xA0, 0775, possibly with minus sign)
///
/// @param[in,out]  arg    Parsed string.
/// @param[out]     type   Type of the resulting number.
/// @param[in]      dooct  If true allow function to recognize octal numbers.
/// @param[in]      dohex  If true allow function to recognize hexadecimal
///                        numbers.
static void find_nr_end(const char **arg, ExpressionNodeType *type,
                        bool dooct, bool dohex)
{
  const char *ptr = *arg;
  int n;

  *type = kExprDecimalNumber;

  if (ptr[0] == '-') {
    ptr++;
  }

  // Recognize hex and octal.
  if (ptr[0] == '0' && ptr[1] != '8' && ptr[1] != '9') {
    if (dohex && (ptr[1] == 'x' || ptr[1] == 'X') && ascii_isxdigit(ptr[2])) {
      *type = kExprHexNumber;
      ptr += 2;  // hexadecimal
    } else {
      *type = kExprDecimalNumber;
      if (dooct) {
        // Don't interpret "0", "08" or "0129" as octal.
        for (n = 1; ascii_isdigit(ptr[n]); n++) {
          if (ptr[n] > '7') {
            *type = kExprDecimalNumber;  // can't be octal
            break;
          }
          if (ptr[n] >= '0') {
            *type = kExprOctalNumber;  // assume octal
          }
        }
      }
    }
  }
  switch (*type) {
    case kExprDecimalNumber: {
      while (ascii_isdigit(*ptr)) {
        ptr++;
      }
      break;
    }
    case kExprOctalNumber: {
      while ('0' <= *ptr && *ptr <= '7') {
        ptr++;
      }
      break;
    }
    case kExprHexNumber: {
      while (ascii_isxdigit(*ptr)) {
        ptr++;
      }
      break;
    }
    default: {
      assert(false);
    }
  }

  *arg = ptr;
}

/// Parse seventh level expression: values
///
/// Parsed values:
///
/// Value                | Description
/// -------------------- | -----------------------
/// number               | number constant
/// "string"             | string constant
/// 'string'             | literal string constant
/// &option-name         | option value
/// @r                   | register contents
/// identifier           | variable value
/// function()           | function call
/// $VAR                 | environment variable
/// (expression)         | nested expression
/// [expr, expr]         | List
/// {key: val, key: val} | Dictionary
///
/// Also handles unary operators (logical NOT, unary minus, unary plus) and
/// subscripts ([], .key, func()).
///
/// @param[in,out]  arg             Parsed string. Must point to the first
///                                 non-white character. Advanced to the next
///                                 non-white after the recognized expression.
/// @param[out]     node            Location where parsing results are saved.
/// @param[out]     error           Structure where errors are saved.
/// @param[in]      want_string     True if the result should be string. Is
///                                 used to preserve compatibility with vim:
///                                 "a".1.2 is a string "a12" (uses string
///                                 concat), not floating-point value. This
///                                 flag is set in parse5 that handles
///                                 concats.
/// @param[in]      parse_funccall  Determines whether function calls should
///                                 be parsed. I.e. if this is true then
///                                 "abc(def)" will be parsed as "call(abc,
///                                 def)", if this is false it will parse this
///                                 as "abc" and stop at opening parenthesis.
///
/// @return FAIL if parsing failed, OK otherwise.
static EDEC(parse7, bool want_string, bool parse_funccall)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  ExpressionNodeType type = kExprUnknown;
  ExpressionNode *parse1_node = NULL;
  const char *parse1_arg;
  const char *s;
  const char *e;
  const char *start_leader;
  const char *end_leader;
  int ret = OK;

  // Skip '!' and '-' characters.  They are handled later.
  start_leader = *arg;
  while (**arg == '!' || **arg == '-' || **arg == '+') {
    *arg = skipwhite(*arg + 1);
  }
  end_leader = *arg;

  switch (**arg) {
    // Number constant.
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9': {
      const char *p;

      s = *arg;
      p = skipdigits(*arg + 1);
      e = p - 1;
      type = kExprDecimalNumber;

      // We accept a float when the format matches
      // "[0-9]\+\.[0-9]\+\([eE][+-]\?[0-9]\+\)\?".  This is very
      // strict to avoid backwards compatibility problems.
      // Don't look for a float after the "." operator, so that
      // ":let vers = 1.2.3" doesn't fail.
      if (!want_string && p[0] == '.' && ascii_isdigit(p[1])) {
        type = kExprFloat;
        p = skipdigits(p + 2);
        if (*p == 'e' || *p == 'E') {
          p++;
          if (*p == '-' || *p == '+') {
            p++;
          }
          if (!ascii_isdigit(*p)) {
            type = kExprDecimalNumber;
          } else {
            p = skipdigits(p + 1);
          }
        }
        if (ASCII_ISALPHA(*p) || *p == '.') {
          type = kExprDecimalNumber;
        }
        if (type != kExprDecimalNumber) {
          e = p - 1;
        }
      }
      if (type == kExprFloat) {
        *arg = e + 1;
      } else {
        find_nr_end(arg, &type, true, true);
        e = *arg - 1;
      }
      VALUE_NODE(type, error, node, s, e);
      break;
    }

    // String constant
    case '"':
    case '\'': {
      const char *p;

      s = *arg;
      p = s + 1;

      if (*s == '"') {
        while (*p != '"' && *p != NUL) {
          if (*p == '\\' && p[1] != NUL) {
            p += 2;
          } else {
            p++;
          }
        }
      } else {
        for (;;) {
          if (*p == '\'') {
            if (p[1] == '\'') {
              p += 2;
            } else {
              break;
            }
          } else if (*p) {
            p++;
          } else {
            break;
          }
        }
      }
      if (*p == NUL) {
        // TODO(ZyX-I): also report which quote is missing
        error->message = N_("E114: Missing quote");
        error->position = s;
        return FAIL;
      }
      p++;

      if (*s == '"') {
        type = kExprDoubleQuotedString;
      } else {
        type = kExprSingleQuotedString;
      }

      VALUE_NODE(type, error, node, s, p - 1);
      *arg = p;
      break;
    }

    // List: [expr, expr]
    case '[': {
      ret = RAW_CALL(parse_list, arg, node, error);
      break;
    }

    // Dictionary: {key: val, key: val}
    case '{': {
      ret = RAW_CALL(parse_dictionary, arg, node, error, &parse1_node,
                     &parse1_arg);
      break;
    }

    // Option value: &name
    case '&': {
      ret = RAW_CALL(parse_option, arg, node, error);
      break;
    }

    // Environment variable: $VAR.
    case '$': {
      ret = RAW_CALL(parse_environment_variable, arg, node, error);
      break;
    }

    // Register contents: @r.
    case '@': {
      s = *arg;
      (*arg)++;
      if (**arg != NUL) {
        (*arg)++;
      }
      // XXX Sigil is included: `:echo @` does the same as `:echo @"`
      // But Vim does not bother itself checking whether next character is
      // a valid register name so you cannot just use `@` in place of `@"`
      // everywhere: only at the end of string.
      VALUE_NODE(kExprRegister, error, node, s, *arg - 1);
      break;
    }

    // nested expression: (expression).
    case '(': {
      VALUE_NODE(kExprExpression, error, node, *arg, NULL);
      *arg = skipwhite(*arg + 1);
      ret = RAW_CALL(parse1, arg, &((*node)->children), error);
      if (**arg == ')') {
        (*arg)++;
      } else if (ret == OK) {
        error->message = N_("E110: Missing ')'");
        error->position = *arg;
        ret = FAIL;
      }
      break;
    }

    default: {
      ret = NOTDONE;
      break;
    }
  }

  if (ret == NOTDONE) {
    // Must be a variable or function name.
    // Can also be a curly-braces kind of name: {expr}.
    ret = RAW_CALL(parse_name, arg, node, error, parse1_node, parse1_arg);

    *arg = skipwhite(*arg);

    if (**arg == '(' && parse_funccall) {
      // Function call. First function call is not handled by handle_subscript
      // for whatever reasons. Allows expressions like "tr   (1, 2, 3)"
      ret = RAW_CALL(parse_func_call, arg, node, error);
    }
  }

  *arg = skipwhite(*arg);

  // Handle following '[', '(' and '.' for expr[expr], expr.name,
  // expr(expr).
  if (ret == OK) {
    ret = RAW_CALL(handle_subscript, arg, node, error, parse_funccall);
  }

  // Apply logical NOT and unary '-', from right to left, ignore '+'.
  if (ret == OK && end_leader > start_leader) {
    while (end_leader > start_leader) {
      ExpressionNode *top_node = NULL;
      --end_leader;
      switch (*end_leader) {
        case '!': {
          type = kExprNot;
          break;
        }
        case '-': {
          type = kExprMinus;
          break;
        }
        case '+': {
          type = kExprPlus;
          break;
        }
      }
      top_node = expr_alloc(type);
      top_node->children = *node;
      *node = top_node;
    }
  }

  return ret;
}

/// Handle sixths level expression: multiplication/division/modulo
///
/// Operators supported:
///
/// Operator | Operation
/// -------- | ---------------------
///   "*"    | Number multiplication
///   "/"    | Number division
///   "%"    | Number modulo
///
/// @param[in,out]  arg    Parsed string. Must point to the first non-white
///                        character. Advanced to the next non-white after the
///                        recognized expression.
/// @param[out]     node   Location where parsing results are saved.
/// @param[out]     error  Structure where errors are saved.
///
/// @return FAIL if parsing failed, OK otherwise.
static EDEC(parse6, bool want_string)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  ExpressionNodeType type = kExprUnknown;
  ExpressionNode *top_node = NULL;
  ExpressionNode **next_node = node;

  // Get the first variable.
  CALL(parse7, arg, node, error, want_string, true);

  // Repeat computing, until no '*', '/' or '%' is following.
  for (;;) {
    switch (**arg) {
      case '*': {
        type = kExprMultiply;
        break;
      }
      case '/': {
        type = kExprDivide;
        break;
      }
      case '%': {
        type = kExprModulo;
        break;
      }
      default: {
        type = kExprUnknown;
        break;
      }
    }
    if (type == kExprUnknown) {
      break;
    }

    if (top_node == NULL || top_node->type != type) {
      UP_NODE(type, error, node, top_node, next_node);
    } else {
      next_node = &((*next_node)->next);
    }

    // Get the second variable.
    *arg = skipwhite(*arg + 1);
    CALL(parse7, arg, next_node, error, want_string, true);
  }
  return OK;
}

/// Handle fifth level expression: addition/subtraction/concatenation
///
/// Operators supported:
///
/// Operator | Operation
/// -------- | --------------------
///   "+"    | List/number addition
///   "/"    | Number subtraction
///   "%"    | String concatenation
///
/// @param[in,out]  arg    Parsed string. Must point to the first non-white
///                        character. Advanced to the next non-white after the
///                        recognized expression.
/// @param[out]     node   Location where parsing results are saved.
/// @param[out]     error  Structure where errors are saved.
///
/// @return FAIL if parsing failed, OK otherwise.
static EDEC_NOARGS(parse5)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  ExpressionNodeType type = kExprUnknown;
  ExpressionNode *top_node = NULL;
  ExpressionNode **next_node = node;

  // Get the first variable.
  CALL(parse6, arg, node, error, false);

  // Repeat computing, until no '+', '-' or '.' is following.
  for (;;) {
    switch (**arg) {
      case '+': {
        type = kExprAdd;
        break;
      }
      case '-': {
        type = kExprSubtract;
        break;
      }
      case '.': {
        type = kExprStringConcat;
        break;
      }
      default: {
        type = kExprUnknown;
        break;
      }
    }
    if (type == kExprUnknown) {
      break;
    }

    if (top_node == NULL || top_node->type != type) {
      UP_NODE(type, error, node, top_node, next_node);
    } else {
      next_node = &((*next_node)->next);
    }

    // Get the second variable.
    *arg = skipwhite(*arg + 1);
    CALL(parse6, arg, next_node, error, type == kExprStringConcat);
  }
  return OK;
}

/// Handle fourth level expression: boolean relations
///
/// Relation types:
///
/// Operator | Relation
/// -------- | ---------------------
///   "=="   | Equals
///   "=~"   | Matches pattern
///   "!="   | Not equals
///   "!~"   | Not matches pattern
///   ">"    | Is greater than
///   ">="   | Is greater than or equal to
///   "<"    | Is less than
///   "<="   | Is less than or equal to
///   "is"   | Is identical to
///  "isnot" | Is not identical to
///
/// Accepts "#" or "?" after each operator to designate case compare strategy
/// (by default it is taken from &ignore case option, trailing "#" means that
/// case is respected, trailing "?" means that it is ignored).
///
/// @param[in,out]  arg    Parsed string. Must point to the first non-white
///                        character. Advanced to the next non-white after the
///                        recognized expression.
/// @param[out]     node   Location where parsing results are saved.
/// @param[out]     error  Structure where errors are saved.
///
/// @return FAIL if parsing failed, OK otherwise.
static EDEC_NOARGS(parse4)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const char *p;
  ExpressionNodeType type = kExprUnknown;
  size_t len = 2;

  // Get the first variable.
  CALL(parse5, arg, node, error);

  p = *arg;
  switch (p[0]) {
    case '=': {
      if (p[1] == '=') {
        type = kExprEquals;
      } else if (p[1] == '~') {
        type = kExprMatches;
      }
      break;
    }
    case '!': {
      if (p[1] == '=') {
        type = kExprNotEquals;
      } else if (p[1] == '~') {
        type = kExprNotMatches;
      }
      break;
    }
    case '>': {
      if (p[1] != '=') {
        type = kExprGreater;
        len = 1;
      } else {
        type = kExprGreaterThanOrEqualTo;
      }
      break;
    }
    case '<': {
      if (p[1] != '=') {
        type = kExprLess;
        len = 1;
      } else {
        type = kExprLessThanOrEqualTo;
      }
      break;
    }
    case 'i': {
      if (p[1] == 's') {
        if (p[2] == 'n' && p[3] == 'o' && p[4] == 't') {
          len = 5;
        }
        if (!vim_isIDc(p[len])) {
          type = len == 2 ? kExprIdentical : kExprNotIdentical;
        }
      }
      break;
    }
  }

  // If there is a comparative operator, use it.
  if (type != kExprUnknown) {
    ExpressionNode *top_node = NULL;
    ExpressionNode **next_node = node;

    UP_NODE(type, error, node, top_node, next_node);

    // extra question mark appended: ignore case
    if (p[len] == '?') {
      top_node->ignore_case = kCCStrategyIgnoreCase;
      len++;
    // extra '#' appended: match case
    } else if (p[len] == '#') {
      top_node->ignore_case = kCCStrategyMatchCase;
      len++;
    }
    // nothing appended: use kCCStrategyUseOption (default)

    // Get the second variable.
    *arg = skipwhite(p + len);
    CALL(parse5, arg, next_node, error);
  }

  return OK;
}

/// Handle second and third level expression: logical operations
///
/// Operators used:
///
/// Operator | Operation
/// -------- | ----------------------
///   "&&"   | Logical AND (level==3)
///   "||"   | Logical OR  (level==2)
///
/// @param[in,out]  arg    Parsed string. Must point to the first non-white
///                        character. Advanced to the next non-white after the
///                        recognized expression.
/// @param[out]     node   Location where parsing results are saved.
/// @param[out]     error  Structure where errors are saved.
/// @param[in]      level  Expression level: determines which logical operator
///                        should be handled.
///
/// @return FAIL if parsing failed, OK otherwise.
static EDEC(parse23, uint8_t level)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  ExpressionNode *top_node = NULL;
  ExpressionNode **next_node = node;
  ExpressionNodeType type;
  char c;
  EDEC_NOARGS((*parse_next));

  if (level == 2) {
    type = kExprLogicalOr;
    parse_next = &parse3;
    c = '|';
  } else {
    type = kExprLogicalAnd;
    parse_next = &parse4;
    c = '&';
  }

  // Get the first variable.
  CALL(parse_next, arg, node, error);

  // Repeat until there is no following "&&".
  while ((*arg)[0] == c && (*arg)[1] == c) {
    if (top_node == NULL) {
      UP_NODE(type, error, node, top_node, next_node);
    }

    // Get the second variable.
    *arg = skipwhite(*arg + 2);
    CALL(parse_next, arg, next_node, error);
    next_node = &((*next_node)->next);
  }

  return OK;
}

/// Handle third level expression: logical AND
///
/// @param[in,out]  arg    Parsed string. Must point to the first non-white
///                        character. Advanced to the next non-white after the
///                        recognized expression.
/// @param[out]     node   Location where parsing results are saved.
/// @param[out]     error  Structure where errors are saved.
///
/// @return FAIL if parsing failed, OK otherwise.
static EDEC_NOARGS(parse3)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  return RAW_CALL(parse23, arg, node, error, 3);
}

/// Handle second level expression: logical OR
///
/// @param[in,out]  arg    Parsed string. Must point to the first non-white
///                        character. Advanced to the next non-white after the
///                        recognized expression.
/// @param[out]     node   Location where parsing results are saved.
/// @param[out]     error  Structure where errors are saved.
///
/// @return FAIL if parsing failed, OK otherwise.
static EDEC_NOARGS(parse2)
{
  return RAW_CALL(parse23, arg, node, error, 2);
}

/// Handle first (top) level expression: ternary conditional operator
///
/// Handles expr2 ? expr1 : expr1
///
/// @param[in,out]  arg    Parsed string. Must point to the first non-white
///                        character. Advanced to the next non-white after the
///                        recognized expression.
/// @param[out]     node   Location where parsing results are saved.
/// @param[out]     error  Structure where errors are saved.
///
/// @return FAIL if parsing failed, OK otherwise.
static EDEC_NOARGS(parse1)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  // Get the first variable.
  CALL(parse2, arg, node, error);

  if ((*arg)[0] == '?') {
    ExpressionNode *top_node;
    ExpressionNode **next_node = node;

    UP_NODE(kExprTernaryConditional, error, node, top_node, next_node);

    // Get the second variable.
    *arg = skipwhite(*arg + 1);
    CALL(parse1, arg, next_node, error);

    // Check for the ":".
    if (**arg != ':') {
      error->message = N_("E109: Missing ':' after '?'");
      error->position = *arg;
      return FAIL;
    }

    next_node = &((*next_node)->next);

    // Get the third variable.
    *arg = skipwhite(*arg + 1);
    CALL(parse1, arg, next_node, error);
  }

  return OK;
}

/// Parse expression
///
/// @param[in]      s      Start of the parsed string.
/// @param[in,out]  arg    Parsed string. May point to whitespace character.
///                        Is advanced to the next non-white after the
///                        recognized expression.
/// @param[out]     error  Structure where errors are saved.
///
/// @return NULL if parsing failed or memory was exhausted, pointer to the
///         allocated expression node otherwise.
ExpressionNode *parse0_err(const char *const s, const char **arg,
                           ExpressionParserError *error)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  ExpressionNode *result = NULL;
  ExpressionOptions eo = {
    kExprRvalue,
    s
  };

  error->message = NULL;
  error->position = NULL;

  *arg = skipwhite(*arg);
  if (RAW_CALL(parse1, arg, &result, error) == FAIL) {
    free_expr_node(result);
    return NULL;
  }

  return result;
}

/// Parse value (actually used for lvals)
///
/// @param[in]      s      Start of the parsed string.
/// @param[in,out]  arg    Parsed string. May point to whitespace character.
///                        Is advanced to the next non-white after the
///                        recognized expression.
/// @param[out]     error  Structure where errors are saved.
///
/// @return NULL if parsing failed or memory was exhausted, pointer to the
///         allocated expression node otherwise.
ExpressionNode *parse7_nofunc(const char *const s, const char **arg,
                              ExpressionParserError *error)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  ExpressionNode *result = NULL;
  ExpressionOptions eo = {
    kExprLvalue,
    s
  };

  error->message = NULL;
  error->position = NULL;

  *arg = skipwhite(*arg);
  if (RAW_CALL(parse7, arg, &result, error, false, false) == FAIL) {
    free_expr_node(result);
    return NULL;
  }

  return result;
}

/// Parse one expression and wrap result in Expression structure
///
/// @param[in,out]  arg    Parsed expression. May point to whitespace character.
///                        Is advanced to the next non-white after the
///                        recognized expression.
/// @param[out]     error  Structure where errors are saved.
/// @param[in]      parse  Parser used to parse one expression in sequence.
/// @param[in]      col    Position of the start of the parsed string in the
///                        parsed line.
///
/// @return NULL if parsing failed or memory was exhausted, pointer to the
///         allocated expression node otherwise.
Expression *parse_one_expression(const char **arg, ExpressionParserError *error,
                                 ExpressionParser parse, const size_t col)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  Expression *result = xcalloc(1, sizeof(Expression));
  const char *const s = *arg;

  if ((result->node = parse(s, arg, error)) == NULL) {
    free_expr(result);
    return NULL;
  }

  result->size = (size_t) (*arg - s);
  result->string = xmemdup(s, result->size);
  result->col = col;

  return result;
}

/// Parse a whitespace-separated sequence of expressions
///
/// @param[in,out]  arg       Parsed string. May point to whitespace character.
///                           Is advanced to the next non-white after the
///                           recognized expression.
/// @param[out]     error     Structure where errors are saved.
/// @param[in]      parse     Parser used to parse one expression in sequence.
/// @param[in]      col       Position of the start of the parsed string in the
///                           parsed line.
/// @param[in]      listends  Determines whether list literal should end
///                           parsing process.
/// @param[in]      endwith   Determines what characters are allowed to stop
///                           parsing. NUL byte always stops parsing.
///
/// @return NULL if parsing failed or memory was exhausted, pointer to the
///         allocated expression node otherwise.
Expression *parse_many_expressions(const char **arg,
                                   ExpressionParserError *error,
                                   ExpressionParser parse, const size_t col,
                                   const bool listends, const char *endwith)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  Expression *result = xcalloc(1, sizeof(Expression));
  ExpressionNode **next = &(result->node);
  const char *const s = *arg;

  error->message = NULL;
  error->position = NULL;

  while (**arg && strchr(endwith, **arg) == NULL) {
    *arg = skipwhite(*arg);
    if ((*next = parse(s, arg, error)) == NULL) {
      free_expr(result);
      return NULL;
    }
    if (listends && (*next)->type == kExprList) {
      break;
    }
    next = &((*next)->next);
  }

  result->size = (size_t) (*arg - s);
  result->string = xmemdup(s, result->size);
  result->col = col;

  return result;
}
