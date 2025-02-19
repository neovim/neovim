#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nvim/eval/typval_defs.h"
#include "nvim/types_defs.h"
#include "nvim/viml/parser/parser_defs.h"

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
  kExprLexAssignment,  ///< Assignment: `=` or `{op}=`.
  // XXX When modifying this enum you need to also modify eltkn_type_tab in
  //     expressions.c and tests and, possibly, viml_pexpr_repr_token.
} LexExprTokenType;

typedef enum {
  kExprCmpEqual,  ///< Equality, inequality.
  kExprCmpMatches,  ///< Matches regex, not matches regex.
  kExprCmpGreater,  ///< `>` or `<=`
  kExprCmpGreaterOrEqual,  ///< `>=` or `<`.
  kExprCmpIdentical,  ///< `is` or `isnot`
} ExprComparisonType;

/// All possible option scopes
typedef enum {
  kExprOptScopeUnspecified = 0,
  kExprOptScopeGlobal = 'g',
  kExprOptScopeLocal = 'l',
} ExprOptScope;

/// All possible assignment types: `=` and `{op}=`.
typedef enum {
  kExprAsgnPlain = 0,  ///< Plain assignment: `=`.
  kExprAsgnAdd,  ///< Assignment augmented with addition: `+=`.
  kExprAsgnSubtract,  ///< Assignment augmented with subtraction: `-=`.
  kExprAsgnConcat,  ///< Assignment augmented with concatenation: `.=`.
} ExprAssignmentType;

#define EXPR_OPT_SCOPE_LIST \
  ((char[]){ kExprOptScopeGlobal, kExprOptScopeLocal })

/// All possible variable scopes
typedef enum {
  kExprVarScopeMissing = 0,
  kExprVarScopeScript = 's',
  kExprVarScopeGlobal = 'g',
  kExprVarScopeVim = 'v',
  kExprVarScopeBuffer = 'b',
  kExprVarScopeWindow = 'w',
  kExprVarScopeTabpage = 't',
  kExprVarScopeLocal = 'l',
  kExprVarScopeArguments = 'a',
} ExprVarScope;

#define EXPR_VAR_SCOPE_LIST \
  ((char[]) { \
    kExprVarScopeScript, kExprVarScopeGlobal, kExprVarScopeVim, \
    kExprVarScopeBuffer, kExprVarScopeWindow, kExprVarScopeTabpage, \
    kExprVarScopeLocal, kExprVarScopeBuffer, kExprVarScopeArguments, \
  })

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
      ExprOptScope scope;  ///< Option scope: &l:, &g: or not specified.
    } opt;  ///< Option properties.

    struct {
      ExprVarScope scope;  ///< Scope character or 0 if not present.
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

    struct {
      ExprAssignmentType type;
    } ass;  ///< For kExprLexAssignment
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
  // XXX Whenever you add a new flag, alter klee_assume() statement in
  //     viml_expressions_lexer.c.
} LexExprFlags;

