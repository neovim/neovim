#ifndef NVIM_VIML_TRANSLATOR_TRANSLATOR_C_H
#define NVIM_VIML_TRANSLATOR_TRANSLATOR_C_H
#undef NVIM_VIML_TRANSLATOR_TRANSLATOR_C_H
// ^ Make linter happy. Actual define is placed later.

#define __STDC_LIMIT_MACROS
#define __STDC_FORMAT_MACROS
#include <stdbool.h>
#include <stddef.h>
#include <inttypes.h>
#include <stdint.h>
#include <assert.h>
#include <string.h>
#undef __STDC_LIMIT_MACROS
#undef __STDC_FORMAT_MACROS

#include "nvim/types.h"
#include "nvim/vim.h"
#include "nvim/mbyte.h"
#include "nvim/charset.h"
#include "nvim/keymap.h"
#include "nvim/ascii.h"

#include "nvim/viml/translator/translator.h"
#include "nvim/viml/parser/expressions.h"
#include "nvim/viml/parser/ex_commands.h"
#include "nvim/viml/parser/command_definitions.h"
#include "nvim/viml/dumpers/dumpers.h"

#if !defined(CH_MACROS_DEFINE_LENGTH) && !defined(CH_MACROS_DEFINE_FWRITE)
# define CH_MACROS_DEFINE_LENGTH
# include "nvim/viml/translator/translator.c.h"
# undef CH_MACROS_DEFINE_LENGTH
#elif !defined(CH_MACROS_DEFINE_FWRITE)
# undef CH_MACROS_DEFINE_LENGTH
# define CH_MACROS_DEFINE_FWRITE
# include "nvim/viml/translator/translator.c.h"  // NOLINT
# undef CH_MACROS_DEFINE_FWRITE
# define CH_MACROS_DEFINE_LENGTH
#endif
#define NVIM_VIML_TRANSLATOR_TRANSLATOR_C_H

#ifndef NVIM_VIML_DUMPERS_CH_MACROS
# define CH_MACROS_OPTIONS_TYPE const TranslationContext
# define CH_MACROS_INDENT_STR "  "
#endif
#include "nvim/viml/dumpers/ch_macros.h"

#ifndef NVIM_VIML_TRANSLATOR_TRANSLATOR_C_H_MACROS
#define NVIM_VIML_TRANSLATOR_TRANSLATOR_C_H_MACROS

#define _STRINGIFY(x) #x
#define STRINGIFY(x) _STRINGIFY(x)

// XXX -1 removes space for trailing zero. Note: STRINGIFY(INTMAX_MAX) may
//     return something like "(dddddL)": three or more characters wider then
//     actually needed.
//     +1 is for minus sign.

/// Length of a buffer capable of holding decimal intmax_t representation
///
/// @note Size of the buffer may be actually a few characters off compared to
///       minimum required size.
#define MAXNUMBUFLEN (sizeof(STRINGIFY(INTMAX_MAX)) - 1 + 1)

/// Length of a buffer capable of holding decimal size_t representation
///
/// @note Size of the buffer may be actually a few characters off compared to
///       minimum required size.
#define SIZETBUFLEN  (sizeof(STRINGIFY(SIZE_MAX)) - 1)

/// Same as W_EXPR_POS, but written string is escaped
#define W_EXPR_POS_ESCAPED(s, node) \
    F(dump_string_length, s + node->start, node->end - node->start + 1)

/// Arguments for translating given expression
#define TRANS_EXPR_ARGS(expr) \
    expr->string, expr->node

/// Arguments for translating expression from command node at given index
#define TRANS_NODE_EXPR_ARGS(node, idx) \
    TRANS_EXPR_ARGS(node->args[idx].arg.expr)

/// Get translation context
///
/// See documentation for TranslationSource for more details.
#define TRANSLATION_SOURCE (o.tsrc)

/// Override one TranslationContext value for the given code
#define OVERRIDE_CONTEXT(key, new_val, code) \
    do { \
      TranslationContext o_tmp = o; \
      o_tmp.key = new_val; \
      do { \
        TranslationContext o = o_tmp; \
        code \
      } while (0); \
    } while (0)

/// Override position-related TranslationContext values for the given code
#define OVERRIDE_CONTEXT_POS(new_lnr, new_start_col, new_name, code) \
    do { \
      TranslationContext o_tmp = o; \
      o_tmp.lnr = new_lnr; \
      o_tmp.start_col = new_start_col; \
      o_tmp.name = new_name; \
      do { \
        TranslationContext o = o_tmp; \
        code \
      } while (0); \
    } while (0)

/// Dump position given CommandPosition and name
#define DUMP_CMD_POS(position, name) \
    F(dump_position, position.lnr, position.col, name)


