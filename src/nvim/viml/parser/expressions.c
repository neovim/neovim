// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/// VimL expression parser

// Planned incompatibilities (to be included into vim_diff.txt when this parser
// will be an actual part of VimL evaluation process):
//
// 1. Expressions are first fully parsed and only then executed.  This means
//    that while ":echo [system('touch abc')" will create file "abc" in Vim and
//    only then raise syntax error regarding missing comma in list in Neovim
//    trying to execute that will immediately raise syntax error regarding
//    missing list end without actually executing anything.
// 2. Expressions are first fully parsed, without considering any runtime
//    information.  This means things like that "d.a" does not change its
//    meaning depending on type of "d" (or whether Vim is currently executing or
//    skipping).  For compatibility reasons the dot thus may either be “concat
//    or subscript” operator or just “concat” operator.
// 3. Expressions parser is aware whether it is called for :echo or <C-r>=.
//    This means that while "<C-r>=1 | 2<CR>" is equivalent to "<C-r>=1<CR>"
//    because "| 2" part is left to be treated as a command separator and then
//    ignored in Neovim it is an error.
// 4. Expressions parser has generally better error reporting.  But for
//    compatibility reasons most errors have error code E15 while error messages
//    are significantly different from Vim’s E15.  Also some error codes were
//    retired because of being harder to emulate or because of them being
//    a result of differences in parsing process: e.g. with ":echo {a, b}" Vim
//    will attempt to parse expression as lambda, fail, check whether it is
//    a curly-braces-name, fail again, and evaluate that as a dictionary, giving
//    error regarding undefined variable "a" (or about missing colon).  Neovim
//    will not try to evaluate anything here: comma right after an argument name
//    means that expression may not be anything, but lambda, so the resulting
//    error message will never be about missing variable or colon: it will be
//    about missing arrow (or a continuation of argument list).
// 5. Failing to parse expression always gives exactly one error message: no
//    more stack of error messages like >
//
//        :echo [1,
//        E697: Missing end of List ']':
//        E15: Invalid expression: [1,
//
// <  , just exactly one E697 message.
// 6. Some expressions involving calling parenthesis which are treated
//    separately by Vim even when not separated by spaces are treated as one
//    expression by Neovim: e.g. ":echo (1)(1)" will yield runtime error after
//    failing to call "1", while Vim will echo "1 1". Reasoning is the same:
//    type of what is in the first expression is generally not known when
//    parsing, so to have separate expressions like this separate them with
//    spaces.
// 7. 'isident' no longer applies to environment variables, they always include
//    ASCII alphanumeric characters and underscore and nothing except this.

#include <stdbool.h>
#include <stddef.h>
#include <assert.h>
#include <string.h>

#include "nvim/vim.h"
#include "nvim/memory.h"
#include "nvim/types.h"
#include "nvim/charset.h"
#include "nvim/ascii.h"
#include "nvim/assert.h"
#include "nvim/lib/kvec.h"
#include "nvim/eval/typval.h"

#include "nvim/viml/parser/expressions.h"
#include "nvim/viml/parser/parser.h"

#define vim_str2nr(s, ...) vim_str2nr((const char_u *)(s), __VA_ARGS__)

typedef kvec_withinit_t(ExprASTNode **, 16) ExprASTStack;

/// Which nodes may be wanted
typedef enum {
  /// Operators: function call, subscripts, binary operators, …
  ///
  /// For unrestricted expressions.
  kENodeOperator,
  /// Values: literals, variables, nested expressions, unary operators.
  ///
  /// For unrestricted expressions as well, implies that top item in AST stack
  /// points to NULL.
  kENodeValue,
} ExprASTWantedNode;

/// Parse type: what is being parsed currently
typedef enum {
  /// Parsing regular VimL expression
  kEPTExpr = 0,
  /// Parsing lambda arguments
  ///
  /// Just like parsing function arguments, but it is valid to be ended with an
  /// arrow only.
  kEPTLambdaArguments,
  /// Assignment: parsing for :let
  kEPTAssignment,
  /// Single assignment: used when lists are not allowed (i.e. when nesting)
  kEPTSingleAssignment,
} ExprASTParseType;

typedef kvec_withinit_t(ExprASTParseType, 4) ExprASTParseTypeStack;

/// Operator priority level
typedef enum {
  kEOpLvlInvalid = 0,
  kEOpLvlComplexIdentifier,
  kEOpLvlParens,
  kEOpLvlAssignment,
  kEOpLvlArrow,
  kEOpLvlComma,
  kEOpLvlColon,
  kEOpLvlTernaryValue,
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

/// Operator associativity
typedef enum {
  kEOpAssNo= 'n',  ///< Not associative / not applicable.
  kEOpAssLeft = 'l',  ///< Left associativity.
  kEOpAssRight = 'r',  ///< Right associativity.
} ExprOpAssociativity;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/parser/expressions.c.generated.h"
#endif

/// Character used as a separator in autoload function/variable names.
#define AUTOLOAD_CHAR '#'

/// Scale number by a given factor
///
/// Used to apply exponent to a number. Idea taken from uClibc.
///
/// @param[in]  num  Number to scale. Does not bother doing anything if it is
///                  zero.
/// @param[in]  base  Base, should be 10 since non-decimal floating-point
///                   numbers are not supported.
/// @param[in]  exponent  Exponent to scale by.
/// @param[in]  exponent_negative  True if exponent is negative.
static inline float_T scale_number(const float_T num,
                                   const uint8_t base,
                                   const uvarnumber_T exponent,
                                   const bool exponent_negative)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_CONST
{
  if (num == 0 || exponent == 0) {
    return num;
  }
  assert(base);
  uvarnumber_T exp = exponent;
  float_T p_base = (float_T)base;
  float_T ret = num;
  while (exp) {
    if (exp & 1) {
      if (exponent_negative) {
        ret /= p_base;
      } else {
        ret *= p_base;
      }
    }
    exp >>= 1;
    p_base *= p_base;
  }
  return ret;
}

/// Get next token for the VimL expression input
///
/// @param  pstate  Parser state.
/// @param[in]  flags  Flags, @see LexExprFlags.
///
/// @return Next token.
LexExprToken viml_pexpr_next_token(ParserState *const pstate, const int flags)
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
          (ExprCaseCompareStrategy)pline.data[ret.len]; \
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
    case '0': case '1': case '2': case '3': case '4': case '5': case '6':
    case '7': case '8': case '9': {
      ret.data.num.is_float = false;
      ret.data.num.base = 10;
      size_t frac_start = 0;
      size_t exp_start = 0;
      size_t frac_end = 0;
      bool exp_negative = false;
      CHARREG(kExprLexNumber, ascii_isdigit);
      if (flags & kELFlagAllowFloat) {
        const LexExprToken non_float_ret = ret;
        if (pline.size > ret.len + 1
            && pline.data[ret.len] == '.'
            && ascii_isdigit(pline.data[ret.len + 1])) {
          ret.len++;
          frac_start = ret.len;
          frac_end = ret.len;
          ret.data.num.is_float = true;
          for (; ret.len < pline.size && ascii_isdigit(pline.data[ret.len])
               ; ret.len++) {
            // A small optimization: trailing zeroes in fractional part do not
            // add anything to significand, so it is useless to include them in
            // frac_end.
            if (pline.data[ret.len] != '0') {
              frac_end = ret.len + 1;
            }
          }
          if (pline.size > ret.len + 1
              && (pline.data[ret.len] == 'e'
                  || pline.data[ret.len] == 'E')
              && ((pline.size > ret.len + 2
                   && (pline.data[ret.len + 1] == '+'
                       || pline.data[ret.len + 1] == '-')
                   && ascii_isdigit(pline.data[ret.len + 2]))
                  || ascii_isdigit(pline.data[ret.len + 1]))) {
            ret.len++;
            if (pline.data[ret.len] == '+'
                || (exp_negative = (pline.data[ret.len] == '-'))) {
              ret.len++;
            }
            exp_start = ret.len;
            CHARREG(kExprLexNumber, ascii_isdigit);
          }
        }
        if (pline.size > ret.len
            && (pline.data[ret.len] == '.'
                || ASCII_ISALPHA(pline.data[ret.len]))) {
          ret = non_float_ret;
        }
      }
      // TODO(ZyX-I): detect overflows
      if (ret.data.num.is_float) {
        // Vim used to use string2float here which in turn uses strtod(). There
        // are two problems with this approach:
        // 1. strtod() is locale-dependent. Not sure how it is worked around so
        //    that I do not see relevant bugs, but it still does not look like
        //    a good idea.
        // 2. strtod() does not accept length argument.
        //
        // The below variant of parsing floats was recognized as acceptable
        // because it is basically how uClibc does the thing: it generates
        // a number ignoring decimal point (but recording its position), then
        // uses recorded position to scale number down when processing exponent.
        float_T significand_part = 0;
        uvarnumber_T exp_part = 0;
        const size_t frac_size = (size_t)(frac_end - frac_start);
        for (size_t i = 0; i < frac_end; i++) {
          if (i == frac_start - 1) {
            continue;
          }
          significand_part = significand_part * 10 + (pline.data[i] - '0');
        }
        if (exp_start) {
          vim_str2nr(pline.data + exp_start, NULL, NULL, 0, NULL, &exp_part,
                     (int)(ret.len - exp_start));
        }
        if (exp_negative) {
          exp_part += frac_size;
        } else {
          if (exp_part < frac_size) {
            exp_negative = true;
            exp_part = frac_size - exp_part;
          } else {
            exp_part -= frac_size;
          }
        }
        ret.data.num.val.floating = scale_number(significand_part, 10, exp_part,
                                                 exp_negative);
      } else {
        int len;
        int prep;
        vim_str2nr(pline.data, &prep, &len, STR2NR_ALL, NULL,
                   &ret.data.num.val.integer, (int)pline.size);
        ret.len = (size_t)len;
        const uint8_t bases[] = {
          [0] = 10,
          ['0'] = 8,
          ['x'] = 16, ['X'] = 16,
          ['b'] = 2, ['B'] = 2,
        };
        ret.data.num.base = bases[prep];
      }
      break;
    }

#define ISWORD_OR_AUTOLOAD(x) \
      (ascii_isident(x) || (x) == AUTOLOAD_CHAR)

    // Environment variable.
    case '$': {
      CHARREG(kExprLexEnv, ascii_isident);
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
      ret.data.var.scope = 0;
      ret.data.var.autoload = false;
      CHARREG(kExprLexPlainIdentifier, ascii_isident);
      // "is" and "isnot" operators.
      if (!(flags & kELFlagIsNotCmp)
          && ((ret.len == 2 && memcmp(pline.data, "is", 2) == 0)
              || (ret.len == 5 && memcmp(pline.data, "isnot", 5) == 0))) {
        ret.type = kExprLexComparison;
        ret.data.cmp.type = kExprCmpIdentical;
        ret.data.cmp.inv = (ret.len == 5);
        GET_CCS(ret, pline);
      // Scope: `s:`, etc.
      } else if (ret.len == 1
                 && pline.size > 1
                 && memchr(EXPR_VAR_SCOPE_LIST, schar,
                           sizeof(EXPR_VAR_SCOPE_LIST)) != NULL
                 && pline.data[ret.len] == ':'
                 && !(flags & kELFlagForbidScope)) {
        ret.len++;
        ret.data.var.scope = (ExprVarScope)schar;
        CHARREG(kExprLexPlainIdentifier, ISWORD_OR_AUTOLOAD);
        ret.data.var.autoload = (
            memchr(pline.data + 2, AUTOLOAD_CHAR, ret.len - 2)
            != NULL);
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
    }

#undef ISWORD_OR_AUTOLOAD
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
          && memchr(EXPR_OPT_SCOPE_LIST, pline.data[1],
                    sizeof(EXPR_OPT_SCOPE_LIST)) != NULL) {
        ret.len += 2;
        ret.data.opt.scope = (ExprOptScope)pline.data[1];
        ret.data.opt.name = pline.data + 3;
      } else {
        ret.data.opt.scope = kExprOptScopeUnspecified;
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
        ret.type = (schar == '!' ? kExprLexNot : kExprLexAssignment);
        ret.data.ass.type = kExprAsgnPlain;
        break;
      }
      ret.type = kExprLexComparison;
      ret.data.cmp.inv = (schar == '!');
      if (pline.data[1] == '=') {
        ret.data.cmp.type = kExprCmpEqual;
        ret.len++;
      } else if (pline.data[1] == '~') {
        ret.data.cmp.type = kExprCmpMatches;
        ret.len++;
      } else if (schar == '!') {
        ret.type = kExprLexNot;
      } else {
        ret.type = kExprLexAssignment;
        ret.data.ass.type = kExprAsgnPlain;
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
                           ? kExprCmpGreaterOrEqual
                           : kExprCmpGreater);
      break;
    }

    // Minus sign, arrow from lambdas or augmented assignment.
    case '-': {
      if (pline.size > 1 && pline.data[1] == '>') {
        ret.len++;
        ret.type = kExprLexArrow;
      } else if (pline.size > 1 && pline.data[1] == '=') {
        ret.len++;
        ret.type = kExprLexAssignment;
        ret.data.ass.type = kExprAsgnSubtract;
      } else {
        ret.type = kExprLexMinus;
      }
      break;
    }

    // Sign or augmented assignment.
