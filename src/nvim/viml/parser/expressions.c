// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/// VimL expression parser

#include <stdbool.h>
#include <stddef.h>
#include <assert.h>
#include <string.h>

#include "nvim/vim.h"
#include "nvim/memory.h"
#include "nvim/types.h"
#include "nvim/charset.h"
#include "nvim/ascii.h"
#include "nvim/lib/kvec.h"

#include "nvim/viml/parser/expressions.h"
#include "nvim/viml/parser/parser.h"

typedef kvec_withinit_t(ExprASTNode **, 16) ExprASTStack;

typedef enum {
  kELvlOperator,  ///< Operators: function call, subscripts, binary operators, …
  kELvlValue,  ///< Actual value: literals, variables, nested expressions.
} ExprASTLevel;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/parser/expressions.c.generated.h"
#endif

/// Character used as a separator in autoload function/variable names.
#define AUTOLOAD_CHAR '#'

/// Get next token for the VimL expression input
///
/// @param  pstate  Parser state.
/// @param[in]  peek  If true, do not advance pstate cursor.
///
/// @return Next token.
LexExprToken viml_pexpr_next_token(ParserState *const pstate, const bool peek)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  LexExprToken ret = {
    .type = kExprLexInvalid,
    .start = pstate->pos,
  };
  ParserLine pline;
  if (!viml_parser_get_remaining_line(pstate, &pline)) {
    ret.type = kExprLexEOC;
    return ret;
  }
  if (pline.size <= 0) {
    ret.len = 0;
    ret.type = kExprLexEOC;
    goto viml_pexpr_next_token_adv_return;
  }
  ret.len = 1;
  const uint8_t schar = (uint8_t)pline.data[0];