/// Dump vim.err.err call
#define DUMP_ERR_ERR(lnr, col, name, msg) \
    do { \
      WS("vim.err.err(state, "); \
      F(dump_position, lnr, col, name); \
      WS(", true, " #msg ")\n"); \
    } while (0)

/// Dump vim.err.err call given CommandPosition
#define DUMP_ERR_ERR_CMD_POS(position, name, msg) \
    DUMP_ERR_ERR(position.lnr, position.col, name, msg)


#define VIM_ZERO  "0"
#define VIM_FALSE "0"
#define VIM_TRUE  "1"
#define VIM_EMPTY_STRING "''"

typedef struct {
  const CommandNode *node;
  const size_t indent;
} TranslateFuncArgs;

typedef struct {
  size_t idx;
  char *var;
} LetListItemAssArgs;

typedef void (*AnyFunction)(void);

typedef struct {
  LetAssignmentType ass_type;
  const char *lval_s;
  const ExpressionNode *lval_node;
  const size_t lval_start_col;
  const AnyFunction rval_dump;
  const void *rval_dump_cookie;
} LetModAssArgs;

typedef enum {
  kOptDefault = 0,
  kOptLocal,
  kOptGlobal,
} OptionType;

/// Structure passed to all translate_* functions
typedef struct {
  TranslationSource tsrc;    ///< Source of the translation string.
  const char *name;          ///< Name of the command being translated.
  size_t lnr;                ///< Number of the line that is being translated.
  size_t start_col;          ///< Offset of “first” column in the line.
  const char *const *lines;  ///< Dumped code lines.
  bool inloop;               ///< True if inside the loop.
} TranslationContext;

FDEC_TYPEDEF_ALL(AssignmentValueDump, const void *const);

#define trans_special(a, b, c, d) \
    ((size_t) trans_special((const char_u **) a, b, (char_u *) c, d))
#define get_option_properties(a, ...) \
    get_option_properties((const char_u *) a, __VA_ARGS__)
#define mb_ptr2len(s) ((size_t) mb_ptr2len((char_u *) s))
#define mb_char2bytes(n, b) ((size_t) mb_char2bytes(n, (char_u *) b))

#endif  // NVIM_VIML_TRANSLATOR_TRANSLATOR_C_H_MACROS

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/translator/translator.c.h.generated.h"
#endif

/// Dump one character
///
/// @param[in]  c  Dumped character
static FDEC(dump_char, char c)
{
  FUNCTION_START;
  switch ((uint8_t) c) {
#define CHAR(c, s) \
    case c: { \
      WS("\\" s); \
      break; \
    }
    CHAR(NUL,  "000")
    CHAR(1,    "001")
    CHAR(2,    "002")
    CHAR(3,    "003")
    CHAR(4,    "004")
    CHAR(5,    "005")
    CHAR(6,    "006")
    CHAR(BELL, "a")
    CHAR(BS,   "b")
    CHAR(TAB,  "t")
    CHAR(NL,   "n")
    CHAR(11,   "011")
    CHAR(FF,   "f")
    CHAR(CAR,  "r")
    CHAR(14,   "014")
    CHAR(15,   "015")
    CHAR(16,   "016")
    CHAR(17,   "017")
    CHAR(18,   "018")
    CHAR(19,   "019")
    CHAR(20,   "020")
    CHAR(21,   "021")
    CHAR(22,   "022")
    CHAR(23,   "023")
    CHAR(24,   "024")
    CHAR(25,   "025")
    CHAR(26,   "026")
    CHAR(ESC,  "027")
    CHAR(28,   "028")
    CHAR(29,   "029")
    CHAR(30,   "030")
    CHAR(31,   "031")
    CHAR('"',  "\"")
    CHAR('\'', "'")
    CHAR('\\', "\\")
    CHAR(127,   "127")
    CHAR(128,   "128")
    CHAR(129,   "129")
    CHAR(130,   "130")
    CHAR(131,   "131")
    CHAR(132,   "132")
    CHAR(133,   "133")
    CHAR(134,   "134")
    CHAR(135,   "135")
    CHAR(136,   "136")
    CHAR(137,   "137")
    CHAR(138,   "138")
    CHAR(139,   "139")
    CHAR(140,   "140")
    CHAR(141,   "141")
    CHAR(142,   "142")
    CHAR(143,   "143")
    CHAR(144,   "144")
    CHAR(145,   "145")
    CHAR(146,   "146")
    CHAR(147,   "147")
    CHAR(148,   "148")
    CHAR(149,   "149")
    CHAR(150,   "150")
    CHAR(151,   "151")
    CHAR(152,   "152")
    CHAR(153,   "153")
    CHAR(154,   "154")
    CHAR(155,   "155")
    CHAR(156,   "156")
    CHAR(157,   "157")
    CHAR(158,   "158")
    CHAR(159,   "159")
    CHAR(160,   "160")
    CHAR(161,   "161")
    CHAR(162,   "162")
    CHAR(163,   "163")
    CHAR(164,   "164")
    CHAR(165,   "165")
    CHAR(166,   "166")
    CHAR(167,   "167")
    CHAR(168,   "168")
    CHAR(169,   "169")
    CHAR(170,   "170")
    CHAR(171,   "171")
    CHAR(172,   "172")
    CHAR(173,   "173")
    CHAR(174,   "174")
    CHAR(175,   "175")
    CHAR(176,   "176")
    CHAR(177,   "177")
    CHAR(178,   "178")
    CHAR(179,   "179")
    CHAR(180,   "180")
    CHAR(181,   "181")
    CHAR(182,   "182")
    CHAR(183,   "183")
    CHAR(184,   "184")
    CHAR(185,   "185")
    CHAR(186,   "186")
    CHAR(187,   "187")
    CHAR(188,   "188")
    CHAR(189,   "189")
    CHAR(190,   "190")
    CHAR(191,   "191")
    CHAR(192,   "192")
    CHAR(193,   "193")
    CHAR(194,   "194")
    CHAR(195,   "195")
    CHAR(196,   "196")
    CHAR(197,   "197")
    CHAR(198,   "198")
    CHAR(199,   "199")
    CHAR(200,   "200")
    CHAR(201,   "201")
    CHAR(202,   "202")
    CHAR(203,   "203")
    CHAR(204,   "204")
    CHAR(205,   "205")
    CHAR(206,   "206")
    CHAR(207,   "207")
    CHAR(208,   "208")
    CHAR(209,   "209")
    CHAR(210,   "210")
    CHAR(211,   "211")
    CHAR(212,   "212")
    CHAR(213,   "213")
    CHAR(214,   "214")
    CHAR(215,   "215")
    CHAR(216,   "216")
    CHAR(217,   "217")
    CHAR(218,   "218")
    CHAR(219,   "219")
    CHAR(220,   "220")
    CHAR(221,   "221")
    CHAR(222,   "222")
    CHAR(223,   "223")
    CHAR(224,   "224")
    CHAR(225,   "225")
    CHAR(226,   "226")
    CHAR(227,   "227")
    CHAR(228,   "228")
    CHAR(229,   "229")
    CHAR(230,   "230")
    CHAR(231,   "231")
    CHAR(232,   "232")
    CHAR(233,   "233")
    CHAR(234,   "234")
    CHAR(235,   "235")
    CHAR(236,   "236")
    CHAR(237,   "237")
    CHAR(238,   "238")
    CHAR(239,   "239")
    CHAR(240,   "240")
    CHAR(241,   "241")
    CHAR(242,   "242")
    CHAR(243,   "243")
    CHAR(244,   "244")
    CHAR(245,   "245")
    CHAR(246,   "246")
    CHAR(247,   "247")
    CHAR(248,   "248")
    CHAR(249,   "249")
    CHAR(250,   "250")
    CHAR(251,   "251")
    CHAR(252,   "252")
    CHAR(253,   "253")
    CHAR(254,   "254")
    CHAR(255,   "255")
#undef CHAR
    default: {
      W_LEN(&c, 1);
      break;
    }
  }
  FUNCTION_END;
}

/// Dump string that is not a vim String
///
/// Use translate_string to dump vim String (kExpr*String)
///
/// @param[in]  s     String that will be written.
/// @param[in]  size  Length of this string.
static FDEC(dump_string_length, const char *s, size_t size)
{
  FUNCTION_START;
  const char *const e = s + size;
  WS("'");
  for (; s < e; s++) {
    size_t charlen = mb_ptr2len(s);
    if (charlen == 1) {
      F(dump_char, *s);;
    } else {
      W_LEN(s, charlen);;
      s += charlen - 1;
    }
  }
  WS("'");
  FUNCTION_END;
}

/// Dump string that is not a vim String
///
/// Use translate_string to dump vim String (kExpr*String)
///
/// @param[in]  s  NUL-terminated string that will be written.
static FDEC(dump_string, const char *const s)
{
  FUNCTION_START;
  F(dump_string_length, s, STRLEN(s));
  FUNCTION_END;
}

/// Dump boolean value
///
/// Writes true or false depending on its argument
///
/// @param[in]  b  Checked value.
static FDEC(dump_bool, bool b)
{
  FUNCTION_START;
  if (b) {
    WS("true");
  } else {
    WS("false");
  }

  FUNCTION_END;
}

/// Dump position for vim.err.err
///
/// @param[in]  position  Position of error in current file.
/// @param[in]  name      Command name.
static FDEC(dump_position, size_t lnr, size_t col, const char *name)
{
  FUNCTION_START;
  WS("'");
  F_NOOPT(dump_unumber, lnr);
  WS(":");
  F_NOOPT(dump_unumber, col);
  WS(":");
  if (name != NULL) {
    W(name);
  }
  WS("'");
  FUNCTION_END;
}

/// Dump regular expression
///
/// @param[in]  regex  Regular expression that will be dumped.
static FDEC(translate_regex, const Regex *const regex)
{
  FUNCTION_START;
  F(dump_string, regex->string);
  FUNCTION_END;
}

/// Dump address followup
///
/// @param[in]  followup  Address followup that will be dumped.
static FDEC(translate_address_followup, const AddressFollowup *const followup)
{
  FUNCTION_START;
  // FIXME Replace magic numbers with constants
  switch (followup->type) {
    case kAddressFollowupShift: {
      WS("0, ");
      F_NOOPT(dump_number, followup->data.shift);
      break;
    }
    case kAddressFollowupForwardPattern: {
      WS("1, ");
      F(dump_string, followup->data.regex->string);
      break;
    }
    case kAddressFollowupBackwardPattern: {
      WS("2, ");
      F(dump_string, followup->data.regex->string);
      break;
    }
    case kAddressFollowupMissing: {
      assert(false);
    }
  }
  FUNCTION_END;
}

/// Dump Ex command range
///
/// @param[in]  range  Range that will be dumped.
static FDEC(translate_range, const Range *const range)
{
  FUNCTION_START;
  const Range *current_range = range;

  if (current_range->address.type == kAddrMissing) {
    WS("nil");
    FUNCTION_END;
  }

  WS("vim.range.compose(state, ");

  for (;;) {
    AddressFollowup *current_followup = current_range->address.followups;
    size_t followup_number = 0;

    assert(current_range->address.type != kAddrMissing);

    for (;;) {
      WS("vim.range.apply_followup(state, ");
      F(translate_address_followup, current_followup);
      followup_number++;
      current_followup = current_followup->next;
      if (current_followup == NULL) {
        break;
      } else {
        WS(", ");
      }
    }

    switch (current_range->address.type) {
      case kAddrFixed: {
        F_NOOPT(dump_number, current_range->address.data.lnr);;
        break;
      }
      case kAddrEnd: {
        WS("vim.range.last(state)");
        break;
      }
      case kAddrCurrent: {
        WS("vim.range.current(state)");
        break;
      }
      case kAddrMark: {
        WS("vim.range.mark(state, '");
        WC(current_range->address.data.mark);
        WS("')");
        break;
      }
      case kAddrForwardSearch: {
        WS("vim.range.forward_search(state, ");
        F(translate_regex, current_range->address.data.regex);
        WS(")");
        break;
      }
      case kAddrBackwardSearch: {
        WS("vim.range.backward_search(state, ");
        F(translate_regex, current_range->address.data.regex);
        WS(")");
        break;
      }
      case kAddrSubstituteSearch: {
        WS("vim.range.substitute_search(state)");
        break;
      }
      case kAddrForwardPreviousSearch: {
        WS("vim.range.forward_previous_search(state)");
        break;
      }
      case kAddrBackwardPreviousSearch: {
        WS("vim.range.backward_previous_search(state)");
        break;
      }
      case kAddrMissing: {
        assert(false);
      }
    }

    while (followup_number--) {
      WS(")");
    }
    WS(", ");

    F(dump_bool, current_range->setpos);

    current_range = current_range->next;
    if (current_range == NULL) {
      break;
    } else {
      WS(", ");
    }
  }

  WS(")");
  FUNCTION_END;
}

/// Dump Ex command flags
///
/// @param[in]  exflags  Flags to dump.
static FDEC(translate_ex_flags, uint_least8_t exflags)
{
  FUNCTION_START;
  WS("{");
  if (exflags & FLAG_EX_LIST) {
    WS("list=true, ");
  }
  if (exflags & FLAG_EX_LNR) {
    WS("lnr=true, ");
  }
  if (exflags & FLAG_EX_PRINT) {
    WS("print=true, ");
  }
  WS("}");
  FUNCTION_END;
}

/// Dump VimL integer number
///
/// @param[in]  type    Type of the number node being dumped.
/// @param[in]  s       Pointer to first character in dumped number.
/// @param[in]  length  Number length.
static FDEC(translate_number, ExpressionNodeType type, const char *s,
            size_t length)
{
  FUNCTION_START;
  switch (type) {
    case kExprHexNumber:
    case kExprDecimalNumber: {
      W_LEN(s, length);
      break;
    }
    case kExprOctalNumber: {
#define MAXOCTALNUMBUFLEN (sizeof(intmax_t) * 8 / 3 + 1)
#ifdef CH_MACROS_DEFINE_LENGTH
      return MAXOCTALNUMBUFLEN + 1;
#else
      uintmax_t unumber;
      char num_s[MAXOCTALNUMBUFLEN + 1];

      // Ignore leading zeroes
      for (; *s == '0' && length; s++, length--) {
      }

      if (length > (ptrdiff_t) MAXOCTALNUMBUFLEN || length == 0) {
        // Integer overflow is an undefined behavior, but we do not emit any
        // errors for overflow in other arguments, so just write zero
        memcpy(num_s, "0", 2);
      } else {
        memcpy(num_s, s, length);
        num_s[length] = NUL;
      }
      if (sscanf(num_s, "%" PRIoMAX, &unumber) != 1) {
        // TODO(ZyX-I): check errno
        // TODO(ZyX-I): check %n output?
        // TODO(ZyX-I): give error message
#ifdef CH_MACROS_DEFINE_FWRITE
        return FAIL;
#else
        return;
#endif
      }
      F_NOOPT(dump_unumber, unumber);
      break;
#endif
#undef MAXOCTALNUMBUFLEN
    }
    default: {
      assert(false);
    }
  }
  FUNCTION_END;
}

/// Dump VimL string
///
/// @param[in]  type    Type of the string node being dumped.
/// @param[in]  s       Pointer to first character in dumped string.
/// @param[in]  length  String length.
static FDEC(translate_string, ExpressionNodeType type, const char *const s,
            const size_t length)
{
  FUNCTION_START;
  bool can_dump_as_is = true;
  const char *const e = s + length - 1;
  switch (type) {
    case kExprSingleQuotedString: {
      for (const char *curp = s + 1; curp < e; curp++) {
        if (*curp == '\'' || *curp < 0x20 || *curp == '\\') {
          can_dump_as_is = false;
          break;
        }
      }
      if (can_dump_as_is) {
        W_LEN(s, length);
      } else {
        assert(length > 0);

        WS("'");
        for (const char *curp = s + 1; curp < e; curp++) {
          switch (*curp) {
            case '\'': {
              WS("\\'");
              curp++;
              break;
            }
            default: {
              F(dump_char, *curp);
              break;
            }
          }
        }
        WS("'");
        break;
      }
      break;
    }
    case kExprDoubleQuotedString: {
      for (const char *curp = s + 1; curp < e; curp++) {
        if (*curp < 0x20) {
          can_dump_as_is = false;
          break;
        }
        if (*curp == '\\') {
          curp++;
          switch (*curp) {
            case 'r':
            case 'n':
            case 'f':
            case 'b':
            case '\\':
            case '\"':
            // Escaping single quote, "[" and "]" result in the escaped
            // character both in lua and in VimL.
            case '\'':
            case '[':
            case ']': {
              break;
            }
            default: {
              can_dump_as_is = false;
              break;
            }
          }
          if (!can_dump_as_is) {
            break;
          }
        }
      }
      if (can_dump_as_is) {
        W_LEN(s, length);
      } else {
        assert(length > 0);

        WS("\"");
        for (const char *curp = s + 1; curp < e; curp++) {
          switch (*curp) {
            case '\\': {
              curp++;
              switch (*curp) {
                case 'r':
                case 'n':
                case 'f':
                case 'b':
                case '\\':
                case '\"': {
                  W_LEN(curp - 1, 2);
                  break;
                }
                case 'e': {
                  WS("\\027");
                  break;
                }
                case 'x':
                case 'X':
                case 'u':
                case 'U': {
                  if (ascii_isxdigit(curp[1])) {
                    int8_t n;
                    int nr = 0;
                    bool isx = (*curp == 'X' || *curp == 'x');

                    if (isx) {
                      n = 2;
                    } else {
                      n = 4;
                    }

                    while (--n >= 0 && ascii_isxdigit(curp[1])) {
                      curp++;
                      nr = (nr << 4) + hex2nr(*curp);
                    }
                    if (isx || nr < 0x7F) {
                      F(dump_char, (char) nr);
                    } else {
                      char buf[MAX_CHAR_LEN];
                      size_t size;

                      size = mb_char2bytes(nr, buf);
                      W_LEN(buf, size);
                    }
                  } else {
                    W_LEN(curp, 1);
                  }
                  break;
                }
                case '0':
                case '1':
                case '2':
                case '3':
                case '4':
                case '5':
                case '6':
                case '7': {
                  char c;
                  c = (char) (*curp - '0');
                  if ('0' <= curp[1] && curp[1] <= '7') {
                    curp++;
                    c = (char) ((c << 3) + (*curp - '0'));
                    if ('0' <= curp[1] && curp[1] <= '7') {
                      curp++;
                      c = (char) ((c << 3) + (*curp - '0'));
                    }
                  }
                  F(dump_char, c);
                  break;
                }
                case '<': {
                  char buf[MAX_CHAR_LEN * 6];
                  size_t size;

                  size = trans_special(&curp, STRLEN(curp), buf, false);
                  curp--;

                  for (size_t i = 0; i < size; i++) {
                    F(dump_char, buf[i]);
                  }

                  break;
                }
                default: {
                  F(dump_char, *curp);
                  break;
                }
              }
              break;
            }
            default: {
              F(dump_char, *curp);
              break;
            }
          }
        }
        WS("\"");
      }
      break;
    }
    default: {
      assert(false);
    }
  }
  FUNCTION_END;
}

#define TS_LAST_SEGMENT 0x01
#define TS_ONLY_SEGMENT 0x02
#define TS_FUNCCALL     0x04
#define TS_FUNCASSIGN   0x08

/// Dumps scope variable
///
/// @param[in]   s      String that holds original representation of translated
///                     variable name.
/// @param[in]   node   Translated variable name.
/// @param[out]  start  Is set to the start of variable name, just after the
///                     scope. If function failed to detect scope it is set to
///                     NULL.
/// @param[in]   flags  Flags.
/// @parblock
///   Supported flags:
///
///   TS_LAST_SEGMENT
///   :   Determines whether currently dumped segment is the last one: if it is
///       then single character name like "a" may only refer to the variable in
///       the current scope, if it is not it may be a construct like
///       "a{':abc'}" which refers to "a:abc" variable.
///
///   TS_ONLY_SEGMENT
///   :   Determines whether this segment is the only one.
///
///   TS_FUNCCALL
///   :   Use "vim.functions" in place of "state.current_scope" in some cases.
///       Note that vim.call implementation should still be able to use
///       "state.global.user_functions" if appropriate.
///
///   TS_FUNCASSIGN
///   :   Use "state.global.user_functions" in place of "state.current_scope" in
///       some cases.
/// @endparblock
static FDEC(translate_scope,
            const char *const s,
            const ExpressionNode *const node,
            const char **start,
            const uint_least8_t flags)
{
  FUNCTION_START;
  assert(node->type == kExprSimpleVariableName ||
         (node->type == kExprIdentifier && !(flags&TS_ONLY_SEGMENT)));
  if (node->end == node->start) {
    if (!(flags & (TS_LAST_SEGMENT|TS_ONLY_SEGMENT))
        && strchr("svalgtwb", s[node->start]) != NULL) {
      *start = NULL;
    } else {
      *start = &(s[node->start]);
      if ((flags & TS_FUNCCALL) && ASCII_ISLOWER(s[node->start])) {
        WS("vim.functions");
      } else if (flags & (TS_FUNCASSIGN|TS_FUNCCALL)) {
        WS("state.global.user_functions");
      } else {
        WS("state.current_scope");
      }
    }
  } else if (s[node->start +1] == ':') {
    switch (s[node->start]) {
      case 's':
      case 'v':
      case 'a':
      case 'l':
      case 'g': {
        *start = s + node->start + 2;
        WS("state.");
        if (s[node->start] == 'g' || s[node->start] == 'v') {
          WS("global.");
        }
        W_LEN(s + node->start, 1);
        break;
      }
      case 't': {
        *start = s + node->start + 2;
        WS("state.global.tabpage.t");
        break;
      }
      case 'w': {
        *start = s + node->start + 2;
        WS("state.global.window.w");
        break;
      }
      case 'b': {
        *start = s + node->start + 2;
        WS("state.global.buffer.b");
        break;
      }
      default: {
        *start = s + node->start;
        if (flags & (TS_FUNCASSIGN|TS_FUNCCALL)) {
          WS("state.global.user_functions");
        } else {
          WS("state.current_scope");
        }
        break;
      }
    }
  } else {
    bool isfunc = false;

    *start = s + node->start;
    if ((flags & TS_FUNCCALL) && ASCII_ISLOWER(s[node->start])) {
      isfunc = true;
      const char *cs;
      const char *const e = s + node->end;
      for (cs = s + node->start + 1; cs < e; cs++) {
        if (!(ASCII_ISLOWER(*cs) || ascii_isdigit(*cs))) {
          isfunc = false;
          break;
        }
      }
    }
    if (isfunc && !(flags & TS_FUNCASSIGN)) {
      WS("vim.functions");
    } else if (flags & (TS_FUNCASSIGN|TS_FUNCCALL)) {
      WS("state.global.user_functions");
    } else {
      WS("state.current_scope");
    }
  }
  FUNCTION_END;
}

/// Translate subscript child node
///
/// Dumps four or six function arguments: indexed value, its position, index,
/// its position, second index and its position as well. Second index with its
/// position may be absent.
///
/// @param[in]  s     String holding initial expression representation.
/// @param[in]  node  Translated subscript.
static FDEC(translate_subscript,
            const char *const s,
            const ExpressionNode *const node)
  FUNC_ATTR_NONNULL_ALL
{
  FUNCTION_START;
  F(translate_expr_node, s, node, false);
  WS(", ");
  F(dump_position, o.lnr, o.start_col + node->start, o.name);
  WS(", ");
  if (node->next->type == kExprEmptySubscript) {
    WS("0");
  } else {
    F(translate_expr_node, s, node->next, false);
  }
  WS(", ");
  F(dump_position, o.lnr, o.start_col + node->next->start,
    o.name);
  if (node->next->next != NULL) {
    WS(", ");
    if (node->next->next->type == kExprEmptySubscript) {
      WS("-1");
    } else {
      F(translate_expr_node, s, node->next->next, false);
    }
    WS(", ");
    F(dump_position, o.lnr, o.start_col + node->next->next->start, o.name);
  }
  FUNCTION_END;
}

/// Dump parsed VimL expression
///
/// @param[in]  s            String holding initial expression representation.
/// @param[in]  node         Expression being dumped.
/// @param[in]  is_funccall  True if expression is translated for funccall.
static FDEC(translate_expr_node,
            const char *const s,
            const ExpressionNode *const node,
            const bool is_funccall)
{
  FUNCTION_START;
  switch (node->type) {
    case kExprFloat: {
      WS("vim.float:new(state, ");
      W_EXPR_POS(s, node);
      WS(")");
      break;
    }
    case kExprDecimalNumber:
    case kExprOctalNumber:
    case kExprHexNumber: {
      F(translate_number, node->type, s + node->start,
        node->end - node->start + 1);
      break;
    }
    case kExprDoubleQuotedString:
    case kExprSingleQuotedString: {
      F(translate_string, node->type, s + node->start,
        node->end - node->start + 1);
      break;
    }
    case kExprOption: {
      const char *name_start;
      OptionType type;
      uint_least8_t option_properties;
      const char *cs = s + node->start;
      size_t length = node->end - node->start + 1;

      if (length > 2 && cs[1] == ':') {
        assert(*cs == 'g' || *cs == 'l');
        type = (*cs == 'g' ? kOptGlobal : kOptLocal);
        name_start = cs + 2;
        length -= 2;
      } else {
        type = kOptDefault;
        name_start = cs;
      }

      option_properties = get_option_properties(name_start, length);
      // If option is not available in this version of neovim …
      if (option_properties & GOP_DISABLED) {
        // … just dump static value
        switch (option_properties & GOP_TYPE_MASK) {
          case GOP_BOOLEAN: {
            WS(VIM_FALSE);
            break;
          }
          case GOP_NUMERIC: {
            WS(VIM_ZERO);
            break;
          }
          case GOP_STRING: {
            WS(VIM_EMPTY_STRING);
            break;
          }
          default: {
            // Option may only be boolean, string or numeric, not a combination
            // of these
            assert(false);
          }
        }
      } else {
            // Requested global option when there is global value
        if ((type == kOptGlobal && (option_properties & GOP_GLOBAL))
            // Or requested option that has nothing, but global value
            || !((option_properties & GOP_LOCALITY_MASK) ^ GOP_GLOBAL)) {
          WS("state.global.options['");
          W_LEN(name_start, length);
          WS("']");
        } else {
          if (option_properties & GOP_GLOBAL) {
            WS("vim.get_local_option(state, ");
          }

          if (option_properties & GOP_BUFFER_LOCAL) {
            WS("state.global.buffer");
          } else if (option_properties & GOP_WINDOW_LOCAL) {
            WS("state.global.window");
          } else {
            assert(false);
          }

          if (option_properties & GOP_GLOBAL) {
            WS(", ");
          } else {
            WS("[");
          }
          WS("'");
          W_LEN(name_start, length);
          WS("'");
          if (option_properties & GOP_GLOBAL) {
            WS(")");
          } else {
            WS("]");
          }
        }
      }
      break;
    }
    case kExprRegister: {
      WS("state.registers[");
      if (node->end < node->start) {
        WS("nil");
      } else {
        F(dump_string_length, s + node->start, 1);
      }
      WS("]");
      break;
    }
    case kExprEnvironmentVariable: {
      WS("state.environment[");
      W_EXPR_POS_ESCAPED(s, node);
      WS("]");
      break;
    }
    case kExprSimpleVariableName: {
      const char *start;
      WS("vim.subscript.subscript(state, false, ");
      F(translate_scope, s, node, &start, TS_ONLY_SEGMENT | (is_funccall
                                                             ? TS_FUNCCALL
                                                             : 0));
      W(", ");
      F(dump_position, o.lnr, o.start_col + node->start, o.name);
      assert(start != NULL);
      WS(", '");
      W_END(start, s + node->end);
      W("', ");
      F(dump_position, o.lnr, o.start_col + node->start, o.name);
      WS(")");
      break;
    }
    case kExprVariableName: {
      WS("vim.subscript.subscript(state, false, ");
      F(translate_varname, s, node, false);
      WS(")");
      break;
    }
    case kExprCurlyName:
    case kExprIdentifier: {
      // Should have been handled by translate_varname above
      assert(false);
    }
    case kExprConcatOrSubscript: {
      WS("vim.concat_or_subscript(state, ");
      F(dump_bool, is_funccall);
      WS(", ");
      F(translate_expr_node, s, node->children, false);
      WS(", ");
      F(dump_position, o.lnr, o.start_col + node->children->start, o.name);
      WS(", ");
      W_EXPR_POS_ESCAPED(s, node);
      WS(", ");
      F(dump_position, o.lnr, o.start_col + node->start, o.name);
      WS(")");
      break;
    }
    case kExprEmptySubscript: {
      assert(false);
    }
    case kExprExpression: {
      WS("(");
      F(translate_expr_node, s, node->children, false);
      WS(")");
      break;
    }
    case kExprSubscript: {
      if (node->children->next->next == NULL) {
        WS("vim.subscript.subscript(state, ");
        F(dump_bool, is_funccall);
        WS(", ");
      } else {
        WS("vim.subscript.slice(state, ");
      }
      F(translate_subscript, s, node->children);
      WS(")");
      break;
    }
    default: {
      const ExpressionNode *current_node;
      bool reversed = false;
      bool dump_positions = true;

      assert(node->children != NULL
             || node->type == kExprDictionary
             || node->type == kExprList);
      switch (node->type) {
        case kExprDictionary: {
          WS("vim.dict:new(state");
          dump_positions = false;
          break;
        }
        case kExprList: {
          WS("vim.list:new(state");
          dump_positions = false;
          break;
        }

#define OPERATOR(op_type, op) \
        case op_type: { \
          WS("vim." op "(state"); \
          break; \
        }

        OPERATOR(kExprAdd,          "op.add")
        OPERATOR(kExprSubtract,     "op.subtract")
        OPERATOR(kExprDivide,       "op.divide")
        OPERATOR(kExprMultiply,     "op.multiply")
        OPERATOR(kExprModulo,       "op.modulo")
        OPERATOR(kExprCall,         "subscript.call")
        OPERATOR(kExprMinus,        "op.negate")
        OPERATOR(kExprNot,          "op.negate_logical")
        OPERATOR(kExprPlus,         "op.promote_integer")
        OPERATOR(kExprStringConcat, "op.concat")
#undef OPERATOR

#define COMPARISON(forward_type, rev_type, op) \
        case forward_type: \
        case rev_type: { \
          if (node->type == rev_type) { \
            reversed = true; \
            WS("vim.op.negate_logical(state, "); \
          } \
          WS("vim.op." op "(state, "); \
          switch (node->ignore_case) { \
            case kCCStrategyUseOption: { \
              WS("state.global.options.ignorecase"); \
              break; \
            } \
            case kCCStrategyMatchCase: { \
              WS("false"); \
              break; \
            } \
            case kCCStrategyIgnoreCase: { \
              WS("true"); \
              break; \
            } \
          } \
          break; \
        }

        COMPARISON(kExprEquals,    kExprNotEquals,            "equals")
        COMPARISON(kExprIdentical, kExprNotIdentical,         "identical")
        COMPARISON(kExprMatches,   kExprNotMatches,           "matches")
        COMPARISON(kExprGreater,   kExprLessThanOrEqualTo,    "greater")
        COMPARISON(kExprLess,      kExprGreaterThanOrEqualTo, "less")
#undef COMPARISON

        default: {
          assert(false);
        }
      }

      current_node = node->children;
      if (node->type == kExprCall) {
        WS(", ");
        F(translate_expr_node, s, current_node, true);
        if (dump_positions) {
          WS(", ");
          F(dump_position, o.lnr, o.start_col + current_node->start, o.name);
        }
        current_node = current_node->next;
      }
      for (; current_node != NULL; current_node = current_node->next) {
        WS(", ");
        F(translate_expr_node, s, current_node, false);
        if (dump_positions) {
          WS(", ");
          F(dump_position, o.lnr, o.start_col + current_node->start, o.name);
        }
      }
      WS(")");

      if (reversed) {
        WS(")");
      }

      break;
    }
  }
  FUNCTION_END;
}

/// Dump a sequence of VimL expressions (e.g. for :echo 1 2 3)
///
/// @param[in]  s     String holding initial expression representation.
/// @param[in]  node  Pointer to the first expression that will be dumped.
static FDEC(translate_expr_nodes,
            const char *const s,
            const ExpressionNode *const node)
{
  FUNCTION_START;
  const ExpressionNode *current_node = node;

  for (;;) {
    F(translate_expr_node, s, current_node, false);
    current_node = current_node->next;
    if (current_node == NULL) {
      break;
    } else {
      WS(", ");
    }
  }

  FUNCTION_END;
}

/// Dump a VimL function definition
///
/// @param[in]  args  Function node and indentation that was used for function
///                   definition.
static FDEC(translate_function_definition, const TranslateFuncArgs *const args)
{
  FUNCTION_START;
  const char **argnames =
      (const char **) args->node->args[ARG_FUNC_ARGS].arg.ga_strs.ga_data;
  size_t size = (size_t) args->node->args[ARG_FUNC_ARGS].arg.ga_strs.ga_len;
  uint_least32_t flags = args->node->args[ARG_FUNC_FLAGS].arg.flags;
  bool varargs = flags & FLAG_FUNC_VARARGS;
  const Expression *funcname = args->node->args[ARG_FUNC_NAME].arg.expr;
  WS("vim.func:new(state, function(state, self, callee_position, ...)\n");
  if (size) {
    WINDENT(args->indent + 1);
    WS("if select('#', ...) < ");
    F_NOOPT(dump_unumber, (size * 2));
    WS(" then\n");
    WINDENT(args->indent + 2);
    WS("return vim.err.err(state, callee_position, true, "
       "'E119: Not enough arguments for function: %s', ");
    F(dump_string_length, funcname->string, funcname->size);
    WS(")\n");
    WINDENT(args->indent + 1);
    WS("end\n");
  }
  if (!varargs) {
    WINDENT(args->indent + 1);
    WS("if select('#', ...) > ");
    F_NOOPT(dump_unumber, (size * 2));
    WS(" then\n");
    WINDENT(args->indent + 2);
    WS("return vim.err.err(state, select(");
    F_NOOPT(dump_unumber, (size * 2 + 2));
    WS(", ...), true, 'E118: Too many arguments for function: %s', ");
    F(dump_string_length, funcname->string, funcname->size);
    WS(")\n");
    WINDENT(args->indent + 1);
    WS("end\n");
  }
  if (args->node->children != NULL) {
    size_t indent = args->indent + 1;
    // TODO(ZyX-I): dump information about function call
    WINDENT(indent);
    WS("state = vim.state.enter_function(state, self, {}, ");
    F(dump_bool, (bool) (flags & FLAG_FUNC_ABORT));
    WS(")\n");
    if (flags & FLAG_FUNC_ABORT) {
      WINDENT(indent);
      WS("local ok, ret = pcall(function()\n");
      indent++;
    }
    for (size_t i = 0; i < size; i++) {
      WINDENT(indent);
      WS("state.a['");
      W(argnames[i]);
      WS("'] = select(");
      F_NOOPT(dump_unumber, (i*2 + 1));
      WS(", ...)\n");
    }
    if (varargs) {
      WINDENT(indent);
      WS("state.a['000'] = vim.list:new(state)\n");
      WINDENT(indent);
      WS("state.a['0'] = select('#', ...)/2");
      if (size) {
        WS(" - ");
        F_NOOPT(dump_unumber, size);
      }
      WS("\n");
      WINDENT(indent);
      WS("for i = 1,state.a['0'] do\n");
      WINDENT(indent + 1);
      WS("state.a['000'][i] =  select(i*2");
      if (size) {
        WS(" + ");
        F_NOOPT(dump_unumber, (size + 2));
      } else {
        WS(" - 1");
      }
      WS(", ...)\n");
      WINDENT(indent + 1);
      WS("state.a[tostring(i)] = state.a['000'][i]\n");
      WINDENT(indent);
      WS("end\n");
    }
    // TODO(ZyX-I): Assign a:firstline and a:lastline
    // These variables are always present even if function is defined without
    // range modifier.
    OVERRIDE_CONTEXT(tsrc, kTransFunc,
                     F(translate_nodes, args->node->children, indent););
    if (flags & FLAG_FUNC_ABORT) {
      indent--;
      WINDENT(indent);
      WS("end)\n");
      WINDENT(indent);
      WS("if not ok then\n");
      WINDENT(indent + 1);
      WS("return vim.err.process_abort(state, ret)\n");
      WINDENT(indent);
      WS("end\n");
      WINDENT(indent);
      WS("return ret\n");
    }
  } else {
    // Empty function: do not bother creating scope dictionaries, just return
    // zero
    WINDENT(args->indent + 1);
    WS("return " VIM_ZERO "\n");
  }
  WINDENT(args->indent);
  WS("end, ");
  size_t end_col = args->node->next->position.col;
  size_t end_lnr = args->node->next->position.lnr;
  if (end_col == 1) {
    end_lnr--;
    end_col = STRLEN(o.lines[end_lnr - 1]);
  } else {
    end_col--;
  }
  if (args->node->children != NULL) {
    F(dump_position,
      args->node->children->position.lnr,
      args->node->children->position.col,
      NULL);
  } else {
    F(dump_position, end_lnr, end_col, NULL);
  }
  assert(args->node->next && args->node->next->type == kCmdEndfunction);
  WS(", ");
  F(dump_string_length, funcname->string, funcname->size);
  WS(", '");
  for (size_t i = 0; i < size; i++) {
    W(argnames[i]);
    if (i < size || varargs) {
      WS(", ");
    }
  }
  if (varargs) {
    WS("...");
  }
  WS("', {");
  F(dump_bool, (bool) flags&FLAG_FUNC_DICT);
  WS(", ");
  F(dump_bool, (bool) flags&FLAG_FUNC_ABORT);
  WS(", ");
  F(dump_bool, (bool) flags&FLAG_FUNC_RANGE);
  WS("}, ");
  F(dump_position, end_lnr, end_col, NULL);
  WS(")\n");
  FUNCTION_END;
}

/// Translate complex VimL variable name (i.e. name with curly brace expansion)
///
/// Translates to two arguments: scope and variable name in this scope. Must be
/// the last arguments to the outer function because it may translate to one
/// argument: a call of get_scope_and_key which will return two values.
///
/// @note This function is responsible for adding position as well.
///
/// @param[in]  s            String holding initial expression representation.
/// @param[in]  node         Translated variable name. Must be a node with
///                          kExprVariableName type.
/// @param[in]  is_funccall  True if translating name of a called function.
static FDEC(translate_varname,
            const char *const s,
            const ExpressionNode *const node,
            const bool is_funccall)
{
  FUNCTION_START;
  const ExpressionNode *current_node = node->children;
  ExpressionNode new_current_node;
  bool close_parenthesis = false;

  assert(node->type == kExprVariableName);
  assert(current_node != NULL);

  if (current_node->type == kExprIdentifier) {
    const char *start;
    F(translate_scope, s, current_node, &start, (is_funccall
                                                 ? TS_FUNCASSIGN
                                                 : 0));
    if (start == NULL) {
      WS("vim.get_scope_and_key(state");
      close_parenthesis = true;
    } else {
      WS(", ");
      F(dump_position, o.lnr, o.start_col + node->start, o.name);
      const size_t new_start = (size_t) (start - s);
      if (new_start == current_node->start) {
        // Keep present value of current_node
      } else if (new_start <= current_node->end) {
        new_current_node = *current_node;
        new_current_node.start = new_start;
        current_node = &new_current_node;
      } else {
        current_node = current_node->next;
      }
    }
  } else {
    WS("vim.get_scope_and_key(state");
    close_parenthesis = true;
  }
  WS(", vim.op.concat(state");

  for (; current_node != NULL; current_node = current_node->next) {
    WS(", ");
    switch (current_node->type) {
      case kExprIdentifier: {
        WS("'");
        W_EXPR_POS(s, current_node);
        WS("', ");
        break;
      }
      case kExprCurlyName: {
        F(translate_expr_node, s, current_node->children, false);
        WS(", ");
        break;
      }
      default: {
        assert(false);
      }
    }
    F(dump_position, o.lnr, o.start_col + current_node->start, o.name);
  }

  WS(")");

  if (close_parenthesis) {
    WS(", ");
    F(dump_position, o.lnr, o.start_col + node->start, o.name);
    WS(")");
  } else {
    WS(", ");
    F(dump_position, o.lnr, o.start_col + node->children->next->start, o.name);
  }

  FUNCTION_END;
}

/// Translate lvalue into one of vim.assign.* calls
///
/// @note Newline is not written.
///
/// @param[in]  s            String holding initial expression representation.
/// @param[in]  node         Translated expression.
/// @param[in]  is_funccall  True if it translates :function definition.
/// @param[in]  bang         True if function must not be unique when
///                          is_funccall is set and true if errors about missing
///                          values are to be ignored.
/// @param[in]  dump_bang    True if the above value should be dumped. Ignored
///                          if is_funccall is true: in this case it is also
///                          considered true.
/// @param[in]  prefix       Function prefix (check out functions in
///                          `vim.assign` table).
/// @param[in]  dump         Function used to dump value that will be assigned.
///                          When NULL use commands for undefining variable and
///                          function definitions (backs :unlet and
///                          :delfunction).
/// @param[in]  dump_cookie  First argument to the above function.
static FDEC(translate_lval,
            const char *const s,
            const ExpressionNode *const node,
            const bool is_funccall, const bool bang,
            const bool dump_bang, const char *const prefix,
            const FTYPE(AssignmentValueDump) FNAME(dump),
            const void *const dump_cookie)
{
  FUNCTION_START;
#define ADD_CALL(what) \
  do { \
    WS("vim.assign."); \
    W(prefix); \
    if (is_funccall) { \
      WS(what "_function(state, "); \
    } else { \
      WS(what "(state, "); \
    } \
    if (dump_bang || is_funccall) { \
      F(dump_bool, bang); \
      WS(", "); \
    } \
    if (FNAME(dump) != NULL) { \
      F(dump, dump_cookie); \
      WS(", "); \
    } \
  } while (0)
  switch (node->type) {
    case kExprSimpleVariableName: {
      const char *start;
      ADD_CALL("dict");
      F(translate_scope, s, node, &start,
        TS_ONLY_SEGMENT|TS_LAST_SEGMENT|(is_funccall ? TS_FUNCASSIGN : 0));
      assert(start != NULL);
      WS(", ");
      F(dump_position, o.lnr, o.start_col + node->start, o.name);
      WS(", '");
      W_END(start, s + node->end);
      WS("', ");
      F(dump_position, o.lnr, o.start_col + (size_t) (start - s), o.name);
      WS(")");
      break;
    }
    case kExprVariableName: {
      assert(node->children != NULL);

      ADD_CALL("dict");

      F(translate_varname, s, node, is_funccall);

      WS(")");
      break;
    }
    case kExprConcatOrSubscript: {
      ADD_CALL("dict");
      F(translate_expr_node, s, node->children, false);
      WS(", ");
      F(dump_position, o.lnr, o.start_col + node->children->start, o.name);
      WS(", '");
      W_EXPR_POS(s, node);
      WS("', ");
      F(dump_position, o.lnr, o.start_col + node->start, o.name);
      WS(")");
      break;
    }
    case kExprSubscript: {
      if (node->children->next->next == NULL) {
        ADD_CALL("dict");
      } else {
        ADD_CALL("slice");
      }
      F(translate_subscript, s, node->children);
      WS(")");
      break;
    }
    default: {
      assert(false);
    }
  }
#undef ADD_CALL
  FUNCTION_END;
}

/// Helper function that dumps list element
///
/// List is located in indentvar described in args.
///
/// @param[in]  args  Variable name and list index.
static FDEC(translate_let_list_item, const LetListItemAssArgs *const args)
{
  FUNCTION_START;
  W(args->var);
  WS("[");
  F_NOOPT(dump_unumber, args->idx);
  WS(" + 1]");
  FUNCTION_END;
}

/// Helper function that dumps one integer
///
/// @param[in]  unumber  Translated number.
static FDEC(translate_unumber, const void *const unumber)
{
  FUNCTION_START;
  F_NOOPT(dump_unumber, (const uintmax_t) (const uintptr_t) unumber);
  FUNCTION_END;
}

/// Helper function that dumps tail of the list
///
/// List is located in indentvar described in args.
///
/// Indentvar is a variable with name based on indentation level. It is used to
/// make variable name unique in some scope.
///
/// @param[in]  args  Indentvar description and number of first element in
///                   dumped list.
static FDEC(translate_let_list_rest, const LetListItemAssArgs *const args)
{
  FUNCTION_START;
  WS("vim.list.raw_slice_to_end(");
  W(args->var);
  WS(", ");
  F_NOOPT(dump_number, (intmax_t) args->idx);
  WS(")");
  FUNCTION_END;
}

/// Helper functions that dumps expression
///
/// Proxy to translate_expr_node without the second argument.
///
/// @param[in]  expr  Translated expression.
static FDEC(translate_rval_expr, const Expression *const expr)
{
  FUNCTION_START;
  OVERRIDE_CONTEXT(start_col, expr->col,
                   F(translate_expr_node, TRANS_EXPR_ARGS(expr), false););
  FUNCTION_END;
}

static FDEC(dump_ass_op_name, LetAssignmentType ass_type)
{
  FUNCTION_START;
  switch (ass_type) {
    case VAL_LET_ADD: {
      WS("add");
      break;
    }
    case VAL_LET_SUBTRACT: {
      WS("subtract");
      break;
    }
    case VAL_LET_APPEND: {
      WS("concat");
      break;
    }
    default: {
      assert(false);
    }
  }
  FUNCTION_END;
}

static FDEC(translate_modifying_assignment, const LetModAssArgs *args)
{
  FUNCTION_START;
  WS("vim.op.mod_");
  F(dump_ass_op_name, args->ass_type);
  WS("(state, ");
  F(translate_expr_node, args->lval_s, args->lval_node, false);
  WS(", ");
  F(dump_position, o.lnr, o.start_col, o.name);
  WS(", ");
  FTYPE(AssignmentValueDump) FNAME(dump) =
      (FTYPE(AssignmentValueDump)) args->rval_dump;
  F(dump, args->rval_dump_cookie);
  WS(", nil)");
  FUNCTION_END;
}

/// Helper function for dumping NUL-terminated string
///
/// @param[in]  str  Dumped string
static FDEC(dump_raw_string, const char *const str)
{
  FUNCTION_START;
  W(str);
  FUNCTION_END;
}

/// Translate assignment
///
/// @note It is assumed that this function is called with indent for the first
///       line already written.
///
/// @param[in]  lval_expr    Value being assigned to.
/// @param[in]  indent       Current level of indentation.
/// @param[in]  err_line     Line that should be run when error occurred. May be
///                          NULL.
/// @param[in]  dump         Function used to dump value that will be assigned.
/// @param[in]  dump_cookie  First argument to the above function.
/// @param[in]  ass_type     Assignment type.
static FDEC(translate_assignment,
            const Expression *const lval_expr,
            const size_t indent,
            const char *const err_line,
            FTYPE(AssignmentValueDump) FNAME(dump),
            const void *const dump_cookie,
            const LetAssignmentType ass_type)
{
  FUNCTION_START;
#define ADD_ASSIGN(node, indent, dump, dump_cookie)\
  do { \
    const char *s = lval_expr->string; \
    const size_t new_start_col = lval_expr->col; \
    if (err_line != NULL) { \
      WS("if "); \
    } \
    switch (ass_type) { \
      case VAL_LET_ASSIGN: { \
        OVERRIDE_CONTEXT(start_col, new_start_col, { \
          F(translate_lval, s, node, false, false, false, "ass_", dump, \
            dump_cookie); \
        }); \
        break; \
      } \
      case VAL_LET_ADD: \
      case VAL_LET_SUBTRACT: \
      case VAL_LET_APPEND: { \
        const LetModAssArgs new_args = { \
          .ass_type = ass_type, \
          .lval_s = s, \
          .lval_node = node, \
          .lval_start_col = new_start_col, \
          .rval_dump = (AnyFunction) (dump), \
          .rval_dump_cookie = dump_cookie \
        }; \
        OVERRIDE_CONTEXT(start_col, new_args.lval_start_col, { \
          F(translate_lval, new_args.lval_s, new_args.lval_node, false, false, \
            false, "ass_", \
            ((FTYPE(AssignmentValueDump)) \
             &FNAME(translate_modifying_assignment)), \
            (void *) &new_args); \
        }); \
        break; \
      } \
      default: { \
        assert(false); \
      } \
    } \
    if (err_line != NULL) { \
      WS(" == nil then\n"); \
      WINDENT(indent + 1); \
      W(err_line); \
      WS("\n"); \
      WINDENT(indent); \
      WS("end\n"); \
    } else { \
      WS("\n"); \
    } \
  } while (0)
  if (lval_expr->node->type == kExprList) {
    bool has_rest = false;
    size_t val_num = 0;
    const ExpressionNode *current_node;

    WS("do\n");
    WINDENT(indent + 1);
    WS("local rhs = ");
    F(dump, dump_cookie);
    WS("\n");

    current_node = lval_expr->node->children;
    for (; current_node != NULL; current_node = current_node->next) {
      if (current_node->type == kExprListRest) {
        has_rest = true;
      } else {
        val_num++;
      }
    }

    assert(val_num > 0);

    WINDENT(indent + 1);
    WS("if vim.is_list(rhs) then\n");

    WINDENT(indent + 2);
    WS("if rhs.length");
    if (has_rest) {
      WS(" >= ");
    } else {
      WS(" == ");
    }
    F_NOOPT(dump_unumber, val_num);
    WS(" then\n");

    current_node = lval_expr->node->children;
    for (size_t i = 0; i < val_num; i++) {
      LetListItemAssArgs args = {
        i,
        "rhs"
      };
      WINDENT(indent + 3);
      ADD_ASSIGN(current_node, indent + 3,
                 (FTYPE(AssignmentValueDump)) (&FNAME(translate_let_list_item)),
                 &args);
      current_node = current_node->next;
    }
    if (has_rest) {
      LetListItemAssArgs args = {
        val_num + 1,
        "rhs"
      };
      WINDENT(indent + 3);
      ADD_ASSIGN(current_node->children, indent + 3,
                 (FTYPE(AssignmentValueDump)) (&FNAME(translate_let_list_rest)),
                 &args);
    }

    WINDENT(indent + 2);
    WS("else\n");
    WINDENT(indent + 3);
    if (!has_rest) {
      WS("if rhs.length > ");
      F_NOOPT(dump_unumber, val_num);
      WS(" then\n");
      WINDENT(indent + 4);
      DUMP_ERR_ERR(o.lnr, lval_expr->node->start + o.start_col, o.name,
                   "E688: More targets than List items");
      WINDENT(indent + 3);
      WS("else\n");
      WINDENT(indent + 4);
    }
    DUMP_ERR_ERR(o.lnr, lval_expr->node->start + o.start_col, o.name,
                 "E687: Less targets than List items");
    if (!has_rest) {
      WINDENT(indent + 3);
      WS("end\n");
    }
    if (err_line != NULL) {
      WINDENT(indent + 3);
      W(err_line);
      WS("\n");
    }
    WINDENT(indent + 2);
    WS("end\n");

    WINDENT(indent + 1);
    WS("else\n");
    WINDENT(indent + 2);
    // FIXME lval_expr is not appropriate here
    DUMP_ERR_ERR(o.lnr, lval_expr->node->start + o.start_col, o.name,
                 "E714: List required");
    if (err_line != NULL) {
      WINDENT(indent + 2);
      W(err_line);
      WS("\n");
    }
    WINDENT(indent + 1);
    WS("end\n");
    WINDENT(indent);
    WS("end\n");
  } else {
    ADD_ASSIGN(lval_expr->node, indent, FNAME(dump), dump_cookie);
  }
#undef ADD_ASSIGN
  FUNCTION_END;
}

#define CMD_FDEC(f) \
    FDEC(f, const CommandNode *const node, const size_t indent)

static CMD_FDEC(translate_call)
{
  FUNCTION_START;
  WINDENT(indent);
  WS("vim.commands.call(state, ");
  F(translate_range, &(node->range));
  WS(", ");
  const Expression *expr = node->args[ARG_EXPR_EXPR].arg.expr;
  OVERRIDE_CONTEXT(start_col, expr->col,
                   F(translate_expr_node, expr->string, expr->node->children,
                     true););
  WS(", ");
  F(dump_position, o.lnr, expr->col + expr->node->children->start, o.name);
  for (const ExpressionNode *arg_node = expr->node->children->next;
       arg_node != NULL;
       arg_node = arg_node->next) {
    WS(", ");
    OVERRIDE_CONTEXT(start_col, expr->col,
                     F(translate_expr_node, expr->string, arg_node, true););
    WS(", ");
    F(dump_position, o.lnr, expr->col + arg_node->start, o.name);
  }
  WS(")\n");
  FUNCTION_END;
}

static CMD_FDEC(translate_throw)
{
  FUNCTION_START;
  WINDENT(indent);
  WS("vim.err.throw(state, ");
  F(translate_expr_node, TRANS_NODE_EXPR_ARGS(node, ARG_EXPR_EXPR), false);
  WS(", ");
  F(dump_position, o.lnr,
    o.start_col + node->args[ARG_EXPR_EXPR].arg.expr->col, o.name);
  WS(")\n");
  FUNCTION_END;
}

static CMD_FDEC(translate_comment)
{
  FUNCTION_START;
  WINDENT(indent);
  WS("-- \"");
  W(node->args[ARG_NAME_NAME].arg.str);
  WS("\n");
  FUNCTION_END;
}

static CMD_FDEC(translate_hashbang_comment)
{
  FUNCTION_START;
  WINDENT(indent);
  WS("-- #!");
  W(node->args[ARG_NAME_NAME].arg.str);
  WS("\n");
  FUNCTION_END;
}

static CMD_FDEC(translate_error)
{
  FUNCTION_START;
  WINDENT(indent);
  WS("vim.err.err(state, ");
  F(dump_position, node->position.lnr, node->position.col, NULL);
  WS(", true, ");
  F(dump_string, node->args[ARG_ERROR_MESSAGE].arg.str);
  WS(")\n");
  FUNCTION_END;
}

/// Translate missing command
static CMD_FDEC(translate_missing)
{
  FUNCTION_START;
  WS("\n");
  FUNCTION_END;
}

/// Translate user command call
static CMD_FDEC(translate_user)
{
  FUNCTION_START;
  WINDENT(indent);
  WS("vim.run_user_command(state, '");
  W(node->name);
  WS("', ");
  F(translate_range, &(node->range));
  WS(", ");
  F(dump_bool, node->bang);
  WS(", ");
  F(dump_string, node->args[ARG_USER_ARG].arg.str);
  WS(")\n");
  FUNCTION_END;
}

static CMD_FDEC(translate_function)
{
  FUNCTION_START;
  const TranslateFuncArgs args = { node, indent };
  WINDENT(indent);
  F(translate_lval, TRANS_NODE_EXPR_ARGS(node, ARG_FUNC_NAME), true,
    node->bang, true, "ass_",
    (FTYPE(AssignmentValueDump)) &FNAME(translate_function_definition),
    (void *) &args);
  WS("\n");
  FUNCTION_END;
}

static CMD_FDEC(translate_for)
{
  FUNCTION_START;
  WINDENT(indent);
  WS("do\n");
  WINDENT(indent + 1);
  WS("local cont = true\n");
  WINDENT(indent + 2);
  WS("for _, i in vim.iter(state, ");
  F(translate_expr_node, TRANS_NODE_EXPR_ARGS(node, ARG_FOR_RHS), false);
  WS(", ");
  F(dump_position, o.lnr, o.start_col + node->args[ARG_FOR_RHS].arg.expr->col,
    o.name);
  WS(") do\n");

  WINDENT(indent + 2);
  F(translate_assignment, node->args[ARG_FOR_LHS].arg.expr, indent + 1,
    "break", (FTYPE(AssignmentValueDump)) &FNAME(dump_raw_string),
    (void *) "i", VAL_LET_ASSIGN);

  WINDENT(indent + 2);
  WS("repeat\n");

  F(translate_nodes, node->children, indent + 3);

  WINDENT(indent + 2);
  WS("until true\n");
  WINDENT(indent + 2);
  WS("if not cont then\n");
  WINDENT(indent + 3);
  WS("break\n");
  WINDENT(indent + 2);
  WS("end\n");
  WINDENT(indent + 1);
  WS("end\n");
  WINDENT(indent);
  WS("end\n");
  FUNCTION_END;
}

static CMD_FDEC(translate_while)
{
  FUNCTION_START;
  WINDENT(indent);
  WS("do\n");
  WINDENT(indent + 1);
  WS("local cont = true\n");
  WINDENT(indent + 1);
  WS("while cont and vim.get_boolean(state, ");
  F(translate_expr_node, TRANS_NODE_EXPR_ARGS(node, ARG_EXPR_EXPR), false);
  WS(") do\n");
  WINDENT(indent + 2);
  WS("repeat\n");

  F(translate_nodes, node->children, indent + 3);

  WINDENT(indent + 2);
  WS("until true\n");
  WINDENT(indent + 1);
  WS("end\n");
  WINDENT(indent);
  WS("end\n");
  FUNCTION_END;
}

static CMD_FDEC(translate_break)
{
  FUNCTION_START;
  WINDENT(indent);
  if (o.inloop) {
    WS("cont = false\n");
    WINDENT(indent);
    WS("break\n");
  } else {
    DUMP_ERR_ERR(o.lnr, o.start_col, o.name,
                 "E587: :break without :while or :for");
  }
  FUNCTION_END;
}

static CMD_FDEC(translate_continue)
{
  FUNCTION_START;
  WINDENT(indent);
  if (o.inloop) {
    WS("break\n");
  } else {
    DUMP_ERR_ERR(o.lnr, o.start_col, o.name,
                 "E586: :continue without :while or :for");
  }
  FUNCTION_END;
}

// Translate :if, :elseif and :else
static CMD_FDEC(translate_if_block)
{
  FUNCTION_START;
  WINDENT(indent);
  switch (node->type) {
    case kCmdElse: {
      WS("else\n");
      break;
    }
    case kCmdElseif: {
      WS("else");
      // fallthrough
    }
    case kCmdIf: {
      WS("if vim.get_boolean(state, ");
      F(translate_expr_node, TRANS_NODE_EXPR_ARGS(node, ARG_EXPR_EXPR), false);
      WS(") then\n");
      break;
    }
    default: {
      assert(false);
    }
  }

  F(translate_nodes, node->children, indent + 1);

  if (node->next == NULL
      || (node->next->type != kCmdElseif
          && node->next->type != kCmdElse)) {
    WINDENT(indent);
    WS("end\n");
  }
  FUNCTION_END;
}

static CMD_FDEC(translate_try_block)
{
  FUNCTION_START;
  CommandNode *first_catch = NULL;
  CommandNode *finally = NULL;
  CommandNode *next = node->next;

  for (next = node->next;
       next->type == kCmdCatch || next->type == kCmdFinally;
       next = next->next) {
    switch (next->type) {
      case kCmdCatch: {
        if (first_catch == NULL) {
          first_catch = next;
        }
        continue;
      }
      case kCmdFinally: {
        finally = next;
        break;
      }
      default: {
        assert(false);
      }
    }
    break;
  }

  WINDENT(indent);
  WS("do\n");

  WINDENT(indent + 1);
  WS("local ok, ret\n");
  WINDENT(indent + 1);
  WS("ok, ret = pcall(function(state)\n");
  F(translate_nodes, node->children, indent + 2);
  WINDENT(indent + 1);
  WS("end, vim.state.enter_try(state))\n");

  if (finally != NULL) {
    WINDENT(indent + 1);
    WS("local fin = function(state)\n");
    F(translate_nodes, finally->children, indent + 2);
    WINDENT(indent + 1);
    WS("end\n");
  }

  if (first_catch != NULL) {
    WINDENT(indent + 1);
    WS("local catch\n");
  }

  if (first_catch != NULL) {
    bool did_first_if = false;

    WINDENT(indent + 1);
    WS("if not ok then\n");

    for (next = first_catch; next->type == kCmdCatch; next = next->next) {
      size_t current_indent;

      if (did_first_if) {
        WINDENT(indent + 1);
        WS("else");
      }

      if (next->args[ARG_REG_REG].arg.reg == NULL) {
        if (did_first_if) {
          WS("\n");
        }
      } else {
        WINDENT(indent + 2);
        WS("if (vim.err.matches(state, ret, ");
        F(translate_regex, next->args[ARG_REG_REG].arg.reg);
        WS(") then\n");
        did_first_if = true;
      }
      current_indent = indent + 2 + (did_first_if ? 1 : 0);
      WINDENT(current_indent);
      WS("catch = function(state)\n");
      F(translate_nodes, next->children, current_indent + 1);
      WINDENT(current_indent);
      WS("end\n");
      WINDENT(current_indent);
      WS("ok = 'caught'\n");  // String "'caught'" is true

      if (next->args[ARG_REG_REG].arg.reg == NULL) {
        break;
      }
    }

    if (did_first_if) {
      WINDENT(indent + 2);
      WS("end\n");
    }

    WINDENT(indent + 1);
    WS("end\n");
  }

  if (first_catch != NULL) {
    WINDENT(indent + 1);
    WS("if catch then\n");
    WINDENT(indent + 2);
    WS("ret = catch(vim.state.enter_catch(state, ret))\n");
    WINDENT(indent + 1);
    WS("end\n");
  }

  if (finally != NULL) {
    WINDENT(indent + 1);
    WS("ret = fin(state)\n");
  }

  WINDENT(indent + 1);
  WS("if not ok then\n");
  WINDENT(indent + 2);
  WS("error(ret, 0)\n");
  WINDENT(indent + 1);
  WS("end\n");

  WINDENT(indent + 1);
  WS("if (ret ~= nil) then\n");
  WINDENT(indent + 2);
  WS("return ret\n");
  WINDENT(indent + 1);
  WS("end\n");
  WINDENT(indent);
  WS("end\n");

  FUNCTION_END;
}

static CMD_FDEC(translate_unlet)
{
  FUNCTION_START;
  const Expression *lval_expr = node->args[ARG_EXPR_EXPR].arg.expr;
  const ExpressionNode *current_node = lval_expr->node;
  for (; current_node != NULL; current_node = current_node->next) {
    OVERRIDE_CONTEXT(start_col, lval_expr->col, {
      F(translate_lval, lval_expr->string, current_node, false, node->bang,
        true, "del_", NULL, NULL);
      WS("\n");
    });
  }
  FUNCTION_END;
}

static CMD_FDEC(translate_lockvar)
{
  FUNCTION_START;
  const Expression *lval_expr = node->args[ARG_EXPR_EXPR].arg.expr;
  const ExpressionNode *current_node = lval_expr->node;
  uintptr_t unumber = (uintptr_t) node->args[ARG_LOCKVAR_DEPTH].arg.unumber;
  if (unumber == 0) {
    unumber = 2;
  }
  for (; current_node != NULL; current_node = current_node->next) {
    OVERRIDE_CONTEXT(start_col, lval_expr->col, {
      F(translate_lval, lval_expr->string, current_node, false, node->bang,
        true, "lock_", &FNAME(translate_unumber), (void *) unumber);
      WS("\n");
    });
  }
  FUNCTION_END;
}

static CMD_FDEC(translate_unlockvar)
{
  FUNCTION_START;
  const Expression *lval_expr = node->args[ARG_EXPR_EXPR].arg.expr;
  const ExpressionNode *current_node = lval_expr->node;
  uintptr_t unumber = (uintptr_t) node->args[ARG_LOCKVAR_DEPTH].arg.unumber;
  if (unumber == 0) {
    unumber = 2;
  }
  for (; current_node != NULL; current_node = current_node->next) {
    OVERRIDE_CONTEXT(start_col, lval_expr->col, {
      F(translate_lval, lval_expr->string, current_node, false, node->bang,
        true, "unlock_", &FNAME(translate_unumber), (void *) unumber);
      WS("\n");
    });
  }
  FUNCTION_END;
}

static CMD_FDEC(translate_delfunction)
{
  FUNCTION_START;
  const Expression *lval_expr = node->args[ARG_EXPR_EXPR].arg.expr;
  const ExpressionNode *current_node = lval_expr->node;
  for (; current_node != NULL; current_node = current_node->next) {
    OVERRIDE_CONTEXT(start_col, lval_expr->col, {
      F(translate_lval, lval_expr->string, current_node, true, node->bang,
        true, "del_", NULL, NULL);
      WS("\n");
    });
  }
  FUNCTION_END;
}

static CMD_FDEC(translate_let)
{
  FUNCTION_START;
  if (node->args[ARG_LET_RHS].arg.expr != NULL) {
    const Expression *lval_expr = node->args[ARG_LET_LHS].arg.expr;
    const Expression *rval_expr = node->args[ARG_LET_RHS].arg.expr;
    LetAssignmentType ass_type = node->args[ARG_LET_ASS_TYPE].arg.unumber;
    WINDENT(indent);
    F(translate_assignment, lval_expr, indent, NULL,
      (FTYPE(AssignmentValueDump)) &FNAME(translate_rval_expr),
      (void *) rval_expr, ass_type);
  } else {
    F(translate_node, node, indent);
  }
  FUNCTION_END;
}

#undef CMD_FDEC

/// Generic VimL Ex commands dumper
///
/// @param[in]  node    Node to translate.
/// @param[in]  indent  Indentation of the result.
static FDEC(translate_node, const CommandNode *const node,
            const size_t indent)
{
  FUNCTION_START;
  const char *name;
  size_t start_from_arg = 0;
  bool do_arg_dump = true;
  bool add_comma = false;

  WINDENT(indent);

  name = CMDDEF(node->type).name;
  assert(name != NULL);

  WS("vim.commands");
  if (ASCII_ISALPHA(*name)) {
    WS(".");
    W(name);
  } else {
    WS("['");
    W(name);
    WS("']");
  }
  WS("(state, ");

  if (CMDDEF(node->type).flags & RANGE) {
    if (add_comma) {
      WS(", ");
    }
    F(translate_range, &(node->range));
    add_comma = true;
  }

  if (CMDDEF(node->type).flags & BANG) {
    if (add_comma) {
      WS(", ");
    }
    F(dump_bool, node->bang);
    add_comma = true;
  }

  if (CMDDEF(node->type).flags & EXFLAGS) {
    if (add_comma) {
      WS(", ");
    }
    F(translate_ex_flags, node->exflags);
    add_comma = true;
  }

  if (CMDDEF(node->type).parse == CMDDEF(kCmdAbclear).parse) {
    if (add_comma) {
      WS(", ");
    }
    F(dump_bool, (bool) node->args[ARG_CLEAR_BUFFER].arg.flags);
  }

  if (do_arg_dump) {
    size_t i;
    size_t num_args = CMDDEF(node->type).num_args;

    for (i = start_from_arg; i < num_args; i++) {
      if (add_comma) {
        WS(", ");
      }
      add_comma = false;
      switch (CMDDEF(node->type).arg_types[i]) {
        case kArgExpression: {
          OVERRIDE_CONTEXT(start_col, node->args[i].arg.expr->col,
                           F(translate_expr_node, TRANS_NODE_EXPR_ARGS(node, i),
                             false););
          add_comma = true;
          break;
        }
        case kArgExpressions: {
          OVERRIDE_CONTEXT(start_col, node->args[i].arg.expr->col,
                           F(translate_expr_nodes, TRANS_NODE_EXPR_ARGS(node,
                                                                        i)););
          add_comma = true;
          break;
        }
        case kArgString: {
          F(dump_string, node->args[i].arg.str);
          add_comma = true;
          break;
        }
        default: {
          break;
        }
      }
    }
  }

  WS(")\n");

  FUNCTION_END;
}


/// Dump a sequence of Ex commands
///
/// @param[in]  node    Pointer to the first node that will be translated.
/// @param[in]  indent  Indentation of the result.
static FDEC(translate_nodes, const CommandNode *const node, size_t indent)
{
  FUNCTION_START;
  const CommandNode *current_node;

  for (current_node = node; current_node != NULL;
       current_node = current_node->next) {
    const char *name = (current_node->name == NULL
                        ? CMDDEF(current_node->type).name
                        : current_node->name);
#define CMD_F(f) \
    OVERRIDE_CONTEXT_POS( \
        current_node->position.lnr, current_node->position.col, name, \
        F(f, current_node, indent); \
    )
    switch (current_node->type) {
      case kCmdFinish: {
        switch (TRANSLATION_SOURCE) {
          case kTransFunc:
          case kTransUser: {
            WINDENT(indent);
            DUMP_ERR_ERR_CMD_POS(
                current_node->position, name,
                "E168: :finish used outside of a sourced file");
            continue;
          }
          case kTransScript: {
            WINDENT(indent);
            WS("return nil\n");
            break;
          }
        }
        break;
      }
      case kCmdReturn: {
        switch (TRANSLATION_SOURCE) {
          case kTransScript:
          case kTransUser: {
            WINDENT(indent);
            DUMP_ERR_ERR_CMD_POS(current_node->position, name,
                                 "E133: :return not inside a function");
            continue;
          }
          case kTransFunc: {
            WINDENT(indent);
            WS("return ");
            OVERRIDE_CONTEXT_POS(current_node->position.lnr,
                                 node->args[ARG_EXPR_EXPR].arg.expr->col,
                                 name, {
              F(translate_expr_node, TRANS_NODE_EXPR_ARGS(node, ARG_EXPR_EXPR),
                false);
            });
            WS("\n");
            break;
          }
        }
        break;
      }
      case kCmdEndwhile:
      case kCmdEndfor:
      case kCmdEndif:
      case kCmdEndfunction:
      case kCmdEndtry: {
        // Handled by :while/:for/:if/:function/:try handlers
        continue;
      }
      case kCmdCatch:
      case kCmdFinally: {
        // Handled by :try handler
        continue;
      }
#define SET_HANDLER(cmd_type, handler) \
      case cmd_type: { \
        CMD_F(handler); \
        continue; \
      }
      SET_HANDLER(kCmdComment, translate_comment)
      SET_HANDLER(kCmdHashbangComment, translate_hashbang_comment)
      SET_HANDLER(kCmdSyntaxError, translate_error)
      SET_HANDLER(kCmdMissing, translate_missing)
      SET_HANDLER(kCmdUSER, translate_user)
      SET_HANDLER(kCmdBreak, translate_break)
      SET_HANDLER(kCmdContinue, translate_continue)
      case kCmdElse:
      case kCmdElseif:
      SET_HANDLER(kCmdIf, translate_if_block)
      SET_HANDLER(kCmdTry, translate_try_block)
      SET_HANDLER(kCmdLet, translate_let)
      SET_HANDLER(kCmdUnlet, translate_unlet)
      SET_HANDLER(kCmdDelfunction, translate_delfunction)
      SET_HANDLER(kCmdThrow, translate_throw)
      SET_HANDLER(kCmdCall, translate_call)
      SET_HANDLER(kCmdLockvar, translate_lockvar)
      SET_HANDLER(kCmdUnlockvar, translate_unlockvar)
#undef SET_HANDLER
#define SET_LOOP_HANDLER(cmd_type, handler, inloop_value) \
      case cmd_type: { \
        OVERRIDE_CONTEXT(inloop, inloop_value, \
                         CMD_F(handler);); \
        continue; \
      }
      // Function body may not be treated as located inside the loop: this
      // affects :break/:continue commands handling resulting in lua error.
      SET_LOOP_HANDLER(kCmdFunction, translate_function, false)
      SET_LOOP_HANDLER(kCmdFor, translate_for, true)
      SET_LOOP_HANDLER(kCmdWhile, translate_while, true)
#undef SET_LOOP_HANDLER
      default: {
        CMD_F(translate_node);
        continue;
      }
    }
    break;
#undef CMD_F
  }

  if (current_node == NULL && TRANSLATION_SOURCE == kTransFunc) {
    WINDENT(indent);
    WS("return " VIM_ZERO "\n");
  }

  FUNCTION_END;
}

static FDEC(translate_parser_result, const ParserResult *const pres,
            size_t indent)
{
  FUNCTION_START;
  WS("state = vim.state.enter_code(state, {\n");
  for (size_t i = 0; i < pres->lines_size; i++) {
    WINDENT(indent + 1);
    F(dump_string, pres->lines[i]);
    WS(",\n");
  }
  WINDENT(indent);
  WS("}, ");
  F(dump_string, pres->fname);
  WS(")\n");
  OVERRIDE_CONTEXT(inloop, false, {
    OVERRIDE_CONTEXT(
        lines, (const char *const *) pres->lines,
        F(translate_nodes, pres->node, indent););
  });
  FUNCTION_END;
}

/// Dump .vim script as lua module.
///
/// @param[in]  pres    Parser output.
/// @param[in]  write   Function that will be used to write the result.
/// @param[in]  cookie  Last argument to the above function.
static FDEC(translate_script, const ParserResult *const pres)
{
  FUNCTION_START;
  OVERRIDE_CONTEXT(tsrc, kTransScript, {
    // FIXME Add <SID>
    WS("vim = require 'vim'\n"
       "s = vim.new_script_scope(state, false)\n"
       "return {\n"
       "  run=function(state)\n"
       "    state = vim.state.enter_script(state, s)\n");

    F(translate_parser_result, pres, 2);

    WS("  end\n"
       "}\n");
  });
  FUNCTION_END;
}

/// Dump command executed from user input as code that runs immediately
///
/// @param[in]  pres    Parser output.
/// @param[in]  write   Function that will be used to write the result.
/// @param[in]  cookie  Last argument to the above function.
static FDEC(translate_input, const ParserResult *const pres)
{
  FUNCTION_START;
  OVERRIDE_CONTEXT(tsrc, kTransUser, {
    WS("local state = vim.state.get_top()\n");
    F(translate_parser_result, pres, 0);
  });
  FUNCTION_END;
}
#endif  // NVIM_VIML_TRANSLATOR_TRANSLATOR_C_H
