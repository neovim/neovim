#ifndef NVIM_VIML_PRINTER_EX_COMMANDS_C_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <assert.h>

#include "nvim/memory.h"
#include "nvim/ascii.h"
// FIXME The following include must not be here, they are for option.h
#include "nvim/vim.h"
#include "nvim/option.h"
#include "nvim/charset.h"

#include "nvim/viml/printer/printer.h"
#include "nvim/viml/printer/expressions.h"
#include "nvim/viml/printer/ex_commands.h"
#include "nvim/viml/parser/expressions.h"
#include "nvim/viml/parser/ex_commands.h"
#include "nvim/viml/dumpers/dumpers.h"

// WARNING: Moving it above breaks compilation
#include "nvim/ex_docmd.h"

#if !defined(CH_MACROS_DEFINE_LENGTH) && !defined(CH_MACROS_DEFINE_FWRITE)
# define CH_MACROS_DEFINE_LENGTH
# include "nvim/viml/printer/ex_commands.c.h"
# undef CH_MACROS_DEFINE_LENGTH
#elif !defined(CH_MACROS_DEFINE_FWRITE)
# undef CH_MACROS_DEFINE_LENGTH
# define CH_MACROS_DEFINE_FWRITE
# include "nvim/viml/printer/ex_commands.c.h"  // NOLINT
# undef CH_MACROS_DEFINE_FWRITE
# define CH_MACROS_DEFINE_LENGTH
#endif
#define NVIM_VIML_PRINTER_EX_COMMANDS_C_H

#ifndef NVIM_VIML_DUMPERS_CH_MACROS
# define CH_MACROS_OPTIONS_TYPE const StyleOptions *const
# define CH_MACROS_INDENT_STR o->command.indent
#endif
#include "nvim/viml/dumpers/ch_macros.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/printer/ex_commands.c.h.generated.h"
#endif

#ifndef NVIM_VIML_PRINTER_EX_COMMANDS_C_H_MACROS
# define NVIM_VIML_PRINTER_EX_COMMANDS_C_H_MACROS
# define mb_char2bytes(n, b) ((size_t) mb_char2bytes(n, (char_u *) b))
# define mb_char2len(n) ((size_t) mb_char2len(n))
#endif

#define IF_AST(s1, s2) \
  do { \
    if (GLOB_AST) { \
      WS(s1); \
    } else { \
      WS(s2); \
    } \
  } while (0)
#define IF_AST_END(s2) IF_AST(")", s2)

static FDEC(print_collection_ch, const u8char_T ch)
{
  FUNCTION_START;
  if (ch && ch < 0x80
      && strchr(pattern_collection_escape_chars, (char) ch) != NULL) {
    WC('\\');
    W_LEN(pattern_collection_escapes + (
        strchr(pattern_collection_escape_chars, (char) ch)
        - pattern_collection_escape_chars), 1);
  } else if (ch && ch < 0x80
             && strchr(pattern_collection_escapable_chars, (char) ch)) {
    WC('\\');
    WC((char) ch);
  } else if (vim_isprintc_strict((int) ch)) {
    char ch_repr[MAX_CHAR_LEN];
    const size_t ch_len = mb_char2len((int) ch);
    mb_char2bytes((int) ch, &(ch_repr[0]));
    W_LEN(ch_repr, ch_len);
  } else {
    if (ch <= 0xFF) {
      WS("\\x");
      WC((char) nr2hex((unsigned) ((ch >> 4) & 0xF)));
      WC((char) nr2hex((unsigned) (ch & 0xF)));
    } else if (ch <= 0xFFFF) {
      WS("\\u");
      WC((char) nr2hex((unsigned) ((ch >> 12) & 0xF)));
      WC((char) nr2hex((unsigned) ((ch >>  8) & 0xF)));
      WC((char) nr2hex((unsigned) ((ch >>  4) & 0xF)));
      WC((char) nr2hex((unsigned) (ch & 0xF)));
#if SIZEOF_INT > 4
// GCC emits a warning that comparison is always true if I don’t #if it.
    } else if (ch <= 0xFFFFFFFFL) {
#else
    } else {
#endif
      WS("\\U");
      WC((char) nr2hex((unsigned) ((ch >> 28) & 0xF)));
      WC((char) nr2hex((unsigned) ((ch >> 24) & 0xF)));
      WC((char) nr2hex((unsigned) ((ch >> 20) & 0xF)));
      WC((char) nr2hex((unsigned) ((ch >> 16) & 0xF)));
      WC((char) nr2hex((unsigned) ((ch >> 12) & 0xF)));
      WC((char) nr2hex((unsigned) ((ch >>  8) & 0xF)));
      WC((char) nr2hex((unsigned) ((ch >>  4) & 0xF)));
      WC((char) nr2hex((unsigned) (ch & 0xF)));
#if SIZEOF_INT > 4
    } else {
      assert(false);
#endif
    }
  }
  FUNCTION_END;
}

static FDEC(print_filename_modifiers, const FilenameModifier *const mod)
{
  FUNCTION_START;
  if (mod == NULL) {
    EARLY_RETURN;
  }
  const FilenameModifier *next;
#ifndef CH_MACROS_DEFINE_LENGTH
  static const char modifier_chars[] = {
    [kFnameModFullPath] = 'p',
    [kFnameMod8_3] = '8',
    [kFnameModHome] = '~',
    [kFnameModRelative] = '.',
    [kFnameModHead] = 'h',
    [kFnameModTail] = 't',
    [kFnameModRoot] = 'r',
    [kFnameModExtension] = 'e',
    [kFnameModEscape] = 'S',
    [kFnameModSub] = 's',
  };
#endif
  for (next = mod; next != NULL; next = next->next) {
    if (next->type == kFnameModGSub) {
      WS(":gs");
    } else {
      WC(':');
      WC(modifier_chars[next->type]);
    }
    if (next->type == kFnameModSub || next->type == kFnameModGSub) {
#ifndef CH_MACROS_DEFINE_LENGTH
      // Possible delimiter characters, in order of preference
      static const char rechars[] = {
        // Characters that have no special meaning in regex, not even escaped
        '/', '-', ':', ';', ',', '!', '"', '`',
        // Characters that have special meaning, but are used rarely
        '\'', '=', '#', '_', '%',
        // Common characters with special meaning
        '~', '@', '+', '|', '&', '?', '^', '$', '.', '*', '\\',
        // Paired characters (substitutions with them will look strange)
        '<', '>', '(', ')', '[', ']', '{', '}',
      };
      // FIXME this code only considers regex, but not replacement.
      // Make sure that delimiter character is not present in regex: there is no
      // way to escape it.
      char delim = rechars[0];
      size_t i;
      for (i = 0; i < ARRAY_SIZE(rechars); i++) {
        if (strchr(&(next->reg->string[0]), rechars[i]) == NULL) {
          // FIXME What to do if all characters from rechars appear in regex or
          //       replacement? Is it possible?
          delim = rechars[i];
          break;
        }
      }
#endif
      WC(delim);
      F(print_regex, next->reg, NUL);
      WC(delim);
      F(print_replacement, next->rep, IS_MAGIC);
      WC(delim);
    }
    if (next->next) {
      IF_AST(", ", "");
    }
  }
  FUNCTION_END;
}

static FDEC(print_collection, const PatternCollection collection)
{
  FUNCTION_START;
  IF_AST("col(", "[");
  if (collection.inverse) {
    IF_AST("inverse, ", "^");
  } else {
    IF_AST("regular, ", "");
  }
  const PatternCollectionItem *next = collection.colitem;
  assert(next != NULL);
  while (next != NULL) {
    switch (next->type) {
      case kPatColItemLiteral: {
        IF_AST("ch(", "");
        F(print_collection_ch, next->data.ch);
        IF_AST_END("");
        break;
      }
      case kPatColItemRange: {
        IF_AST("rng(", "");
        F(print_collection_ch, next->data.range.ch1);
        IF_AST(", ", "-");
        F(print_collection_ch, next->data.range.ch2);
        IF_AST_END("");
        break;
      }
      case kPatColItemClass: {
        IF_AST("class(", "[:");
        W_LEN(pattern_character_classes[next->data.class].str,
              pattern_character_classes[next->data.class].len);
        IF_AST_END(":]");
        break;
      }
    }
    next = next->next;
    if (next) {
      IF_AST(", ", "");
    }
  }
  IF_AST_END("]");
  FUNCTION_END;
}

static FDEC(print_pattern, const Pattern *const pat)
{
  FUNCTION_START;
  const Pattern *cur_pat;

  if (pat == NULL) {
    EARLY_RETURN;
  }

  for (cur_pat = pat; cur_pat != NULL; cur_pat = cur_pat->next) {
    switch (cur_pat->type) {
      case kGlobExpression: {
        IF_AST("expr(", "`=");
        F(print_expr, cur_pat->data.expr);
        IF_AST_END("`");
        break;
      }
      case kGlobShell: {
        IF_AST("shell(", "`");
        W(cur_pat->data.str);
        IF_AST_END("`");
        break;
      }
      case kPatHome: {
        IF_AST("home()", "~");
        break;
      }
      case kPatCurrent: {
        IF_AST("cur(", "%");
        F(print_filename_modifiers, cur_pat->data.mod);
        IF_AST_END("");
        break;
      }
      case kPatAlternate: {
        IF_AST("alt(", "#");
        F(print_filename_modifiers, cur_pat->data.mod);
        IF_AST_END("");
        break;
      }
      case kPatCharacter: {
        IF_AST("char()", "?");
        break;
      }
      case kPatAnything: {
        IF_AST("any()", "*");
        break;
      }
      case kPatArguments: {
        IF_AST("args(", "##");
        F(print_filename_modifiers, cur_pat->data.mod);
        IF_AST_END("");
        break;
      }
      case kPatAnyRecurse: {
        IF_AST("any(recursive)", "**");
        break;
      }
      case kPatOldFile: {
        IF_AST("old(", "#<");
        F_NOOPT(dump_unumber, (uintmax_t) cur_pat->data.number);
        assert(cur_pat->next != NULL && cur_pat->next->type == kPatFnameMod);
        break;
      }
      case kPatBufname: {
        IF_AST("buf(", "#");
        F_NOOPT(dump_unumber, (uintmax_t) cur_pat->data.number);
        assert(cur_pat->next != NULL && cur_pat->next->type == kPatFnameMod);
        break;
      }
      case kPatFnameMod: {
        if (cur_pat->data.mod) {
          IF_AST(", ", "");
          F(print_filename_modifiers, cur_pat->data.mod);
        }
        IF_AST_END("");
        break;
      }
      case kPatCollection: {
        F(print_collection, cur_pat->data.collection);
        break;
      }
      case kPatEnviron: {
        IF_AST("env(", "$");
        W(cur_pat->data.str);
        IF_AST_END("");
        break;
      }
      case kPatAuList:
      case kPatBranch: {
        const Patterns *cpats;
        if (cur_pat->type == kPatBranch) {
          IF_AST("branch(", "{");
        }
        for (cpats = &(cur_pat->data.pats);
             cpats != NULL;
             cpats = cpats->next) {
          F(print_pattern, cpats->pat);
          if (cpats->next != NULL) {
            WC(',');
          }
        }
        if (cur_pat->type == kPatBranch) {
          IF_AST_END("}");
        }
        break;
      }
      case kPatLiteral: {
        if (GLOB_AST) {
          WS("lit(");
        }
        W(cur_pat->data.str);
        IF_AST_END("");
        break;
      }
      case kPatSourcedLnum:
      case kPatCurWord:
      case kPatCurWORD:
      case kPatClient:
      case kPatCurFile:
      case kPatSourcedFile:
      case kPatAuFile:
      case kPatAuBuf:
      case kPatAuMatch: {
        IF_AST("", "<");
        for (const CmdlineSpecialDescription *sp_desc = &(cmdline_specials[0]);;
             sp_desc++) {
          if (sp_desc->type == cur_pat->type) {
            W_LEN(sp_desc->str, sp_desc->len);
            break;
          }
          assert(sp_desc->str != NULL);
        }
        IF_AST("(", ">");
        F(print_filename_modifiers, cur_pat->data.mod);
        IF_AST_END("");
        break;
      }
      case kPatMissing: {
        assert(false);
      }
    }
    if (GLOB_AST && cur_pat->next != NULL
        && cur_pat->next->type != kPatFnameMod) {
      WS(".");
    }
  }

  FUNCTION_END;
}