#define GET_CCS(ret, pline) \
  do { \
    if (ret.len < pline.size \
        && strchr("?#", pline.data[ret.len]) != NULL) { \
      ret.data.cmp.ccs = \
          (CaseCompareStrategy)pline.data[ret.len]; \
      ret.len++; \
    } else { \
      ret.data.cmp.ccs = kCCStrategyUseOption; \
    } \
  } while (0)
  switch (schar) {
    // Paired brackets.
#define BRACKET(typ, opning, clsing) \
    case opning: \
    case clsing: { \
      ret.type = typ; \
      ret.data.brc.closing = (schar == clsing); \
      break; \
    }
    BRACKET(kExprLexParenthesis, '(', ')')
    BRACKET(kExprLexBracket, '[', ']')
    BRACKET(kExprLexFigureBrace, '{', '}')
#undef BRACKET

    // Single character tokens without data.
#define CHAR(typ, ch) \
    case ch: { \
      ret.type = typ; \
      break; \
    }
    CHAR(kExprLexQuestion, '?')
    CHAR(kExprLexColon, ':')
    CHAR(kExprLexDot, '.')
    CHAR(kExprLexPlus, '+')
    CHAR(kExprLexComma, ',')
#undef CHAR

    // Multiplication/division/modulo.
#define MUL(mul_type, ch) \
    case ch: { \
      ret.type = kExprLexMultiplication; \
      ret.data.mul.type = mul_type; \
      break; \
    }
    MUL(kExprLexMulMul, '*')
    MUL(kExprLexMulDiv, '/')
    MUL(kExprLexMulMod, '%')
#undef MUL

#define CHARREG(typ, cond) \
    do { \
      ret.type = typ; \
      for (; (ret.len < pline.size \
              && cond(pline.data[ret.len])) \
           ; ret.len++) { \
      } \
    } while (0)

    // Whitespace.
    case ' ':
    case TAB: {
      CHARREG(kExprLexSpacing, ascii_iswhite);
      break;
    }

    // Control character, except for NUL, NL and TAB.
    case Ctrl_A: case Ctrl_B: case Ctrl_C: case Ctrl_D: case Ctrl_E:
    case Ctrl_F: case Ctrl_G: case Ctrl_H:

    case Ctrl_K: case Ctrl_L: case Ctrl_M: case Ctrl_N: case Ctrl_O:
    case Ctrl_P: case Ctrl_Q: case Ctrl_R: case Ctrl_S: case Ctrl_T:
    case Ctrl_U: case Ctrl_V: case Ctrl_W: case Ctrl_X: case Ctrl_Y:
    case Ctrl_Z: {
#define ISCTRL(schar) (schar < ' ')
      CHARREG(kExprLexInvalid, ISCTRL);
      ret.data.err.type = kExprLexSpacing;
      ret.data.err.msg =
          _("E15: Invalid control character present in input: %.*s");
      break;
#undef ISCTRL
    }

    // Number.
    // Note: determining whether dot is (not) a part of a float needs more
    // context, so lexer does not do this.
    // FIXME: Resolve ambiguity by additional argument.
    case '0': case '1': case '2': case '3': case '4': case '5': case '6':
    case '7': case '8': case '9': {
      CHARREG(kExprLexNumber, ascii_isdigit);
      break;
    }

    // Environment variable.
    case '$': {
      // FIXME: Parser function can’t be thread-safe with vim_isIDc.
      CHARREG(kExprLexEnv, vim_isIDc);
      break;
    }

    // Normal variable/function name.
    case 'a': case 'b': case 'c': case 'd': case 'e': case 'f': case 'g':
    case 'h': case 'i': case 'j': case 'k': case 'l': case 'm': case 'n':
    case 'o': case 'p': case 'q': case 'r': case 's': case 't': case 'u':
    case 'v': case 'w': case 'x': case 'y': case 'z':
    case 'A': case 'B': case 'C': case 'D': case 'E': case 'F': case 'G':
    case 'H': case 'I': case 'J': case 'K': case 'L': case 'M': case 'N':
    case 'O': case 'P': case 'Q': case 'R': case 'S': case 'T': case 'U':
    case 'V': case 'W': case 'X': case 'Y': case 'Z':
    case '_': {
#define ISWORD_OR_AUTOLOAD(x) \
      (ASCII_ISALNUM(x) || (x) == AUTOLOAD_CHAR || (x) == '_')
#define ISWORD(x) \
      (ASCII_ISALNUM(x) || (x) == '_')
      ret.data.var.scope = 0;
      ret.data.var.autoload = false;
      CHARREG(kExprLexPlainIdentifier, ISWORD);
      // "is" and "isnot" operators.
      if ((ret.len == 2 && memcmp(pline.data, "is", 2) == 0)
          || (ret.len == 5 && memcmp(pline.data, "isnot", 5) == 0)) {
        ret.type = kExprLexComparison;
        ret.data.cmp.type = kExprLexCmpIdentical;
        ret.data.cmp.inv = (ret.len == 5);
        GET_CCS(ret, pline);
      // Scope: `s:`, etc.
      } else if (ret.len == 1
                 && pline.size > 1
                 && strchr("sgvbwtla", schar) != NULL
                 && pline.data[ret.len] == ':') {
        ret.len++;
        ret.data.var.scope = schar;
        CHARREG(kExprLexPlainIdentifier, ISWORD_OR_AUTOLOAD);
        ret.data.var.autoload = (
            memchr(pline.data + 2, AUTOLOAD_CHAR, ret.len - 2)
            != NULL);
      // FIXME: Resolve ambiguity with an argument to the lexer function.
      // Previous CHARREG stopped at autoload character in order to make it
      // possible to detect `is#`. Continue now with autoload characters
      // included.
      //
      // Warning: there is ambiguity for the lexer: `is#Foo(1)` is a call of
      // function `is#Foo()`, `1is#Foo(1)` is a comparison `1 is# Foo(1)`. This
      // needs to be resolved on the higher level where context is available.
      } else if (pline.size > ret.len
                 && pline.data[ret.len] == AUTOLOAD_CHAR) {
        ret.data.var.autoload = true;
        CHARREG(kExprLexPlainIdentifier, ISWORD_OR_AUTOLOAD);
      }
      break;
#undef ISWORD_OR_AUTOLOAD
#undef ISWORD
    }
#undef CHARREG

    // Option.
    case '&': {
#define OPTNAMEMISS(ret) \
        do { \
          ret.type = kExprLexInvalid; \
          ret.data.err.type = kExprLexOption; \
          ret.data.err.msg = _("E112: Option name missing: %.*s"); \
        } while (0)
      if (pline.size > 1 && pline.data[1] == '&') {
        ret.type = kExprLexAnd;
        ret.len++;
        break;
      }
      if (pline.size == 1 || !ASCII_ISALPHA(pline.data[1])) {
        OPTNAMEMISS(ret);
        break;
      }
      ret.type = kExprLexOption;
      if (pline.size > 2
          && pline.data[2] == ':'
          && strchr("gl", pline.data[1]) != NULL) {
        ret.len += 2;
        ret.data.opt.scope = (pline.data[1] == 'g'
                              ? kExprLexOptGlobal
                              : kExprLexOptLocal);
        ret.data.opt.name = pline.data + 3;
      } else {
        ret.data.opt.scope = kExprLexOptUnspecified;
        ret.data.opt.name = pline.data + 1;
      }
      const char *p = ret.data.opt.name;
      const char *const e = pline.data + pline.size;
      if (e - p >= 4 && p[0] == 't' && p[1] == '_') {
        ret.data.opt.len = 4;
        ret.len += 4;
      } else {
        for (; p < e && ASCII_ISALPHA(*p); p++) {
        }
        ret.data.opt.len = (size_t)(p - ret.data.opt.name);
        if (ret.data.opt.len == 0) {
          OPTNAMEMISS(ret);
        } else {
          ret.len += ret.data.opt.len;
        }
      }
      break;
#undef OPTNAMEMISS
    }

    // Register.
    case '@': {
      ret.type = kExprLexRegister;
      if (pline.size > 1) {
        ret.len++;
        ret.data.reg.name = (uint8_t)pline.data[1];
      } else {
        ret.data.reg.name = -1;
      }
      break;
    }

    // Single quoted string.
    case '\'': {
      ret.type = kExprLexSingleQuotedString;
      ret.data.str.closed = false;
      for (; ret.len < pline.size && !ret.data.str.closed; ret.len++) {
        if (pline.data[ret.len] == '\'') {
          if (ret.len + 1 < pline.size && pline.data[ret.len + 1] == '\'') {
            ret.len++;
          } else {
            ret.data.str.closed = true;
          }
        }
      }
      break;
    }

    // Double quoted string.
    case '"': {
      ret.type = kExprLexDoubleQuotedString;
      ret.data.str.closed = false;
      for (; ret.len < pline.size && !ret.data.str.closed; ret.len++) {
        if (pline.data[ret.len] == '\\') {
          if (ret.len + 1 < pline.size) {
            ret.len++;
          }
        } else if (pline.data[ret.len] == '"') {
          ret.data.str.closed = true;
        }
      }
      break;
    }

    // Unary not, (un)equality and regex (not) match comparison operators.
    case '!':
    case '=': {
      if (pline.size == 1) {
viml_pexpr_next_token_invalid_comparison:
        ret.type = (schar == '!' ? kExprLexNot : kExprLexInvalid);
        if (ret.type == kExprLexInvalid) {
          ret.data.err.msg = _("E15: Expected == or =~: %.*s");
          ret.data.err.type = kExprLexComparison;
        }
        break;
      }
      ret.type = kExprLexComparison;
      ret.data.cmp.inv = (schar == '!');
      if (pline.data[1] == '=') {
        ret.data.cmp.type = kExprLexCmpEqual;
        ret.len++;
      } else if (pline.data[1] == '~') {
        ret.data.cmp.type = kExprLexCmpMatches;
        ret.len++;
      } else {
        goto viml_pexpr_next_token_invalid_comparison;
      }
      GET_CCS(ret, pline);
      break;
    }

    // Less/greater [or equal to] comparison operators.
    case '>':
    case '<': {
      ret.type = kExprLexComparison;
      const bool haseqsign = (pline.size > 1 && pline.data[1] == '=');
      if (haseqsign) {
        ret.len++;
      }
      GET_CCS(ret, pline);
      ret.data.cmp.inv = (schar == '<');
      ret.data.cmp.type = ((ret.data.cmp.inv ^ haseqsign)
                           ? kExprLexCmpGreaterOrEqual
                           : kExprLexCmpGreater);
      break;
    }

    // Minus sign or arrow from lambdas.
    case '-': {
      if (pline.size > 1 && pline.data[1] == '>') {
        ret.len++;
        ret.type = kExprLexArrow;
      } else {
        ret.type = kExprLexMinus;
      }
      break;
    }

    // Expression end because Ex command ended.
    case NUL:
    case NL: {
      ret.type = kExprLexEOC;
      break;
    }

    // Everything else is not valid.
    default: {
      ret.len = (size_t)utfc_ptr2len_len((const char_u *)pline.data,
                                         (int)pline.size);
      ret.type = kExprLexInvalid;
      ret.data.err.type = kExprLexPlainIdentifier;
      ret.data.err.msg = _("E15: Unidentified character: %.*s");
      break;
    }
  }
