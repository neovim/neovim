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

#include "nvim/viml/parser/expressions.h"
#include "nvim/viml/parser/parser.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/parser/expressions.c.generated.h"
#endif

/// Character used as a separator in autoload function/variable names.
#define AUTOLOAD_CHAR '#'

/// Get next token for the VimL expression input
LexExprToken viml_pexpr_next_token(ParserState *const pstate)
  FUNC_ATTR_WARN_UNUSED_RESULT
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
  viml_parser_advance(pstate, ret.len);
  return ret;
}
