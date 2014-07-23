#ifndef NVIM_VIML_PARSER_EXPRESSIONS_H
#define NVIM_VIML_PARSER_EXPRESSIONS_H

#include "nvim/types.h"

typedef enum {
  kExprUnknown = 0,

  // Ternary operators
  kExprTernaryConditional,    // ? :

  // Binary operators
#define LOGICAL_START kExprLogicalOr
  kExprLogicalOr,             // ||
  kExprLogicalAnd,            // &&
#define LOGICAL_END kExprLogicalAnd
#define COMPARISON_START kExprGreater
  kExprGreater,               // >
  kExprGreaterThanOrEqualTo,  // >=
  kExprLess,                  // <
  kExprLessThanOrEqualTo,     // <=
  kExprEquals,                // ==
  kExprNotEquals,             // !=
  kExprIdentical,             // is
  kExprNotIdentical,          // isnot
  kExprMatches,               // =~
  kExprNotMatches,            // !~
#define COMPARISON_END kExprNotMatches
#define ARITHMETIC_START kExprAdd
  kExprAdd,                   // +
  kExprSubtract,              // -
  kExprMultiply,              // *
  kExprDivide,                // /
  kExprModulo,                // %
#define ARITHMETIC_END kExprModulo
  kExprStringConcat,          // .
  // 19

  // Unary operators
#define UNARY_START kExprNot
  kExprNot,                   // !
  kExprMinus,                 // -
  kExprPlus,                  // +
#define UNARY_END kExprPlus
  // 22

  // Simple value nodes
  kExprDecimalNumber,         // 0
  kExprOctalNumber,           // 0123
  kExprHexNumber,             // 0x1C
  kExprFloat,                 // 0.0, 0.0e0
  kExprDoubleQuotedString,    // "abc"
  kExprSingleQuotedString,    // 'abc'
  kExprOption,                // &option
  kExprRegister,              // @r
  kExprEnvironmentVariable,   // $VAR
  // 31

  // Curly braces names parts
  kExprVariableName,          // Top-level part
  kExprSimpleVariableName,    // Variable name without curly braces
  kExprIdentifier,            // plain string part
  kExprCurlyName,             // curly brace name
  // 35

  // Complex value nodes
  kExprExpression,            // (expr)
  kExprList,                  // [expr, ]
  kExprDictionary,            // {expr : expr, }
  // 38

  // Subscripts
  kExprSubscript,             // expr[expr:expr]
  kExprConcatOrSubscript,     // expr.name
  kExprCall,                  // expr(expr, )

  kExprEmptySubscript,        // empty lhs or rhs in [lhs:rhs]

  kExprListRest,              // Node after ";" in lval lists
} ExpressionNodeType;

#define LOGICAL_LENGTH (LOGICAL_END - LOGICAL_START + 1)
#define COMPARISON_LENGTH (COMPARISON_END - COMPARISON_START + 1)
#define ARITHMETIC_LENGTH (ARITHMETIC_END - ARITHMETIC_START + 1)
#define UNARY_LENGTH (UNARY_END - UNARY_START + 1)

// Defines whether to ignore case:
//    ==   kCCStrategyUseOption
//    ==#  kCCStrategyMatchCase
//    ==?  kCCStrategyIgnoreCase
typedef enum {
  kCCStrategyUseOption = 0,  // 0 for xcalloc
  kCCStrategyMatchCase,
  kCCStrategyIgnoreCase,
} CaseCompareStrategy;

/// Structure to represent VimL expressions
typedef struct expression_node {
  ExpressionNodeType type;  ///< Node type.
  size_t start;             ///< Position of expression token start inside
                            ///< a parsed string.
  size_t end;               ///< Position of last character of expression
                            ///< token.
  CaseCompareStrategy ignore_case;   ///< Determines whether case should be
                                     ///< ignored while comparing. Only valid
                                     ///< for comparison operators:
                                     ///< kExpr(Greater|Less)*,
                                     ///< kExpr[Not]Matches, kExpr[Not]Equals.
  struct expression_node *children;  ///< Subexpressions: valid for operators,
                                     ///< subscripts (including kExprCall),
                                     ///< complex variable names.
  struct expression_node *next;  ///< Next node: expression nodes are arranged
                                 ///< as a linked list.
} ExpressionNode;

/// Structure that represents the whole parsed expression
typedef struct {
  ExpressionNode *node;  ///< Top-level node.
  char *string;          ///< Expression string saved for debugging.
  size_t size;           ///< Above string length.
  size_t col;            ///< Position of the first character in parsed string.
} Expression;

typedef struct error {
  const char *message;
  const char *position;
} ExpressionParserError;

/// Defines scope in which expressions are parsed
typedef enum {
  kExprRvalue = 0,  ///< Rvalue: value that can be accessed.
  kExprLvalue,      ///< Lvalue: left side of an assignment.
} ExpressionType;

typedef struct {
  ExpressionType type;
  const char *start;
} ExpressionOptions;

typedef ExpressionNode *(*ExpressionParser)(const char *const, const char **,
                                            ExpressionParserError *);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/parser/expressions.h.generated.h"
#endif
#endif  // NVIM_VIML_PARSER_EXPRESSIONS_H
