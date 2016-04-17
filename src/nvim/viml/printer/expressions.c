#include <stdbool.h>
#include <stddef.h>

#include "nvim/vim.h"
#include "nvim/memory.h"
#include "nvim/viml/parser/expressions.h"
#include "nvim/viml/printer/printer.h"
#include "nvim/viml/dumpers/dumpers.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/printer/expressions.c.generated.h"
#endif

#define OP_SPACES { 1, 1 }
#define LOGICAL_OP_SPACES OP_SPACES
#define COMPARISON_OP_SPACES OP_SPACES
#define IS_SPACES OP_SPACES
#define ARITHMETIC_OP_SPACES OP_SPACES
#define STRING_OP_SPACES ARITHMETIC_OP_SPACES
#define UNARY_OP_SPACES { 0, 0 }
#define TERNARY_OP_SPACES OP_SPACES
#define COMPLEX_LITERAL_SPACES { 0, 0 }
#define VALUE_SEPARATOR_SPACES { 0, 1 }
#define LIST_LITERAL_SPACES COMPLEX_LITERAL_SPACES
#define LIST_VALUE_SPACES VALUE_SEPARATOR_SPACES
#define DICT_LITERAL_SPACES COMPLEX_LITERAL_SPACES
#define DICT_VALUE_SPACES VALUE_SEPARATOR_SPACES
#define DICT_KEY_SPACES VALUE_SEPARATOR_SPACES
#define VARIABLE_SPACES { 0, 0 }
#define CURLY_NAME_SPACES VARIABLE_SPACES
#define FUNCTION_CALL_SPACES { 0, 0 }
#define ARGUMENT_SPACES VALUE_SEPARATOR_SPACES
#define INDENT "  "
#define LET_SPACES { 1, 1 }
#define SLICE_SPACES { 1, 1 }
#define INDEX_SPACES VARIABLE_SPACES
#define TRAILING_COMMA false
#define LIST_TRAILING_COMMA TRAILING_COMMA
#define DICT_TRAILING_COMMA TRAILING_COMMA
#define FUNCTION_CMD_CALL_SPACES FUNCTION_CALL_SPACES
#define CMD_ARGUMENT_SPACES ARGUMENT_SPACES
#define ATTRIBUTE_SPACES 1
#define FUNCTION_SUB_SPACES 0
#define FUNCTION_CMD_SUB_SPACES FUNCTION_SUB_SPACES
#define COMMENT_INLINE_SPACES 2
#define COMMENT_SPACES 0

const StyleOptions default_po = {
  {
    {
      {
        LOGICAL_OP_SPACES,
        LOGICAL_OP_SPACES
      },
      {
        COMPARISON_OP_SPACES,
        COMPARISON_OP_SPACES,
        COMPARISON_OP_SPACES,
        COMPARISON_OP_SPACES,
        COMPARISON_OP_SPACES,
        COMPARISON_OP_SPACES,
        IS_SPACES,
        IS_SPACES,
        COMPARISON_OP_SPACES,
        COMPARISON_OP_SPACES
      },
      {
        ARITHMETIC_OP_SPACES,
        ARITHMETIC_OP_SPACES,
        ARITHMETIC_OP_SPACES,
        ARITHMETIC_OP_SPACES,
        ARITHMETIC_OP_SPACES
      },
      {
        STRING_OP_SPACES
      },
      {
        UNARY_OP_SPACES,
        UNARY_OP_SPACES,
        UNARY_OP_SPACES
      },
      {
        TERNARY_OP_SPACES,
        TERNARY_OP_SPACES
      }
    },
    {
      LIST_LITERAL_SPACES,
      LIST_VALUE_SPACES,
      LIST_TRAILING_COMMA
    },
    {
      DICT_LITERAL_SPACES,
      DICT_KEY_SPACES,
      DICT_VALUE_SPACES,
      DICT_TRAILING_COMMA
    },
    CURLY_NAME_SPACES,
    {
      SLICE_SPACES,
      INDEX_SPACES
    },
    {
      FUNCTION_SUB_SPACES,
      FUNCTION_CALL_SPACES,
      ARGUMENT_SPACES
    }
  },
  {
    INDENT,
    {
      LET_SPACES,
      LET_SPACES,
      LET_SPACES,
      LET_SPACES
    },
    {
      FUNCTION_CMD_SUB_SPACES,
      FUNCTION_CMD_CALL_SPACES,
      CMD_ARGUMENT_SPACES,
      ATTRIBUTE_SPACES
    },
    {
      COMMENT_INLINE_SPACES,
      COMMENT_SPACES
    },
    {
      false
    },
    {
      false
    },
    {
      false
    },
    {
      " "
    },
    {
      " :"
    },
    {
      false,
      " "
    },
    {
      false,
    },
    {
      " :"
    },
  },
  true,
  {
    "\n",
    1,
  },
};