#define CHAR_OR_ASSIGN(ch, ch_type, ass_type) \
    case ch: { \
      if (pline.size > 1 && pline.data[1] == '=') { \
        ret.len++; \
        ret.type = kExprLexAssignment; \
        ret.data.ass.type = ass_type; \
      } else { \
        ret.type = ch_type; \
      } \
      break; \
    }
    CHAR_OR_ASSIGN('+', kExprLexPlus, kExprAsgnAdd)
    CHAR_OR_ASSIGN('.', kExprLexDot, kExprAsgnConcat)
#undef CHAR_OR_ASSIGN

    // Expression end because Ex command ended.
    case NUL:
    case NL: {
      if (flags & kELFlagForbidEOC) {
        ret.type = kExprLexInvalid;
        ret.data.err.msg = _("E15: Unexpected EOC character: %.*s");
        ret.data.err.type = kExprLexSpacing;
      } else {
        ret.type = kExprLexEOC;
      }
      break;
    }

    case '|': {
      if (pline.size >= 2 && pline.data[ret.len] == '|') {
        // "||" is or.
        ret.len++;
        ret.type = kExprLexOr;
      } else if (flags & kELFlagForbidEOC) {
        // Note: `<C-r>=1 | 2<CR>` actually yields 1 in Vim without any
        //       errors. This will be changed here.
        ret.type = kExprLexInvalid;
        ret.data.err.msg = _("E15: Unexpected EOC character: %.*s");
        ret.data.err.type = kExprLexOr;
      } else {
        ret.type = kExprLexEOC;
      }
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
  if (!(flags & kELFlagPeek)) {
    viml_parser_advance(pstate, ret.len);
  }
  return ret;
}

static const char *const eltkn_type_tab[] = {
  [kExprLexInvalid] = "Invalid",
  [kExprLexMissing] = "Missing",
  [kExprLexSpacing] = "Spacing",
  [kExprLexEOC] = "EOC",

  [kExprLexQuestion] = "Question",
  [kExprLexColon] = "Colon",
  [kExprLexOr] = "Or",
  [kExprLexAnd] = "And",
  [kExprLexComparison] = "Comparison",
  [kExprLexPlus] = "Plus",
  [kExprLexMinus] = "Minus",
  [kExprLexDot] = "Dot",
  [kExprLexMultiplication] = "Multiplication",

  [kExprLexNot] = "Not",

  [kExprLexNumber] = "Number",
  [kExprLexSingleQuotedString] = "SingleQuotedString",
  [kExprLexDoubleQuotedString] = "DoubleQuotedString",
  [kExprLexOption] = "Option",
  [kExprLexRegister] = "Register",
  [kExprLexEnv] = "Env",
  [kExprLexPlainIdentifier] = "PlainIdentifier",

  [kExprLexBracket] = "Bracket",
  [kExprLexFigureBrace] = "FigureBrace",
  [kExprLexParenthesis] = "Parenthesis",
  [kExprLexComma] = "Comma",
  [kExprLexArrow] = "Arrow",
  [kExprLexAssignment] = "Assignment",
};

const char *const eltkn_cmp_type_tab[] = {
  [kExprCmpEqual] = "Equal",
  [kExprCmpMatches] = "Matches",
  [kExprCmpGreater] = "Greater",
  [kExprCmpGreaterOrEqual] = "GreaterOrEqual",
  [kExprCmpIdentical] = "Identical",
};

const char *const expr_asgn_type_tab[] = {
  [kExprAsgnPlain] = "Plain",
  [kExprAsgnAdd] = "Add",
  [kExprAsgnSubtract] = "Subtract",
  [kExprAsgnConcat] = "Concat",
};

const char *const ccs_tab[] = {
  [kCCStrategyUseOption] = "UseOption",
  [kCCStrategyMatchCase] = "MatchCase",
  [kCCStrategyIgnoreCase] = "IgnoreCase",
};

static const char *const eltkn_mul_type_tab[] = {
  [kExprLexMulMul] = "Mul",
  [kExprLexMulDiv] = "Div",
  [kExprLexMulMod] = "Mod",
};

static const char *const eltkn_opt_scope_tab[] = {
  [kExprOptScopeUnspecified] = "Unspecified",
  [kExprOptScopeGlobal] = "Global",
  [kExprOptScopeLocal] = "Local",
};

/// Represent token as a string
///
/// Intended for testing and debugging purposes.
///
/// @param[in]  pstate  Parser state, needed to get token string from it. May be
///                     NULL, in which case in place of obtaining part of the
///                     string represented by token only token length is
///                     returned.
/// @param[in]  token  Token to represent.
/// @param[out]  ret_size  Return string size, for cases like NULs inside
///                        a string. May be NULL.
///
/// @return Token represented in a string form, in a static buffer (overwritten
///         on each call).
const char *viml_pexpr_repr_token(const ParserState *const pstate,
                                  const LexExprToken token,
                                  size_t *const ret_size)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  static char ret[1024];
  char *p = ret;
  const char *const e = &ret[1024] - 1;
#define ADDSTR(...) \
  do { \
    p += snprintf(p, (size_t)(sizeof(ret) - (size_t)(p - ret)), __VA_ARGS__); \
    if (p >= e) { \
      goto viml_pexpr_repr_token_end; \
    } \
  } while (0)
  ADDSTR("%zu:%zu:%s", token.start.line, token.start.col,
         eltkn_type_tab[token.type]);
  switch (token.type) {
#define TKNARGS(tkn_type, ...) \
    case tkn_type: { \
      ADDSTR(__VA_ARGS__); \
      break; \
    }
    TKNARGS(kExprLexComparison, "(type=%s,ccs=%s,inv=%i)",
            eltkn_cmp_type_tab[token.data.cmp.type],
            ccs_tab[token.data.cmp.ccs],
            (int)token.data.cmp.inv)
    TKNARGS(kExprLexMultiplication, "(type=%s)",
            eltkn_mul_type_tab[token.data.mul.type])
    TKNARGS(kExprLexAssignment, "(type=%s)",
            expr_asgn_type_tab[token.data.ass.type])
    TKNARGS(kExprLexRegister, "(name=%s)", intchar2str(token.data.reg.name))
    case kExprLexDoubleQuotedString:
    TKNARGS(kExprLexSingleQuotedString, "(closed=%i)",
            (int)token.data.str.closed)
    TKNARGS(kExprLexOption, "(scope=%s,name=%.*s)",
            eltkn_opt_scope_tab[token.data.opt.scope],
            (int)token.data.opt.len, token.data.opt.name)
    TKNARGS(kExprLexPlainIdentifier, "(scope=%s,autoload=%i)",
            intchar2str((int)token.data.var.scope),
            (int)token.data.var.autoload)
    TKNARGS(kExprLexNumber, "(is_float=%i,base=%i,val=%lg)",
            (int)token.data.num.is_float,
            (int)token.data.num.base,
            (double)(token.data.num.is_float
                     ? (double)token.data.num.val.floating
                     : (double)token.data.num.val.integer))
    TKNARGS(kExprLexInvalid, "(msg=%s)", token.data.err.msg)
    default: {
      // No additional arguments.
      break;
    }
#undef TKNARGS
  }
  if (pstate == NULL) {
    ADDSTR("::%zu", token.len);
  } else {
    *p++ = ':';
    memmove(
        p, &pstate->reader.lines.items[token.start.line].data[token.start.col],
        token.len);
    p += token.len;
    *p = NUL;
  }
#undef ADDSTR
viml_pexpr_repr_token_end:
  if (ret_size != NULL) {
    *ret_size = (size_t)(p - ret);
  }
  return ret;
}

const char *const east_node_type_tab[] = {
  [kExprNodeMissing] = "Missing",
  [kExprNodeOpMissing] = "OpMissing",
  [kExprNodeTernary] = "Ternary",
  [kExprNodeTernaryValue] = "TernaryValue",
  [kExprNodeRegister] = "Register",
  [kExprNodeSubscript] = "Subscript",
  [kExprNodeListLiteral] = "ListLiteral",
  [kExprNodeUnaryPlus] = "UnaryPlus",
  [kExprNodeBinaryPlus] = "BinaryPlus",
  [kExprNodeNested] = "Nested",
  [kExprNodeCall] = "Call",
  [kExprNodePlainIdentifier] = "PlainIdentifier",
  [kExprNodePlainKey] = "PlainKey",
  [kExprNodeComplexIdentifier] = "ComplexIdentifier",
  [kExprNodeUnknownFigure] = "UnknownFigure",
  [kExprNodeLambda] = "Lambda",
  [kExprNodeDictLiteral] = "DictLiteral",
  [kExprNodeCurlyBracesIdentifier] = "CurlyBracesIdentifier",
  [kExprNodeComma] = "Comma",
  [kExprNodeColon] = "Colon",
  [kExprNodeArrow] = "Arrow",
  [kExprNodeComparison] = "Comparison",
  [kExprNodeConcat] = "Concat",
  [kExprNodeConcatOrSubscript] = "ConcatOrSubscript",
  [kExprNodeInteger] = "Integer",
  [kExprNodeFloat] = "Float",
  [kExprNodeSingleQuotedString] = "SingleQuotedString",
  [kExprNodeDoubleQuotedString] = "DoubleQuotedString",
  [kExprNodeOr] = "Or",
  [kExprNodeAnd] = "And",
  [kExprNodeUnaryMinus] = "UnaryMinus",
  [kExprNodeBinaryMinus] = "BinaryMinus",
  [kExprNodeNot] = "Not",
  [kExprNodeMultiplication] = "Multiplication",
  [kExprNodeDivision] = "Division",
  [kExprNodeMod] = "Mod",
  [kExprNodeOption] = "Option",
  [kExprNodeEnvironment] = "Environment",
  [kExprNodeAssignment] = "Assignment",
};

/// Represent `int` character as a string
///
/// Converts
/// - ASCII digits into '{digit}'
/// - ASCII printable characters into a single-character strings
/// - everything else to numbers.
///
/// @param[in]  ch  Character to convert.
///
/// @return Converted string, stored in a static buffer (overriden after each
///         call).
static const char *intchar2str(const int ch)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  static char buf[sizeof(int) * 3 + 1];
  if (' ' <= ch && ch < 0x7f) {
    if (ascii_isdigit(ch)) {
      buf[0] = '\'';
      buf[1] = (char)ch;
      buf[2] = '\'';
      buf[3] = NUL;
    } else {
      buf[0] = (char)ch;
      buf[1] = NUL;
    }
  } else {
    snprintf(buf, sizeof(buf), "%i", ch);
  }
  return buf;
}

#ifdef UNIT_TESTING
#include <stdio.h>

REAL_FATTR_UNUSED
static inline void viml_pexpr_debug_print_ast_node(
    const ExprASTNode *const *const eastnode_p,
    const char *const prefix)
{
  if (*eastnode_p == NULL) {
    fprintf(stderr, "%s %p : NULL\n", prefix, (void *)eastnode_p);
  } else {
    fprintf(stderr, "%s %p : %p : %s : %zu:%zu:%zu\n",
            prefix, (void *)eastnode_p, (void *)(*eastnode_p),
            east_node_type_tab[(*eastnode_p)->type], (*eastnode_p)->start.line,
            (*eastnode_p)->start.col, (*eastnode_p)->len);
  }
}

REAL_FATTR_UNUSED
static inline void viml_pexpr_debug_print_ast_stack(
    const ExprASTStack *const ast_stack,
    const char *const msg)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_ALWAYS_INLINE
{
  fprintf(stderr, "\n%sstack: %zu:\n", msg, kv_size(*ast_stack));
  for (size_t i = 0; i < kv_size(*ast_stack); i++) {
    viml_pexpr_debug_print_ast_node(
        (const ExprASTNode *const *)kv_A(*ast_stack, i),
        "-");
  }
}