#undef IF_AST
#undef IF_AST_END

/// Print :substitute replacement string
///
/// @param[in]  rep    Printed replacement AST.
/// @param[in]  magic  True if 'magic' option is in effect.
static FDEC(print_replacement, const Replacement *rep, const bool magic)
{
  FUNCTION_START;
  while (rep != NULL) {
    switch (rep->type) {
#define REP_ATOM(s, rep_type) \
      case rep_type: { \
        WS(s); \
        break; \
      }
      REP_ATOM("\\u", kRepCharUpCase)
      REP_ATOM("\\l", kRepCharDownCase)
      REP_ATOM("\\U", kRepUpCase)
      REP_ATOM("\\L", kRepDownCase)
      REP_ATOM("\\E", kRepCaseEnd)
      REP_ATOM("\\r", kRepNewLine)
#undef REP_ATOM
      case kRepMatched: {
        if (!USE_S_AMPERSAND) {
          WS("\\0");
        } else if (magic) {
          WC('&');
        } else {
          WS("\\&");
        }
        break;
      }
      case kRepPrevSub: {
        if (magic) {
          WC('~');
        } else {
          WS("\\~");
        }
        break;
      }
      case kRepEscaped: {
        switch (rep->data.ch) {
          case NUL: {
            WS("\\r");
            break;
          }
          case BS: {
            WS("\\b");
            break;
          }
          case TAB: {
            WS("\\t");
            break;
          }
          case '\\': {
            WS("\\\\");
            break;
          }
          case CAR: {
            WC('\\');
            WC(CAR);
            break;
          }
          default: {
            assert(false);
          }
        }
        break;
      }
      case kRepEscLiteral: {
        WC('\\');
        char s[MB_MAXBYTES];
        const size_t s_len = mb_char2bytes((int) rep->data.ch, &(s[0]));
        W_LEN(s, s_len);
        break;
      }
      case kRepGroup: {
        WC('\\');
        assert(rep->data.group > 0 && rep->data.group < 10);
        WC((char) ('0' + rep->data.group));
        break;
      }
      case kRepLiteral: {
        if (magic) {
          W_ESCAPED(rep->data.str, "\\~&\n");
        } else {
          W_ESCAPED(rep->data.str, "\\\n");
        }
        break;
      }
      case kRepExpr: {
        assert(rep->next == NULL);
        WS("\\=");
        F(print_expr, rep->data.expr);
        break;
      }
    }
    rep = rep->next;
  }
  FUNCTION_END;
}

static FDEC(print_regex, const Regex *const regex, const char endch)
{
  FUNCTION_START;
  if (endch) {
    WC(endch);
  }
  assert(regex->string != NULL);
  if (endch) {
    size_t numslashes = 0;
    for (const char *p = regex->string; *p; p++) {
      if (*p == '\\') {
        numslashes++;
      } else {
        numslashes = 0;
      }
      if (*p == endch && numslashes % 2 == 0) {
        WC('\\');
      }
      WC(*p);
    }
  } else {
    W(regex->string);
  }
  if (endch) {
    WC(endch);
  }
  FUNCTION_END;
}

static FDEC(print_address_followup, const AddressFollowup *const followup)
{
  FUNCTION_START;

  if (followup == NULL) {
    EARLY_RETURN;
  }

  switch (followup->type) {
    case kAddressFollowupMissing: {
      EARLY_RETURN;
    }
    case kAddressFollowupShift: {
      if (followup->data.shift >= 0) {
        WC('+');
      }
      F_NOOPT(dump_number, (intmax_t) followup->data.shift);
      break;
    }
    case kAddressFollowupForwardPattern:
    case kAddressFollowupBackwardPattern: {
      char ch = (followup->type == kAddressFollowupForwardPattern
                 ? '/'
                 : '?');
      F(print_regex, followup->data.regex, ch);
      break;
    }
  }

  F(print_address_followup, followup->next);

  FUNCTION_END;
}

static FDEC(print_address, const Address *const address)
{
  FUNCTION_START;

  if (address == NULL) {
    EARLY_RETURN;
  }

  switch (address->type) {
    case kAddrMissing: {
      EARLY_RETURN;
    }
    case kAddrFixed: {
      F_NOOPT(dump_unumber, (uintmax_t) address->data.lnr);
      break;
    }
    case kAddrEnd: {
      WC('$');
      break;
    }
    case kAddrCurrent: {
      WC('.');
      break;
    }
    case kAddrMark: {
      WC('\'');
      WC(address->data.mark);
      break;
    }
    case kAddrForwardSearch:
    case kAddrBackwardSearch: {
      char ch = (address->type == kAddrForwardSearch
                 ? '/'
                 : '?');
      F(print_regex, address->data.regex, ch);
      break;
    }
    case kAddrForwardPreviousSearch: {
      WS("\\/");
      break;
    }
    case kAddrBackwardPreviousSearch: {
      WS("\\?");
      break;
    }
    case kAddrSubstituteSearch: {
      WS("\\&");
      break;
    }
  }

  FUNCTION_END;
}

static FDEC(print_range, const Range *const range)
{
  FUNCTION_START;

  if (range->address.type == kAddrMissing) {
    EARLY_RETURN;
  }

  F(print_address, &(range->address));
  F(print_address_followup, range->address.followups);
  if (range->next != NULL) {
    WC(range->setpos ? ';' : ',');
    F(print_range, range->next);
  }

  FUNCTION_END;
}

static FDEC(print_node_name,
            const CommandType node_type,
            const char *const node_name,
            const bool node_bang)
{
  FUNCTION_START;
  const char *name;

  if (node_name != NULL) {
    name = node_name;
  } else if (CMDDEF(node_type).name == NULL) {
    name = "";
  } else {
    name = CMDDEF(node_type).name;
  }

  W(name);

  if (node_bang) {
    WC('!');
  }

  FUNCTION_END;
}

static FDEC(print_optflags,
            const uint_least32_t optflags,
            const char *const enc)
{
  FUNCTION_START;

  if (optflags & FLAG_OPT_BIN_USE_FLAG) {
    if (optflags & FLAG_OPT_BIN) {
      WS(" ++bin");
    } else {
      W(" ++nobin");
    }
  }
  if (optflags & FLAG_OPT_EDIT) {
    WS(" ++edit");
  }
  switch (optflags & FLAG_OPT_FF_MASK) {
    case 0: {
      break;
    }
    case VAL_OPT_FF_DOS: {
      WS(" ++ff=dos");
      break;
    }
    case VAL_OPT_FF_MAC: {
      WS(" ++ff=mac");
      break;
    }
    case VAL_OPT_FF_UNIX: {
      WS(" ++ff=unix");
      break;
    }
    default: {
      assert(false);
    }
  }
  switch (optflags & FLAG_OPT_BAD_MASK) {
    case 0: {
      break;
    }
    case VAL_OPT_BAD_KEEP: {
      WS(" ++bad=keep");
      break;
    }
    case VAL_OPT_BAD_DROP: {
      WS(" ++bad=drop");
      break;
    }
    default: {
      WS(" ++bad=");
      WC(VAL_OPT_BAD_TO_CHAR(optflags));
    }
  }
  if (enc != NULL) {
    WS(" ++enc=");
    W(enc);
  }

  FUNCTION_END;
}

static FDEC(print_count, const CommandNode *const node)
{
  FUNCTION_START;

  if (node->has_count) {
    WC(' ');
    F_NOOPT(dump_unumber, (uintmax_t) node->count);
  }

  FUNCTION_END;
}

static FDEC(print_register, const Register reg)
{
  FUNCTION_START;

  if (reg.name) {
    WC(' ');
    WC(reg.name);
    if (reg.name == '=' && reg.expr != NULL) {
      F_ESCAPED(print_expr, "\n|\"", reg.expr);
    } else {
      assert(reg.expr == NULL);
    }
  }

  FUNCTION_END;
}

static FDEC(print_exflags, const uint_least8_t exflags)
{
  FUNCTION_START;

  if (exflags) {
    WC(' ');
    if (exflags & FLAG_EX_LIST) {
      WC('l');
    }
    if (exflags & FLAG_EX_LNR) {
      WC('#');
    }
    if (exflags & FLAG_EX_PRINT) {
      WC('p');
    }
  }

  FUNCTION_END;
}

static FDEC(print_plus_cmd, const CommandNode *const node)
{
  FUNCTION_START;
  WS(" +");
#ifndef CH_MACROS_DEFINE_LENGTH
  const char *const escapes = "\011\012\013\014\015 \\\n|\"";
  // vim_isspace:              ^9  ^10 ^11 ^12 ^13 ^  | ||
  // ENDS_EXCMD:                                      ^ ^^
#endif
  F_ESCAPED(print_node, escapes, node, 0, true, false);
  FUNCTION_END;
}

static FDEC(print_glob_arg, const Glob glob)
{
  FUNCTION_START;
  if (glob.pat.type == kPatMissing) {
    EARLY_RETURN;
  }
  for (const Glob *cur_glob = &glob;
       cur_glob != NULL;
       cur_glob = cur_glob->next) {
    WC(' ');
    F(print_pattern, &(cur_glob->pat));
  }
  FUNCTION_END;
}

#ifndef INCLUDED_EVENTS
# define INCLUDED_EVENTS
# ifdef INCLUDE_GENERATED_DECLARATIONS
#  define NO_FIRST_AUTOPAT
// FIXME should include fileio.h, but this spawns lots of errors
#  include "auevents_enum.generated.h"
// FIXME should export event_names
#  include "auevents_name_map.generated.h"
# endif
#endif

static FDEC(print_auevent, const AuEvent event)
{
  FUNCTION_START;
  if (event == ANY_EVENT) {
    WC('*');
  } else if (event == NO_EVENT) {
    assert(false);
  } else {
    W_LEN(event_names[event].name, event_names[event].len);
  }
  FUNCTION_END;
}

static FDEC(print_menu_name, const MenuItem *const item)
  FUNC_ATTR_NONNULL_ALL
{
  FUNCTION_START;
  const MenuItem *cur = item;

  while (cur != NULL) {
    if (cur == item) {
      WC(' ');
    } else {
      WC('.');
    }
    W(cur->name);
    cur = cur->subitem;
  }
  FUNCTION_END;
}

static FDEC(print_args,
            const CommandType type,
            const CommandArg *arg,
            const CommandArgType *atype,
            size_t argnum)
{
  FUNCTION_START;
  while (argnum--) {
    switch (*atype) {
      case kArgExpressions:
      case kArgExpression: {
        if (arg->arg.expr != NULL) {
          WC(' ');
          F(print_expr, arg->arg.expr);
        }
        break;
      }
      case kArgString: {
        if (arg->arg.str != NULL) {
          // FIXME Handle comment printing in other location
          if (type == kCmdComment) {
            SPACES_BEFORE_TEXT2(command, comment);
          } else if (type != kCmdHashbangComment) {
            WC(' ');
          }
          // FIXME Escape arguments if necessary
          W(arg->arg.str);
        }
        break;
      }
      case kArgAuEvents: {
        if (arg->arg.events != NULL) {
          WC(' ');
          for (const AuEvent *event = arg->arg.events;
               *event != NO_EVENT;
               event++) {
            F(print_auevent, *event);
            if (event[1] != NO_EVENT) {
              WC(',');
            }
          }
        }
        break;
      }
      case kArgPattern: {
        if (arg->arg.pat != NULL) {
          WC(' ');
          F(print_pattern, arg->arg.pat);
        }
        break;
      }
      case kArgMenuName: {
        if (arg->arg.menu_item != NULL) {
          F(print_menu_name, arg->arg.menu_item);
        }
        break;
      }
      case kArgNumber: {
        WC(' ');
        F_NOOPT(dump_number, (intmax_t) arg->arg.number);
        break;
      }
      case kArgRegex: {
        if (arg->arg.reg != NULL) {
          WC(' ');
          F(print_regex, arg->arg.reg, '/');
        }
        break;
      }
      case kArgAddress: {
        if (arg->arg.range != NULL) {
          WC(' ');
          F(print_range, arg->arg.range);
        }
        break;
      }
      case kArgChar: {
        if (arg->arg.ch != NUL) {
          WC(' ');
          WC(arg->arg.ch);
        }
        break;
      }
      default: {
        break;
      }
    }
    arg++;
    atype++;
  }
  FUNCTION_END;
}