#undef GET_CCS
viml_pexpr_next_token_adv_return:
  if (!peek) {
    viml_parser_advance(pstate, ret.len);
  }
  return ret;
}

// start = s ternary_expr s EOC
// ternary_expr = binop_expr
//                ( s Question s ternary_expr s Colon s ternary_expr s )?
// binop_expr = unaryop_expr ( binop unaryop_expr )?
// unaryop_expr = ( unaryop )? subscript_expr
// subscript_expr = subscript_expr subscript
//                | value_expr
// subscript = Bracket('[') s ternary_expr s Bracket(']')
//           | s Parenthesis('(') call_args Parenthesis(')')
//           | Dot ( PlainIdentifier | Number )+
// # Note: `s` before Parenthesis('(') is only valid if preceding subscript_expr
// #       is PlainIdentifier
// value_expr = ( float | Number
//              | DoubleQuotedString | SingleQuotedString
//              | paren_expr
//              | list_literal
//              | lambda_literal
//              | dict_literal
//              | Environment
//              | Option
//              | Register
//              | var )
// float = Number Dot Number ( PlainIdentifier('e') ( Plus | Minus )? Number )?
// # Note: `1.2.3` is concat and not float. `"abc".2.3` is also concat without
// #       floats.
// paren_expr = Parenthesis('(') s ternary_expr s Parenthesis(')')
// list_literal = Bracket('[') s
//                  ( ternary_expr s Comma s )*
//                  ternary_expr? s
//                Bracket(']')
// dict_literal = FigureBrace('{') s
//                  ( ternary_expr s Colon s ternary_expr s Comma s )*
//                  ( ternary_expr s Colon s ternary_expr s )?
//                FigureBrace('}')
// lambda_literal = FigureBrace('{') s
//                    ( PlainIdentifier s Comma s )*
//                    PlainIdentifier s
//                  Arrow s
//                    ternary_expr s
//                  FigureBrace('}')
// var = varchunk+
// varchunk = PlainIdentifier
//          | Comparison("is" | "is#" | "isnot" | "isnot#")
//          | FigureBrace('{') s ternary_expr s FigureBrace('}')
// call_args = ( s ternary_expr s Comma s )* s ternary_expr? s
// binop = s ( Plus | Minus | Dot
//           | Comparison
//           | Multiplication
//           | Or
//           | And ) s
// unaryop = s ( Not | Plus | Minus ) s
// s = Spacing?
//
// Binary operator precedence and associativity:
//
// Operator | Precedence | Associativity
// ---------+------------+-----------------
// ||       | 2          | left
// &&       | 3          | left
// cmp*     | 4          | not associative
// + - .    | 5          | left
// * / %    | 6          | left
//
// * comparison operators:
//
// == ==# ==?  != !=# !=?
// =~ =~# =~?  !~ !~# !~?
//  >  >#  >?  <= <=# <=?
//  <  <#  <?  >= >=# >=?
// is is# is?  isnot isnot# isnot?
//
// Used highlighting groups and assumed linkage:
//
// NVimInvalid -> Error
// NVimInvalidValue -> NVimInvalid
// NVimInvalidOperator -> NVimInvalid
// NVimInvalidDelimiter -> NVimInvalid
//
// NVimOperator -> Operator
// NVimUnaryOperator -> NVimOperator
// NVimBinaryOperator -> NVimOperator
// NVimComparisonOperator -> NVimOperator
// NVimTernaryOperator -> NVimOperator
//
// NVimParenthesis -> Delimiter
//
// NVimInvalidSpacing -> NVimInvalid
// NVimInvalidTernaryOperator -> NVimInvalidOperator
// NVimInvalidRegister -> NVimInvalidValue
// NVimInvalidClosingBracket -> NVimInvalidDelimiter
// NVimInvalidSpacing -> NVimInvalid
//
// NVimUnaryPlus -> NVimUnaryOperator
// NVimBinaryPlus -> NVimBinaryOperator
// NVimRegister -> SpecialChar
// NVimNestingParenthesis -> NVimParenthesis
// NVimCallingParenthesis -> NVimParenthesis

