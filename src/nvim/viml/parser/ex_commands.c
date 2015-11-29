// vim: ts=8 sts=2 sw=2 tw=80

//
// Copyright 2014 Nikolay Pavlov

// ex_commands.c: Ex commands parsing

#include <stddef.h>
#include <stdbool.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>

#include "nvim/vim.h"
#include "nvim/types.h"
#include "nvim/memory.h"
#include "nvim/strings.h"
#include "nvim/misc2.h"
#include "nvim/charset.h"
#include "nvim/globals.h"
#include "nvim/garray.h"
#include "nvim/getchar.h"
#include "nvim/farsi.h"
#include "nvim/menu.h"
#include "nvim/regexp.h"
#include "nvim/ascii.h"
#include "nvim/ex_getln.h"
#include "nvim/ex_docmd.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/digraph.h"
#include "nvim/assert.h"

#include "nvim/viml/parser/expressions.h"
#include "nvim/viml/parser/ex_commands.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
// FIXME should include fileio.h, but this spawns lots of errors
int check_nomodeline(char_u **argp);
# include "auevents_enum.generated.h"
# include "viml/parser/auevents_find.generated.h"
#endif

#define getdigits(arg) getdigits((char_u **) (arg))
#define getdigits_int(arg) getdigits_int((char_u **) (arg))
#define getdigits_long(arg) getdigits_long((char_u **) (arg))
#define skipwhite(arg) (char *) skipwhite((char_u *) (arg))
#define skipdigits(arg) (char *) skipdigits((char_u *) (arg))
#define mb_ptr_adv_(p) p += has_mbyte ? (*mb_ptr2len)((const char_u *) p) : 1
#define mb_ptr2len(p) ((size_t) mb_ptr2len((const char_u *) p))
#define mb_ptr2char(p) (mb_ptr2char((const char_u *) p))
#define mb_ptr2cells(p) ((size_t) mb_ptr2cells((const char_u *) p))
#define enc_canonize(p) (char *) enc_canonize((char_u *) (p))
#define check_ff_value(p) check_ff_value((char_u *) (p))
#define replace_termcodes(a, b, c, d, e, f, g) \
    (char *) replace_termcodes((const char_u *) a, b, (char_u **) c, d, e, f, g)
#define lrswap(s) lrswap((char_u *) s)
#define backslash_halve(s) backslash_halve((char_u *) s)
#define get_list_range(pp, i1, i2) get_list_range((char_u **)pp, i1, i2)
#define skiptowhite(p) (const char *) skiptowhite((char_u *) p)
#define skiptowhite_esc(p) (const char *) skiptowhite_esc((char_u *) p)
#define check_nomodeline(p) check_nomodeline((char_u **) p)
#define get_histtype(p, len, d) get_histtype((const char_u *) p, len, d)
#define find_key_option_len(p, l) find_key_option_len((const char_u *) p, len)
#define findoption_len(p, l) findoption_len((const char_u *) p, l)
#define vim_str2nr(p, ...) vim_str2nr((const char_u *) (p), __VA_ARGS__)
#define string_to_key(p) string_to_key((char_u *) (p))
#define mb_cptr2char_adv(p) mb_cptr2char_adv((char_u **) (p))

#define CPO_SUBPC(state) ((state)->o.flags&FLAG_POC_CPO_SUBPC)
#define MAGIC(state) ((state)->o.flags&FLAG_POC_MAGIC)
#define COL(state) (state->position.col + (size_t) (state->cmdp - state->s))
#define P_COL(state, p) (COL(state) + (size_t) ((p) - state->cmdp))
#define ENDPOS(state, endcol) (CommandPosition) { state->position.lnr, endcol }

#define CMD_P_ARGS \
    CommandParserState *const state, \
    CommandParserResult *const ret_parsed
#define CMD_SUBP_ARGS \
    CMD_P_ARGS, \
    CommandArg *const subargsargs

typedef int (*SubCommandParser)(CMD_SUBP_ARGS);

#define RET_PARSED_CMD_ALLOC(ret_parsed, type, position) \
    ret_parsed->node = *ret_parsed->cur_node = cmd_alloc(type, (position));
#define RET_PARSED_FREE_NODE(ret_parsed) \
    do { \
      free_cmd(*ret_parsed->cur_node); \
      ret_parsed->main_node = ret_parsed->node = *ret_parsed->cur_node = NULL; \
    } while (0)

#define SUBARGS(m) \
    (sizeof((CommandArgType[]) m)/sizeof(CommandArgType)), (CommandArgType[]) m
#define EMPTY_SUBARGS 0, NULL
#define SS(s) s, (sizeof(s) - 1)

/// List of syntax options types
typedef enum {
  kSynOptFlag,     ///< Bit flag.
  kSynOptGroups,   ///< Group list.
  kSynOptSGroups,  ///< Group list with special groups like ALL allowed.
  kSynOptCharStr,  ///< char * string, containing one character (for cchar).
  kSynOptGroup,    ///< One group name (for group[t]here).
} SynOptType;

typedef struct {
  const char *name;
  SynOptType type;
  int offset;
  uint_least32_t flag;
  uint_least32_t acceted_commands;
} SynOptDef;

#define SYN_FLAG_OPT(name_str, accepted_in, name) \
    { name_str, \
      kSynOptFlag, \
      SYN_ARG_FLAGS_OFFSET, \
      FLAG_SYN_##accepted_in##_##name, \
      SYN_SCOPE_##accepted_in }
#define SYN_OPT(name_str, type, accepted_in, name) \
    { name_str, \
      kSynOpt##type, \
      SYN_ARG_##name##_OFFSET, \
      0, \
      SYN_SCOPE_##accepted_in }
#define SYN_GROUP_OPT(name_str, accepted_in, name) \
    { name_str, \
      kSynOptGroup, \
      SYN_ARG_##name##_OFFSET, \
      0, \
      SYN_SCOPE_##accepted_in }

typedef struct {
  const char *name;
  SynRegOffsetType type;
} SpoDef;

typedef struct {
  const char *name;
  size_t name_len;
  unsigned type;
  size_t num_args;
  const CommandArgType *types;
  const SubCommandParser parse;
} SubCommandDefinition;

/// Definition of the block command
typedef struct {
  CommandType same_group_type;    ///< Command which belongs to the same block.
                                  ///< Only used for block commands which do not
                                  ///< start block.
  CommandType same_group_type_2;  ///< Same as .same_group_type, second command.
  CommandType same_group_type_3;  ///< Same as .same_group_type, third command.
  CommandType not_after;          ///< Command which must not precede the block
                                  ///< command being defined.
  bool push_stack;                ///< True if command starts new block (only
                                  ///< false for `end*` commands).
  char *not_after_message;        ///< Error message in case command follows
                                  ///< .not_after command.
  char *no_start_message;         ///< Error message in case start command (e.g.
                                  ///< :if for :elseif, :else and :endif) is
                                  ///< missing.
  char *duplicate_message;        ///< Error message in case command follows the
                                  ///< same block command on this level.
} BlockCommandDef;

typedef struct {
  VimlLineGetter fgetline;
  void *cookie;
  garray_T ga;
} SavingFgetlineArgs;

/// Options for parse_menu_name
typedef enum {
  kMenuDefaults,    ///< Do unescape menu items and save text after <Tab>.
  kMenuIgnoreText,  ///< Respect text after <Tab>, but do not save it.
  kMenuWholeCmd,    ///< Ignore <Tab>, do not treat whitespaces specially and
                    ///< treat <C-v> as "\\".
} MenuNameParsingOptions;

static const Replacement prev_rep;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/parser/ex_commands.c.generated.h"
#endif

#include "nvim/viml/parser/command_definitions.h"
#define DO_DECLARE_EXCMD
#include "nvim/viml/parser/command_definitions.h"  // NOLINT
#undef DO_DECLARE_EXCMD

/// Command node that is used to represent absense of command
///
/// Also serves the purpose of providing default values.
static const CommandNode nocmd = {
  .type = kCmdMissing,
  .name = NULL,
  .next = NULL,
  .children = NULL,
  .range = {
    .address = {
      .type = kAddrMissing,
      .data = { .regex = NULL },
      .followups = NULL,
    },
    .setpos = false,
    .next = NULL,
  },
  .skips = NULL,
  .skips_count = 0,
  .position = {
    .lnr = 0,
    .col = 0,
  },
  .end_position = {
    .lnr = 0,
    .col = 0,
  },
  .has_count = false,
  .count = 0,
  .reg = {
    .name = NUL,
    .expr = NULL,
  },
  .exflags = 0,
  .optflags = 0,
  .enc = NULL,
  .glob = {
    .pat = {
      .type = kPatMissing,
      .data = { .pats = { .pat = NULL, .next = NULL } },
      .next = NULL,
    },
    .next = NULL,
  },
  .bang = false,
};

#define NODE_IS_ALLOCATED(node) ((node) != NULL && (node) != &nocmd)

/// Allocate new command node and assign its type property
///
/// Uses type argument to determine how much memory it should allocate.
///
/// @param[in]  type      Node type.
/// @param[in]  position  Position of command start.
///
/// @return Pointer to allocated block of memory or NULL in case of error.
static CommandNode *cmd_alloc(CommandType type, CommandPosition position)
  FUNC_ATTR_NONNULL_RET
{
  // XXX May allocate less space then needed to hold the whole struct: less by
  // one size of CommandArg.
  size_t size = offsetof(CommandNode, args);
  CommandNode *node;

  if (type != kCmdUnknown) {
    size += sizeof(node->args[0]) * CMDDEF(type).num_args;
  }

  node = (CommandNode *) xcalloc(1, size);
  node->type = type;
  node->position = position;

  return node;
}

/// Allocate new regex definition and assign all its properties
///
/// @param[in]  string  Regular expression string.
/// @param[in]  len     String length. It is not required for string[len] to be
///                     a NUL byte.
///
/// @return Pointer to allocated block of memory.
static Regex *regex_alloc(const char *string, size_t len)
{
  Regex *regex;

  regex = (Regex *) xmalloc(offsetof(Regex, string) + len + 1);
  memcpy(regex->string, string, len);
  regex->string[len] = NUL;
  regex->prog = NULL;
  // FIXME: use vim_regcomp, but make it save errors in place of throwing
  //        them right away.
  // regex->prog = vim_regcomp(reg->string, 0);

  return regex;
}

/// Allocate new replacement atom
///
/// @note Does not zero memory when allocating, but does assign NULL to next
///       field.
///
/// @param[in]  type       Type of the replacement.
/// @param[in]  start_col  First column of the atom.
/// @param[in]  end_col    Last column of the atom.
///
/// @return Pointer to allocated block of memory.
static Replacement *replacement_alloc(const ReplacementType type,
                                      const size_t start_col,
                                      const size_t end_col)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_RET
{
  Replacement *const ret = xmalloc(sizeof(*ret));
  ret->type = type;
  ret->start_col = start_col;
  ret->end_col = end_col;
  ret->next = NULL;
  return ret;
}

/// Allocate new glob pattern part
///
/// @param[in]  type  Part type.
///
/// @return Pointer to allocated block of memory.
static Pattern *pattern_alloc(PatternType type)
{
  Pattern *const pat = xcalloc(1, sizeof(*pat));

  pat->type = type;

  return pat;
}

/// Allocate new address followup structure and set its type
///
/// @param[in]  type  Followup type.
///
/// @return Pointer to allocated block of memory.
static AddressFollowup *address_followup_alloc(AddressFollowupType type)
{
  AddressFollowup *const followup = xcalloc(1, sizeof(*followup));

  followup->type = type;

  return followup;
}

static void free_complete(CmdComplete *compl)
{
  if ((compl) == NULL) {
    return;
  }

  xfree(compl->arg);
  xfree(compl);
}

static void free_menu_item(MenuItem *menu_item)
{
  if (menu_item == NULL)
    return;

  free_menu_item(menu_item->subitem);
  xfree(menu_item->name);
  xfree(menu_item);
}

static void free_regex(Regex *regex)
{
  if (regex == NULL)
    return;

  vim_regfree(regex->prog);
  xfree(regex);
}

static void free_replacement(Replacement *rep)
{
  if (rep == NULL) {
    return;
  }

  switch (rep->type) {
    case kRepExpr: {
      free_expr(rep->data.expr);
      break;
    }
    case kRepLiteral: {
      xfree(rep->data.str);
      break;
    }
    case kRepEscaped:
    case kRepEscLiteral:
    case kRepMatched:
    case kRepGroup:
    case kRepPrevSub:
    case kRepCharUpCase:
    case kRepUpCase:
    case kRepCharDownCase:
    case kRepDownCase:
    case kRepCaseEnd:
    case kRepNewLine: {
      break;
    }
  }
  free_replacement(rep->next);
  xfree(rep);
}

static void free_patterns(Patterns *pats)
{
  if (pats == NULL)
    return;
  free_pattern(pats->pat);
  xfree(pats->pat);
  free_patterns(pats->next);
  xfree(pats->next);
}

static void free_colitem(PatternCollectionItem *colitem)
{
  if (colitem == NULL) {
    return;
  }
  free_colitem(colitem->next);
  xfree(colitem);
}

static void free_modifiers(FilenameModifier *mod)
{
  if (mod == NULL) {
    return;
  }
  free_regex(mod->reg);
  free_replacement(mod->rep);
  free_modifiers(mod->next);
  xfree(mod);
}

static void free_pattern(Pattern *pat)
{
  if (pat == NULL)
    return;

  switch (pat->type) {
    case kPatFnameMod:
    case kPatSourcedLnum:
    case kPatCurWord:
    case kPatCurWORD:
    case kPatClient:
    case kPatCurrent:
    case kPatAlternate:
    case kPatCurFile:
    case kPatSourcedFile:
    case kPatAuFile:
    case kPatAuBuf:
    case kPatAuMatch: {
      free_modifiers(pat->data.mod);
      pat->data.mod = NULL;
      break;
    }
    case kPatBufname:
    case kPatOldFile:
    case kPatMissing:
    case kPatHome:
    case kPatArguments:
    case kPatCharacter:
    case kPatAnything:
    case kPatAnyRecurse: {
      break;
    }
    case kPatLiteral:
    case kPatEnviron:
    case kGlobShell: {
      xfree(pat->data.str);
      break;
    }
    case kPatCollection: {
      free_colitem(pat->data.collection.colitem);
      pat->data.collection.colitem = NULL;
      break;
    }
    case kGlobExpression: {
      free_expr(pat->data.expr);
      pat->data.expr = NULL;
      break;
    }
    case kPatAuList:
    case kPatBranch: {
      free_patterns(&pat->data.pats);
      pat->data.pats = (Patterns) { NULL, NULL };
      break;
    }
  }
  free_pattern(pat->next);
  xfree(pat->next);
}

static void free_glob(Glob *glob)
{
  if (glob == NULL)
    return;

  free_pattern(&glob->pat);
  free_glob(glob->next);
  xfree(glob->next);
}

static void free_address_data(Address *address)
{
  if (address == NULL)
    return;

  switch (address->type) {
    case kAddrMissing:
    case kAddrFixed:
    case kAddrEnd:
    case kAddrCurrent:
    case kAddrMark:
    case kAddrForwardPreviousSearch:
    case kAddrBackwardPreviousSearch:
    case kAddrSubstituteSearch: {
      break;
    }
    case kAddrForwardSearch:
    case kAddrBackwardSearch: {
      free_regex(address->data.regex);
      break;
    }
  }
  free_address_followup(address->followups);
}

static void free_address_followup(AddressFollowup *followup)
{
  if (followup == NULL)
    return;

  switch (followup->type) {
    case kAddressFollowupMissing:
    case kAddressFollowupShift: {
      break;
    }
    case kAddressFollowupForwardPattern:
    case kAddressFollowupBackwardPattern: {
      free_regex(followup->data.regex);
      break;
    }
  }
  free_address_followup(followup->next);
  xfree(followup);
}

static void free_range_data(Range *range)
{
  if (range == NULL)
    return;

  free_address_data(&range->address);
  free_range(range->next);
}

static void free_range(Range *range)
{
  if (range == NULL)
    return;

  free_range_data(range);
  xfree(range);
}

static void free_syn_group_list(SynGroupList *group)
{
  if (group == NULL) {
    return;
  }

  switch (group->type) {
    case kSynGroupLiteral:
    case kSynGroupCluster: {
      xfree(group->data.name);
      group->data.name = NULL;
      break;
    }
    case kSynGroupRegex: {
      free_regex(group->data.regex);
      group->data.regex = NULL;
      break;
    }
    case kSynGroupAll:
    case kSynGroupTop:
    case kSynGroupContained: {
      break;
    }
  }
  free_syn_group_list(group->next);
  group->next = NULL;
  xfree(group);
}

static void free_syn_pattern_data(SynPattern *syn_pat)
{
  if (syn_pat == NULL) {
    return;
  }

  free_regex(syn_pat->reg);
  xfree(syn_pat->flagss);
  xfree(syn_pat->offsets);
}

static void free_syn_patterns(SynPatterns *syn_pats)
{
  if (syn_pats == NULL) {
    return;
  }

  free_syn_patterns(syn_pats->next);
  free_syn_pattern_data(&syn_pats->syn_pat);
  xfree(syn_pats);
}

const char *const empty_string = "";

static void free_cmd_arg(CommandArg *arg, CommandArgType type)
{
  switch (type) {
    case kArgExpression:
    case kArgExpressions:
    case kArgAssignLhs: {
      free_expr(arg->arg.expr);
      arg->arg.expr = NULL;
      break;
    }
    case kArgFlags:
    case kArgNumber:
    case kArgUNumber:
    case kArgChar:
    case kArgColumn: {
      break;
    }
    case kArgNumbers: {
      xfree(arg->arg.numbers);
      arg->arg.numbers = NULL;
      break;
    }
    case kArgUNumbers: {
      xfree(arg->arg.unumbers);
      arg->arg.unumbers = NULL;
      break;
    }
    case kArgString: {
      xfree(arg->arg.str);
      arg->arg.str = NULL;
      break;
    }
    case kArgPattern: {
      free_pattern(arg->arg.pat);
      xfree(arg->arg.pat);
      arg->arg.pat = NULL;
      break;
    }
    case kArgGlob: {
      free_glob(arg->arg.glob);
      xfree(arg->arg.glob);
      arg->arg.glob = NULL;
      break;
    }
    case kArgRegex: {
      free_regex(arg->arg.reg);
      arg->arg.reg = NULL;
      break;
    }
    case kArgReplacement: {
      free_replacement(arg->arg.rep);
      arg->arg.rep = NULL;
      break;
    }
    case kArgLines:
    case kArgGaStrings: {
      ga_clear_strings(&arg->arg.ga_strs);
      break;
    }
    case kArgStrings: {
      char **const strs = arg->arg.strs;
      if (strs != NULL) {
        char **cur_str = strs;
        while (*cur_str != NULL) {
          if (*cur_str != empty_string) {
            xfree(*cur_str);
          }
          cur_str++;
        }
        xfree(strs);
      }
      arg->arg.strs = NULL;
      break;
    }
    case kArgMenuName: {
      free_menu_item(arg->arg.menu_item);
      arg->arg.menu_item = NULL;
      break;
    }
    case kArgAuEvents: {
      xfree(arg->arg.events);
      arg->arg.events = NULL;
      break;
    }
    case kArgAddress: {
      free_range(arg->arg.range);
      arg->arg.range = NULL;
      break;
    }
    case kArgCmdComplete: {
      free_complete(arg->arg.complete);
      arg->arg.complete = NULL;
      break;
    }
    case kArgArgs: {
      CommandArg *subargs = arg->arg.args.args;
      size_t numsubargs = arg->arg.args.num_args;
      size_t i;
      for (i = 0; i < numsubargs; i++) {
        free_cmd_arg(&subargs[i], arg->arg.args.types[i]);
      }
      xfree(subargs);
      arg->arg.args.args = NULL;
      arg->arg.args.num_args = 0;
      break;
    }
    case kArgColor: {
      if (arg->arg.color.type == kHiColorName) {
        xfree(arg->arg.color.data.name);
        arg->arg.color.data.name = NULL;
      }
      break;
    }
    case kArgSynGroups: {
      free_syn_group_list(arg->arg.group);
      arg->arg.group = NULL;
      break;
    }
    case kArgSynPattern: {
      free_syn_pattern_data(arg->arg.syn_pat);
      xfree(arg->arg.syn_pat);
      arg->arg.syn_pat = NULL;
      break;
    }
    case kArgSynPatterns: {
      free_syn_patterns(arg->arg.syn_pats);
      arg->arg.syn_pats = NULL;
      break;
    }
  }
}

/// Free and clear everything inside CommandNode structure
///
/// Does not free its argument.
///
/// @param[in,out]  node  Structure to clear.
void clear_cmd(CommandNode *node)
{
  size_t numargs;
  size_t i;

  if (!NODE_IS_ALLOCATED(node)) {
    return;
  }

  numargs = CMDDEF(node->type).num_args;

  if (node->type != kCmdUnknown) {
    for (i = 0; i < numargs; i++) {
      free_cmd_arg(&node->args[i], CMDDEF(node->type).arg_types[i]);
    }
  }

  free_cmd(node->next);
  free_cmd(node->children);
  free_glob(&node->glob);
  free_range_data(&node->range);
  xfree(node->name);
  xfree(node->skips);
  node->next = NULL;
  node->children = NULL;
  node->glob.next = NULL;
  node->glob.pat.type = kPatMissing;
  node->range.next = NULL;
  node->range.address.type = kAddrMissing;
}

void free_cmd(CommandNode *node)
{
  clear_cmd(node);
  xfree(node);
}

/// Get a list of comma separated patterns
///
/// Useful for branches (src/{foo,bar}.c) and autocommand pattern list
/// (src/foo.c,src/bar.c).
///
/// @param[in,out]  state  Parser state. Warning: ->cmdp is expected to be one
///                        character before actual pattern.
/// @param[out]  ret_parsed  Location where error will be saved.
/// @param[out]  pat  Address where pattern will be saved.
/// @param[in]  is_glob  True if parsing fully qualified globs (i.e. ``
///                      `shell command` `` and `` `=VimL.Expression()` ``
///                      are allowed).
///
/// @return OK if everything is good, NOTDONE if there was an error (in this
///         case error structure must be populated), FAIL if there was error
///         without error message.
static int get_comma_separated_patterns(CMD_P_ARGS,
                                        Pattern **pat,
                                        const bool is_glob)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  Pattern **next = pat;
  Patterns *cur_pats = &((*next)->data.pats);
  Patterns **next_pats = &cur_pats;
  do {
    int cret;
    Pattern *pat = NULL;
    state->cmdp++;
    if ((cret = get_glob_pattern(state, ret_parsed, &pat, true, is_glob))
        != OK) {
      return cret;
    }
    if (pat != NULL) {
      if (*next_pats == NULL) {
        *next_pats = xcalloc(1, sizeof(**next_pats));
      }
      (*next_pats)->pat = pat;
      next_pats = &((*next_pats)->next);
    }
  } while (*state->cmdp == ',');
  return OK;
}

const CollectionCharacterClassDef pattern_character_classes[] = {
  [kColCharClassAlnum] = { "alnum", 5 },
  [kColCharClassAlpha] = { "alpha", 5 },
  [kColCharClassBlank] = { "blank", 5 },
  [kColCharClassCntrl] = { "cntrl", 5 },
  [kColCharClassDigit] = { "digit", 5 },
  [kColCharClassGraph] = { "graph", 5 },
  [kColCharClassLower] = { "lower", 5 },
  [kColCharClassPrint] = { "print", 5 },
  [kColCharClassPunct] = { "punct", 5 },
  [kColCharClassSpace] = { "space", 5 },
  [kColCharClassUpper] = { "upper", 5 },
  [kColCharClassXdigit] = { "xdigit", 6 },
  [kColCharClassReturn] = { "return", 6 },
  [kColCharClassTab] = { "tab", 3 },
  [kColCharClassEscape] = { "escape", 6 },
  [kColCharClassBackspace] = { "backspace", 9 },
};
const char *pattern_collection_escapes = "etrbn";
const char *pattern_collection_escape_chars = "\033\t\r\b\n";
const char *pattern_collection_escapable_chars = "]\\^-";

/// Parse [] collection in a pattern
///
/// @param[in,out]  state  Parser state.
/// @param[out]  ret_parsed  Location where error will be saved.
/// @param[out]  collection  Location where results are saved.
///
/// @return OK in case of success, NOTDONE if there was an error with the error
///         message and FAIL in case of non-recoverable error.
static int get_pattern_collection(CMD_P_ARGS,
                                  PatternCollection *collection)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  if (*state->cmdp == '^') {
    collection->inverse = true;
    state->cmdp++;
  }
  PatternCollectionItem *prev = NULL;
  PatternCollectionItem **next = &collection->colitem;
  u8char_T literal_char = 0;
  bool is_range = false;
  const char *range_dash;
  while (*state->cmdp != ']') {
    switch (*state->cmdp) {
      case '-': {
        if (prev == NULL || prev->type != kPatColItemLiteral
            || state->cmdp[1] == ']') {
          goto get_pattern_collection_fetch_literal_character;
        }
        is_range = true;
        range_dash = state->cmdp;
        state->cmdp++;
        break;
      }
      case '[': {
        if (state->cmdp[1] == ':') {
          const char *e = state->cmdp + 2;
          while (ASCII_ISLOWER(*e)) {
            e++;
          }
          if (*e != ':' || e[1] != ']') {
            goto get_pattern_collection_fetch_literal_character;
          }
          const size_t class_len = (size_t) (e - (state->cmdp + 2));
          bool found = false;
          size_t i;
          for (i = 0; i < ARRAY_SIZE(pattern_character_classes); i++) {
            if (class_len == pattern_character_classes[i].len
                && STRNCMP(pattern_character_classes[i].str, state->cmdp + 2,
                           class_len) == 0) {
              found = true;
              break;
            }
          }
          if (found) {
            if (is_range) {
              // Destroy the collection
              free_colitem(collection->colitem);
              collection->colitem = NULL;
              return OK;
            }
            *next = xcalloc(1, sizeof(**next));
            (*next)->type = kPatColItemClass;
            (*next)->data.class = (CollectionCharacterClassType) i;
            prev = *next;
            next = &((*next)->next);
            state->cmdp = e + 2;
          } else {
            goto get_pattern_collection_fetch_literal_character;
          }
        } else {
          goto get_pattern_collection_fetch_literal_character;
        }
        break;
      }
      case '\\': {
        if (state->cmdp[1]) {
          if (strchr(pattern_collection_escapable_chars, state->cmdp[1])
              != NULL) {
            // Include state->cmdp[1] literally
            state->cmdp++;
            goto get_pattern_collection_fetch_literal_character;
          } else if (strchr(pattern_collection_escapes,
                            state->cmdp[1]) != NULL) {
            // Some special escape sequences
            state->cmdp++;
            literal_char =
                (u8char_T) pattern_collection_escape_chars[
                  strchr(pattern_collection_escapes, *state->cmdp) -
                  pattern_collection_escapes];
            state->cmdp++;
            goto get_pattern_collection_process_literal_character;
          } else if (state->cmdp[1] == 'd' && ascii_isdigit(state->cmdp[2])) {
            size_t char_len = 1;
            state->cmdp += 2;
            literal_char = (u8char_T) (*state->cmdp - '0');
            state->cmdp++;
            while (ascii_isdigit(*state->cmdp) && char_len < 3) {
              literal_char = literal_char * 10 + (u8char_T)(*state->cmdp - '0');
              char_len++;
              state->cmdp++;
            }
            goto get_pattern_collection_process_literal_character;
          } else if (state->cmdp[1] == 'o' && ascii_isdigit(state->cmdp[2])
                     && state->cmdp['2'] < '8') {
            // \oN octal escape
            size_t char_len = 1;
            state->cmdp += 2;
            literal_char = (u8char_T) (*state->cmdp - '0');
            state->cmdp++;
            while (ascii_isdigit(*state->cmdp) && (*state->cmdp < '8')
                   && char_len < 3 && literal_char < 0377) {
              literal_char = literal_char * 8 + (u8char_T) (*state->cmdp - '0');
              char_len++;
              state->cmdp++;
            }
            goto get_pattern_collection_process_literal_character;
          } else if (state->cmdp[1] == 'x' && ascii_isxdigit(state->cmdp[2])) {
            // \xN hexadecimal escape
            if (ascii_isxdigit(state->cmdp[3])) {
              literal_char = (u8char_T) (16 * hex2nr(state->cmdp[2])
                                         + hex2nr(state->cmdp[3]));
              state->cmdp += 4;
            } else {
              literal_char = (u8char_T) hex2nr(state->cmdp[2]);
              state->cmdp += 3;
            }
            goto get_pattern_collection_process_literal_character;
          } else if ((state->cmdp[1] == 'u' || state->cmdp[1] == 'U')
                     && ascii_isxdigit(state->cmdp[2])) {
            // \uN/\UN unicode character escape
            size_t char_len = 1;
            const size_t max_char_len = (state->cmdp[1] == 'u' ? 4 : 8);
            state->cmdp += 2;
            literal_char = (u8char_T) hex2nr(*state->cmdp);
            state->cmdp++;
            while (ascii_isxdigit(*state->cmdp) && char_len <= max_char_len) {
              literal_char = (literal_char * 16
                              + (u8char_T) hex2nr(*state->cmdp));
              char_len++;
              state->cmdp++;
            }
            goto get_pattern_collection_process_literal_character;
          }
          break;
        }
        // fallthrough
      }
      default: {
        // literal character
get_pattern_collection_fetch_literal_character:
        {}
        size_t char_len = mb_ptr2len(state->cmdp);
        literal_char = (u8char_T) mb_ptr2char(state->cmdp);
        state->cmdp += char_len;
get_pattern_collection_process_literal_character:
        if (is_range) {
          if (literal_char < prev->data.ch) {
            ret_parsed->error.message =
                N_("E16: Invalid range: end is greater then start");
            ret_parsed->error.position = range_dash;
            return NOTDONE;
          }
          prev->type = kPatColItemRange;
          prev->data.range.ch1 = prev->data.ch;
          prev->data.range.ch2 = literal_char;
          is_range = false;
        } else {
          *next = xcalloc(1, sizeof(**next));
          (*next)->type = kPatColItemLiteral;
          (*next)->data.ch = literal_char;
          prev = *next;
          next = &((*next)->next);
        }
        literal_char = 0;
        break;
      }
    }
  }
  return OK;
}

/// Parse filename modifiers
///
/// @param[in,out]  state  Parser state.
/// @param[out]  ret_parsed  Location where error will be saved.
/// @param[out]  mod  Location where parsing results will be saved.
///
/// @return OK in case of success, NOTDONE if there was an error with the error,
///         FAIL otherwise.
static int parse_filename_modifiers(CMD_P_ARGS,
                                    FilenameModifier **mod)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  FilenameModifier **next = mod;
parse_filename_modifiers_repeat:
#define RECORD_MODIFIER(mod_type) \
  do { \
    *next = xcalloc(1, sizeof(**next)); \
    (*next)->type = mod_type; \
    next = &((*next)->next); \
  } while (0)
  // ":p": full path
  if (*state->cmdp == ':' && state->cmdp[1] == 'p') {
    RECORD_MODIFIER(kFnameModFullPath);
    state->cmdp += 2;
  }
  // ":.": path relative to the current directory
  // ":~": path relative to the home directory
  // ":8": shortname path
  while (*state->cmdp == ':' && (state->cmdp[1] == '.'
                                 || state->cmdp[1] == '~'
                                 || state->cmdp[1] == '8')) {
    state->cmdp += 2;
    switch (state->cmdp[-1]) {
      case '.': {
        RECORD_MODIFIER(kFnameModRelative);
        break;
      }
      case '~': {
        RECORD_MODIFIER(kFnameModHome);
        break;
      }
      case '8': {
        RECORD_MODIFIER(kFnameMod8_3);
        break;
      }
    }
  }
  // ":h": head, remove "/file_name", can be repeated
  while (*state->cmdp == ':' && state->cmdp[1] == 'h') {
    state->cmdp += 2;
    RECORD_MODIFIER(kFnameModHead);
  }
  // ":8": shortname
  if (*state->cmdp == ':' && state->cmdp[1] == '8') {
    state->cmdp += 2;
    RECORD_MODIFIER(kFnameMod8_3);
  }
  // ":t": tail, just the basename
  if (*state->cmdp == ':' && state->cmdp[1] == 't') {
    state->cmdp += 2;
    RECORD_MODIFIER(kFnameModTail);
  }
  // ":e": extension, can be repeated
  // ":r": root, without extension, can be repeated
  while (*state->cmdp == ':' && (state->cmdp[1] == 'e'
                                 || state->cmdp[1] == 'r')) {
    state->cmdp += 2;
    switch (state->cmdp[-1]) {
      case 'e': {
        RECORD_MODIFIER(kFnameModExtension);
        break;
      }
      case 'r': {
        RECORD_MODIFIER(kFnameModRoot);
        break;
      }
    }
  }
  if (*state->cmdp == ':' && (state->cmdp[1] == 's'
                              || (state->cmdp[1] == 'g'
                                  && state->cmdp[2] == 's'))) {
    bool is_gsub = false;
    if (state->cmdp[1] == 'g') {
      is_gsub = true;
    }
    const char *const reg_start = state->cmdp + 3 + is_gsub;
    const char sep = reg_start[-1];
    const char *const reg_end = strchr(reg_start, sep);
    if (sep && reg_end != NULL) {
      const char *const rep_start = reg_end + 1;
      const char *const rep_end = strchr(rep_start, sep);
      if (rep_end != NULL) {
        state->cmdp = rep_end + 1;
        *next = xcalloc(1, sizeof(**next));
        (*next)->type = is_gsub? kFnameModGSub: kFnameModSub;
        (*next)->reg = regex_alloc(reg_start, (size_t) (reg_end - reg_start));
        char *const rep_copy =
            xmemdupz(rep_start, (size_t) (rep_end - rep_start));
        CommandParserState rep_state = *state;
        rep_state.cmdp = rep_state.s = rep_copy;
        rep_state.position = (CommandPosition) { 0, 0 };
        int pr_ret;
        if ((pr_ret = parse_replacement(&rep_state, ret_parsed,
                                        &((*next)->rep), NUL,
                                        MAGIC(state))) != OK) {
          if (ret_parsed->error.position != NULL) {
            ret_parsed->error.position =
                rep_start + (ret_parsed->error.position - rep_copy);
          }
          xfree(rep_copy);
          return pr_ret;
        }
        assert(*rep_state.cmdp == NUL);
        assert((*next)->rep != &prev_rep);
        next = &((*next)->next);
        xfree(rep_copy);
        // After using :s, repeat all the modifiers
        goto parse_filename_modifiers_repeat;
      }
    }
  }
  // ":S": shellescape string
  if (*state->cmdp == ':' && state->cmdp[1] == 'S') {
    state->cmdp += 2;
    RECORD_MODIFIER(kFnameModEscape);
  }
#undef RECORD_MODIFIER
  return OK;
}

const CmdlineSpecialDescription cmdline_specials[] = {
  { "cword", 5, kPatCurWord },
  { "cWORD", 5, kPatCurWORD },
  { "cfile", 5, kPatCurFile },
  { "afile", 5, kPatAuFile },
  { "abuf", 4, kPatAuBuf },
  { "amatch", 6, kPatAuMatch },
  { "sfile", 5, kPatSourcedFile },
  { "slnum", 5, kPatSourcedLnum },
  { "client", 6, kPatClient },
  { NULL, 0, 0 },
};