REAL_FATTR_UNUSED
static inline void viml_pexpr_debug_print_token(
    const ParserState *const pstate, const LexExprToken token)
  FUNC_ATTR_ALWAYS_INLINE
{
  fprintf(stderr, "\ntkn: %s\n", viml_pexpr_repr_token(pstate, token, NULL));
}
#define PSTACK(msg) \
    viml_pexpr_debug_print_ast_stack(&ast_stack, #msg)
#define PSTACK_P(msg) \
    viml_pexpr_debug_print_ast_stack(ast_stack, #msg)
#define PNODE_P(eastnode_p, msg) \
    viml_pexpr_debug_print_ast_node((const ExprASTNode *const *)eastnode_p, \
                                    (#msg))
#define PTOKEN(tkn) \
    viml_pexpr_debug_print_token(pstate, tkn)
#endif

const uint8_t node_maxchildren[] = {
  [kExprNodeMissing] = 0,
  [kExprNodeOpMissing] = 2,
  [kExprNodeTernary] = 2,
  [kExprNodeTernaryValue] = 2,
  [kExprNodeRegister] = 0,
  [kExprNodeSubscript] = 2,
  [kExprNodeListLiteral] = 1,
  [kExprNodeUnaryPlus] = 1,
  [kExprNodeBinaryPlus] = 2,
  [kExprNodeNested] = 1,
  [kExprNodeCall] = 2,
  [kExprNodePlainIdentifier] = 0,
  [kExprNodePlainKey] = 0,
  [kExprNodeComplexIdentifier] = 2,
  [kExprNodeUnknownFigure] = 1,
  [kExprNodeLambda] = 2,
  [kExprNodeDictLiteral] = 1,
  [kExprNodeCurlyBracesIdentifier] = 1,
  [kExprNodeComma] = 2,
  [kExprNodeColon] = 2,
  [kExprNodeArrow] = 2,
  [kExprNodeComparison] = 2,
  [kExprNodeConcat] = 2,
  [kExprNodeConcatOrSubscript] = 2,
  [kExprNodeInteger] = 0,
  [kExprNodeFloat] = 0,
  [kExprNodeSingleQuotedString] = 0,
  [kExprNodeDoubleQuotedString] = 0,
  [kExprNodeOr] = 2,
  [kExprNodeAnd] = 2,
  [kExprNodeUnaryMinus] = 1,
  [kExprNodeBinaryMinus] = 2,
  [kExprNodeNot] = 1,
  [kExprNodeMultiplication] = 2,
  [kExprNodeDivision] = 2,
  [kExprNodeMod] = 2,
  [kExprNodeOption] = 0,
  [kExprNodeEnvironment] = 0,
  [kExprNodeAssignment] = 2,
};

/// Free memory occupied by AST
///
/// @param  ast  AST stack to free.
void viml_pexpr_free_ast(ExprAST ast)
{
  ExprASTStack ast_stack;
  kvi_init(ast_stack);
  kvi_push(ast_stack, &ast.root);
  while (kv_size(ast_stack)) {
    ExprASTNode **const cur_node = kv_last(ast_stack);
#ifndef NDEBUG
    // Explicitly check for AST recursiveness.
    for (size_t i = 0 ; i < kv_size(ast_stack) - 1 ; i++) {
      assert(*kv_A(ast_stack, i) != *cur_node);
    }
#endif
    if (*cur_node == NULL) {
      assert(kv_size(ast_stack) == 1);
      kv_drop(ast_stack, 1);
    } else if ((*cur_node)->children != NULL) {
#ifndef NDEBUG
      const uint8_t maxchildren = node_maxchildren[(*cur_node)->type];
      assert(maxchildren > 0);
      assert(maxchildren <= 2);
      assert(maxchildren == 1
             ? (*cur_node)->children->next == NULL
             : ((*cur_node)->children->next == NULL
                || (*cur_node)->children->next->next == NULL));
#endif
      kvi_push(ast_stack, &(*cur_node)->children);
    } else if ((*cur_node)->next != NULL) {
      kvi_push(ast_stack, &(*cur_node)->next);
    } else if (*cur_node != NULL) {
      kv_drop(ast_stack, 1);
      switch ((*cur_node)->type) {
        case kExprNodeDoubleQuotedString:
        case kExprNodeSingleQuotedString: {
          xfree((*cur_node)->data.str.value);
          break;
        }
        case kExprNodeMissing:
        case kExprNodeOpMissing:
        case kExprNodeTernary:
        case kExprNodeTernaryValue:
        case kExprNodeRegister:
        case kExprNodeSubscript:
        case kExprNodeListLiteral:
        case kExprNodeUnaryPlus:
        case kExprNodeBinaryPlus:
        case kExprNodeNested:
        case kExprNodeCall:
        case kExprNodePlainIdentifier:
        case kExprNodePlainKey:
        case kExprNodeComplexIdentifier:
        case kExprNodeUnknownFigure:
        case kExprNodeLambda:
        case kExprNodeDictLiteral:
        case kExprNodeCurlyBracesIdentifier:
        case kExprNodeAssignment:
        case kExprNodeComma:
        case kExprNodeColon:
        case kExprNodeArrow:
        case kExprNodeComparison:
        case kExprNodeConcat:
        case kExprNodeConcatOrSubscript:
        case kExprNodeInteger:
        case kExprNodeFloat:
        case kExprNodeOr:
        case kExprNodeAnd:
        case kExprNodeUnaryMinus:
        case kExprNodeBinaryMinus:
        case kExprNodeNot:
        case kExprNodeMultiplication:
        case kExprNodeDivision:
        case kExprNodeMod:
        case kExprNodeOption:
        case kExprNodeEnvironment: {
          break;
        }
      }
      xfree(*cur_node);
      *cur_node = NULL;
    }
  }
  kvi_destroy(ast_stack);
}

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

static struct {
  ExprOpLvl lvl;
  ExprOpAssociativity ass;
} node_type_to_node_props[] = {
  [kExprNodeMissing] = { kEOpLvlInvalid, kEOpAssNo, },
  [kExprNodeOpMissing] = { kEOpLvlMultiplication, kEOpAssNo },

  [kExprNodeNested] = { kEOpLvlParens, kEOpAssNo },
  // Note: below nodes are kEOpLvlSubscript for “binary operator” itself, but
  //       kEOpLvlParens when it comes to inside the parenthesis.
  [kExprNodeCall] = { kEOpLvlParens, kEOpAssNo },
  [kExprNodeSubscript] = { kEOpLvlParens, kEOpAssNo },

  [kExprNodeUnknownFigure] = { kEOpLvlParens, kEOpAssLeft },
  [kExprNodeLambda] = { kEOpLvlParens, kEOpAssNo },
  [kExprNodeDictLiteral] = { kEOpLvlParens, kEOpAssNo },
  [kExprNodeListLiteral] = { kEOpLvlParens, kEOpAssNo },

  [kExprNodeArrow] = { kEOpLvlArrow, kEOpAssNo },

  // Right associativity for comma because this means easier access to arguments
  // list, etc: for "[a, b, c, d]" you can access "a" in one step if it is
  // represented as "list(comma(a, comma(b, comma(c, d))))" then if it is
  // "list(comma(comma(comma(a, b), c), d))" in which case you will need to
  // traverse all three comma() structures. And with comma operator (including
  // actual comma operator from C which is not present in VimL) nobody cares
  // about associativity, only about order of execution.
  [kExprNodeComma] = { kEOpLvlComma, kEOpAssRight },

  // Colons are not eligible for chaining, so nobody cares about associativity.
  [kExprNodeColon] = { kEOpLvlColon, kEOpAssNo },

  [kExprNodeTernary] = { kEOpLvlTernary, kEOpAssRight },

  [kExprNodeOr] = { kEOpLvlOr, kEOpAssLeft },

  [kExprNodeAnd] = { kEOpLvlAnd, kEOpAssLeft },

  [kExprNodeTernaryValue] = { kEOpLvlTernaryValue, kEOpAssRight },

  [kExprNodeComparison] = { kEOpLvlComparison, kEOpAssRight },

  [kExprNodeBinaryPlus] = { kEOpLvlAddition, kEOpAssLeft },
  [kExprNodeBinaryMinus] = { kEOpLvlAddition, kEOpAssLeft },
  [kExprNodeConcat] = { kEOpLvlAddition, kEOpAssLeft },

  [kExprNodeMultiplication] = { kEOpLvlMultiplication, kEOpAssLeft },
  [kExprNodeDivision] = { kEOpLvlMultiplication, kEOpAssLeft },
  [kExprNodeMod] = { kEOpLvlMultiplication, kEOpAssLeft },

  [kExprNodeUnaryPlus] = { kEOpLvlUnary, kEOpAssNo },
  [kExprNodeUnaryMinus] = { kEOpLvlUnary, kEOpAssNo },
  [kExprNodeNot] = { kEOpLvlUnary, kEOpAssNo },

  [kExprNodeConcatOrSubscript] = { kEOpLvlSubscript, kEOpAssLeft },

  [kExprNodeCurlyBracesIdentifier] = { kEOpLvlComplexIdentifier, kEOpAssLeft },

  [kExprNodeAssignment] = { kEOpLvlAssignment, kEOpAssLeft },

  [kExprNodeComplexIdentifier] = { kEOpLvlValue, kEOpAssLeft },

  [kExprNodePlainIdentifier] = { kEOpLvlValue, kEOpAssNo },
  [kExprNodePlainKey] = { kEOpLvlValue, kEOpAssNo },
  [kExprNodeRegister] = { kEOpLvlValue, kEOpAssNo },
  [kExprNodeInteger] = { kEOpLvlValue, kEOpAssNo },
  [kExprNodeFloat] = { kEOpLvlValue, kEOpAssNo },
  [kExprNodeDoubleQuotedString] = { kEOpLvlValue, kEOpAssNo },
  [kExprNodeSingleQuotedString] = { kEOpLvlValue, kEOpAssNo },
  [kExprNodeOption] = { kEOpLvlValue, kEOpAssNo },
  [kExprNodeEnvironment] = { kEOpLvlValue, kEOpAssNo },
};

/// Get AST node priority level
///
/// Used primary to reduce line length, so keep the name short.
///
/// @param[in]  node  Node to get priority for.
///
/// @return Node priority level.
static inline ExprOpLvl node_lvl(const ExprASTNode node)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_CONST FUNC_ATTR_WARN_UNUSED_RESULT
{
  return node_type_to_node_props[node.type].lvl;
}

/// Get AST node associativity, to be used for operator nodes primary
///
/// Used primary to reduce line length, so keep the name short.
///
/// @param[in]  node  Node to get priority for.
///
/// @return Node associativity.
static inline ExprOpAssociativity node_ass(const ExprASTNode node)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_CONST FUNC_ATTR_WARN_UNUSED_RESULT
{
  return node_type_to_node_props[node.type].ass;
}

/// Handle binary operator
///
/// This function is responsible for handling priority levels as well.
///
/// @param[in]  pstate  Parser state, used for error reporting.
/// @param  ast_stack  AST stack. May be popped of some values and will
///                    definitely receive new ones.
/// @param  bop_node  New node to handle.
/// @param[out]  want_node_p  New value of want_node.
/// @param[out]  ast_err  Location where error is saved, if any.
///
/// @return True if no errors occurred, false otherwise.
static bool viml_pexpr_handle_bop(const ParserState *const pstate,
                                  ExprASTStack *const ast_stack,
                                  ExprASTNode *const bop_node,
                                  ExprASTWantedNode *const want_node_p,
                                  ExprASTError *const ast_err)
  FUNC_ATTR_NONNULL_ALL
{
  bool ret = true;
  ExprASTNode **top_node_p = NULL;
  ExprASTNode *top_node;
  ExprOpLvl top_node_lvl;
  ExprOpAssociativity top_node_ass;
  assert(kv_size(*ast_stack));
  const ExprOpLvl bop_node_lvl = ((bop_node->type == kExprNodeCall
                                   || bop_node->type == kExprNodeSubscript)
                                  ? kEOpLvlSubscript
                                  : node_lvl(*bop_node));
#ifndef NDEBUG
  const ExprOpAssociativity bop_node_ass = (
      (bop_node->type == kExprNodeCall
       || bop_node->type == kExprNodeSubscript)
      ? kEOpAssLeft
      : node_ass(*bop_node));
#endif
  do {
    ExprASTNode **new_top_node_p = kv_last(*ast_stack);
    ExprASTNode *new_top_node = *new_top_node_p;
    assert(new_top_node != NULL);
    const ExprOpLvl new_top_node_lvl = node_lvl(*new_top_node);
    const ExprOpAssociativity new_top_node_ass = node_ass(*new_top_node);
    assert(bop_node_lvl != new_top_node_lvl
           || bop_node_ass == new_top_node_ass);
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
    if (bop_node_lvl == top_node_lvl && top_node_ass == kEOpAssRight) {
      break;
    }
  } while (kv_size(*ast_stack));
  if (top_node_ass == kEOpAssLeft || top_node_lvl != bop_node_lvl) {
    // outer(op(x,y)) -> outer(new_op(op(x,y),*))
    //
    // Before: top_node_p = outer(*), points to op(x,y)
    //         Other stack elements unknown
    //
    // After: top_node_p = outer(*), points to new_op(op(x,y))
    //        &bop_node->children->next = new_op(op(x,y),*), points to NULL
    *top_node_p = bop_node;
    bop_node->children = top_node;
    assert(bop_node->children->next == NULL);
    kvi_push(*ast_stack, top_node_p);
    kvi_push(*ast_stack, &bop_node->children->next);
  } else {
    assert(top_node_lvl == bop_node_lvl && top_node_ass == kEOpAssRight);
    assert(top_node->children != NULL && top_node->children->next != NULL);
    // outer(op(x,y)) -> outer(op(x,new_op(y,*)))
    //
    // Before: top_node_p = outer(*), points to op(x,y)
    //         Other stack elements unknown
    //
    // After: top_node_p = outer(*), points to op(x,new_op(y))
    //        &top_node->children->next = op(x,*), points to new_op(y)
    //        &bop_node->children->next = new_op(y,*), points to NULL
    bop_node->children = top_node->children->next;
    top_node->children->next = bop_node;
    assert(bop_node->children->next == NULL);
    kvi_push(*ast_stack, top_node_p);
    kvi_push(*ast_stack, &top_node->children->next);
    kvi_push(*ast_stack, &bop_node->children->next);
    // TODO(ZyX-I): Make this not error, but treat like Python does
    if (bop_node->type == kExprNodeComparison) {
      east_set_error(pstate, ast_err,
                     _("E15: Operator is not associative: %.*s"),
                     bop_node->start);
      ret = false;
    }
  }
  *want_node_p = kENodeValue;
  return ret;
}

/// ParserPosition literal based on ParserPosition pos with columns shifted
///
/// Function does not check whether resulting position is valid.
///
/// @param[in]  pos  Position to shift.
/// @param[in]  shift  Number of bytes to shift.
///
/// @return Shifted position.
static inline ParserPosition shifted_pos(const ParserPosition pos,
                                         const size_t shift)
  FUNC_ATTR_CONST FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return (ParserPosition) { .line = pos.line, .col = pos.col + shift };
}

/// ParserPosition literal based on ParserPosition pos with specified column
///
/// Function does not check whether remaining position is valid.
///
/// @param[in]  pos  Position to adjust.
/// @param[in]  new_col  New column.
///
/// @return Shifted position.
static inline ParserPosition recol_pos(const ParserPosition pos,
                                       const size_t new_col)
  FUNC_ATTR_CONST FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return (ParserPosition) { .line = pos.line, .col = new_col };
}

/// Get highlight group name
#define HL(g) (is_invalid ? "NvimInvalid" #g : "Nvim" #g)

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
      (cur_node)->start = cur_token.start; \
      (cur_node)->len = cur_token.len; \
    } while (0)

/// Allocate new node and set its position from the current token
///
/// If previous token happened to contain spacing then it will be included.
///
/// @param  cur_node  Variable to save allocated node to.
/// @param  typ  Node type.
#define NEW_NODE_WITH_CUR_POS(cur_node, typ) \
    do { \
      (cur_node) = NEW_NODE(typ); \
      POS_FROM_TOKEN((cur_node), cur_token); \
      if (prev_token.type == kExprLexSpacing) { \
        (cur_node)->start = prev_token.start; \
        (cur_node)->len += prev_token.len; \
      } \
    } while (0)

/// Check whether it is possible to have next expression after current
///
/// For :echo: `:echo @a @a` is a valid expression. `:echo (@a @a)` is not.
#define MAY_HAVE_NEXT_EXPR \
    (kv_size(ast_stack) == 1)

/// Add operator node
///
/// @param[in]  cur_node  Node to add.
#define ADD_OP_NODE(cur_node) \
    is_invalid |= !viml_pexpr_handle_bop(pstate, &ast_stack, cur_node, \
                                         &want_node, &ast.err)

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
        ADD_OP_NODE(cur_node); \
        goto viml_pexpr_parse_process_token; \
      } \
    } while (0)