/// Allocate a new node and set some of the values
///
/// @param[in]  type  Node type to allocate.
/// @param[in]  level  Node level to allocate
static inline ExprASTNode *viml_pexpr_new_node(const ExprASTNodeType type)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_MALLOC
{
  ExprASTNode *ret = xmalloc(sizeof(*ret));
  ret->type = type;
  ret->children = NULL;
  ret->next = NULL;
  return ret;
}

typedef enum {
  kEOpLvlInvalid = 0,
  kEOpLvlParens,
  kEOpLvlTernary,
  kEOpLvlOr,
  kEOpLvlAnd,
  kEOpLvlComparison,
  kEOpLvlAddition,  ///< Addition, subtraction and concatenation.
  kEOpLvlMultiplication,  ///< Multiplication, division and modulo.
  kEOpLvlUnary,  ///< Unary operations: not, minus, plus.
  kEOpLvlSubscript,  ///< Subscripts.
  kEOpLvlValue,  ///< Values: literals, variables, nested expressions, …
} ExprOpLvl;

typedef enum {
  kEOpAssNo= 'n',  ///< Not associative / not applicable.
  kEOpAssLeft = 'l',  ///< Left associativity.
  kEOpAssRight = 'r',  ///< Right associativity.
} ExprOpAssociativity;