/// Get glob pattern
///
/// @param[in,out]  state  Parser state.
/// @param[out]  ret_parsed  Location where error will be saved.
/// @param[in]  is_branch  True if parsed string is a part of {a,b}.
/// @param[in]  is_glob  True if all glob pattern features should be supported.
///                      Specifically this allows \`command\` and \`=expr\`.
///
/// @return OK in case of success, NOTDONE if there was a parsing error, FAIL
///        otherwise.
static int get_glob_pattern(CMD_P_ARGS,
                            Pattern **const pat,
                            const bool is_branch,
                            const bool is_glob)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  Pattern **next = pat;
  size_t literal_length = 0;
  const char *literal_start = NULL;
  int ret = FAIL;
  const char *const s = state->cmdp;

  *pat = NULL;

  for (;;) {
    PatternType type = kPatMissing;
    switch (*state->cmdp) {
      case '`': {
        if (!is_glob)
          type = kPatLiteral;
        // FIXME Not compatible
        else if (is_branch)
          type = kPatLiteral;
        else if (state->cmdp[1] == '=')
          type = kGlobExpression;
        else
          type = kGlobShell;
        break;
      }
      case '*': {
        if (state->cmdp[1] == '*')
          type = kPatAnyRecurse;
        else
          type = kPatAnything;
        break;
      }
      case '?': {
        type = kPatCharacter;
        break;
      }
      case '%': {
        type = kPatCurrent;
        break;
      }
      case '#': {
        switch (state->cmdp[1]) {
          case '1':
          case '2':
          case '3':
          case '4':
          case '5':
          case '6':
          case '7':
          case '8':
          case '9': {
            type = kPatBufname;
            break;
          }
          case '<': {
            if (ascii_isdigit(state->cmdp[2]))
              type = kPatOldFile;
            else
              type = kPatLiteral;
            break;
          }
          case '#': {
            type = kPatArguments;
            break;
          }
          default: {
            type = kPatAlternate;
            break;
          }
        }
        break;
      }
      case '[': {
        type = kPatCollection;
        break;
      }
      case '{': {
        type = kPatBranch;
        break;
      }
      case '}': {
        if (is_branch) {
          type = kPatMissing;
        } else {
          type = kPatLiteral;
        }
        break;
      }
      case '$': {
        type = kPatEnviron;
        break;
      }
      case ',': {
        if (is_branch) {
          type = kPatMissing;
        } else {
          type = kPatLiteral;
        }
        break;
      }
      case '\\': {
        type = kPatLiteral;
        state->cmdp++;
        break;
      }
      // Ends the whole command
      case NUL:
      case '|':
      case '\n':
      case '"': {
        // fallthrough
      }
      // Ends one pattern
      case ' ':
      case '\t': {
        type = kPatMissing;
        break;
      }
      case '~': {
        if (state->cmdp == s) {
          type = kPatHome;
        } else {
          type = kPatLiteral;
        }
        break;
      }
      case '<': {
        size_t len;
        for (len = 0; ASCII_ISALPHA(state->cmdp[len + 1]); len++) {
        }
        if (state->cmdp[len] != '>') {
          const CmdlineSpecialDescription *sp_desc;
          for (sp_desc = &cmdline_specials[0]; sp_desc->str; sp_desc++) {
            if (len == sp_desc->len
                && STRNCMP(state->cmdp + 1, sp_desc->str, len) == 0) {
              break;
            }
          }
          if (sp_desc->str != NULL) {
            type = sp_desc->type;
            break;
          }
        }
        // fallthrough
      }
      default: {
        type = kPatLiteral;
        break;
      }
    }
    if (type == kPatLiteral) {
      if (literal_start == NULL) {
        literal_start = state->cmdp;
      }
      literal_length++;
#define GLOB_SPECIAL_CHARS "`#*?%\\[{}]$ \t"
#define IS_GLOB_SPECIAL(c) (strchr(GLOB_SPECIAL_CHARS, c) != NULL)
      // TODO(ZyX-I): Compare with vim
      if (*state->cmdp == '\\' && IS_GLOB_SPECIAL(state->cmdp[1])) {
        state->cmdp += 2;
      } else {
        state->cmdp++;
      }
    } else {
      if (literal_start != NULL) {
        char *p;
        const char *t;
        assert(*next == NULL);
        *next = pattern_alloc(kPatLiteral);
        (*next)->data.str = xcalloc(literal_length + 1, sizeof(char));
        p = (*next)->data.str;

        for (t = literal_start; t < state->cmdp; t++) {
          if (*t == '\\' && IS_GLOB_SPECIAL(t[1])) {
            *p++ = t[1];
            t++;
          } else {
            *p++ = *t;
          }
        }
        literal_start = NULL;
        literal_length = 0;
        next = &((*next)->next);
      }
      if (type == kPatMissing)
        break;
      assert(*next == NULL);
      *next = pattern_alloc(type);
      bool parse_fmods = false;
      switch (type) {
        case kGlobExpression: {
          ExpressionParserError expr_error;
          state->cmdp += 2;
          if (((*next)->data.expr = parse_one_expression(
                      &state->cmdp, &expr_error, &parse0_err, COL(state)))
                  == NULL) {
            if (expr_error.message == NULL)
              goto get_glob_error_return;
            ret_parsed->error.message = expr_error.message;
            ret_parsed->error.position = expr_error.position;
            ret = NOTDONE;
            goto get_glob_error_return;
          }
          state->cmdp++;
          break;
        }
        case kGlobShell: {
          const char *const init_p = state->cmdp;
          state->cmdp++;
          while (!ENDS_EXCMD(*state->cmdp) && !(*state->cmdp == '`'
                                                && state->cmdp[-1] != '\\')) {
            state->cmdp++;
          }
          if (*state->cmdp != '`' || state->cmdp == init_p + 1) {
            free_pattern(*next);
            xfree(*next);
            *next = NULL;
            state->cmdp = init_p + 1;
            literal_start = init_p;
            literal_length = 1;
            continue;
          } else {
            ((*next)->data.str = xmemdupz(init_p + 1,
                                          (size_t) (state->cmdp - init_p) - 1));
            state->cmdp++;
          }
          break;
        }
        case kPatCurrent:
        case kPatAlternate: {
          parse_fmods = true;
          state->cmdp++;
          break;
        }
        case kPatHome:  // FIXME Other users’ homes
        case kPatCharacter:
        case kPatAnything: {
          state->cmdp++;
          break;
        }
        case kPatCurWord:
        case kPatCurWORD:
        case kPatCurFile:
        case kPatAuFile:
        case kPatAuBuf:
        case kPatAuMatch:
        case kPatSourcedFile:
        case kPatSourcedLnum:
        case kPatClient: {
          parse_fmods = true;
          for (const CmdlineSpecialDescription *sp_desc = &cmdline_specials[0];;
               sp_desc++) {
            if (sp_desc->type == type) {
              state->cmdp += 2 + sp_desc->len;
              break;
            }
          }
          break;
        }
        case kPatArguments:
        case kPatAnyRecurse: {
          state->cmdp += 2;
          break;
        }
        case kPatOldFile: {
          state->cmdp++;
          // fallthrough
        }
        case kPatBufname: {
          state->cmdp++;
          (*next)->data.number = (int) getdigits(&state->cmdp);
          parse_fmods = true;
          break;
        }
        case kPatCollection: {
          const char *const init_p = state->cmdp;
          state->cmdp++;
          int pcret;
          if ((pcret = get_pattern_collection(
                      state, ret_parsed, &((*next)->data.collection))) != OK) {
            ret = pcret;
            goto get_glob_error_return;
          }
          if (*state->cmdp == ']' && (*next)->data.collection.colitem != NULL) {
            state->cmdp++;
          } else {
            state->cmdp = init_p;
            free_pattern(*next);
            xfree(*next);
            *next = NULL;
            literal_start = state->cmdp;
            state->cmdp++;
            literal_length = 1;
            continue;
          }
          break;
        }
        case kPatEnviron: {
          state->cmdp++;
          const char *const init_p = state->cmdp;
          const char *const end = find_env_end(&state->cmdp);
          if (end == NULL) {
            free_pattern(*next);
            xfree(*next);
            *next = NULL;
            literal_start = init_p - 1;
            state->cmdp = init_p;
            literal_length = 1;
          } else {
            (*next)->data.str = xmemdupz(init_p,
                                         (size_t) (state->cmdp - init_p));
          }
          break;
        }
        case kPatBranch: {
          const char *const init_p = state->cmdp;
          int gcsp_ret = get_comma_separated_patterns(state, ret_parsed, next,
                                                      is_glob);
          if (gcsp_ret != OK) {
            ret = gcsp_ret;
            goto get_glob_error_return;
          }
          if (*state->cmdp == '}' && (*next)->data.pats.next != NULL) {
            state->cmdp++;
          } else {
            state->cmdp = init_p;
            free_pattern(*next);
            xfree(*next);
            *next = NULL;
            literal_start = state->cmdp;
            state->cmdp++;
            literal_length = 1;
            continue;
          }
          break;
        }
        case kPatFnameMod:
        case kPatAuList:
        case kPatMissing:
        case kPatLiteral: {
          assert(false);
        }
      }
      if (parse_fmods) {
        int pfm_ret;
        if (type == kPatOldFile || type == kPatBufname) {
          next = &((*next)->next);
          *next = pattern_alloc(kPatFnameMod);
        }
        if ((pfm_ret = parse_filename_modifiers(state, ret_parsed,
                                                &((*next)->data.mod))) != OK) {
          ret = pfm_ret;
          goto get_glob_error_return;
        }
      }
      next = &((*next)->next);
    }
  }

  return OK;

get_glob_error_return:
  free_pattern(*pat);
  xfree(*pat);
  *pat = NULL;
  return ret;
}

/// Create new syntax error node
///
/// @param[in]  state  Parser state.
/// @param[in,out]  ret_parsed  Place where error node goes, also contains the
///                             error definition. Error is cleared in process.
///
/// @return Always returns NOTDONE.
static int create_error_node(CMD_P_ARGS)
{
  if (ret_parsed->error.message != NULL) {
    RET_PARSED_CMD_ALLOC(ret_parsed, kCmdSyntaxError,
                         (ret_parsed->node == NULL
                          ? state->position
                          : ret_parsed->node->position));
    ret_parsed->node->args[ARG_ERROR_LINESTR].arg.str = xstrdup(state->s);
    ret_parsed->node->args[ARG_ERROR_MESSAGE].arg.str =
        xstrdup(ret_parsed->error.message);
    ret_parsed->node->args[ARG_ERROR_OFFSET].arg.col =
        (size_t) (ret_parsed->error.position - state->s);
    memset(&ret_parsed->error, 0, sizeof(ret_parsed->error));
  }
  return NOTDONE;
}

/// Get virtual column for the first non-blank character
///
/// Tabs are considered to be 8 cells wide. Spaces are 1 cell wide. Other
/// characters are considered non-blank.
///
/// @param[in,out]  pp  String for which indentation should be updated. Is
///                     advanced to the first non-white character.
///
/// @return Offset of the first non-white character.
static int get_vcol(const char **pp)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  int vcol = 0;
  const char *p = *pp;

  for (;;) {
    switch (*p++) {
      case ' ': {
        vcol++;
        continue;
      }
      case TAB: {
        vcol += 8 - vcol % 8;
        continue;
      }
      default: {
        break;
      }
    }
    break;
  }

  *pp = p - 1;
  return vcol;
}

/// Get regular expression
///
/// @param[in,out]  state  Parser state. ->cmdp should point to the first
///                        character of the regular expression, *not* to the
///                        first character before it. ->cmdp is advanced to the
///                        character just after endch.
/// @param[out]  ret_parsed  Location where error will be saved.
/// @param[out]  regex  Location where regex is saved.
/// @param[in]  endch  Last character of the regex: character at which
///                    regular expression should end (unless it was
///                    escaped). Is expected to be either '?', '/' or NUL
///                    (note: regex will in any case end on NUL, but using
///                    NUL here will result in a faster code: NULs cannot
///                    be escaped, so it just uses STRLEN to find regex
///                    end).
/// @param[in]  no_end_message  Error message which should be thrown if string
///                             ended, but endch was not found. If NULL this
///                             situation is considered to be OK.
///
/// @return FAIL in case of non-recoverable failure, NOTDONE in case of error,
///         OK otherwise.
static int get_regex(CMD_P_ARGS,
                     Regex **regex, const char endch,
                     const char *const no_end_message)
  FUNC_ATTR_NONNULL_ARG(1, 2, 3) FUNC_ATTR_WARN_UNUSED_RESULT
{
  assert(endch != NUL || no_end_message == NULL);
  const char *const s = state->cmdp;

  if (endch == NUL) {
    state->cmdp += STRLEN(state->cmdp);
  } else {
    while (*state->cmdp != NUL && *state->cmdp != endch) {
      if (*state->cmdp == '\\' && state->cmdp[1] != NUL)
        state->cmdp += 2;
      else
        state->cmdp++;
    }
  }

  *regex = regex_alloc(s, (size_t) (state->cmdp - s));

  if (*state->cmdp != NUL) {
    state->cmdp++;
  } else if (no_end_message != NULL) {
    ret_parsed->error.message = no_end_message;
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }

  return OK;
}

/// Free line obtained using nextline(), and adjust position to its end
static inline void freeline(CommandParserState *const state)
  FUNC_ATTR_NONNULL_ALL
{
  if (state->s != NULL) {
    state->position.col = strlen(state->s);
    if (state->line.can_free) {
      xfree((void *) state->s);
      state->cmdp = state->s = NULL;
    }
  }
}

#define CMD_P_DEF(f) \
    int f(CMD_P_ARGS) FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
#define CMD_SUBP_DEF(f) \
    int f(CMD_SUBP_ARGS) FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT

static CMD_P_DEF(parse_append)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  garray_T *ga_strs =
      &ret_parsed->node->args[ARG_APPEND_LINES].arg.ga_strs;
  const char *first_nonblank;
  int vcol = -1;
  int cur_vcol = -1;

  ga_init(ga_strs, (int) sizeof(char *), 3);

  freeline(state);
  while (nextline(state, ':', vcol == -1 ? 0 : vcol)) {
    first_nonblank = state->s;
    if (vcol == -1) {
      vcol = get_vcol(&first_nonblank);
    } else {
      cur_vcol = get_vcol(&first_nonblank);
    }
    if (first_nonblank[0] == '.' && first_nonblank[1] == NUL
        && cur_vcol <= vcol) {
      freeline(state);
      break;
    }
    ga_grow(ga_strs, 1);
    ((char **)(ga_strs->ga_data))[ga_strs->ga_len++] =
        (char *) (state->line.can_free ? state->s : xstrdup(state->s));
    state->s = state->cmdp = NULL;
  }

  return OK;
}

/// Set RHS of :map/:abbrev/:menu node
///
/// @param[in]  state  Parser state.
/// @param[out]  ret_parsed  Location where rhs will be saved (in ->node).
/// @param[in]  rhs  Right hand side of the command.
/// @param[in]  rhs_idx  Offset of RHS argument in
///                      ret_parsed->node->args array.
/// @parblock
///   @note rhs_idx + 1 is expected to point to parsed variant of RHS (for
///         <expr>-type mappings)). If parser error occurred during running
///         expression ret_parsed->node->children will point to syntax
///         error node.
/// @endparblock
/// @param[in]  special  True if explicit <special> was supplied.
/// @param[in]  is_expr  True if it is <expr>-type mapping.
/// @parblock
///   @note If this argument is always false then you do not need to care about
///         rhs_idx + 1 and ret_parsed->node->children.
/// @endparblock
///
/// @return FAIL when out of memory, OK otherwise.
static int set_node_rhs(CMD_P_ARGS, const char *rhs, const size_t rhs_idx,
                        const bool special, const bool is_expr)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  char *rhs_buf;
  char *new_rhs;

  new_rhs = replace_termcodes(rhs, strlen(rhs), &rhs_buf, false, true, special,
                              FLAG_POC_TO_FLAG_CPO(state->o.flags));
  if (rhs_buf == NULL)
    return FAIL;

  if ((state->o.flags&FLAG_POC_ALTKEYMAP) && (state->o.flags&FLAG_POC_RL))
    lrswap(new_rhs);

  if (is_expr) {
    ExpressionParserError expr_error;
    Expression *expr = NULL;
    const char *rhs_end = new_rhs;

    expr_error.position = NULL;
    expr_error.message = NULL;

    if ((expr = parse_one_expression(&rhs_end, &expr_error, &parse0_err,
                                     state->position.col)) == NULL) {
      if (expr_error.message == NULL) {
        xfree(new_rhs);
        return FAIL;
      }
      ret_parsed->error.position = expr_error.position;
      ret_parsed->error.message = expr_error.message;
      if (create_error_node(state, ret_parsed) == FAIL) {
        xfree(new_rhs);
        return FAIL;
      }
    } else if (*rhs_end != NUL) {
      free_expr(expr);

      ret_parsed->error.position = rhs_end;
      ret_parsed->error.message = N_("E15: trailing characters");

      if (create_error_node(state, ret_parsed) == FAIL) {
        xfree(new_rhs);
        return FAIL;
      }
    } else {
      ret_parsed->node->args[rhs_idx + 1].arg.expr = expr;
    }

    xfree(new_rhs);
  } else {
    ret_parsed->node->args[rhs_idx].arg.str = new_rhs;
  }
  return OK;
}

/// Parse :*map/:*abbrev/:*unmap/:*unabbrev commands
///
/// @param[in,out]  state  Parser state. ->cmdp is advanced to the end of the
///                        string unless a error occurred. ->cmdp must point to
///                        the first non-white character of the command
///                        argument.
/// @param[in]  unmap  Determines whether :*map/:*abbrev or :*unmap/:*unabbrev
///                    command is being parsed.
///
/// @return OK if everything was parsed correctly, FAIL in case of
///         non-recoverable error.
static int do_parse_map(CMD_P_ARGS, bool unmap)
{
  uint_least32_t map_flags = 0;
  const char *lhs;
  const char *lhs_end;
  const char *rhs;
  char *lhs_buf;
  bool do_backslash = !(state->o.flags & FLAG_POC_CPO_BSLASH);

  for (;;) {
    if (*state->cmdp != '<') {
      break;
    }

    switch (state->cmdp[1]) {
      case 'b': {
        // Check for "<buffer>": mapping local to buffer.
        if (STRNCMP(state->cmdp, "<buffer>", 8) == 0) {
          state->cmdp = skipwhite(state->cmdp + 8);
          map_flags |= FLAG_MAP_BUFFER;
          continue;
        }
        break;
      }
      case 'n': {
        // Check for "<nowait>": don't wait for more characters.
        if (STRNCMP(state->cmdp, "<nowait>", 8) == 0) {
          state->cmdp = skipwhite(state->cmdp + 8);
          map_flags |= FLAG_MAP_NOWAIT;
          continue;
        }
        break;
      }
      case 's': {
        // Check for "<silent>": don't echo commands.
        if (STRNCMP(state->cmdp, "<silent>", 8) == 0) {
          state->cmdp = skipwhite(state->cmdp + 8);
          map_flags |= FLAG_MAP_SILENT;
          continue;
        }

        // Check for "<special>": accept special keys in <>
        if (STRNCMP(state->cmdp, "<special>", 9) == 0) {
          state->cmdp = skipwhite(state->cmdp + 9);
          map_flags |= FLAG_MAP_SPECIAL;
          continue;
        }

        // Check for "<script>": remap script-local mappings only
        if (STRNCMP(state->cmdp, "<script>", 8) == 0) {
          state->cmdp = skipwhite(state->cmdp + 8);
          map_flags |= FLAG_MAP_SCRIPT;
          continue;
        }
        break;
      }
      case 'e': {
        // Check for "<expr>": {rhs} is an expression.
        if (STRNCMP(state->cmdp, "<expr>", 6) == 0) {
          state->cmdp = skipwhite(state->cmdp + 6);
          map_flags |= FLAG_MAP_EXPR;
          continue;
        }
        break;
      }
      case 'u': {
        // Check for "<unique>": don't overwrite an existing mapping.
        if (STRNCMP(state->cmdp, "<unique>", 8) == 0) {
          state->cmdp = skipwhite(state->cmdp + 8);
          map_flags |= FLAG_MAP_UNIQUE;
          continue;
        }
        break;
      }
      default: {
        break;
      }
    }
    break;
  }
  ret_parsed->node->args[ARG_MAP_FLAGS].arg.flags = map_flags;

  lhs = state->cmdp;
  while (*state->cmdp && (unmap || !ascii_iswhite(*state->cmdp))) {
    if ((state->cmdp[0] == Ctrl_V || (do_backslash && state->cmdp[0] == '\\'))
        && state->cmdp[1] != NUL) {
      state->cmdp++;  // skip CTRL-V or backslash
    }
    state->cmdp++;
  }

  lhs_end = state->cmdp;
  state->cmdp = skipwhite(state->cmdp);
  rhs = state->cmdp;

  state->cmdp += strlen(state->cmdp);

  if (*lhs != NUL) {
    // Note: type of the abbreviation is not checked because it depends on the
    //       &iskeyword option. Unlike $ENV parsing (which depends on the
    //       options too) it is not unlikely that both 1. file will be parsed
    //       before result is actually used and 2. option value at the execution
    //       stage will make results invalid.
    lhs = replace_termcodes(lhs, (size_t) (lhs_end - lhs), &lhs_buf, true, true,
                            map_flags&FLAG_MAP_SPECIAL,
                            FLAG_POC_TO_FLAG_CPO(state->o.flags));
    if (lhs_buf == NULL)
      return FAIL;
    ret_parsed->node->args[ARG_MAP_LHS].arg.str = (char *) lhs;
  }

  if (*rhs != NUL) {
    assert(!unmap);
    if (STRICMP(rhs, "<nop>") == 0) {
      // Empty string
      rhs = xcalloc(1, sizeof(char));
    } else {
      return set_node_rhs(state, ret_parsed, rhs, ARG_MAP_RHS,
                          map_flags & FLAG_MAP_SPECIAL,
                          map_flags & FLAG_MAP_EXPR);
    }
  }

  return OK;
}

static CMD_P_DEF(parse_map)
{
  return do_parse_map(state, ret_parsed, false);
}

static CMD_P_DEF(parse_unmap)
{
  return do_parse_map(state, ret_parsed, true);
}

static CMD_P_DEF(parse_mapclear)
{
  bool local;

  local = (STRCMP(state->cmdp, "<buffer>") == 0);
  if (local) {
    state->cmdp += 8;
  }

  ret_parsed->node->args[ARG_CLEAR_BUFFER].arg.flags = local;

  return OK;
}

/// Unescape characters
///
/// It is expected to be called on a string in allocated memory that is safe to
/// alter. This function only removes "\\" charaters from the string, modifying
/// memory in-place.
///
/// @param[in,out]  p        String being unescaped.
/// @param[in]      unctrlv  Treat <C-v> as escape character.
static void str_unescape(char *p, bool unctrlv)
{
  while (*p) {
    if ((*p == '\\' || (*p == Ctrl_V && unctrlv)) && p[1] != NUL)
      STRMOVE(p, p + 1);
    p++;
  }
}

/// Parse menu name
///
/// @param[in,out]  state  Parser state.
/// @param[out]  ret_parsed  Location where error will be saved.
/// @param[in]  unmenu  True when parsing :unmenu.
/// @param[out]  menu_item  Address where allocated menu is saved.
/// @param[out]  menu_text  Address where left text is saved.
///
/// @return OK in case of success, NOTDONE in case of error, FAIL in case of
///         unrecoverable error.
static int parse_menu_name(CMD_P_ARGS,
                           const MenuNameParsingOptions mnpo,
                           MenuItem **const menu_item,
                           char **const menu_text)
{
  MenuItem *sub = NULL;
  const char *s = NULL;
  const char *menu_path_end = NULL;
  const char *menu_path = state->cmdp;
  MenuItem **next = menu_item;

  if (*menu_path == '.') {
    ret_parsed->error.message = N_("E475: Expected menu name");
    ret_parsed->error.position = menu_path;
    return NOTDONE;
  }

  while (*state->cmdp && (mnpo == kMenuWholeCmd
                          || !ascii_iswhite(*state->cmdp))) {
    if ((*state->cmdp == '\\' || *state->cmdp == Ctrl_V)
        && state->cmdp[1] != NUL) {
      state->cmdp++;
      if (*state->cmdp == TAB && mnpo != kMenuWholeCmd) {
        s = state->cmdp + 1;
        menu_path_end = state->cmdp - 2;
      }
    } else if (STRNICMP(state->cmdp, "<TAB>", 5) == 0
               && mnpo != kMenuWholeCmd) {
      menu_path_end = state->cmdp - 1;
      state->cmdp += 4;
      s = state->cmdp + 1;
    } else if (*state->cmdp == '.' && s == NULL) {
      menu_path_end = state->cmdp - 1;
      if (menu_path_end == menu_path) {
        ret_parsed->error.message = N_("E792: Empty menu name");
        ret_parsed->error.position = state->cmdp;
        return NOTDONE;
      }
    } else if ((!state->cmdp[1] || (mnpo != kMenuWholeCmd
                                    && ascii_iswhite(state->cmdp[1])))
               && state->cmdp != menu_path && s == NULL) {
      menu_path_end = state->cmdp;
    }
    if (menu_path_end != NULL) {
      sub = xcalloc(1, sizeof(*sub));

      *next = sub;
      next = &sub->subitem;

      sub->name = xmemdupz(menu_path, (size_t) (menu_path_end - menu_path) + 1);

      str_unescape(sub->name, mnpo == kMenuWholeCmd);

      menu_path = state->cmdp + 1;
      menu_path_end = NULL;
    }
    state->cmdp++;
  }

  if (s != NULL) {
    char *text;
    if (*menu_item == NULL) {
      ret_parsed->error.message = N_("E792: Empty menu name");
      ret_parsed->error.position = s;
      return NOTDONE;
    }

    if (mnpo == kMenuDefaults) {
      text = xmemdupz(s, (size_t) (state->cmdp - s));

      str_unescape(text, false);

      *menu_text = text;
    }
  }
  return OK;
}

/// Parse :*menu/:*unmenu
///
/// @param[in,out]  state  Parser state. ->cmdp is advanced to the end of the
///                        string unless a error occurred. Must point to the
///                        first non-white character of the command argument.
/// @param[in]  unmenu  Determines whether :*menu or :*unmenu command is being
///                     parsed.
///
/// @return FAIL when out of memory, OK otherwise.
static int do_parse_menu(CMD_P_ARGS, const bool unmenu)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  // FIXME "menu *" parses to something weird
  uint_least32_t menu_flags = 0;
  size_t i;
  const char *s;
  const char *map_to;

  for (;;) {
    if (STRNCMP(state->cmdp, "<script>", 8) == 0) {
      menu_flags |= FLAG_MENU_SCRIPT;
      state->cmdp = skipwhite(state->cmdp + 8);
      continue;
    }
    if (STRNCMP(state->cmdp, "<silent>", 8) == 0) {
      menu_flags |= FLAG_MENU_SILENT;
      state->cmdp = skipwhite(state->cmdp + 8);
      continue;
    }
    if (STRNCMP(state->cmdp, "<special>", 9) == 0) {
      menu_flags |= FLAG_MENU_SPECIAL;
      state->cmdp = skipwhite(state->cmdp + 9);
      continue;
    }
    break;
  }

  // Locate an optional "icon=filename" argument.
  if (STRNCMP(state->cmdp, "icon=", 5) == 0) {
    char *icon;

    state->cmdp += 5;
    s = state->cmdp;

    while (*state->cmdp != NUL && *state->cmdp != ' ') {
      if (*state->cmdp == '\\') {
        state->cmdp++;
      }
      mb_ptr_adv_(state->cmdp);
    }

    if (!unmenu) {
      icon = xmemdupz(s, (size_t) (state->cmdp - s));

      str_unescape(icon, false);

      ret_parsed->node->args[ARG_MENU_ICON].arg.str = icon;
    }

    if (*state->cmdp != NUL) {
      state->cmdp = skipwhite(state->cmdp);
    }
  }

  for (s = state->cmdp; *s; ++s) {
    if (!ascii_isdigit(*s) && *s != '.') {
      break;
    }
  }

  if (ascii_iswhite(*s)) {
    int *pris;
    i = 0;
    for (; i < MENUDEPTH && !ascii_iswhite(*state->cmdp); i++) {
    }
    if (i) {
      if (unmenu) {
        for (i = 0; i < MENUDEPTH && !ascii_iswhite(*state->cmdp); i++) {
          state->cmdp = skipdigits(state->cmdp);
          if (*state->cmdp == '.') {
            state->cmdp++;
          }
        }
      } else {
        pris = xcalloc(i + 1, sizeof(int));
        ret_parsed->node->args[ARG_MENU_PRI].arg.numbers = pris;
        for (i = 0; i < MENUDEPTH && !ascii_iswhite(*state->cmdp); i++) {
          pris[i] = (int) getdigits(&state->cmdp);
          if (pris[i] == 0) {
            pris[i] = MENU_DEFAULT_PRI;
          }
          if (*state->cmdp == '.') {
            state->cmdp++;
          }
        }
      }
    }
    state->cmdp = skipwhite(state->cmdp);
  }

  if (STRNCMP(state->cmdp, "enable", 6) == 0 && ascii_iswhite(state->cmdp[6])) {
    menu_flags |= FLAG_MENU_ENABLE;
    state->cmdp = skipwhite(state->cmdp + 6);
  } else if (STRNCMP(state->cmdp, "disable", 7) == 0
             && ascii_iswhite(state->cmdp[7])) {
    menu_flags |= FLAG_MENU_DISABLE;
    state->cmdp = skipwhite(state->cmdp + 7);
  }

  if (!unmenu) {
    ret_parsed->node->args[ARG_MENU_FLAGS].arg.flags = menu_flags;
  }

  if (*state->cmdp == NUL) {
    return OK;
  }

  const char *const menu_path = state->cmdp;
  const size_t name_idx = (unmenu ? ARG_UNMENU_LHS : ARG_MENU_NAME);
  int pmn_ret = parse_menu_name(
      state, ret_parsed, unmenu ? kMenuIgnoreText : kMenuDefaults,
      &ret_parsed->node->args[name_idx].arg.menu_item,
      unmenu ? NULL : &ret_parsed->node->args[ARG_MENU_TEXT].arg.str);
  if (pmn_ret != OK) {
    return pmn_ret;
  }

  state->cmdp = skipwhite(state->cmdp);

  if (unmenu) {
    return OK;
  }

  map_to = state->cmdp;

  state->cmdp += strlen(state->cmdp);

  // FIXME More checks
  if (*map_to != NUL) {
    if (ret_parsed->node->args[ARG_MENU_NAME].arg.menu_item == NULL) {
      ret_parsed->error.message = N_("E792: Empty menu name");
      ret_parsed->error.position = menu_path;
      return NOTDONE;
    } else if (
        ret_parsed->node->args[ARG_MENU_NAME].arg.menu_item->subitem
        == NULL) {
      ret_parsed->error.message =
          N_("E331: Must not add menu items directly to menu bar");
      ret_parsed->error.position = menu_path;
      return NOTDONE;
    }
    return set_node_rhs(state, ret_parsed, map_to, ARG_MENU_RHS,
                        menu_flags&FLAG_MENU_SPECIAL, false);
  }

  return OK;
}

static CMD_P_DEF(parse_menu)
{
  return do_parse_menu(state, ret_parsed, false);
}

static CMD_P_DEF(parse_unmenu)
{
  return do_parse_menu(state, ret_parsed, true);
}

/// Parse an expression or a whitespace-separated sequence of expressions
///
/// Used for ":execute" and ":echo*"
///
/// @param[in,out]  state  Parser state. ->cmdp is advanced to the end of the
///                        last expression. Should point to the first character
///                        of the expression (may point to whitespace
///                        character).
/// @param[out]  ret_parsed  Location where error will be saved.
/// @param[in]  multi  Determines whether parsed expression is actually
///                    a sequence of expressions.
///
/// @return FAIL if out of memory, NOTDONE in case of error, OK otherwise.
static int do_parse_expr_cmd(CMD_P_ARGS, const bool multi)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  Expression *expr;
  ExpressionParserError expr_error;

  if (multi) {
    expr = parse_many_expressions(&state->cmdp, &expr_error, &parse0_err,
                                  COL(state), false, "\n|");
  } else {
    expr = parse_one_expression(&state->cmdp, &expr_error, &parse0_err,
                                COL(state));
  }

  if (expr == NULL) {
    if (expr_error.message == NULL) {
      return FAIL;
    }
    ret_parsed->error.message = expr_error.message;
    ret_parsed->error.position = expr_error.position;
    return NOTDONE;
  }

  ret_parsed->node->args[ARG_EXPR_EXPR].arg.expr = expr;

  return OK;
}

static CMD_P_DEF(parse_expr_cmd)
{
  if (ret_parsed->node->type == kCmdReturn
      && ENDS_EXCMD_NOCOMMENT(*state->cmdp)) {
    return OK;
  }

  return do_parse_expr_cmd(state, ret_parsed, false);
}

static CMD_P_DEF(parse_call)
{
  const char *const s = state->cmdp;
  int ret = do_parse_expr_cmd(state, ret_parsed, false);
  if (ret == OK
      && (ret_parsed->node->args[ARG_EXPR_EXPR].arg.expr->node->type
          != kExprCall)) {
    ret_parsed->error.message = N_("E129: :call accepts only function calls");
    ret_parsed->error.position = s;
    return NOTDONE;
  }
  return ret;
}

static CMD_P_DEF(parse_expr_seq_cmd)
{
  if (ENDS_EXCMD_NOCOMMENT(*state->cmdp)) {
    return OK;
  }
  return do_parse_expr_cmd(state, ret_parsed, true);
}

static CMD_P_DEF(parse_rest_line)
{
  size_t len;
  if (*state->cmdp == NUL) {
    if (ret_parsed->node->type == kCmdCstag) {
      ret_parsed->error.message = "E562: Usage: cstag <ident>";
    } else {
      ret_parsed->error.message = (char *) e_argreq;
    }
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }

  len = strlen(state->cmdp);

  ret_parsed->node->args[0].arg.str = xmemdupz(state->cmdp, len);
  state->cmdp += len;
  return OK;
}

static CMD_P_DEF(parse_rest_allow_empty)
{
  if (*state->cmdp == NUL) {
    return OK;
  }

  return parse_rest_line(state, ret_parsed);
}

static const char *do_fgetline(int c, const char **arg, int indent)
{
  if (*arg) {
    const char *result;
    result = xstrdup(*arg);
    *arg = NULL;
    return result;
  } else {
    return NULL;
  }
}

static CMD_P_DEF(parse_do)
{
  const char *arg = state->cmdp;
  CommandParserState new_state = *state;
  new_state.line = (LineGetterOptions) {
    (VimlLineGetter) &do_fgetline, &arg, true };
  CommandParserResult new_ret_parsed = *ret_parsed;

  if ((ret_parsed->node->children =
       parse_cmd_sequence(&new_state, &new_ret_parsed)) == NULL) {
    return FAIL;
  }

  state->cmdp = new_state.cmdp;

  return OK;
}

/// Check whether given expression node is a valid lvalue
///
/// @param[in]   s            String that holds original representation of
///                           parsed expression.
/// @param[in]   node         Checked expression.
/// @param[out]  ret_parsed   Location where error will be saved.
/// @param[in]   allow_list   Determines whether list nodes are allowed.
/// @param[in]   allow_lower  Determines whether simple variable names are
///                           allowed to start with a lowercase letter.
/// @param[in]   allow_env    Determines whether it is allowed to contain
///                           kExprOption, kExprRegister and
///                           kExprEnvironmentVariable nodes.
///
/// @return true if check failed, false otherwise.
static bool check_lval(const char *const s, ExpressionNode *node,
                       CommandParserResult *ret_parsed, bool allow_list,
                       bool allow_lower, bool allow_env)
{
  switch (node->type) {
    case kExprSimpleVariableName: {
      if (!allow_lower
          && ASCII_ISLOWER(s[node->start])
          && s[node->start + 1] != ':'  // Fast check: most functions
                                        // containing colon contain it in the
                                        // second character
          && memchr((void *) (s + node->start), '#',
                    node->end - node->start + 1) == NULL
          // FIXME? Though foo:bar works in Vim Bram said it was never
          //        intended to work.
          && memchr((void *) (s + node->start), ':',
                    node->end - node->start + 1) == NULL) {
        ret_parsed->error.message =
            N_("E128: Function name must start with a capital "
               "or contain a colon or a hash");
        ret_parsed->error.position = s + node->start;
        return true;
      }
      break;
    }
    case kExprEnvironmentVariable: {
      if (allow_env) {
        if (node->start > node->end) {
          ret_parsed->error.message = N_("E475: Cannot assign to environment "
                                         "variable with an empty name");
          ret_parsed->error.position = s + node->end;
          return true;
        }
      }
      // fallthrough
    }
    case kExprOption:
    case kExprRegister: {
      if (!allow_env) {
        ret_parsed->error.message = N_("E15: Only variable names are allowed");
        ret_parsed->error.position = s + node->start;
        return true;
      }
      break;
    }
    case kExprListRest: {
      break;
    }
    case kExprVariableName: {
      break;
    }
    case kExprConcatOrSubscript:
    case kExprSubscript: {
      for (ExpressionNode *root = node; root->children != NULL;
           root = root->children) {
        switch (root->type) {
          case kExprConcatOrSubscript:
          case kExprSubscript: {
            continue;
          }
          case kExprVariableName:
          case kExprSimpleVariableName: {
            break;
          }
          default: {
            ret_parsed->error.message =
                N_("E475: Expected variable name or a list of variable names");
            ret_parsed->error.position = s + root->start;
            return true;
          }
        }
        break;
      }
      break;
    }
    case kExprList: {
      if (allow_list) {
        ExpressionNode *item = node->children;

        if (item == NULL) {
          ret_parsed->error.message =
              N_("E475: Expected non-empty list of variable names");
          ret_parsed->error.position = s + node->start;
          return true;
        }

        while (item != NULL) {
          if (check_lval(s, item, ret_parsed, false, allow_lower, allow_env))
            return true;
          item = item->next;
        }
      } else {
        ret_parsed->error.message = N_("E475: Expected variable name");
        ret_parsed->error.position = s + node->start;
        return true;
      }
      break;
    }
    default: {
      if (allow_list) {
        ret_parsed->error.message =
            N_("E475: Expected variable name or a list of variable names");
      } else {
        ret_parsed->error.message = N_("E475: Expected variable name");
      }
      ret_parsed->error.position = s + node->start;
      return true;
    }
  }
  return false;
}

#define FLAG_PLVAL_SPACEMULT 0x01
#define FLAG_PLVAL_LISTMULT  0x02
#define FLAG_PLVAL_NOLOWER   0x04
#define FLAG_PLVAL_ALLOW_ENV 0x08

/// Parse left value of assignment
///
/// @param[in,out]  state  Parser state. ->cmdp is advanced to the next
///                        character after parsed expression.
/// @param[out]  ret_parsed   Location where error will be saved.
/// @param[out]  expr  Location where result will be saved.
/// @param[in]  flags  Flags:
/// @parblock
///   Flag                 | Description
///   -------------------- | -------------------------------------------------
///   FLAG_PLVAL_SPACEMULT | Allow space-separated multiple values
///   FLAG_PLVAL_LISTMULT  | Allow multiple values in a list ("[a, b]")
///   FLAG_PLVAL_NOLOWER   | Do not allow name to start with a lowercase letter
///   FLAG_PLVAL_ALLOW_ENV | Allow options, env variables and registers
///
///   @note If both FLAG_PLVAL_LISTMULT and FLAG_PLVAL_SPACEMULT were
///         specified then only either space-separated values or list will be
///         allowed, but not both.
/// @endparblock
///
/// @return OK if parsing was successfull, NOTDONE if it was not, FAIL when
///         out of memory.
static int parse_lval(CMD_P_ARGS, Expression **const expr, const int flags)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  ExpressionParserError expr_error;
  const char *const s = state->cmdp;
  bool allow_list = (bool) (flags&FLAG_PLVAL_LISTMULT);
  bool allow_env = (bool) (flags&FLAG_PLVAL_ALLOW_ENV);

  if (flags&FLAG_PLVAL_SPACEMULT) {
    *expr = parse_many_expressions(&state->cmdp, &expr_error, &parse7_nofunc,
                                   COL(state), true, "\n\"|-.+=");
  } else {
    *expr = parse_one_expression(&state->cmdp, &expr_error, &parse7_nofunc,
                                 COL(state));
  }

  if (*expr == NULL) {
    if (expr_error.message == NULL) {
      return FAIL;
    }
    ret_parsed->error.message = expr_error.message;
    ret_parsed->error.position = expr_error.position;
    return NOTDONE;
  }

  if ((*expr)->node->next != NULL) {
    allow_list = false;
    allow_env = false;
  }

  for (ExpressionNode *next = (*expr)->node; next != NULL; next = next->next) {
    if (check_lval((*expr)->string, next, ret_parsed, allow_list,
                   !(flags&FLAG_PLVAL_NOLOWER), allow_env)) {
      free_expr(*expr);
      *expr = NULL;
      if (ret_parsed->error.message == NULL) {
        return FAIL;
      }
      if (ret_parsed->error.position == NULL) {
        ret_parsed->error.position = s;
      }
      return NOTDONE;
    }
  }

  return OK;
}