/// Expression AST node type
typedef enum {
  kExprNodeMissing = 0,
  kExprNodeOpMissing,
  kExprNodeTernary,  ///< Ternary operator.
  kExprNodeTernaryValue,  ///< Ternary operator, colon.
  kExprNodeRegister,  ///< Register.
  kExprNodeSubscript,  ///< Subscript.
  kExprNodeListLiteral,  ///< List literal.
  kExprNodeUnaryPlus,
  kExprNodeBinaryPlus,
  kExprNodeNested,  ///< Nested parenthesised expression.
  kExprNodeCall,  ///< Function call.
  /// Plain identifier: simple variable/function name
  ///
  /// Looks like "string", "g:Foo", etc: consists from a single
  /// kExprLexPlainIdentifier token.
  kExprNodePlainIdentifier,
  /// Plain dictionary key, for use with kExprNodeConcatOrSubscript
  kExprNodePlainKey,
  /// Complex identifier: variable/function name with curly braces
  kExprNodeComplexIdentifier,
  /// Figure brace expression which is not yet known
  ///
  /// May resolve to any of kExprNodeDictLiteral, kExprNodeLambda or
  /// kExprNodeCurlyBracesIdentifier.
  kExprNodeUnknownFigure,
  kExprNodeLambda,  ///< Lambda.
  kExprNodeDictLiteral,  ///< Dict literal.
  kExprNodeCurlyBracesIdentifier,  ///< Part of the curly braces name.
  kExprNodeComma,  ///< Comma “operator”.
  kExprNodeColon,  ///< Colon “operator”.
  kExprNodeArrow,  ///< Arrow “operator”.
  kExprNodeComparison,  ///< Various comparison operators.
  /// Concat operator
  ///
  /// To be only used in cases when it is known for sure it is not a subscript.
  kExprNodeConcat,
  /// Concat or subscript operator
  ///
  /// For cases when it is not obvious whether expression is a concat or
  /// a subscript. May only have either number or plain identifier as the second
  /// child. To make it easier to avoid curly braces in place of
  /// kExprNodePlainIdentifier node kExprNodePlainKey is used.
  kExprNodeConcatOrSubscript,
  kExprNodeInteger,  ///< Integral number.
  kExprNodeFloat,  ///< Floating-point number.
  kExprNodeSingleQuotedString,
  kExprNodeDoubleQuotedString,
  kExprNodeOr,
  kExprNodeAnd,
  kExprNodeUnaryMinus,
  kExprNodeBinaryMinus,
  kExprNodeNot,
  kExprNodeMultiplication,
  kExprNodeDivision,
  kExprNodeMod,
  kExprNodeOption,
  kExprNodeEnvironment,
  kExprNodeAssignment,
  // XXX When modifying this list also modify east_node_type_tab both in parser
  //     and in tests, and you most likely will also have to alter list of
  //     highlight groups stored in highlight_init_cmdline variable.
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
      ExprVarScope scope;  ///< Scope character or 0 if not present.
      /// Actual identifier without scope.
      ///
      /// Points to inside parser reader state.
      const char *ident;
      size_t ident_len;  ///< Actual identifier length.
    } var;  ///< For kExprNodePlainIdentifier and kExprNodePlainKey.
    struct {
      bool got_colon;  ///< True if colon was seen.
    } ter;  ///< For kExprNodeTernaryValue.
    struct {
      ExprComparisonType type;  ///< Comparison type.
      ExprCaseCompareStrategy ccs;  ///< Case comparison strategy.
      bool inv;  ///< True if comparison is to be inverted.
    } cmp;  ///< For kExprNodeComparison.
    struct {
      uvarnumber_T value;
    } num;  ///< For kExprNodeInteger.
    struct {
      float_T value;
    } flt;  ///< For kExprNodeFloat.
    struct {
      char *value;
      size_t size;
    } str;  ///< For kExprNodeSingleQuotedString and
            ///< kExprNodeDoubleQuotedString.
    struct {
      const char *ident;  ///< Option name start.
      size_t ident_len;  ///< Option name length.
      ExprOptScope scope;  ///< Option scope: &l:, &g: or not specified.
    } opt;  ///< For kExprNodeOption.
    struct {
      const char *ident;  ///< Environment variable name start.
      size_t ident_len;  ///< Environment variable name length.
    } env;  ///< For kExprNodeEnvironment.
    struct {
      ExprAssignmentType type;
    } ass;  ///< For kExprNodeAssignment
  } data;
};

enum ExprParserFlags {
  /// Allow multiple expressions in a row: e.g. for :echo
  ///
  /// Parser will still parse only one of them though.
  kExprFlagsMulti = (1 << 0),
  /// Allow NL, NUL and bar to be EOC
  ///
  /// When parsing expressions input by user bar is assumed to be a binary
  /// operator and other two are spacings.
  kExprFlagsDisallowEOC = (1 << 1),
  /// Parse :let argument
  ///
  /// That mean that top level node must be an assignment and first nodes
  /// belong to lvalues.
  kExprFlagsParseLet = (1 << 2),
  // XXX whenever you add a new flag, alter klee_assume() statement in
  //     viml_expressions_parser.c, nvim_parse_expression() flags parsing
  //     alongside with its documentation and flag sets in check_parsing()
  //     function in expressions parser functional and unit tests.
};

/// AST error definition
typedef struct {
  /// Error message. Must contain a single printf format atom: %.*s.
  const char *msg;
  /// Error message argument: points to the location of the error.
  const char *arg;
  /// Message argument length: length till the end of string.
  int arg_len;
} ExprASTError;

/// Structure representing complete AST for one expression
typedef struct {
  /// When AST is not correct this message will be printed.
  ///
  /// Uses `semsg(msg, arg_len, arg);`, `msg` is assumed to contain only `%.*s`.
  ExprASTError err;
  /// Root node of the AST.
  ExprASTNode *root;
} ExprAST;

/// Array mapping ExprASTNodeType to maximum amount of children node may have
extern const uint8_t node_maxchildren[];

/// Array mapping ExprASTNodeType values to their stringified versions
extern const char *const east_node_type_tab[];

/// Array mapping ExprComparisonType values to their stringified versions
extern const char *const eltkn_cmp_type_tab[];

/// Array mapping ExprCaseCompareStrategy values to their stringified versions
extern const char *const ccs_tab[];

/// Array mapping ExprAssignmentType values to their stringified versions
extern const char *const expr_asgn_type_tab[];

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/parser/expressions.h.generated.h"
#endif