static const ExprOpLvl node_type_to_op_lvl[] = {
  [kExprNodeMissing] = kEOpLvlInvalid,
  [kExprNodeOpMissing] = kEOpLvlMultiplication,

  [kExprNodeNested] = kEOpLvlParens,
  [kExprNodeComplexIdentifier] = kEOpLvlParens,

  [kExprNodeTernary] = kEOpLvlTernary,

  [kExprNodeBinaryPlus] = kEOpLvlAddition,

  [kExprNodeUnaryPlus] = kEOpLvlUnary,

  [kExprNodeSubscript] = kEOpLvlSubscript,
  [kExprNodeCall] = kEOpLvlSubscript,

  [kExprNodeRegister] = kEOpLvlValue,
  [kExprNodeListLiteral] = kEOpLvlValue,
  [kExprNodePlainIdentifier] = kEOpLvlValue,
};

static const ExprOpAssociativity node_type_to_op_ass[] = {
  [kExprNodeMissing] = kEOpAssNo,
  [kExprNodeOpMissing] = kEOpAssNo,

  [kExprNodeNested] = kEOpAssNo,
  [kExprNodeComplexIdentifier] = kEOpAssLeft,

  [kExprNodeTernary] = kEOpAssNo,

  [kExprNodeBinaryPlus] = kEOpAssLeft,

  [kExprNodeUnaryPlus] = kEOpAssNo,

  [kExprNodeSubscript] = kEOpAssLeft,
  [kExprNodeCall] = kEOpAssLeft,

  [kExprNodeRegister] = kEOpAssNo,
  [kExprNodeListLiteral] = kEOpAssNo,
  [kExprNodePlainIdentifier] = kEOpAssNo,
};