static char *expression_type_string[] = {
  "Unknown",
  "?:",
  "||",
  "&&",
  ">",
  ">=",
  "<",
  "<=",
  "==",
  "!=",
  "is",
  "isnot",
  "=~",
  "!~",
  "+",
  "-",
  "*",
  "/",
  "%",
  "..",
  "!",
  "-!",
  "+!",
  "N",
  "O",
  "X",
  "F",
  "\"",
  "'",
  "&",
  "@",
  "$",
  "cvar",
  "var",
  "id",
  "curly",
  "expr",
  "[]",
  "{}",
  "index",
  ".",
  "call",
  "empty",
  ";",
};

static char *case_compare_strategy_string[] = {
  "",
  "#",
  "?",
};

#include "nvim/viml/printer/expressions.c.h"

size_t sprint_expr_len(const StyleOptions *const po,
                       const Expression *const expr)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_CONST
{
  ExprPrinterOptions epo = { po->expression, expr->string };
  size_t len = sprint_node_len(&epo, expr->string, expr->node);
  ExpressionNode *next = expr->node->next;

  while (next != NULL) {
    len++;
    len += sprint_node_len(&epo, expr->string, next);
    next = next->next;
  }

  return len;
}

void sprint_expr(const StyleOptions *const po, const Expression *const expr,
                 char **pp)
  FUNC_ATTR_NONNULL_ALL
{
  ExpressionNode *next = expr->node->next;
  ExprPrinterOptions epo = { po->expression, expr->string };

  sprint_node(&epo, expr->string, expr->node, pp);

  while (next != NULL) {
    *(*pp)++ = ' ';
    sprint_node(&epo, expr->string, next, pp);
    next = next->next;
  }
}

int print_expr(const StyleOptions *const po, const Expression *const expr,
               Writer write, void *cookie)
{
  ExpressionNode *next = expr->node->next;
  ExprPrinterOptions epo = { po->expression, expr->string };

  if (print_node(&epo, expr->string, expr->node, write, cookie) == FAIL) {
    return FAIL;
  }

  while (next != NULL) {
    if (write(" ", 1, 1, cookie) != 1) {
      return FAIL;
    }
    if (print_node(&epo, expr->string, next, write, cookie) == FAIL) {
      return FAIL;
    }
    next = next->next;
  }
  return OK;
}

size_t srepresent_expr_len(const StyleOptions *const po,
                           const Expression *const expr)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_CONST
{
  ExprPrinterOptions epo = { po->expression, expr->string };
  return srepresent_node_len(&epo, expr->string, expr->node);
}

void srepresent_expr(const StyleOptions *const po, const Expression *const expr,
                     char **pp)
  FUNC_ATTR_NONNULL_ALL
{
  ExprPrinterOptions epo = { po->expression, expr->string };
  srepresent_node(&epo, expr->string, expr->node, pp);
}

int represent_expr(const StyleOptions *const po, const Expression *const expr,
                   Writer write, void *cookie)
{
  ExprPrinterOptions epo = { po->expression, expr->string };
  return represent_node(&epo, expr->string, expr->node, write, cookie);
}