/// Record missing value: for things like "* 5"
///
/// @param[in]  msg  Error message.
#define ADD_VALUE_IF_MISSING(msg) \
        do { \
          if (want_node == kENodeValue) { \
            ERROR_FROM_TOKEN_AND_MSG(cur_token, (msg)); \
            NEW_NODE_WITH_CUR_POS((*top_node_p), kExprNodeMissing); \
            (*top_node_p)->len = 0; \
            want_node = kENodeOperator; \
          } \
        } while (0)

/// Set AST error, unless AST already is not correct
///
/// @param[out]  ret_ast  AST to set error in.
/// @param[in]  pstate  Parser state, used to get error message argument.
/// @param[in]  msg  Error message, assumed to be already translated and
///                  containing a single %token "%.*s".
/// @param[in]  start  Position at which error occurred.
static inline void east_set_error(const ParserState *const pstate,
                                  ExprASTError *const ret_ast_err,
                                  const char *const msg,
                                  const ParserPosition start)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_ALWAYS_INLINE
{
  if (ret_ast_err->msg != NULL) {
    return;
  }
  const ParserLine pline = pstate->reader.lines.items[start.line];
  ret_ast_err->msg = msg;
  ret_ast_err->arg_len = (int)(pline.size - start.col);
  ret_ast_err->arg = pline.data + start.col;
}

/// Set error from the given token and given message
#define ERROR_FROM_TOKEN_AND_MSG(cur_token, msg) \
    do { \
      is_invalid = true; \
      east_set_error(pstate, &ast.err, msg, cur_token.start); \
    } while (0)

/// Like #ERROR_FROM_TOKEN_AND_MSG, but gets position from a node
#define ERROR_FROM_NODE_AND_MSG(node, msg) \
    do { \
      is_invalid = true; \
      east_set_error(pstate, &ast.err, msg, node->start); \
    } while (0)

/// Set error from the given kExprLexInvalid token
#define ERROR_FROM_TOKEN(cur_token) \
    ERROR_FROM_TOKEN_AND_MSG(cur_token, cur_token.data.err.msg)

/// Select figure brace type, altering highlighting as well if needed
///
/// @param[out]  node  Node to modify type.
/// @param[in]  new_type  New type, one of ExprASTNodeType values without
///                       kExprNode prefix.
/// @param[in]  hl  Corresponding highlighting, passed as an argument to #HL.
#define SELECT_FIGURE_BRACE_TYPE(node, new_type, hl) \
    do { \
      ExprASTNode *const node_ = (node); \
      assert(node_->type == kExprNodeUnknownFigure \
             || node_->type == kExprNode##new_type); \
      node_->type = kExprNode##new_type; \
      if (pstate->colors) { \
        kv_A(*pstate->colors, node_->data.fig.opening_hl_idx).group = \
             HL(hl); \
      } \
    } while (0)

/// Add identifier which should constitute complex identifier node
///
/// This one is to be called only in case want_node is kENodeOperator.
///
/// @param  new_ident_node_code  Code used to create a new identifier node and
///                              update want_node and ast_stack, without
///                              a trailing semicolon.
/// @param  hl  Highlighting name to use, passed as an argument to #HL.
#define ADD_IDENT(new_ident_node_code, hl) \
    do { \
      assert(want_node == kENodeOperator); \
      /* Operator: may only be curly braces name, but only under certain */ \
      /* conditions. */ \
\
      /* First condition is that there is no space before a part of complex */ \
      /* identifier. */ \
      if (prev_token.type == kExprLexSpacing) { \
        OP_MISSING; \
      } \
      switch ((*top_node_p)->type) { \
        /* Second is that previous node is one of the identifiers: */ \
        /* complex, plain, curly braces. */ \
\
        /* TODO(ZyX-I): Extend syntax to allow ${expr}. This is needed to */ \
        /* handle environment variables like those bash uses for */ \
        /* `export -f`: their names consist not only of alphanumeric */ \
        /* characetrs. */ \
        case kExprNodeComplexIdentifier: \
        case kExprNodePlainIdentifier: \
        case kExprNodeCurlyBracesIdentifier: { \
          NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeComplexIdentifier); \
          cur_node->len = 0; \
          cur_node->children = *top_node_p; \
          *top_node_p = cur_node; \
          kvi_push(ast_stack, &cur_node->children->next); \
          ExprASTNode **const new_top_node_p = kv_last(ast_stack); \
          assert(*new_top_node_p == NULL); \
          new_ident_node_code; \
          *new_top_node_p = cur_node; \
          HL_CUR_TOKEN(hl); \
          break; \
        } \
        default: { \
          OP_MISSING; \
          break; \
        } \
      } \
    } while (0)

/// Determine whether given parse type is an assignment
///
/// @param[in]  pt  Checked parse type.
///
/// @return true if parsing an assignment, false otherwise.
static inline bool pt_is_assignment(const ExprASTParseType pt)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_CONST FUNC_ATTR_WARN_UNUSED_RESULT
{
  return (pt == kEPTAssignment || pt == kEPTSingleAssignment);
}

/// Structure used to define “string shifts” necessary to map string
/// highlighting to actual strings.
typedef struct {
  size_t start;  ///< Where special character starts in original string.
  size_t orig_len;  ///< Length of orininal string (e.g. 4 for "\x80").
  size_t act_len;  ///< Length of resulting character(s) (e.g. 1 for "\x80").
  bool escape_not_known;  ///< True if escape sequence in original is not known.
} StringShift;

/// Parse and highlight single- or double-quoted string
///
/// Function is supposed to detect and highlight regular expressions (but does
/// not do now).
///
/// @param[out]  pstate  Parser state which also contains a place where
///                      highlighting is saved.
/// @param[out]  node  Node where string parsing results are saved.
/// @param[in]  token  Token to highlight.
/// @param[in]  ast_stack  Parser AST stack, used to detect whether current
///                        string is a regex.
/// @param[in]  is_invalid  Whether currently processed token is not valid.
static void parse_quoted_string(ParserState *const pstate,
                                ExprASTNode *const node,
                                const LexExprToken token,
                                const ExprASTStack ast_stack,
                                const bool is_invalid)
  FUNC_ATTR_NONNULL_ALL
{
  const ParserLine pline = pstate->reader.lines.items[token.start.line];
  const char *const s = pline.data + token.start.col;
  const char *const e = s + token.len - token.data.str.closed;
  const char *p = s + 1;
  const bool is_double = (token.type == kExprLexDoubleQuotedString);
  size_t size = token.len - token.data.str.closed - 1;
  kvec_withinit_t(StringShift, 16) shifts;
  kvi_init(shifts);
  if (!is_double) {
    viml_parser_highlight(pstate, token.start, 1, HL(SingleQuote));
    while (p < e) {
      const char *const chunk_e = memchr(p, '\'', (size_t)(e - p));
      if (chunk_e == NULL) {
        break;
      }
      size--;
      p = chunk_e + 2;
      if (pstate->colors) {
        kvi_push(shifts, ((StringShift) {
            .start = token.start.col + (size_t)(chunk_e - s),
            .orig_len = 2,
            .act_len = 1,
            .escape_not_known = false,
        }));
      }
    }
    node->data.str.size = size;
    if (size == 0) {
      node->data.str.value = NULL;
    } else {
      char *v_p;
      v_p = node->data.str.value = xmallocz(size);
      p = s + 1;
      while (p < e) {
        const char *const chunk_e = memchr(p, '\'', (size_t)(e - p));
        if (chunk_e == NULL) {
          memcpy(v_p, p, (size_t)(e - p));
          break;
        }
        memcpy(v_p, p, (size_t)(chunk_e - p));
        v_p += (size_t)(chunk_e - p) + 1;
        v_p[-1] = '\'';
        p = chunk_e + 2;
      }
    }
  } else {
    viml_parser_highlight(pstate, token.start, 1, HL(DoubleQuote));
    for (p = s + 1; p < e; p++) {
      if (*p == '\\' && p + 1 < e) {
        p++;
        if (p + 1 == e) {
          size--;
          break;
        }
        switch (*p) {
          // A "\<x>" form occupies at least 4 characters, and produces up to
          // 6 characters: reserve space for 2 extra, but do not compute actual
          // length just now, it would be costy.
          case '<': {
            size += 2;
            break;
          }
          // Hexadecimal, always single byte, but at least three bytes each.
          case 'x': case 'X': {
            size--;
            if (ascii_isxdigit(p[1])) {
              size--;
              if (p + 2 < e && ascii_isxdigit(p[2])) {
                size--;
              }
            }
            break;
          }
          // Unicode
          //
          // \uF takes 1 byte which is 2 bytes less then escape sequence.
          // \uFF: 2 bytes, 2 bytes less.
          // \uFFF: 3 bytes, 2 bytes less.
          // \uFFFF: 3 bytes, 3 bytes less.
          // \UFFFFF: 4 bytes, 3 bytes less.
          // \UFFFFFF: 5 bytes, 3 bytes less.
          // \UFFFFFFF: 6 bytes, 3 bytes less.
          // \U7FFFFFFF: 6 bytes, 4 bytes less.
          case 'u': case 'U': {
            const char *const esc_start = p;
            size_t n = (*p == 'u' ? 4 : 8);
            int nr = 0;
            p++;
            while (p + 1 < e && n-- && ascii_isxdigit(p[1])) {
              p++;
              nr = (nr << 4) + hex2nr(*p);
            }
            // Escape length: (esc_start - 1) points to "\\", esc_start to "u"
            // or "U", p to the byte after last byte. So escape sequence
            // occupies p - (esc_start - 1), but it stands for a utf_char2len
            // bytes.
            size -= (size_t)((p - (esc_start - 1)) - utf_char2len(nr));
            p--;
            break;
          }
          // Octal, always single byte, but at least two bytes each.
          case '0': case '1': case '2': case '3': case '4': case '5': case '6':
          case '7': {
            size--;
            p++;
            if (*p >= '0' && *p <= '7') {
              size--;
              p++;
              if (p < e && *p >= '0' && *p <= '7') {
                size--;
                p++;
              }
            }
            break;
          }
          default: {
            size--;
            break;
          }
        }
      }
    }
    if (size == 0) {
      node->data.str.value = NULL;
      node->data.str.size = 0;
    } else {
      char *v_p;
      v_p = node->data.str.value = xmalloc(size);
      p = s + 1;
      while (p < e) {
        const char *const chunk_e = memchr(p, '\\', (size_t)(e - p));
        if (chunk_e == NULL) {
          memcpy(v_p, p, (size_t)(e - p));
          v_p += e - p;
          break;
        }
        memcpy(v_p, p, (size_t)(chunk_e - p));
        v_p += (size_t)(chunk_e - p);
        p = chunk_e + 1;
        if (p == e) {
          *v_p++ = '\\';
          break;
        }
        bool is_unknown = false;
        const char *const v_p_start = v_p;
        switch (*p) {
#define SINGLE_CHAR_ESC(ch, real_ch) \
          case ch: { \
            *v_p++ = real_ch; \
            p++; \
            break; \
          }
          SINGLE_CHAR_ESC('b', BS)
          SINGLE_CHAR_ESC('e', ESC)
          SINGLE_CHAR_ESC('f', FF)
          SINGLE_CHAR_ESC('n', NL)
          SINGLE_CHAR_ESC('r', CAR)
          SINGLE_CHAR_ESC('t', TAB)
          SINGLE_CHAR_ESC('"', '"')
          SINGLE_CHAR_ESC('\\', '\\')
#undef SINGLE_CHAR_ESC

          // Hexadecimal or unicode.
          case 'X': case 'x': case 'u': case 'U': {
            if (p + 1 < e && ascii_isxdigit(p[1])) {
              size_t n;
              int nr;
              bool is_hex = (*p == 'x' || *p == 'X');

              if (is_hex) {
                n = 2;
              } else if (*p == 'u') {
                n = 4;
              } else {
                n = 8;
              }
              nr = 0;
              while (p + 1 < e && n-- && ascii_isxdigit(p[1])) {
                p++;
                nr = (nr << 4) + hex2nr(*p);
              }
              p++;
              if (is_hex) {
                *v_p++ = (char)nr;
              } else {
                v_p += utf_char2bytes(nr, (char_u *)v_p);
              }
            } else {
              is_unknown = true;
              *v_p++ = *p;
              p++;
            }
            break;
          }
          // Octal: "\1", "\12", "\123".
          case '0': case '1': case '2': case '3': case '4': case '5': case '6':
          case '7': {
            uint8_t ch = (uint8_t)(*p++ - '0');
            if (p < e && *p >= '0' && *p <= '7') {
              ch = (uint8_t)((ch << 3) + *p++ - '0');
              if (p < e && *p >= '0' && *p <= '7') {
                ch = (uint8_t)((ch << 3) + *p++ - '0');
              }
            }
            *v_p++ = (char)ch;
            break;
          }
          // Special key, e.g.: "\<C-W>"
          case '<': {
            const size_t special_len = (
                trans_special((const char_u **)&p, (size_t)(e - p),
                              (char_u *)v_p, true, true));
            if (special_len != 0) {
              v_p += special_len;
            } else {
              is_unknown = true;
              mb_copy_char((const char_u **)&p, (char_u **)&v_p);
            }
            break;
          }
          default: {
            is_unknown = true;
            mb_copy_char((const char_u **)&p, (char_u **)&v_p);
            break;
          }
        }
        if (pstate->colors) {
          kvi_push(shifts, ((StringShift) {
              .start = token.start.col + (size_t)(chunk_e - s),
              .orig_len = (size_t)(p - chunk_e),
              .act_len = (size_t)(v_p - (char *)v_p_start),
              .escape_not_known = is_unknown,
          }));
        }
      }
      node->data.str.size = (size_t)(v_p - node->data.str.value);
    }
  }
  if (pstate->colors) {
    // TODO(ZyX-I): use ast_stack to determine and highlight regular expressions
    // TODO(ZyX-I): use ast_stack to determine and highlight printf format str
    // TODO(ZyX-I): use ast_stack to determine and highlight expression strings
    size_t next_col = token.start.col + 1;
    const char *const body_str = (is_double
                                  ? HL(DoubleQuotedBody)
                                  : HL(SingleQuotedBody));
    const char *const esc_str = (is_double
                                 ? HL(DoubleQuotedEscape)
                                 : HL(SingleQuotedQuote));
    const char *const ukn_esc_str = (is_double
                                     ? HL(DoubleQuotedUnknownEscape)
                                     : HL(SingleQuotedUnknownEscape));
    for (size_t i = 0; i < kv_size(shifts); i++) {
      const StringShift cur_shift = kv_A(shifts, i);
      if (cur_shift.start > next_col) {
        viml_parser_highlight(pstate, recol_pos(token.start, next_col),
                              cur_shift.start - next_col,
                              body_str);
      }
      viml_parser_highlight(pstate, recol_pos(token.start, cur_shift.start),
                            cur_shift.orig_len,
                            (cur_shift.escape_not_known
                             ? ukn_esc_str
                             : esc_str));
      next_col = cur_shift.start + cur_shift.orig_len;
    }
    if (next_col - token.start.col < token.len - token.data.str.closed) {
      viml_parser_highlight(pstate, recol_pos(token.start, next_col),
                            (token.start.col
                             + token.len
                             - token.data.str.closed
                             - next_col),
                            body_str);
    }
  }
  if (token.data.str.closed) {
    if (is_double) {
      viml_parser_highlight(pstate, shifted_pos(token.start, token.len - 1),
                            1, HL(DoubleQuote));
    } else {
      viml_parser_highlight(pstate, shifted_pos(token.start, token.len - 1),
                            1, HL(SingleQuote));
    }
  }
  kvi_destroy(shifts);
}

