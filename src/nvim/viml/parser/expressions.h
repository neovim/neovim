#ifndef NVIM_VIML_PARSER_EXPRESSIONS_H
#define NVIM_VIML_PARSER_EXPRESSIONS_H

#include <stddef.h>
#include <stdbool.h>

#include "nvim/types.h"
#include "nvim/viml/parser/parser.h"

// Defines whether to ignore case:
//    ==   kCCStrategyUseOption
//    ==#  kCCStrategyMatchCase
//    ==?  kCCStrategyIgnoreCase
typedef enum {
  kCCStrategyUseOption = 0,  // 0 for xcalloc
  kCCStrategyMatchCase = '#',
  kCCStrategyIgnoreCase = '?',
} CaseCompareStrategy;

/// Lexer token type
typedef enum {
  kExprLexInvalid = 0,  ///< Invalid token, indicaten an error.
  kExprLexMissing,  ///< Missing token, for use in parser.
  kExprLexSpacing,  ///< Spaces, tabs, newlines, etc.
  kExprLexEOC,  ///< End of command character: NL, |, just end of stream.

  kExprLexQuestion,  ///< Question mark, for use in ternary.
  kExprLexColon,  ///< Colon, for use in ternary.
  kExprLexOr,  ///< Logical or operator.
  kExprLexAnd,  ///< Logical and operator.
  kExprLexComparison,  ///< One of the comparison operators.
  kExprLexPlus,  ///< Plus sign.
  kExprLexMinus,  ///< Minus sign.
  kExprLexDot,  ///< Dot: either concat or subscript, also part of the float.
  kExprLexMultiplication,  ///< Multiplication, division or modulo operator.

  kExprLexNot,  ///< Not: !.

  kExprLexNumber,  ///< Integer number literal, or part of a float.
  kExprLexSingleQuotedString,  ///< Single quoted string literal.
  kExprLexDoubleQuotedString,  ///< Double quoted string literal.
  kExprLexOption,  ///< &optionname option value.
  kExprLexRegister,  ///< @r register value.
  kExprLexEnv,  ///< Environment $variable value.
  kExprLexPlainIdentifier,  ///< Identifier without scope: `abc`, `foo#bar`.

  kExprLexBracket,  ///< Bracket, either opening or closing.
  kExprLexFigureBrace,  ///< Figure brace, either opening or closing.
  kExprLexParenthesis,  ///< Parenthesis, either opening or closing.
  kExprLexComma,  ///< Comma.
  kExprLexArrow,  ///< Arrow, like from lambda expressions.
} LexExprTokenType;

/// Lexer token
typedef struct {
  ParserPosition start;
  size_t len;
  LexExprTokenType type;
  union {
    struct {
      enum {
        kExprLexCmpEqual,  ///< Equality, unequality.
        kExprLexCmpMatches,  ///< Matches regex, not matches regex.
        kExprLexCmpGreater,  ///< `>` or `<=`
        kExprLexCmpGreaterOrEqual,  ///< `>=` or `<`.
        kExprLexCmpIdentical,  ///< `is` or `isnot`
      } type;  ///< Comparison type.
      CaseCompareStrategy ccs;  ///< Case comparison strategy.
      bool inv;  ///< True if comparison is to be inverted.
    } cmp;  ///< For kExprLexComparison.

    struct {
      enum {
        kExprLexMulMul,  ///< Real multiplication.
        kExprLexMulDiv,  ///< Division.
        kExprLexMulMod,  ///< Modulo.
      } type;  ///< Multiplication type.
    } mul;  ///< For kExprLexMultiplication.

    struct {
      bool closing;  ///< True if bracket/etc is a closing one.
    } brc;  ///< For brackets/braces/parenthesis.

    struct {
      int name;  ///< Register name, may be -1 if name not present.
    } reg;  ///< For kExprLexRegister.

    struct {
      bool closed;  ///< True if quote was closed.
    } str;  ///< For kExprLexSingleQuotedString and kExprLexDoubleQuotedString.

    struct {
      const char *name;  ///< Option name start.
      size_t len;  ///< Option name length.
      enum {
        kExprLexOptUnspecified = 0,
        kExprLexOptGlobal = 1,
        kExprLexOptLocal = 2,
      } scope;  ///< Option scope: &l:, &g: or not specified.
    } opt;  ///< Option properties.

    struct {
      int scope;  ///< Scope character or 0 if not present.
      bool autoload;  ///< Has autoload characters.
    } var;  ///< For kExprLexPlainIdentifier

    struct {
      LexExprTokenType type;  ///< Suggested type for parsing incorrect code.
      const char *msg;  ///< Error message.
    } err;  ///< For kExprLexInvalid
  } data;  ///< Additional data, if needed.
} LexExprToken;

/// Expression AST node type
typedef enum {
  kExprNodeMissing = 'X',
  kExprNodeOpMissing = '_',
  kExprNodeTernary = '?',  ///< Ternary operator, valid one has three children.
  kExprNodeRegister = '@',  ///< Register, no children.
  kExprNodeSubscript = 's',  ///< Subscript, should have two or three children.
  kExprNodeListLiteral = 'l',  ///< List literal, any number of children.
  kExprNodeUnaryPlus = 'p',
  kExprNodeBinaryPlus = '+',
  kExprNodeNested = 'e',  ///< Nested parenthesised expression.
  kExprNodeCall = 'c',  ///< Function call.
  /// Plain identifier: simple variable/function name
  ///
  /// Looks like "string", "g:Foo", etc: consists from a single 
  /// kExprLexPlainIdentifier token.
  kExprNodePlainIdentifier = 'i',
  /// Complex identifier: variable/function name with curly braces
  kExprNodeComplexIdentifier = 'I',
} ExprASTNodeType;

typedef struct expr_ast_node ExprASTNode;

/// Structure representing one AST node
struct expr_ast_node {
  ExprASTNodeType type;  ///< Node type.
  /// Node children: e.g. for 1 + 2 nodes 1 and 2 will be children of +.
  ExprASTNode *children;
  /// Next node: e.g. for 1 + 2 child nodes 1 and 2 are put into a single-linked
  /// list: `(+)->children` references only node 1, node 2 is in
  /// `(+)->children->next`.
  ExprASTNode *next;
  ParserPosition start;
  size_t len;
  union {
    struct {
      int name;  ///< Register name, may be -1 if name not present.
    } reg;  ///< For kExprNodeRegister.
  } data;
};

enum {
  /// Allow multiple expressions in a row: e.g. for :echo
  ///
  /// Parser will still parse only one of them though.
  kExprFlagsMulti = (1 << 0),
  /// Allow NL, NUL and bar to be EOC
  ///
  /// When parsing expressions input by user bar is assumed to be a binary
  /// operator and other two are spacings.
  kExprFlagsDisallowEOC = (1 << 1),
  /// Print errors when encountered
  ///
  /// Without the flag they are only taken into account when parsing.
  kExprFlagsPrintError = (1 << 2),
} ExprParserFlags;

/// Structure representing complety AST for one expression
typedef struct {
  /// True if represented AST is correct and can be executed. Incorrect ones may
  /// still be used for completion, or in linters.
  bool correct;
  /// When AST is not correct this message will be printed.
  ///
  /// Uses `emsgf(msg, arg_len, arg);`, `msg` is assumed to contain only `%.*s`.
  struct {
    const char *msg;
    int arg_len;
    const char *arg;
  } err;
  /// Root node of the AST.
  ExprASTNode *root;
} ExprAST;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/parser/expressions.h.generated.h"
#endif

#endif  // NVIM_VIML_PARSER_EXPRESSIONS_H
