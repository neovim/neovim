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
#include "nvim/assert.h"
#include "nvim/lib/kvec.h"

#include "nvim/viml/parser/expressions.h"
#include "nvim/viml/parser/parser.h"

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
  /// Argument: only allows simple argument names.
  kENodeArgument,
  /// Argument separator: only allows commas.
  kENodeArgumentSeparator,
} ExprASTWantedNode;

/// Operator priority level
typedef enum {
  kEOpLvlInvalid = 0,
  kEOpLvlComplexIdentifier,
  kEOpLvlParens,
  kEOpLvlArrow,
  kEOpLvlComma,
  kEOpLvlColon,
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
    case '0': case '1': case '2': case '3': case '4': case '5': case '6':
    case '7': case '8': case '9': {
      ret.data.num.is_float = false;
      CHARREG(kExprLexNumber, ascii_isdigit);
      if (flags & kELFlagAllowFloat) {
        if (pline.size > ret.len + 1
            && pline.data[ret.len] == '.'
            && ascii_isdigit(pline.data[ret.len + 1])) {
          ret.len++;
          ret.data.num.is_float = true;
          CHARREG(kExprLexNumber, ascii_isdigit);
          if (pline.size > ret.len + 1
              && (pline.data[ret.len] == 'e'
                  || pline.data[ret.len] == 'E')
              && ((pline.size > ret.len + 2
                   && (pline.data[ret.len + 1] == '+'
                       || pline.data[ret.len + 1] == '-')
                   && ascii_isdigit(pline.data[ret.len + 2]))
                  || ascii_isdigit(pline.data[ret.len + 1]))) {
            ret.len++;
            if (pline.data[ret.len] == '+' || pline.data[ret.len] == '-') {
              ret.len++;
            }
            CHARREG(kExprLexNumber, ascii_isdigit);
          }
        }
      }
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
      if (!(flags & kELFlagIsNotCmp)
          && ((ret.len == 2 && memcmp(pline.data, "is", 2) == 0)
              || (ret.len == 5 && memcmp(pline.data, "isnot", 5) == 0))) {
        ret.type = kExprLexComparison;
        ret.data.cmp.type = kExprLexCmpIdentical;
        ret.data.cmp.inv = (ret.len == 5);
        GET_CCS(ret, pline);
      // Scope: `s:`, etc.
      } else if (ret.len == 1
                 && pline.size > 1
                 && strchr("sgvbwtla", schar) != NULL
                 && pline.data[ret.len] == ':'
                 && !(flags & kELFlagForbidScope)) {
        ret.len++;
        ret.data.var.scope = schar;
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

#ifdef UNIT_TESTING
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
};

static const char *const eltkn_cmp_type_tab[] = {
  [kExprLexCmpEqual] = "Equal",
  [kExprLexCmpMatches] = "Matches",
  [kExprLexCmpGreater] = "Greater",
  [kExprLexCmpGreaterOrEqual] = "GreaterOrEqual",
  [kExprLexCmpIdentical] = "Identical",
};

static const char *const ccs_tab[] = {
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
  [kExprLexOptUnspecified] = "Unspecified",
  [kExprLexOptGlobal] = "Global",
  [kExprLexOptLocal] = "Local",
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
    TKNARGS(kExprLexRegister, "(name=%s)", intchar2str(token.data.reg.name))
    case kExprLexDoubleQuotedString:
    TKNARGS(kExprLexSingleQuotedString, "(closed=%i)",
            (int)token.data.str.closed)
    TKNARGS(kExprLexOption, "(scope=%s,name=%.*s)",
            eltkn_opt_scope_tab[token.data.opt.scope],
            (int)token.data.opt.len, token.data.opt.name)
    TKNARGS(kExprLexPlainIdentifier, "(scope=%s,autoload=%i)",
            intchar2str(token.data.var.scope), (int)token.data.var.autoload)
    TKNARGS(kExprLexNumber, "(is_float=%i)", (int)token.data.num.is_float)
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
#endif

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
    fprintf(stderr, "%s %p : %p : %c : %zu:%zu:%zu\n",
            prefix, (void *)eastnode_p, (void *)(*eastnode_p),
            (*eastnode_p)->type, (*eastnode_p)->start.line,
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
    viml_pexpr_debug_print_ast_node((const ExprASTNode *const *)ast_stack, #msg)
#define PTOKEN(tkn) \
    viml_pexpr_debug_print_token(pstate, tkn)
#endif

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
// NVimInternalError -> highlight as fg:red/bg:red
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
// NVimColon -> Delimiter
// NVimComma -> Delimiter
// NVimArrow -> Delimiter
//
// NVimLambda -> Delimiter
// NVimDict -> Delimiter
// NVimCurly -> Delimiter
//
// NVimIdentifier -> Identifier
// NVimIdentifierScope -> NVimIdentifier
// NVimIdentifierScopeDelimiter -> NVimIdentifier
//
// NVimFigureBrace -> NVimInternalError
//
// NVimInvalidComma -> NVimInvalidDelimiter
// NVimInvalidSpacing -> NVimInvalid
// NVimInvalidTernaryOperator -> NVimInvalidOperator
// NVimInvalidRegister -> NVimInvalidValue
// NVimInvalidClosingBracket -> NVimInvalidDelimiter
// NVimInvalidSpacing -> NVimInvalid
// NVimInvalidArrow -> NVimInvalidDelimiter
// NVimInvalidLambda -> NVimInvalidDelimiter
// NVimInvalidDict -> NVimInvalidDelimiter
// NVimInvalidCurly -> NVimInvalidDelimiter
// NVimInvalidFigureBrace -> NVimInvalidDelimiter
// NVimInvalidIdentifier -> NVimInvalidValue
// NVimInvalidIdentifierScope -> NVimInvalidValue
// NVimInvalidIdentifierScopeDelimiter -> NVimInvalidValue
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
  kEOpLvlComplexIdentifier,
  kEOpLvlParens,
  kEOpLvlArrow,
  kEOpLvlComma,
  kEOpLvlColon,
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
  // Note: it is kEOpLvlSubscript for “binary operator” itself, but
  //       kEOpLvlParens when it comes to inside the parenthesis.
  [kExprNodeCall] = kEOpLvlParens,

  [kExprNodeUnknownFigure] = kEOpLvlParens,
  [kExprNodeLambda] = kEOpLvlParens,
  [kExprNodeDictLiteral] = kEOpLvlParens,

  [kExprNodeArrow] = kEOpLvlArrow,

  [kExprNodeComma] = kEOpLvlComma,

  [kExprNodeColon] = kEOpLvlColon,

  [kExprNodeTernary] = kEOpLvlTernary,

  [kExprNodeBinaryPlus] = kEOpLvlAddition,

  [kExprNodeUnaryPlus] = kEOpLvlUnary,

  [kExprNodeSubscript] = kEOpLvlSubscript,

  [kExprNodeCurlyBracesIdentifier] = kEOpLvlComplexIdentifier,

  [kExprNodeComplexIdentifier] = kEOpLvlValue,
  [kExprNodePlainIdentifier] = kEOpLvlValue,
  [kExprNodeRegister] = kEOpLvlValue,
  [kExprNodeListLiteral] = kEOpLvlValue,
};

static const ExprOpAssociativity node_type_to_op_ass[] = {
  [kExprNodeMissing] = kEOpAssNo,
  [kExprNodeOpMissing] = kEOpAssNo,

  [kExprNodeNested] = kEOpAssNo,
  [kExprNodeCall] = kEOpAssNo,

  [kExprNodeUnknownFigure] = kEOpAssLeft,
  [kExprNodeLambda] = kEOpAssNo,
  [kExprNodeDictLiteral] = kEOpAssNo,

  // Does not really matter.
  [kExprNodeArrow] = kEOpAssNo,

  [kExprNodeColon] = kEOpAssNo,

  // Right associativity for comma because this means easier access to arguments
  // list, etc: for "[a, b, c, d]" you can access "a" in one step if it is
  // represented as "list(comma(a, comma(b, comma(c, d))))" then if it is
  // "list(comma(comma(comma(a, b), c), d))" in which case you will need to
  // traverse all three comma() structures. And with comma operator (including
  // actual comma operator from C which is not present in VimL) nobody cares
  // about associativity, only about order of execution.
  [kExprNodeComma] = kEOpAssRight,

  [kExprNodeTernary] = kEOpAssNo,

  [kExprNodeBinaryPlus] = kEOpAssLeft,

  [kExprNodeUnaryPlus] = kEOpAssNo,

  [kExprNodeSubscript] = kEOpAssLeft,

  [kExprNodeCurlyBracesIdentifier] = kEOpAssLeft,

  [kExprNodeComplexIdentifier] = kEOpAssLeft,
  [kExprNodePlainIdentifier] = kEOpAssNo,
  [kExprNodeRegister] = kEOpAssNo,
  [kExprNodeListLiteral] = kEOpAssNo,
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
  return node_type_to_op_lvl[node.type];
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
  return node_type_to_op_ass[node.type];
}

/// Handle binary operator
///
/// This function is responsible for handling priority levels as well.
static void viml_pexpr_handle_bop(ExprASTStack *const ast_stack,
                                  ExprASTNode *const bop_node,
                                  ExprASTWantedNode *const want_node_p)
  FUNC_ATTR_NONNULL_ALL
{
  ExprASTNode **top_node_p = NULL;
  ExprASTNode *top_node;
  ExprOpLvl top_node_lvl;
  ExprOpAssociativity top_node_ass;
  assert(kv_size(*ast_stack));
  const ExprOpLvl bop_node_lvl = (bop_node->type == kExprNodeCall
                                  ? kEOpLvlSubscript
                                  : node_lvl(*bop_node));
#ifndef NDEBUG
  const ExprOpAssociativity bop_node_ass = (
      bop_node->type == kExprNodeCall
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
  // FIXME: Handle no associativity
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
  }
  *want_node_p = (*want_node_p == kENodeArgumentSeparator
                  ? kENodeArgument
                  : kENodeValue);
}

/// ParserPosition literal based on ParserPosition pos with columns shifted
///
/// Function does not check whether remaining position is valid.
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
        viml_pexpr_handle_bop(&ast_stack, cur_node, &want_node); \
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
            NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeMissing); \
            cur_node->len = 0; \
            *top_node_p = cur_node; \
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

/// Set error from the given token and given message
#define ERROR_FROM_TOKEN_AND_MSG(cur_token, msg) \
    do { \
      is_invalid = true; \
      east_set_error(&ast, pstate, msg, cur_token.start); \
    } while (0)

/// Like #ERROR_FROM_TOKEN_AND_MSG, but gets position from a node
#define ERROR_FROM_NODE_AND_MSG(node, msg) \
    do { \
      is_invalid = true; \
      east_set_error(&ast, pstate, msg, node->start); \
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
  // 1. *last is NULL if want_node is kExprLexValue. Indicates where expression
  //    is to be put.
  // 2. *last is not NULL otherwise, indicates current expression to be used as
  //    an operator argument.
  ExprASTWantedNode want_node = kENodeValue;
  LexExprToken prev_token = { .type = kExprLexMissing };
  bool highlighted_prev_spacing = false;
  // Lambda node, valid when parsing lambda arguments only.
  ExprASTNode *lambda_node = NULL;
  do {
    const int want_node_to_lexer_flags[] = {
      [kENodeValue] = kELFlagIsNotCmp,
      [kENodeOperator] = kELFlagForbidScope,
      [kENodeArgument] = kELFlagIsNotCmp,
      [kENodeArgumentSeparator] = kELFlagForbidScope,
    };
    // FIXME Determine when (not) to allow floating-point numbers.
    const int lexer_additional_flags = (
        kELFlagPeek
        | ((flags & kExprFlagsDisallowEOC) ? kELFlagForbidEOC : 0));
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
    ExprASTNode *cur_node = NULL;
    assert((want_node == kENodeValue || want_node == kENodeArgument)
           == (*top_node_p == NULL));
    if ((want_node == kENodeArgumentSeparator
         && tok_type != kExprLexComma
         && tok_type != kExprLexArrow)
        || (want_node == kENodeArgument
            && !(tok_type == kExprLexPlainIdentifier
                 && cur_token.data.var.scope == 0
                 && !cur_token.data.var.autoload)
            && tok_type != kExprLexArrow)) {
      lambda_node->data.fig.type_guesses.allow_lambda = false;
      if (lambda_node->children != NULL
          && lambda_node->children->type == kExprNodeComma) {
        // If lambda has comma child this means that parser has already seen at
        // least "{arg1,", so node cannot possibly be anything, but lambda.

        // Vim may give E121 or E720 in this case, but it does not look right to
        // have either because both are results of reevaluation possibly-lambda
        // node as a dictionary and here this is not going to happen.
        ERROR_FROM_TOKEN_AND_MSG(
            cur_token, _("E15: Expected lambda arguments list or arrow: %.*s"));
      } else {
        // Else it may appear that possibly-lambda node is actually a dictionary
        // or curly-braces-name identifier.
        lambda_node = NULL;
        if (want_node == kENodeArgumentSeparator) {
          want_node = kENodeOperator;
        } else {
          want_node = kENodeValue;
        }
      }
    }
    assert(lambda_node == NULL
           || want_node == kENodeArgumentSeparator
           || want_node == kENodeArgument);
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
        if (want_node == kENodeValue) {
          NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeRegister);
          cur_node->data.reg.name = cur_token.data.reg.name;
          *top_node_p = cur_node;
          want_node = kENodeOperator;
          HL_CUR_TOKEN(Register);
        } else {
          // Register in operator position: e.g. @a @a
          OP_MISSING;
        }
        break;
      }
      case kExprLexPlus: {
        if (want_node == kENodeValue) {
          // Value level: assume unary plus
          NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeUnaryPlus);
          *top_node_p = cur_node;
          kvi_push(ast_stack, &cur_node->children);
          HL_CUR_TOKEN(UnaryPlus);
        } else {
          NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeBinaryPlus);
          viml_pexpr_handle_bop(&ast_stack, cur_node, &want_node);
          HL_CUR_TOKEN(BinaryPlus);
        }
        want_node = kENodeValue;
        break;
      }
      case kExprLexComma: {
        assert(want_node != kENodeArgument);
        if (want_node == kENodeValue) {
          // Value level: comma appearing here is not valid.
          // Note: in Vim string(,x) will give E116, this is not the case here.
          ERROR_FROM_TOKEN_AND_MSG(
              cur_token, _("E15: Expected value, got comma: %.*s"));
          NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeMissing);
          cur_node->len = 0;
          *top_node_p = cur_node;
          want_node = (want_node == kENodeArgument
                       ? kENodeArgumentSeparator
                       : kENodeOperator);
        }
        if (want_node == kENodeArgumentSeparator) {
          assert(lambda_node->data.fig.type_guesses.allow_lambda);
          assert(lambda_node != NULL);
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
            assert(want_node == kENodeArgumentSeparator);
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
        viml_pexpr_handle_bop(&ast_stack, cur_node, &want_node);
        HL_CUR_TOKEN(Comma);
        break;
      }
      case kExprLexColon: {
        ADD_VALUE_IF_MISSING(_("E15: Expected value, got colon: %.*s"));
        if (kv_size(ast_stack) < 2) {
          goto viml_pexpr_parse_invalid_colon;
        }
        bool is_ternary = false;
        bool can_be_ternary = true;
        for (size_t i = 1; i < kv_size(ast_stack); i++) {
          ExprASTNode *const *const eastnode_p =
              (ExprASTNode *const *)kv_Z(ast_stack, i);
          const ExprASTNodeType eastnode_type = (*eastnode_p)->type;
          const ExprOpLvl eastnode_lvl = node_lvl(**eastnode_p);
          STATIC_ASSERT(kEOpLvlTernary > kEOpLvlComma,
                        "Unexpected operator priorities");
          if (can_be_ternary && eastnode_lvl == kEOpLvlTernary) {
            assert(eastnode_type == kExprNodeTernary);
            is_ternary = true;
            break;
          } else if (eastnode_type == kExprNodeUnknownFigure) {
            SELECT_FIGURE_BRACE_TYPE(*eastnode_p, DictLiteral, Dict);
            break;
          } else if (eastnode_type == kExprNodeDictLiteral
                     || eastnode_type == kExprNodeComma) {
            break;
          } else if (eastnode_lvl > kEOpLvlTernary) {
            // Do nothing
          } else if (eastnode_lvl > kEOpLvlComma) {
            can_be_ternary = false;
          } else {
viml_pexpr_parse_invalid_colon:
            ERROR_FROM_TOKEN_AND_MSG(
                cur_token,
                _("E15: Colon outside of dictionary or ternary operator: "
                  "%.*s"));
            break;
          }
          if (i == kv_size(ast_stack) - 1) {
            goto viml_pexpr_parse_invalid_colon;
          }
        }
        NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeColon);
        viml_pexpr_handle_bop(&ast_stack, cur_node, &want_node);
        if (is_ternary) {
          HL_CUR_TOKEN(TernaryColon);
        } else {
          HL_CUR_TOKEN(Colon);
        }
        want_node = kENodeValue;
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
          } else {
            if (!kv_size(ast_stack)) {
              new_top_node_p = top_node_p;
              goto viml_pexpr_parse_figure_brace_closing_error;
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

                // Should actually be kENodeArgument, but that was changed
                // earlier.
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
                  // Will reset to NVimInvalidFigureBrace.
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
        } else {
          if (want_node == kENodeValue) {
            HL_CUR_TOKEN(FigureBrace);
            // Value: may be any of lambda, dictionary literal and curly braces
            // name.
            NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeUnknownFigure);
            cur_node->data.fig.type_guesses.allow_lambda = true;
            cur_node->data.fig.type_guesses.allow_dict = true;
            cur_node->data.fig.type_guesses.allow_ident = true;
            if (pstate->colors) {
              cur_node->data.fig.opening_hl_idx = kv_size(*pstate->colors) - 1;
            }
            *top_node_p = cur_node;
            kvi_push(ast_stack, &cur_node->children);
            want_node = kENodeArgument;
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
                  want_node = kENodeValue;
                } while (0),
                Curly);
          }
        }
        break;
      }
      case kExprLexArrow: {
        if (want_node == kENodeArgumentSeparator
            || want_node == kENodeArgument) {
          if (want_node == kENodeArgument) {
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
            assert(want_node == kENodeArgument);
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
          is_invalid = true;
          ADD_VALUE_IF_MISSING(_("E15: Unexpected arrow: %.*s"));
          NEW_NODE_WITH_CUR_POS(cur_node, kExprNodeArrow);
          viml_pexpr_handle_bop(&ast_stack, cur_node, &want_node);
        }
        want_node = kENodeValue;
        HL_CUR_TOKEN(Arrow);
        break;
      }
      case kExprLexPlainIdentifier: {
        if (want_node == kENodeValue || want_node == kENodeArgument) {
          want_node = (want_node == kENodeArgument
                       ? kENodeArgumentSeparator
                       : kENodeOperator);
          NEW_NODE_WITH_CUR_POS(cur_node, kExprNodePlainIdentifier);
          cur_node->data.var.scope = cur_token.data.var.scope;
          const size_t scope_shift = (cur_token.data.var.scope == 0
                                      ? 0
                                      : 2);
          cur_node->data.var.ident = (pline.data + cur_token.start.col
                                      + scope_shift);
          cur_node->data.var.ident_len = cur_token.len - scope_shift;
          *top_node_p = cur_node;
          if (scope_shift) {
            viml_parser_highlight(pstate, cur_token.start, 1,
                                  HL(IdentifierScope));
            viml_parser_highlight(pstate, shifted_pos(cur_token.start, 1), 1,
                                  HL(IdentifierScopeDelimiter));
          }
          if (scope_shift < cur_token.len) {
            viml_parser_highlight(pstate, shifted_pos(cur_token.start,
                                                      scope_shift),
                                  cur_token.len - scope_shift,
                                  HL(Identifier));
          }
        // FIXME: Actually, g{foo}g:foo is valid: "1?g{foo}g:foo" is like
        //        "g{foo}g" and not an error.
        } else {
          if (cur_token.data.var.scope == 0) {
            ADD_IDENT(
                do {
                  NEW_NODE_WITH_CUR_POS(cur_node, kExprNodePlainIdentifier);
                  cur_node->data.var.scope = cur_token.data.var.scope;
                  cur_node->data.var.ident = pline.data + cur_token.start.col;
                  cur_node->data.var.ident_len = cur_token.len;
                  want_node = kENodeOperator;
                } while (0),
                Identifier);
          } else {
            OP_MISSING;
          }
        }
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
            viml_pexpr_handle_bop(&ast_stack, cur_node, &want_node);
            HL_CUR_TOKEN(CallingParenthesis);
          } else {
            // Currently it is impossible to reach this.
            assert(false);
          }
          want_node = kENodeValue;
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
  if (want_node == kENodeValue) {
    east_set_error(&ast, pstate, _("E15: Expected value, got EOC: %.*s"),
                   pstate->pos);
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
      // This should only happen when want_node == kENodeValue.
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