/// Additional flags to pass to lexer depending on want_node
static const int want_node_to_lexer_flags[] = {
  [kENodeValue] = kELFlagIsNotCmp,
  [kENodeOperator] = kELFlagForbidScope,
};

/// Number of characters to highlight as NumberPrefix depending on the base
static const uint8_t base_to_prefix_length[] = {
  [2] = 2,
  [8] = 1,
  [10] = 0,
  [16] = 2,
};

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
    .err = {
      .msg = NULL,
      .arg_len = 0,
      .arg = NULL,
    },
    .root = NULL,
  };
  // Expression stack contains current branch in AST tree: that is
  // - Stack item 0 contains root of the tree, i.e. &ast->root.
  // - Stack item i points to the previous stack items’ last child.
  //
  // When parser expects “value” node that is something like identifier or "["
  // (list start) last stack item contains NULL. Otherwise last stack item is
  // supposed to contain last “finished” value: e.g. "1" or "+(1, 1)" (node
  // representing "1+1").
  ExprASTStack ast_stack;
  kvi_init(ast_stack);
  kvi_push(ast_stack, &ast.root);
  ExprASTWantedNode want_node = kENodeValue;
  ExprASTParseTypeStack pt_stack;
  kvi_init(pt_stack);
  kvi_push(pt_stack, kEPTExpr);
  if (flags & kExprFlagsParseLet) {
    kvi_push(pt_stack, kEPTAssignment);
  }
  LexExprToken prev_token = { .type = kExprLexMissing };
  bool highlighted_prev_spacing = false;
  // Lambda node, valid when parsing lambda arguments only.
  ExprASTNode *lambda_node = NULL;
  size_t asgn_level = 0;
  do {
    const bool is_concat_or_subscript = (
        want_node == kENodeValue
        && kv_size(ast_stack) > 1
        && (*kv_Z(ast_stack, 1))->type == kExprNodeConcatOrSubscript);
    const int lexer_additional_flags = (
        kELFlagPeek
        | ((flags & kExprFlagsDisallowEOC) ? kELFlagForbidEOC : 0)
        | ((want_node == kENodeValue
            && (kv_size(ast_stack) == 1
                || ((*kv_Z(ast_stack, 1))->type != kExprNodeConcat
                    && ((*kv_Z(ast_stack, 1))->type
                        != kExprNodeConcatOrSubscript))))
           ? kELFlagAllowFloat
           : 0));
    LexExprToken cur_token = viml_pexpr_next_token(
        pstate, want_node_to_lexer_flags[want_node] | lexer_additional_flags);
    if (cur_token.type == kExprLexEOC) {
      break;
    }
    LexExprTokenType tok_type = cur_token.type;
    const bool token_invalid = (tok_type == kExprLexInvalid);
    bool is_invalid = token_invalid;
viml_pexpr_parse_process_token:
    // May use different flags this time.
    cur_token = viml_pexpr_next_token(
        pstate, want_node_to_lexer_flags[want_node] | lexer_additional_flags);
    if (tok_type == kExprLexSpacing) {
      if (is_invalid) {
        HL_CUR_TOKEN(Spacing);
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
    const ParserLine pline = pstate->reader.lines.items[cur_token.start.line];
    ExprASTNode **const top_node_p = kv_last(ast_stack);
    assert(kv_size(ast_stack) >= 1);
    ExprASTNode *cur_node = NULL;
#ifndef NDEBUG
    const bool want_value = (want_node == kENodeValue);
    assert(want_value == (*top_node_p == NULL));
    assert(kv_A(ast_stack, 0) == &ast.root);
    // Check that stack item i + 1 points to stack items’ i *last* child.
    for (size_t i = 0; i + 1 < kv_size(ast_stack); i++) {
      const bool item_null = (want_value && i + 2 == kv_size(ast_stack));
      assert((&(*kv_A(ast_stack, i))->children == kv_A(ast_stack, i + 1)
              && (item_null
                  ? (*kv_A(ast_stack, i))->children == NULL
                  : (*kv_A(ast_stack, i))->children->next == NULL))
             || ((&(*kv_A(ast_stack, i))->children->next
                  == kv_A(ast_stack, i + 1))
                 && (item_null
                     ? (*kv_A(ast_stack, i))->children->next == NULL
                     : (*kv_A(ast_stack, i))->children->next->next == NULL)));
    }
#endif
    // Note: in Vim whether expression "cond?d.a:2" is valid depends both on
    // "cond" and whether "d" is a dictionary: expression is valid if condition
    // is true and "d" is a dictionary (with "a" key or it will complain about
    // missing one, but this is not relevant); if any of the requirements is
    // broken then this thing is parsed as "d . a:2" yielding missing colon
    // error. This parser does not allow such ambiguity, especially because it
    // simply can’t: whether "d" is a dictionary is not known at the parsing
    // time.
    //
    // Here example will always contain a concat with "a:2" sucking colon,
    // making expression invalid both because there is no longer a spare colon
    // for ternary and because concatenating dictionary with anything is not
    // valid. There are more cases when this will make a difference though.
    const bool node_is_key = (
        is_concat_or_subscript
        && (cur_token.type == kExprLexPlainIdentifier
            ? (!cur_token.data.var.autoload
               && cur_token.data.var.scope == kExprVarScopeMissing)
            : (cur_token.type == kExprLexNumber))
        && prev_token.type != kExprLexSpacing);
    if (is_concat_or_subscript && !node_is_key) {
      // Note: in Vim "d. a" (this is the reason behind `prev_token.type !=
      // kExprLexSpacing` part of the condition) as well as any other "d.{expr}"
      // where "{expr}" does not look like a key is invalid whenever "d" happens
      // to be a dictionary. Since parser has no idea whether preceding
      // expression is actually a dictionary it can’t outright reject anything,
      // so it turns kExprNodeConcatOrSubscript into kExprNodeConcat instead,
      // which will yield different errors then Vim does in a number of
      // circumstances, and in any case runtime and not parse time errors.
      (*kv_Z(ast_stack, 1))->type = kExprNodeConcat;
    }
    // Pop some stack pt_stack items in case of misplaced nodes.
    const bool is_single_assignment = kv_last(pt_stack) == kEPTSingleAssignment;
    switch (kv_last(pt_stack)) {
      case kEPTExpr: {
        break;
      }
      case kEPTLambdaArguments: {
        if ((want_node == kENodeOperator
             && tok_type != kExprLexComma
             && tok_type != kExprLexArrow)
            || (want_node == kENodeValue
                && !(cur_token.type == kExprLexPlainIdentifier
                     && cur_token.data.var.scope == kExprVarScopeMissing
                     && !cur_token.data.var.autoload)
                && tok_type != kExprLexArrow)) {
          lambda_node->data.fig.type_guesses.allow_lambda = false;
          if (lambda_node->children != NULL
              && lambda_node->children->type == kExprNodeComma) {
            // If lambda has comma child this means that parser has already seen
            // at least "{arg1,", so node cannot possibly be anything, but
            // lambda.

            // Vim may give E121 or E720 in this case, but it does not look
            // right to have either because both are results of reevaluation
            // possibly-lambda node as a dictionary and here this is not going
            // to happen.
            ERROR_FROM_TOKEN_AND_MSG(
                cur_token,
                _("E15: Expected lambda arguments list or arrow: %.*s"));
          } else {
            // Else it may appear that possibly-lambda node is actually
            // a dictionary or curly-braces-name identifier.
            lambda_node = NULL;
            kv_drop(pt_stack, 1);
          }
        }
        break;
      }
      case kEPTSingleAssignment:
      case kEPTAssignment: {
        if (want_node == kENodeValue
            && tok_type != kExprLexBracket
            && tok_type != kExprLexPlainIdentifier
            && (tok_type != kExprLexFigureBrace || cur_token.data.brc.closing)
            && !(node_is_key && tok_type == kExprLexNumber)
            && tok_type != kExprLexEnv
            && tok_type != kExprLexOption
            && tok_type != kExprLexRegister) {
          ERROR_FROM_TOKEN_AND_MSG(
              cur_token,
              _("E15: Expected value part of assignment lvalue: %.*s"));
          kv_drop(pt_stack, 1);
        } else if (want_node == kENodeOperator
                   && tok_type != kExprLexBracket
                   && (tok_type != kExprLexFigureBrace
                       || cur_token.data.brc.closing)
                   && tok_type != kExprLexDot
                   && (tok_type != kExprLexComma || !is_single_assignment)
                   && tok_type != kExprLexAssignment
                   // Curly brace identifiers: will contain plain identifier or
                   // another curly brace in position where operator is wanted.
                   && !((tok_type == kExprLexPlainIdentifier
                         || (tok_type == kExprLexFigureBrace
                             && !cur_token.data.brc.closing))
                        && prev_token.type != kExprLexSpacing)) {
          if (flags & kExprFlagsMulti && MAY_HAVE_NEXT_EXPR) {
            goto viml_pexpr_parse_end;
          }
          ERROR_FROM_TOKEN_AND_MSG(
              cur_token,
              _("E15: Expected assignment operator or subscript: %.*s"));
          kv_drop(pt_stack, 1);
        }
        assert(kv_size(pt_stack));
        break;
      }
    }
    assert(kv_size(pt_stack));
    const ExprASTParseType cur_pt = kv_last(pt_stack);
    assert(lambda_node == NULL || cur_pt == kEPTLambdaArguments);
    switch (tok_type) {
      case kExprLexMissing:
      case kExprLexSpacing:
      case kExprLexEOC: {
        assert(false);
      }
      case kExprLexInvalid: {
        ERROR_FROM_TOKEN(cur_token);
        tok_type = cur_token.data.err.type;
        goto viml_pexpr_parse_process_token;
      }
      case kExprLexRegister: {
        if (want_node == kENodeOperator) {
          // Register in operator position: e.g. @a @a
          OP_MISSING;
        }
        NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeRegister);
        cur_node->data.reg.name = cur_token.data.reg.name;
        *top_node_p = cur_node;
        want_node = kENodeOperator;
        HL_CUR_TOKEN(Register);
        break;
      }
#define SIMPLE_UB_OP(op) \
      case kExprLex##op: { \
        if (want_node == kENodeValue) { \
          /* Value level: assume unary operator. */ \
          NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeUnary##op); \
          *top_node_p = cur_node; \
          kvi_push(ast_stack, &cur_node->children); \
          HL_CUR_TOKEN(Unary##op); \
        } else { \
          NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeBinary##op); \
          ADD_OP_NODE(cur_node); \
          HL_CUR_TOKEN(Binary##op); \
        } \
        want_node = kENodeValue; \
        break; \
      }
      SIMPLE_UB_OP(Plus)
      SIMPLE_UB_OP(Minus)
#undef SIMPLE_UB_OP
#define SIMPLE_B_OP(op, msg) \
      case kExprLex##op: { \
        ADD_VALUE_IF_MISSING(_("E15: Unexpected " msg ": %.*s")); \
        NEW_NODE_WITH_CUR_POS(cur_node, kExprNode##op); \
        HL_CUR_TOKEN(op); \
        ADD_OP_NODE(cur_node); \
        break; \
      }
      SIMPLE_B_OP(Or, "or operator")
      SIMPLE_B_OP(And, "and operator")
#undef SIMPLE_B_OP
      case kExprLexMultiplication: {
        ADD_VALUE_IF_MISSING(
            _("E15: Unexpected multiplication-like operator: %.*s"));
        switch (cur_token.data.mul.type) {
#define MUL_OP(lex_op_tail, node_op_tail) \
          case kExprLexMul##lex_op_tail: { \
            NEW_NODE_WITH_CUR_POS(cur_node, kExprNode##node_op_tail); \
            HL_CUR_TOKEN(node_op_tail); \
            break; \
          }
          MUL_OP(Mul, Multiplication)
          MUL_OP(Div, Division)
          MUL_OP(Mod, Mod)
#undef MUL_OP
        }
        ADD_OP_NODE(cur_node);
        break;
      }
      case kExprLexOption: {
        if (want_node == kENodeOperator) {
          OP_MISSING;
        }
        NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeOption);
        if (cur_token.type == kExprLexInvalid) {
          assert(cur_token.len == 1
                 || (cur_token.len == 3
                     && pline.data[cur_token.start.col + 2] == ':'));
          cur_node->data.opt.ident = (
              pline.data + cur_token.start.col + cur_token.len);
          cur_node->data.opt.ident_len = 0;
          cur_node->data.opt.scope = (
              cur_token.len == 3
              ? (ExprOptScope)pline.data[cur_token.start.col + 1]
              : kExprOptScopeUnspecified);
        } else {
          cur_node->data.opt.ident = cur_token.data.opt.name;
          cur_node->data.opt.ident_len = cur_token.data.opt.len;
          cur_node->data.opt.scope = cur_token.data.opt.scope;
        }
        *top_node_p = cur_node;
        want_node = kENodeOperator;
        viml_parser_highlight(pstate, cur_token.start, 1, HL(OptionSigil));
        const size_t scope_shift = (
            cur_token.data.opt.scope == kExprOptScopeUnspecified ? 0 : 2);
        if (scope_shift) {
          viml_parser_highlight(pstate, shifted_pos(cur_token.start, 1), 1,
                                HL(OptionScope));
          viml_parser_highlight(pstate, shifted_pos(cur_token.start, 2), 1,
                                HL(OptionScopeDelimiter));
        }
        viml_parser_highlight(
            pstate, shifted_pos(cur_token.start, scope_shift + 1),
            cur_token.len - (scope_shift + 1), HL(OptionName));
        break;
      }
      case kExprLexEnv: {
        if (want_node == kENodeOperator) {
          OP_MISSING;
        }
        NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeEnvironment);
        cur_node->data.env.ident = pline.data + cur_token.start.col + 1;
        cur_node->data.env.ident_len = cur_token.len - 1;
        if (cur_node->data.env.ident_len == 0) {
          ERROR_FROM_TOKEN_AND_MSG(cur_token,
                                   _("E15: Environment variable name missing"));
        }
        *top_node_p = cur_node;
        want_node = kENodeOperator;
        viml_parser_highlight(pstate, cur_token.start, 1, HL(EnvironmentSigil));
        viml_parser_highlight(pstate, shifted_pos(cur_token.start, 1),
                              cur_token.len - 1, HL(EnvironmentName));
        break;
      }
      case kExprLexNot: {
        if (want_node == kENodeOperator) {
          OP_MISSING;
        }
        NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeNot);
        *top_node_p = cur_node;
        kvi_push(ast_stack, &cur_node->children);
        HL_CUR_TOKEN(Not);
        break;
      }
      case kExprLexComparison: {
        ADD_VALUE_IF_MISSING(
            _("E15: Expected value, got comparison operator: %.*s"));
        NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeComparison);
        if (cur_token.type == kExprLexInvalid) {
          cur_node->data.cmp.ccs = kCCStrategyUseOption;
          cur_node->data.cmp.type = kExprCmpEqual;
          cur_node->data.cmp.inv = false;
        } else {
          cur_node->data.cmp.ccs = cur_token.data.cmp.ccs;
          cur_node->data.cmp.type = cur_token.data.cmp.type;
          cur_node->data.cmp.inv = cur_token.data.cmp.inv;
        }
        ADD_OP_NODE(cur_node);
        if (cur_token.data.cmp.ccs != kCCStrategyUseOption) {
          viml_parser_highlight(pstate, cur_token.start, cur_token.len - 1,
                                HL(Comparison));
          viml_parser_highlight(
              pstate, shifted_pos(cur_token.start, cur_token.len - 1), 1,
              HL(ComparisonModifier));
        } else {
          HL_CUR_TOKEN(Comparison);
        }
        want_node = kENodeValue;
        break;
      }
      case kExprLexComma: {
        assert(!(want_node == kENodeValue && cur_pt == kEPTLambdaArguments));
        if (want_node == kENodeValue) {
          // Value level: comma appearing here is not valid.
          // Note: in Vim string(,x) will give E116, this is not the case here.
          ERROR_FROM_TOKEN_AND_MSG(
              cur_token, _("E15: Expected value, got comma: %.*s"));
          NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeMissing);
          cur_node->len = 0;
          *top_node_p = cur_node;
          want_node = kENodeOperator;
        }
        if (cur_pt == kEPTLambdaArguments) {
          assert(lambda_node != NULL);
          assert(lambda_node->data.fig.type_guesses.allow_lambda);
          SELECT_FIGURE_BRACE_TYPE(lambda_node, Lambda, Lambda);
        }
        if (kv_size(ast_stack) < 2) {
          goto viml_pexpr_parse_invalid_comma;
        }
        for (size_t i = 1; i < kv_size(ast_stack); i++) {
          ExprASTNode *const *const eastnode_p =
              (ExprASTNode *const *)kv_Z(ast_stack, i);
          const ExprASTNodeType eastnode_type = (*eastnode_p)->type;
          const ExprOpLvl eastnode_lvl = node_lvl(**eastnode_p);
          if (eastnode_type == kExprNodeLambda) {
            assert(cur_pt == kEPTLambdaArguments
                   && want_node == kENodeOperator);
            break;
          } else if (eastnode_type == kExprNodeDictLiteral
                     || eastnode_type == kExprNodeListLiteral
                     || eastnode_type == kExprNodeCall) {
            break;
          } else if (eastnode_type == kExprNodeComma
                     || eastnode_type == kExprNodeColon
                     || eastnode_lvl > kEOpLvlComma) {
            // Do nothing
          } else {
viml_pexpr_parse_invalid_comma:
            ERROR_FROM_TOKEN_AND_MSG(
                cur_token,
                _("E15: Comma outside of call, lambda or literal: %.*s"));
            break;
          }
          if (i == kv_size(ast_stack) - 1) {
            goto viml_pexpr_parse_invalid_comma;
          }
        }
        NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeComma);
        ADD_OP_NODE(cur_node);
        HL_CUR_TOKEN(Comma);
        break;
      }