/// Print children of block command
///
/// @param[in]  node     Children which will be printed.
/// @param[in]  indent   Indent of first line in the block.
/// @param[in]  barnext  True if command separator used is bar.
static FDEC(print_block_children,
            const CommandNode *const node,
            const size_t indent,
            const bool barnext)
{
  FUNCTION_START;
  if (node == NULL) {
    EARLY_RETURN;
  }
  if (barnext) {
    WS(" | ");
  } else {
    W_NL;
  }
  F(print_node, node, indent, barnext, false);
  FUNCTION_END;
}

#define CMD_FDEC(f) \
    FDEC(f, const CommandNode *const node, const size_t indent, \
         const bool barnext)

#define PRINT_FROM_ARG(node, start_from_arg) \
    F(print_args, node->type, node->args + start_from_arg, \
      CMDDEF(node->type).arg_types + start_from_arg, \
      CMDDEF(node->type).num_args - start_from_arg);

#define PRINT_FLAG(ch, name) \
  do { \
    if (flags & name) { \
      WC(ch); \
    } \
  } while (0)

static CMD_FDEC(print_syntax_error)
{
  FUNCTION_START;
  const char *line = node->args[ARG_ERROR_LINESTR].arg.str;
  const char *message = node->args[ARG_ERROR_MESSAGE].arg.str;
  const size_t offset = node->args[ARG_ERROR_OFFSET].arg.flags;
  size_t line_len;

  WS("\\ error: ");

  W(message);

  WS(": ");

  line_len = STRLEN(line);

  if (offset < line_len) {
    if (offset) {
      W_LEN(line, offset);
    }
    WS("!!");
    W_LEN(line + offset, 1);
    WS("!!");

    W_LEN(line + offset + 1, line_len - offset - 1);
  } else {
    W_LEN(line, line_len);
    WS("!!!");
  }
  F(print_block_children, node->children, indent + 1, barnext);
  FUNCTION_END;
}

static FDEC(print_ga_strs, const garray_T *const ga,
            const char *const delim, const size_t delim_len,
            const char *const escapes)
{
  FUNCTION_START;
  const int ga_len = ga->ga_len;

  if (escapes == NULL) {
    for (int i = 0; i < ga_len ; i++) {
      W_LEN(delim, delim_len);
      W(((char **)ga->ga_data)[i]);
    }
  } else {
    for (int i = 0; i < ga_len ; i++) {
      W_LEN(delim, delim_len);
      W_ESCAPED(((char **)ga->ga_data)[i], escapes);
    }
  }
  FUNCTION_END;
}

/// Print append command family (:append, :insert, :change)
static CMD_FDEC(print_append)
{
  FUNCTION_START;
  const garray_T *const ga = &(node->args[ARG_APPEND_LINES].arg.ga_strs);
  F(print_ga_strs, ga, NEWLINE, NULL);
  W_NL;
  WC('.');
  FUNCTION_END;
}

/// Print :*map/:*unmap/:*abbrev/:*unnabbrev command family
static CMD_FDEC(print_map)
{
  FUNCTION_START;
  const uint_least32_t map_flags = node->args[ARG_MAP_FLAGS].arg.flags;

  if (map_flags) {
    WC(' ');
  }

  if (map_flags & FLAG_MAP_BUFFER) {
    WS("<buffer>");
  }
  if (map_flags & FLAG_MAP_NOWAIT) {
    WS("<nowait>");
  }
  if (map_flags & FLAG_MAP_SILENT) {
    WS("<silent>");
  }
  if (map_flags & FLAG_MAP_SPECIAL) {
    WS("<special>");
  }
  if (map_flags & FLAG_MAP_SCRIPT) {
    WS("<script>");
  }
  if (map_flags & FLAG_MAP_EXPR) {
    WS("<expr>");
  }
  if (map_flags & FLAG_MAP_UNIQUE) {
    WS("<unique>");
  }

  if (node->args[ARG_MAP_LHS].arg.str != NULL) {
    bool unmap = CMDDEF(node->type).parse == CMDDEF(kCmdUnmap).parse;
    WC(' ');

    // FIXME untranslate mappings
    W(node->args[ARG_MAP_LHS].arg.str);

    assert(node->children == NULL);
    if (unmap) {
    } else if (node->args[ARG_MAP_EXPR].arg.expr != NULL) {
      WC(' ');
      F(print_expr, node->args[ARG_MAP_EXPR].arg.expr);
    } else if (node->args[ARG_MAP_RHS].arg.str != NULL) {
      WC(' ');
      // FIXME untranslate mappings
      W(node->args[ARG_MAP_RHS].arg.str);
    }
  }
  FUNCTION_END;
}

/// Print :*mapclear/:*abclear command family
static CMD_FDEC(print_mapclear)
{
  FUNCTION_START;
  if (node->args[ARG_CLEAR_BUFFER].arg.flags) {
    WC(' ');
    WS("<buffer>");
  }
  FUNCTION_END;
}

/// Print :*menu command family
static CMD_FDEC(print_menu)
{
  FUNCTION_START;
  const uint_least32_t menu_flags = node->args[ARG_MENU_FLAGS].arg.flags;

  if (menu_flags & (FLAG_MENU_SILENT|FLAG_MENU_SPECIAL|FLAG_MENU_SCRIPT)) {
    WC(' ');
  }

  if (menu_flags & FLAG_MENU_SILENT) {
    WS("<silent>");
  }
  if (menu_flags & FLAG_MENU_SPECIAL) {
    WS("<special>");
  }
  if (menu_flags & FLAG_MENU_SCRIPT) {
    WS("<script>");
  }

  if (node->args[ARG_MENU_ICON].arg.str != NULL) {
    WC(' ');
    WS("icon=");
    W(node->args[ARG_MENU_ICON].arg.str);
  }

  if (node->args[ARG_MENU_PRI].arg.numbers != NULL) {
    const int *number = node->args[ARG_MENU_PRI].arg.numbers;

    WC(' ');

    while (*number) {
      if (*number != MENU_DEFAULT_PRI) {
        F_NOOPT(dump_unumber, (uintmax_t) *number);
      }
      number++;
      if (*number) {
        WC('.');
      }
    }
  }

  if (menu_flags & FLAG_MENU_DISABLE) {
    WC(' ');
    WS("disable");
  }
  if (menu_flags & FLAG_MENU_ENABLE) {
    WC(' ');
    WS("enable");
  }

  if (node->args[ARG_MENU_NAME].arg.menu_item != NULL) {
    F(print_menu_name, node->args[ARG_MENU_NAME].arg.menu_item);
    if (node->args[ARG_MENU_TEXT].arg.str != NULL) {
      WS("<Tab>");
      W(node->args[ARG_MENU_TEXT].arg.str);
    }
  }

  PRINT_FROM_ARG(node, ARG_MENU_RHS);
  FUNCTION_END;
}

static CMD_FDEC(print_for)
{
  FUNCTION_START;
  WC(' ');
  F(print_expr, node->args[ARG_FOR_LHS].arg.expr);
  WS(" in ");
  F(print_expr, node->args[ARG_FOR_RHS].arg.expr);
  F(print_block_children, node->children, indent + 1, barnext);
  FUNCTION_END;
}

/// Expression command family (:*echo*, :*execute*, :delfunction)
static CMD_FDEC(print_expr_cmd)
{
  FUNCTION_START;
  PRINT_FROM_ARG(node, 0);
  F(print_block_children, node->children, indent + 1, barnext);
  FUNCTION_END;
}

/// Lockvar command family (:[un]lockvar)
static CMD_FDEC(print_lockvar)
{
  FUNCTION_START;
  if (node->args[ARG_LOCKVAR_DEPTH].arg.number) {
    WC(' ');
    F_NOOPT(dump_unumber, node->args[ARG_LOCKVAR_DEPTH].arg.unumber);
  }
  WC(' ');
  F(print_expr, node->args[ARG_EXPRS_EXPRS].arg.expr);
  FUNCTION_END;
}

static CMD_FDEC(print_function)
{
  FUNCTION_START;
  if (node->args[ARG_FUNC_REG].arg.reg == NULL) {
    if (node->args[ARG_FUNC_NAME].arg.expr != NULL) {
      WC(' ');
      F(print_expr, node->args[ARG_FUNC_NAME].arg.expr);
      if (node->args[ARG_FUNC_ARGS].arg.ga_strs.ga_itemsize != 0) {
        const uint_least32_t flags = node->args[ARG_FUNC_FLAGS].arg.flags;
        const garray_T *ga = &(node->args[ARG_FUNC_ARGS].arg.ga_strs);
        SPACES_BEFORE_SUBSCRIPT2(command, function);
        WC('(');
        SPACES_AFTER_START3(command, function, call);
        for (int i = 0; i < ga->ga_len; i++) {
          W(((char **)ga->ga_data)[i]);
          if (i < ga->ga_len - 1 || flags&FLAG_FUNC_VARARGS) {
            SPACES_BEFORE3(command, function, argument);
            WC(',');
            SPACES_AFTER3(command, function, argument);
          }
        }
        if (flags&FLAG_FUNC_VARARGS) {
          WS("...");
        }
        SPACES_BEFORE_END3(command, function, call);
        WC(')');
        if (flags&FLAG_FUNC_RANGE) {
          SPACES_BEFORE_ATTRIBUTE2(command, function);
          WS("range");
        }
        if (flags&FLAG_FUNC_DICT) {
          SPACES_BEFORE_ATTRIBUTE2(command, function);
          WS("dict");
        }
        if (flags&FLAG_FUNC_ABORT) {
          SPACES_BEFORE_ATTRIBUTE2(command, function);
          WS("abort");
        }
      }
      F(print_block_children, node->children, indent + 1, barnext);
    } else {
      assert(node->children == NULL);
    }
  } else {
    assert(node->children == NULL);
  }
  FUNCTION_END;
}

static CMD_FDEC(print_let)
{
  FUNCTION_START;
  if (node->args[ARG_LET_LHS].arg.expr != NULL) {
    const LetAssignmentType ass_type =
        (LetAssignmentType) node->args[ARG_LET_ASS_TYPE].arg.flags;
    bool add_rval = true;

    WC(' ');
    F(print_expr, node->args[ARG_LET_LHS].arg.expr);
    switch (ass_type) {
      case VAL_LET_NO_ASS: {
        add_rval = false;
        break;
      }
      case VAL_LET_ASSIGN: {
        SPACES_BEFORE3(command, let, assign);
        WC('=');
        SPACES_AFTER3(command, let, assign);
        break;
      }
      case VAL_LET_ADD: {
        SPACES_BEFORE3(command, let, add);
        WS("+=");
        SPACES_AFTER3(command, let, add);
        break;
      }
      case VAL_LET_SUBTRACT: {
        SPACES_BEFORE3(command, let, subtract);
        WS("-=");
        SPACES_AFTER3(command, let, subtract);
        break;
      }
      case VAL_LET_APPEND: {
        SPACES_BEFORE3(command, let, concat);
        WS(".=");
        SPACES_AFTER3(command, let, concat);
        break;
      }
    }
    if (add_rval) {
      F(print_expr, node->args[ARG_LET_RHS].arg.expr);
    }
  }
  FUNCTION_END;
}

