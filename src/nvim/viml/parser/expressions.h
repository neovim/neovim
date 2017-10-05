#ifndef NVIM_VIML_PARSER_EXPRESSIONS_H
#define NVIM_VIML_PARSER_EXPRESSIONS_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#include "nvim/types.h"
#include "nvim/viml/parser/parser.h"
#include "nvim/eval/typval.h"

// Defines whether to ignore case:
//    ==   kCCStrategyUseOption
//    ==#  kCCStrategyMatchCase
//    ==?  kCCStrategyIgnoreCase
typedef enum {
  kCCStrategyUseOption = 0,  // 0 for xcalloc
  kCCStrategyMatchCase = '#',
  kCCStrategyIgnoreCase = '?',
} ExprCaseCompareStrategy;

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

typedef enum {
  kExprCmpEqual,  ///< Equality, unequality.
  kExprCmpMatches,  ///< Matches regex, not matches regex.
  kExprCmpGreater,  ///< `>` or `<=`
  kExprCmpGreaterOrEqual,  ///< `>=` or `<`.
  kExprCmpIdentical,  ///< `is` or `isnot`
} ExprComparisonType;

/// Lexer token
typedef struct {
  ParserPosition start;
  size_t len;
  LexExprTokenType type;
  union {
    struct {
      ExprComparisonType type;  ///< Comparison type.
      ExprCaseCompareStrategy ccs;  ///< Case comparison strategy.
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

    struct {
      union {
        float_T floating;
        uvarnumber_T integer;
      } val;  ///< Number value.
      uint8_t base;  ///< Base: 2, 8, 10 or 16.
      bool is_float;  ///< True if number is a floating-point.
    } num;  ///< For kExprLexNumber
  } data;  ///< Additional data, if needed.
} LexExprToken;

typedef enum {
  /// If set, “pointer” to the current byte in pstate will not be shifted
  kELFlagPeek = (1 << 0),
  /// Determines whether scope is allowed to come before the identifier
  kELFlagForbidScope = (1 << 1),
  /// Determines whether floating-point numbers are allowed
  ///
  /// I.e. whether dot is a decimal point separator or is not a part of
  /// a number at all.
  kELFlagAllowFloat = (1 << 2),
  /// Determines whether `is` and `isnot` are seen as comparison operators
  ///
  /// If set they are supposed to be just regular identifiers.
  kELFlagIsNotCmp = (1 << 3),
  /// Determines whether EOC tokens are allowed
  ///
  /// If set then it will yield Invalid token with E15 in place of EOC one if
  /// “EOC” is something like "|". It is fine with emitting EOC at the end of
  /// string still, with or without this flag set.
  kELFlagForbidEOC = (1 << 4),
  // WARNING: whenever you add a new flag, alter klee_assume() statement in
  // viml_expressions_lexer.c.
} LexExprFlags;

/// Expression AST node type
typedef enum {
  kExprNodeMissing = 'X',
  kExprNodeOpMissing = '_',
  kExprNodeTernary = '?',  ///< Ternary operator.
  kExprNodeTernaryValue = 'C',  ///< Ternary operator, colon.
  kExprNodeRegister = '@',  ///< Register.
  kExprNodeSubscript = 's',  ///< Subscript.
  kExprNodeListLiteral = 'l',  ///< List literal.
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
  /// Figure brace expression which is not yet known
  ///
  /// May resolve to any of kExprNodeDictLiteral, kExprNodeLambda or
  /// kExprNodeCurlyBracesIdentifier.
  kExprNodeUnknownFigure = '{',
  kExprNodeLambda = '\\',  ///< Lambda.
  kExprNodeDictLiteral = 'd',  ///< Dictionary literal.
  kExprNodeCurlyBracesIdentifier= '}',  ///< Part of the curly braces name.
  kExprNodeComma = ',',  ///< Comma “operator”.
  kExprNodeColon = ':',  ///< Colon “operator”.
  kExprNodeArrow = '>',  ///< Arrow “operator”.
  kExprNodeComparison = '=',  ///< Various comparison operators.
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
    struct {
      /// Which nodes UnknownFigure can’t possibly represent.
      struct {
        /// True if UnknownFigure may actually represent dictionary literal.
        bool allow_dict;
        /// True if UnknownFigure may actually represent lambda.
        bool allow_lambda;
        /// True if UnknownFigure may actually be part of curly braces name.
        bool allow_ident;
      } type_guesses;
      /// Highlight chunk index, used for rehighlighting if needed
      size_t opening_hl_idx;
    } fig;  ///< For kExprNodeUnknownFigure.
    struct {
      int scope;  ///< Scope character or 0 if not present.
      /// Actual identifier without scope.
      ///
      /// Points to inside parser reader state.
      const char *ident;
      size_t ident_len;  ///< Actual identifier length.
    } var;  ///< For kExprNodePlainIdentifier.
    struct {
      bool got_colon;  ///< True if colon was seen.
    } ter;  ///< For kExprNodeTernaryValue.
    struct {
      ExprComparisonType type;  ///< Comparison type.
      ExprCaseCompareStrategy ccs;  ///< Case comparison strategy.
      bool inv;  ///< True if comparison is to be inverted.
    } cmp;  ///< For kExprNodeComparison.
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
  // WARNING: whenever you add a new flag, alter klee_assume() statement in
  // viml_expressions_parser.c.
} ExprParserFlags;

/// AST error definition
typedef struct {
  /// Error message. Must contain a single printf format atom: %.*s.
  const char *msg;
  /// Error message argument: points to the location of the error.
  const char *arg;
  /// Message argument length: length till the end of string.
  int arg_len;
} ExprASTError;

/// Structure representing complety AST for one expression
typedef struct {
  /// When AST is not correct this message will be printed.
  ///
  /// Uses `emsgf(msg, arg_len, arg);`, `msg` is assumed to contain only `%.*s`.
  ExprASTError err;
  /// Root node of the AST.
  ExprASTNode *root;
} ExprAST;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/parser/expressions.h.generated.h"
#endif

#endif  // NVIM_VIML_PARSER_EXPRESSIONS_H