#define EXP_VAL_COLON "E15: Expected value, got colon: %.*s"
      case kExprLexColon: {
        bool is_ternary = false;
        if (kv_size(ast_stack) < 2) {
          goto viml_pexpr_parse_invalid_colon;
        }
        bool can_be_ternary = true;
        bool is_subscript = false;
        for (size_t i = 1; i < kv_size(ast_stack); i++) {
          ExprASTNode *const *const eastnode_p =
              (ExprASTNode *const *)kv_Z(ast_stack, i);
          const ExprASTNodeType eastnode_type = (*eastnode_p)->type;
          const ExprOpLvl eastnode_lvl = node_lvl(**eastnode_p);
          STATIC_ASSERT(kEOpLvlTernary > kEOpLvlComma,
                        "Unexpected operator priorities");
          if (can_be_ternary && eastnode_type == kExprNodeTernaryValue
              && !(*eastnode_p)->data.ter.got_colon) {
            kv_drop(ast_stack, i);
            (*eastnode_p)->start = cur_token.start;
            (*eastnode_p)->len = cur_token.len;
            if (prev_token.type == kExprLexSpacing) {
              (*eastnode_p)->start = prev_token.start;
              (*eastnode_p)->len += prev_token.len;
            }
            is_ternary = true;
            (*eastnode_p)->data.ter.got_colon = true;
            ADD_VALUE_IF_MISSING(_(EXP_VAL_COLON));
            assert((*eastnode_p)->children != NULL);
            assert((*eastnode_p)->children->next == NULL);
            kvi_push(ast_stack, &(*eastnode_p)->children->next);
            break;
          } else if (eastnode_type == kExprNodeUnknownFigure) {
            SELECT_FIGURE_BRACE_TYPE(*eastnode_p, DictLiteral, Dict);
            break;
          } else if (eastnode_type == kExprNodeDictLiteral) {
            break;
          } else if (eastnode_type == kExprNodeSubscript) {
            is_subscript = true;
            can_be_ternary = false;
            assert(!is_ternary);
            break;
          } else if (eastnode_type == kExprNodeColon) {
            goto viml_pexpr_parse_invalid_colon;
          } else if (eastnode_lvl >= kEOpLvlTernaryValue) {
            // Do nothing
          } else if (eastnode_lvl >= kEOpLvlComma) {
            can_be_ternary = false;
          } else {
            goto viml_pexpr_parse_invalid_colon;
          }
          if (i == kv_size(ast_stack) - 1) {
            goto viml_pexpr_parse_invalid_colon;
          }
        }
        if (is_subscript) {
          assert(kv_size(ast_stack) > 1);
          // Colon immediately following subscript start: it is empty subscript
          // part like a[:2].
          if (want_node == kENodeValue
              && (*kv_Z(ast_stack, 1))->type == kExprNodeSubscript) {
            NEW_NODE_WITH_CUR_POS(*top_node_p, kExprNodeMissing);
            (*top_node_p)->len = 0;
            want_node = kENodeOperator;
          } else {
            ADD_VALUE_IF_MISSING(_(EXP_VAL_COLON));
          }
          NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeColon);
          ADD_OP_NODE(cur_node);
          HL_CUR_TOKEN(SubscriptColon);
        } else {
          goto viml_pexpr_parse_valid_colon;
viml_pexpr_parse_invalid_colon:
          ERROR_FROM_TOKEN_AND_MSG(
              cur_token,
              _("E15: Colon outside of dictionary or ternary operator: %.*s"));
viml_pexpr_parse_valid_colon:
          ADD_VALUE_IF_MISSING(_(EXP_VAL_COLON));
          if (is_ternary) {
            HL_CUR_TOKEN(TernaryColon);
          } else {
            NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeColon);
            ADD_OP_NODE(cur_node);
            HL_CUR_TOKEN(Colon);
          }
        }
        want_node = kENodeValue;
        break;
      }