/// :*do command family (:argdo, :bufdo, :windo, etc)
static CMD_FDEC(print_do)
{
  FUNCTION_START;
  if (node->children) {
    W(DO_CMD_SEPARATOR);
    F(print_node, node->children, indent, true, false);
  }
  FUNCTION_END;
}

/// Modifier command family (:silent, :botright, etc)
static CMD_FDEC(print_modifier)
{
  FUNCTION_START;
  if (node->children) {
    WC(' ');
    F(print_node, node->children, indent, false, true);
  }
  FUNCTION_END;
}

static CMD_FDEC(print_simple_command)
{
  FUNCTION_START;
  PRINT_FROM_ARG(node, 0);
  if (!(CMDDEF(node->type).flags & EDITCMD)) {
    F(print_block_children, node->children, indent + 1, barnext);
  }
  FUNCTION_END;
}

static CMD_FDEC(print_autocmd)
{
  FUNCTION_START;
  PRINT_FROM_ARG(node, 0);
  if (node->args[ARG_AU_NESTED].arg.flags) {
    WS(" nested");
  }
  if (node->children) {
    W(AU_CMD_SEPARATOR);
    F(print_node, node->children, indent, true, false);
  }
  FUNCTION_END;
}

static CMD_FDEC(print_breakadd)
{
  FUNCTION_START;
  BreakType type = (BreakType) node->args[ARG_BREAK_TYPE].arg.flags;
  switch (type) {
    case kBreakInFunction: {
      WS(" func ");
      break;
    }
    case kBreakInFile: {
      WS(" file ");
      break;
    }
    case kBreakHere: {
      WS(" here");
      FUNCTION_END;
    }
    case kProfileStart: {
      WS(" start ");
      break;
    }
    case kProfilePause: {
      WS(" pause");
      FUNCTION_END;
    }
    case kProfileContinue: {
      WS(" continue");
      FUNCTION_END;
    }
  }
  if (node->range.address.type != kAddrMissing) {
    assert(node->range.address.type == kAddrFixed);
    F(print_range, &(node->range));
    WS(" ");
  }
  F(print_pattern, node->args[ARG_BREAK_NAME].arg.pat);
  FUNCTION_END;
}

static FDEC(print_complete, const CmdComplete *const complete)
{
  FUNCTION_START;
  if (complete->type == EXPAND_NOTHING) {
    EARLY_RETURN;
  }
  WS(" -complete=");
  switch (complete->type) {
    case EXPAND_USER_DEFINED: {
      WS("custom,");
      W(complete->arg);
      break;
    }
    case EXPAND_USER_LIST: {
      WS("customlist,");
      W(complete->arg);
      break;
    }
    default: {
      for (const CompleteVariant *ccomplete = &(command_complete[0]);
           ccomplete->expand != 0;
           ccomplete++) {
        if (ccomplete->expand == complete->type) {
          W(ccomplete->name);
          break;
        }
      }
      break;
    }
  }
  FUNCTION_END;
}

static CMD_FDEC(print_command)
{
  FUNCTION_START;
  uint_least32_t flags = node->args[ARG_CMD_FLAGS].arg.flags;
  if (flags & FLAG_CMD_BANG) {
    WS(" -bang");
  }
  if (flags & FLAG_CMD_BUFFER) {
    WS(" -buffer");
  }
  if (flags & FLAG_CMD_BAR) {
    WS(" -bar");
  }
  if (flags & FLAG_CMD_REGISTER) {
    WS(" -register");
  }
  switch (flags & FLAG_CMD_NARGS_MASK) {
    case VAL_CMD_NARGS_NO: {
      if (USE_EXPLICIT_NARGS) {
        WS(" -nargs=0");
      }
      break;
    }
    case VAL_CMD_NARGS_ONE: {
      WS(" -nargs=1");
      break;
    }
    case VAL_CMD_NARGS_ANY: {
      WS(" -nargs=*");
      break;
    }
    case VAL_CMD_NARGS_Q: {
      WS(" -nargs=?");
      break;
    }
    case VAL_CMD_NARGS_P: {
      WS(" -nargs=+");
      break;
    }
  }
  switch (flags & FLAG_CMD_RANGE_MASK) {
    case VAL_CMD_RANGE_NO: {
      break;
    }
    case VAL_CMD_RANGE_ALL: {
      WS(" -range=%");
      break;
    }
    case VAL_CMD_RANGE_CUR: {
      WS(" -range");
      break;
    }
    case VAL_CMD_RANGE_COUNT: {
      WS(" -range=");
      F_NOOPT(dump_number, (intmax_t) node->count);
      break;
    }
    default: {
      assert(false);
    }
  }
  switch (flags & FLAG_CMD_COUNT_MASK) {
    case VAL_CMD_COUNT_NO: {
      break;
    }
    case VAL_CMD_COUNT_EMPTY: {
      WS(" -count");
      break;
    }
    case VAL_CMD_COUNT_COUNT: {
      WS(" -count=");
      F_NOOPT(dump_number, (intmax_t) node->count);
      break;
    }
    default: {
      assert(false);
    }
  }
  if (node->args[ARG_CMD_COMPLETE].arg.complete != NULL) {
    F(print_complete, node->args[ARG_CMD_COMPLETE].arg.complete);
  }
  if (node->args[ARG_CMD_NAME].arg.str != NULL) {
    WC(' ');
    W(node->args[ARG_CMD_NAME].arg.str);
  }
  if (node->args[ARG_CMD_COMMAND].arg.str != NULL) {
    W(CMD_CMD_SEPARATOR);
    W(node->args[ARG_CMD_COMMAND].arg.str);
  }
  FUNCTION_END;
}

static CMD_FDEC(print_cbuffer)
{
  FUNCTION_START;
  if (node->args[ARG_NUMBER_NUMBER].arg.number != -1) {
    WC(' ');
    F_NOOPT(dump_number, (intmax_t) node->args[ARG_NUMBER_NUMBER].arg.number);
  }
  FUNCTION_END;
}

static CMD_FDEC(print_clist)
{
  FUNCTION_START;
  WS(" ");
  F_NOOPT(dump_number, (intmax_t) node->args[ARG_CLIST_FIRST].arg.number);
  WS(", ");
  F_NOOPT(dump_number, (intmax_t) node->args[ARG_CLIST_LAST].arg.number);
  FUNCTION_END;
}

static CMD_FDEC(print_delmarks)
{
  FUNCTION_START;
  const char *p = node->args[ARG_NAME_NAME].arg.str;
  if (p != NULL) {
    WS(" ");
    uint8_t from = 0;
    const char *const s = p;
    for (; ; p++) {
      switch (*p) {
        case 'Y': {
          if (from == 0) {
            from = (uint8_t) (FIRST_MARK_CODE + (uint8_t) (p - s));
          }
          break;
        }
        case NUL:
        case 'N': {
          if (from == 0) {
            break;
          }
          const uint8_t to = (uint8_t) ((uint8_t) FIRST_MARK_CODE
                                        + (uint8_t) (p - s) - 1);
          WC((char) from);
          if (from != to) {
            WC('-');
            WC((char) to);
          }
          from = 0;
          break;
        }
        default: {
          assert(false);
        }
      }
      if (*p == NUL) {
        break;
      }
    }
  }
  FUNCTION_END;
}

static CMD_FDEC(print_digraphs)
{
  FUNCTION_START;
  const char *const *cur_dig =
      (const char *const *) node->args[ARG_DIG_DIGRAPHS].arg.strs;
  if (cur_dig != NULL) {
    const uint_least32_t *cur_cp = node->args[ARG_DIG_CHARS].arg.unumbers;
    for (; *cur_dig != NULL; cur_dig++, cur_cp++) {
      WC(' ');
      W(*cur_dig);
      WC(' ');
      F_NOOPT(dump_unumber, (uintmax_t) *cur_cp);
    }
  }
  FUNCTION_END;
}

static CMD_FDEC(print_later)
{
  FUNCTION_START;
  WC(' ');
  F_NOOPT(dump_unumber, (uintmax_t) node->args[ARG_LATER_COUNT].arg.unumber);
  switch (node->args[ARG_LATER_FLAGS].arg.flags & FLAG_LATER_TYPE_MASK) {
    case VAL_LATER_COUNT: {
      break;
    }
#define LATER_TYPE(ch, type) \
    case VAL_LATER_##type: { \
      WC(ch); \
      break; \
    }
    LATER_TYPE('s', SECONDS)
    LATER_TYPE('m', MINUTES)
    LATER_TYPE('h', HOURS)
    LATER_TYPE('d', DAYS)
    LATER_TYPE('f', FILE)
#undef LATER_TYPE
  }
  FUNCTION_END;
}

static CMD_FDEC(print_doautocmd)
{
  FUNCTION_START;
  if (node->args[ARG_DOAU_NOMDLINE].arg.flags) {
    WS(" <nomodeline>");
  }
  PRINT_FROM_ARG(node, ARG_DOAU_GROUP);
  FUNCTION_END;
}

static CMD_FDEC(print_filetype)
{
  FUNCTION_START;
  uint_least32_t flags = node->args[ARG_FT_FLAGS].arg.flags;
  if (flags & FLAG_FT_PLUGIN) {
    WS(" plugin");
  }
  if (flags & FLAG_FT_INDENT) {
    WS(" indent");
  }
  if (flags & FLAG_FT_ON) {
    WS(" on");
  } else if (flags & FLAG_FT_DETECT) {
    WS(" detect");
  } else if (flags & FLAG_FT_OFF) {
    WS(" off");
  }
  FUNCTION_END;
}

static CMD_FDEC(print_history)
{
  FUNCTION_START;
  uint_least32_t flags = node->args[ARG_HIST_FLAGS].arg.flags;
  if ((flags & FLAG_HIST_ALL) == FLAG_HIST_ALL) {
    WS(" all");
  } else if (flags & FLAG_HIST_DEFAULT) {
    // Do nothing
  } else {
    switch (flags & FLAG_HIST_ALL) {
#define HIST_FLAG_TO_STR(flag, str, ch) \
      case flag: { \
        if (USE_HISTCHAR) { \
          WC(' '); \
          WC(ch); \
        } else { \
          WS(" " str); \
        } \
        break; \
      }
      HIST_FLAG_TO_STR(FLAG_HIST_CMD, "cmd", ':')
      HIST_FLAG_TO_STR(FLAG_HIST_SEARCH, "search", '/')
      HIST_FLAG_TO_STR(FLAG_HIST_EXPR, "expr", '=')
      HIST_FLAG_TO_STR(FLAG_HIST_INPUT, "input", '@')
      HIST_FLAG_TO_STR(FLAG_HIST_DEBUG, "debug", '>')
#undef HIST_FLAG_TO_STR
      default: {
        assert(false);
      }
    }
  }
  WC(' ');
  F_NOOPT(dump_number, (intmax_t) node->args[ARG_HIST_FIRST].arg.number);
  WS(", ");
  F_NOOPT(dump_number, (intmax_t) node->args[ARG_HIST_LAST].arg.number);
  FUNCTION_END;
}

static CMD_FDEC(print_retab)
{
  FUNCTION_START;
  if (node->count != 0) {
    WC(' ');
    F_NOOPT(dump_unumber, (uintmax_t) node->count);
  }
  FUNCTION_END;
}

static CMD_FDEC(print_resize)
{
  FUNCTION_START;
  int n = node->args[ARG_RESIZE_NUMBER].arg.number;
  if (n != 0 || node->type != kCmdTabmove) {
    WC(' ');
    if (node->args[ARG_RESIZE_FLAGS].arg.flags && n >= 0) {
      WC('+');
    }
    F_NOOPT(dump_number, (intmax_t) n);
  }
  FUNCTION_END;
}