#ifdef UNIT_TESTING
#include <stdio.h>
REAL_FATTR_UNUSED
static inline void viml_pexpr_debug_print_ast_stack(
    const ExprASTStack *const ast_stack,
    const char *const msg)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_ALWAYS_INLINE
{
  fprintf(stderr, "\n%sstack: %zu:\n", msg, kv_size(*ast_stack));
  for (size_t i = 0; i < kv_size(*ast_stack); i++) {
    const ExprASTNode *const *const eastnode_p = (
        (const ExprASTNode *const *)kv_A(*ast_stack, i));
    if (*eastnode_p == NULL) {
      fprintf(stderr, "- %p : NULL\n", (void *)eastnode_p);
    } else {
      fprintf(stderr, "- %p : %p : %c : %zu:%zu:%zu\n",
              (void *)eastnode_p, (void *)(*eastnode_p), (*eastnode_p)->type,
              (*eastnode_p)->start.line, (*eastnode_p)->start.col,
              (*eastnode_p)->len);
    }
  }
}
#define PSTACK(msg) \
    viml_pexpr_debug_print_ast_stack(&ast_stack, #msg)
#define PSTACK_P(msg) \
    viml_pexpr_debug_print_ast_stack(ast_stack, #msg)
#endif

/// Handle binary operator
///
/// This function is responsible for handling priority levels as well.
static void viml_pexpr_handle_bop(ExprASTStack *const ast_stack,
                                  ExprASTNode *const bop_node,
                                  ExprASTLevel *const want_level_p)
  FUNC_ATTR_NONNULL_ALL
{
  ExprASTNode **top_node_p = NULL;
  ExprASTNode *top_node;
  ExprOpLvl top_node_lvl;
  ExprOpAssociativity top_node_ass;
  assert(kv_size(*ast_stack));
  const ExprOpLvl bop_node_lvl = node_type_to_op_lvl[bop_node->type];
  do {
    ExprASTNode **new_top_node_p = kv_last(*ast_stack);
    ExprASTNode *new_top_node = *new_top_node_p;
    assert(new_top_node != NULL);
    const ExprOpLvl new_top_node_lvl = node_type_to_op_lvl[new_top_node->type];
    const ExprOpAssociativity new_top_node_ass = (
        node_type_to_op_ass[new_top_node->type]);
    if (top_node_p != NULL
        && ((bop_node_lvl > new_top_node_lvl
             || (bop_node_lvl == new_top_node_lvl
                 && new_top_node_ass == kEOpAssNo)))) {
      break;
    }
    kv_drop(*ast_stack, 1);
    top_node_p = new_top_node_p;
    top_node = new_top_node;
    top_node_lvl = new_top_node_lvl;
    top_node_ass = new_top_node_ass;
  } while (kv_size(*ast_stack));
  // FIXME Handle right and no associativity correctly
  *top_node_p = bop_node;
  bop_node->children = top_node;
  assert(bop_node->children->next == NULL);
  kvi_push(*ast_stack, top_node_p);
  kvi_push(*ast_stack, &bop_node->children->next);
  *want_level_p = kELvlValue;
}

/// Get highlight group name
#define HL(g) (is_invalid ? "NVimInvalid" #g : "NVim" #g)

/// Highlight current token with the given group
#define HL_CUR_TOKEN(g) \
        viml_parser_highlight(pstate, cur_token.start, cur_token.len, \
                              HL(g))

/// Allocate new node, saving some values
#define NEW_NODE(type) \
    viml_pexpr_new_node(type)

/// Set position of the given node to position from the given token
///
/// @param  cur_node  Node to modify.
/// @param  cur_token  Token to set position from.
#define POS_FROM_TOKEN(cur_node, cur_token) \
    do { \
      cur_node->start = cur_token.start; \
      cur_node->len = cur_token.len; \
    } while (0)

/// Allocate new node and set its position from the current token
///
/// If previous token happened to contain spacing then it will be included.
///
/// @param  cur_node  Variable to save allocated node to.
/// @param  typ  Node type.
#define NEW_NODE_WITH_CUR_POS(cur_node, typ) \
    do { \
      cur_node = NEW_NODE(typ); \
      POS_FROM_TOKEN(cur_node, cur_token); \
      if (prev_token.type == kExprLexSpacing) { \
        cur_node->start = prev_token.start; \
        cur_node->len += prev_token.len; \
      } \
    } while (0)

// TODO(ZyX-I): actual condition
/// Check whether it is possible to have next expression after current
///
/// For :echo: `:echo @a @a` is a valid expression. `:echo (@a @a)` is not.
#define MAY_HAVE_NEXT_EXPR \
    (kv_size(ast_stack) == 1)

/// Record missing operator: for things like
///
///     :echo @a @a
///
/// (allowed) or
///
///     :echo (@a @a)
///
/// (parsed as OpMissing(@a, @a)).
#define OP_MISSING \
    do { \
      if (flags & kExprFlagsMulti && MAY_HAVE_NEXT_EXPR) { \
        /* Multiple expressions allowed, return without calling */ \
        /* viml_parser_advance(). */ \
        goto viml_pexpr_parse_end; \
      } else { \
        assert(*top_node_p != NULL); \
        ERROR_FROM_TOKEN_AND_MSG(cur_token, _("E15: Missing operator: %.*s")); \
        NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeOpMissing); \
        cur_node->len = 0; \
        viml_pexpr_handle_bop(&ast_stack, cur_node, &want_level); \
        is_invalid = true; \
        goto viml_pexpr_parse_process_token; \
      } \
    } while (0)

/// Set AST error, unless AST already is not correct
///
/// @param[out]  ret_ast  AST to set error in.
/// @param[in]  pstate  Parser state, used to get error message argument.
/// @param[in]  msg  Error message, assumed to be already translated and
///                  containing a single %token "%.*s".
/// @param[in]  start  Position at which error occurred.
static inline void east_set_error(ExprAST *const ret_ast,
                                  const ParserState *const pstate,
                                  const char *const msg,
                                  const ParserPosition start)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_ALWAYS_INLINE
{
  if (!ret_ast->correct) {
    return;
  }
  const ParserLine pline = pstate->reader.lines.items[start.line];
  ret_ast->correct = false;
  ret_ast->err.msg = msg;
  ret_ast->err.arg_len = (int)(pline.size - start.col);
  ret_ast->err.arg = pline.data + start.col;
}

/// Set error from the given kExprLexInvalid token and given message
#define ERROR_FROM_TOKEN_AND_MSG(cur_token, msg) \
    east_set_error(&ast, pstate, msg, cur_token.start)

/// Set error from the given kExprLexInvalid token
#define ERROR_FROM_TOKEN(cur_token) \
    ERROR_FROM_TOKEN_AND_MSG(cur_token, cur_token.data.err.msg)

/// Parse one VimL expression
///
/// @param  pstate  Parser state.
/// @param[in]  flags  Additional flags, see ExprParserFlags
///
/// @return Parsed AST.
ExprAST viml_pexpr_parse(ParserState *const pstate, const int flags)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  ExprAST ast = {
    .correct = true,
    .err = {
      .msg = NULL,
      .arg_len = 0,
      .arg = NULL,
    },
    .root = NULL,
  };
  ExprASTStack ast_stack;
  kvi_init(ast_stack);
  kvi_push(ast_stack, &ast.root);
  // Expressions stack:
  // 1. *last is NULL if want_level is kExprLexValue. Indicates where expression
  //    is to be put.
  // 2. *last is not NULL otherwise, indicates current expression to be used as
  //    an operator argument.
  ExprASTLevel want_level = kELvlValue;
  LexExprToken prev_token = { .type = kExprLexMissing };
  bool highlighted_prev_spacing = false;
  do {
    LexExprToken cur_token = viml_pexpr_next_token(pstate, true);
    if (cur_token.type == kExprLexEOC) {
      if (flags & kExprFlagsDisallowEOC) {
        if (cur_token.len == 0) {
          // It is end of string, break.
          break;
        } else {
          // It is NL, NUL or bar.
          //
          // Note: `<C-r>=1 | 2<CR>` actually yields 1 in Vim without any
          //       errors. This will be changed here.
          cur_token.type = kExprLexInvalid;
          cur_token.data.err.msg = _("E15: Unexpected EOC character: %.*s");
          const ParserLine pline = (
              pstate->reader.lines.items[cur_token.start.line]);
          const char eoc_char = pline.data[cur_token.start.col];
          cur_token.data.err.type = ((eoc_char == NUL || eoc_char == NL)
                                     ? kExprLexSpacing
                                     : kExprLexOr);
        }
      } else {
        break;
      }
    }
    LexExprTokenType tok_type = cur_token.type;
    const bool token_invalid = (tok_type == kExprLexInvalid);
    bool is_invalid = token_invalid;
viml_pexpr_parse_process_token:
    if (tok_type == kExprLexSpacing) {
      if (is_invalid) {
        viml_parser_highlight(pstate, cur_token.start, cur_token.len,
                              HL(Spacing));
      } else {
        // Do not do anything: let regular spacing be highlighted as normal.
        // This also allows later to highlight spacing as invalid.
      }
      goto viml_pexpr_parse_cycle_end;
    } else if (is_invalid && prev_token.type == kExprLexSpacing
               && !highlighted_prev_spacing) {
      viml_parser_highlight(pstate, prev_token.start, prev_token.len,
                            HL(Spacing));
      is_invalid = false;
      highlighted_prev_spacing = true;
    }
    ExprASTNode **const top_node_p = kv_last(ast_stack);
    ExprASTNode *cur_node = NULL;
    // Keep these two asserts separate for debugging purposes.
    assert(want_level == kELvlValue || *top_node_p != NULL);
    assert(want_level != kELvlValue || *top_node_p == NULL);
    switch (tok_type) {
      case kExprLexEOC: {
        assert(false);
      }
      case kExprLexInvalid: {
        ERROR_FROM_TOKEN(cur_token);
        tok_type = cur_token.data.err.type;
        goto viml_pexpr_parse_process_token;
      }
      case kExprLexRegister: {
        if (want_level == kELvlValue) {
          NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeRegister);
          cur_node->data.reg.name = cur_token.data.reg.name;
          *top_node_p = cur_node;
          want_level = kELvlOperator;
          viml_parser_highlight(pstate, cur_token.start, cur_token.len,
                                HL(Register));
        } else {
          // Register in operator position: e.g. @a @a
          OP_MISSING;
        }
        break;
      }
      case kExprLexPlus: {
        if (want_level == kELvlValue) {
          // Value level: assume unary plus
          NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeUnaryPlus);
          *top_node_p = cur_node;
          kvi_push(ast_stack, &cur_node->children);
          HL_CUR_TOKEN(UnaryPlus);
        } else if (want_level < kELvlValue) {
          NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeBinaryPlus);
          viml_pexpr_handle_bop(&ast_stack, cur_node, &want_level);
          HL_CUR_TOKEN(BinaryPlus);
        }
        want_level = kELvlValue;
        break;
      }
      case kExprLexParenthesis: {
        if (cur_token.data.brc.closing) {
          if (want_level == kELvlValue) {
            if (kv_size(ast_stack) > 1) {
              const ExprASTNode *const prev_top_node = *kv_Z(ast_stack, 1);
              if (prev_top_node->type == kExprNodeCall) {
                // Function call without arguments, this is not an error.
                // But further code does not expect NULL nodes.
                kv_drop(ast_stack, 1);
                goto viml_pexpr_parse_no_paren_closing_error;
              }
            }
            is_invalid = true;
            ERROR_FROM_TOKEN_AND_MSG(cur_token, _("E15: Expected value: %.*s"));
            NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeMissing);
            cur_node->len = 0;
            *top_node_p = cur_node;
          } else {
            // Always drop the topmost value: when want_level != kELvlValue
            // topmost item on stack is a *finished* left operand, which may as
            // well be "(@a)" which needs not be finished.
            kv_drop(ast_stack, 1);
          }
viml_pexpr_parse_no_paren_closing_error: {}
          ExprASTNode **new_top_node_p = NULL;
          while (kv_size(ast_stack)
                 && (new_top_node_p == NULL
                     || ((*new_top_node_p)->type != kExprNodeNested
                         && (*new_top_node_p)->type != kExprNodeCall))) {
            new_top_node_p = kv_pop(ast_stack);
          }
          if (new_top_node_p != NULL
              && ((*new_top_node_p)->type == kExprNodeNested
                  || (*new_top_node_p)->type == kExprNodeCall)) {
            if ((*new_top_node_p)->type == kExprNodeNested) {
              HL_CUR_TOKEN(NestingParenthesis);
            } else {
              HL_CUR_TOKEN(CallingParenthesis);
            }
          } else {
            // “Always drop the topmost value” branch has got rid of the single
            // value stack had, so there is nothing known to enclose. Correct
            // this.
            if (new_top_node_p == NULL) {
              new_top_node_p = top_node_p;
            }
            is_invalid = true;
            HL_CUR_TOKEN(NestingParenthesis);
            ERROR_FROM_TOKEN_AND_MSG(
                cur_token, _("E15: Unexpected closing parenthesis: %.*s"));
            cur_node = NEW_NODE(kExprNodeNested);
            cur_node->start = cur_token.start;
            cur_node->len = 0;
            // Unexpected closing parenthesis, assume that it was wanted to
            // enclose everything in ().
            cur_node->children = *new_top_node_p;
            *new_top_node_p = cur_node;
            assert(cur_node->next == NULL);
          }
          kvi_push(ast_stack, new_top_node_p);
          want_level = kELvlOperator;
        } else {
          if (want_level == kELvlValue) {
            NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeNested);
            *top_node_p = cur_node;
            kvi_push(ast_stack, &cur_node->children);
            HL_CUR_TOKEN(NestingParenthesis);
          } else if (want_level == kELvlOperator) {
            if (prev_token.type == kExprLexSpacing) {
              // For some reason "function (args)" is a function call, but
              // "(funcref) (args)" is not. AFAIR this somehow involves
              // compatibility and Bram was commenting that this is
              // intentionally inconsistent and he is not very happy with the
              // situation himself.
              if ((*top_node_p)->type != kExprNodePlainIdentifier
                  && (*top_node_p)->type != kExprNodeComplexIdentifier) {
                OP_MISSING;
              }
            }
            NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeCall);
            viml_pexpr_handle_bop(&ast_stack, cur_node, &want_level);
            HL_CUR_TOKEN(CallingParenthesis);
          } else {
            // Currently it is impossible to reach this.
            assert(false);
          }
          want_level = kELvlValue;
        }
        break;
      }
    }