#undef EXP_VAL_COLON
      case kExprLexBracket: {
        if (cur_token.data.brc.closing) {
          ExprASTNode **new_top_node_p = NULL;
          // Always drop the topmost value:
          //
          // 1. When want_node != kENodeValue topmost item on stack is
          //    a *finished* left operand, which may as well be "{@a}" which
          //    needs not be finished again.
          // 2. Otherwise it is pointing to NULL what nobody wants.
          kv_drop(ast_stack, 1);
          if (!kv_size(ast_stack)) {
            NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeListLiteral);
            cur_node->len = 0;
            if (want_node != kENodeValue) {
              cur_node->children = *top_node_p;
            }
            *top_node_p = cur_node;
            goto viml_pexpr_parse_bracket_closing_error;
          }
          if (want_node == kENodeValue) {
            // It is OK to want value if
            //
            // 1. It is empty list literal, in which case top node will be
            //    ListLiteral.
            // 2. It is list literal with trailing comma, in which case top node
            //    will be that comma.
            // 3. It is subscript with colon, but without one of the values:
            //    e.g. "a[:]", "a[1:]", top node will be colon in this case.
            if ((*kv_last(ast_stack))->type != kExprNodeListLiteral
                && (*kv_last(ast_stack))->type != kExprNodeComma
                && (*kv_last(ast_stack))->type != kExprNodeColon) {
              ERROR_FROM_TOKEN_AND_MSG(
                  cur_token,
                  _("E15: Expected value, got closing bracket: %.*s"));
            }
          }
          do {
            new_top_node_p = kv_pop(ast_stack);
          } while (kv_size(ast_stack)
                   && (new_top_node_p == NULL
                       || ((*new_top_node_p)->type != kExprNodeListLiteral
                           && (*new_top_node_p)->type != kExprNodeSubscript)));
          ExprASTNode *new_top_node = *new_top_node_p;
          switch (new_top_node->type) {
            case kExprNodeListLiteral: {
              if (pt_is_assignment(cur_pt) && new_top_node->children == NULL) {
                ERROR_FROM_TOKEN_AND_MSG(
                    cur_token, _("E475: Unable to assign to empty list: %.*s"));
              }
              HL_CUR_TOKEN(List);
              break;
            }
            case kExprNodeSubscript: {
              HL_CUR_TOKEN(SubscriptBracket);
              break;
            }
            default: {
viml_pexpr_parse_bracket_closing_error:
              assert(!kv_size(ast_stack));
              ERROR_FROM_TOKEN_AND_MSG(
                  cur_token, _("E15: Unexpected closing figure brace: %.*s"));
              HL_CUR_TOKEN(List);
              break;
            }
          }
          kvi_push(ast_stack, new_top_node_p);
          want_node = kENodeOperator;
          if (kv_size(ast_stack) <= asgn_level) {
            assert(kv_size(ast_stack) == asgn_level);
            asgn_level = 0;
            if (cur_pt == kEPTAssignment) {
              assert(ast.err.msg);
            } else if (cur_pt == kEPTExpr
                       && kv_size(pt_stack) > 1
                       && pt_is_assignment(kv_Z(pt_stack, 1))) {
              kv_drop(pt_stack, 1);
            }
          }
          if (cur_pt == kEPTSingleAssignment && kv_size(ast_stack) == 1) {
            kv_drop(pt_stack, 1);
          }
        } else {
          if (want_node == kENodeValue) {
            // Value means list literal or list assignment.
            NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeListLiteral);
            *top_node_p = cur_node;
            kvi_push(ast_stack, &cur_node->children);
            want_node = kENodeValue;
            if (cur_pt == kEPTAssignment) {
              // Additional assignment parse type allows to easily forbid nested
              // lists.
              kvi_push(pt_stack, kEPTSingleAssignment);
            } else if (cur_pt == kEPTSingleAssignment) {
              ERROR_FROM_TOKEN_AND_MSG(
                  cur_token,
                  _("E475: Nested lists not allowed when assigning: %.*s"));
            }
            HL_CUR_TOKEN(List);
          } else {
            // Operator means subscript, also in assignment. But in assignment
            // subscript may be pretty much any expression, so need to push
            // kEPTExpr.
            if (prev_token.type == kExprLexSpacing) {
              OP_MISSING;
            }
            NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeSubscript);
            ADD_OP_NODE(cur_node);
            HL_CUR_TOKEN(SubscriptBracket);
            if (pt_is_assignment(cur_pt)) {
              assert(want_node == kENodeValue);  // Subtract 1 for NULL at top.
              asgn_level = kv_size(ast_stack) - 1;
              kvi_push(pt_stack, kEPTExpr);
            }
          }
        }
        break;
      }
      case kExprLexFigureBrace: {
        if (cur_token.data.brc.closing) {
          ExprASTNode **new_top_node_p = NULL;
          // Always drop the topmost value:
          //
          // 1. When want_node != kENodeValue topmost item on stack is
          //    a *finished* left operand, which may as well be "{@a}" which
          //    needs not be finished again.
          // 2. Otherwise it is pointing to NULL what nobody wants.
          kv_drop(ast_stack, 1);
          if (!kv_size(ast_stack)) {
            NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeUnknownFigure);
            cur_node->data.fig.type_guesses.allow_lambda = false;
            cur_node->data.fig.type_guesses.allow_dict = false;
            cur_node->data.fig.type_guesses.allow_ident = false;
            cur_node->len = 0;
            if (want_node != kENodeValue) {
              cur_node->children = *top_node_p;
            }
            *top_node_p = cur_node;
            new_top_node_p = top_node_p;
            goto viml_pexpr_parse_figure_brace_closing_error;
          }
          if (want_node == kENodeValue) {
            if ((*kv_last(ast_stack))->type != kExprNodeUnknownFigure
                && (*kv_last(ast_stack))->type != kExprNodeComma) {
              // kv_last being UnknownFigure may occur for empty dictionary
              // literal, while Comma is expected in case of non-empty one.
              ERROR_FROM_TOKEN_AND_MSG(
                  cur_token,
                  _("E15: Expected value, got closing figure brace: %.*s"));
            }
          }
          do {
            new_top_node_p = kv_pop(ast_stack);
          } while (kv_size(ast_stack)
                   && (new_top_node_p == NULL
                       || ((*new_top_node_p)->type != kExprNodeUnknownFigure
                           && (*new_top_node_p)->type != kExprNodeDictLiteral
                           && ((*new_top_node_p)->type
                               != kExprNodeCurlyBracesIdentifier)
                           && (*new_top_node_p)->type != kExprNodeLambda)));
          ExprASTNode *new_top_node = *new_top_node_p;
          switch (new_top_node->type) {
            case kExprNodeUnknownFigure: {
              if (new_top_node->children == NULL) {
                // No children of curly braces node indicates empty dictionary.
                assert(want_node == kENodeValue);
                assert(new_top_node->data.fig.type_guesses.allow_dict);
                SELECT_FIGURE_BRACE_TYPE(new_top_node, DictLiteral, Dict);
                HL_CUR_TOKEN(Dict);
              } else if (new_top_node->data.fig.type_guesses.allow_ident) {
                SELECT_FIGURE_BRACE_TYPE(new_top_node, CurlyBracesIdentifier,
                                         Curly);
                HL_CUR_TOKEN(Curly);
              } else {
                // If by this time type of the node has not already been
                // guessed, but it definitely is not a curly braces name then
                // it is invalid for sure.
                ERROR_FROM_NODE_AND_MSG(
                    new_top_node,
                    _("E15: Don't know what figure brace means: %.*s"));
                if (pstate->colors) {
                  // Will reset to NvimInvalidFigureBrace.
                  kv_A(*pstate->colors,
                       new_top_node->data.fig.opening_hl_idx).group = (
                           HL(FigureBrace));
                }
                HL_CUR_TOKEN(FigureBrace);
              }
              break;
            }
            case kExprNodeDictLiteral: {
              HL_CUR_TOKEN(Dict);
              break;
            }
            case kExprNodeCurlyBracesIdentifier: {
              HL_CUR_TOKEN(Curly);
              break;
            }
            case kExprNodeLambda: {
              HL_CUR_TOKEN(Lambda);
              break;
            }
            default: {
viml_pexpr_parse_figure_brace_closing_error:
              assert(!kv_size(ast_stack));
              ERROR_FROM_TOKEN_AND_MSG(
                  cur_token, _("E15: Unexpected closing figure brace: %.*s"));
              HL_CUR_TOKEN(FigureBrace);
              break;
            }
          }
          kvi_push(ast_stack, new_top_node_p);
          want_node = kENodeOperator;
          if (kv_size(ast_stack) <= asgn_level) {
            assert(kv_size(ast_stack) == asgn_level);
            if (cur_pt == kEPTExpr
                && kv_size(pt_stack) > 1
                && pt_is_assignment(kv_Z(pt_stack, 1))) {
              kv_drop(pt_stack, 1);
              asgn_level = 0;
            }
          }
        } else {
          if (want_node == kENodeValue) {
            HL_CUR_TOKEN(FigureBrace);
            // Value: may be any of lambda, dictionary literal and curly braces
            // name.

            // Though if we are in an assignment this may only be a curly braces
            // name.
            if (pt_is_assignment(cur_pt)) {
              NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeCurlyBracesIdentifier);
              cur_node->data.fig.type_guesses.allow_lambda = false;
              cur_node->data.fig.type_guesses.allow_dict = false;
              cur_node->data.fig.type_guesses.allow_ident = true;
              kvi_push(pt_stack, kEPTExpr);
            } else {
              NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeUnknownFigure);
              cur_node->data.fig.type_guesses.allow_lambda = true;
              cur_node->data.fig.type_guesses.allow_dict = true;
              cur_node->data.fig.type_guesses.allow_ident = true;
            }
            if (pstate->colors) {
              cur_node->data.fig.opening_hl_idx = kv_size(*pstate->colors) - 1;
            }
            *top_node_p = cur_node;
            kvi_push(ast_stack, &cur_node->children);
            kvi_push(pt_stack, kEPTLambdaArguments);
            lambda_node = cur_node;
          } else {
            ADD_IDENT(
                do {
                  NEW_NODE_WITH_CUR_POS(cur_node,
                                        kExprNodeCurlyBracesIdentifier);
                  cur_node->data.fig.opening_hl_idx = kv_size(*pstate->colors);
                  cur_node->data.fig.type_guesses.allow_lambda = false;
                  cur_node->data.fig.type_guesses.allow_dict = false;
                  cur_node->data.fig.type_guesses.allow_ident = true;
                  kvi_push(ast_stack, &cur_node->children);
                  if (pt_is_assignment(cur_pt)) {
                    kvi_push(pt_stack, kEPTExpr);
                  }
                  want_node = kENodeValue;
                } while (0),
                Curly);
          }
          if (pt_is_assignment(cur_pt)
              && !pt_is_assignment(kv_last(pt_stack))) {
            assert(want_node == kENodeValue);  // Subtract 1 for NULL at top.
            asgn_level = kv_size(ast_stack) - 1;
          }
        }
        break;
      }
      case kExprLexArrow: {
        if (cur_pt == kEPTLambdaArguments) {
          kv_drop(pt_stack, 1);
          assert(kv_size(pt_stack));
          if (want_node == kENodeValue) {
            // Wanting value means trailing comma and NULL at the top of the
            // stack.
            kv_drop(ast_stack, 1);
          }
          assert(kv_size(ast_stack) >= 1);
          while ((*kv_last(ast_stack))->type != kExprNodeLambda
                 && (*kv_last(ast_stack))->type != kExprNodeUnknownFigure) {
            kv_drop(ast_stack, 1);
          }
          assert((*kv_last(ast_stack)) == lambda_node);
          SELECT_FIGURE_BRACE_TYPE(lambda_node, Lambda, Lambda);
          NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeArrow);
          if (lambda_node->children == NULL) {
            assert(want_node == kENodeValue);
            lambda_node->children = cur_node;
            kvi_push(ast_stack, &lambda_node->children);
          } else {
            assert(lambda_node->children->next == NULL);
            lambda_node->children->next = cur_node;
            kvi_push(ast_stack, &lambda_node->children->next);
          }
          kvi_push(ast_stack, &cur_node->children);
          lambda_node = NULL;
        } else {
          // Only first branch is valid.
          ADD_VALUE_IF_MISSING(_("E15: Unexpected arrow: %.*s"));
          ERROR_FROM_TOKEN_AND_MSG(
              cur_token, _("E15: Arrow outside of lambda: %.*s"));
          NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeArrow);
          ADD_OP_NODE(cur_node);
        }
        want_node = kENodeValue;
        HL_CUR_TOKEN(Arrow);
        break;
      }
      case kExprLexPlainIdentifier: {
        const ExprVarScope scope = (cur_token.type == kExprLexInvalid
                                    ? kExprVarScopeMissing
                                    : cur_token.data.var.scope);
        if (want_node == kENodeValue) {
          want_node = kENodeOperator;
          NEW_NODE_WITH_CUR_POS(cur_node,
                                (node_is_key
                                 ? kExprNodePlainKey
                                 : kExprNodePlainIdentifier));
          cur_node->data.var.scope = scope;
          const size_t scope_shift = (scope == kExprVarScopeMissing ? 0 : 2);
          cur_node->data.var.ident = (pline.data + cur_token.start.col
                                      + scope_shift);
          cur_node->data.var.ident_len = cur_token.len - scope_shift;
          *top_node_p = cur_node;
          if (scope_shift) {
            assert(!node_is_key);
            viml_parser_highlight(pstate, cur_token.start, 1,
                                  HL(IdentifierScope));
            viml_parser_highlight(pstate, shifted_pos(cur_token.start, 1), 1,
                                  HL(IdentifierScopeDelimiter));
          }
          viml_parser_highlight(pstate, shifted_pos(cur_token.start,
                                                    scope_shift),
                                cur_token.len - scope_shift,
                                (node_is_key
                                 ? HL(IdentifierKey)
                                 : HL(IdentifierName)));
        } else {
          if (scope == kExprVarScopeMissing) {
            ADD_IDENT(
                do {
                  NEW_NODE_WITH_CUR_POS(cur_node, kExprNodePlainIdentifier);
                  cur_node->data.var.scope = scope;
                  cur_node->data.var.ident = pline.data + cur_token.start.col;
                  cur_node->data.var.ident_len = cur_token.len;
                  want_node = kENodeOperator;
                } while (0),
                IdentifierName);
          } else {
            OP_MISSING;
          }
        }
        break;
      }
      case kExprLexNumber: {
        if (want_node != kENodeValue) {
          OP_MISSING;
        }
        if (node_is_key) {
          NEW_NODE_WITH_CUR_POS(cur_node, kExprNodePlainKey);
          cur_node->data.var.ident = pline.data + cur_token.start.col;
          cur_node->data.var.ident_len = cur_token.len;
          HL_CUR_TOKEN(IdentifierKey);
        } else if (cur_token.data.num.is_float) {
          NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeFloat);
          cur_node->data.flt.value = cur_token.data.num.val.floating;
          HL_CUR_TOKEN(Float);
        } else {
          NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeInteger);
          cur_node->data.num.value = cur_token.data.num.val.integer;
          const uint8_t prefix_length = base_to_prefix_length[
              cur_token.data.num.base];
          viml_parser_highlight(pstate, cur_token.start, prefix_length,
                                HL(NumberPrefix));
          viml_parser_highlight(
              pstate, shifted_pos(cur_token.start, prefix_length),
              cur_token.len - prefix_length, HL(Number));
        }
        want_node = kENodeOperator;
        *top_node_p = cur_node;
        break;
      }
      case kExprLexDot: {
        ADD_VALUE_IF_MISSING(_("E15: Unexpected dot: %.*s"));
        if (prev_token.type == kExprLexSpacing) {
          if (cur_pt == kEPTAssignment) {
            ERROR_FROM_TOKEN_AND_MSG(
                cur_token, _("E15: Cannot concatenate in assignments: %.*s"));
          }
          NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeConcat);
          HL_CUR_TOKEN(Concat);
        } else {
          NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeConcatOrSubscript);
          HL_CUR_TOKEN(ConcatOrSubscript);
        }
        ADD_OP_NODE(cur_node);
        break;
      }
      case kExprLexParenthesis: {
        if (cur_token.data.brc.closing) {
          if (want_node == kENodeValue) {
            if (kv_size(ast_stack) > 1) {
              const ExprASTNode *const prev_top_node = *kv_Z(ast_stack, 1);
              if (prev_top_node->type == kExprNodeCall) {
                // Function call without arguments, this is not an error.
                // But further code does not expect NULL nodes.
                kv_drop(ast_stack, 1);
                goto viml_pexpr_parse_no_paren_closing_error;
              }
            }
            ERROR_FROM_TOKEN_AND_MSG(
                cur_token, _("E15: Expected value, got parenthesis: %.*s"));
            NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeMissing);
            cur_node->len = 0;
            *top_node_p = cur_node;
          } else {
            // Always drop the topmost value: when want_node != kENodeValue
            // topmost item on stack is a *finished* left operand, which may as
            // well be "(@a)" which needs not be finished again.
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
            ERROR_FROM_TOKEN_AND_MSG(
                cur_token, _("E15: Unexpected closing parenthesis: %.*s"));
            HL_CUR_TOKEN(NestingParenthesis);
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
          want_node = kENodeOperator;
        } else {
          if (want_node == kENodeValue) {
            NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeNested);
            *top_node_p = cur_node;
            kvi_push(ast_stack, &cur_node->children);
            HL_CUR_TOKEN(NestingParenthesis);
          } else if (want_node == kENodeOperator) {
            if (prev_token.type == kExprLexSpacing) {
              // For some reason "function (args)" is a function call, but
              // "(funcref) (args)" is not. AFAIR this somehow involves
              // compatibility and Bram was commenting that this is
              // intentionally inconsistent and he is not very happy with the
              // situation himself.
              if ((*top_node_p)->type != kExprNodePlainIdentifier
                  && (*top_node_p)->type != kExprNodeComplexIdentifier
                  && (*top_node_p)->type != kExprNodeCurlyBracesIdentifier) {
                OP_MISSING;
              }
            }
            NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeCall);
            ADD_OP_NODE(cur_node);
            HL_CUR_TOKEN(CallingParenthesis);
          } else {
            // Currently it is impossible to reach this.
            assert(false);
          }
          want_node = kENodeValue;
        }
        break;
      }
      case kExprLexQuestion: {
        ADD_VALUE_IF_MISSING(_("E15: Expected value, got question mark: %.*s"));
        NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeTernary);
        ADD_OP_NODE(cur_node);
        HL_CUR_TOKEN(Ternary);
        ExprASTNode *ter_val_node;
        NEW_NODE_WITH_CUR_POS(ter_val_node, kExprNodeTernaryValue);
        ter_val_node->data.ter.got_colon = false;
        assert(cur_node->children != NULL);
        assert(cur_node->children->next == NULL);
        assert(kv_last(ast_stack) == &cur_node->children->next);
        *kv_last(ast_stack) = ter_val_node;
        kvi_push(ast_stack, &ter_val_node->children);
        break;
      }
      case kExprLexDoubleQuotedString:
      case kExprLexSingleQuotedString: {
        const bool is_double = (tok_type == kExprLexDoubleQuotedString);
        if (!cur_token.data.str.closed) {
          // It is weird, but Vim has two identical errors messages with
          // different error numbers: "E114: Missing quote" and
          // "E115: Missing quote".
          ERROR_FROM_TOKEN_AND_MSG(
              cur_token, (is_double
                          ? _("E114: Missing double quote: %.*s")
                          : _("E115: Missing single quote: %.*s")));
        }
        if (want_node == kENodeOperator) {
          OP_MISSING;
        }
        NEW_NODE_WITH_CUR_POS(
            cur_node, (is_double
                       ? kExprNodeDoubleQuotedString
                       : kExprNodeSingleQuotedString));
        *top_node_p = cur_node;
        parse_quoted_string(pstate, cur_node, cur_token, ast_stack, is_invalid);
        want_node = kENodeOperator;
        break;
      }
      case kExprLexAssignment: {
        if (cur_pt == kEPTAssignment) {
          kv_drop(pt_stack, 1);
        } else if (cur_pt == kEPTSingleAssignment) {
          kv_drop(pt_stack, 2);
          ERROR_FROM_TOKEN_AND_MSG(
              cur_token,
              _("E475: Expected closing bracket to end list assignment "
                "lvalue: %.*s"));
        } else {
          ERROR_FROM_TOKEN_AND_MSG(
              cur_token, _("E15: Misplaced assignment: %.*s"));
        }
        assert(kv_size(pt_stack));
        assert(kv_last(pt_stack) == kEPTExpr);
        ADD_VALUE_IF_MISSING(_("E15: Unexpected assignment: %.*s"));
        NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeAssignment);
        cur_node->data.ass.type = cur_token.data.ass.type;
        switch (cur_token.data.ass.type) {
#define HL_ASGN(asgn, hl) \
          case kExprAsgn##asgn: { HL_CUR_TOKEN(hl); break; }
          HL_ASGN(Plain, PlainAssignment)
          HL_ASGN(Add, AssignmentWithAddition)
          HL_ASGN(Subtract, AssignmentWithSubtraction)
          HL_ASGN(Concat, AssignmentWithConcatenation)
#undef HL_ASGN
        }
        ADD_OP_NODE(cur_node);
        break;
      }
    }