static CMD_P_DEF(parse_lvals)
{
  Expression *expr;
  int ret;

  if ((ret = parse_lval(state, ret_parsed, &expr,
                        ret_parsed->node->type == kCmdDelfunction
                        ? FLAG_PLVAL_NOLOWER
                        : FLAG_PLVAL_SPACEMULT)) == FAIL) {
    return FAIL;
  }

  ret_parsed->node->args[ARG_EXPRS_EXPRS].arg.expr = expr;

  if (ret == NOTDONE) {
    return NOTDONE;
  }

  return OK;
}

static CMD_P_DEF(parse_lockvar)
{
  if (ascii_isdigit(*state->cmdp)) {
    ret_parsed->node->args[ARG_LOCKVAR_DEPTH].arg.unumber =
        (unsigned) getdigits(&state->cmdp);
  }

  return parse_lvals(state, ret_parsed);
}

static CMD_P_DEF(parse_for)
{
  Expression *expr;
  Expression *list_expr;
  ExpressionParserError expr_error;
  int ret;

  if ((ret = parse_lval(state, ret_parsed, &expr, FLAG_PLVAL_LISTMULT))
      == FAIL) {
    return FAIL;
  }

  ret_parsed->node->args[ARG_FOR_LHS].arg.expr = expr;

  if (ret == NOTDONE) {
    return NOTDONE;
  }

  state->cmdp = skipwhite(state->cmdp);

  if (state->cmdp[0] != 'i' || state->cmdp[1] != 'n') {
    ret_parsed->error.message = N_("E690: Missing \"in\" after :for");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }

  state->cmdp = skipwhite(state->cmdp + 2);

  if ((list_expr = parse_one_expression(&state->cmdp, &expr_error, &parse0_err,
                                        COL(state))) == NULL) {
    if (expr_error.message == NULL) {
      return FAIL;
    }
    ret_parsed->error.message = expr_error.message;
    ret_parsed->error.position = expr_error.position;
    return NOTDONE;
  }

  ret_parsed->node->args[ARG_FOR_RHS].arg.expr = list_expr;

  return OK;
}

