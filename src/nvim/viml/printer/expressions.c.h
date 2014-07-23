#ifndef NVIM_VIML_PRINTER_EXPRESSIONS_C_H

#include <stdbool.h>
#include <stddef.h>
#include <assert.h>

#include "nvim/memory.h"
#include "nvim/ascii.h"

#include "nvim/viml/printer/expressions.h"
#include "nvim/viml/parser/expressions.h"
#include "nvim/viml/printer/printer.h"
#include "nvim/viml/dumpers/dumpers.h"

#if !defined(CH_MACROS_DEFINE_LENGTH) && !defined(CH_MACROS_DEFINE_FWRITE)
# define CH_MACROS_DEFINE_LENGTH
# include "nvim/viml/printer/expressions.c.h"
# undef CH_MACROS_DEFINE_LENGTH
#elif !defined(CH_MACROS_DEFINE_FWRITE)
# undef CH_MACROS_DEFINE_LENGTH
# define CH_MACROS_DEFINE_FWRITE
# include "nvim/viml/printer/expressions.c.h"  // NOLINT
# undef CH_MACROS_DEFINE_FWRITE
# define CH_MACROS_DEFINE_LENGTH
#endif
#define NVIM_VIML_PRINTER_EXPRESSIONS_C_H

#ifndef NVIM_VIML_DUMPERS_CH_MACROS
# define CH_MACROS_OPTIONS_TYPE const ExprPrinterOptions *const
# define CH_MACROS_INDENT_STR ""
# define WE(node) W_EXPR_POS(o->string, node)
# define _OPERATOR_SPACES(po_e_o, op) \
    (LOGICAL_START <= op && op <= LOGICAL_END \
     ? po_e_o.logical[op - LOGICAL_START] \
     : (COMPARISON_START <= op && op <= COMPARISON_END \
        ? po_e_o.comparison[op - COMPARISON_START] \
        : (ARITHMETIC_START <= op && op <= ARITHMETIC_END \
           ? po_e_o.arithmetic[op - ARITHMETIC_START] \
           : (op == kExprStringConcat \
              ? po_e_o.string.concat \
              : (UNARY_START <= op && op <= UNARY_END \
                 ? po_e_o.unary[op - UNARY_START] \
                 : (assert(false), _error_spaces))))))
# define OPERATOR_SPACES(op) \
     _OPERATOR_SPACES(o->style.operators, op)
#endif
#include "nvim/viml/dumpers/ch_macros.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/printer/expressions.c.h.generated.h"
#endif