viml_pexpr_parse_cycle_end:
    prev_token = cur_token;
    highlighted_prev_spacing = false;
    viml_parser_advance(pstate, cur_token.len);
  } while (true);
viml_pexpr_parse_end:
  if (want_level == kELvlValue) {
    east_set_error(&ast, pstate, _("E15: Expected value: %.*s"), pstate->pos);
  } else if (kv_size(ast_stack) != 1) {
    // Something may be wrong, check whether it really is.

    // Pointer to ast.root must never be dropped, so “!= 1” is expected to be
    // the same as “> 1”.
    assert(kv_size(ast_stack));
    // Topmost stack item must be a *finished* value, so it must not be
    // analyzed. E.g. it may contain an already finished nested expression.
    kv_drop(ast_stack, 1);
    while (ast.correct && kv_size(ast_stack)) {
      const ExprASTNode *const cur_node = (*kv_pop(ast_stack));
      // This should only happen when want_level == kELvlValue.
      assert(cur_node != NULL);
      switch (cur_node->type) {
        case kExprNodeOpMissing:
        case kExprNodeMissing: {
          // Error should’ve been already reported.
          break;
        }
        case kExprNodeCall: {
          // TODO(ZyX-I): Rehighlight as invalid?
          east_set_error(
              &ast, pstate,
              _("E116: Missing closing parenthesis for function call: %.*s"),
              cur_node->start);
          break;
        }
        case kExprNodeNested: {
          // TODO(ZyX-I): Rehighlight as invalid?
          east_set_error(
              &ast, pstate,
              _("E110: Missing closing parenthesis for nested expression"
                ": %.*s"),
              cur_node->start);
          break;
        }
        case kExprNodeBinaryPlus:
        case kExprNodeUnaryPlus:
        case kExprNodeRegister: {
          // It is OK to see these in the stack.
          break;
        }
        // TODO(ZyX-I): handle other values
      }
    }
  }
  kvi_destroy(ast_stack);
  return ast;
}

#undef NEW_NODE
#undef HL