static CMD_FDEC(print_redir)
{
  FUNCTION_START;
  uint_least32_t flags = node->args[ARG_REDIR_FLAGS].arg.flags;
  if (node->args[ARG_REDIR_VAR].arg.expr != NULL) {
    WS(" => ");
    F(print_expr, node->args[ARG_REDIR_VAR].arg.expr);
  } else if (node->args[ARG_REDIR_FILE].arg.str != NULL) {
    if (flags & FLAG_REDIR_APPEND) {
      WS(" >> ");
    } else {
      WS(" > ");
    }
    W(node->args[ARG_REDIR_FILE].arg.str);
  } else if (flags & FLAG_REDIR_REG_MASK) {
    WS(" @");
    WC((char) (flags & FLAG_REDIR_REG_MASK));
    if (flags & FLAG_REDIR_APPEND) {
      WS(">>");
    }
  } else {
    WS(" END");
  }
  FUNCTION_END;
}

static CMD_FDEC(print_script)
{
  FUNCTION_START;
  const garray_T *const ga_strs = &(node->args[ARG_APPEND_LINES].arg.ga_strs);
  if (ga_strs->ga_len == 1) {
    WC(' ');
    W(*((char **) (ga_strs->ga_data)));
  } else {
    WS(" << ");
    char *end_pattern = "EOF";
    size_t eofs = 1;
    bool allocated_end_pattern = false;
    for (size_t i = 0; i < (size_t) ga_strs->ga_len;) {
      const char *const s = ((char **) (ga_strs->ga_data))[i];
      if (STRCMP(s, end_pattern) == 0) {
        if (allocated_end_pattern) {
          xfree(end_pattern);
        }
        allocated_end_pattern = true;
        eofs++;
        end_pattern = xmallocz(eofs * 3);
        for (size_t j = 0; j < eofs; j++) {
          memcpy(end_pattern + (j * 3), "EOF", 3);
        }
        i = 0;
      } else {
        i++;
      }
    }
    W(end_pattern);
    W_NL;
    for (size_t i = 0; i < (size_t) ga_strs->ga_len; i++) {
      W(((char **) (ga_strs->ga_data))[i]);
      W_NL;
    }
    W(end_pattern);
    W_NL;
    if (allocated_end_pattern) {
      xfree(end_pattern);
    }
  }
  FUNCTION_END;
}

static CMD_FDEC(print_global)
{
  FUNCTION_START;
  switch (node->args[ARG_G_FLAGS].arg.flags) {
    case 0: {
      assert(node->args[ARG_G_REG].arg.reg != NULL);
      PRINT_FROM_ARG(node, ARG_G_REG);
      break;
    }
    case FLAG_G_RE_SUBST: {
      WS(" \\&");
      break;
    }
    case FLAG_G_RE_SEARCH: {
      WS(" \\/");
      break;
    }
    default: {
      assert(false);
    }
  }
  if (node->children) {
    W(G_CMD_SEPARATOR);
    F(print_node, node->children, indent, true, false);
  }
  FUNCTION_END;
}

static CMD_FDEC(print_vimgrep)
{
  FUNCTION_START;
  assert(node->args[ARG_VIMG_REG].arg.reg != NULL);
  WC(' ');
  F(print_regex, node->args[ARG_VIMG_REG].arg.reg, '/');
  if (node->args[ARG_VIMG_FLAGS].arg.flags & FLAG_VIMG_EVERY) {
    WC('g');
  }
  if (node->args[ARG_VIMG_FLAGS].arg.flags & FLAG_VIMG_NOJUMP) {
    WC('j');
  }
  F(print_glob_arg, node->glob);
  FUNCTION_END;
}

static CMD_FDEC(print_set)
{
  FUNCTION_START;
  char **const names = node->args[ARG_SET_OPTIONS].arg.strs;
  char **const values = node->args[ARG_SET_VALUES].arg.strs;
  const uint_least32_t *const flagss = node->args[ARG_SET_FLAGSS].arg.unumbers;
  const uint_least32_t *const keys = node->args[ARG_SET_KEYS].arg.unumbers;
  const int *const ivalues = node->args[ARG_SET_IVALUES].arg.numbers;
  const int *const opt_idxs = node->args[ARG_SET_INDEXES].arg.numbers;
  if (names == NULL) {
    EARLY_RETURN;
  }
  for (size_t i = 0; names[i] != NULL; i++) {
    WC(' ');
    uint_least32_t flags = flagss[i];
    if (flags & FLAG_SET_UNSET) {
      WS("no");
    }
    if (opt_idxs[i] >= 0) {
      char *const name = get_option_name(opt_idxs[i], SET_SHOW_SHORT);
      assert(name != NULL);
      assert(keys[i] == 0);
      W(name);
      xfree(name);
    } else {
      // TODO(ZyX-I): Use ARG_SET_KEYS to get key name.
      W(names[i]);
    }
    if (flags & FLAG_SET_DEFAULT) {
      if (flags & FLAG_SET_VI) {
        WS("&vi");
      } else if (flags & FLAG_SET_VIM) {
        WS("&vim");
      } else {
        WS("&");
      }
    } else if (flags & FLAG_SET_SHOW) {
      WS("?");
    } else if (flags & FLAG_SET_INVERT) {
      WS("!");
    } else if (flags & FLAG_SET_GLOBAL) {
      WS("<");
    } else if (flags & FLAG_SET_APPEND) {
      WS("+=");
    } else if (flags & FLAG_SET_PREPEND) {
      WS("^=");
    } else if (flags & FLAG_SET_REMOVE) {
      WS("-=");
    } else if (flags & FLAG_SET_ASSIGN) {
      WS("=");
    }
    if (flags & FLAG_SET_IVALUE) {
      F_NOOPT(dump_number, (intmax_t) ivalues[i]);
    } else if (values[i] != empty_string) {
      assert(flags & (FLAG_SET_ASSIGN
                      |FLAG_SET_REMOVE
                      |FLAG_SET_PREPEND
                      |FLAG_SET_APPEND));
      W_ESCAPED(values[i], "\"| \t\\");
    }
  }
  FUNCTION_END;
}

static CMD_FDEC(print_sleep)
{
  FUNCTION_START;
  switch (node->args[ARG_SLEEP_MULT].arg.unumber) {
    case 1000: {
      break;
    }
    case 0: {
      WC('m');
      break;
    }
    default: {
      assert(false);
    }
  }
  FUNCTION_END;
}

static CMD_FDEC(print_sub)
{
  FUNCTION_START;
  const uint_least32_t flags = node->args[ARG_S_FLAGS].arg.flags;
  char delim = NUL;
  if (flags & FLAG_S_RE_SUBST) {
    assert(node->args[ARG_S_REP].arg.rep == NULL);
    WS("\\&");
    delim = '&';
  } else if (flags & FLAG_S_RE_SEARCH) {
    assert(node->args[ARG_S_REP].arg.rep == NULL);
    WS("\\/");
    delim = '/';
  } else if (node->type == kCmdSubstitute
             || node->type == kCmdSmagic
             || node->type == kCmdSnomagic) {
    delim = '/';
    if (node->args[ARG_S_REG].arg.reg != NULL) {
      F(print_regex, node->args[ARG_S_REG].arg.reg, delim);
    } else {
      WC(delim);
      WC(delim);
    }
  } else {
    delim = '&';
    assert(node->args[ARG_S_REG].arg.reg == NULL);
    assert(node->args[ARG_S_REP].arg.rep == NULL);
  }
  assert(delim != NUL);
  const Replacement *rep = node->args[ARG_S_REP].arg.rep;
  if (flags & FLAG_S_SUB_PREV) {
    assert(rep == NULL);
    WC('%');
  } else {
    F(print_replacement, rep, (node->type == kCmdSubstitute
                               ? IS_MAGIC
                               : (node->type == kCmdSmagic)));
  }
  WC(delim);
  PRINT_FLAG('&', FLAG_S_KEEP);
  PRINT_FLAG('c', FLAG_S_CONFIRM);
  PRINT_FLAG('e', FLAG_S_NOERR);
  PRINT_FLAG('i', FLAG_S_IC);
  PRINT_FLAG('I', FLAG_S_NOIC);
  PRINT_FLAG('n', FLAG_S_COUNT);
  PRINT_FLAG('p', FLAG_S_PRINT);
  PRINT_FLAG('#', FLAG_S_PRINT_LNR);
  PRINT_FLAG('l', FLAG_S_PRINT_LIST);
  PRINT_FLAG('r', FLAG_S_R);
  if (flags & FLAG_S_G) {
    assert((flags & FLAG_S_G_REVERSE) == 0);
    WC('g');
  } else if (flags & FLAG_S_G_REVERSE) {
    WS("gg");
  }
  if (node->count > 0) {
    F_NOOPT(dump_unumber, (uintmax_t) node->count);
  }
  FUNCTION_END;
}

static CMD_FDEC(print_sort)
{
  FUNCTION_START;
  uint_least32_t flags = node->args[ARG_SORT_FLAGS].arg.flags;
  if (flags & (~FLAG_SORT_RE_SEARCH)) {
    WC(' ');
    PRINT_FLAG('n', FLAG_SORT_DECIMAL);
    PRINT_FLAG('o', FLAG_SORT_OCTAL);
    PRINT_FLAG('x', FLAG_SORT_HEX);
    PRINT_FLAG('i', FLAG_SORT_IC);
    PRINT_FLAG('r', FLAG_SORT_USEMATCH);
    PRINT_FLAG('u', FLAG_SORT_KEEPFST);
  }
  if (flags & FLAG_SORT_RE_SEARCH) {
    assert(node->args[ARG_SORT_REG].arg.reg == NULL);
    WS(" //");
  } else {
    PRINT_FROM_ARG(node, ARG_SORT_REG);
  }
  FUNCTION_END;
}

static CMD_FDEC(print_syntime)
{
  FUNCTION_START;
  switch (node->args[ARG_SYNTIME_ACTION].arg.flags) {
#define SYNTIME_ACTION(str, val) \
    case val: { \
      WS(" " str); \
      break; \
    }
    SYNTIME_ACTION("on", VAL_SYNTIME_ON)
    SYNTIME_ACTION("off", VAL_SYNTIME_OFF)
    SYNTIME_ACTION("clear", VAL_SYNTIME_CLEAR)
    SYNTIME_ACTION("report", VAL_SYNTIME_REPORT)
#undef SYNTIME_ACTION
    default: {
      assert(false);
    }
  }
  FUNCTION_END;
}

static CMD_FDEC(print_2numbers)
{
  FUNCTION_START;
  if (!node->args[ARG_2INTS_FLAGS].arg.flags) {
    WC(' ');
    F_NOOPT(dump_number, (intmax_t) node->args[ARG_2INTS_NUM1].arg.number);
    WC(' ');
    F_NOOPT(dump_number, (intmax_t) node->args[ARG_2INTS_NUM2].arg.number);
  }
  FUNCTION_END;
}

static CMD_FDEC(print_wincmd)
{
  FUNCTION_START;
  uint8_t action = (uint8_t) node->args[ARG_WINCMD_CHAR].arg.ch;
  if (action) {
    WC(' ');
    if (action & 0x80) {
      action &= (uint8_t) (~((uint8_t) 0x80));
      WC('g');
    }
    WC((char) action);
  } else {
    // Warning: second character in the below string must not be any valid
    // :wincmd action
    WS(" !");
  }
  FUNCTION_END;
}

static CMD_FDEC(print_z)
{
  FUNCTION_START;
  const char kind = node->args[ARG_Z_KIND].arg.ch;
  const uint_least32_t bigness = node->args[ARG_Z_BIGNESS].arg.unumber;
  const uint_least32_t multiplier = node->args[ARG_Z_MULTIPLIER].arg.unumber;
  if (kind == '+' || kind == '-') {
    assert(multiplier >= 1);
    for (uint_least32_t i = 0; i < multiplier; i++) {
      WC(kind);
    }
  } else {
    assert(multiplier == 0);
    if (kind) {
      WC(kind);
    }
  }
  if (bigness != 0) {
    F_NOOPT(dump_unumber, (uintmax_t) bigness);
  }
  FUNCTION_END;
}