static FDEC(print_node, const char *const s, const ExpressionNode *const node)
{
  FUNCTION_START;
  bool add_ccs = false;

  switch (node->type) {
    case kExprGreater:
    case kExprGreaterThanOrEqualTo:
    case kExprLess:
    case kExprLessThanOrEqualTo:
    case kExprEquals:
    case kExprNotEquals:
    case kExprIdentical:
    case kExprNotIdentical:
    case kExprMatches:
    case kExprNotMatches: {
      assert(node->children->next->next == NULL);

      add_ccs = true;
      // fallthrough
    }
    case kExprLogicalOr:
    case kExprLogicalAnd:
    case kExprAdd:
    case kExprSubtract:
    case kExprMultiply:
    case kExprDivide:
    case kExprModulo:
    case kExprStringConcat: {
      ExpressionNode *child = node->children;
      char *operator;

      assert(node->children != NULL);
      assert(node->children->next != NULL);

      if (node->type == kExprStringConcat) {
        operator = ".";
      } else {
        operator = expression_type_string[node->type];
      }

      child = node->children;
      do {
        F(print_node, s, child);
        child = child->next;
        if (child != NULL) {
          SPACES(OPERATOR_SPACES(node->type).before);
          W(operator);
          if (add_ccs) {
            if (node->ignore_case) {
              W_LEN(case_compare_strategy_string[node->ignore_case], 1);
            }
          }
          SPACES(OPERATOR_SPACES(node->type).after);
        }
      } while (child != NULL);

      break;
    }
    case kExprTernaryConditional: {
      assert(node->children != NULL);
      assert(node->children->next != NULL);
      assert(node->children->next->next != NULL);
      assert(node->children->next->next->next == NULL);

      F(print_node, s, node->children);
      SPACES_BEFORE4(style, operators, ternary, condition);
      WC('?');
      SPACES_AFTER4(style, operators, ternary, condition);
      F(print_node, s, node->children->next);
      SPACES_BEFORE4(style, operators, ternary, values);
      WC(':');
      SPACES_AFTER4(style, operators, ternary, values);
      F(print_node, s, node->children->next->next);
      break;
    }
    case kExprNot:
    case kExprMinus:
    case kExprPlus: {
      assert(node->children != NULL);
      assert(node->children->next == NULL);
      SPACES(OPERATOR_SPACES(node->type).before);
      W_LEN(expression_type_string[node->type], 1);
      SPACES(OPERATOR_SPACES(node->type).after);
      F(print_node, s, node->children);
      break;
    }
    case kExprEnvironmentVariable:
    case kExprOption: {
      WC((node->type == kExprEnvironmentVariable ? '$' : '&'));
      // fallthrough
    }
    case kExprDecimalNumber:
    case kExprOctalNumber:
    case kExprHexNumber:
    case kExprFloat:
    case kExprDoubleQuotedString:
    case kExprSingleQuotedString:
    case kExprRegister:
    case kExprSimpleVariableName:
    case kExprIdentifier: {
      assert(node->children == NULL);

      WE(node);
      break;
    }
    case kExprVariableName: {
      ExpressionNode *child = node->children;

      assert(child != NULL);

      do {
        F(print_node, s, child);
        child = child->next;
      } while (child != NULL);
      break;
    }
    case kExprCurlyName:
    case kExprExpression: {
      assert(node->children != NULL);
      assert(node->children->next == NULL);

      WC((node->type == kExprExpression ? '(' : '{'));
      if (node->type == kExprCurlyName) {
        SPACES_AFTER_START2(style, curly_name);
      } else {
        SPACES_AFTER_START3(style, function_call, call);
      }
      F(print_node, s, node->children);
      if (node->type == kExprCurlyName) {
        SPACES_BEFORE_END2(style, curly_name);
      } else {
        SPACES_BEFORE_END3(style, function_call, call);
      }
      WC((node->type == kExprExpression ? ')' : '}'));
      break;
    }
    case kExprList: {
      ExpressionNode *child = node->children;

      WC('[');
      SPACES_AFTER_START3(style, list, braces);
      while (child != NULL) {
        F(print_node, s, child);
        child = child->next;
        if (child != NULL || ADD_TRAILING_COMMA2(style, list)) {
          SPACES_BEFORE3(style, list, item);
          if (child != NULL && child->type == kExprListRest) {
            assert(child->children != NULL);
            assert(child->next == NULL);
            assert(child->children->next == NULL);
            child = child->children;
            WC(';');
          } else {
            WC(',');
          }
          SPACES_AFTER3(style, list, item);
        }
      }
      SPACES_BEFORE_END3(style, list, braces);
      WC(']');
      break;
    }
    case kExprDictionary: {
      ExpressionNode *child = node->children;
      WC('{');
      SPACES_AFTER_START3(style, dictionary, curly_braces);
      while (child != NULL) {
        F(print_node, s, child);
        child = child->next;
        assert(child != NULL);
        SPACES_BEFORE3(style, dictionary, key);
        WC(':');
        SPACES_AFTER3(style, dictionary, key);
        F(print_node, s, child);
        child = child->next;
        if (child != NULL || ADD_TRAILING_COMMA2(style, dictionary)) {
          SPACES_BEFORE3(style, dictionary, item);
          WC(',');
          SPACES_AFTER3(style, dictionary, item);
        }
      }
      SPACES_BEFORE_END3(style, dictionary, curly_braces);
      WC('}');
      break;
    }
    case kExprSubscript: {
      assert(node->children != NULL);
      assert(node->children->next != NULL);

      F(print_node, s, node->children);
      WC('[');
      SPACES_AFTER_START3(style, subscript, brackets);
      F(print_node, s, node->children->next);
      if (node->children->next->next != NULL) {
        assert(node->children->next->next->next == NULL);
        SPACES_BEFORE3(style, subscript, slice);
        WC(':');
        SPACES_AFTER3(style, subscript, slice);
        F(print_node, s, node->children->next->next);
      }
      SPACES_BEFORE_END3(style, subscript, brackets);
      WC(']');
      break;
    }
    case kExprConcatOrSubscript: {
      assert(node->children != NULL);
      assert(node->children->next == NULL);

      F(print_node, s, node->children);
      WC('.');
      WE(node);
      break;
    }
    case kExprCall: {
      ExpressionNode *child;

      assert(node->children != NULL);

      F(print_node, s, node->children);
      WC('(');
      child = node->children->next;
      while (child != NULL) {
        F(print_node, s, child);
        child = child->next;
        if (child != NULL) {
          WC(',');
          WC(' ');
        }
      }
      WC(')');
      break;
    }
    case kExprEmptySubscript: {
      break;
    }
    default: {
      assert(false);
    }
  }

  FUNCTION_END;
}

static FDEC(represent_node, const char *const s,
            const ExpressionNode *const node)
{
  FUNCTION_START;

  W(expression_type_string[node->type]);
  W(case_compare_strategy_string[node->ignore_case]);

  bool add_start;
  bool add_end;
  switch (node->type) {
    case kExprLogicalOr:
    case kExprLogicalAnd:
    case kExprGreater:
    case kExprGreaterThanOrEqualTo:
    case kExprLess:
    case kExprLessThanOrEqualTo:
    case kExprEquals:
    case kExprNotEquals:
    case kExprIdentical:
    case kExprNotIdentical:
    case kExprMatches:
    case kExprNotMatches:
    case kExprAdd:
    case kExprSubtract:
    case kExprMultiply:
    case kExprDivide:
    case kExprModulo:
    case kExprStringConcat:
    case kExprNot:
    case kExprMinus:
    case kExprPlus:
    case kExprVariableName:
    case kExprSubscript:
    case kExprCall: {
      add_start = false;
      add_end = false;
      break;
    }
    case kExprCurlyName:
    case kExprList:
    case kExprDictionary:
    case kExprExpression:
    case kExprEmptySubscript: {
      add_start = true;
      add_end = false;
      break;
    }
    default: {
      add_start = true;
      add_end = true;
      break;
    }
  }

  if (add_start) {
    WC('[');
    if (add_end) {
      size_t node_len = node->end - node->start + 1;

      WC('+');

      W_LEN(s + node->start, node_len);

      WC('+');
    } else {
      WC('!');
      W_LEN(s + node->start, 1);
      WC('!');
    }
    WC(']');
  }

  if (node->children != NULL) {
    WC('(');
    F(represent_node, s, node->children);
    WC(')');
  }

  if (node->next != NULL) {
    WS(", ");
    F(represent_node, s, node->next);
  }

  FUNCTION_END;
}

#undef CH_MACROS_OPTIONS_TYPE

#endif  // NVIM_VIML_PRINTER_EXPRESSIONS_C_H