static CMD_P_DEF(parse_function)
{
  Expression *expr;
  int ret;
  garray_T *args = &ret_parsed->node->args[ARG_FUNC_ARGS].arg.ga_strs;
  uint_least32_t flags = 0;
  bool mustend = false;

  if (ENDS_EXCMD(*state->cmdp)) {
    return OK;
  }

  if (*state->cmdp == '/') {
    return get_regex(state, ret_parsed,
                     &ret_parsed->node->args[ARG_FUNC_REG].arg.reg,
                     '/', NULL);
  }

  if ((ret = parse_lval(state, ret_parsed, &expr, FLAG_PLVAL_NOLOWER))
      == FAIL) {
    return FAIL;
  }

  ret_parsed->node->args[ARG_FUNC_NAME].arg.expr = expr;

  if (ret == NOTDONE) {
    return NOTDONE;
  }

  state->cmdp = skipwhite(state->cmdp);

  if (*state->cmdp != '(') {
    if (!ENDS_EXCMD(*state->cmdp)) {
      ret_parsed->error.message = N_("E124: Missing '('");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
    return OK;
  }

  state->cmdp = skipwhite(state->cmdp + 1);

  ga_init(args, (int) sizeof(char *), 3);

  while (*state->cmdp != ')') {
    char *notend_message = N_("E475: Expected end of arguments list");
    if (state->cmdp[0] == '.' && state->cmdp[1] == '.'
        && state->cmdp[2] == '.') {
      flags |= FLAG_FUNC_VARARGS;
      state->cmdp += 3;
      mustend = true;
    } else {
      const char *arg_start = state->cmdp;
      const char *arg;
      int i;

      while (ASCII_ISALNUM(*state->cmdp) || *state->cmdp == '_') {
        state->cmdp++;
      }

      if (arg_start == state->cmdp) {
        ret_parsed->error.message = N_("E125: Argument expected, got nothing");
      } else if (ascii_isdigit(*arg_start)) {
        ret_parsed->error.message =
            N_("E125: Function argument cannot start with a digit");
      } else if ((state->cmdp - arg_start == 9
                  && strncmp(arg_start, "firstline", 9) == 0)
                 || (state->cmdp - arg_start == 8
                     && strncmp(arg_start, "lastline", 8) == 0)) {
        ret_parsed->error.message =
            N_("E125: Names \"firstline\" and \"lastline\" are reserved");
      } else {
        ret_parsed->error.message = NULL;
      }

      if (ret_parsed->error.message != NULL) {
        ret_parsed->error.position = arg_start;
        return NOTDONE;
      }

      arg = xmemdupz(arg_start, (size_t) (state->cmdp - arg_start));

      for (i = 0; i < args->ga_len; i++) {
        if (strcmp(((char **)(args->ga_data))[i], arg) == 0) {
          ret_parsed->error.message = N_("E853: Duplicate argument name: %s");
          ret_parsed->error.position = arg_start;
          return FAIL;
        }
      }

      ga_grow(args, 1);
#if 0
      if (ga_grow(args, 1) == FAIL) {
        ga_clear_strings(args);
        xfree(arg);
        return FAIL;
      }
#endif

      ((char **)(args->ga_data))[args->ga_len++] = (char *) arg;
    }
    if (*state->cmdp == ',') {
      state->cmdp++;
    } else {
      mustend = true;
      notend_message = N_("E475: Expected end of arguments list or comma");
    }
    state->cmdp = skipwhite(state->cmdp);
    if (mustend && *state->cmdp != ')') {
      ret_parsed->error.message = notend_message;
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
  }
  state->cmdp++;  // Skip the ')'

  // find extra arguments "range", "dict" and "abort"
  for (;;) {
    state->cmdp = skipwhite(state->cmdp);
    if (strncmp(state->cmdp, "range", 5) == 0) {
      flags |= FLAG_FUNC_RANGE;
      state->cmdp += 5;
    } else if (strncmp(state->cmdp, "dict", 4) == 0) {
      flags |= FLAG_FUNC_DICT;
      state->cmdp += 4;
    } else if (strncmp(state->cmdp, "abort", 5) == 0) {
      flags |= FLAG_FUNC_ABORT;
      state->cmdp += 5;
    } else {
      break;
    }
  }

  ret_parsed->node->args[ARG_FUNC_FLAGS].arg.flags = flags;

  return OK;
}

static CMD_P_DEF(parse_let)
{
  Expression *expr;
  ExpressionParserError expr_error;
  int ret;
  Expression *rval_expr;
  LetAssignmentType ass_type = 0;

  if (ENDS_EXCMD(*state->cmdp)) {
    return OK;
  }

  if ((ret = parse_lval(state, ret_parsed, &expr,
                        FLAG_PLVAL_LISTMULT|FLAG_PLVAL_SPACEMULT
                        |FLAG_PLVAL_ALLOW_ENV)) == FAIL) {
    return FAIL;
  }

  ret_parsed->node->args[ARG_LET_LHS].arg.expr = expr;

  if (ret == NOTDONE) {
    return NOTDONE;
  }

  state->cmdp = skipwhite(state->cmdp);

  if (ENDS_EXCMD(*state->cmdp)) {
    if (expr->node->type == kExprList) {
      ret_parsed->error.message =
          N_("E474: To list multiple variables use \":let var|let var2\", "
                   "not \":let [var, var2]\"");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
    return OK;
  } else {
    if (expr->node->next != NULL) {
      ret_parsed->error.message =
          N_("E18: Expected end of command after last variable");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
  }

  switch (*state->cmdp) {
    case '=': {
      state->cmdp++;
      ass_type = VAL_LET_ASSIGN;
      break;
    }
    case '+':
    case '-':
    case '.': {
      switch (*state->cmdp) {
        case '+': {
          ass_type = VAL_LET_ADD;
          break;
        }
        case '-': {
          ass_type = VAL_LET_SUBTRACT;
          break;
        }
        case '.': {
          ass_type = VAL_LET_APPEND;
          break;
        }
      }
      if (state->cmdp[1] != '=') {
        ret_parsed->error.message =
            N_("E18: '+', '-' and '.' must be followed by '='");
        ret_parsed->error.position = state->cmdp;
        return NOTDONE;
      }
      state->cmdp += 2;
      break;
    }
    default: {
      ret_parsed->error.message =
          N_("E18: Expected assignment operation or end of command");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
  }

  ret_parsed->node->args[ARG_LET_ASS_TYPE].arg.flags =
      (uint_least32_t) ass_type;

  state->cmdp = skipwhite(state->cmdp);

  if ((rval_expr = parse_one_expression(&state->cmdp, &expr_error, &parse0_err,
                                        COL(state))) == NULL) {
    if (expr_error.message == NULL) {
      return FAIL;
    }
    ret_parsed->error.message = expr_error.message;
    ret_parsed->error.position = expr_error.position;
    return NOTDONE;
  }

  ret_parsed->node->args[ARG_LET_RHS].arg.expr = rval_expr;

  return OK;
}

static CMD_P_DEF(parse_scriptencoding)
{
  if (*state->cmdp == NUL) {
    return OK;
  }
  // TODO(ZyX-I): Setup conversion from parsed encoding
  if ((ret_parsed->node->args[0].arg.str = enc_canonize(state->cmdp))
      == NULL) {
    return FAIL;
  }
  state->cmdp += strlen(state->cmdp);
  return OK;
}

/// Parse a list of autocmd events
///
/// @param[in,out]  state  Parser state.
/// @param[out]  ret_parsed  Location where error will be saved.
///
/// @return [allocated] Parsed events list or NULL in case of error.
static AuEvent *parse_events(CMD_P_ARGS)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL FUNC_ATTR_MALLOC
{
  if (*state->cmdp == '*') {
    if (state->cmdp[1] != NUL && !ascii_iswhite(state->cmdp[1])) {
      ret_parsed->error.message = N_("E215: Illegal character after *");
      ret_parsed->error.position = state->cmdp + 1;
      return NULL;
    }
    AuEvent *events = xcalloc(2, sizeof(*events));
    events[0] = ANY_EVENT;
    events[1] = NO_EVENT;
    state->cmdp = skipwhite(state->cmdp + 1);
    return events;
  }
  AuEvent event = NO_EVENT;
  garray_T ga;
  ga_init(&ga, (int) sizeof(event), 1);
  do {
    event = find_event(&state->cmdp);
    GA_APPEND(AuEvent, &ga, event);
    if (*state->cmdp == ',') {
      state->cmdp++;
    } else {
      break;
    }
  } while (event != NO_EVENT);
  GA_APPEND(AuEvent, &ga, NO_EVENT);
  if (!(ascii_iswhite(*state->cmdp) || *state->cmdp == NUL)) {
    ga_clear(&ga);
    return NULL;
  }
  state->cmdp = skipwhite(state->cmdp);
  return (AuEvent *) ga.ga_data;
}

/// Parse event and group names for :au and :doau
///
/// @param[in,out]  state  Parser state.
/// @param[out]  ret_parsed  Location where error will be saved.
/// @param[out]  events  Address where found events are saved.
/// @param[out]  group  Address where group name is saved.
///
/// @return OK in case of success, NOTDONE in case of syntax error and FAIL in
///         case of non-recoverable error.
static int parse_group_and_event(CMD_P_ARGS, AuEvent **const events,
                                 char **const group)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  *group = NULL;
  *events = parse_events(state, ret_parsed);
  if (ret_parsed->error.message != NULL) {
    return NOTDONE;
  }
  if (*events == NULL) {
    const char *const start = state->cmdp;
    while (!ascii_iswhite(*state->cmdp) && *state->cmdp) {
      state->cmdp++;
    }
    *group = xmemdupz(start, (size_t) (state->cmdp - start));
    state->cmdp = skipwhite(state->cmdp);
    if (*state->cmdp) {
      *events = parse_events(state, ret_parsed);
      if (ret_parsed->error.message != NULL) {
        return NOTDONE;
      }
      if (*events == NULL) {
        ret_parsed->error.message = N_("E216: No such event");
        ret_parsed->error.position = state->cmdp;
        return NOTDONE;
      }
    }
  }
  return OK;
}

static CMD_P_DEF(parse_autocmd)
{
  if (*state->cmdp == NUL) {
    return OK;
  }
  int pgeret;
  if ((pgeret = parse_group_and_event(
              state, ret_parsed,
              &ret_parsed->node->args[ARG_AU_EVENTS].arg.events,
              &ret_parsed->node->args[ARG_AU_GROUP].arg.str)) != OK) {
    return pgeret;
  }
  state->cmdp = skipwhite(state->cmdp);
  if (*state->cmdp == NUL) {
    return OK;
  }

  Pattern *pat = pattern_alloc(kPatAuList);
  state->cmdp--;
  int gcsp_ret = get_comma_separated_patterns(state, ret_parsed, &pat, false);
  if (gcsp_ret != OK) {
    return gcsp_ret;
  }
  ret_parsed->node->args[ARG_AU_PATTERNS].arg.pat = pat;
  state->cmdp = skipwhite(state->cmdp);

  if (strncmp(state->cmdp, "nested", sizeof("nested") - 1) == 0) {
    const char *const start = state->cmdp;
    state->cmdp = skipwhite(state->cmdp + sizeof("nested") - 1 + 1);
    if (*state->cmdp == NUL) {
      state->cmdp = start;
    } else {
      ret_parsed->node->args[ARG_AU_NESTED].arg.flags = 1;
    }
  }

  if (*state->cmdp == NUL) {
    return OK;
  }

  return parse_do(state, ret_parsed);
}

static CMD_P_DEF(parse_doautocmd)
{
  const char *const s = state->cmdp;
  int pgeret;
  AuEvent *events = NULL;
  ret_parsed->node->args[ARG_DOAU_NOMDLINE].arg.flags =
      (uint_least32_t) (!check_nomodeline(&state->cmdp));
  state->cmdp = skipwhite(state->cmdp);
  if ((pgeret = parse_group_and_event(
              state, ret_parsed, &events,
              &ret_parsed->node->args[ARG_DOAU_GROUP].arg.str)) != OK) {
    return pgeret;
  }
  ret_parsed->node->args[ARG_DOAU_EVENTS].arg.events = events;
  if (events != NULL && *events == ANY_EVENT) {
    ret_parsed->error.message =
        N_("E217: Can't execute autocommands for ALL events");
    ret_parsed->error.position = s;
    return NOTDONE;
  }
  state->cmdp = skipwhite(state->cmdp);
  if (*state->cmdp != NUL) {
    size_t len = strlen(state->cmdp);
    ret_parsed->node->args[ARG_DOAU_FNAME].arg.str =
        xmemdupz(state->cmdp, len);
    state->cmdp += len;
  }
  return OK;
}

static CMD_P_DEF(parse_behave)
{
  if (strcmp(state->cmdp, "mswin") == 0 || strcmp(state->cmdp, "xterm") == 0) {
    ret_parsed->node->args[ARG_NAME_NAME].arg.str = xstrdup(state->cmdp);
    state->cmdp += strlen(state->cmdp);
    return OK;
  } else {
    ret_parsed->error.message =
        N_("E475: :behave command currently only supports mswin and xterm");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
}

static CMD_P_DEF(parse_breakadd)
{
  BreakType type;
  bool is_profile = ret_parsed->node->type == kCmdProfile;
  bool profiling = (is_profile || ret_parsed->node->type == kCmdProfdel);

  if (strncmp(state->cmdp, "func", 4) == 0) {
    type = kBreakInFunction;
    state->cmdp += 4;
  } else if (strncmp(state->cmdp, "file", 4) == 0) {
    type = kBreakInFile;
    state->cmdp += 4;
  } else if (!profiling && strncmp(state->cmdp, "here", 4) == 0) {
    type = kBreakHere;
    state->cmdp += 4;
  } else if (is_profile && strncmp(state->cmdp, "start", 5) == 0) {
    type = kProfileStart;
    state->cmdp += 5;
  } else if (is_profile && strncmp(state->cmdp, "pause", 5) == 0) {
    type = kProfilePause;
    state->cmdp += 5;
  } else if (is_profile && strncmp(state->cmdp, "continue", 8) == 0) {
    type = kProfileContinue;
    state->cmdp += 8;
  } else {
    if (is_profile) {
      ret_parsed->error.message =
          N_("E475: :profile command only accepts `func', `file', `start', "
             "`pause' and `continue' as its first argument");
    } else if (profiling) {
      ret_parsed->error.message =
          N_("E475: :profdel command only accepts `func' and `file' "
             "as their first argument");
    } else {
      ret_parsed->error.message =
          N_("E475: Debug commands only accept `func', `file' and `here'");
    }
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }

  state->cmdp = skipwhite(state->cmdp);

  if (type == kBreakHere || type == kProfilePause || type == kProfileContinue) {
    // Do nothing
  } else if (type == kProfileStart) {
    if (*state->cmdp == NUL) {
      ret_parsed->error.message = N_("E750: Expected file name");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
    Pattern *const pat = pattern_alloc(kPatLiteral);
    const size_t file_len = strlen(state->cmdp);
    pat->data.str = xmemdupz(state->cmdp, file_len);
    ret_parsed->node->args[ARG_BREAK_NAME].arg.pat = pat;
    state->cmdp += file_len;
  } else {
    if (!profiling && ascii_isdigit(*state->cmdp)) {
      size_t lnr = 0;
      lnr = (size_t) getdigits(&state->cmdp);
      state->cmdp = skipwhite(state->cmdp);
      ret_parsed->node->range.address.type = kAddrFixed;
      ret_parsed->node->range.address.data.lnr = (linenr_T) lnr;
    }
    if (!*state->cmdp) {
      if (type == kBreakInFunction) {
        ret_parsed->error.message =
            N_("E475: Expecting function name or pattern");
      } else {
        ret_parsed->error.message = N_("E475: Expecting file name or pattern");
      }
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
    state->cmdp = skipwhite(state->cmdp);
    Pattern *pat = NULL;
    int cret;
    if ((cret = get_glob_pattern(state, ret_parsed, &pat, false, true)) != OK) {
      free_pattern(pat);
      xfree(pat);
      return cret;
    }
    ret_parsed->node->args[ARG_BREAK_NAME].arg.pat = pat;
  }
  ret_parsed->node->args[ARG_BREAK_TYPE].arg.flags =
      (uint_least32_t) type;
  return OK;
}

static CMD_P_DEF(parse_cbuffer)
{
  ret_parsed->node->args[ARG_NUMBER_NUMBER].arg.number = -1;
  if (*state->cmdp != NUL) {
    int bufnr;
    if (ascii_isdigit(*state->cmdp)) {
      bufnr = (int) getdigits(&state->cmdp);
    }
    if (*state->cmdp != NUL) {
      ret_parsed->error.message = N_("E474: Expected buffer number");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
    ret_parsed->node->args[ARG_NUMBER_NUMBER].arg.number = bufnr;
  }
  return OK;
}

static CMD_P_DEF(parse_number)
{
  ret_parsed->node->args[ARG_NUMBER_NUMBER].arg.number =
      atoi(state->cmdp);
  state->cmdp += strlen(state->cmdp);
  return OK;
}

static CMD_P_DEF(parse_clist)
{
  int start = 1;
  int end = -1;

  if (get_list_range(&state->cmdp, &start, &end) != OK) {
    ret_parsed->error.message = N_("E488: Expected valid integer range");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
  ret_parsed->node->args[ARG_CLIST_FIRST].arg.number = start;
  ret_parsed->node->args[ARG_CLIST_LAST].arg.number = end;
  return OK;
}

static CMD_P_DEF(parse_regex)
{
  Regex *regex = NULL;
  if (*state->cmdp == NUL) {
  } else if (*state->cmdp == '/') {
    state->cmdp++;
    int rret;
    if ((rret = get_regex(state, ret_parsed, &regex, '/', NULL)) != OK) {
      return rret;
    }
  } else {
    size_t numbslashes = 0;
    const char *e;
    for (e = state->cmdp; *e; e++) {
      if (*e == '\\') {
        numbslashes++;
      }
    }
    char *new_regex =
        xmalloc(6 + numbslashes + ((size_t) (e - state->cmdp) + 1));
    //          ^ \V\< and \>
    char *np = new_regex;
    memcpy(np, "\\V\\<", 4);
    np += 4;
    for (; state->cmdp < e; state->cmdp++) {
      *np++ = *state->cmdp;
      if (*state->cmdp == '\\') {
        *np++ = '\\';
      }
    }
    memcpy(np, "\\>", 3);
    //                ^ Also copy trailing NUL
    np += 2;
    assert(*np == NUL);
    regex = regex_alloc(new_regex, (size_t) (np - new_regex));
    xfree(new_regex);
  }
  ret_parsed->node->args[ARG_REG_REG].arg.reg = regex;
  return OK;
}

static CMD_P_DEF(parse_catch)
{
  if (ENDS_EXCMD(*state->cmdp)) {
    return OK;
  } else {
    state->cmdp++;
    return get_regex(state, ret_parsed,
                     &ret_parsed->node->args[ARG_REG_REG].arg.reg,
                     state->cmdp[-1], NULL);
  }
}

static CMD_P_DEF(parse_address)
{
  Range *range = NULL;
  Range **next = &range;
  while (*state->cmdp) {
    *next = xcalloc(1, sizeof(**next));
    if (get_address(state, ret_parsed, &((*next)->address)) == FAIL) {
      free_range(range);
      return FAIL;
    }
    if ((*next)->address.type == kAddrMissing) {
      if (*next != range) {
        break;
      }
      ret_parsed->error.message = N_("E14: Invalid address");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
    if (get_address_followups(state, ret_parsed, &((*next)->address.followups))
        == FAIL) {
      free_range(range);
      return FAIL;
    }
    state->cmdp = skipwhite(state->cmdp);
    (*next)->setpos = (*state->cmdp == ';');
    if (*state->cmdp == ';' || *state->cmdp == ',') {
      state->cmdp++;
      next = &((*next)->next);
    } else {
      break;
    }
  }
  ret_parsed->node->args[ARG_ADDR_ADDR].arg.range = range;
  return OK;
}

/// Parse -complete option
///
/// @param[in]  p  Pointer to the first character of the parsed value.
/// @param[in]  vallen  Length of the parsed value.
/// @param[out]  ret_parsed  Location where error will be saved.
/// @param[out]  comp  Address where parsing results are saved. Must be zeroed
///                    before passing here.
///
/// @return OK in case of success, NOTDONE in case of failure if error was set,
///         FAIL in case of non-recoverable error.
static int parse_completion_argument(const char *p, const size_t vallen,
                                     CommandParserResult *const ret_parsed,
                                     CmdComplete *compl)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const char *arg = NULL;
  size_t arglen = 0;
  size_t valend = vallen;

  // Look for any argument part - which is the part after any ','
  for (size_t i = 0; i < vallen; i++) {
    if (p[i] == ',') {
      arg = p + i + 1;
      arglen = vallen - i - 1;
      valend = i;
      break;
    }
  }
  for (size_t i = 0; command_complete[i].expand != 0; i++) {
    if (strlen(command_complete[i].name) == valend
        && strncmp(p, command_complete[i].name, valend) == 0) {
      compl->type = command_complete[i].expand;
      break;
    }
  }
  if (compl->type == EXPAND_NOTHING) {
    ret_parsed->error.message = N_("E180: Invalid complete value");
    ret_parsed->error.position = p;
    return NOTDONE;
  }
  if (arg == NULL) {
    if (compl->type == EXPAND_USER_DEFINED || compl->type == EXPAND_USER_LIST) {
      ret_parsed->error.message =
          N_("E467: Custom completion requires a function argument");
      ret_parsed->error.position = p + vallen;
      return NOTDONE;
    }
  } else {
    if (compl->type != EXPAND_USER_DEFINED && compl->type != EXPAND_USER_LIST) {
      ret_parsed->error.message =
          N_("E468: Completion argument only allowed for custom completion");
      ret_parsed->error.position = arg - 1;
      return NOTDONE;
    }
    compl->arg = xmemdupz(arg, arglen);
  }
  return OK;
}

static CMD_P_DEF(parse_command)
{
  uint_least32_t flags = 0;
  CmdComplete *compl = NULL;
  while (*state->cmdp == '-') {
    state->cmdp++;
    const char *const end = skiptowhite(state->cmdp);
    const size_t nlen = (size_t) (end - state->cmdp);
    if (STRNICMP(state->cmdp, "bang", nlen) == 0) {
      flags |= FLAG_CMD_BANG;
    } else if (STRNICMP(state->cmdp, "buffer", nlen) == 0) {
      flags |= FLAG_CMD_BUFFER;
    } else if (STRNICMP(state->cmdp, "bar", nlen) == 0) {
      flags |= FLAG_CMD_BAR;
    } else if (STRNICMP(state->cmdp, "register", nlen) == 0) {
      flags |= FLAG_CMD_REGISTER;
    } else {
      const char *val = NULL;
      size_t vallen = 0;
      size_t attrlen = nlen;

      // Look for the attribute name - which is the part before any '='
      size_t i;
      for (i = 0; i < nlen; ++i) {
        if (state->cmdp[i] == '=') {
          val = state->cmdp + i + 1;
          vallen = nlen - i - 1;
          attrlen = i;
          break;
        }
      }

      if (STRNICMP(state->cmdp, "nargs", attrlen) == 0) {
        // If vallen != 1 then argument is definitely invalid. NUL value skips
        // to default: case.
        flags &= ~FLAG_CMD_NARGS_MASK;
        switch (vallen == 1 ? *val : NUL) {
          case '0': {
            flags |= VAL_CMD_NARGS_NO;
            break;
          }
          case '1': {
            flags |= VAL_CMD_NARGS_ONE;
            break;
          }
          case '*': {
            flags |= VAL_CMD_NARGS_ANY;
            break;
          }
          case '?': {
            flags |= VAL_CMD_NARGS_Q;
            break;
          }
          case '+': {
            flags |= VAL_CMD_NARGS_P;
            break;
          }
          default: {
            ret_parsed->error.message = N_("E176: Invalid number of arguments");
            ret_parsed->error.position = (val == NULL
                                          ? state->cmdp + attrlen
                                          : val);
            goto parse_command_error_return;
          }
        }
      } else if (STRNICMP(state->cmdp, "range", attrlen) == 0) {
        if (vallen == 1 && *val == '%') {
          flags &= ~FLAG_CMD_RANGE_MASK;
          flags |= VAL_CMD_RANGE_ALL;
        } else if (val == NULL) {
          flags &= ~FLAG_CMD_RANGE_MASK;
          flags |= VAL_CMD_RANGE_CUR;
        } else {
          state->cmdp = val;
          if ((flags & FLAG_CMD_COUNT_MASK) == VAL_CMD_COUNT_COUNT
              || (flags & FLAG_CMD_RANGE_MASK) == VAL_CMD_RANGE_COUNT) {
            goto parse_command_double_count;
          }
          int count = (int) getdigits(&state->cmdp);
          if (state->cmdp != val + vallen || vallen == 0) {
            goto parse_command_invalid_count;
          }
          flags &= ~FLAG_CMD_RANGE_MASK;
          flags |= VAL_CMD_RANGE_COUNT;
          // Do not alter has_count so that printer does not dump count without
          // special-casing it.
          ret_parsed->node->count = count;
        }
      } else if (STRNICMP(state->cmdp, "count", attrlen) == 0) {
        if (val == NULL) {
          flags &= ~FLAG_CMD_COUNT_MASK;
          flags |= VAL_CMD_COUNT_EMPTY;
        } else {
          state->cmdp = val;
          if ((flags & FLAG_CMD_COUNT_MASK) == VAL_CMD_COUNT_COUNT
              || (flags & FLAG_CMD_RANGE_MASK) == VAL_CMD_RANGE_COUNT) {
            goto parse_command_double_count;
          }
          int count = (int) getdigits(&state->cmdp);
          if (state->cmdp != val + vallen) {
            goto parse_command_invalid_count;
          }
          flags &= ~FLAG_CMD_COUNT_MASK;
          flags |= VAL_CMD_COUNT_COUNT;
          // Do not alter has_count so that printer does not dump count without
          // special-casing it.
          ret_parsed->node->count = count;
        }
      } else if (STRNICMP(state->cmdp, "complete", attrlen) == 0) {
        if (val == NULL) {
          ret_parsed->error.message =
              N_("E179: Argument required for -complete");
          ret_parsed->error.position = state->cmdp + attrlen;
          goto parse_command_error_return;
        }
        compl = xcalloc(1, sizeof(*compl));
        int cret;
        if ((cret = parse_completion_argument(val, vallen, ret_parsed, compl))
            != OK) {
          free_complete(compl);
          return cret;
        }
      } else {
        ret_parsed->error.message = N_("E181: Invalid attribute");
        ret_parsed->error.position = state->cmdp;
        goto parse_command_error_return;
      }
    }
    state->cmdp = skipwhite(end);
  }
  const char *const name_start = state->cmdp;
  if (ASCII_ISALPHA(*state->cmdp)) {
    while (ASCII_ISALNUM(*state->cmdp)) {
      state->cmdp++;
    }
  }
  size_t name_len = (size_t) (state->cmdp - name_start);
  if (!ENDS_EXCMD(*state->cmdp) && !ascii_iswhite(*state->cmdp)) {
    ret_parsed->error.message = N_("E182: Invalid command name");
    ret_parsed->error.position = state->cmdp;
    goto parse_command_error_return;
  } else if (!ASCII_ISUPPER(*name_start)) {
    ret_parsed->error.message =
        N_("E183: User defined commands must start with an uppercase letter");
    ret_parsed->error.position = name_start;
    goto parse_command_error_return;
  } else if ((name_len == 1 && *name_start == 'X')
             || (name_len <= 4 && STRNCMP(name_start, "Next", name_len) == 0)) {
    ret_parsed->error.message =
        N_("E841: Reserved name, cannot be used for user defined command");
    ret_parsed->error.position = name_start;
    goto parse_command_error_return;
  }
  char *name = xmemdupz(name_start, name_len);
  state->cmdp = skipwhite(state->cmdp);
  if (*state->cmdp != NUL) {
    const size_t remaining_len = strlen(state->cmdp);
    ret_parsed->node->args[ARG_CMD_COMMAND].arg.str =
        xmemdupz(state->cmdp, remaining_len);
    state->cmdp += remaining_len;
  }
  ret_parsed->node->args[ARG_CMD_FLAGS].arg.flags = flags;
  ret_parsed->node->args[ARG_CMD_COMPLETE].arg.complete = compl;
  ret_parsed->node->args[ARG_CMD_NAME].arg.str = name;
  return OK;
parse_command_double_count:
  ret_parsed->error.message = N_("E177: Count cannot be specified twice");
  ret_parsed->error.position = state->cmdp;
  goto parse_command_error_return;
parse_command_invalid_count:
  ret_parsed->error.message = N_("E178: Invalid default value for count");
  ret_parsed->error.position = state->cmdp;
  goto parse_command_error_return;
parse_command_error_return:
  free_complete(compl);
  return NOTDONE;
}

static CMD_P_DEF(parse_delmarks)
{
  if (ret_parsed->node->bang) {
    if (*state->cmdp == NUL) {
      return OK;
    } else {
      ret_parsed->error.message = N_("E474: :delmarks must be called either "
                                     "without bang or without arguments");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
  } else if (*state->cmdp == NUL) {
    ret_parsed->error.message = N_("E471: You must specify register(s)");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
  // All marks are in range 0x20 - 0x7F (really narrower)
  uint8_t marks[MAX_NUM_MARKS];
  memset(&marks[0], 'N', MAX_NUM_MARKS);
  for (; *state->cmdp != NUL; state->cmdp++) {
    bool is_lower = ASCII_ISLOWER(*state->cmdp);
    bool is_digit = ascii_isdigit(*state->cmdp);
    if (is_lower || is_digit || ASCII_ISUPPER(*state->cmdp)) {
      if (state->cmdp[1] == '-') {
        uint8_t from = (uint8_t) *state->cmdp;
        uint8_t to = (uint8_t) state->cmdp[2];
        if (!(is_lower
              ? ASCII_ISLOWER(to)
              : (is_digit
                 ? ascii_isdigit(to)
                 : ASCII_ISUPPER(to)))) {
          ret_parsed->error.message = N_("E475: Trying to construct range out "
                                         "of marks from different sets");
          ret_parsed->error.position = state->cmdp + 2;
          return NOTDONE;
        } else if (to < from) {
          ret_parsed->error.message =
              N_("E475: Upper range bound is less then lower range bound");
          ret_parsed->error.position = state->cmdp + 2;
          return NOTDONE;
        }
        memset(&marks[from - FIRST_MARK_CODE], 'Y',
               ((size_t) (to - from) + 1));
        state->cmdp += 2;
      } else {
        marks[*state->cmdp - FIRST_MARK_CODE] = 'Y';
      }
    } else {
      switch (*state->cmdp) {
        case '"':
        case '^':
        case '.':
        case '[':
        case ']':
        case '<':
        case '>': {
          marks[*state->cmdp - FIRST_MARK_CODE] = 'Y';
          break;
        }
        case ' ': {
          break;
        }
        default: {
          ret_parsed->error.message = N_("E475: Unknown mark");
          ret_parsed->error.position = state->cmdp;
          return NOTDONE;
        }
      }
    }
  }
  ret_parsed->node->args[ARG_NAME_NAME].arg.str =
      xmemdupz(&marks[0], MAX_NUM_MARKS);
  return OK;
}

static CMD_P_DEF(parse_display)
{
  if (*state->cmdp == NUL) {
    return OK;
  }
#define REGSTART 0x20
#define REGNUM 0x5F - REGSTART + 1
  char regtab[REGNUM];
  size_t reglen = 0;
  memset(regtab, 0, REGNUM);
  for (; *state->cmdp; state->cmdp++) {
    if (!valid_yank_reg(*state->cmdp, false)) {
      continue;
    }
    uint8_t reg = (uint8_t) TOUPPER_ASC(*state->cmdp);
    assert(reg - REGSTART < REGNUM && reg > REGSTART);
    if (!regtab[reg - REGSTART]) {
      reglen++;
    }
    regtab[reg - REGSTART] = 1;
  }
  char *regnames = xmallocz(reglen);
  char *cur_regname = regnames;
  for (uint8_t i = 0; i < REGNUM; i++) {
    if (regtab[i]) {
      *cur_regname++ = (char) TOLOWER_ASC(i + REGSTART);
    }
  }
  ret_parsed->node->args[ARG_NAME_NAME].arg.str = regnames;
#undef REGSTART
#undef REGNUM
  return OK;
}

static CMD_P_DEF(parse_digraphs)
{
  const char *const s = state->cmdp;
  if (*state->cmdp == NUL) {
    return OK;
  }

  size_t dig_count = 0;

  while (*state->cmdp != NUL) {
    state->cmdp = skipwhite(state->cmdp);
    if (*state->cmdp == NUL) {
      return OK;
    } else if (*state->cmdp == ESC) {
      goto parse_digraphs_esc_error;
    }
    mb_ptr_adv_(state->cmdp);
    if (*state->cmdp == NUL) {
      ret_parsed->error.message =
          N_("E474: Expected second digraph character, but got nothing");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    } else if (*state->cmdp == ESC) {
      goto parse_digraphs_esc_error;
    }
    mb_ptr_adv_(state->cmdp);
    state->cmdp = skipwhite(state->cmdp);
    if (!ascii_isdigit(*state->cmdp)) {
      ret_parsed->error.message = (const char *) e_number_exp;
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
    state->cmdp = skipdigits(state->cmdp);
    dig_count++;
  }

  if (dig_count == 0) {
    return OK;
  }

  state->cmdp = s;

  char **const digraphs = xmalloc(sizeof(char *) * (dig_count + 1));
  uint_least32_t *const codepoints =
      xmalloc(sizeof(uint_least32_t) * dig_count);

  char **cur_dig = digraphs;
  uint_least32_t *cur_cp = codepoints;

  while (dig_count) {
    state->cmdp = skipwhite(state->cmdp);
    const char *const dig_start = state->cmdp;
    mb_ptr_adv_(state->cmdp);
    mb_ptr_adv_(state->cmdp);
    *cur_dig++ = xmemdupz(dig_start, (size_t) (state->cmdp - dig_start));
    state->cmdp = skipwhite(state->cmdp);
    *cur_cp++ = (uint_least32_t) getdigits(&state->cmdp);
    dig_count--;
  }
  *cur_dig = NULL;
  ret_parsed->node->args[ARG_DIG_DIGRAPHS].arg.strs = digraphs;
  ret_parsed->node->args[ARG_DIG_CHARS].arg.unumbers = codepoints;
  return OK;
parse_digraphs_esc_error:
  ret_parsed->error.message = N_("E104: Escape not allowed in digraph");
  ret_parsed->error.position = state->cmdp;
  return NOTDONE;
}

static CMD_P_DEF(parse_later)
{
  uint_least32_t later_type = VAL_LATER_COUNT;
  unsigned count = 1;
  if (ascii_isdigit(*state->cmdp)) {
    count = (unsigned) getdigits(&state->cmdp);
    switch (*state->cmdp) {
#define LATER_TYPE(ch, type) \
      case ch: { \
        state->cmdp++; \
        later_type = VAL_LATER_##type; \
        break; \
      }
      LATER_TYPE('s', SECONDS)
      LATER_TYPE('m', MINUTES)
      LATER_TYPE('h', HOURS)
      LATER_TYPE('d', DAYS)
      LATER_TYPE('f', FILE)
#undef LATER_TYPE
      case NUL: {
        break;
      }
      default: {
        ret_parsed->error.message =
            N_("E475: Expected 's', 'm', 'h', 'd', 'f' or nothing "
               "after number");
        ret_parsed->error.position = state->cmdp;
        return NOTDONE;
      }
    }
    if (*state->cmdp != NUL) {
      ret_parsed->error.message = N_("E475: Trailing characters");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
  } else if (*state->cmdp != NUL) {
    ret_parsed->error.message = N_("E475: Expected numeric argument");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
  ret_parsed->node->args[ARG_LATER_FLAGS].arg.flags = later_type;
  ret_parsed->node->args[ARG_LATER_COUNT].arg.unumber = count;
  return OK;
}

static CMD_P_DEF(parse_filetype)
{
  if (*state->cmdp == NUL) {
    return OK;
  }
  uint_least32_t flags = 0;
  for (;;) {
    if (strncmp(state->cmdp, "plugin", 6) == 0) {
      flags |= FLAG_FT_PLUGIN;
      state->cmdp = skipwhite(state->cmdp + 6);
      continue;
    } else if (strncmp(state->cmdp, "indent", 6) == 0) {
      flags |= FLAG_FT_INDENT;
      state->cmdp = skipwhite(state->cmdp + 6);
      continue;
    }
    break;
  }
  if (strcmp(state->cmdp, "on") == 0) {
    flags |= FLAG_FT_ON;
    state->cmdp += 2;
  } else if (strcmp(state->cmdp, "detect") == 0) {
    flags |= FLAG_FT_DETECT;
    state->cmdp += 6;
  } else if (strcmp(state->cmdp, "off") == 0) {
    flags |= FLAG_FT_OFF;
    state->cmdp += 3;
  } else {
    ret_parsed->error.message =
        N_("E475: Invalid syntax: expected "
           "`filetype[ [plugin|indent]... {on|off|detect}]'");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
  ret_parsed->node->args[ARG_FT_FLAGS].arg.flags = flags;
  return OK;
}

static CMD_P_DEF(parse_history)
{
  uint_least32_t flags = 0;
  if (!(ascii_isdigit(*state->cmdp) || *state->cmdp == '-'
        || *state->cmdp == ',')) {
    const char *end = state->cmdp;
    while (*end && (ASCII_ISALPHA(*end) || strchr(":=@>/?", *end) != NULL)) {
      end++;
    }
    HistoryType histtype = get_histtype(state->cmdp,
                                        (size_t) (end - state->cmdp), true);
    switch (histtype) {
      case HIST_INVALID: {
        if (STRNICMP(state->cmdp, "all", end - state->cmdp) == 0) {
          flags |= FLAG_HIST_ALL;
          break;
        } else {
          ret_parsed->error.message =
              N_("E488: Expected history name or nothing");
          ret_parsed->error.position = state->cmdp;
          return NOTDONE;
        }
      }
#define HIST_TO_FLAG(h) \
      case HIST_##h: { \
        flags |= FLAG_HIST_##h; \
        break; \
      }
      HIST_TO_FLAG(DEFAULT)
      HIST_TO_FLAG(CMD)
      HIST_TO_FLAG(SEARCH)
      HIST_TO_FLAG(EXPR)
      HIST_TO_FLAG(INPUT)
      HIST_TO_FLAG(DEBUG)
#undef HIST_TO_FLAG
    }
    state->cmdp = end;
  } else {
    flags |= FLAG_HIST_DEFAULT;
  }
  ret_parsed->node->args[ARG_HIST_FIRST].arg.number = 1;
  ret_parsed->node->args[ARG_HIST_LAST].arg.number = -1;
  if (get_list_range(
          &state->cmdp,
          &ret_parsed->node->args[ARG_HIST_FIRST].arg.number,
          &ret_parsed->node->args[ARG_HIST_LAST].arg.number) != OK) {
    ret_parsed->error.message = N_("E488: Expected valid history lines range");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
  ret_parsed->node->args[ARG_HIST_FLAGS].arg.flags = flags;
  return OK;
}

static CMD_P_DEF(parse_mark)
{
  if (*state->cmdp == NUL) {
    ret_parsed->error.message = N_("E471: Expected mark name");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
  if (   ASCII_ISLOWER(*state->cmdp)
      || ASCII_ISUPPER(*state->cmdp)
      || *state->cmdp == '\''
      || *state->cmdp == '`') {
    ret_parsed->node->args[ARG_MARK_CHAR].arg.ch = *state->cmdp;
    state->cmdp++;
  } else {
    ret_parsed->error.message =
        N_("E191: Argument must be a letter or forward/backward quote");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
  return OK;
}

static CMD_P_DEF(parse_popup)
{
  return parse_menu_name(
      state, ret_parsed, kMenuWholeCmd,
      &ret_parsed->node->args[ARG_POPUP_NAME].arg.menu_item, NULL);
}

static CMD_P_DEF(parse_make)
{
  // Warning: Vim redirects parsing to :vimgrep if &grepprg is "internal".
  // Parser cannot do this.
  return parse_rest_allow_empty(state, ret_parsed);
}

static CMD_P_DEF(parse_retab)
{
  const char *const s = state->cmdp;
  int new_ts = (int) getdigits(&state->cmdp);
  if (new_ts < 0) {
    ret_parsed->error.message = (const char *) e_positive;
    ret_parsed->error.position = s;
    return NOTDONE;
  }
  ret_parsed->node->count = new_ts;
  return OK;
}

static CMD_P_DEF(parse_resize)
{
  int n = atoi(state->cmdp);
  bool relative = (*state->cmdp == '-' || *state->cmdp == '+');
  ret_parsed->node->args[ARG_RESIZE_FLAGS].arg.flags =
      (uint_least32_t) relative;
  ret_parsed->node->args[ARG_RESIZE_NUMBER].arg.number = n;
  state->cmdp += strlen(state->cmdp);
  return OK;
}

static CMD_P_DEF(parse_redir)
{
  uint_least32_t flags = 0;
  switch (*state->cmdp) {
    case '>': {
      state->cmdp++;
      if (*state->cmdp == '>') {
        state->cmdp++;
        flags |= FLAG_REDIR_APPEND;
      }
      state->cmdp = skipwhite(state->cmdp);
      size_t len = strlen(state->cmdp);
      ret_parsed->node->args[ARG_REDIR_FILE].arg.str =
          xmemdupz(state->cmdp, len);
      state->cmdp += len;
      break;
    }
    case '@': {
      state->cmdp++;
      if (*state->cmdp == NUL) {
        // :redir @ seems to behave the same way as :redir END.
      } else if (ASCII_ISALPHA(*state->cmdp)
                 || strchr("\"*+", *state->cmdp) != NULL) {
        flags |= (((uint_least32_t) (*state->cmdp)) & FLAG_REDIR_REG_MASK);
        state->cmdp++;
        if (*state->cmdp == '>') {
          state->cmdp++;
          if (*state->cmdp == '>') {
            state->cmdp++;
            flags |= FLAG_REDIR_APPEND;
          }
        }
      } else {
        ret_parsed->error.message =
            N_("E475: Expected register name; one of A-Z, a-z, \", * and +");
        ret_parsed->error.position = state->cmdp;
        return NOTDONE;
      }
      break;
    }
    case '=': {
      state->cmdp++;
      if (*state->cmdp == '>') {
        state->cmdp++;
        Expression *expr;
        int ret;

        if ((ret = parse_lval(state, ret_parsed, &expr, 0)) == FAIL) {
          return FAIL;
        }
        ret_parsed->node->args[ARG_REDIR_VAR].arg.expr = expr;
        if (ret == NOTDONE) {
          return NOTDONE;
        }
      } else {
        ret_parsed->error.message = N_("E475: Expected `>' and variable name");
        ret_parsed->error.position = state->cmdp;
        return NOTDONE;
      }
      break;
    }
    case 'E':
    case 'e': {
      if (STRICMP(state->cmdp, "END") == 0) {
        state->cmdp += 3;
      } else {
        ret_parsed->error.message = N_("E475: Expected `END'");
        ret_parsed->error.position = state->cmdp + 1;
        return NOTDONE;
      }
      break;
    }
    default: {
      ret_parsed->error.message =
          N_("E475: Expected `END', `>[>] {file}', "
             "`@{register}[>[>]]' or `=> {variable}'");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
  }
  ret_parsed->node->args[ARG_REDIR_FLAGS].arg.flags = flags;
  return OK;
}

static CMD_P_DEF(parse_script)
{
  garray_T *ga_strs =
      &ret_parsed->node->args[ARG_APPEND_LINES].arg.ga_strs;

  ga_init(ga_strs, sizeof(char *), 16);

  if (state->cmdp[0] != '<' || state->cmdp[1] != '<') {
    size_t len = strlen(state->cmdp);
    GA_APPEND(char *, ga_strs, xmemdupz(state->cmdp, len));
    state->cmdp += len;
  } else {
    state->cmdp = skipwhite(state->cmdp + 2);
    const char *const end_pattern = (*state->cmdp ? state->cmdp : ".");
    CommandParserState saved_state = *state;
    while (nextline(state, ':', 0)) {
      if (strcmp(end_pattern, state->s) == 0) {
        freeline(state);
        break;
      }
      GA_APPEND(char *, ga_strs,
                state->line.can_free ? (char *) state->s : xstrdup(state->s));
      state->s = state->cmdp = NULL;
    }
    // Need to free the first line, but only after `end_pattern` is no longer
    // useful.
    freeline(&saved_state);
  }
  return OK;
}

static CMD_P_DEF(parse_open)
{
  if (*state->cmdp == '/') {
    state->cmdp++;
    int rret;
    if ((rret = get_regex(
                state, ret_parsed,
                &ret_parsed->node->args[ARG_OPEN_REGEX].arg.reg, '/',
                NULL)) != OK) {
      return rret;
    }
    // Ignore any other arguments
    state->cmdp += strlen(state->cmdp);
  } else if (*state->cmdp != NUL) {
    const size_t len = strlen(state->cmdp);
    ret_parsed->node->args[ARG_OPEN_FILE].arg.str =
        xmemdupz(state->cmdp, len);
    state->cmdp += len;
  }
  return OK;
}

static CMD_P_DEF(parse_global)
{
  uint_least32_t flags = 0;
  // Udocumented Vi feature:
  //  :g\/ and :g\?: use previous search pattern
  //  :g\&         : use previous substitute pattern
  if (*state->cmdp == '\\') {
    state->cmdp++;
    if (*state->cmdp == '&') {
      flags |= FLAG_G_RE_SUBST;
    } else if (*state->cmdp == '/' || *state->cmdp == '?') {
      flags |= FLAG_G_RE_SEARCH;
    } else {
      ret_parsed->error.message = (const char *) e_backslash;
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
    state->cmdp++;
  } else if (*state->cmdp == NUL) {
    ret_parsed->error.message =
        N_("E148: Regular expression missing from global");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  } else {
    state->cmdp++;
    int rret;
    if ((rret = get_regex(state, ret_parsed,
                          &ret_parsed->node->args[ARG_G_REG].arg.reg,
                          state->cmdp[-1], NULL))
        != OK) {
      return rret;
    }
  }
  ret_parsed->node->args[ARG_G_FLAGS].arg.flags = flags;
  if (*state->cmdp != NUL) {
    return parse_do(state, ret_parsed);
  }
  return OK;
}

static CMD_P_DEF(parse_vimgrep)
{
  Regex *regex = NULL;
  uint_least32_t flags = 0;
  // ":vimgrep pattern fname"
  if (vim_isIDc(*state->cmdp)) {
    const char *const s = state->cmdp;
    state->cmdp = skiptowhite(state->cmdp);
    regex = regex_alloc(s, (size_t) (state->cmdp - s));
  } else {
    state->cmdp++;
    int rret;
    if ((rret = get_regex(state, ret_parsed, &regex, state->cmdp[-1], NULL))
        != OK) {
      return rret;
    }
    for (;;) {
      switch (*state->cmdp) {
        case 'g': {
          flags |= FLAG_VIMG_EVERY;
          state->cmdp++;
          continue;
        }
        case 'j': {
          flags |= FLAG_VIMG_NOJUMP;
          state->cmdp++;
          continue;
        }
        default: {
          break;
        }
      }
      break;
    }
  }
  ret_parsed->node->args[ARG_VIMG_FLAGS].arg.flags = flags;
  ret_parsed->node->args[ARG_VIMG_REG].arg.reg = regex;
  state->cmdp = skipwhite(state->cmdp);
  if (*state->cmdp == NUL) {
    ret_parsed->error.message =
        N_("E683: File name missing or invalid pattern");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
  return parse_files(state, ret_parsed);
}

static CMD_P_DEF(parse_gui)
{
  if (*state->cmdp == '-' && (state->cmdp[1] == 'f' || state->cmdp[1] == 'b')
      && (!state->cmdp[2] || ascii_iswhite(state->cmdp[2]))) {
    ret_parsed->node->args[ARG_GUI_FG].arg.flags =
        (uint_least32_t) (state->cmdp[1] == 'f');
    state->cmdp = skipwhite(state->cmdp + 2);
  }
  if (*state->cmdp == NUL) {
    return OK;
  }
  return parse_files(state, ret_parsed);
}

static CMD_P_DEF(parse_marks)
{
  const char *const s = state->cmdp;
  size_t marksnum = 0;
  for (; *state->cmdp; state->cmdp++) {
    if (ASCII_ISALPHA(*state->cmdp)
        || strchr("'\"[]^.<>", *state->cmdp) != NULL) {
      marksnum++;
    }
  }
  char *const marks = xmallocz(marksnum);
  char *cur_mark = marks;
  for (const char *p = s; *p; p++) {
    if (ASCII_ISALPHA(*p) || strchr("'\"[]^.<>", *p) != NULL) {
      *cur_mark++ = *p;
    }
  }
  ret_parsed->node->args[ARG_NAME_NAME].arg.str = marks;
  return OK;
}

static CMD_P_DEF(parse_match)
{
  if (*state->cmdp == NUL) {
    return OK;
  } else if (STRNICMP(state->cmdp, "none", 4) == 0
             && (ascii_iswhite(state->cmdp[4]) || ENDS_EXCMD(state->cmdp[4]))) {
    state->cmdp += 4;
    return OK;
  }
  const char *const s = state->cmdp;
  state->cmdp = skiptowhite(state->cmdp);
  ret_parsed->node->args[ARG_MATCH_GROUP].arg.str =
      xmemdupz(s, (size_t) (state->cmdp - s));
  state->cmdp = skipwhite(state->cmdp);
  if (*state->cmdp == NUL) {
    ret_parsed->error.message = N_("E475: Expected regular expression");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
  state->cmdp++;
  int rret;
  if ((rret = get_regex(state, ret_parsed,
                        &ret_parsed->node->args[ARG_MATCH_REG].arg.reg,
                        state->cmdp[-1], NULL)) != OK) {
    return rret;
  }
  state->cmdp = skipwhite(state->cmdp);
  return OK;
}

///< Structure that holds :set arguments
typedef struct set_arg {
  const char *name;      ///< Address of the first character of the option name.
  size_t name_len;       ///< Name length.
  int opt_idx;           ///< Option index or -1.
  int key;               ///< Key index or 0.
  uint_least32_t flags;  ///< Flags.
  const char *value;     ///< String value.
  size_t value_len;      ///< Value length.
  long ivalue;           ///< Integer value.
  struct set_arg *next;  ///< Next processed option.
} SetArg;

static int wildcharm_idx = -2;
static int wildchar_idx = -2;

static CMD_P_DEF(parse_set)
{
  if (*state->cmdp == NUL) {
    return OK;
  }
  if (wildcharm_idx == -2) {
#define FINDOPTION(s) findoption_len(s, sizeof(s) - 1)
    wildcharm_idx = FINDOPTION("wildcharm");
    wildchar_idx = FINDOPTION("wildchar");
#undef FINDOPTION
  }
  size_t num_options = 0;
  SetArg *args;
  SetArg **next = &args;
  while (ASCII_ISLOWER(*state->cmdp) || *state->cmdp == '<') {
    const char *const start_arg = state->cmdp;
    *next = xcalloc(1, sizeof(**next));
    num_options++;
    if (strncmp(state->cmdp, "all", 3) == 0 && !ASCII_ISALPHA(state->cmdp[3])) {
      (*next)->name = state->cmdp;
      (*next)->name_len = 3;
      (*next)->opt_idx = -1;
      state->cmdp += 3;
      if (*state->cmdp == '&') {
        state->cmdp++;
        (*next)->flags |= FLAG_SET_DEFAULT;
      } else {
        (*next)->flags |= FLAG_SET_SHOW;
      }
    } else if (STRNCMP(state->cmdp, "termcap", 7) == 0) {
      (*next)->name = state->cmdp;
      (*next)->name_len = 7;
      (*next)->opt_idx = -1;
      (*next)->flags |= FLAG_SET_SHOW;
      state->cmdp += 7;
    } else {
      if (strncmp(state->cmdp, "no", 2) == 0
          && strncmp(state->cmdp, "novice", 6) != 0) {
        (*next)->flags |= FLAG_SET_UNSET;
        state->cmdp += 2;
      } else if (strncmp(state->cmdp, "inv", 3) == 0) {
        (*next)->flags |= FLAG_SET_INVERT;
        state->cmdp += 3;
      }
      int key = 0;
      size_t len = 0;
      int nextchar = 0;
      int opt_idx = -1;
      if (*state->cmdp == '<') {
        if (state->cmdp[1] == 't' && state->cmdp[2] == '_'
            && state->cmdp[3] && state->cmdp[4]) {
          len = 5;
        } else {
          len = 1;
          while (state->cmdp[len] && state->cmdp[len] != '>') {
            len++;
          }
        }
        if (state->cmdp[len] != '>') {
          ret_parsed->error.message = N_("E474: Expected `<'");
          ret_parsed->error.position = state->cmdp + len;
          goto parse_set_error;
        }
        opt_idx = findoption_len(state->cmdp + 1, len - 1);
        len++;
        if (opt_idx == -1) {
          key = find_key_option_len(state->cmdp + 1, len);
          (*next)->name = state->cmdp;
          (*next)->name_len = len;
        } else {
          (*next)->name = state->cmdp + 1;
          (*next)->name_len = len - 2;
        }
      } else {
        if (state->cmdp[0] == 't' && state->cmdp[1] == '_'
            && state->cmdp[2] && state->cmdp[3]) {
          len = 4;
        } else {
          while (ASCII_ISALNUM(state->cmdp[len]) || state->cmdp[len] == '_') {
            len++;
          }
        }
        opt_idx = findoption_len(state->cmdp, len);
        if (opt_idx == -1) {
          key = find_key_option_len(state->cmdp, len);
        }
        (*next)->name = state->cmdp;
        (*next)->name_len = len;
      }

      if (opt_idx == -1 && key == 0) {
        ret_parsed->error.message = N_("E518: Unknown option");
        ret_parsed->error.position = state->cmdp;
        goto parse_set_error;
      }

      (*next)->opt_idx = opt_idx;
      (*next)->key = key;

      int afterchar = state->cmdp[len];
      while (ascii_iswhite(state->cmdp[len])) {
        len++;
      }

      if (state->cmdp[len] && state->cmdp[len + 1] == '=') {
        switch (state->cmdp[len]) {
          case '+': {
            (*next)->flags |= FLAG_SET_APPEND;
            len++;
            break;
          }
          case '-': {
            (*next)->flags |= FLAG_SET_REMOVE;
            len++;
            break;
          }
          case '^': {
            (*next)->flags |= FLAG_SET_PREPEND;
            len++;
            break;
          }
          default: {
            break;
          }
        }
      }
      nextchar = state->cmdp[len];

      uint_least8_t properties;

      if (opt_idx >= 0) {
        properties = get_option_properties_idx(opt_idx);
      } else {
        // Key properties
        properties = GOP_STRING|GOP_GLOBAL;
      }

      state->cmdp += len;
      if (nextchar == '&' && state->cmdp[1] == 'v' && state->cmdp[2] == 'i') {
        (*next)->flags |= FLAG_SET_DEFAULT;
        if (state->cmdp[3] == 'm') {
          (*next)->flags |= FLAG_SET_VIM;
          state->cmdp += 3;
        } else {
          (*next)->flags |= FLAG_SET_VI;
          state->cmdp += 2;
        }
      }
      if (nextchar && strchr("?!&<", nextchar) != NULL
          && state->cmdp[1] != NUL && !ascii_iswhite(state->cmdp[1])) {
        ret_parsed->error.message = (const char *) e_trailing;
        ret_parsed->error.position = state->cmdp + 1;
        goto parse_set_error;
      }

      if (nextchar == '?' || (
              ((*next)->flags & (FLAG_SET_UNSET|FLAG_SET_INVERT)) == 0
              && (!nextchar || strchr("=:&<", nextchar) == NULL)
              && !(properties & GOP_BOOLEAN))) {
        (*next)->flags |= FLAG_SET_SHOW;
        if (nextchar == '?') {
          state->cmdp++;
        }
      } else {
        if (properties & GOP_BOOLEAN) {
          if (nextchar == '=' || nextchar == ':') {
            ret_parsed->error.message =
                N_("E474: Cannot set boolean options with `=' or `:'");
            ret_parsed->error.position = state->cmdp;
            goto parse_set_error;
          }
          switch (nextchar) {
            case '!': {
              (*next)->flags |= FLAG_SET_INVERT;
              state->cmdp++;
              break;
            }
            case '&': {
              (*next)->flags |= FLAG_SET_DEFAULT;
              state->cmdp++;
              break;
            }
            case '<': {
              (*next)->flags |= FLAG_SET_GLOBAL;
              state->cmdp++;
              break;
            }
            case NUL: {
              break;
            }
            default: {
              if (!ascii_iswhite(afterchar)) {
                ret_parsed->error.message = (const char *) e_trailing;
                ret_parsed->error.position = state->cmdp;
                goto parse_set_error;
              }
              break;
            }
          }
        } else {
          if ((nextchar && strchr("=:&<", nextchar) == NULL)) {
            ret_parsed->error.message =
                N_("E474: Expected `=', `:', `&' or `<'");
            ret_parsed->error.position = state->cmdp;
            goto parse_set_error;
          }
          if ((*next)->flags & (FLAG_SET_UNSET|FLAG_SET_INVERT)) {
            ret_parsed->error.message =
                N_("E474: Cannot invert or unset non-boolean option");
            ret_parsed->error.position = start_arg;
            goto parse_set_error;
          }
          if (properties & GOP_NUMERIC) {
            state->cmdp++;
            if (nextchar == '&') {
              (*next)->flags |= FLAG_SET_DEFAULT;
            } else if (nextchar == '<') {
              (*next)->flags |= FLAG_SET_GLOBAL;
            } else if ((opt_idx == wildcharm_idx
                        || opt_idx == wildchar_idx)
                       && (*state->cmdp == '<' || *state->cmdp == '^'
                           || ((!state->cmdp[1]
                                || ascii_iswhite(state->cmdp[1]))
                               && !ascii_isdigit(*state->cmdp)))) {
              (*next)->ivalue = string_to_key(state->cmdp);
              (*next)->flags |= FLAG_SET_IVALUE|FLAG_SET_ASSIGN;
              if ((*next)->ivalue == 0 && opt_idx == wildcharm_idx) {
                ret_parsed->error.message = N_("E474: Expected key definition");
                ret_parsed->error.position = state->cmdp;
                goto parse_set_error;
              }
              while (*state->cmdp != NUL && !ascii_iswhite(*state->cmdp)) {
                if (*state->cmdp++ == '\\' && *state->cmdp != NUL) {
                  state->cmdp++;
                }
              }
            } else if (*state->cmdp == '-' || ascii_isdigit(*state->cmdp)) {
              (*next)->flags |= FLAG_SET_IVALUE|FLAG_SET_ASSIGN;
              int ilen = 0;
              vim_str2nr(state->cmdp, NULL, &ilen, true, true,
                         &((*next)->ivalue), NULL);
              if (state->cmdp[ilen] && !ascii_iswhite(state->cmdp[ilen])) {
                ret_parsed->error.message =
                    N_("E474: Only numbers are allowed");
                ret_parsed->error.position = state->cmdp;
                goto parse_set_error;
              }
              state->cmdp += ilen;
            } else {
              ret_parsed->error.message = N_("E521: Number required after =");
              ret_parsed->error.position = state->cmdp;
              goto parse_set_error;
            }
          } else if (opt_idx >= 0) {
            state->cmdp++;
            if (nextchar == '&') {
              (*next)->flags |= FLAG_SET_DEFAULT;
            } else if (nextchar == '<') {
              (*next)->flags |= FLAG_SET_GLOBAL;
            } else {
              (*next)->flags |= FLAG_SET_ASSIGN;
              size_t arglen = 0;
              for (; state->cmdp[arglen] && !ascii_iswhite(state->cmdp[arglen]);
                   arglen++) {
                if (state->cmdp[arglen] == '\\') {
                  arglen++;
                }
              }
              (*next)->value = state->cmdp;
              (*next)->value_len = arglen;
              state->cmdp += arglen;
            }
          } else {
            assert(nextchar == '=');
            (*next)->flags |= FLAG_SET_ASSIGN;
            state->cmdp++;
            size_t arglen = 0;
            for (; state->cmdp[arglen] && !ascii_iswhite(state->cmdp[arglen]);
                 arglen++) {
              if (state->cmdp[arglen] == '\\') {
                arglen++;
              }
            }
            (*next)->value = state->cmdp;
            (*next)->value_len = arglen;
            state->cmdp += arglen;
          }
        }
      }
    }
    state->cmdp = skipwhite(state->cmdp);
    next = &((*next)->next);
  }
  // Note: using num_options + 1 here to have place for NULL which indicates
  //       number of options set. It is not indicated anywhere else.
  char **const names = ret_parsed->node->args[ARG_SET_OPTIONS].arg.strs =
      xmalloc(sizeof(char *) * (num_options + 1));
  // Note: using xcalloc so that NULLs will appear where appropriate.
  // Note: using num_options + 1 here because trailing NULL is needed for
  //       free_cmd_arg(). One should not use it to determine whether option
  //       list ended.
  char **const values = ret_parsed->node->args[ARG_SET_VALUES].arg.strs =
      xcalloc(num_options + 1, sizeof(char *));
  uint_least32_t *const flagss =
      ret_parsed->node->args[ARG_SET_FLAGSS].arg.unumbers =
      xmalloc(sizeof(uint_least32_t) * num_options);
  uint_least32_t *const keys =
      ret_parsed->node->args[ARG_SET_KEYS].arg.unumbers =
      xmalloc(sizeof(uint_least32_t) * num_options);
  int *ivalues = ret_parsed->node->args[ARG_SET_IVALUES].arg.numbers =
      xmalloc(sizeof(int) * num_options);
  int *opt_idxs = ret_parsed->node->args[ARG_SET_INDEXES].arg.numbers =
      xmalloc(sizeof(int) * num_options);
  SetArg *cur = args;
  for (size_t i = 0; cur != NULL; i++) {
    names[i] = xmemdupz(cur->name, cur->name_len);
    if (cur->value != NULL) {
      values[i] = xmemdupz(cur->value, cur->value_len);
      str_unescape(values[i], false);
    } else {
      values[i] = (char *) empty_string;
    }
    flagss[i] = cur->flags;
    keys[i] = (uint_least32_t) cur->key;
    // TODO(ZyX-I): Hold long?
    ivalues[i] = (int) cur->ivalue;
    opt_idxs[i] = cur->opt_idx;
    SetArg *prev = cur;
    cur = cur->next;
    xfree(prev);
  }
  names[num_options] = NULL;
  return OK;
parse_set_error:
  for (SetArg *cur = args; cur != NULL;) {
    SetArg *prev = cur;
    cur = prev->next;
    xfree(prev);
  }
  return NOTDONE;
}

static CMD_P_DEF(parse_sleep)
{
  switch (*state->cmdp) {
    case 'm': {
      // :sleep in Vim ignores characters after 'm'
      state->cmdp += strlen(state->cmdp);
      break;
    }
    case NUL: {
      ret_parsed->node->args[ARG_SLEEP_MULT].arg.unumber = 1000;
      break;
    }
    default: {
      ret_parsed->error.message = N_("E475: Expected `m' or nothing");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
  }
  return OK;
}

static const Replacement prev_rep = {
  .type = kRepPrevSub,
};

/// Parse replacement string
///
/// @param[in,out]  state  Parser state.
/// @param[out]  ret_parsed  Location where error will be saved.
/// @param[out]  rep  Location where result will be saved.
/// @param[in]  delim  Delimiter (character at which replacement string should
///                    end).
/// @param[in]  magic  True if &magic is enabled.
///
/// @return OK (success), FAIL (unrecoverable error) or NOTDONE (error).
static int parse_replacement(CMD_P_ARGS, Replacement **rep, const char delim,
                             const bool magic)
{
  const char *const sub_start = state->cmdp;
  Replacement **next = rep;
  while (*state->cmdp) {
    if (*state->cmdp == delim) {
      break;
    }
    if (*state->cmdp == '\\' && state->cmdp[1]) {
      state->cmdp++;
    }
    mb_ptr_adv_(state->cmdp);
  }
  if (state->cmdp - sub_start == 1 && *sub_start == '%' && CPO_SUBPC(state)) {
    *next = (Replacement *) &prev_rep;
  } else {
    if (*sub_start == '\\' && sub_start[1] == '=') {
      char *const expr_str_start =
          xmemdupz(sub_start + 2, (size_t) (state->cmdp - sub_start) - 2);
      const char *expr_str = expr_str_start;
      Expression *expr;
      ExpressionParserError expr_error;

      expr = parse_one_expression(&expr_str, &expr_error, &parse0_err,
                                  P_COL(state, sub_start + 2));
      if (expr == NULL) {
        if (expr_error.message == NULL) {
          return FAIL;
        }
        ret_parsed->error.message = expr_error.message;
        ret_parsed->error.position = sub_start + 2
            + (expr_error.position - expr_str_start);
        return NOTDONE;
      }
      if (*expr_str) {
        // Expected expression to end here. Early return will result in
        // e_trailing error message.
        state->cmdp = sub_start + (expr_str - expr_str_start);
        xfree(expr_str_start);
        return OK;
      }
      xfree(expr_str_start);
      *next = replacement_alloc(kRepExpr, P_COL(state, sub_start),
                                COL(state) - 1);
      (*next)->data.expr = expr;
    } else {
      const char *p2 = sub_start;
      while (p2 < state->cmdp) {
        switch (*p2) {
          case '\\': {
            p2++;
            switch (*p2) {
#define REP_ATOM(ch, rep_type) \
              case ch: { \
                (*next) = replacement_alloc(rep_type, P_COL(state, p2 - 1), \
                                            P_COL(state, p2)); \
                p2++; \
                break; \
              }
              REP_ATOM('u', kRepCharUpCase)
              REP_ATOM('l', kRepCharDownCase)
              REP_ATOM('U', kRepUpCase)
              REP_ATOM('L', kRepDownCase)
              case 'e':
              REP_ATOM('E', kRepCaseEnd)
              REP_ATOM('0', kRepMatched)
              REP_ATOM('r', kRepNewLine)
#undef REP_ATOM
#define REP_ESC_ATOM(c, res) \
              case c: { \
                (*next) = replacement_alloc(kRepEscaped, P_COL(state, p2 - 1), \
                                            P_COL(state, p2)); \
                (*next)->data.ch = (uint32_t) (res); \
                p2++; \
                break; \
              }
              REP_ESC_ATOM('n', NUL)
              REP_ESC_ATOM('b', BS)
              REP_ESC_ATOM('t', TAB)
              // May as well use literal escapes for the characters below, but
              // these ones are explicitly mentioned in help.
              REP_ESC_ATOM('\\', '\\')
              REP_ESC_ATOM(CAR, CAR)
#undef REP_ESC_ATOM
              case '1':
              case '2':
              case '3':
              case '4':
              case '5':
              case '6':
              case '7':
              case '8':
              case '9': {
                (*next) = replacement_alloc(kRepGroup, P_COL(state, p2 - 1),
                                            P_COL(state, p2));
                (*next)->data.group = (uint8_t) (*p2 - '0');
                p2++;
                break;
              }
              case '&': {
                if (!magic) {
                  (*next) = replacement_alloc(kRepMatched, P_COL(state, p2 - 1),
                                              P_COL(state, p2));
                  p2++;
                  break;
                }
                // fallthrough
              }
              case '~': {
                if (!magic) {
                  (*next) = replacement_alloc(kRepPrevSub, P_COL(state, p2 - 1),
                                              P_COL(state, p2));
                  p2++;
                  break;
                }
                // fallthrough
              }
              default: {
                const char *const p2_s = p2;
                uint32_t ch = (uint32_t) mb_cptr2char_adv(&p2);
                (*next) = replacement_alloc(kRepEscLiteral,
                                            P_COL(state, p2_s - 1),
                                            P_COL(state, p2 - 1));
                (*next)->data.ch = ch;
                // TODO(ZyX-I): Give a warning in most cases because \x is
                //              reserved.
                break;
              }
            }
            break;
          }
          case '&': {
            if (magic) {
              (*next) = replacement_alloc(kRepMatched, P_COL(state, p2 - 1),
                                          P_COL(state, p2));
              p2++;
              break;
            }
            // fallthrough
          }
          case '~': {
            if (magic) {
              (*next) = replacement_alloc(kRepPrevSub, P_COL(state, p2 - 1),
                                          P_COL(state, p2));
              p2++;
              break;
            }
            // fallthrough
          }
          default: {
            const char *const p2_s = p2;
            while (p2 < state->cmdp && *p2 != '\\'
                   && ((*p2 != '~' && *p2 != '&')
                       || !magic)) {
              assert(*p2 != NUL);
              p2++;
            }
            (*next) = replacement_alloc(kRepLiteral, P_COL(state, p2_s),
                                        P_COL(state, p2));
            (*next)->data.str = xmemdupz(p2_s, (size_t) (p2 - p2_s));
            break;
          }
        }
        assert(*next != NULL);
        next = &((*next)->next);
      }
    }
  }
  return OK;
}

static CMD_P_DEF(parse_sub)
{
  uint_least32_t flags = 0;
  char delim = 0;
  if ((ret_parsed->node->type == kCmdSubstitute
       || ret_parsed->node->type == kCmdSmagic
       || ret_parsed->node->type == kCmdSnomagic)
      && *state->cmdp && !ascii_iswhite(*state->cmdp)
      && strchr("0123456789cegriIp|\"", *state->cmdp) == NULL) {
    if (isalpha(*state->cmdp)) {
      ret_parsed->error.message =
          N_("E146: Regular expressions can't be delimited by letters");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
    if (*state->cmdp == '\\') {
      state->cmdp++;
      switch (*state->cmdp) {
        case '/':
        case '?': {
          flags |= FLAG_S_RE_SEARCH;
          break;
        }
        case '&': {
          flags |= FLAG_S_RE_SUBST;
          break;
        }
        default: {
          ret_parsed->error.message = (char *) e_backslash;
          ret_parsed->error.position = state->cmdp;
          return NOTDONE;
        }
      }
      delim = *state->cmdp;
      state->cmdp++;
    } else {
      delim = *state->cmdp;
      state->cmdp++;
      int rret;
      if ((rret = get_regex(
                  state, ret_parsed,
                  &ret_parsed->node->args[ARG_S_REG].arg.reg, delim,
                  NULL)) != OK) {
        return rret;
      }
    }
    int pr_ret;
    if ((pr_ret = parse_replacement(
                state, ret_parsed,
                &ret_parsed->node->args[ARG_S_REP].arg.rep,
                delim,
                (ret_parsed->node->type == kCmdSubstitute
                 ? MAGIC(state)
                 : ret_parsed->node->type == kCmdSmagic)))
        != OK) {
      return pr_ret;
    }
    if (ret_parsed->node->args[ARG_S_REP].arg.rep == &prev_rep) {
      ret_parsed->node->args[ARG_S_REP].arg.rep = NULL;
      flags |= FLAG_S_SUB_PREV;
    }
  } else {
    delim = '&';
  }
  if (*state->cmdp == delim) {
    state->cmdp++;
  }
  while (*state->cmdp) {
    switch (*state->cmdp) {
#define S_FLAG(ch, flag) \
      case ch: { \
        flags |= flag; \
        state->cmdp++; \
        continue; \
      }
      S_FLAG('c', FLAG_S_CONFIRM)
      S_FLAG('n', FLAG_S_COUNT)
      S_FLAG('e', FLAG_S_NOERR)
      S_FLAG('r', FLAG_S_R)
      S_FLAG('p', FLAG_S_PRINT)
      S_FLAG('#', FLAG_S_PRINT_LNR)
      S_FLAG('l', FLAG_S_PRINT_LIST)
      S_FLAG('i', FLAG_S_IC)
      S_FLAG('I', FLAG_S_NOIC)
#undef S_FLAG
      case 'g': {
        if (state->o.flags & FLAG_POC_ED) {
          if (flags & FLAG_S_G) {
            flags &= ~FLAG_S_G;
            flags |= FLAG_S_G_REVERSE;
          } else {
            flags &= ~FLAG_S_G_REVERSE;
            flags |= FLAG_S_G;
          }
        } else {
          flags |= FLAG_S_G;
        }
        state->cmdp++;
        continue;
      }
      default: {
        break;
      }
    }
    break;
  }
  if (flags & FLAG_S_COUNT) {
    // TODO(ZyX-I): Give a warning here if COUNT and CONFIRM flags are both
    //              enabled.
    flags &= ~FLAG_S_CONFIRM;
  }
  state->cmdp = skipwhite(state->cmdp);
  if (ascii_isdigit(*state->cmdp)) {
    const char *const p_s = state->cmdp;
    ret_parsed->node->count = (int) getdigits(&state->cmdp);
    if (ret_parsed->node->count == 0) {
      ret_parsed->error.message = (char *) e_zerocount;
      ret_parsed->error.position = p_s;
      return NOTDONE;
    }
  }
  ret_parsed->node->args[ARG_S_FLAGS].arg.flags = flags;
  state->cmdp = skipwhite(state->cmdp);
  return OK;
}

static CMD_P_DEF(parse_sort)
{
  uint_least32_t flags = 0;
  for (; *state->cmdp; state->cmdp++) {
    switch (*state->cmdp) {
      case ' ':
      case TAB: {
        continue;
      }
#define SORT_FLAG(ch, flag) \
      case ch: { \
        flags |= flag; \
        continue; \
      }
      SORT_FLAG('i', FLAG_SORT_IC)
      SORT_FLAG('r', FLAG_SORT_USEMATCH)
      SORT_FLAG('u', FLAG_SORT_KEEPFST)
#undef SORT_FLAG
      case 'n': {
        flags |= FLAG_SORT_DECIMAL;
        if (flags & (FLAG_SORT_OCTAL | FLAG_SORT_HEX)) {
          goto parse_sort_numeric_error;
        }
        continue;
      }
      case 'o': {
        flags |= FLAG_SORT_OCTAL;
        if (flags & (FLAG_SORT_DECIMAL | FLAG_SORT_HEX)) {
          goto parse_sort_numeric_error;
        }
        continue;
      }
      case 'x': {
        flags |= FLAG_SORT_HEX;
        if (flags & (FLAG_SORT_DECIMAL | FLAG_SORT_OCTAL)) {
          goto parse_sort_numeric_error;
        }
        continue;
      }
      // ENDS_EXCMD
      case NL:
      case NUL:
      case '|':
      case '"': {
        break;
      }
      default: {
        if (ASCII_ISALPHA(*state->cmdp)) {
          ret_parsed->error.message =
              N_("E475: Expected sort flag or non-ASCII "
                 "regular expression delimiter");
          ret_parsed->error.position = state->cmdp;
          return NOTDONE;
        }
        const char delim = *state->cmdp;
        state->cmdp++;
        int rret;
        if (*state->cmdp == delim) {
          flags |= FLAG_SORT_RE_SEARCH;
          state->cmdp++;
        } else if ((rret = get_regex(
                    state, ret_parsed,
                    &ret_parsed->node->args[ARG_SORT_REG].arg.reg,
                    delim, (char *) e_invalpat)) != OK) {
          return rret;
        }
        break;
      }
    }
    break;
  }
  ret_parsed->node->args[ARG_SORT_FLAGS].arg.flags = flags;
  return OK;
parse_sort_numeric_error:
  ret_parsed->error.message =
      N_("E474: Can only specify one kind of numeric sort");
  ret_parsed->error.position = state->cmdp;
  return NOTDONE;
}

static CMD_P_DEF(parse_syntime)
{
  uint_least32_t action = 0;
  if (strcmp(state->cmdp, "on") == 0) {
    action = VAL_SYNTIME_ON;
  } else if (strcmp(state->cmdp, "off") == 0) {
    action = VAL_SYNTIME_OFF;
  } else if (strcmp(state->cmdp, "clear") == 0) {
    action = VAL_SYNTIME_CLEAR;
  } else if (strcmp(state->cmdp, "report") == 0) {
    action = VAL_SYNTIME_REPORT;
  } else {
    ret_parsed->error.message =
        N_("E475: Expected one action of `on', `off', `clear' or `report'");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
  ret_parsed->node->args[ARG_SYNTIME_ACTION].arg.flags = action;
  state->cmdp += strlen(state->cmdp);
  return OK;
}

static CMD_P_DEF(parse_2numbers)
{
  if (ret_parsed->node->type == kCmdWinpos && *state->cmdp == NUL) {
    ret_parsed->node->args[ARG_2INTS_FLAGS].arg.flags =
        (uint_least32_t) true;
    return OK;
  }
  ret_parsed->node->args[ARG_2INTS_NUM1].arg.number =
      (int) getdigits(&state->cmdp);
  state->cmdp = skipwhite(state->cmdp);
  const char *const num2_start = state->cmdp;
  ret_parsed->node->args[ARG_2INTS_NUM2].arg.number =
      (int) getdigits(&state->cmdp);
  if (*num2_start == NUL || *state->cmdp != NUL) {
    switch (ret_parsed->node->type) {
      case kCmdWinsize: {
        ret_parsed->error.message =
            N_("E465: :winsize requires two number arguments");
        break;
      }
      case kCmdWinpos: {
        ret_parsed->error.message =
            N_("E466: :winpos requires two number arguments");
        break;
      }
      default: {
        assert(false);
      }
    }
    ret_parsed->error.position = (*num2_start == NUL
                                  ? num2_start
                                  : state->cmdp);
    return NOTDONE;
  }
  return OK;
}

static CMD_P_DEF(parse_wincmd)
{
  uint8_t action = 0;
  switch (*state->cmdp) {
#define WINCMD_ACTION(ch) \
    case ch: { \
      action = (uint8_t) ch; \
      state->cmdp++; \
      break; \
    }
    // split current window in two parts, horizontally
    case 'S':
    case Ctrl_S:
    WINCMD_ACTION('s')
    // split current window in two parts, vertically
    case Ctrl_V:
    WINCMD_ACTION('v')
    // split current window and edit alternate file
    case Ctrl_HAT:
    WINCMD_ACTION('^')
    // open new window
    case Ctrl_N:
    WINCMD_ACTION('n')
    // quit current window
    case Ctrl_Q:
    WINCMD_ACTION('q')
    // close current window
    case Ctrl_C:
    WINCMD_ACTION('c')
    // close preview window
    case Ctrl_Z:
    WINCMD_ACTION('z')
    // cursor to preview window
    WINCMD_ACTION('P')
    // close all but current window
    case Ctrl_O:
    WINCMD_ACTION('o')
    // cursor to next window with wrap around
    case Ctrl_W:
    WINCMD_ACTION('w')
    // cursor to previous window with wrap around
    WINCMD_ACTION('W')
    // cursor to window below
    case Ctrl_J:
    WINCMD_ACTION('j')
    // cursor to window above
    case Ctrl_K:
    WINCMD_ACTION('k')
    // cursor to left window
    case Ctrl_H:
    WINCMD_ACTION('h')
    // cursor to right window
    case Ctrl_L:
    WINCMD_ACTION('l')
    // move window to new tab page
    WINCMD_ACTION('T')
    // cursor to top-left window
    case Ctrl_T:
    WINCMD_ACTION('t')
    // cursor to bottom-right window
    case Ctrl_B:
    WINCMD_ACTION('b')
    // cursor to last accessed (previous) window
    case Ctrl_P:
    WINCMD_ACTION('p')
    // exchange current and next window
    case Ctrl_X:
    WINCMD_ACTION('x')
    // rotate windows downwards
    case Ctrl_R:
    WINCMD_ACTION('r')
    // rotate windows upwards
    WINCMD_ACTION('R')
    // move window to the very top/bottom/left/right
    WINCMD_ACTION('K')
    WINCMD_ACTION('J')
    WINCMD_ACTION('H')
    WINCMD_ACTION('L')
    // make all windows the same height
    WINCMD_ACTION('=')
    // increase current window height
    WINCMD_ACTION('+')
    // decrease current window height
    WINCMD_ACTION('-')
    // set current window height
    case Ctrl__:
    WINCMD_ACTION('_')
    // increase current window width
    WINCMD_ACTION('>')
    // decrease current window width
    WINCMD_ACTION('<')
    // set current window width
    WINCMD_ACTION('|')
    // jump to tag and split window if tag exists (in preview window)
    WINCMD_ACTION('}')
    case Ctrl_RSB:
    WINCMD_ACTION(']')
    // edit file name under cursor in a new window
    case 'F':
    case Ctrl_F:
    WINCMD_ACTION('f')
    // Go to the first occurrence of the identifier under cursor along path in
    // a new window -- webb
    //
    // Go to any match
    WINCMD_ACTION('i')
    // Go to definition, using 'define'
    case Ctrl_D:
    WINCMD_ACTION('d')
    WINCMD_ACTION(CAR)
    // CTRL-W g  extended commands
    case 'g':
    case Ctrl_G: {
      state->cmdp++;
      switch (*state->cmdp) {
#define EXTENDED_WINCMD_ACTION(ch) \
        case ch: { \
          action = 0x80 | ((uint8_t) ch); \
          state->cmdp++; \
          break; \
        }
        EXTENDED_WINCMD_ACTION('}');
        case Ctrl_RSB:
        EXTENDED_WINCMD_ACTION(']');
        EXTENDED_WINCMD_ACTION('f');
        EXTENDED_WINCMD_ACTION('F');
#undef EXTENDED_WINCMD_ACTION
        case NUL: {
          ret_parsed->error.message =
              N_("E474: Expected extended window action "
                 "(see help tags starting with CTRL-W_g)");
          ret_parsed->error.position = state->cmdp + 1;
          return NOTDONE;
        }
        default: {
          state->cmdp++;
          break;
        }
      }
      break;
    }
    case NUL: {
      ret_parsed->error.message = (char *) e_argreq;
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
    default: {
      state->cmdp++;
      break;
    }
#undef WINCMD_ACTION
  }
  state->cmdp = skipwhite(state->cmdp);
  if (!ENDS_EXCMD(*state->cmdp)) {
    ret_parsed->error.message = N_("E474: Trailing characters");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
  ret_parsed->node->args[ARG_WINCMD_CHAR].arg.ch = (char) action;
  return OK;
}

static CMD_P_DEF(parse_z)
{
  const char kind = *state->cmdp;
  if (kind && strchr("-+=^.", kind) != NULL) {
    ret_parsed->node->args[ARG_Z_KIND].arg.ch = kind;
    state->cmdp++;
  }
  if (kind == '+' || kind == '-') {
    size_t multiplier = 1;
    while (state->cmdp[multiplier - 1] == kind) {
      multiplier++;
    }
    state->cmdp += multiplier - 1;
    ret_parsed->node->args[ARG_Z_MULTIPLIER].arg.unumber =
        (uint_least32_t) multiplier;
  }
  while (*state->cmdp == '-' || *state->cmdp == '+') {
    state->cmdp++;
  }
  if (*state->cmdp) {
    if (!ascii_isdigit(*state->cmdp)) {
      ret_parsed->error.message = N_("E144: non-numeric argument to :z");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    } else {
      ret_parsed->node->args[ARG_Z_BIGNESS].arg.unumber =
          (uint_least32_t) getdigits(&state->cmdp);
    }
  }
  return OK;
}

static CMD_P_DEF(parse_at)
{
  char c = *state->cmdp;
  if (c == NUL || (c == '*' && ret_parsed->node->type == kCmdStar)) {
    c = '@';
  }
  if (c != '@' && !valid_yank_reg(c, false)) {
    ret_parsed->error.message = (const char *) e_invalidreg;
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
  ret_parsed->node->args[ARG_MARK_CHAR].arg.ch = c;
  state->cmdp += STRLEN(state->cmdp);
  return OK;
}

/// Get :help language
///
/// @param[in]      s    Start of the checked string.
/// @param[in,out]  end  Pointer to the end (e.g. NUL character) of the checked
///                      string. Will be moved to the "@" sign if language was
///                      found.
///
/// @return Help language (NUL-terminated string with length equal to 2) or
///         NULL.
static inline char *get_help_lang(const char *const s, const char **end)
{
  const char *p = *end;
  if (p - 3 >= s
      && p[-3] == '@'
      && ASCII_ISALPHA(p[-2])
      && ASCII_ISALPHA(p[-1])) {
    *end -= 3;
    return xmemdupz(p - 2, 2);
  } else {
    return NULL;
  }
}

static CMD_P_DEF(parse_help)
{
  const char *const s = state->cmdp;
  const char *end = state->cmdp;
  while (*end && *end != '\n' && *end != '\r'
        && !(*end == '|' && end[1] && end[1] != '|')) {
    end++;
  }
  state->cmdp = end;
  // Remove trailing blanks
  while (end - 1 >= s && ascii_iswhite(end[-1]) && end[-2] != '\\') {
    end--;
  }
  ret_parsed->node->args[ARG_HELP_LANG].arg.str = get_help_lang(s, &end);
  if (end != s) {
    ret_parsed->node->args[ARG_HELP_TOPIC].arg.str =
        xmemdupz(s, (size_t) (end - s));
  }
  return OK;
}

static CMD_P_DEF(parse_helpgrep)
{
  const char *const p = state->cmdp;
  const char *end = p + strlen(p);
  state->cmdp = end;
  if (end == p) {
    ret_parsed->error.message = (char *) e_argreq;
    ret_parsed->error.position = p;
    return NOTDONE;
  }
  ret_parsed->node->args[ARG_HELPG_LANG].arg.str =
      get_help_lang(p, &end);
  ret_parsed->node->args[ARG_HELPG_REG].arg.reg =
      regex_alloc(p, (size_t) (end - p));
  return OK;
}

static CMD_P_DEF(parse_helptags)
{
  if (strncmp(state->cmdp, "++t", 3) == 0 && ascii_iswhite(state->cmdp[3])) {
    state->cmdp = skipwhite(state->cmdp + 3);
    ret_parsed->node->args[ARG_HT_MAIN].arg.flags = 1;
  }
  if (*state->cmdp == NUL) {
    ret_parsed->error.message = (char *) e_argreq;
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
  return parse_files(state, ret_parsed);
}

static CMD_P_DEF(parse_mkspell)
{
  if (STRNCMP(state->cmdp, "-ascii", 6) == 0) {
    state->cmdp = skipwhite(state->cmdp + 6);
    ret_parsed->node->args[ARG_MKS_ASCII].arg.flags =
        (uint_least32_t) true;
  }
  if (*state->cmdp == NUL) {
    return OK;
  }
  return parse_files(state, ret_parsed);
}

static CMD_P_DEF(parse_language)
{
  const char *end = skiptowhite(state->cmdp);
  LocaleType type = VAL_LANG_ALL;
  if ((*end == NUL || ascii_iswhite(*end)) && end - state->cmdp >= 3) {
    if (STRNICMP(state->cmdp, "messages", end - state->cmdp) == 0) {
      type = VAL_LANG_MESSAGES;
      state->cmdp = skipwhite(end);
    } else if (STRNICMP(state->cmdp, "ctype", end - state->cmdp) == 0) {
      type = VAL_LANG_CTYPE;
      state->cmdp = skipwhite(end);
    } else if (STRNICMP(state->cmdp, "time", end - state->cmdp) == 0) {
      type = VAL_LANG_TIME;
      state->cmdp = skipwhite(end);
    }
  }
  ret_parsed->node->args[ARG_LANG_TYPE].arg.flags =
      (uint_least32_t) type;
  if (*state->cmdp != NUL) {
    const size_t len = strlen(state->cmdp);
    ret_parsed->node->args[ARG_LANG_LANG].arg.str =
        xmemdupz(state->cmdp, len);
    state->cmdp += len;
  }
  return OK;
}

static CMD_P_DEF(parse_write)
{
  if (*state->cmdp == '>' && ret_parsed->node->type != kCmdRead) {
    state->cmdp++;
    if (*state->cmdp != '>') {
      ret_parsed->error.message = N_("E494: Use w or w>>");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
    state->cmdp = skipwhite(state->cmdp + 1);
    ret_parsed->node->args[ARG_W_APPEND].arg.flags =
        (uint_least32_t) true;
  } else if (*state->cmdp == '!'
             && ret_parsed->node->type != kCmdUpdate) {
    state->cmdp++;
    const size_t len = strlen(state->cmdp);
    ret_parsed->node->args[ARG_W_SHELL].arg.str =
        xmemdupz(state->cmdp, len);
    state->cmdp += len;
    return OK;
  }
  return parse_files(state, ret_parsed);
}

static CMD_P_DEF(parse_loadview)
{
  ret_parsed->node->args[ARG_LOADVIEW_NR].arg.ch = *state->cmdp;
  if (*state->cmdp != NUL) {
    state->cmdp += strlen(state->cmdp);
  }
  return OK;
}

static CMD_P_DEF(parse_loadkeymap)
{
  if (state->o.flags & FLAG_POC_EXMODE) {
    ret_parsed->error.message =
        N_("E105: Using :loadkeymap not in a sourced file");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }

  garray_T *const ga_lhss =
      &ret_parsed->node->args[ARG_LKMAP_LHSS].arg.ga_strs;
  garray_T *const ga_rhss =
      &ret_parsed->node->args[ARG_LKMAP_RHSS].arg.ga_strs;
  garray_T *const ga_coms =
      &ret_parsed->node->args[ARG_LKMAP_COMS].arg.ga_strs;

  ga_init(ga_lhss, (int) sizeof(char *), 16);
  ga_init(ga_rhss, (int) sizeof(char *), 16);
  ga_init(ga_coms, (int) sizeof(char *), 16);

  const char *error_message = NULL;
  const char *error_position = NULL;
  freeline(state);
  while (nextline(state, ':', 0)) {
    if (*state->cmdp == NUL) {
      freeline(state);
      GA_APPEND(char *, ga_lhss, NULL);
      GA_APPEND(char *, ga_rhss, NULL);
      GA_APPEND(char *, ga_coms, NULL);
    } else if (*state->cmdp == '"') {
      GA_APPEND(char *, ga_lhss, NULL);
      GA_APPEND(char *, ga_rhss, NULL);
      GA_APPEND(char *, ga_coms, (char *) state->s);
      state->s = state->cmdp = NULL;
    } else {
      const char *const lhs_start = state->cmdp;
      const char *const lhs_end = skiptowhite(lhs_start);
      const char *const rhs_start = skipwhite(lhs_end);
      const char *const rhs_end = skiptowhite(rhs_start);
      const char *const com_start = skipwhite(rhs_end);
      if (lhs_start == lhs_end) {
        error_message = N_("E791: Empty LHS");
        error_position = lhs_start;
        goto parse_loadkeymap_error;
      }
      if (rhs_start == rhs_end) {
        error_message = N_("E791: Empty RHS");
        error_position = rhs_start;
        goto parse_loadkeymap_error;
      }
      GA_APPEND(char *, ga_lhss, xmemdupz(lhs_start,
                                          (size_t) (lhs_end - lhs_start)));
      GA_APPEND(char *, ga_rhss, xmemdupz(rhs_start,
                                          (size_t) (rhs_end - rhs_start)));
      GA_APPEND(char *, ga_coms, *com_start == NUL ? NULL : xstrdup(com_start));
      freeline(state);
    }
  }
  return OK;
parse_loadkeymap_error:
  ret_parsed->error = (CommandParserError) {
    .message = error_message,
    .position = error_position,
  };
  clear_cmd(ret_parsed->node);
  if (create_error_node(state, ret_parsed) == FAIL) {
    return FAIL;
  }
  freeline(state);
  return NOTDONE;
}

static const char *menu_skip_part(const char *p)
{
  while (*p && *p != '.' && !ascii_iswhite(*p)) {
    if ((*p == '\\' || *p == Ctrl_V) && p[1]) {
      p++;
    }
    p++;
  }
  return p;
}

static CMD_P_DEF(parse_menutranslate)
{
  if (strncmp(state->cmdp, "clear", 5) == 0
      && ENDS_EXCMD(*skipwhite(state->cmdp + 5))) {
    state->cmdp = skipwhite(state->cmdp + 5);
  } else {
    const char *const from = state->cmdp;
    const char *const from_end = menu_skip_part(from);
    const char *const to = skipwhite(from_end);
    const char *const to_end = menu_skip_part(to);
    if (to_end == to || *to_end == '.') {
      if (*to == '.' || *to_end == '.') {
        ret_parsed->error.message = N_("E474: Expected no submenus");
      } else if (from_end == from) {
        ret_parsed->error.message =
            N_("E474: Expected string that is to be translated");
      } else {
        ret_parsed->error.message = N_("E474: Expected translated string");
      }
      ret_parsed->error.position = to_end;
      return NOTDONE;
    }

    int pnmret;

    state->cmdp = from;
    if ((pnmret = parse_menu_name(
                state, ret_parsed, kMenuDefaults,
                &ret_parsed->node->args[ARG_MT_FROM_ITEM].arg.menu_item,
                &ret_parsed->node->args[ARG_MT_FROM_TEXT].arg.str))
        != OK) {
      return pnmret;
    }
    if (state->cmdp != from_end) {
      ret_parsed->error.message =
          N_("E474: Unexpected end of string to be translated");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
    if (ret_parsed->node->args[ARG_MT_FROM_ITEM].arg.menu_item->subitem
        != NULL) {
      ret_parsed->error.message = N_("E474: Expected no submenus");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }

    state->cmdp = to;
    if ((pnmret = parse_menu_name(
                state, ret_parsed, kMenuDefaults,
                &ret_parsed->node->args[ARG_MT_TO_ITEM].arg.menu_item,
                &ret_parsed->node->args[ARG_MT_TO_TEXT].arg.str))
        != OK) {
      return pnmret;
    }
    if (state->cmdp != to_end) {
      ret_parsed->error.message =
          N_("E474: Unexpected end of translated string");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
    if (ret_parsed->node->args[ARG_MT_TO_ITEM].arg.menu_item->subitem
        != NULL) {
      ret_parsed->error.message = N_("E474: Expected no submenus");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }

    state->cmdp = to_end;
  }
  return OK;
}

static const char *skiptospace(const char *p)
{
  while (*p != ' ' && *p) {
    p++;
  }
  return p;
}

static const char *skipspaces(const char *p)
{
  while (*p == ' ') {
    p++;
  }
  return p;
}

static CMD_SUBP_DEF(parse_cscope_add)
{
  const char *arg_start;
  char *fname = NULL;
  char *ppath = NULL;
  char *flags = NULL;
  if (!*state->cmdp) {
    ret_parsed->error.message =
        N_("E560: Usage: cs[cope] add file|dir [pre-path] [flags]");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
  arg_start = state->cmdp;
  state->cmdp = skiptospace(state->cmdp);
  fname = xmemdupz(arg_start, (size_t) (state->cmdp - arg_start));
  arg_start = state->cmdp = skipspaces(state->cmdp);
  if (*state->cmdp) {
    state->cmdp = skiptospace(state->cmdp);
    ppath = xmemdupz(arg_start, (size_t) (state->cmdp - arg_start));
    state->cmdp = skipspaces(state->cmdp);
    if (*state->cmdp) {
      const size_t flags_len = strlen(state->cmdp);
      flags = xmemdupz(state->cmdp, flags_len);
      state->cmdp += flags_len;
    }
  }
  subargsargs[CSCOPE_ARG_ADD_PATH].arg.str = fname;
  subargsargs[CSCOPE_ARG_ADD_PRE_PATH].arg.str = ppath;
  subargsargs[CSCOPE_ARG_ADD_FLAGS].arg.str = flags;
  return OK;
}

static CMD_SUBP_DEF(parse_cscope_find)
{
  const char *const opt_start = state->cmdp;
  const char *const opt_end = skiptospace(opt_start);
  const char *const arg_start = (*opt_end && *opt_end == ' '
                                 ? opt_end + 1
                                 : opt_end);
  if (opt_start == opt_end || !*arg_start) {
    ret_parsed->error.message =
        N_("E560: Usage: cs[cope] find c|d|e|f|g|i|s|t name");
    ret_parsed->error.position = (opt_start == opt_end? opt_start: arg_start);
    return NOTDONE;
  }
  // Note: normally (opt_end - opt_start) == 1, but this is not ever checked.
  CscopeSearchType search_type;
  switch (*opt_start) {
    case '0':
    case 's': {
      search_type = kCscopeFindSymbol;
      break;
    }
    case '1':
    case 'g': {
      search_type = kCscopeFindDefinition;
      break;
    }
    case '2':
    case 'd': {
      search_type = kCscopeFindCallees;
      break;
    }
    case '3':
    case 'c': {
      search_type = kCscopeFindCallers;
      break;
    }
    case '4':
    case 't': {
      search_type = kCscopeFindText;
      break;
    }
    case '6':
    case 'e': {
      search_type = kCscopeFindEgrep;
      break;
    }
    case '7':
    case 'f': {
      search_type = kCscopeFindFile;
      break;
    }
    case '8':
    case 'i': {
      search_type = kCscopeFindIncluders;
      break;
    }
    default: {
      ret_parsed->error.message = N_("E561: unknown cscope search type");
      ret_parsed->error.position = opt_start;
      return NOTDONE;
    }
  }
  size_t arg_len = STRLEN(arg_start);
  subargsargs[CSCOPE_ARG_FIND_TYPE].arg.flags = (uint_least32_t) search_type;
  subargsargs[CSCOPE_ARG_FIND_NAME].arg.str = xmemdupz(arg_start, arg_len);
  state->cmdp = arg_start + arg_len;
  return OK;
}

static const SubCommandDefinition cscope_commands[] = {
  { SS("add"), kCscopeAdd, SUBARGS(CSCOPE_ARGS_ADD), &parse_cscope_add },
  { SS("find"), kCscopeFind, SUBARGS(CSCOPE_ARGS_FIND), &parse_cscope_find },
  { SS("help"), kCscopeHelp, EMPTY_SUBARGS, NULL },
  { SS("kill"), kCscopeKill, EMPTY_SUBARGS, NULL },
  { SS("reset"), kCscopeReset, EMPTY_SUBARGS, NULL },
  { SS("show"), kCscopeShow, EMPTY_SUBARGS, NULL },
  { NULL, 0, 0, 0, NULL, NULL },
};

static CMD_P_DEF(parse_cscope)
{
  const char *const s = state->cmdp;
  // Original function uses `strtok`. I do not think this is wise idea.
  const char *const cmd_end = skiptospace(s);
  const size_t cmd_len = (size_t) (cmd_end - s);
  const SubCommandDefinition *cur_cmd = &cscope_commands[0];
  CommandSubArgs *subargs = &ret_parsed->node->args[ARG_SUBCMD].arg.args;
  subargs->type = kCscopeHelp;
  if (cmd_len > 0) {
    while (cur_cmd->name != NULL) {
      if (STRNCMP(s, cur_cmd->name, cmd_len) == 0) {
        state->cmdp += cmd_len;
        state->cmdp = skipspaces(state->cmdp);
        subargs->type = cur_cmd->type;
        subargs->num_args = cur_cmd->num_args;
        subargs->types = cur_cmd->types;
        CommandArg *subargsargs = NULL;
        if (cur_cmd->num_args) {
          subargsargs = xcalloc(subargs->num_args, sizeof(CommandArg));
          subargs->args = subargsargs;
        }
        if (cur_cmd->parse) {
          int pret;
          if ((pret = cur_cmd->parse(state, ret_parsed, subargsargs)) != OK) {
            return pret;
          }
        }
        break;
      }
      cur_cmd++;
    }
  }
  if (subargs->type == kCscopeHelp) {
    state->cmdp += strlen(state->cmdp);
  }
  return OK;
}

static CMD_P_DEF(parse_sniff)
{
  // Sets:
  // Case                CMD       SYMBOL    DEF       MSG
  // List commands       NULL      NULL      NULL      NULL
  // Define new command  non-NULL  NULL      non-NULL  non-NULL
  // Run some command    non-NULL  non-NULL  NULL      NULL
  if (ENDS_EXCMD(*state->cmdp)) {
    return OK;
  }
  const char *const cmd_end = skiptowhite(state->cmdp);
  char *const cmd = xmemdupz(state->cmdp, (size_t) (cmd_end - state->cmdp));
  ret_parsed->node->args[ARG_SNIFF_CMD].arg.str = cmd;
  const char *symbol = skipwhite(cmd_end);
  if (ENDS_EXCMD(*symbol)) {
    symbol = NULL;
  }
  if (STRCMP(cmd, "addcmd") == 0) {
    const char *const symbol_end = skiptowhite(symbol);
    xfree(ret_parsed->node->args[ARG_SNIFF_CMD].arg.str);
    ret_parsed->node->args[ARG_SNIFF_CMD].arg.str =
        xmemdupz(symbol, (size_t) (symbol_end - symbol));
    const char *const def = skipwhite(symbol_end);
    const char *const def_end = skiptowhite(def);
    ret_parsed->node->args[ARG_SNIFF_DEF].arg.str =
        xmemdupz(def, (size_t) (def_end - def));
    const char *const msg = skipwhite(def_end);
    if (ENDS_EXCMD(*msg)) {
      ret_parsed->node->args[ARG_SNIFF_MSG].arg.str =
          xstrdup(ret_parsed->node->args[ARG_SNIFF_CMD].arg.str);
      state->cmdp = msg;
    } else {
      const char *const msg_end = skiptowhite_esc(msg);
      ret_parsed->node->args[ARG_SNIFF_MSG].arg.str =
          xmemdupz(msg, (size_t) (msg_end - msg));
      state->cmdp = msg_end;
    }
  } else {
    const size_t len = STRLEN(symbol);
    ret_parsed->node->args[ARG_SNIFF_SYMBOL].arg.str =
        xmemdupz(symbol, len);
    state->cmdp = symbol + len;
  }
  return OK;
}

const HighlightAttrDef hl_attr_table[] = {
  { SS("bold"), FLAG_HI_TERM_BOLD },
  { SS("underline"), FLAG_HI_TERM_UNDERLINE },
  { SS("undercurl"), FLAG_HI_TERM_UNDERCURL },
  { SS("inverse"), FLAG_HI_TERM_REVERSE },
  { SS("reverse"), FLAG_HI_TERM_REVERSE },
  { SS("italic"), FLAG_HI_TERM_ITALIC },
  { SS("standout"), FLAG_HI_TERM_STANDOUT },
  { SS("none"), FLAG_HI_TERM_NONE },
  { NULL, 0, 0 },
};

static CMD_P_DEF(parse_highlight)
{
  uint_least32_t flags = 0;
  if (ENDS_EXCMD(*state->cmdp)) {
    return OK;
  }
  const char *name_start = state->cmdp;
  const char *name_end = skiptowhite(name_start);
  state->cmdp = skipwhite(name_end);

  if (strncmp(name_start, "default", (size_t) (name_end - name_start)) == 0) {
    flags |= FLAG_HI_DEFAULT;
    name_start = state->cmdp;
    name_end = skiptowhite(name_start);
    state->cmdp = skipwhite(name_end);
  }

  if (strncmp(name_start, "clear", (size_t) (name_end - name_start)) == 0) {
    flags |= FLAG_HI_CLEAR;
  } else if (strncmp(name_start, "link", (size_t) (name_end - name_start))
             == 0) {
    flags |= FLAG_HI_LINK;
  }

  if (!(flags & (FLAG_HI_CLEAR|FLAG_HI_LINK)) && ENDS_EXCMD(*state->cmdp)) {
    ret_parsed->node->args[ARG_HI_GROUP].arg.str =
        xmemdupz(name_start, (size_t) (name_end - name_start));
    goto parse_highlight_end;
  }

  if (flags & FLAG_HI_LINK) {
    const char *const from_start = state->cmdp;
    const char *const from_end = skiptowhite(from_start);
    const char *const to_start = skipwhite(from_end);
    const char *const to_end = skiptowhite(to_start);

    if (ENDS_EXCMD(*from_start) || ENDS_EXCMD(*to_start)) {
      ret_parsed->error.message =
          N_("E412: Not enough arguments to :highlight link");
      ret_parsed->error.position = ((ENDS_EXCMD(*from_start))
                                    ? from_start
                                    : to_start);
      return NOTDONE;
    }

    state->cmdp = skipwhite(to_end);
    if (!ENDS_EXCMD(*state->cmdp)) {
      ret_parsed->error.message =
          N_("E413: Too many arguments to :highlight link");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }

    ret_parsed->node->args[ARG_HI_GROUP].arg.str =
        xmemdupz(from_start, (size_t) (from_end - from_start));
    ret_parsed->node->args[ARG_HI_TGT_GROUP].arg.str =
        xmemdupz(to_start, (size_t) (to_end - to_start));
    goto parse_highlight_end;
  }

  if (flags & FLAG_HI_CLEAR) {
    if (ENDS_EXCMD(*state->cmdp)) {
      goto parse_highlight_end;
    }
    name_start = state->cmdp;
    name_end = skiptowhite(name_start);
    state->cmdp = skipwhite(name_end);
  }

  ret_parsed->node->args[ARG_HI_GROUP].arg.str =
      xmemdupz(name_start, (size_t) (name_end - name_start));

  if (!(flags & FLAG_HI_CLEAR)) {
    while (!ENDS_EXCMD(*state->cmdp)) {
      const char *const key_start = state->cmdp;
      if (*key_start == '=') {
        ret_parsed->error.message = N_("E415: Unexpected equal sign");
        ret_parsed->error.position = key_start;
        return NOTDONE;
      }

      // Isolate the key ("c?term|gui", "(term|gui)(fg|bg)")
      while (*state->cmdp && !ascii_iswhite(*state->cmdp)
             && *state->cmdp != '=') {
        state->cmdp++;
      }
      const char *const key_end = state->cmdp;

      if (*state->cmdp != '=') {
        ret_parsed->error.message = N_("E416: Missing equal sign");
        ret_parsed->error.position = state->cmdp;
        return NOTDONE;
      }
      state->cmdp++;

      // Isolate the argument
      state->cmdp = skipwhite(state->cmdp);
      const char *arg_start = state->cmdp;
      if (*state->cmdp == '\'') {
        arg_start++;
        state->cmdp = strchr(state->cmdp + 1, '\'');
        if (state->cmdp == NULL) {
          ret_parsed->error.message = N_("E475: Missing closing quote");
          ret_parsed->error.position = arg_start - 1;
          return NOTDONE;
        }
      } else {
        state->cmdp = skiptowhite(state->cmdp);
      }
      const char *const arg_end = state->cmdp;
      const size_t arg_len = (size_t) (arg_end - arg_start);

      if (!arg_len) {
        ret_parsed->error.message = N_("E417: Missing argument");
        ret_parsed->error.position = arg_start;
        return NOTDONE;
      }

      if (*state->cmdp == '\'') {
        state->cmdp++;
      }

      const size_t key_len = (size_t) (key_end - key_start);
      int prop_idx = -1;
      switch (key_len) {
        case 3: {
          if (STRNICMP(key_start, "gui", 3) == 0) {
            prop_idx = ARG_HI_GUI;
          } else {
            goto parse_highlight_unknown_property;
          }
          break;
        }
        case 4: {
          if (STRNICMP(key_start, "term", 4) == 0) {
            prop_idx = ARG_HI_TERM;
          } else if (STRNICMP(key_start, "font", 4) == 0) {
            prop_idx = ARG_HI_FONT;
          } else if (STRNICMP(key_start, "stop", 4) == 0) {
            prop_idx = ARG_HI_STOP;
          } else {
            goto parse_highlight_unknown_property;
          }
          break;
        }
        case 5: {
          if (STRNICMP(key_start, "cterm", 5) == 0) {
            prop_idx = ARG_HI_CTERM;
          } else if (STRNICMP(key_start, "guifg", 5) == 0) {
            prop_idx = ARG_HI_GUIFG;
          } else if (STRNICMP(key_start, "guibg", 5) == 0) {
            prop_idx = ARG_HI_GUIBG;
          } else if (STRNICMP(key_start, "guisp", 5) == 0) {
            prop_idx = ARG_HI_GUISP;
          } else if (STRNICMP(key_start, "start", 5) == 0) {
            prop_idx = ARG_HI_START;
          } else {
            goto parse_highlight_unknown_property;
          }
          break;
        }
        case 7: {
          if (STRNICMP(key_start, "ctermfg", 7) == 0) {
            prop_idx = ARG_HI_CTERMFG;
          } else if (STRNICMP(key_start, "ctermbg", 7) == 0) {
            prop_idx = ARG_HI_CTERMBG;
          } else {
            goto parse_highlight_unknown_property;
          }
          break;
        }
        default: {
          goto parse_highlight_unknown_property;
        }
      }
      if (prop_idx == ARG_HI_GUI
          || prop_idx == ARG_HI_TERM
          || prop_idx == ARG_HI_CTERM) {
        uint_least32_t attr_flags = 0;
        const char *ap = arg_start;
        while (ap < arg_end) {
          const HighlightAttrDef *cur_hl_attr = &hl_attr_table[0];
          for (cur_hl_attr = &hl_attr_table[0];
               cur_hl_attr->hl_attr_name != NULL;
               cur_hl_attr++) {
            if (STRNICMP(ap, cur_hl_attr->hl_attr_name,
                         cur_hl_attr->hl_attr_name_len) == 0) {
              attr_flags |= cur_hl_attr->hl_attr_flag;
              ap += cur_hl_attr->hl_attr_name_len;
              break;
            }
          }
          if (cur_hl_attr->hl_attr_name == NULL) {
            ret_parsed->error.message = N_("E418: Illegal attribute name");
            ret_parsed->error.position = ap;
            return NOTDONE;
          }
          if (*ap == ',') {
            ap++;
          }
        }
        ret_parsed->node->args[prop_idx].arg.flags = attr_flags;
      } else if (prop_idx == ARG_HI_FONT) {
        ret_parsed->node->args[prop_idx].arg.str =
            xmemdupz(arg_start, arg_len);
      } else if (prop_idx == ARG_HI_CTERMFG || prop_idx == ARG_HI_CTERMBG
                 || prop_idx == ARG_HI_GUIFG || prop_idx == ARG_HI_GUIBG
                 || prop_idx == ARG_HI_GUISP) {
        if (ascii_isdigit(*arg_start)
            && (prop_idx == ARG_HI_CTERMFG || prop_idx == ARG_HI_CTERMBG)) {
          ret_parsed->node->args[prop_idx].arg.color.type = kHiColorIdx;
          ret_parsed->node->args[prop_idx].arg.color.data.idx =
              (uint8_t) atoi(arg_start);
        } else if (*arg_start == '#' && arg_len == 7
                 && (prop_idx == ARG_HI_GUIFG
                     || prop_idx == ARG_HI_GUIBG
                     || prop_idx == ARG_HI_GUISP)
                 && ascii_isxdigit(arg_start[1])
                 && ascii_isxdigit(arg_start[2])
                 && ascii_isxdigit(arg_start[3])
                 && ascii_isxdigit(arg_start[4])
                 && ascii_isxdigit(arg_start[5])
                 && ascii_isxdigit(arg_start[6])) {
          ret_parsed->node->args[prop_idx].arg.color.type = kHiColorRGB;
          union {
            struct {
              unsigned rgb : 24;
            } rgb_1;
            struct {
              unsigned blue : 8;
              unsigned green : 8;
              unsigned red : 8;
            } rgb_3;
          } current_color;
          // & 0xFFFFFF is not needed: it is there to silence GCC warning.
          current_color.rgb_1.rgb = (unsigned) (
              strtoul(arg_start + 1, NULL, 16) & 0xFFFFFF);
          ret_parsed->node->args[prop_idx].arg.color.data.rgb.red =
              current_color.rgb_3.red;
          ret_parsed->node->args[prop_idx].arg.color.data.rgb.green
              = current_color.rgb_3.green;
          ret_parsed->node->args[prop_idx].arg.color.data.rgb.blue
              = current_color.rgb_3.blue;
        } else if (arg_len == 2 && STRNICMP(arg_start, "fg", 2) == 0) {
          ret_parsed->node->args[prop_idx].arg.color.type = kHiColorFg;
        } else if (arg_len == 2 && STRNICMP(arg_start, "bg", 2) == 0) {
          ret_parsed->node->args[prop_idx].arg.color.type = kHiColorBg;
        } else if (arg_len == 4 && STRNICMP(arg_start, "none", 4) == 0) {
          ret_parsed->node->args[prop_idx].arg.color.type = kHiColorNone;
        } else {
          ret_parsed->node->args[prop_idx].arg.color.type = kHiColorName;
          ret_parsed->node->args[prop_idx].arg.color.data.name =
              xmemdupz(arg_start, arg_len);
        }
      } else if (prop_idx == ARG_HI_START || prop_idx == ARG_HI_STOP) {
        // FIXME Do better parsing.
        ret_parsed->node->args[prop_idx].arg.str =
            xmemdupz(arg_start, arg_len);
      } else {
parse_highlight_unknown_property:
        ret_parsed->error.message = N_("E423: Unknown property name");
        ret_parsed->error.position = key_start;
        return NOTDONE;
      }
      state->cmdp = skipwhite(state->cmdp);
    }
  } else {
    state->cmdp += strlen(state->cmdp);
  }

parse_highlight_end:
  ret_parsed->node->args[ARG_HI_FLAGS].arg.flags = flags;
  return OK;
}

static int parse_sign_undeflist(CMD_SUBP_ARGS, const SignArgType type)
{
  if (*state->cmdp == NUL) {
    if (type == kSignList) {
      // `:sign list` without arguments
      return OK;
    } else {
      ret_parsed->error.message = N_("E156: Missing sign name");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
  } else {
    const char *name_start = state->cmdp;
    state->cmdp = skiptowhite(state->cmdp);
    // If sign name is a number then skip leading zeroes.
    while (name_start < state->cmdp - 1 && *name_start == '0') {
      name_start++;
    }
    STATIC_ASSERT(SIGN_ARG_DEFINE_NAME == SIGN_ARG_UNDEFINE_NAME,
                  "Name indexes do not match");
    STATIC_ASSERT(SIGN_ARG_DEFINE_NAME == SIGN_ARG_LIST_NAME,
                  "Name indexes do not match");
    subargsargs[SIGN_ARG_DEFINE_NAME].arg.str =
        xmemdupz(name_start, (size_t) (state->cmdp - name_start));
    if (type != kSignDefine) {
      state->cmdp += strlen(state->cmdp);
      goto parse_sign_undeflist_end;
    }
    for (;;) {
      state->cmdp = skipwhite(state->cmdp);
      if (*state->cmdp == NUL) {
        break;
      }
      const char *const prop_start = state->cmdp;
      state->cmdp = skiptowhite_esc(state->cmdp);
      if (strncmp(prop_start, "icon=", 5) == 0) {
        const char *const val_start = prop_start + 5;
        char *icon_file = xmemdupz(val_start,
                                   (size_t) (state->cmdp - val_start));
        backslash_halve(icon_file);
        subargsargs[SIGN_ARG_DEFINE_ICON].arg.str = icon_file;
      } else if (STRNCMP(prop_start, "text=", 5) == 0) {
        const char *const text_start = prop_start + 5;
        size_t cells = 0;
        const char *s;
        if (has_mbyte) {
          for (s = text_start; s < state->cmdp; s += (mb_ptr2len(s))) {
            if (!vim_isprintc(mb_ptr2char(s))) {
              ret_parsed->error.message =
                  N_("E239: Non-printable character in sign text");
              ret_parsed->error.position = s;
              return NOTDONE;
            }
            cells += mb_ptr2cells(s);
          }
        } else {
          for (s = text_start; s < state->cmdp; s++) {
            if (!vim_isprintc(*s)) {
              ret_parsed->error.message =
                  N_("E239: Non-printable character in sign text");
              ret_parsed->error.position = s;
              return NOTDONE;
            }
          }
          cells = (size_t) (s - text_start);
        }
        if (s != state->cmdp) {
          ret_parsed->error.message =
              N_("E239: Failed to process complete sign text");
          ret_parsed->error.position = s;
          return NOTDONE;
        } else if (cells != 2) {
          ret_parsed->error.message = (cells > 2
                                       ? N_("E239: Sign text is too wide")
                                       : N_("E239: Sign text is too narrow"));
          ret_parsed->error.position = text_start;
          return NOTDONE;
        }
      } else if (STRNCMP(prop_start, "linehl=", 7) == 0) {
        subargsargs[SIGN_ARG_DEFINE_LINEHL].arg.str =
            xmemdupz(prop_start + 7, (size_t) ((state->cmdp - prop_start) - 7));
      } else if (STRNCMP(prop_start, "texthl=", 7) == 0) {
        subargsargs[SIGN_ARG_DEFINE_TEXTHL].arg.str =
            xmemdupz(prop_start + 7, (size_t) ((state->cmdp - prop_start) - 7));
      } else {
        ret_parsed->error.message = N_("E475: Unknown sign property");
        ret_parsed->error.position = prop_start;
        return NOTDONE;
      }
    }
  }
parse_sign_undeflist_end:
  return OK;
}

static CMD_SUBP_DEF(parse_sign_define)
{
  return parse_sign_undeflist(state, ret_parsed, subargsargs, kSignDefine);
}

static CMD_SUBP_DEF(parse_sign_undefine)
{
  return parse_sign_undeflist(state, ret_parsed, subargsargs, kSignUndefine);
}

static CMD_SUBP_DEF(parse_sign_list)
{
  return parse_sign_undeflist(state, ret_parsed, subargsargs, kSignList);
}

static int parse_sign_unplacejump(CMD_SUBP_ARGS, const SignArgType type)
{
  if (*state->cmdp == NUL) {
    if (type == kSignJump) {
      ret_parsed->error.message = (const char *) e_argreq;
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    } else {
      return OK;
    }
  }
  if (type == kSignUnplace && *state->cmdp == '*' && state->cmdp[1] == NUL) {
    subargsargs[SIGN_ARG_UNPLACE_ID].arg.number = SIGN_ID_ALL;
    return OK;
  }
  int id = SIGN_ID_MISSING;
  if (ascii_isdigit(*state->cmdp)) {
    const char *const id_start = state->cmdp;
    id = getdigits_int(&state->cmdp);
    if (!ascii_iswhite(*state->cmdp) && *state->cmdp != NUL) {
      id = SIGN_ID_MISSING;
      state->cmdp = id_start;
    } else if (id == 0) {
      ret_parsed->error.message = N_("E474: Cannot use zero as sign id");
      ret_parsed->error.position = id_start;
      return NOTDONE;
    } else  {
      state->cmdp = skipwhite(state->cmdp);
      if (type == kSignUnplace && *state->cmdp == NUL) {
        subargsargs[SIGN_ARG_UNPLACE_ID].arg.number = id;
        goto parse_sign_unplacejump_end;
      }
    }
  }
  int lnum = 0;
  const char *sign_name_start = NULL;
  const char *sign_name_end = NULL;
  const char *file_start = NULL;
  const char *file_end = NULL;
  const char *lnum_start = NULL;
  int bufnr = 0;
  while (*state->cmdp) {
    if (strncmp(state->cmdp, "line=", 5) == 0) {
      state->cmdp += 5;
      lnum_start = state->cmdp;
      lnum = atoi(state->cmdp);
      if (lnum <= 0) {
        ret_parsed->error.message =
            N_("E885: Can only use positive line numbers");
        ret_parsed->error.position = state->cmdp;
        return NOTDONE;
      }
      state->cmdp = skiptowhite(state->cmdp);
    } else if (*state->cmdp == '*' && type == kSignUnplace) {
      if (id != SIGN_ID_MISSING) {
        ret_parsed->error.message =
            N_("E474: Cannot use `*' when identifier was already given");
        ret_parsed->error.position = state->cmdp;
        return NOTDONE;
      }
      id = SIGN_ID_ALL;
      state->cmdp = skiptowhite(state->cmdp + 1);
    } else if (strncmp(state->cmdp, "name=", 5) == 0) {
      state->cmdp += 5;
      sign_name_start = state->cmdp;
      sign_name_end = state->cmdp = skiptowhite(state->cmdp);
      while (sign_name_start[0] == '0' && sign_name_start[1] != NUL) {
        sign_name_start++;
      }
    } else if (strncmp(state->cmdp, "file=", 5) == 0) {
      state->cmdp += 5;
      file_start = state->cmdp;
      state->cmdp += strlen(state->cmdp);
      file_end = state->cmdp;
      break;
    } else if (strncmp(state->cmdp, "buffer=", 7) == 0) {
      state->cmdp += 7;
      const char *const bufnr_start = state->cmdp;
      bufnr = getdigits_int(&state->cmdp);
      if (bufnr <= 0) {
        ret_parsed->error.message =
            N_("E158: Buffer number can only be positive");
        ret_parsed->error.position = bufnr_start;
        return NOTDONE;
      }
      state->cmdp = skipwhite(state->cmdp);
      if (*state->cmdp != NUL) {
        ret_parsed->error.message =
            N_("E488: buffer= argument must be the last one");
        ret_parsed->error.position = state->cmdp;
        return NOTDONE;
      }
      break;
    } else {
      assert(*state->cmdp != NUL);
      ret_parsed->error.message = N_("E474: Unknown property");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
    state->cmdp = skipwhite(state->cmdp);
  }
  if (bufnr == 0 && file_start == NULL) {
    ret_parsed->error.message =
        N_("E474: Must provide either buffer= or file= as the last argument");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
  assert(id != 0);
  if (id < 0 && !(type == kSignUnplace && id == SIGN_ID_ALL)) {
    if (lnum_start != NULL || sign_name_start != NULL) {
      ret_parsed->error.message =
          N_("E474: Cannot use line= and name= without a sign id");
      ret_parsed->error.position =
          (lnum_start != NULL ? lnum_start : sign_name_start);
      return NOTDONE;
    }
  } else if (type == kSignJump) {
    if (lnum_start != NULL || sign_name_start != NULL) {
      ret_parsed->error.message =
          N_("E474: Cannot use line= and name= with :sign jump");
      ret_parsed->error.position =
          (lnum_start != NULL ? lnum_start : sign_name_start);
      return NOTDONE;
    }
  } else if (type == kSignUnplace) {
    if (lnum_start != NULL || sign_name_start != NULL) {
      ret_parsed->error.message =
          N_("E474: Cannot use line= and name= with :sign unplace");
      ret_parsed->error.position =
          (lnum_start != NULL ? lnum_start : sign_name_start);
      return NOTDONE;
    }
  } else if (type == kSignPlace) {
    if (sign_name_start == NULL) {
      ret_parsed->error.message = N_("E474: Missing sign name");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
  } else {
    assert(false);
  }
  STATIC_ASSERT(SIGN_ARG_UNPLACE_ID == SIGN_ARG_PLACE_ID,
                "Id indexes do not match");
  STATIC_ASSERT(SIGN_ARG_UNPLACE_ID == SIGN_ARG_JUMP_ID,
                "Id indexes do not match");
  STATIC_ASSERT(SIGN_ARG_UNPLACE_FILE == SIGN_ARG_PLACE_FILE,
                "File indexes do not match");
  STATIC_ASSERT(SIGN_ARG_UNPLACE_FILE == SIGN_ARG_JUMP_FILE,
                "File indexes do not match");
  STATIC_ASSERT(SIGN_ARG_UNPLACE_BUFFER == SIGN_ARG_PLACE_BUFFER,
                "Buffer indexes do not match");
  STATIC_ASSERT(SIGN_ARG_UNPLACE_BUFFER == SIGN_ARG_JUMP_BUFFER,
                "Buffer indexes do not match");
  subargsargs[SIGN_ARG_PLACE_ID].arg.number = id;
  subargsargs[SIGN_ARG_PLACE_BUFFER].arg.unumber = (unsigned) bufnr;
  if (file_start != NULL) {
    subargsargs[SIGN_ARG_PLACE_FILE].arg.str =
        xmemdupz(file_start, (size_t) (file_end - file_start));
  }
  if (lnum_start != NULL) {
    assert(type == kSignPlace);
    subargsargs[SIGN_ARG_PLACE_LINE].arg.unumber = (unsigned) lnum;
  }
  if (sign_name_start != NULL) {
    assert(type == kSignPlace);
    subargsargs[SIGN_ARG_PLACE_NAME].arg.str =
        xmemdupz(sign_name_start, (size_t) (sign_name_end - sign_name_start));
  }
parse_sign_unplacejump_end:
  return OK;
}

static CMD_SUBP_DEF(parse_sign_place)
{
  return parse_sign_unplacejump(state, ret_parsed, subargsargs, kSignPlace);
}

static CMD_SUBP_DEF(parse_sign_unplace)
{
  return parse_sign_unplacejump(state, ret_parsed, subargsargs, kSignUnplace);
}

static CMD_SUBP_DEF(parse_sign_jump)
{
  return parse_sign_unplacejump(state, ret_parsed, subargsargs, kSignJump);
}

static const SubCommandDefinition sign_commands[] = {
  { SS("define"), kSignDefine, SUBARGS(SIGN_ARGS_DEFINE), &parse_sign_define },
  { SS("undefine"), kSignUndefine, SUBARGS(SIGN_ARGS_UNDEFINE),
    &parse_sign_undefine },
  { SS("list"), kSignList, SUBARGS(SIGN_ARGS_LIST), &parse_sign_list },
  { SS("place"), kSignPlace, SUBARGS(SIGN_ARGS_PLACE), &parse_sign_place },
  { SS("unplace"), kSignUnplace, SUBARGS(SIGN_ARGS_UNPLACE),
    &parse_sign_unplace },
  { SS("jump"), kSignJump, SUBARGS(SIGN_ARGS_JUMP), &parse_sign_jump },
  { NULL, 0, 0, 0, NULL, NULL },
};

static CMD_P_DEF(parse_sign)
{
  if (*state->cmdp == NUL) {
    ret_parsed->error.message = (const char *) e_argreq;
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
  const char *const s = state->cmdp;
  const char *const cmd_end = skiptowhite(s);
  const size_t cmd_len = (size_t) (cmd_end - s);
  const SubCommandDefinition *cur_cmd = &sign_commands[0];
  CommandSubArgs *subargs = &ret_parsed->node->args[ARG_SUBCMD].arg.args;
  if (cmd_len > 0) {
    while (cur_cmd->name != NULL) {
      if (cur_cmd->name_len == cmd_len
          && STRNCMP(s, cur_cmd->name, cmd_len) == 0) {
        state->cmdp += cmd_len;
        state->cmdp = skipwhite(state->cmdp);
        subargs->type = cur_cmd->type;
        subargs->num_args = cur_cmd->num_args;
        subargs->types = cur_cmd->types;
        CommandArg *subargsargs = NULL;
        if (cur_cmd->num_args) {
          subargsargs = xcalloc(subargs->num_args, sizeof(CommandArg));
          subargs->args = subargsargs;
        }
        if (cur_cmd->parse) {
          int pret;
          if ((pret = cur_cmd->parse(state, ret_parsed, subargsargs)) != OK) {
            return pret;
          }
        }
        break;
      }
      cur_cmd++;
    }
    if (cur_cmd->name == NULL) {
      ret_parsed->error.message = N_("E160: Unknown sign command");
      ret_parsed->error.position = s;
      return NOTDONE;
    }
  }
  return OK;
}

static CMD_SUBP_DEF(parse_syntax_case)
{
  const char *const s = state->cmdp;
  state->cmdp = skiptowhite(s);
  if (state->cmdp - s == 5 && STRNICMP(s, "match", 5) == 0) {
    subargsargs[SYN_ARG_CASE_FLAGS].arg.flags = (uint_least32_t) false;
  } else if (state->cmdp - s == 6 && STRNICMP(s, "ignore", 6) == 0) {
    subargsargs[SYN_ARG_CASE_FLAGS].arg.flags = (uint_least32_t) true;
  } else {
    ret_parsed->error.message = N_("E390: Expected match or ignore");
    ret_parsed->error.position = s;
    return NOTDONE;
  }
  state->cmdp = skipwhite(state->cmdp);
  return OK;
}

/// Parse syntax groups list
///
/// @param[in,out]  state  Parser state.
/// @param[out]  ret_parsed  Location where error will be saved.
/// @param[out]  group  Address where parsing result will be saved.
/// @param[in]  allow_specials  Allow special values ALLBUT, ALL, TOP,
///                             CONTAINED.
///
/// @return OK if everything was parsed correctly, NOTDONE in case of error,
///         FAIL otherwise.
int parse_group_list(CMD_P_ARGS, SynGroupList **group,
                     const bool allow_specials)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  SynGroupList **next = group;
  while (*next != NULL) {
    next = &((*next)->next);
  }
  group = next;
  state->cmdp = skipwhite(state->cmdp);
  if (*state->cmdp != '=') {
    ret_parsed->error.message = N_("E405: Missing equal sign");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
  state->cmdp = skipwhite(state->cmdp + 1);
  if (ENDS_EXCMD(*state->cmdp)) {
    ret_parsed->error.message = N_("E406: Empty argument");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
  do {
    const char *const name_start = state->cmdp;
    for (; *state->cmdp && !ascii_iswhite(*state->cmdp) && *state->cmdp != ',';
         state->cmdp++) {
    }
    *next = xcalloc(1, sizeof(**next));
    const size_t name_len = (size_t) (state->cmdp - name_start);
    if ((name_len == 6 && STRNCMP(name_start, "ALLBUT", 6) == 0)
        || (name_len == 3 && STRNCMP(name_start, "ALL", 3) == 0)
        || (name_len == 3 && STRNCMP(name_start, "TOP", 3) == 0)
        || (name_len == 9 && STRNCMP(name_start, "CONTAINED", 9) == 0)) {
      if (!allow_specials) {
        ret_parsed->error.message =
            N_("E407: Special arguments ALL[BUT], TOP, CONTAINED "
               "are not allowed here");
        ret_parsed->error.position = name_start;
        return NOTDONE;
      }
      if (next != group) {
        ret_parsed->error.message =
            N_("E407: Special arguments ALL[BUT], TOP, CONTAINED "
               "are only allowed in the beginning of the list");
        ret_parsed->error.position = name_start;
        return NOTDONE;
      }
      switch (*name_start) {
        case 'A': {
          (*next)->type = kSynGroupAll;
          break;
        }
        case 'T': {
          (*next)->type = kSynGroupTop;
          break;
        }
        case 'C': {
          (*next)->type = kSynGroupContained;
          break;
        }
        default: {
          assert(false);
        }
      }
    } else if (*name_start == '@') {
      (*next)->type = kSynGroupCluster;
      (*next)->data.name = xmemdupz(name_start + 1, name_len - 1);
    } else if (strpbrk(name_start, "\\.*^$~[") == NULL
               || strpbrk(name_start, "\\.*^$~[") < state->cmdp) {
      (*next)->type = kSynGroupLiteral;
      (*next)->data.name = xmemdupz(name_start, name_len);
    } else {
      char *regstr = xmalloc(name_len + 3);
      *regstr = '^';
      memcpy(regstr + 1, name_start, name_len);
      regstr[name_len + 1] = '$';
      regstr[name_len + 2] = NUL;
      (*next)->type = kSynGroupRegex;
      (*next)->data.regex = regex_alloc(regstr, name_len + 2);
      xfree(regstr);
    }
    next = &((*next)->next);
    state->cmdp = skipwhite(state->cmdp);
    if (*state->cmdp != ',') {
      break;
    }
    state->cmdp = skipwhite(state->cmdp + 1);
  } while (!ENDS_EXCMD(*state->cmdp));
  return OK;
}

/// Get the start of the group name argument
///
/// @param[in]   p         Parsed string.
/// @param[out]  name_end  Location where name end is saved.
///
/// @return Pointer to the next argument or NULL if there is no next argument.
static const char *get_group_name(const char *p, const char **name_end)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  *name_end = skiptowhite(p);
  const char *const rest = skipwhite(*name_end);
  if (ENDS_EXCMD(*p) || *rest == NUL) {
    return NULL;
  }
  return rest;
}

static CMD_SUBP_DEF(parse_syntax_cluster)
{
  const char *const cluster_name_start = state->cmdp;
  const char *cluster_name_end = NULL;
  bool got_clstr = false;
  state->cmdp = get_group_name(state->cmdp, &cluster_name_end);
  if (state->cmdp != NULL) {
    subargsargs[SYN_ARG_CLUSTER_NAME].arg.str =
        xmemdupz(cluster_name_start,
                 (size_t) (cluster_name_end - cluster_name_start));
    int prop_idx = -1;
    for (;;) {
      if (STRNICMP(state->cmdp, "add", 3) == 0
          && (ascii_iswhite(state->cmdp[3]) || state->cmdp[3] == '=')) {
        state->cmdp += 3;
        prop_idx = SYN_ARG_CLUSTER_ADD;
      } else if (STRNICMP(state->cmdp, "remove", 6) == 0
                 && (ascii_iswhite(state->cmdp[6]) || state->cmdp[6] == '=')) {
        state->cmdp += 6;
        prop_idx = SYN_ARG_CLUSTER_REMOVE;
      } else if (STRNICMP(state->cmdp, "contains", 8) == 0
                 && (ascii_iswhite(state->cmdp[8]) || state->cmdp[8] == '=')) {
        state->cmdp += 8;
        prop_idx = SYN_ARG_CLUSTER_CONTAINS;
      } else {
        break;
      }

      int pglret = parse_group_list(state, ret_parsed,
                                    &subargsargs[prop_idx].arg.group, false);
      if (pglret != OK) {
        return pglret;
      }
      got_clstr = true;
    }
  } else {
    ret_parsed->error.message =
        N_("E475: Expected group name followed by an argument");
    ret_parsed->error.position = cluster_name_end;
    return NOTDONE;
  }
  if (!got_clstr) {
    ret_parsed->error.message = N_("E400: No cluster specified");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
  return OK;
}

static CMD_SUBP_DEF(parse_syntax_conceal)
{
  const char *const s = state->cmdp;
  const char *const p = skiptowhite(s);
  if (p - s == 2 && STRNICMP(s, "on", 2) == 0) {
    subargsargs[SYN_ARG_CONCEAL_FLAGS].arg.flags = (uint_least32_t) true;
  } else if (p - s == 3 && STRNICMP(s, "off", 3) == 0) {
    subargsargs[SYN_ARG_CONCEAL_FLAGS].arg.flags = (uint_least32_t) false;
  } else {
    ret_parsed->error.message = N_("E390: Expected on or off");
    ret_parsed->error.position = s;
    return NOTDONE;
  }
  state->cmdp = skipwhite(p);
  return OK;
}

static CMD_SUBP_DEF(parse_syntax_include)
{
  const char *cluster_name_end = NULL;
  if (*state->cmdp == '@') {
    state->cmdp++;
    const char *const fname_start =
        get_group_name(state->cmdp, &cluster_name_end);
    if (fname_start == NULL) {
      ret_parsed->error.message = N_("E397: Filename required");
      ret_parsed->error.position = cluster_name_end;
      return NOTDONE;
    }
    subargsargs[SYN_ARG_INCLUDE_CLUSTER].arg.str =
        xmemdupz(state->cmdp, (size_t) (cluster_name_end - state->cmdp));
    state->cmdp = fname_start;
  }
  int pret;
  if ((pret = get_glob_pattern(state, ret_parsed,
                               &subargsargs[SYN_ARG_INCLUDE_FILE].arg.pat,
                               false, false)) != OK) {
    return pret;
  }
  return OK;
}

static const SynOptDef synopttab[] = {
  SYN_FLAG_OPT("cCoOnNtTaAiInNeEdD",     MAIN,   CONTAINED),
  SYN_FLAG_OPT("oOnNeElLiInNeE",         MAIN,   ONELINE),
  SYN_FLAG_OPT("kKeEeEpPeEnNdD",         REGION, KEEPEND),
  SYN_FLAG_OPT("eExXtTeEnNdD",           MR,     EXTEND),
  SYN_FLAG_OPT("eExXcClLuUdDeEnNlL",     MR,     EXCLUDENL),
  SYN_FLAG_OPT("tTrRaAnNsSpPaArReEnNtT", MAIN,   TRANSPARENT),
  SYN_FLAG_OPT("sSkKiIpPnNlL",           MAIN,   SKIPNL),
  SYN_FLAG_OPT("sSkKiIpPwWhHiItTeE",     MAIN,   SKIPWHITE),
  SYN_FLAG_OPT("sSkKiIpPeEmMpPtTyY",     MAIN,   SKIPEMPTY),
  SYN_GROUP_OPT("gGrRoOuUpPhHeErReE",    SYNC,   GROUPHERE),
  SYN_GROUP_OPT("gGrRoOuUpPtThHeErReE",  SYNC,   GROUPTHERE),
  SYN_FLAG_OPT("dDiIsSpPlLaAyY",         MAIN,   DISPLAY),
  SYN_FLAG_OPT("fFoOlLdD",               MAIN,   FOLD),
  SYN_FLAG_OPT("cCoOnNcCeEaAlL",         MAIN,   CONCEAL),
  SYN_FLAG_OPT("cCoOnNcCeEaAlLeEnNdDsS", REGION, CONCEALENDS),
  SYN_OPT("cCcChHaArR",             CharStr, MAIN,   CCHAR),
  SYN_OPT("cCoOnNtTaAiInNsS",       SGroups, MR,     CONTAINS),
  SYN_OPT("cCoOnNtTaAiInNeEdDiInN", Groups,  MAIN,   CONTAINEDIN),
  SYN_OPT("nNeExXtTgGrRoOuUpP",     Groups,  MAIN,   NEXTGROUP),
  { NULL, 0, 0, 0, 0 },
};
static const char *first_synopt_letters = "cCoOkKeEtTsSgGdDfFnN";

/// Get syntax various :syn options
///
/// @param[in]  state  Parser state.
/// @param[out]  ret_parsed  Location where error will be saved.
/// @param[in]  flags_offset  Index at which flags are located in subargsargs.
/// @param[in]  scope  What :syn subcommand is parsed.
/// @param[out]  subargsargs  Location where results will be saved.
///
/// @return OK in case of success, NOTDONE in case of error and FAIL in case of
///         non-recoverable error. NOTDONE may be returned when
///         ret_parsed->error is not set.
static int get_syn_options(CMD_P_ARGS, const int flags_offset,
                           const uint_least32_t scope,
                           CommandArg *const subargsargs)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  for (;;) {
    // This is used very often when a large number of keywords is defined.
    // Need to skip quickly when no option name is found.
    // Also avoid tolower(), it's slow.
    if (strchr(first_synopt_letters, *state->cmdp) == NULL) {
      break;
    }

    const SynOptDef *cur_def;

    size_t len = 0;
    for (cur_def = &synopttab[0]; cur_def->name != NULL; cur_def++) {
      const char *const name = cur_def->name;
      size_t i;
      for (i = 0, len = 0; name[i] != NUL; i += 2, len++) {
        if (state->cmdp[len] != name[i] && state->cmdp[len] != name[i + 1]) {
          break;
        }
      }
      if (name[i] == NUL && (ascii_iswhite(state->cmdp[len])
                             || ((cur_def->type == kSynOptFlag
                                  || cur_def->type == kSynOptGroup)
                                 ? ENDS_EXCMD(state->cmdp[len])
                                 : state->cmdp[len] == '='))) {
        if (!(scope & cur_def->acceted_commands)) {
          if (scope == SYN_SCOPE_KEYWORD) {
            cur_def = &synopttab[ARRAY_SIZE(synopttab) - 1];
          } else {
            ret_parsed->error.message =
                N_("E395: This option is not accepted for this command");
            ret_parsed->error.position = state->cmdp;
            return NOTDONE;
          }
        }
        break;
      }
    }
    if (cur_def->name == NULL) {  // No match found.
      break;
    }
    state->cmdp += len;
    const int offset = flags_offset + cur_def->offset;
    switch (cur_def->type) {
      case kSynOptFlag: {
        subargsargs[offset].arg.flags |= cur_def->flag;
        break;
      }
      case kSynOptSGroups:
      case kSynOptGroups: {
        const int pglret = parse_group_list(state, ret_parsed,
                                            &subargsargs[offset].arg.group,
                                            cur_def->type == kSynOptSGroups);
        if (pglret != OK) {
          return pglret;
        }
        break;
      }
      case kSynOptCharStr: {
        if (*state->cmdp == '=') {
          state->cmdp++;
          const char *const cchar_start = state->cmdp;
          int cchar;
          size_t cchar_len;
          if (has_mbyte) {
            cchar_len = mb_ptr2len(state->cmdp);
            cchar = mb_ptr2char(state->cmdp);
          } else {
            cchar_len = 1;
            cchar = *state->cmdp;
          }
          state->cmdp += cchar_len;
          if (!vim_isprintc_strict(cchar)) {
            ret_parsed->error.message =
                N_("E844: Cchar argument is not printable");
            ret_parsed->error.position = cchar_start;
            return NOTDONE;
          }
          if (subargsargs[offset].arg.str != NULL) {
            xfree(subargsargs[offset].arg.str);
            subargsargs[offset].arg.str = NULL;
          }
          subargsargs[offset].arg.str = xmemdupz(cchar_start, cchar_len);
        }
        break;
      }
      case kSynOptGroup: {
        state->cmdp = skipwhite(state->cmdp);
        const char *const group_name_start = state->cmdp;
        state->cmdp = skiptowhite(state->cmdp);
        if (state->cmdp == group_name_start) {
          return NOTDONE;
        }
        subargsargs[offset].arg.str =
            xmemdupz(group_name_start,
                     (size_t) (state->cmdp - group_name_start));
        break;
      }
    }
    state->cmdp = skipwhite(state->cmdp);
  }
  return OK;
}

#define GET_SYN_OPTIONS(ret, state, ret_parsed, subcmd_name, scope, \
                        subargsargs) \
    do { \
      ret = get_syn_options(state, ret_parsed, SYN_ARG_##subcmd_name##_FLAGS, \
                            scope, subargsargs); \
      STATIC_ASSERT(SYN_ARG_##subcmd_name##_FLAGS == \
                    (SYN_ARG_##subcmd_name##_FLAGS + SYN_ARG_FLAGS_OFFSET), \
                    "Flags have incorrect offset for get_syn_options"); \
      STATIC_ASSERT(SYN_ARG_##subcmd_name##_CCHAR == \
                    (SYN_ARG_##subcmd_name##_FLAGS + SYN_ARG_CCHAR_OFFSET), \
                    "Cchar has incorrect offset for get_syn_options"); \
      STATIC_ASSERT(SYN_ARG_##subcmd_name##_CONTAINS == \
                    (SYN_ARG_##subcmd_name##_FLAGS \
                     + SYN_ARG_CONTAINS_OFFSET), \
                    "Contained has incorrect offset for get_syn_options"); \
      STATIC_ASSERT(SYN_ARG_##subcmd_name##_CONTAINEDIN == \
                    (SYN_ARG_##subcmd_name##_FLAGS \
                     + SYN_ARG_CONTAINEDIN_OFFSET), \
                    "Containedin has incorrect offset for get_syn_options"); \
      STATIC_ASSERT(SYN_ARG_##subcmd_name##_NEXTGROUP == \
                    (SYN_ARG_##subcmd_name##_FLAGS \
                     + SYN_ARG_NEXTGROUP_OFFSET), \
                    "Nextgroup has incorrect offset for get_syn_options"); \
    } while (0)

static CMD_SUBP_DEF(parse_syntax_keyword)
{
  const char *group_name_end = NULL;

  const char *const args_start = get_group_name(state->cmdp, &group_name_end);

  if (args_start != NULL) {
    subargsargs[SYN_ARG_KEYWORD_GROUP].arg.str =
        xmemdupz(state->cmdp, (size_t) (group_name_end - state->cmdp));
    state->cmdp = args_start;
    garray_T *kw_ga = &subargsargs[SYN_ARG_KEYWORD_KEYWORDS].arg.ga_strs;
    ga_init(kw_ga, (int) sizeof(char *), 8);
    for (; !ENDS_EXCMD(*state->cmdp); state->cmdp = skipwhite(state->cmdp)) {
      int gso_ret;
      GET_SYN_OPTIONS(gso_ret, state, ret_parsed, KEYWORD, SYN_SCOPE_KEYWORD,
                      subargsargs);
      if (ENDS_EXCMD(*state->cmdp) || (gso_ret == NOTDONE
                                       && ret_parsed->error.message == NULL)) {
        break;
      }
      if (gso_ret != OK) {
        return gso_ret;
      }
      const char *const kw_start = state->cmdp;
      size_t escapes = 0;
      while (*state->cmdp && !ascii_iswhite(*state->cmdp)) {
        if (*state->cmdp == '\\' && state->cmdp[1] != NUL) {
          state->cmdp++;
          escapes++;
        }
        state->cmdp++;
      }
      const size_t kw_len = (size_t) (state->cmdp - kw_start);
      char *const kw = xmallocz(kw_len - escapes);
      GA_APPEND(char *, kw_ga, kw);
      char *kwp = kw;
      const char *curp = kw_start;
      while (curp < state->cmdp) {
        if (*curp == '\\' && curp[1] != NUL) {
          curp++;
        }
        *kwp++ = *curp++;
      }
      state->cmdp = skipwhite(state->cmdp);
    }
  } else {
    ret_parsed->error.message = (state->cmdp == group_name_end
                                 ? N_("E475: Expected group name")
                                 : N_("E475: Expected keywords"));
    ret_parsed->error.position = group_name_end;
    return NOTDONE;
  }
  return OK;
}

static CMD_SUBP_DEF(parse_syntax_list)
{
  if (ENDS_EXCMD(*state->cmdp)) {
    return OK;
  }
  STATIC_ASSERT((int) SYN_ARG_LIST_GROUPS == (int) SYN_ARG_CLEAR_GROUPS,
                ":syn-list is not compatible with :syn-clear");
  SynGroupList **next = &subargsargs[SYN_ARG_LIST_GROUPS].arg.group;
  while (!ENDS_EXCMD(*state->cmdp)) {
    const char *const arg_end = skiptowhite(state->cmdp);
    *next = xcalloc(1, sizeof(**next));
    if (*state->cmdp == '@') {
      (*next)->type = kSynGroupCluster;
      (*next)->data.name =
          xmemdupz(state->cmdp + 1, (size_t) (arg_end - (state->cmdp + 1)));
    } else {
      (*next)->type = kSynGroupLiteral;
      (*next)->data.name =
          xmemdupz(state->cmdp, (size_t) (arg_end - state->cmdp));
    }
    next = &((*next)->next);
    state->cmdp = skipwhite(arg_end);
  }
  return OK;
}

static const SpoDef spo_tab[] = {
  { "ms=", kSynRegOffsetMatchStart },
  { "me=", kSynRegOffsetMatchEnd },
  { "hs=", kSynRegOffsetHiStart },
  { "he=", kSynRegOffsetHiEnd },
  { "rs=", kSynRegOffsetRegionStart },
  { "re=", kSynRegOffsetRegionEnd },
  { "lc=", kSynRegOffsetLContext },
  { NULL, 0 },
};

/// Get syntax pattern
///
/// @param[in,out]  state  Parser state.
/// @param[out]  ret_parsed  Location where error will be saved.
/// @param[out]  syn_pat  Location where result will be saved.
///
/// @return OK in case of success, NOTDONE in case of error (ret_parsed->error
///         may not be set in this case) or FAIL in case of non-recoverable
///         error.
static int get_syn_pattern(CMD_P_ARGS, SynPattern *const syn_pat)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  // Need at least three characters.
  if (!*state->cmdp || !state->cmdp[1] || !state->cmdp[2]) {
    return NOTDONE;
  }
  const char *const pat_start = state->cmdp;
  char endch = *state->cmdp;
  state->cmdp++;
  int rret;
  if ((rret = get_regex(state, ret_parsed, &syn_pat->reg, endch, NULL)) != OK) {
    return rret;
  }
  if (state->cmdp[-1] != endch) {
    ret_parsed->error.message = N_("E401: Pattern delimiter not found");
    ret_parsed->error.position = pat_start;
    return NOTDONE;
  }
  garray_T ga_off_flagss;
  ga_init(&ga_off_flagss, (int) sizeof(uint_least32_t), 1);
  garray_T ga_offs;
  ga_init(&ga_offs, (int) sizeof(int), 1);
  for (;;) {
    const SpoDef *cur_def;
    for (cur_def = &spo_tab[0]; cur_def->name != NULL; cur_def++) {
      if (strncmp(state->cmdp, cur_def->name, 3) == 0) {
        break;
      }
    }
    if (cur_def->name == NULL) {
      break;
    }
    state->cmdp += 3;
    uint_least32_t flags = (uint_least32_t) cur_def->type;
    if (cur_def->type != kSynRegOffsetLContext) {
      switch (*state->cmdp) {
        case 'b':
        case 's': {
          flags |= kSynRegOffsetAnchorStart;
          break;
        }
        case 'e': {
          flags |= kSynRegOffsetAnchorEnd;
          break;
        }
        default: {
          ret_parsed->error.message =
              N_("E402: Expected offset anchor designator (`s' or `e')");
          ret_parsed->error.position = state->cmdp;
          return NOTDONE;
        }
      }
      state->cmdp++;
    } else {
      flags |= kSynRegOffsetAnchorLC;
    }
    int offset = getdigits_int(&state->cmdp);
    GA_APPEND(uint_least32_t, &ga_off_flagss, flags);
    GA_APPEND(int, &ga_offs, offset);
    if (*state->cmdp != ',') {
      break;
    }
    state->cmdp++;
  }
  syn_pat->offset_count = (size_t) ga_off_flagss.ga_len;
  syn_pat->flagss = (uint_least32_t *) ga_off_flagss.ga_data;
  syn_pat->offsets = (int *) ga_offs.ga_data;
  if (!ENDS_EXCMD(*state->cmdp) && !ascii_iswhite(*state->cmdp)) {
    ret_parsed->error.message = N_("E402: Garbage after pattern");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
  state->cmdp = skipwhite(state->cmdp);
  return OK;
}

/// Add syn pattern to a list of syn patterns
///
/// @param[in,out]  state  Parser state.
/// @param[out]  ret_parsed  Location where error will be saved.
/// @param[out]  syn_pats  Location where results will be saved.
///
/// @return OK in case of success, NOTDONE in case of error (ret_parsed->error
///         may not be set in this case) or FAIL in case of non-recoverable
///         error.
static int add_syn_pattern(CMD_P_ARGS, SynPatterns **const syn_pats)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  SynPatterns **next = syn_pats;
  while ((*next) != NULL) {
    next = &((*next)->next);
  }
  *next = xcalloc(1, sizeof(**next));
  return get_syn_pattern(state, ret_parsed, &((*next)->syn_pat));
}

static int do_parse_syntax_match(CMD_SUBP_ARGS, uint_least32_t scope)
{
  const char *group_name_end;
  const char *const args_start = get_group_name(state->cmdp, &group_name_end);
  if (args_start != NULL) {
    subargsargs[SYN_ARG_MATCH_GROUP].arg.str =
        xmemdupz(state->cmdp, (size_t) (group_name_end - state->cmdp));
    state->cmdp = args_start;
    int gso_ret;
    GET_SYN_OPTIONS(gso_ret, state, ret_parsed, MATCH, scope, subargsargs);
    if (gso_ret == OK) {
      subargsargs[SYN_ARG_MATCH_REGEX].arg.syn_pat =
          xcalloc(1, sizeof(SynPattern));
      const int gsp_ret = get_syn_pattern(
          state, ret_parsed, subargsargs[SYN_ARG_MATCH_REGEX].arg.syn_pat);
      if (gsp_ret != OK) {
        return gsp_ret;
      }
      GET_SYN_OPTIONS(gso_ret, state, ret_parsed, MATCH, scope, subargsargs);
    }
    if (gso_ret != OK) {
      return gso_ret;
    }
    state->cmdp = skipwhite(state->cmdp);
    if (!ENDS_EXCMD(*state->cmdp)) {
      ret_parsed->error.message = N_("E475: Trailing characters");
      ret_parsed->error.position = state->cmdp;
      return NOTDONE;
    }
  } else {
    ret_parsed->error.message =
        N_("E475: Expected group name followed by an argument");
    ret_parsed->error.position = group_name_end;
    return NOTDONE;
  }
  return OK;
}

static CMD_SUBP_DEF(parse_syntax_match)
{
  return do_parse_syntax_match(state, ret_parsed, subargsargs, SYN_SCOPE_MATCH);
}

static CMD_SUBP_DEF(parse_syntax_region)
{
  const char *group_name_end;
  const char *const args_start = get_group_name(state->cmdp, &group_name_end);
  if (args_start != NULL) {
    subargsargs[SYN_ARG_REGION_GROUP].arg.str =
        xmemdupz(state->cmdp, (size_t) (group_name_end - state->cmdp));
    state->cmdp = args_start;
    while (!ENDS_EXCMD(*state->cmdp)) {
      int gso_ret;
      GET_SYN_OPTIONS(gso_ret, state, ret_parsed, REGION, SYN_SCOPE_REGION,
                      subargsargs);
      if (gso_ret != OK) {
        if (gso_ret == FAIL || ret_parsed->error.message != NULL) {
          return gso_ret;
        }
        break;
      }
      if (ENDS_EXCMD(*state->cmdp)) {
        break;
      }
      const char *const key_start = state->cmdp;
      while (*state->cmdp && !ascii_iswhite(*state->cmdp)
             && *state->cmdp != '=') {
        state->cmdp++;
      }
      const size_t key_len = (size_t) (state->cmdp - key_start);
      int arg_idx = -1;
      if (key_len == 10 && STRNICMP(key_start, "matchgroup", 10) == 0) {
        arg_idx = SYN_ARG_REGION_MATCHGROUP;
      } else if (key_len == 5 && STRNICMP(key_start, "start", 5) == 0) {
        arg_idx = SYN_ARG_REGION_STARTREG;
      } else if (key_len == 3 && STRNICMP(key_start, "end", 3) == 0) {
        arg_idx = SYN_ARG_REGION_ENDREG;
      } else if (key_len == 4 && STRNICMP(key_start, "skip", 4) == 0) {
        arg_idx = SYN_ARG_REGION_SKIPREG;
      } else {
        break;
      }
      state->cmdp = skipwhite(state->cmdp);
      if (*state->cmdp != '=') {
        ret_parsed->error.message = N_("E398: Missing `='");
        ret_parsed->error.position = state->cmdp;
        return NOTDONE;
      }
      state->cmdp = skipwhite(state->cmdp + 1);
      if (*state->cmdp == NUL) {
        if (arg_idx == SYN_ARG_REGION_MATCHGROUP) {
          ret_parsed->error.message = N_("E399: Expected group name");
        } else {
          ret_parsed->error.message = N_("E399: Expected syntax pattern");
        }
        ret_parsed->error.position = state->cmdp;
        return NOTDONE;
      }
      if (arg_idx == SYN_ARG_REGION_MATCHGROUP) {
        const char *const group_name_start = state->cmdp;
        state->cmdp = skiptowhite(group_name_start);
        if (state->cmdp - group_name_start != 4
            || strncmp(group_name_start, "NONE", 4) != 0) {
          xfree(subargsargs[arg_idx].arg.str);
          subargsargs[arg_idx].arg.str =
              xmemdupz(group_name_start,
                       (size_t) (state->cmdp - group_name_start));
        }
        state->cmdp = skipwhite(state->cmdp);
      } else {
        const int asp_ret = add_syn_pattern(state, ret_parsed,
                                            &subargsargs[arg_idx].arg.syn_pats);
        if (asp_ret != OK) {
          return asp_ret;
        }
        state->cmdp = skipwhite(state->cmdp);
      }
    }
  }
  if (!(subargsargs[SYN_ARG_REGION_STARTREG].arg.reg != NULL
        && subargsargs[SYN_ARG_REGION_ENDREG].arg.reg != NULL)) {
    ret_parsed->error.message = N_("E399: Not enough arguments");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }
  return OK;
}

static CMD_SUBP_DEF(parse_syntax_spell)
{
  const char *const s = state->cmdp;
  const char *const p = skiptowhite(s);
  if (p - s == 8 && STRNICMP(s, "toplevel", 8) == 0) {
    subargsargs[SYN_ARG_SPELL_FLAGS].arg.flags = VAL_SYN_SPELL_TOPLEVEL;
  } else if (p - s == 10 && STRNICMP(s, "notoplevel", 10) == 0) {
    subargsargs[SYN_ARG_SPELL_FLAGS].arg.flags = VAL_SYN_SPELL_NOTOPLEVEL;
  } else if (p - s == 7 && STRNICMP(s, "default", 7) == 0) {
    subargsargs[SYN_ARG_SPELL_FLAGS].arg.flags = VAL_SYN_SPELL_DEFAULT;
  } else {
    ret_parsed->error.message =
        N_("E390: Expected toplevel, notoplevel or default");
    ret_parsed->error.position = s;
    return NOTDONE;
  }
  state->cmdp = skipwhite(p);
  return OK;
}

#define parse_syntax_clear parse_syntax_list

static const SubCommandDefinition syntax_commands[] = {
  { SS("case"), kSynCase, SUBARGS(SYN_ARGS_CASE), &parse_syntax_case },
  { SS("clear"), kSynClear, SUBARGS(SYN_ARGS_CLEAR), &parse_syntax_clear },
  { SS("cluster"), kSynCluster, SUBARGS(SYN_ARGS_CLUSTER),
    &parse_syntax_cluster },
  { SS("conceal"), kSynConceal, SUBARGS(SYN_ARGS_CONCEAL),
    &parse_syntax_conceal },
  { SS("enable"), kSynEnable, EMPTY_SUBARGS, NULL },
  { SS("include"), kSynInclude, SUBARGS(SYN_ARGS_INCLUDE),
    &parse_syntax_include },
  { SS("keyword"), kSynKeyword, SUBARGS(SYN_ARGS_KEYWORD),
    &parse_syntax_keyword },
  { SS("list"), kSynList, SUBARGS(SYN_ARGS_LIST), &parse_syntax_list },
  { SS("manual"), kSynManual, EMPTY_SUBARGS, NULL },
  { SS("match"), kSynMatch, SUBARGS(SYN_ARGS_MATCH), &parse_syntax_match },
  { SS("on"), kSynOn, EMPTY_SUBARGS, NULL },
  { SS("off"), kSynOff, EMPTY_SUBARGS, NULL },
  { SS("region"), kSynRegion, SUBARGS(SYN_ARGS_REGION), &parse_syntax_region },
  { SS("reset"), kSynReset, EMPTY_SUBARGS, NULL },
  { SS("spell"), kSynSpell, SUBARGS(SYN_ARGS_SPELL), &parse_syntax_spell },
  { SS("sync"), kSynSync, SUBARGS(SYN_ARGS_SYNC), &parse_syntax_sync },
  { SS(""), kSynList, EMPTY_SUBARGS, NULL },
  { NULL, 0, 0, 0, NULL, NULL },
};

static CMD_SUBP_DEF(parse_syntax_sync)
{
  if (ENDS_EXCMD(*state->cmdp)) {
    return OK;
  }
  while (!ENDS_EXCMD(*state->cmdp)) {
    const char *const arg_start = state->cmdp;
    const char *const arg_end = skiptowhite(arg_start);
    state->cmdp = skipwhite(arg_end);
    const size_t arg_len = (size_t) (arg_end - arg_start);
    if (arg_len == 8 && STRNICMP(arg_start, "ccomment", 8) == 0) {
      if (!ENDS_EXCMD(*state->cmdp)) {
        const char *const group_name_start = state->cmdp;
        const char *const group_name_end = skiptowhite(group_name_start);
        state->cmdp = skipwhite(group_name_end);
        subargsargs[SYN_ARG_SYNC_CCOMMENT].arg.str =
            xmemdupz(group_name_start,
                     (size_t) (group_name_end - group_name_start));
      } else {
        subargsargs[SYN_ARG_SYNC_CCOMMENT].arg.str = xstrdup("Comment");
      }
    // Note: it appears that `syn sync lines` is not documented.
    } else if ((arg_len >= 5 && STRNICMP(arg_start, "lines", 5) == 0)
               || (arg_len >= 8 && STRNICMP(arg_start, "minlines", 8) == 0)
               || (arg_len >= 8 && STRNICMP(arg_start, "maxlines", 8) == 0)
               || (arg_len >= 10 && STRNICMP(arg_start, "linebreaks", 10) == 0)
               ) {
      const char *num_start =
          arg_start + (*arg_start == 'm' || *arg_start == 'M'
                       ? 9
                       : (arg_start[4] == 's' || arg_start[4] == 'S'
                          ? 6
                          : 11));
      if (num_start[-1] != '=' || !ascii_isdigit(*num_start)) {
        ret_parsed->error.message = N_("E404: Expected `=number'");
        ret_parsed->error.position = num_start - (num_start[-1] == '=');
        return NOTDONE;
      }
      int prop_idx = -1;
      if ((arg_len >= 5
           && (*arg_start == 'l' || *arg_start == 'L')
           && (arg_start[4] == 's' || arg_start[4] == 'S'))
          || (arg_len >= 8
              && (*arg_start == 'm' || *arg_start == 'M')
              && (arg_start[1] == 'i' || arg_start[1] == 'I'))) {
        // lines and minlines
        prop_idx = SYN_ARG_SYNC_MINLINES;
        subargsargs[SYN_ARG_SYNC_FLAGS].arg.flags |= FLAG_SYN_SYNC_HASMINLINES;
      } else if (arg_len >= 8
                 && (*arg_start == 'm' || *arg_start == 'M')
                 && (arg_start[1] == 'a' || arg_start[1] == 'A')) {
        // maxlines
        prop_idx = SYN_ARG_SYNC_MAXLINES;
        subargsargs[SYN_ARG_SYNC_FLAGS].arg.flags |= FLAG_SYN_SYNC_HASMAXLINES;
      } else {
        prop_idx = SYN_ARG_SYNC_LINEBREAKS;
        subargsargs[SYN_ARG_SYNC_FLAGS].arg.flags |=
            FLAG_SYN_SYNC_HASLINEBREAKS;
      }
      subargsargs[prop_idx].arg.unumber = (unsigned) getdigits_long(&num_start);
    } else if (arg_len == 9 && STRNICMP(arg_start, "fromstart", 9) == 0) {
      subargsargs[SYN_ARG_SYNC_FLAGS].arg.flags |= FLAG_SYN_SYNC_FROMSTART;
    } else if (arg_len == 8 && STRNICMP(arg_start, "linecont", 8) == 0) {
      if (subargsargs[SYN_ARG_SYNC_REGEX].arg.reg != NULL) {
        ret_parsed->error.message =
            N_("E403: syntax sync: line continuations pattern specified twice");
        ret_parsed->error.position = arg_start;
        return NOTDONE;
      }
      char endch = *state->cmdp;
      const char *const reg_start = state->cmdp;
      state->cmdp++;
      int rret;
      if ((rret = get_regex(state, ret_parsed,
                            &subargsargs[SYN_ARG_SYNC_REGEX].arg.reg, endch,
                            NULL))
          != OK) {
        return rret;
      }
      if (state->cmdp[-1] != endch) {
        ret_parsed->error.message = N_("E404: Pattern end not found");
        ret_parsed->error.position = reg_start;
        return NOTDONE;
      }
      state->cmdp = skipwhite(state->cmdp);
    } else {
      if ((arg_len == 5 && STRNICMP(arg_start, "match", 5) == 0)
          || (arg_len == 6 && STRNICMP(arg_start, "region", 6) == 0)
          || (arg_len == 5 && STRNICMP(arg_start, "clear", 5) == 0)) {
        CommandSubArgs *new_subargs =
            &subargsargs[SYN_ARG_SYNC_CMD].arg.args;
        if (arg_len == 5) {
          if (*arg_start == 'c' || *arg_start == 'C') {
            new_subargs->type = kSynClear;
          } else {
            new_subargs->type = kSynMatch;
          }
        } else {
          new_subargs->type = kSynRegion;
        }
        const SubCommandDefinition *const cur_cmd =
            &syntax_commands[new_subargs->type];
        new_subargs->num_args = cur_cmd->num_args;
        new_subargs->types = cur_cmd->types;
        CommandArg *new_subargsargs =
            xcalloc(new_subargs->num_args, sizeof(CommandArg));
        new_subargs->args = new_subargsargs;
        switch (new_subargs->type) {
          case kSynClear: {
            return parse_syntax_clear(state, ret_parsed, new_subargsargs);
          }
          case kSynMatch: {
            return do_parse_syntax_match(state, ret_parsed, new_subargsargs,
                                         SYN_SCOPE_MATCH|SYN_SCOPE_SYNC);
          }
          case kSynRegion: {
            return parse_syntax_region(state, ret_parsed, new_subargsargs);
          }
          default: {
            assert(false);
          }
        }
      } else {
        ret_parsed->error.message = N_("E404: Unknown argument");
        ret_parsed->error.position = arg_start;
        return NOTDONE;
      }
    }
  }
  return OK;
}

static CMD_P_DEF(parse_syntax)
{
  const char *const s = state->cmdp;
  const char *cmd_end;
  for (cmd_end = state->cmdp; ASCII_ISALPHA(*cmd_end); cmd_end++) {
  }
  const size_t cmd_len = (size_t) (cmd_end - s);
  const SubCommandDefinition *cur_cmd = &syntax_commands[0];
  CommandSubArgs *subargs = &ret_parsed->node->args[ARG_SUBCMD].arg.args;
  while (cur_cmd->name != NULL) {
    if (cur_cmd->name_len == cmd_len
        && strncmp(s, cur_cmd->name, cmd_len) == 0) {
      state->cmdp += cmd_len;
      state->cmdp = skipwhite(state->cmdp);
      subargs->type = cur_cmd->type;
      subargs->num_args = cur_cmd->num_args;
      subargs->types = cur_cmd->types;
      CommandArg *subargsargs = NULL;
      if (cur_cmd->num_args) {
        subargsargs = xcalloc(subargs->num_args, sizeof(CommandArg));
        subargs->args = subargsargs;
      }
      if (cur_cmd->parse) {
        int pret;
        if ((pret = cur_cmd->parse(state, ret_parsed, subargsargs)) != OK) {
          return pret;
        }
      }
      break;
    }
    cur_cmd++;
  }
  if (cur_cmd->name == NULL) {
    ret_parsed->error.message = N_("E410: Invalid :syntax subcommand");
    ret_parsed->error.position = s;
    return NOTDONE;
  }
  return OK;
}

#undef SUBARGS
#undef EMPTY_SUBARGS
#undef CMD_P_DEF
#undef CMD_SUBP_DEF

/// Check for an Ex command with optional tail.
///
/// @param[in,out]  pp   Start of the command. Is advanced to the command
///                      argument if requested command was found.
/// @param[in]      cmd  Name of the command which is checked for.
/// @param[in]      len  Minimal length required to accept a match.
///
/// @return true if requested command was found, false otherwise.
static bool check_for_cmd(const char **pp, const char *cmd, size_t len)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  size_t i;

  for (i = 0; cmd[i] != NUL; i++) {
    if (cmd[i] != (*pp)[i]) {
      break;
    }
  }

  if ((i >= len) && !isalpha((*pp)[i])) {
    *pp = skipwhite(*pp + i);
    return true;
  }
  return false;
}

/// Get a single Ex adress
///
/// @param[in,out]  state  Parser state. ->cmdp is advanced to the next
///                        character after parsed address. May point at
///                        whitespace.
/// @param[out]  ret_parsed  Location where error will be saved.
/// @param[out]  address  Structure where result will be saved.
///
/// @return OK when parsing was successfull, FAIL otherwise.
static int get_address(CMD_P_ARGS, Address *address)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  state->cmdp = skipwhite(state->cmdp);
  switch (*state->cmdp) {
    case '.': {
      address->type = kAddrCurrent;
      state->cmdp++;
      break;
    }
    case '$': {
      address->type = kAddrEnd;
      state->cmdp++;
      break;
    }
    case '\'': {
      address->type = kAddrMark;
      state->cmdp++;
      address->data.mark = *state->cmdp;
      if (*state->cmdp != NUL) {
        state->cmdp++;
      }
      break;
    }
    case '/':
    case '?': {
      const char c = *state->cmdp;
      state->cmdp++;
      if (c == '/')
        address->type = kAddrForwardSearch;
      else
        address->type = kAddrBackwardSearch;
      int rret;
      if ((rret = get_regex(state, ret_parsed, &address->data.regex, c, NULL))
          != OK) {
        return rret;
      }
      break;
    }
    case '\\': {
      state->cmdp++;
      switch (*state->cmdp) {
        case '&': {
          address->type = kAddrSubstituteSearch;
          break;
        }
        case '?': {
          address->type = kAddrBackwardPreviousSearch;
          break;
        }
        case '/': {
          address->type = kAddrForwardPreviousSearch;
          break;
        }
        default: {
          ret_parsed->error.message = (char *) e_backslash;
          ret_parsed->error.position = state->cmdp;
          return FAIL;
        }
      }
      state->cmdp++;
      break;
    }
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9': {
      address->type = kAddrFixed;
      address->data.lnr = (linenr_T) getdigits(&state->cmdp);
      break;
    }
    default: {
      address->type = kAddrMissing;
      break;
    }
  }
  return OK;
}

/// Get address modifiers
///
/// I.e. `/pat2/` in `/pat//pat2/` or `+1` in `/pat/+1`.
///
/// @param[in,out]  state  Parser state.
/// @param[out]  ret_parsed  Location where error will be saved.
/// @param[out]  followup  Location where result will be saved.
///
/// @return OK in case of success, NOTDONE in case of failure if error was set,
///         FAIL in case of non-recoverable error.
static int get_address_followups(CMD_P_ARGS, AddressFollowup **const followup)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  AddressFollowup *fw;
  AddressFollowupType type = kAddressFollowupMissing;

  state->cmdp = skipwhite(state->cmdp);
  switch (*state->cmdp) {
    case '-':
    case '+': {
      type = kAddressFollowupShift;
      break;
    }
    case '/': {
      type = kAddressFollowupForwardPattern;
      break;
    }
    case '?': {
      type = kAddressFollowupBackwardPattern;
      break;
    }
  }
  if (type != kAddressFollowupMissing) {
    state->cmdp++;
    fw = address_followup_alloc(type);
    fw->type = type;
    switch (type) {
      case kAddressFollowupShift: {
        int sign = (state->cmdp[-1] == '+' ? 1 : -1);
        if (ascii_isdigit(*state->cmdp)) {
          fw->data.shift = sign * (int) getdigits(&state->cmdp);
        } else {
          fw->data.shift = sign;
        }
        break;
      }
      case kAddressFollowupForwardPattern:
      case kAddressFollowupBackwardPattern: {
        int rret;
        if ((rret = get_regex(state, ret_parsed, &fw->data.regex,
                              state->cmdp[-1], NULL)) != OK) {
          free_address_followup(fw);
          return rret;
        }
        break;
      }
      default: {
        assert(false);
      }
    }
    *followup = fw;
    const int gaf_ret = get_address_followups(state, ret_parsed, &fw->next);
    if (gaf_ret != OK) {
      return gaf_ret;
    }
  }
  return OK;
}

/// Check if p points to a separator between Ex commands (possibly with spaces)
///
/// @param[in]  p  Checked string
///
/// @return First character of next command (last character after command
///         separator), NULL if no separator was found.
static const char *check_next_cmd(const char *p)
  FUNC_ATTR_CONST
{
  p = skipwhite(p);
  if (*p == '|' || *p == '\n') {
    return p + 1;
  } else {
    return NULL;
  }
}

// Table used to quickly search for a command, based on its first character.
static CommandType cmdidxs[27] =
{
  kCmdAppend,
  kCmdBuffer,
  kCmdChange,
  kCmdDelete,
  kCmdEdit,
  kCmdFile,
  kCmdGlobal,
  kCmdHelp,
  kCmdInsert,
  kCmdJoin,
  kCmdK,
  kCmdList,
  kCmdMove,
  kCmdNext,
  kCmdOpen,
  kCmdPrint,
  kCmdQuit,
  kCmdRead,
  kCmdSubstitute,
  kCmdT,
  kCmdUndo,
  kCmdVglobal,
  kCmdWrite,
  kCmdXit,
  kCmdYank,
  kCmdZ,
  kCmdBang
};

/// Find a built-in Ex command by its name or find user command name
///
/// @param[in,out]  state  Parser state. ->cmdp is advanced to the next
///                        character after the command.
/// @param[out]  ret_parsed  Location where results will be saved. Error will be
///                          saved in ret_parsed->error, other results in
///                          ret_parsed->node->type and ret_parsed->node->name.
///
/// @return OK if parsing was successfull, NOTDONE in case of error, FAIL in
///         case of non-recoverable error.
static int find_command(CMD_P_ARGS)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  CommandType cmdidx = kCmdUnknown;
  const char *p = state->cmdp;
  const char *const s = p;

  ret_parsed->node->name = NULL;

  // Isolate the command and search for it in the command table.
  // Exceptions:
  // - the 'k' command can directly be followed by any character.
  // - the 's' command can be followed directly by 'c', 'g', 'i', 'I' or 'r'
  //   but :sre[wind] is another command, as are :scrip[tnames],
  //   :scs[cope], :sim[alt], :sig[ns] and :sil[ent].
  // - the "d" command can directly be followed by 'l' or 'p' flag.
  if (*p == 'k') {
    ret_parsed->node->type = kCmdK;
    p++;
  } else if (p[0] == 's'
             && ((p[1] == 'c' && p[2] != 's' && p[2] != 'r'
                  && p[3] != 'i' && p[4] != 'p')
                 || p[1] == 'g'
                 || (p[1] == 'i' && p[2] != 'm' && p[2] != 'l' && p[2] != 'g')
                 || p[1] == 'I'
                 || (p[1] == 'r' && p[2] != 'e'))) {
    ret_parsed->node->type = kCmdSubstitute;
    p++;
  } else {
    bool found = false;

    while (ASCII_ISALPHA(*p)) {
      p++;
    }
    // for python 3.x support ":py3", ":python3", ":py3file", etc.
    if (s[0] == 'p' && s[1] == 'y') {
      while (ASCII_ISALNUM(*p)) {
        p++;
      }
    }

    // check for non-alpha command
    if (p == s && strchr("@*!=><&~#", *p) != NULL) {
      p++;
    }
    size_t len = (size_t) (p - s);
    if (*s == 'd' && (p[-1] == 'l' || p[-1] == 'p')) {
      // Check for ":dl", ":dell", etc. to ":deletel": that's
      // :delete with the 'l' flag.  Same for 'p'.
      size_t i;
      for (i = 0; i < len; i++) {
        if (s[i] != "delete"[i]) {
          break;
        }
      }
      if (i == len - 1) {
        --len;
      }
    }

    if (ASCII_ISLOWER(*s)) {
      cmdidx = cmdidxs[(int)(*s - 'a')];
    } else {
      cmdidx = cmdidxs[26];
    }

    for (; (int)cmdidx < (int)kCmdSIZE;
         cmdidx = (CommandType)((int)cmdidx + 1)) {
      if (STRNCMP(CMDDEF(cmdidx).name, s, len) == 0) {
        found = true;
        break;
      }
    }

    // Look for a user defined command as a last resort.
    if (!found && *s >= 'A' && *s <= 'Z') {
      // User defined commands may contain digits.
      while (ASCII_ISALNUM(*p)) {
        p++;
      }
      if (p == s) {
        cmdidx = kCmdUnknown;
      }
      ret_parsed->node->name = xmemdupz(s, (size_t) (p - s));
      ret_parsed->node->type = kCmdUSER;
    } else if (!found) {
      ret_parsed->node->type = kCmdUnknown;
      ret_parsed->error.message = N_("E492: Not an editor command");
      ret_parsed->error.position = s;
      return NOTDONE;
    } else {
      ret_parsed->node->type = cmdidx;
    }
  }

  state->cmdp = p;

  return OK;
}

/// Get command argument
///
/// Not used for commands with complex relations with bar or comment symbol:
/// e.g. :echo (it allows things like "echo 'abc|def'") or :write
/// (":w`='abc|def'`").
///
/// @param[in]  state  Parser state.
/// @param[out]  ret_parsed  Location where results will be saved.
/// @param[out]  arg              Resulting command-line argument.
/// @param[out]  next_cmd_offset  Offset of next command.
///
/// @return OK.
static int get_cmd_arg(CMD_P_ARGS, char **arg, size_t *next_cmd_offset)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  size_t skcnt = 0;
  const char *const start = state->cmdp;
  const char *p = start;
  bool did_set_next_cmd_offset = false;
  for (; *p; mb_ptr_adv_(p)) {
    if (*p == Ctrl_V) {
      if (CMDDEF(ret_parsed->node->type).flags & (USECTRLV)) {
      } else {
        skcnt++;
      }
      if (*p == NUL) {  // stop at NUL after CTRL-V
        break;
      }
    } else if ((*p == '"' && !(CMDDEF(ret_parsed->node->type).flags & NOTRLCOM)
                && ((ret_parsed->node->type != kCmdAt
                     && ret_parsed->node->type != kCmdStar)
                    || p != *arg)
                && (ret_parsed->node->type != kCmdRedir
                    || p != *arg + 1 || p[-1] != '@'))
               || *p == '|' || *p == '\n') {
      if (((state->o.flags & FLAG_POC_CPO_BAR)
           || !(CMDDEF(ret_parsed->node->type).flags & USECTRLV))
          && *(p - 1) == '\\') {
        skcnt++;
      } else {
        const char *nextcmd = check_next_cmd(p);
        if (nextcmd != NULL) {
          did_set_next_cmd_offset = true;
          *next_cmd_offset = (size_t) (nextcmd - start);
        }
        break;
      }
    }
  }

  ret_parsed->node->skips_count = skcnt;

  if (!did_set_next_cmd_offset) {
    *next_cmd_offset = (size_t) (p - start);
  }

  size_t len = (size_t) (p - start) - skcnt + 1;

  // From del_trailing_spaces: remove trailing spaces
  if (!(CMDDEF(ret_parsed->node->type).flags & NOTRLCOM)) {
    while (--p > start && ascii_iswhite(*p) && p[-1] != '\\'
           && p[-1] != Ctrl_V) {
      len--;
    }
  }

  const char *e = p;

  *arg = xmalloc(sizeof(char) * len);

  if (skcnt) {
    ret_parsed->node->skips = xmalloc(sizeof(size_t) * skcnt);
  } else {
    ret_parsed->node->skips = NULL;
  }

  size_t *cur_move = ret_parsed->node->skips;

  char *s = *arg;
  for (p = start; p <= e;) {
    if (*p == Ctrl_V && !(CMDDEF(ret_parsed->node->type).flags & USECTRLV)) {
      p++;
      *cur_move++ = (size_t) (p - start);
      if (*p == NUL) {  // stop at NUL after CTRL-V
        break;
      }
    // Check for '"': start of comment or '|': next command
    // :@" and :*" do not start a comment!
    // :redir @" doesn't either.
    } else if ((*p == '"'
                && !(CMDDEF(ret_parsed->node->type).flags & NOTRLCOM)
                && ((ret_parsed->node->type != kCmdAt
                     && ret_parsed->node->type != kCmdStar)
                    || p != start)
                && (ret_parsed->node->type != kCmdRedir
                    || p != start + 1
                    || p[-1] != '@'))
               || *p == '|'
               || *p == '\n') {
      // We remove the '\' before the '|', unless USECTRLV is used
      // AND 'b' is present in 'cpoptions'.
      if (((state->o.flags & FLAG_POC_CPO_BAR)
           || !(CMDDEF(ret_parsed->node->type).flags & USECTRLV))
          && p[-1] == '\\') {
        s--;  // remove the '\'
        *cur_move++ = (size_t) (p - start) - 1;
      } else {
        break;
      }
    } else if (*p == NUL) {
      break;
    }
    size_t ch_len = mb_ptr2len(p);
    memcpy(s, p, ch_len);
    s += ch_len;
    p += ch_len;
  }
  *s = NUL;

  return OK;
}

/// Fgetline implementation that simply returns given string
///
/// Useful for :execute, :*do, etc.
///
/// @param[in,out]  arg  Pointer to pointer to the start of string which will be
///                      returned. This string must live in an allocated memory.
const char *do_fgetline_allocated(int c, const char **arg, int indent)
{
  if (*arg) {
    const char *saved_arg = *arg;
    *arg = NULL;
    return saved_arg;
  } else {
    return NULL;
  }
}

/// Parse +cmd
///
/// @param[in,out]  state  Parser state. ->cmdp must point to the first +.
/// @param[in,out]  ret_parsed  Location where parsing results will be saved.
///                             They will be saved in ->node->children. Uses
///                             ->node->position.
///
/// @return OK if everything was parsed correctly, FAIL if out of memory.
///
/// @note Syntax errors in parsed command only happen *after* opening buffer.
static int parse_argcmd(CMD_P_ARGS)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  if (*state->cmdp == '+') {
    state->cmdp++;
    if (ascii_isspace(*state->cmdp) || !*state->cmdp) {
      CommandPosition new_position = ret_parsed->node->position;
      new_position.col = COL(state);
      ret_parsed->node->children = cmd_alloc(kCmdMissing, new_position);
      ret_parsed->node->children->range.address.type = kAddrEnd;
      ret_parsed->node->children->end_position = ENDPOS(state, COL(state));
    } else {
      const char *cmd_start = state->cmdp;
      char *arg;
      char *arg_start;
      CommandParserState new_state = *state;
      new_state.position = (CommandPosition) { 0, 0 };
      new_state.s = state->cmdp;
      new_state.line = (LineGetterOptions) {
        (VimlLineGetter) &do_fgetline_allocated, &arg_start, true };

      while (*state->cmdp && !ascii_isspace(*state->cmdp)) {
        if (*state->cmdp == '\\' && state->cmdp[1] != NUL) {
          state->cmdp++;
        }
        mb_ptr_adv_(state->cmdp);
      }

      arg = xmemdupz(cmd_start, (size_t) (state->cmdp - cmd_start));

      arg_start = arg;

      // TODO(ZyX-I): Record skips and adjust positions
      while (*arg) {
        if (*arg == '\\' && arg[1] != NUL) {
          STRMOVE(arg, arg + 1);
        }
        mb_ptr_adv_(arg);
      }
      CommandParserResult new_ret_parsed = *ret_parsed;

      if ((ret_parsed->node->children =
           parse_cmd_sequence(&new_state, &new_ret_parsed)) == NULL) {
        return FAIL;
      }

      assert(arg_start == NULL);
    }
  }
  return OK;
}

/// Parse ++opt
///
/// @param[in,out]  state  Parser state. ->cmdp must point to the first +.
/// @param[out]  ret_parsed  Location where results will be saved.
///
/// @return OK if everything was parsed correctly, NOTDONE in case of error,
///         FAIL if out of memory.
static int parse_argopt(CMD_P_ARGS)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  bool do_ff = false;
  bool do_enc = false;
  bool do_bad = false;
  const char *arg_start;

  state->cmdp += 2;
  if (strncmp(state->cmdp, "bin", 3) == 0
      || strncmp(state->cmdp, "nobin", 5) == 0) {
    if (*state->cmdp == 'n') {
      state->cmdp += 2;
      ret_parsed->node->optflags |= FLAG_OPT_BIN_USE_FLAG;
    } else {
      ret_parsed->node->optflags |= FLAG_OPT_BIN_USE_FLAG|FLAG_OPT_BIN;
    }
    if (!check_for_cmd(&state->cmdp, "binary", 3)) {
      ret_parsed->error.message =
          N_("E474: Expected ++[no]bin or ++[no]binary");
      ret_parsed->error.position = state->cmdp + 3;
      return NOTDONE;
    }
    state->cmdp = skipwhite(state->cmdp);
    return OK;
  }

  if (strncmp(state->cmdp, "edit", 4) == 0) {
    ret_parsed->node->optflags |= FLAG_OPT_EDIT;
    state->cmdp = skipwhite(state->cmdp + 4);
    return OK;
  }

  if (strncmp(state->cmdp, "ff", 2) == 0) {
    state->cmdp += 2;
    do_ff = true;
  } else if (strncmp(state->cmdp, "fileformat", 10) == 0) {
    state->cmdp += 10;
    do_ff = true;
  } else if (strncmp(state->cmdp, "enc", 3) == 0) {
    if (strncmp(state->cmdp, "encoding", 8) == 0) {
      state->cmdp += 8;
    } else {
      state->cmdp += 3;
    }
    do_enc = true;
  } else if (strncmp(state->cmdp, "bad", 3) == 0) {
    state->cmdp += 3;
    do_bad = true;
  } else {
    ret_parsed->error.message = N_("E474: Unknown ++opt");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }

  if (*state->cmdp != '=') {
    ret_parsed->error.message =
        N_("E474: Option requires argument: use ++opt=arg");
    ret_parsed->error.position = state->cmdp;
    return NOTDONE;
  }

  state->cmdp++;

  arg_start = state->cmdp;

  while (*state->cmdp && !ascii_isspace(*state->cmdp)) {
    if (*state->cmdp == '\\' && (state->cmdp)[1] != NUL) {
      state->cmdp++;
    }
    mb_ptr_adv_(state->cmdp);
  }

  if (do_ff) {
    // XXX check_ff_value requires NUL-terminated string. Thus I duplicate list
    //     of accepted strings here
    switch (*arg_start) {
      case 'd': {
        if (state->cmdp == arg_start + 3
            && arg_start[1] == 'o'
            && arg_start[2] == 's') {
          ret_parsed->node->optflags |= VAL_OPT_FF_DOS;
        } else {
          goto parse_argopt_ff_error;
        }
        break;
      }
      case 'u': {
        if (state->cmdp == arg_start + 4
            && arg_start[1] == 'n'
            && arg_start[2] == 'i'
            && arg_start[3] == 'x') {
          ret_parsed->node->optflags |= VAL_OPT_FF_UNIX;
        } else {
          goto parse_argopt_ff_error;
        }
        break;
      }
      case 'm': {
        if (state->cmdp == arg_start + 3
            && arg_start[1] == 'a'
            && arg_start[2] == 'c') {
          ret_parsed->node->optflags |= VAL_OPT_FF_MAC;
        } else {
          goto parse_argopt_ff_error;
        }
        break;
      }
      default: {
        goto parse_argopt_ff_error;
      }
    }
  } else if (do_enc) {
    char *e;
    ret_parsed->node->enc =
        xmemdupz(arg_start, (size_t) (state->cmdp - arg_start));
    for (e = ret_parsed->node->enc; *e != NUL; e++)
      *e = (char) TOLOWER_ASC(*e);
  } else if (do_bad) {
    size_t len = (size_t) (state->cmdp - arg_start);
    if (STRNICMP(arg_start, "keep", len) == 0) {
      ret_parsed->node->optflags |= VAL_OPT_BAD_KEEP;
    } else if (STRNICMP(arg_start, "drop", len) == 0) {
      ret_parsed->node->optflags |= VAL_OPT_BAD_DROP;
    } else if (MB_BYTE2LEN((size_t) *arg_start) == 1
               && state->cmdp == arg_start + 1) {
      ret_parsed->node->optflags |= CHAR_TO_VAL_OPT_BAD(*arg_start);
    } else {
      ret_parsed->error.message =
          N_("E474: Invalid ++bad argument: use "
             "\"keep\", \"drop\" or a single-byte character");
      ret_parsed->error.position = arg_start;
      return NOTDONE;
    }
  } else {
    assert(false);
  }
  state->cmdp = skipwhite(state->cmdp);
  return OK;
parse_argopt_ff_error:
  ret_parsed->error.message = N_("E474: Invalid ++ff argument");
  ret_parsed->error.position = arg_start;
  return NOTDONE;
}

/// Parse a range specifier of the form addr[,addr][;addr]…
///
/// Here `addr` is `main[+-]followup[+-]followup…` where `main` is one of
///
/// `main` | Accepts followup | Description
/// ------ | ---------------- | ------------------------------------------------
///  `%`   |       No         | Entire buffer. Equivalent to `1,$`.
///  `*`   |       No         | Visual range. Equivalent to `'<,'>`.
///  `$`   |       Yes        | Last line of the buffer.
///  `.`   |       Yes        | Current line.
/// empty  |       Yes        | Current line.
///  NUM   |       Yes        | Line number NUM in the buffer.
///  `'x`  |       Yes        | Mark `x`, defined for the current buffer.
/// `/re/` |       Yes        | Next line matching `re`.
/// `?re?` |       Yes        | Previous line matching `re`.
///
/// and `followup` is one of
///
/// `followup` | Description
/// ---------- | --------------------------------------------
///    NUM     | Move address defined by `main` by NUM lines.
///   `/re/`   | Search for `re` after `main`.
///   `?re?`   | Search for `re` before `main`.
///
/// @param[in,out]  state  Parser state.
/// @param[out]  ret_parsed  Location where error or result will be saved. If
///                          any, error will be saved in a form of an error
///                          node. Result is saved in ret_parsed->error->range.
/// @param[out]  range_start  Location where to save pointer to the first
///                           character of the range.
///
/// @return OK if everything was parsed correctly, NOTDONE in case of error,
///         FAIL otherwise.
int parse_range(CMD_P_ARGS, const char **range_start)
{
  Range current_range;

  *range_start = NULL;

  memset(&ret_parsed->node->range, 0, sizeof(ret_parsed->node->range));
  memset(&current_range, 0, sizeof(current_range));

  // repeat for all ',' or ';' separated addresses
  for (;;) {
    state->cmdp = skipwhite(state->cmdp);
    if (*range_start == NULL) {
      *range_start = state->cmdp;
    }
    if (get_address(state, ret_parsed, &current_range.address) == FAIL) {
      free_range_data(&current_range);
      if (ret_parsed->error.message == NULL) {
        return FAIL;
      }
      return create_error_node(state, ret_parsed);
    }
    const int gaf_ret = get_address_followups(state, ret_parsed,
                                              &current_range.address.followups);
    if (gaf_ret != OK) {
      free_range_data(&current_range);
      if (ret_parsed->error.message == NULL) {
        return FAIL;
      }
      return create_error_node(state, ret_parsed);
    }
    state->cmdp = skipwhite(state->cmdp);
    if (current_range.address.followups != NULL) {
      if (current_range.address.type == kAddrMissing)
        current_range.address.type = kAddrCurrent;
    } else if (ret_parsed->node->range.address.type == kAddrMissing
               && current_range.address.type == kAddrMissing) {
      if (*state->cmdp == '%') {
        current_range.address.type = kAddrFixed;
        current_range.address.data.lnr = 1;
        current_range.next = xcalloc(1, sizeof(*current_range.next));
        current_range.next->address.type = kAddrEnd;
        ret_parsed->node->range = current_range;
        state->cmdp++;
        break;
      } else if (*state->cmdp == '*' && !(state->o.flags & FLAG_POC_CPO_STAR)) {
        current_range.address.type = kAddrMark;
        current_range.address.data.mark = '<';
        current_range.next = xcalloc(1, sizeof(*current_range.next));
        current_range.next->address.type = kAddrMark;
        current_range.next->address.data.mark = '>';
        ret_parsed->node->range = current_range;
        state->cmdp++;
        break;
      }
    }
    current_range.setpos = (*state->cmdp == ';');
    if (ret_parsed->node->range.address.type != kAddrMissing) {
      Range **target = &ret_parsed->node->range.next;
      while (*target != NULL)
        target = &((*target)->next);
      *target = xcalloc(1, sizeof(**target));
      **target = current_range;
    } else {
      ret_parsed->node->range = current_range;
    }
    memset(&current_range, 0, sizeof(current_range));
    if (*state->cmdp == ';' || *state->cmdp == ',') {
      state->cmdp++;
    } else {
      break;
    }
  }
  return OK;
}

/// Parses command modifiers
///
/// @param[in,out]  state  Parser state.
/// @param[out]  ret_parsed  Location where parsing results will be saved.
/// @param[in]  pstart  Position of the first leading digit, if any.
///                     Points to the same location pp does otherwise.
///
/// @return OK if everything was parsed correctly, NOTDONE in case of error,
///         FAIL otherwise.
int parse_modifiers(CMD_P_ARGS, const char *const pstart)
  FUNC_ATTR_NONNULL_ALL
{
  CommandType type = kCmdMissing;
  const char *mod_start = state->cmdp;

  // FIXME (genex_cmds.lua): Iterate over precomputed table with only modifier
  //                         commands
  for (int i = cmdidxs[(int) (*state->cmdp - 'a')];
       *(CMDDEF(i).name) == *state->cmdp;
       i++) {
    if (CMDDEF(i).flags & ISMODIFIER) {
      size_t common_len = 0;
      if (i > 0) {
        const char *name = CMDDEF(i).name;
        const char *prev_name = CMDDEF(i - 1).name;
        common_len++;
        // FIXME (genex_cmds.lua): Precompute and record this in cmddefs
        while (name[common_len] == prev_name[common_len]) {
          common_len++;
        }
      }
      if (check_for_cmd(&state->cmdp, CMDDEF(i).name, common_len + 1)) {
        type = (CommandType) i;
        break;
      }
    }
  }
  if (type != kCmdMissing) {
    if (ascii_isdigit(*pstart) && !((CMDDEF(type).flags) & COUNT)) {
      ret_parsed->error.message = (char *) e_norange;
      ret_parsed->error.position = pstart;
      return create_error_node(state, ret_parsed);
    }
    if (*state->cmdp == '!' && !(CMDDEF(type).flags & BANG)) {
      ret_parsed->error.message = (char *) e_norange;
      ret_parsed->error.position = pstart;
      return create_error_node(state, ret_parsed);
    }
    RET_PARSED_CMD_ALLOC(ret_parsed, type, ret_parsed->node->position);
    if (ascii_isdigit(*pstart)) {
      ret_parsed->node->has_count = true;
      ret_parsed->node->count = (int) getdigits(&pstart);
    }
    if (*state->cmdp == '!') {
      ret_parsed->node->bang = true;
      state->cmdp++;
    }
    ret_parsed->node->position.col = P_COL(state, mod_start);
    ret_parsed->node->end_position = ENDPOS(state, COL(state) - 1);
    ret_parsed->cur_node = &ret_parsed->node->children;
  } else {
    state->cmdp = pstart;
  }
  return OK;
}

/// Add comment node
///
/// @param[in,out]  state  Parser state.
/// @param[out]  ret_parsed  Location where parsing results will be saved.
/// @param[in]  comment_type  Type of the comment.
///
/// @return OK
static int set_comment_node(CMD_P_ARGS, const CommandType comment_type)
  FUNC_ATTR_NONNULL_ALL
{
  RET_PARSED_CMD_ALLOC(ret_parsed, comment_type, ret_parsed->node->position);
  const size_t len = strlen(state->cmdp);
  ret_parsed->node->args[0].arg.str = xmemdup(state->cmdp, len + 1);
  state->cmdp += len;
  ret_parsed->node->end_position = ENDPOS(state, COL(state));
  return OK;
}

/// Parse lines without commands
///
/// Duplicates vi behaviour:
///
/// - `:3` jumps to line 3
/// - `:3|…` prints line 3
/// - `:|` prints current line
///
/// Is also responsible for creating comment nodes (unless they were created
/// earlier).
///
/// @param[in,out]  state  Parser state.
/// @param[in,out]  ret_parsed  Location where parsing results will be saved.
///                             Also contains current range in ->node.range.
/// @param[in]  prev_cmd_end  End of the previous command. Will be saved to
///                           the current node’s end_position member if there is
///                           current node.
/// @param[in]  nextcmd  Start of the next command.
///
/// @returns OK.
static int parse_no_cmd(CMD_P_ARGS,
                        const char *const prev_cmd_end,
                        const char *const nextcmd)
  FUNC_ATTR_NONNULL_ARG(1, 2, 3)
{
  const Range range = ret_parsed->node->range;
  if (NODE_IS_ALLOCATED(ret_parsed->node)) {
    ret_parsed->node->end_position = ENDPOS(state, COL(state));
  }
  if (*state->cmdp == '|' || (state->o.flags & FLAG_POC_EXMODE
                              && range.address.type != kAddrMissing)) {
    RET_PARSED_CMD_ALLOC(ret_parsed, kCmdPrint, ret_parsed->node->position);
    ret_parsed->node->range = range;
    state->cmdp++;
    ret_parsed->node->end_position = ENDPOS(state, COL(state));
    return OK;
  } else if (*state->cmdp == '"') {
    free_range_data(&ret_parsed->node->range);
    state->cmdp++;
    return set_comment_node(state, ret_parsed, kCmdComment);
  } else {
    RET_PARSED_CMD_ALLOC(ret_parsed, kCmdMissing, ret_parsed->node->position);
    ret_parsed->node->range = range;

    if (nextcmd != NULL) {
      state->cmdp = nextcmd;
    }
    ret_parsed->node->end_position = ENDPOS(state, COL(state));
    return OK;
  }
}

/// Parse a sequence of file names
///
/// @param[in,out]  state  Parser state.
/// @param[out]  ret_parsed  Location where results will be saved. Glob is saved
///                          in ->node->glob.
///
/// @return FAIL in case of failure, NOTDONE in case of error, OK in case of
///         success.
static int parse_files(CMD_P_ARGS)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  Glob *cur_glob = &ret_parsed->node->glob;
  Glob **next = &cur_glob;
  while (!ENDS_EXCMD(*state->cmdp)) {
    Pattern *pat = NULL;
    state->cmdp = skipwhite(state->cmdp);
    int pret;
    if ((pret = get_glob_pattern(state, ret_parsed, &pat, false, true))
        == FAIL) {
      return FAIL;
    }
    if (pret == NOTDONE) {
      free_pattern(pat);
      xfree(pat);
      return NOTDONE;
    }
    if (pat != NULL) {
      if (*next == NULL) {
        *next = xcalloc(1, sizeof(**next));
      }
      (*next)->pat = *pat;
      xfree(pat);
      next = &((*next)->next);
    }
  }
  return OK;
}

/// Parses one command
///
/// @param[in,out]  state  Parser state.
/// @param[out]  ret_parsed  Location where parsing results will be saved.
///
/// @return OK if everything was parsed correctly, FAIL if out of memory,
///         NOTDONE for parser error.
int parse_one_cmd(CMD_P_ARGS)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  CommandNode node = nocmd;
  node.type = kCmdUnknown;
  ret_parsed->node = &node;
  ret_parsed->main_node = NULL;

  node.position = (CommandPosition) { state->position.lnr, COL(state) };

#define FREE_CMD_ARG_START \
  do { \
    if (used_get_cmd_arg) { \
      xfree((void *) cmd_arg_start); \
      cmd_arg_start = NULL; \
    } \
  } while (0)
#define FAIL_RET do { ret = FAIL; goto parse_one_cmd_free_return; } while (0)
  bool used_get_cmd_arg = false;
  const char *cmd_arg;
  const char *cmd_arg_start;
  size_t next_cmd_offset = 0;
  size_t *cur_skip = node.skips;
  const char *real_cmd_arg = NULL;
  int ret = OK;

  if (state->cmdp[0] == '#' && state->cmdp[1] == '!'
      && state->position.col == 1) {
    state->cmdp += 2;
    return set_comment_node(state, ret_parsed, kCmdHashbangComment);
  }

  cmd_arg_start = cmd_arg = state->cmdp;
  for (;;) {
    const char *pstart;
    // 1. skip comment lines and leading white space and colons
    while (*state->cmdp == ' ' || *state->cmdp == TAB || *state->cmdp == ':') {
      state->cmdp++;
    }
    // in ex mode, an empty line works like :+ (switch to next line)
    if (*state->cmdp == NUL && state->o.flags & FLAG_POC_EXMODE) {
      AddressFollowup *fw;
      RET_PARSED_CMD_ALLOC(ret_parsed, kCmdMissing, node.position);
      ret_parsed->node->range.address.type = kAddrCurrent;
      fw = address_followup_alloc(kAddressFollowupShift);
      fw->data.shift = 1;
      ret_parsed->node->range.address.followups = fw;
      ret_parsed->node->end_position = ENDPOS(state, COL(state));
      return OK;
    }

    if (*state->cmdp == '"') {
      state->cmdp++;
      return set_comment_node(state, ret_parsed, kCmdComment);
    }

    if (*state->cmdp == NUL) {
      return OK;
    }

    pstart = state->cmdp;
    if (ascii_isdigit(*state->cmdp)) {
      state->cmdp = skipwhite(skipdigits(state->cmdp));
    }

    // 2. handle command modifiers.
    if (ASCII_ISLOWER(*state->cmdp)) {
      const int mret = parse_modifiers(state, ret_parsed, pstart);
      if (mret != OK) {
        return mret;
      } else if (state->cmdp == pstart) {
        break;
      }
      ret_parsed->node = &node;
    } else {
      state->cmdp = pstart;
      break;
    }
  }

  const char *modifiers_end = state->cmdp;
  const char *range_start = NULL;
  // 3. parse a range specifier
  {
    const int rret = parse_range(state, ret_parsed, &range_start);
    if (rret != OK) {
      return rret;
    }
  }

  // 4. parse command

  // Skip ':' and any white space
  while (*state->cmdp == ' ' || *state->cmdp == TAB || *state->cmdp == ':') {
    state->cmdp++;
  }

  const char *nextcmd = NULL;
  if (*state->cmdp == NUL || *state->cmdp == '"'
      || (nextcmd = check_next_cmd(state->cmdp)) != NULL) {
    return parse_no_cmd(state, ret_parsed, modifiers_end, nextcmd);
  }

  int fc_ret;
  if ((fc_ret = find_command(state, ret_parsed)) != OK) {
    ret = fc_ret;
    goto parse_one_cmd_checked_error_return;
  }

  // Here used to be :Ni! egg. It was removed

  if (*state->cmdp == '!') {
    if (CMDDEF(node.type).flags & BANG) {
      state->cmdp++;
      node.bang = true;
    } else {
      ret_parsed->error.message = (char *) e_nobang;
      ret_parsed->error.position = state->cmdp;
      goto parse_one_cmd_error_return;
    }
  }

  if (node.range.address.type != kAddrMissing
      && !(CMDDEF(node.type).flags & RANGE)) {
    ret_parsed->error.message = (char *) e_norange;
    ret_parsed->error.position = range_start;
    goto parse_one_cmd_error_return;
  }

  // Skip to start of argument.
  // Don't do this for the ":!" command, because ":!! -l" needs the space.
  if (node.type != kCmdBang) {
    state->cmdp = skipwhite(state->cmdp);
  }

  if (CMDDEF(node.type).flags & ARGOPT) {
    while (state->cmdp[0] == '+' && state->cmdp[1] == '+') {
      int aret;
      if ((aret = parse_argopt(state, ret_parsed)) == FAIL) {
        FAIL_RET;
      }
      if (aret == NOTDONE) {
        goto parse_one_cmd_error_return;
      }
    }
  }

  if (CMDDEF(node.type).flags & EDITCMD) {
    if (parse_argcmd(state, ret_parsed) == FAIL) {
      FAIL_RET;
    }
  }

  if (CMDDEF(node.type).flags & REGSTR && *state->cmdp != NUL
      // Numbered registers are not allowed for if count is allowed
      && !((CMDDEF(node.type).flags & COUNT) && ascii_isdigit(*state->cmdp))) {
    if (valid_yank_reg(*state->cmdp, node.type != kCmdPut)) {
      if (*state->cmdp == '=') {
        state->cmdp++;
        const char *expr_start = state->cmdp;
        used_get_cmd_arg = true;
        char *new_cmd_arg = NULL;
        if (get_cmd_arg(state, ret_parsed, &new_cmd_arg, &next_cmd_offset)
            == FAIL) {
          RET_PARSED_FREE_NODE(ret_parsed);
          FAIL_RET;
        }
        cmd_arg = cmd_arg_start = new_cmd_arg;
        ExpressionParserError expr_error;
        node.reg.name = '=';
        if ((node.reg.expr = parse_one_expression(
                    &cmd_arg, &expr_error, &parse0_err, node.position.col))
            == NULL) {
          ret_parsed->error.message = expr_error.message;
          ret_parsed->error.position = expr_error.position;
          goto parse_one_cmd_checked_error_return;
        }
        // Adjust p according to cmd_arg adjustment
        state->cmdp += (cmd_arg - cmd_arg_start);
        if (node.skips_count) {
          // TODO(ZyX-I): Test behavior when skip occurs at the very end
          cur_skip = node.skips;
          while (*cur_skip < (size_t) (state->cmdp - expr_start)) {
            state->cmdp++;
            cur_skip++;
          }
          real_cmd_arg = state->cmdp;
        }
      } else {
        node.reg.name = *state->cmdp;
        state->cmdp++;
      }
    } else {
      ret_parsed->error.message = (const char *) e_invalidreg;
      ret_parsed->error.position = state->cmdp;
      goto parse_one_cmd_error_return;
    }
  }

  if (CMDDEF(node.type).flags & COUNT && !(CMDDEF(node.type).flags & BUFNAME)) {
    if (ascii_isdigit(*state->cmdp)) {
      node.has_count = true;
      node.count = (int) getdigits(&state->cmdp);
      state->cmdp = skipwhite(state->cmdp);
    }
  }

  if (CMDDEF(node.type).flags & EXFLAGS) {
    for (;;) {
      switch (*state->cmdp) {
        case 'l': {
          node.exflags |= FLAG_EX_LIST;
          state->cmdp++;
          continue;
        }
        case '#': {
          node.exflags |= FLAG_EX_LNR;
          state->cmdp++;
          continue;
        }
        case 'p': {
          node.exflags |= FLAG_EX_PRINT;
          state->cmdp++;
          continue;
        }
        default: {
          break;
        }
      }
      break;
    }
  }

  if (CMDDEF(node.type).flags & (XFILE|BUFNAME)) {
    switch (parse_files(state, ret_parsed)) {
      case OK: {
        break;
      }
      case NOTDONE: {
        goto parse_one_cmd_error_return;
      }
      case FAIL: {
        goto parse_one_cmd_free_return;
      }
    }
  }

  if (!(CMDDEF(node.type).flags & EXTRA)
      && *state->cmdp != NUL && *state->cmdp != '"'
      && (*state->cmdp != '|' || !(CMDDEF(node.type).flags & TRLBAR))) {
    ret_parsed->error.message = (char *) e_trailing;
    ret_parsed->error.position = state->cmdp;
    goto parse_one_cmd_error_return;
  }

  if (NODE_IS_ALLOCATED(*ret_parsed->cur_node)) {
    (*ret_parsed->cur_node)->end_position = ENDPOS(state, COL(state));
  }
  RET_PARSED_CMD_ALLOC(ret_parsed, node.type, node.position);
  // Note: ignoring `args` array, thus cannot use `*ret_parsed->node = node`.
  memcpy(ret_parsed->node, &node, offsetof(CommandNode, args));
  ret_parsed->main_node = ret_parsed->node;

  const CommandArgsParser parse = CMDDEF(node.type).parse;

  if (parse != NULL) {
    // Adjust cmd_arg according to p
    if (used_get_cmd_arg) {
      cmd_arg += (state->cmdp - real_cmd_arg);
      if (node.skips_count) {
        // TODO(ZyX-I): Test behavior when skip occurs at the very end
        while (*cur_skip < (size_t) (state->cmdp - real_cmd_arg)) {
          cmd_arg--;
          cur_skip++;
        }
      }
    } else {
      cmd_arg = state->cmdp;
    }
    // XFILE commands may have bars inside `=…`
    // ISGREP commands may have bars inside patterns
    // ISEXPR commands may have bars inside "" or as logical OR
    if (!used_get_cmd_arg
        && !(CMDDEF(node.type).flags & (XFILE|ISGREP|ISEXPR|LITERAL))) {
      used_get_cmd_arg = true;
      char *new_cmd_arg = NULL;
      if (get_cmd_arg(state, ret_parsed, &new_cmd_arg, &next_cmd_offset)
          == FAIL) {
        goto parse_one_cmd_node_free_return;
      }
      cmd_arg = cmd_arg_start = new_cmd_arg;
    }
    int pret;
    CommandParserState new_state = *state;
    bool has_trailing_characters = false;
    if (used_get_cmd_arg) {
      new_state.cmdp = new_state.s = cmd_arg_start;
      new_state.position.col = COL(state);

      pret = parse(&new_state, ret_parsed);

      if (new_state.position.lnr > state->position.lnr || new_state.s == NULL) {
        if (new_state.line.can_free) {
          // cmd_arg_start was already freed
          cmd_arg_start = NULL;
          // But regular string still was not
          freeline(state);
        }
        state->position = new_state.position;
        state->s = state->cmdp = NULL;
      } else {
        assert(state->cmdp != NULL);
        state->cmdp += next_cmd_offset;
        has_trailing_characters = (new_state.cmdp != NULL
                                   && *new_state.cmdp != NUL);
      }
    } else {
      pret = parse(state, ret_parsed);
    }
    if (pret == FAIL) {
      goto parse_one_cmd_node_free_return;
    }
    assert(pret == NOTDONE || ret_parsed->error.message == NULL);
    if (pret == NOTDONE) {
      if (ret_parsed->node->type == kCmdSyntaxError) {
        ret = NOTDONE;
      } else {
        CommandParserState *used_state = (used_get_cmd_arg ? &new_state: state);
        RET_PARSED_FREE_NODE(ret_parsed);
        ret_parsed->node = &node;
        assert(used_state->s != NULL);
        ret = create_error_node(used_state, ret_parsed);
      }
      FREE_CMD_ARG_START;
      return ret;
    } else if (used_get_cmd_arg) {
      if (has_trailing_characters) {
        RET_PARSED_FREE_NODE(ret_parsed);
        ret_parsed->node = &node;
        ret_parsed->error.message = (char *) e_trailing;
        ret_parsed->error.position = new_state.cmdp;
        ret = create_error_node(&new_state, ret_parsed);
        FREE_CMD_ARG_START;
        return ret;
      }
    }
    ret = pret;
  }

  FREE_CMD_ARG_START;
  ret_parsed->node->end_position = ENDPOS(state, COL(state));
  return ret;
parse_one_cmd_checked_error_return:
  if (ret_parsed->error.message == NULL) {
    ret = FAIL;
  }
parse_one_cmd_error_return:
  ret = create_error_node(state, ret_parsed);
parse_one_cmd_free_return:
  FREE_CMD_ARG_START;
  node.type = kCmdMissing;
  clear_cmd(&node);
  return ret;
parse_one_cmd_node_free_return:
  FREE_CMD_ARG_START;
  RET_PARSED_FREE_NODE(ret_parsed);
  return FAIL;
#undef FREE_CMD_ARG_START
#undef FAIL_RET
}

static const BlockCommandDef empty_bd = {
  .same_group_type = kCmdUnknown,
  .same_group_type_2 = kCmdUnknown,
  .same_group_type_3 = kCmdUnknown,
  .not_after = kCmdUnknown,
  .push_stack = false,
  .not_after_message = NULL,
  .no_start_message = NULL,
  .duplicate_message = NULL,
};

/// Get block command definition
///
/// This function determines which commands are block commands (like :if), what
/// error messages should be shown when block command is misplaced and
/// conditions under which commands are considered misplaced.
///
/// @param[in]  type  Block command used.
///
/// @return Block command options.
static BlockCommandDef get_block_definition(const CommandType type)
  FUNC_ATTR_PURE
{
  BlockCommandDef bd = empty_bd;
  switch (type) {
    case kCmdEndif: {
      bd.no_start_message  = N_("E580: :endif without :if");
      bd.same_group_type_3 = kCmdElse;
      bd.same_group_type_2 = kCmdElseif;
      bd.same_group_type   = kCmdIf;
      break;
    }
    case kCmdElseif: {
      bd.not_after_message = N_("E584: :elseif after :else");
      bd.no_start_message  = N_("E582: :elseif without :if");
      bd.same_group_type_2 = kCmdElseif;
      bd.same_group_type   = kCmdIf;
      bd.not_after = kCmdElse;
      bd.push_stack = true;
      break;
    }
    case kCmdElse: {
      bd.no_start_message  = N_("E581: :else without :if");
      bd.duplicate_message = N_("E583: multiple :else");
      bd.same_group_type_2 = kCmdElseif;
      bd.same_group_type   = kCmdIf;
      bd.push_stack = true;
      break;
    }
    case kCmdEndfunction: {
      bd.no_start_message  = N_("E193: :endfunction not inside a function");
      bd.same_group_type   = kCmdFunction;
      break;
    }
    case kCmdEndtry: {
      bd.no_start_message  = N_("E602: :endtry without :try");
      bd.same_group_type_3 = kCmdFinally;
      bd.same_group_type_2 = kCmdCatch;
      bd.same_group_type   = kCmdTry;
      break;
    }
    case kCmdFinally: {
      bd.no_start_message  = N_("E606: :finally without :try");
      bd.duplicate_message = N_("E607: multiple :finally");
      bd.same_group_type_2 = kCmdCatch;
      bd.same_group_type   = kCmdTry;
      bd.push_stack = true;
      break;
    }
    case kCmdCatch: {
      bd.not_after_message = N_("E604: :catch after :finally");
      bd.no_start_message  = N_("E603: :catch without :try");
      bd.same_group_type_2 = kCmdCatch;
      bd.same_group_type   = kCmdTry;
      bd.not_after = kCmdFinally;
      bd.push_stack = true;
      break;
    }
    case kCmdEndfor: {
      bd.not_after_message = N_("E732: Using :endfor with :while");
      bd.no_start_message  = (char *) e_for;
      bd.same_group_type   = kCmdFor;
      bd.not_after = kCmdWhile;
      break;
    }
    case kCmdEndwhile: {
      bd.not_after_message = N_("E733: Using :endwhile with :for");
      bd.no_start_message  = (char *) e_while;
      bd.same_group_type   =kCmdWhile;
      bd.not_after = kCmdFor;
      break;
    }
    case kCmdIf:
    case kCmdFunction:
    case kCmdTry:
    case kCmdFor:
    case kCmdWhile: {
      bd.push_stack = true;
      break;
    }
    default: {
      break;
    }
  }
  return bd;
}

/// Get message for missing block command ends
///
/// @param[in]  type  Command for which message should be obtained. Must be one
///                   of the commands that starts block or separates it (i.e.
///                   if, else, elseif, function, finally, catch, try, for,
///                   while). Behavior is undefined if called for other
///                   commands.
///
/// @return Pointer to the error message. Must not be freed.
static char *get_missing_message(const CommandType type)
  FUNC_ATTR_PURE
{
  switch (type) {
    case kCmdElseif:
    case kCmdElse:
    case kCmdIf: {
      return (char *) e_endif;
      break;
    }
    case kCmdFunction: {
      return N_("E126: Missing :endfunction");
      break;
    }
    case kCmdFinally:
    case kCmdCatch:
    case kCmdTry: {
      return (char *) e_endtry;
      break;
    }
    case kCmdFor: {
      return (char *) e_endfor;
      break;
    }
    case kCmdWhile: {
      return (char *) e_endwhile;
      break;
    }
    default: {
      assert(false);
    }
  }
  return NULL;
}

/// Get next line
///
/// @param[in,out]  state  Where to get next line from. Line is saved into
///                        ->s and ->p, also adjusts ->position.lnr and zeroes
///                        ->position.col.
/// @param[in]  ch  First argument to state->line.get.
/// @param[in]  indent  Third argument to state->line.get.
///
/// @return true unless EOF. In case of EOF state is not touched.
bool nextline(CommandParserState *const state, const int ch, const int indent)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  char *const line = state->line.get(ch, state->line.cookie, indent);
  if (line == NULL) {
    return false;
  }
  state->cmdp = state->s = line;
  state->position.lnr++;
  state->position.col = 0;
  return true;
}

#define NEW_ERROR_NODE(error_message) \
        do { \
          ret_parsed->error.message = (error_message); \
          ret_parsed->error.position = state->cmdp; \
          ret_parsed->cur_node = bstack[bstack_idx].next_node; \
          ret_parsed->node = *ret_parsed->cur_node; \
          if (create_error_node(state, ret_parsed) == FAIL) { \
            goto parse_cmd_sequence_error; \
          } \
          bstack[bstack_idx].next_node \
              = &((*bstack[bstack_idx].next_node)->next); \
        } while (0)
#define NEW_BLOCK_SEP_ERROR_NODE(error_message) \
        do { \
          CommandNode **const next_node = bstack[bstack_idx].next_node; \
          NEW_ERROR_NODE(error_message); \
          if (bd.push_stack) { \
            bstack[bstack_idx].type = block_type; \
            bstack_idx++; \
            bstack[bstack_idx].type = kCmdMissing; \
            bstack[bstack_idx].next_node \
                = &(*next_node)->children; \
          } \
        } while (0)

/// Parses sequence of commands
///
/// @param[in,out]  state  Parser state.
/// @param[out]  ret_parsed  Location where parsing results will be saved.
///
/// @return Top-level command node or NULL in case of non-recoverable failure.
CommandNode *parse_cmd_sequence(CMD_P_ARGS)
  FUNC_ATTR_NONNULL_ALL
{
  struct blockstack_item {
    CommandType type;         // Block node type. May be kCmdMissing.
    CommandNode **next_node;  // Location where next node will be saved.
  } bstack[MAX_NEST_BLOCKS + 1];
  size_t bstack_idx = 0;
  CommandNode *result = NULL;

  bstack[0].type = kCmdMissing;
  bstack[0].next_node = &result;

  while (nextline(state, ':', (int) bstack_idx)) {
    state->cmdp = state->s;
    while (state->cmdp != NULL && *state->cmdp) {
      const char *const parse_start = state->cmdp;

      state->position.col = COL(state);
      ret_parsed->cur_node = bstack[bstack_idx].next_node;
      ret_parsed->node = *ret_parsed->cur_node;
      const int ret = parse_one_cmd(state, ret_parsed);
      if (ret == FAIL) {
        goto parse_cmd_sequence_error;
      }

      CommandNode *const block_command_node = ret_parsed->main_node;
      assert(parse_start != state->cmdp || ret == NOTDONE);
      (void)parse_start;

      const CommandType block_type = (block_command_node == NULL
                                      ? kCmdMissing
                                      : block_command_node->type);

      const BlockCommandDef bd = (
          (block_type == kCmdFunction
           && !block_command_node->args[ARG_FUNC_ARGS].arg.ga_strs.ga_growsize)
          ? empty_bd
          : get_block_definition(block_type));

      if (bd.same_group_type != kCmdUnknown) {
        const size_t initial_bstack_idx = bstack_idx;

        if (bstack_idx == 0) {
          free_cmd(*bstack[bstack_idx].next_node);
          *bstack[bstack_idx].next_node = NULL;
          NEW_ERROR_NODE(bd.no_start_message);
        } else {
          CommandNode *const new_node = *bstack[initial_bstack_idx].next_node;
          *bstack[initial_bstack_idx].next_node = NULL;
          bool emit_no_start_error = false;
          do {
            emit_no_start_error = false;
            if (bd.not_after != kCmdUnknown
                && bstack[bstack_idx].type == bd.not_after) {
              free_cmd(new_node);
              NEW_BLOCK_SEP_ERROR_NODE(bd.not_after_message);
              break;
            } else if (bd.duplicate_message != NULL
                       && bstack[bstack_idx].type == block_type) {
              free_cmd(new_node);
              NEW_BLOCK_SEP_ERROR_NODE(bd.duplicate_message);
              break;
            } else if (bstack[bstack_idx].type == bd.same_group_type
                       || bstack[bstack_idx].type == bd.same_group_type_2
                       || bstack[bstack_idx].type == bd.same_group_type_3) {
              *bstack[bstack_idx].next_node = new_node;
              bstack[bstack_idx].type = (bd.push_stack
                                         ? block_type
                                         : kCmdMissing);
              bstack[bstack_idx].next_node = &new_node->next;
              if (bd.push_stack) {
                bstack_idx++;
                bstack[bstack_idx].type = kCmdMissing;
                bstack[bstack_idx].next_node = &block_command_node->children;
              }
              break;
            } else if (bstack[bstack_idx].type != kCmdMissing) {
              NEW_ERROR_NODE(get_missing_message(bstack[bstack_idx].type));
              emit_no_start_error = true;
            } else {
              emit_no_start_error = true;
            }
          } while (bstack_idx && bstack_idx--);
          if (emit_no_start_error) {
            free_cmd(new_node);
            NEW_ERROR_NODE(bd.no_start_message);
            break;
          }
        }
      } else if (NODE_IS_ALLOCATED(*bstack[bstack_idx].next_node)) {
        bstack[bstack_idx].next_node = &((*bstack[bstack_idx].next_node)->next);
        if (bd.push_stack) {
          bstack[bstack_idx].type = block_type;
          bstack_idx++;
          if (bstack_idx >= MAX_NEST_BLOCKS) {
            // FIXME Make message with error code
            ret_parsed->error.message = N_("too many nested blocks");
            ret_parsed->error.position = state->cmdp;
            if (create_error_node(state, ret_parsed) == FAIL) {
              goto parse_cmd_sequence_error;
            }
            bstack_idx--;
          }
          bstack[bstack_idx].type = kCmdMissing;
          bstack[bstack_idx].next_node = &block_command_node->children;
        }
      }
      if (ret == NOTDONE) {
        break;
      }
      if (state->cmdp != NULL) {
        state->cmdp = skipwhite(state->cmdp);
        if (*state->cmdp == '|' || *state->cmdp == '\n') {
          state->cmdp++;
        }
      }
    }
    freeline(state);
    if (bstack_idx == 0 && state->o.early_return) {
      break;
    }
  }

  if (bstack_idx) {
    state->position.lnr++;
    state->cmdp = state->s = "";
    do {
      if (bstack[bstack_idx].type != kCmdMissing) {
        NEW_ERROR_NODE(get_missing_message(bstack[bstack_idx].type));
      }
    } while (bstack_idx && bstack_idx--);
  }

  return result;
parse_cmd_sequence_error:
  free_cmd(result);
  freeline(state);
  return NULL;
}

#undef NEW_ERROR_NODE
#undef NEW_BLOCK_SEP_ERROR_NODE

/// Fgetline implementation that calls another fgetline and saves the result
static char *saving_fgetline(int c, SavingFgetlineArgs *args, int indent)
{
  char *line = args->fgetline(c, args->cookie, indent);
  if (line != NULL) {
    GA_APPEND(char *, &args->ga, line);
  }
  return line;
}

void free_parser_result(ParserResult *pres)
{
  if (pres == NULL) {
    return;
  }
  free_cmd(pres->node);
  for (size_t i = 0; i < pres->lines_size; i++) {
    xfree(pres->lines[i]);
  }
  xfree(pres->lines);
  xfree(pres->fname);
  xfree(pres);
}

/// Return a pair (AST, lines that were parsed)
///
/// Parsed lines are supposed to be used for implementing `:function Func`
/// introspection and error reporting.
///
/// @param[in]  o         Parser options.
/// @param[in]  fname     Path to the parsed file or a string enclosed in `<` to
///                       indicate that current input is not from any file.
/// @param[in]  fgetline  Function used to obtain the next line.
///
///                       @par
///                       This function should return NULL when there are no
///                       more lines.
///
///                       @note This function must return string in allocated
///                             memory. Only parser thread must have access to
///                             strings returned by fgetline.
/// @param      cookie    Second argument to the above function.
ParserResult *parse_string(CommandParserOptions o, const char *fname,
                           VimlLineGetter fgetline, void *cookie)
  FUNC_ATTR_NONNULL_ALL
{
  ParserResult *ret = xcalloc(1, sizeof(*ret));
  SavingFgetlineArgs fgargs = {
    .fgetline = fgetline,
    .cookie = cookie
  };
  CommandParserState state = {
    .s = NULL,
    .cmdp = NULL,
    .line = {
      .get = (VimlLineGetter) &saving_fgetline,
      .cookie = &fgargs,
      .can_free = false,
    },
    .position = { 0, 0 },
    .o = o,
  };
  CommandParserResult ret_parsed;
  memset(&ret_parsed, 0, sizeof(ret_parsed));
  ga_init(&fgargs.ga, (int) sizeof(char *), 16);
  ret->node = parse_cmd_sequence(&state, &ret_parsed);
  ret->lines = (char **) fgargs.ga.ga_data;
  ret->lines_size = (size_t) fgargs.ga.ga_len;
  ret->fname = xstrdup(fname);
  if (ret->node == NULL) {
    free_parser_result(ret);
    return NULL;
  }
  return ret;
}