static CMD_FDEC(print_at)
{
  FUNCTION_START;
  WC(node->args[ARG_MARK_CHAR].arg.ch);
  FUNCTION_END;
}

static CMD_FDEC(print_help)
{
  FUNCTION_START;
  if (node->args[ARG_HELP_TOPIC].arg.str != NULL) {
    WC(' ');
    W(node->args[ARG_HELP_TOPIC].arg.str);
  }
  if (node->args[ARG_HELP_LANG].arg.str != NULL) {
    assert(STRLEN(node->args[ARG_HELP_LANG].arg.str) == 2);
    if (node->args[ARG_HELP_TOPIC].arg.str == NULL) {
      WC(' ');
    }
    WC('@');
    W(node->args[ARG_HELP_LANG].arg.str);
  }
  FUNCTION_END;
}

static CMD_FDEC(print_helpgrep)
{
  FUNCTION_START;
  assert(node->args[ARG_HELPG_REG].arg.reg != NULL);
  WC(' ');
  F(print_regex, node->args[ARG_HELPG_REG].arg.reg, NUL);
  if (node->args[ARG_HELPG_LANG].arg.str != NULL) {
    assert(STRLEN(node->args[ARG_HELPG_LANG].arg.str) == 2);
    WC('@');
    W(node->args[ARG_HELPG_LANG].arg.str);
  }
  FUNCTION_END;
}

static CMD_FDEC(print_gui)
{
  FUNCTION_START;
  if (node->args[ARG_GUI_FG].arg.flags) {
    WS(" -f");
  } else {
    WS(" -b");
  }
  F(print_glob_arg, node->glob);
  FUNCTION_END;
}

static CMD_FDEC(print_mkspell)
{
  FUNCTION_START;
  if (node->args[ARG_MKS_ASCII].arg.flags) {
    WS(" -ascii");
  }
  F(print_glob_arg, node->glob);
  FUNCTION_END;
}

static CMD_FDEC(print_helptags)
{
  FUNCTION_START;
  if (node->args[ARG_HT_MAIN].arg.flags) {
    WS(" ++t");
  }
  F(print_glob_arg, node->glob);
  FUNCTION_END;
}

static CMD_FDEC(print_language)
{
  FUNCTION_START;
  switch ((LocaleType) (node->args[ARG_LANG_TYPE].arg.flags)) {
    case VAL_LANG_ALL: {
      break;
    }
    case VAL_LANG_MESSAGES: {
      WS(" messages");
      break;
    }
    case VAL_LANG_CTYPE: {
      WS(" ctype");
      break;
    }
    case VAL_LANG_TIME: {
      WS(" time");
      break;
    }
  }
  PRINT_FROM_ARG(node, ARG_LANG_LANG);
  FUNCTION_END;
}

static CMD_FDEC(print_write)
{
  FUNCTION_START;
  if (node->args[ARG_W_APPEND].arg.flags) {
    assert(node->type == kCmdUpdate || node->args[ARG_W_SHELL].arg.str == NULL);
    WS(" >>");
  }
  if (node->type != kCmdUpdate && node->args[ARG_W_SHELL].arg.str != NULL) {
    assert(node->glob.pat.type == kPatMissing);
    WS(" !");
    W(node->args[ARG_W_SHELL].arg.str);
  } else {
    F(print_glob_arg, node->glob);
  }
  FUNCTION_END;
}

static CMD_FDEC(print_loadkeymap)
{
  FUNCTION_START;
  const garray_T *ga_lhss = &(node->args[ARG_LKMAP_LHSS].arg.ga_strs);
  const garray_T *ga_rhss = &(node->args[ARG_LKMAP_RHSS].arg.ga_strs);
  const garray_T *ga_coms = &(node->args[ARG_LKMAP_COMS].arg.ga_strs);
  const size_t lines_len = (size_t) ga_lhss->ga_len;
  assert(ga_lhss->ga_len == ga_rhss->ga_len);
  assert(ga_lhss->ga_len == ga_coms->ga_len);
  for (size_t i = 0; i < lines_len; i++) {
    W_NL;
    const char *const lhs = ((char **)ga_lhss->ga_data)[i];
    const char *const rhs = ((char **)ga_rhss->ga_data)[i];
    const char *const com = ((char **)ga_coms->ga_data)[i];
    if (lhs == NULL && com == NULL) {
      // Empty line: do nothing
    } else if (lhs == NULL) {
      W(com);
    } else {
      assert(lhs != NULL && rhs != NULL);
      W(lhs);
      WC('\t');
      W(rhs);
      if (com != NULL) {
        WC('\t');
        W(com);
      }
    }
  }
  FUNCTION_END;
}

static CMD_FDEC(print_menutranslate)
{
  FUNCTION_START;
  MenuItem *from_item = node->args[ARG_MT_FROM_ITEM].arg.menu_item;
  const char *const from_text = node->args[ARG_MT_FROM_TEXT].arg.str;
  MenuItem *to_item = node->args[ARG_MT_TO_ITEM].arg.menu_item;
  const char *const to_text = node->args[ARG_MT_TO_TEXT].arg.str;
  assert(from_item != NULL);
  assert(to_item != NULL);
  assert(from_item->subitem == NULL);
  assert(to_item->subitem == NULL);
  assert(from_item->name != NULL);
  assert(to_item->name != NULL);
  F(print_menu_name, from_item);
  if (from_text != NULL) {
    WS("<Tab>");
    W(from_text);
  }
  F(print_menu_name, to_item);
  if (to_text != NULL) {
    WS("<Tab>");
    W(to_text);
  }
  FUNCTION_END;
}

static CMD_FDEC(print_cscope)
{
  FUNCTION_START;
  static const char *const cscope_command_names[] = {
    "add",
    "find",
    "help",
    "kill",
    "reset",
    "show",
  };

#ifndef CH_MACROS_DEFINE_LENGTH
  static const char *const cscope_find_chars = "sgdct efi";
#endif

  const CommandSubArgs subargs = node->args[ARG_SUBCMD].arg.args;
  const CommandArg *subargsargs = subargs.args;
  WC(' ');
  W(cscope_command_names[subargs.type]);
  if (subargs.num_args) {
    WC(' ');
    CscopeArgType subargs_type = (CscopeArgType) subargs.type;
    switch (subargs_type) {
      case kCscopeAdd: {
        W(subargsargs[CSCOPE_ARG_ADD_PATH].arg.str);
        if (subargsargs[CSCOPE_ARG_ADD_PRE_PATH].arg.str != NULL) {
          WC(' ');
          W(subargsargs[CSCOPE_ARG_ADD_PRE_PATH].arg.str);
        }
        if (subargsargs[CSCOPE_ARG_ADD_FLAGS].arg.str != NULL) {
          WC(' ');
          W(subargsargs[CSCOPE_ARG_ADD_FLAGS].arg.str);
        }
        break;
      }
      case kCscopeFind: {
        WC(cscope_find_chars[subargsargs[CSCOPE_ARG_FIND_TYPE].arg.flags]);
        WC(' ');
        W(subargsargs[CSCOPE_ARG_FIND_NAME].arg.str);
        break;
      }
      default: {
        assert(false);
      }
    }
  }
  FUNCTION_END;
}

static CMD_FDEC(print_sniff)
{
  FUNCTION_START;
  if (node->args[ARG_SNIFF_DEF].arg.str != NULL) {
    WS(" addcmd");
  }
  PRINT_FROM_ARG(node, 0);
  FUNCTION_END;
}

static FDEC(print_prop_str_p, const char *const p)
{
  FUNCTION_START;
  bool needs_quote = false;
  if (strpbrk(p, " \t" ENDS_EXCMD_CHARS) != NULL) {
    WC('\'');
    needs_quote = true;
  }
  W(p);
  if (needs_quote) {
    WC('\'');
  }
  FUNCTION_END;
}

static FDEC(print_prop_str, const CommandArg arg)
{
  FUNCTION_START;
  F(print_prop_str_p, arg.arg.str);
  FUNCTION_END;
}