viml_pexpr_parse_cycle_end:
    prev_token = cur_token;
    highlighted_prev_spacing = false;
    viml_parser_advance(pstate, cur_token.len);
  } while (true);
viml_pexpr_parse_end:
  assert(kv_size(pt_stack));
  assert(kv_size(ast_stack));
  if (want_node == kENodeValue
      // Blacklist some parse type entries as their presence means better error
      // message in the other branch.
      && kv_last(pt_stack) != kEPTLambdaArguments) {
    east_set_error(pstate, &ast.err, _("E15: Expected value, got EOC: %.*s"),
                   pstate->pos);
  } else if (kv_size(ast_stack) != 1) {
    // Something may be wrong, check whether it really is.

    // Pointer to ast.root must never be dropped, so “!= 1” is expected to be
    // the same as “> 1”.
    assert(kv_size(ast_stack));
    // Topmost stack item must be a *finished* value, so it must not be
    // analyzed. E.g. it may contain an already finished nested expression.
    kv_drop(ast_stack, 1);
    while (ast.err.msg == NULL && kv_size(ast_stack)) {
      const ExprASTNode *const cur_node = (*kv_pop(ast_stack));
      // This should only happen when want_node == kENodeValue.
      assert(cur_node != NULL);
      // TODO(ZyX-I): Rehighlight as invalid?
      switch (cur_node->type) {
        case kExprNodeOpMissing:
        case kExprNodeMissing: {
          // Error should’ve been already reported.
          break;
        }
        case kExprNodeCall: {
          east_set_error(
              pstate, &ast.err,
              _("E116: Missing closing parenthesis for function call: %.*s"),
              cur_node->start);
          break;
        }
        case kExprNodeNested: {
          east_set_error(
              pstate, &ast.err,
              _("E110: Missing closing parenthesis for nested expression"
                ": %.*s"),
              cur_node->start);
          break;
        }
        case kExprNodeListLiteral: {
          // For whatever reason "[1" yields "E696: Missing comma in list" error
          // in Vim while "[1," yields E697.
          east_set_error(
              pstate, &ast.err,
              _("E697: Missing end of List ']': %.*s"),
              cur_node->start);
          break;
        }
        case kExprNodeDictLiteral: {
          // Same problem like with list literal with E722 (missing comma) vs
          // E723, but additionally just "{" yields only E15.
          east_set_error(
              pstate, &ast.err,
              _("E723: Missing end of Dictionary '}': %.*s"),
              cur_node->start);
          break;
        }
        case kExprNodeUnknownFigure: {
          east_set_error(
              pstate, &ast.err,
              _("E15: Missing closing figure brace: %.*s"),
              cur_node->start);
          break;
        }
        case kExprNodeLambda: {
          east_set_error(
              pstate, &ast.err,
              _("E15: Missing closing figure brace for lambda: %.*s"),
              cur_node->start);
          break;
        }
        case kExprNodeCurlyBracesIdentifier: {
          // Until trailing "}" it is impossible to distinguish curly braces
          // identifier and dictionary, so it must not appear in the stack like
          // this.
          assert(false);
        }
        case kExprNodeInteger:
        case kExprNodeFloat:
        case kExprNodeSingleQuotedString:
        case kExprNodeDoubleQuotedString:
        case kExprNodeOption:
        case kExprNodeEnvironment:
        case kExprNodeRegister:
        case kExprNodePlainIdentifier:
        case kExprNodePlainKey: {
          // These are plain values and not containers, for them it should only
          // be possible to show up in the topmost stack element, but it was
          // unconditionally popped at the start.
          assert(false);
        }
        case kExprNodeComma:
        case kExprNodeColon:
        case kExprNodeArrow: {
          // It is actually only valid inside something else, but everything
          // where one of the above is valid requires to be closed and thus is
          // to be caught later.
          break;
        }
        case kExprNodeSubscript:
        case kExprNodeConcatOrSubscript:
        case kExprNodeComplexIdentifier:
        case kExprNodeAssignment:
        case kExprNodeMod:
        case kExprNodeDivision:
        case kExprNodeMultiplication:
        case kExprNodeNot:
        case kExprNodeAnd:
        case kExprNodeOr:
        case kExprNodeConcat:
        case kExprNodeComparison:
        case kExprNodeUnaryMinus:
        case kExprNodeUnaryPlus:
        case kExprNodeBinaryMinus:
        case kExprNodeTernary:
        case kExprNodeBinaryPlus: {
          // It is OK to see these in the stack.
          break;
        }
        case kExprNodeTernaryValue: {
          if (!cur_node->data.ter.got_colon) {
            // Actually Vim throws E109 in more cases.
            east_set_error(
                pstate, &ast.err, _("E109: Missing ':' after '?': %.*s"),
                cur_node->start);
          }
          break;
        }
      }
    }
  }
  kvi_destroy(ast_stack);
  return ast;
}  // NOLINT(readability/fn_size)

#undef NEW_NODE
#undef HL