static FDEC(print_color, const CommandArg arg)
{
  FUNCTION_START;
  const HighlightColor color = arg.arg.color;
  switch (color.type) {
    case kHiColorName: {
      F(print_prop_str_p, color.data.name);
      break;
    }
    case kHiColorRGB: {
      char color_repr[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
#ifndef CH_MACROS_DEFINE_LENGTH
      snprintf(&(color_repr[0]), sizeof(color_repr), "#%02X%02X%02X",
               color.data.rgb.red, color.data.rgb.green, color.data.rgb.blue);
#endif
      W_LEN(color_repr, sizeof(color_repr) - 1);
      break;
    }
    case kHiColorIdx: {
      F_NOOPT(dump_unumber, (uintmax_t) color.data.idx);
      break;
    }
    case kHiColorFg: {
      WS("fg");
      break;
    }
    case kHiColorBg: {
      WS("bg");
      break;
    }
    case kHiColorNone: {
      WS("None");
      break;
    }
  }
  FUNCTION_END;
}

static FDEC(print_attr_flags, const CommandArg arg)
{
  FUNCTION_START;
  const uint_least32_t attr_flags = arg.arg.flags;
  if (attr_flags == 0) {
    EARLY_RETURN;
  }
  bool did_comma = true;
  for (const HighlightAttrDef *cur_hl_attr = &(hl_attr_table[0]);
       cur_hl_attr->hl_attr_name != NULL;
       cur_hl_attr++) {
    if (attr_flags & cur_hl_attr->hl_attr_flag
        // Protect from printing both inverse and reverse.
        && cur_hl_attr->hl_attr_flag != (cur_hl_attr + 1)->hl_attr_flag) {
      if (!did_comma) {
        WC(',');
      }
      W_LEN(cur_hl_attr->hl_attr_name, cur_hl_attr->hl_attr_name_len);
      did_comma = false;
    }
  }
  FUNCTION_END;
}

typedef FDEC_TYPEDEF(HiPropertyDumperFunc, CommandArg arg);

static CMD_FDEC(print_highlight)
{
  FUNCTION_START;
  const uint_least32_t flags = node->args[ARG_HI_FLAGS].arg.flags;
  if (flags & FLAG_HI_DEFAULT) {
    WS(" default");
  }
  if (flags & FLAG_HI_CLEAR) {
    WS(" clear");
  }
  if (flags & FLAG_HI_LINK) {
    WS(" link");
  }
  if (node->args[ARG_HI_GROUP].arg.str != NULL) {
    WC(' ');
    W(node->args[ARG_HI_GROUP].arg.str);
  }
  if (flags & FLAG_HI_LINK) {
    assert(node->args[ARG_HI_TGT_GROUP].arg.str != NULL);
    WC(' ');
    W(node->args[ARG_HI_TGT_GROUP].arg.str);
    FUNCTION_END;
  } else {
    assert(node->args[ARG_HI_TGT_GROUP].arg.str == NULL);
  }
  if (flags & FLAG_HI_CLEAR) {
    FUNCTION_END;
  }
  static const PropertyDef prop_table[] = {
    { (VoidFuncRef) FNAME(print_attr_flags), "term", ARG_HI_TERM },
    { (VoidFuncRef) FNAME(print_attr_flags), "cterm", ARG_HI_CTERM },
    { (VoidFuncRef) FNAME(print_color), "ctermfg", ARG_HI_CTERMFG },
    { (VoidFuncRef) FNAME(print_color), "ctermbg", ARG_HI_CTERMBG },
    { (VoidFuncRef) FNAME(print_attr_flags), "gui", ARG_HI_GUI },
    { (VoidFuncRef) FNAME(print_color), "guifg", ARG_HI_GUIFG },
    { (VoidFuncRef) FNAME(print_color), "guibg", ARG_HI_GUIBG },
    { (VoidFuncRef) FNAME(print_color), "guisp", ARG_HI_GUISP },
    { (VoidFuncRef) FNAME(print_prop_str), "font", ARG_HI_FONT },
    { (VoidFuncRef) FNAME(print_prop_str), "start", ARG_HI_START },
    { (VoidFuncRef) FNAME(print_prop_str), "stop", ARG_HI_STOP },
    { NULL, NULL, -1 },
  };
  CommandArg reference;
  memset(&reference, 0, sizeof(reference));
  for (const PropertyDef *prop_def = &(prop_table[0]);
       prop_def->prop_dump != NULL;
       prop_def++) {
    const CommandArg arg = node->args[prop_def->prop_idx];
    if (memcmp(&reference, &arg, sizeof(CommandArg)) == 0) {
      continue;
    } else {
      WC(' ');
      W(prop_def->prop_name);
      WC('=');
      F_PTR(((FTYPE(HiPropertyDumperFunc)) (prop_def->prop_dump)), arg);
    }
  }
  FUNCTION_END;
}

static CMD_FDEC(print_sign)
{
  FUNCTION_START;
  static const char *const sign_command_names[] = {
    "define",
    "undefine",
    "list",
    "place",
    "unplace",
    "jump",
  };

  const CommandSubArgs subargs = node->args[ARG_SUBCMD].arg.args;
  const CommandArg *subargsargs = subargs.args;
  WC(' ');
  W(sign_command_names[subargs.type]);
  if (subargs.num_args) {
    SignArgType subargs_type = (SignArgType) subargs.type;
    switch (subargs_type) {
      case kSignList:
      case kSignUndefine:
      case kSignDefine: {
        if (subargsargs[SIGN_ARG_DEFINE_NAME].arg.str != NULL) {
          WC(' ');
          W(subargsargs[SIGN_ARG_DEFINE_NAME].arg.str);
        }
        if (subargs_type == kSignDefine) {
          if (subargsargs[SIGN_ARG_DEFINE_TEXTHL].arg.str != NULL) {
            WS(" texthl=");
            W(subargsargs[SIGN_ARG_DEFINE_TEXTHL].arg.str);
          }
          if (subargsargs[SIGN_ARG_DEFINE_LINEHL].arg.str != NULL) {
            WS(" linehl=");
            W(subargsargs[SIGN_ARG_DEFINE_LINEHL].arg.str);
          }
          if (subargsargs[SIGN_ARG_DEFINE_TEXT].arg.str != NULL) {
            WS(" text=");
            W(subargsargs[SIGN_ARG_DEFINE_TEXT].arg.str);
          }
          if (subargsargs[SIGN_ARG_DEFINE_ICON].arg.str != NULL) {
            WS(" icon=");
            W(subargsargs[SIGN_ARG_DEFINE_ICON].arg.str);
          }
        }
        break;
      }
      case kSignPlace:
      case kSignUnplace:
      case kSignJump: {
        if (subargsargs[SIGN_ARG_PLACE_ID].arg.number != SIGN_ID_MISSING) {
          if (subargsargs[SIGN_ARG_PLACE_ID].arg.number == SIGN_ID_ALL) {
            WS(" *");
          } else if (subargsargs[SIGN_ARG_PLACE_ID].arg.number) {
            WC(' ');
            F_NOOPT(dump_unumber,
                    (uintmax_t) subargsargs[SIGN_ARG_PLACE_ID].arg.number);
          }
        }
        if (subargs_type == kSignPlace) {
          if (subargsargs[SIGN_ARG_PLACE_LINE].arg.unumber) {
            WS(" line=");
            F_NOOPT(dump_unumber,
                    (uintmax_t) subargsargs[SIGN_ARG_PLACE_LINE].arg.unumber);
          }
          if (subargsargs[SIGN_ARG_PLACE_NAME].arg.str != NULL) {
            WS(" name=");
            W(subargsargs[SIGN_ARG_PLACE_NAME].arg.str);
          }
        }
        if (subargsargs[SIGN_ARG_PLACE_FILE].arg.str != NULL) {
          WS(" file=");
          W(subargsargs[SIGN_ARG_PLACE_FILE].arg.str);
        } else if (subargsargs[SIGN_ARG_PLACE_BUFFER].arg.unumber) {
          WS(" buffer=");
          F_NOOPT(dump_unumber,
                  (uintmax_t) subargsargs[SIGN_ARG_PLACE_BUFFER].arg.unumber);
        }
        break;
      }
    }
  }
  FUNCTION_END;
}

static FDEC(print_group_list, const SynGroupList *const group, const char delim)
{
  FUNCTION_START;
  if (group == NULL) {
    EARLY_RETURN;
  }
  for (const SynGroupList *cur_group = group;
       cur_group != NULL;
       cur_group = cur_group->next) {
    switch (cur_group->type) {
      case kSynGroupCluster: {
        WC('@');
        // fallthrough
      }
      case kSynGroupLiteral: {
        W(cur_group->data.name);
        break;
      }
      case kSynGroupRegex: {
        F(print_regex, cur_group->data.regex, NUL);
        break;
      }
      case kSynGroupAll: {
        if (cur_group->next != NULL) {
          W("ALLBUT");
        } else {
          W("ALL");
        }
        break;
      }
      case kSynGroupTop: {
        W("TOP");
        break;
      }
      case kSynGroupContained: {
        W("CONTAINED");
        break;
      }
    }
    if (cur_group->next != NULL) {
      WC(delim);
    }
  }
  FUNCTION_END;
}

static FDEC(print_syn_options, const int flags_offset,
            const CommandArg *const subargsargs,
            const uint_least32_t scope)
{
  FUNCTION_START;
  const uint_least32_t flags =
      subargsargs[flags_offset + SYN_ARG_FLAGS_OFFSET].arg.flags;
  static const struct {
    const uint_least32_t flag;
    const char *const str;
  } flags_tab[] = {
    { FLAG_SYN_MAIN_CONTAINED, "contained" },
    { FLAG_SYN_MAIN_ONELINE, "oneline" },
    { FLAG_SYN_REGION_KEEPEND, "keepend" },
    { FLAG_SYN_MR_EXTEND, "extend" },
    { FLAG_SYN_MR_EXCLUDENL, "excludenl" },
    { FLAG_SYN_MAIN_TRANSPARENT, "transparent" },
    { FLAG_SYN_MAIN_SKIPNL, "skipnl" },
    { FLAG_SYN_MAIN_SKIPWHITE, "skipwhite" },
    { FLAG_SYN_MAIN_SKIPEMPTY, "skipempty" },
    { FLAG_SYN_MAIN_DISPLAY, "display" },
    { FLAG_SYN_MAIN_FOLD, "fold" },
    { FLAG_SYN_MAIN_CONCEAL, "conceal" },
    { FLAG_SYN_REGION_CONCEALENDS, "concealends" },
    { FLAG_SYN_SYNC_FROMSTART, "fromstart" },
  };
  for (size_t i = 0; i < ARRAY_SIZE(flags_tab); i++) {
    if (flags & flags_tab[i].flag) {
      WC(' ');
      W(flags_tab[i].str);
    }
  }
  if (scope & SYN_SCOPE_SYNC) {
    if (subargsargs[flags_offset + SYN_ARG_GROUPHERE_OFFSET].arg.str != NULL) {
      WS(" grouphere ");
      W(subargsargs[flags_offset + SYN_ARG_GROUPHERE_OFFSET].arg.str);
    }
    if (subargsargs[flags_offset + SYN_ARG_GROUPTHERE_OFFSET].arg.str != NULL) {
      WS(" groupthere ");
      W(subargsargs[flags_offset + SYN_ARG_GROUPTHERE_OFFSET].arg.str);
    }
  }
  if (subargsargs[flags_offset + SYN_ARG_CCHAR_OFFSET].arg.str != NULL) {
    WS(" cchar=");
    W(subargsargs[flags_offset + SYN_ARG_CCHAR_OFFSET].arg.str);
  }
  if (scope & SYN_SCOPE_MR
      && (subargsargs[flags_offset + SYN_ARG_CONTAINS_OFFSET].arg.group
          != NULL)) {
    WS(" contains=");
    F(print_group_list,
      subargsargs[flags_offset + SYN_ARG_CONTAINS_OFFSET].arg.group, ',');
  }
  if (subargsargs[flags_offset + SYN_ARG_CONTAINEDIN_OFFSET].arg.group
      != NULL) {
    WS(" containedin=");
    F(print_group_list,
      subargsargs[flags_offset + SYN_ARG_CONTAINEDIN_OFFSET].arg.group, ',');
  }
  if (subargsargs[flags_offset + SYN_ARG_NEXTGROUP_OFFSET].arg.group != NULL) {
    WS(" nextgroup=");
    F(print_group_list,
      subargsargs[flags_offset + SYN_ARG_NEXTGROUP_OFFSET].arg.group, ',');
  }
  FUNCTION_END;
}

static FDEC(print_syn_pattern, const SynPattern syn_pat)
{
  FUNCTION_START;
  F(print_regex, syn_pat.reg, '/');
  const uint_least32_t *flagss = syn_pat.flagss;
  const int *offs = syn_pat.offsets;
#ifndef CH_MACROS_DEFINE_LENGTH
  static const char *const spos[] = {
    "ms=",
    "me=",
    "hs=",
    "he=",
    "rs=",
    "re=",
    "lc=",
  };
#endif
  for (size_t i = 0; i < syn_pat.offset_count; flagss++, offs++, i++) {
    W_LEN(spos[((*flagss) & FLAG_SYN_OFFSET_MASK) - 1], 3);
    switch ((SynRegOffsetAnchorType)
            ((*flagss) & (~((uint_least32_t) FLAG_SYN_OFFSET_MASK)))) {
      case kSynRegOffsetAnchorStart: {
        WC('s');
        if (*offs > 0) {
          WC('+');
        }
        break;
      }
      case kSynRegOffsetAnchorEnd: {
        WC('e');
        if (*offs > 0) {
          WC('+');
        }
        break;
      }
      case kSynRegOffsetAnchorLC: {
        break;
      }
    }
    if (*offs) {
      F_NOOPT(dump_number, (intmax_t) (*offs));
    }
    if (i < syn_pat.offset_count - 1) {
      WC(',');
    }
  }
  FUNCTION_END;
}

static FDEC(print_syn_patterns, const char *const prefix,
            const SynPatterns *const syn_pats)
{
  FUNCTION_START;
  const size_t prefix_len = STRLEN(prefix);
  for (const SynPatterns *cur_syn_pats = syn_pats;
       cur_syn_pats != NULL;
       cur_syn_pats = cur_syn_pats->next) {
    W_LEN(prefix, prefix_len);
    F(print_syn_pattern, cur_syn_pats->syn_pat);
  }
  FUNCTION_END;
}

static FDEC(print_syntax_match, const CommandArg *const subargsargs,
            const uint_least32_t scope)
{
  FUNCTION_START;
  WC(' ');
  W(subargsargs[SYN_ARG_MATCH_GROUP].arg.str);
  WC(' ');
  F(print_syn_pattern, *subargsargs[SYN_ARG_MATCH_REGEX].arg.syn_pat);
  F(print_syn_options, SYN_ARG_KEYWORD_FLAGS, subargsargs, scope);
  FUNCTION_END;
}

static FDEC(print_syntax_region, const CommandArg *const subargsargs)
{
  FUNCTION_START;
  WC(' ');
  W(subargsargs[SYN_ARG_REGION_GROUP].arg.str);
  if (subargsargs[SYN_ARG_REGION_MATCHGROUP].arg.str) {
    WS(" matchgroup=");
    W(subargsargs[SYN_ARG_REGION_MATCHGROUP].arg.str);
  }
  F(print_syn_patterns, " start=",
    subargsargs[SYN_ARG_REGION_STARTREG].arg.syn_pats);
  if (subargsargs[SYN_ARG_REGION_SKIPREG].arg.reg != NULL) {
    F(print_syn_patterns, " skip=",
      subargsargs[SYN_ARG_REGION_SKIPREG].arg.syn_pats);
  }
  F(print_syn_patterns, " end=",
    subargsargs[SYN_ARG_REGION_ENDREG].arg.syn_pats);
  F(print_syn_options, SYN_ARG_KEYWORD_FLAGS, subargsargs, SYN_SCOPE_REGION);
  FUNCTION_END;
}

static CMD_FDEC(print_syntax)
{
  FUNCTION_START;
  const CommandSubArgs subargs = node->args[ARG_SUBCMD].arg.args;
  const CommandArg *const subargsargs = subargs.args;
  static const char *const syn_command_names[] = {
    "case",
    "clear",
    "cluster",
    "conceal",
    "enable",
    "include",
    "keyword",
    "list",
    "manual",
    "match",
    "on",
    "off",
    "region",
    "reset",
    "spell",
    "sync",
  };
  WC(' ');
  W(syn_command_names[subargs.type]);
  switch ((SynArgType) subargs.type) {
    case kSynEnable:
    case kSynManual:
    case kSynOn:
    case kSynOff:
    case kSynReset: {
      assert(subargsargs == NULL);
      break;
    }
    case kSynCase: {
      if (subargsargs[SYN_ARG_CASE_FLAGS].arg.flags) {
        W(" match");
      } else {
        W(" ignore");
      }
      break;
    }
    case kSynConceal: {
      if (subargsargs[SYN_ARG_CONCEAL_FLAGS].arg.flags) {
        W(" on");
      } else {
        W(" off");
      }
      break;
    }
    case kSynSpell: {
      switch (subargsargs[SYN_ARG_CONCEAL_FLAGS].arg.flags) {
        case VAL_SYN_SPELL_TOPLEVEL: {
          W(" toplevel");
          break;
        }
        case VAL_SYN_SPELL_NOTOPLEVEL: {
          W(" notoplevel");
          break;
        }
        case VAL_SYN_SPELL_DEFAULT: {
          W(" default");
          break;
        }
      }
      break;
    }
    case kSynCluster: {
      static const struct {
        const int prop_idx;
        const char *prop_name;
      } cluster_props[] = {
        { SYN_ARG_CLUSTER_CONTAINS, " contains" },
        { SYN_ARG_CLUSTER_ADD, " add" },
        { SYN_ARG_CLUSTER_REMOVE, " remove" },
      };
      WC(' ');
      W(subargsargs[SYN_ARG_CLUSTER_NAME].arg.str);
      for (size_t i = 0; i < ARRAY_SIZE(cluster_props); i++) {
        const SynGroupList *group =
            subargsargs[cluster_props[i].prop_idx].arg.group;
        if (group != NULL) {
          W(cluster_props[i].prop_name);
          WC('=');
          F(print_group_list, group, ',');
        }
      }
      break;
    }
    case kSynInclude: {
      WC(' ');
      if (subargsargs[SYN_ARG_INCLUDE_CLUSTER].arg.str != NULL) {
        WC('@');
        W(subargsargs[SYN_ARG_INCLUDE_CLUSTER].arg.str);
        WC(' ');
      }
      F(print_pattern, subargsargs[SYN_ARG_INCLUDE_FILE].arg.pat);
      break;
    }
    case kSynKeyword: {
      WC(' ');
      W(subargsargs[SYN_ARG_KEYWORD_GROUP].arg.str);
      F(print_syn_options, SYN_ARG_KEYWORD_FLAGS, subargsargs,
        SYN_SCOPE_KEYWORD);
      F(print_ga_strs, &(subargsargs[SYN_ARG_KEYWORD_KEYWORDS].arg.ga_strs),
        " ", 1, " \t");
      break;
    }
    case kSynClear:
    case kSynList: {
      if (subargsargs == NULL) {
        break;
      }
      const SynGroupList *group = subargsargs[SYN_ARG_LIST_GROUPS].arg.group;
      if (group) {
        WC(' ');
        F(print_group_list, group, ' ');
      }
      break;
    }
    case kSynMatch: {
      F(print_syntax_match, subargsargs, SYN_SCOPE_MATCH);
      break;
    }
    case kSynRegion: {
      F(print_syntax_region, subargsargs);
      break;
    }
    case kSynSync: {
      const uint_least32_t flags = subargsargs[SYN_ARG_SYNC_FLAGS].arg.flags;
      if (subargsargs[SYN_ARG_SYNC_CCOMMENT].arg.str != NULL) {
        WS(" ccomment ");
        W(subargsargs[SYN_ARG_SYNC_CCOMMENT].arg.str);
      }
      if (flags & FLAG_SYN_SYNC_HASMINLINES) {
        WS(" minlines=");
        F_NOOPT(dump_unumber,
                (uintmax_t) subargsargs[SYN_ARG_SYNC_MINLINES].arg.unumber);
      }
      if (flags & FLAG_SYN_SYNC_HASMAXLINES) {
        WS(" maxlines=");
        F_NOOPT(dump_unumber,
                (uintmax_t) subargsargs[SYN_ARG_SYNC_MAXLINES].arg.unumber);
      }
      if (flags & FLAG_SYN_SYNC_HASLINEBREAKS) {
        WS(" linebreaks=");
        F_NOOPT(dump_unumber,
                (uintmax_t) subargsargs[SYN_ARG_SYNC_LINEBREAKS].arg.unumber);
      }
      if (flags & FLAG_SYN_SYNC_FROMSTART) {
        WS(" fromstart");
      }
      if (subargsargs[SYN_ARG_SYNC_REGEX].arg.reg != NULL) {
        WS(" linecont ");
        F(print_regex, subargsargs[SYN_ARG_SYNC_REGEX].arg.reg, '/');
      }
      if (subargsargs[SYN_ARG_SYNC_CMD].arg.args.num_args) {
        switch (subargsargs[SYN_ARG_SYNC_CMD].arg.args.type) {
          case kSynMatch: {
            WS(" match");
            F(print_syntax_match, subargsargs[SYN_ARG_SYNC_CMD].arg.args.args,
              SYN_SCOPE_MATCH|SYN_SCOPE_SYNC);
            break;
          }
          case kSynRegion: {
            WS(" region");
            F(print_syntax_region, subargsargs[SYN_ARG_SYNC_CMD].arg.args.args);
            break;
          }
          case kSynClear: {
            const SynGroupList *group = (subargsargs[SYN_ARG_SYNC_CMD].arg.args
                                         .args[SYN_ARG_CLEAR_GROUPS].arg.group);
            WS(" clear");
            if (group) {
              WC(' ');
              F(print_group_list, group, ' ');
            }
            break;
          }
          default: {
            assert(false);
          }
        }
      }
      break;
    }
  }
  FUNCTION_END;
}

#undef PRINT_FLAG
#undef CMD_FDEC

static FDEC(print_node,
            const CommandNode *const node,
            const size_t indent,
            const bool barnext,
            const bool ignore_first_indent)
{
  FUNCTION_START;
#define CMD_F(f) F(f, node, indent, barnext)
  if (node == NULL) {
    EARLY_RETURN;
  }

  if (!barnext && !ignore_first_indent) {
    WINDENT(indent);
  }

  if (CMDDEF(node->type).parse != CMDDEF(kCmdBreakadd).parse) {
    F(print_range, &(node->range));
  }
  F(print_node_name, node->type, node->name, node->bang);
  F(print_optflags, node->optflags, node->enc);

  if (CMDDEF(node->type).flags & EDITCMD && node->children) {
    F(print_plus_cmd, node->children);
  }

  F(print_register, node->reg);
  F(print_count, node);
  F(print_exflags, node->exflags);
  if (CMDDEF(node->type).flags & (XFILE|BUFNAME)) {
    F(print_glob_arg, node->glob);
  }

  if (node->type == kCmdSyntaxError) {
    CMD_F(print_syntax_error);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdAppend).parse) {
    CMD_F(print_append);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdMap).parse
             || CMDDEF(node->type).parse == CMDDEF(kCmdUnmap).parse) {
    CMD_F(print_map);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdMapclear).parse) {
    CMD_F(print_mapclear);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdMenu).parse) {
    CMD_F(print_menu);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdFor).parse) {
    CMD_F(print_for);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdCaddexpr).parse
             || CMDDEF(node->type).parse == CMDDEF(kCmdEcho).parse
             || CMDDEF(node->type).parse == CMDDEF(kCmdDelfunction).parse) {
    CMD_F(print_expr_cmd);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdLockvar).parse) {
    CMD_F(print_lockvar);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdFunction).parse) {
    CMD_F(print_function);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdLet).parse) {
    CMD_F(print_let);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdArgdo).parse) {
    CMD_F(print_do);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdAutocmd).parse) {
    CMD_F(print_autocmd);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdBreakadd).parse) {
    CMD_F(print_breakadd);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdCaddbuffer).parse) {
    CMD_F(print_cbuffer);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdClist).parse) {
    CMD_F(print_clist);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdCommand).parse) {
    CMD_F(print_command);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdDelmarks).parse) {
    CMD_F(print_delmarks);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdDigraphs).parse) {
    CMD_F(print_digraphs);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdDoautocmd).parse) {
    CMD_F(print_doautocmd);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdLater).parse) {
    CMD_F(print_later);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdFiletype).parse) {
    CMD_F(print_filetype);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdHistory).parse) {
    CMD_F(print_history);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdRetab).parse) {
    CMD_F(print_retab);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdResize).parse) {
    CMD_F(print_resize);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdRedir).parse) {
    CMD_F(print_redir);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdRuby).parse) {
    CMD_F(print_script);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdGlobal).parse) {
    CMD_F(print_global);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdVimgrep).parse) {
    CMD_F(print_vimgrep);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdSet).parse) {
    CMD_F(print_set);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdSleep).parse) {
    CMD_F(print_sleep);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdSubstitute).parse) {
    CMD_F(print_sub);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdSort).parse) {
    CMD_F(print_sort);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdSyntime).parse) {
    CMD_F(print_syntime);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdWinsize).parse) {
    CMD_F(print_2numbers);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdWincmd).parse) {
    CMD_F(print_wincmd);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdZ).parse) {
    CMD_F(print_z);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdAt).parse) {
    CMD_F(print_at);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdHelp).parse) {
    CMD_F(print_help);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdHelpgrep).parse) {
    CMD_F(print_helpgrep);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdGui).parse) {
    CMD_F(print_gui);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdMkspell).parse) {
    CMD_F(print_mkspell);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdHelptags).parse) {
    CMD_F(print_helptags);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdLanguage).parse) {
    CMD_F(print_language);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdWrite).parse) {
    CMD_F(print_write);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdLoadkeymap).parse) {
    CMD_F(print_loadkeymap);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdMenutranslate).parse) {
    CMD_F(print_menutranslate);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdCscope).parse) {
    CMD_F(print_cscope);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdSniff).parse) {
    CMD_F(print_sniff);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdHighlight).parse) {
    CMD_F(print_highlight);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdSign).parse) {
    CMD_F(print_sign);
  } else if (CMDDEF(node->type).parse == CMDDEF(kCmdSyntax).parse) {
    CMD_F(print_syntax);
  } else if (CMDDEF(node->type).flags & ISMODIFIER) {
    CMD_F(print_modifier);
  } else {
    CMD_F(print_simple_command);
  }

  if (node->next != NULL) {
    if (barnext) {
      WS(" | ");
    } else {
      W_NL;
    }
    F(print_node, node->next, indent, barnext, false);
  }

#undef CMD_F
  FUNCTION_END;
}

#undef CH_MACROS_OPTIONS_TYPE

#endif  // NVIM_VIML_PRINTER_EX_COMMANDS_C_H
