// Handling of regular expressions: vim_regcomp(), vim_regexec(), vim_regsub()

// By default: do not create debugging logs or files related to regular
// expressions, even when compiling with -DDEBUG.
// Uncomment the second line to get the regexp debugging.
// #undef REGEXP_DEBUG
// #define REGEXP_DEBUG

#include <assert.h>
#include <ctype.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <stddef.h>
#include <string.h>
#include <uv.h>

#include "nvim/ascii_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/userfunc.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/keycodes.h"
#include "nvim/macros_defs.h"
#include "nvim/mark.h"
#include "nvim/mark_defs.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option_vars.h"
#include "nvim/os/input.h"
#include "nvim/plines.h"
#include "nvim/pos_defs.h"
#include "nvim/profile.h"
#include "nvim/regexp.h"
#include "nvim/regexp_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"

typedef enum {
  RGLF_LINE = 0x01,
  RGLF_LENGTH = 0x02,
  RGLF_SUBMATCH = 0x04,
} reg_getline_flags_T;

enum {
  /// In the NFA engine: how many braces are allowed.
  /// TODO(RE): Use dynamic memory allocation instead of static, like here
  NFA_MAX_BRACES = 20,
};

enum {
  /// In the NFA engine: how many states are allowed.
  NFA_MAX_STATES = 100000,
  NFA_TOO_EXPENSIVE = -1,
};

/// Which regexp engine to use? Needed for vim_regcomp().
/// Must match with 'regexpengine'.
enum {
  AUTOMATIC_ENGINE    = 0,
  BACKTRACKING_ENGINE = 1,
  NFA_ENGINE          = 2,
};

/// Structure returned by vim_regcomp() to pass on to vim_regexec().
/// This is the general structure. For the actual matcher, two specific
/// structures are used. See code below.
struct regprog {
  regengine_T *engine;
  unsigned regflags;
  unsigned re_engine;  ///< Automatic, backtracking or NFA engine.
  unsigned re_flags;   ///< Second argument for vim_regcomp().
  bool re_in_use;      ///< prog is being executed
};

/// Structure used by the back track matcher.
/// These fields are only to be used in regexp.c!
/// See regexp.c for an explanation.
typedef struct {
  // These four members implement regprog_T.
  regengine_T *engine;
  unsigned regflags;
  unsigned re_engine;
  unsigned re_flags;
  bool re_in_use;

  int regstart;
  uint8_t reganch;
  uint8_t *regmust;
  int regmlen;
  uint8_t reghasz;
  uint8_t program[];
} bt_regprog_T;

/// Structure representing a NFA state.
/// An NFA state may have no outgoing edge, when it is a NFA_MATCH state.
typedef struct nfa_state nfa_state_T;
struct nfa_state {
  int c;
  nfa_state_T *out;
  nfa_state_T *out1;
  int id;
  int lastlist[2];  ///< 0: normal, 1: recursive
  int val;
};

/// Structure used by the NFA matcher.
typedef struct {
  // These four members implement regprog_T.
  regengine_T *engine;
  unsigned regflags;
  unsigned re_engine;
  unsigned re_flags;
  bool re_in_use;

  nfa_state_T *start;   ///< points into state[]

  int reganch;          ///< pattern starts with ^
  int regstart;         ///< char at start of pattern
  uint8_t *match_text;  ///< plain text to match with

  int has_zend;         ///< pattern contains \ze
  int has_backref;      ///< pattern contains \1 .. \9
  int reghasz;
  char *pattern;
  int nsubexp;          ///< number of ()
  int nstate;
  nfa_state_T state[];
} nfa_regprog_T;

struct regengine {
  /// bt_regcomp or nfa_regcomp
  regprog_T *(*regcomp)(uint8_t *, int);
  /// bt_regfree or nfa_regfree
  void (*regfree)(regprog_T *);
  /// bt_regexec_nl or nfa_regexec_nl
  int (*regexec_nl)(regmatch_T *, uint8_t *, colnr_T, bool);
  /// bt_regexec_mult or nfa_regexec_mult
  int (*regexec_multi)(regmmatch_T *, win_T *, buf_T *, linenr_T, colnr_T, proftime_T *, int *);
#ifdef REGEXP_DEBUG
  uint8_t *expr;
#endif
};

// Structure used to save the current input state, when it needs to be
// restored after trying a match.  Used by reg_save() and reg_restore().
// Also stores the length of "backpos".
typedef struct {
  union {
    uint8_t *ptr;       // rex.input pointer, for single-line regexp
    lpos_T pos;        // rex.input pos, for multi-line regexp
  } rs_u;
  int rs_len;
} regsave_T;

// struct to save start/end pointer/position in for \(\)
typedef struct {
  union {
    uint8_t *ptr;
    lpos_T pos;
  } se_u;
} save_se_T;

// Values for rs_state in regitem_T.
typedef enum regstate_E {
  RS_NOPEN = 0,         // NOPEN and NCLOSE
  RS_MOPEN,             // MOPEN + [0-9]
  RS_MCLOSE,            // MCLOSE + [0-9]
  RS_ZOPEN,             // ZOPEN + [0-9]
  RS_ZCLOSE,            // ZCLOSE + [0-9]
  RS_BRANCH,            // BRANCH
  RS_BRCPLX_MORE,       // BRACE_COMPLEX and trying one more match
  RS_BRCPLX_LONG,       // BRACE_COMPLEX and trying longest match
  RS_BRCPLX_SHORT,      // BRACE_COMPLEX and trying shortest match
  RS_NOMATCH,           // NOMATCH
  RS_BEHIND1,           // BEHIND / NOBEHIND matching rest
  RS_BEHIND2,           // BEHIND / NOBEHIND matching behind part
  RS_STAR_LONG,         // STAR/PLUS/BRACE_SIMPLE longest match
  RS_STAR_SHORT,  // STAR/PLUS/BRACE_SIMPLE shortest match
} regstate_T;

// When there are alternatives a regstate_T is put on the regstack to remember
// what we are doing.
// Before it may be another type of item, depending on rs_state, to remember
// more things.
typedef struct regitem_S {
  regstate_T rs_state;         // what we are doing, one of RS_ above
  int16_t rs_no;            // submatch nr or BEHIND/NOBEHIND
  uint8_t *rs_scan;         // current node in program
  union {
    save_se_T sesave;
    regsave_T regsave;
  } rs_un;                      // room for saving rex.input
} regitem_T;

// used for BEHIND and NOBEHIND matching
typedef struct regbehind_S {
  regsave_T save_after;
  regsave_T save_behind;
  int save_need_clear_subexpr;
  save_se_T save_start[NSUBEXP];
  save_se_T save_end[NSUBEXP];
} regbehind_T;

// Since the out pointers in the list are always
// uninitialized, we use the pointers themselves
// as storage for the Ptrlists.
typedef union Ptrlist Ptrlist;
union Ptrlist {
  Ptrlist *next;
  nfa_state_T *s;
};

struct Frag {
  nfa_state_T *start;
  Ptrlist *out;
};
typedef struct Frag Frag_T;

typedef struct {
  int in_use;       ///< number of subexpr with useful info

  // When REG_MULTI is true list.multi is used, otherwise list.line.
  union {
    struct multipos {
      linenr_T start_lnum;
      linenr_T end_lnum;
      colnr_T start_col;
      colnr_T end_col;
    } multi[NSUBEXP];
    struct linepos {
      uint8_t *start;
      uint8_t *end;
    } line[NSUBEXP];
  } list;
  colnr_T orig_start_col;  // list.multi[0].start_col without \zs
} regsub_T;

typedef struct {
  regsub_T norm;      // \( .. \) matches
  regsub_T synt;      // \z( .. \) matches
} regsubs_T;

// nfa_pim_T stores a Postponed Invisible Match.
typedef struct nfa_pim_S nfa_pim_T;
struct nfa_pim_S {
  int result;                   // NFA_PIM_*, see below
  nfa_state_T *state;           // the invisible match start state
  regsubs_T subs;               // submatch info, only party used
  union {
    lpos_T pos;
    uint8_t *ptr;
  } end;                        // where the match must end
};

// nfa_thread_T contains execution information of a NFA state
typedef struct {
  nfa_state_T *state;
  int count;
  nfa_pim_T pim;                // if pim.result != NFA_PIM_UNUSED: postponed
                                // invisible match
  regsubs_T subs;               // submatch info, only party used
} nfa_thread_T;

// nfa_list_T contains the alternative NFA execution states.
typedef struct {
  nfa_thread_T *t;           ///< allocated array of states
  int n;                        ///< nr of states currently in "t"
  int len;                      ///< max nr of states in "t"
  int id;                       ///< ID of the list
  int has_pim;                  ///< true when any state has a PIM
} nfa_list_T;

#ifdef REGEXP_DEBUG
// show/save debugging data when BT engine is used
# define BT_REGEXP_DUMP
// save the debugging data to a file instead of displaying it
# define BT_REGEXP_LOG
# define BT_REGEXP_DEBUG_LOG
# define BT_REGEXP_DEBUG_LOG_NAME       "bt_regexp_debug.log"
#endif

// Magic characters have a special meaning, they don't match literally.
// Magic characters are negative.  This separates them from literal characters
// (possibly multi-byte).  Only ASCII characters can be Magic.
#define Magic(x)        ((int)(x) - 256)
#define un_Magic(x)     ((x) + 256)
#define is_Magic(x)     ((x) < 0)

typedef void (*fptr_T)(int *, int);

static int no_Magic(int x)
{
  if (is_Magic(x)) {
    return un_Magic(x);
  }
  return x;
}

static int toggle_Magic(int x)
{
  if (is_Magic(x)) {
    return un_Magic(x);
  }
  return Magic(x);
}

// The first byte of the BT regexp internal "program" is actually this magic
// number; the start node begins in the second byte.  It's used to catch the
// most severe mutilation of the program by the caller.
#define REGMAGIC        0234

// Utility definitions.
#define UCHARAT(p)      ((int)(*(uint8_t *)(p)))

// Used for an error (down from) vim_regcomp(): give the error message, set
// rc_did_emsg and return NULL
#define EMSG_RET_NULL(m) return (emsg(m), rc_did_emsg = true, (void *)NULL)
#define IEMSG_RET_NULL(m) return (iemsg(m), rc_did_emsg = true, (void *)NULL)
#define EMSG_RET_FAIL(m) return (emsg(m), rc_did_emsg = true, FAIL)
#define EMSG2_RET_NULL(m, c) \
  return (semsg((m), (c) ? "" : "\\"), rc_did_emsg = true, (void *)NULL)
#define EMSG3_RET_NULL(m, c, a) \
  return (semsg((m), (c) ? "" : "\\", (a)), rc_did_emsg = true, (void *)NULL)
#define EMSG2_RET_FAIL(m, c) \
  return (semsg((m), (c) ? "" : "\\"), rc_did_emsg = true, FAIL)
#define EMSG_ONE_RET_NULL EMSG2_RET_NULL(_(e_invalid_item_in_str_brackets), reg_magic == MAGIC_ALL)

#define MAX_LIMIT       (32767 << 16)

static const char e_invalid_character_after_str_at[]
  = N_("E59: Invalid character after %s@");
static const char e_invalid_use_of_underscore[]
  = N_("E63: Invalid use of \\_");
static const char e_pattern_uses_more_memory_than_maxmempattern[]
  = N_("E363: Pattern uses more memory than 'maxmempattern'");
static const char e_invalid_item_in_str_brackets[]
  = N_("E369: Invalid item in %s%%[]");
static const char e_missing_delimiter_after_search_pattern_str[]
  = N_("E654: Missing delimiter after search pattern: %s");
static const char e_missingbracket[] = N_("E769: Missing ] after %s[");
static const char e_reverse_range[] = N_("E944: Reverse range in character class");
static const char e_large_class[] = N_("E945: Range too large in character class");
static const char e_unmatchedpp[] = N_("E53: Unmatched %s%%(");
static const char e_unmatchedp[] = N_("E54: Unmatched %s(");
static const char e_unmatchedpar[] = N_("E55: Unmatched %s)");
static const char e_z_not_allowed[] = N_("E66: \\z( not allowed here");
static const char e_z1_not_allowed[] = N_("E67: \\z1 - \\z9 not allowed here");
static const char e_missing_sb[] = N_("E69: Missing ] after %s%%[");
static const char e_empty_sb[] = N_("E70: Empty %s%%[]");
static const char e_recursive[] = N_("E956: Cannot use pattern recursively");
static const char e_regexp_number_after_dot_pos_search_chr[]
  = N_("E1204: No Number allowed after .: '\\%%%c'");
static const char e_nfa_regexp_missing_value_in_chr[]
  = N_("E1273: (NFA regexp) missing value in '\\%%%c'");
static const char e_atom_engine_must_be_at_start_of_pattern[]
  = N_("E1281: Atom '\\%%#=%c' must be at the start of the pattern");
static const char e_substitute_nesting_too_deep[] = N_("E1290: substitute nesting too deep");

#define NOT_MULTI       0
#define MULTI_ONE       1
#define MULTI_MULT      2

// return values for regmatch()
#define RA_FAIL         1       // something failed, abort
#define RA_CONT         2       // continue in inner loop
#define RA_BREAK        3       // break inner loop
#define RA_MATCH        4       // successful match
#define RA_NOMATCH      5       // didn't match

/// Return NOT_MULTI if c is not a "multi" operator.
/// Return MULTI_ONE if c is a single "multi" operator.
/// Return MULTI_MULT if c is a multi "multi" operator.
static int re_multi_type(int c)
{
  if (c == Magic('@') || c == Magic('=') || c == Magic('?')) {
    return MULTI_ONE;
  }
  if (c == Magic('*') || c == Magic('+') || c == Magic('{')) {
    return MULTI_MULT;
  }
  return NOT_MULTI;
}

static char *reg_prev_sub = NULL;
static size_t reg_prev_sublen = 0;

// REGEXP_INRANGE contains all characters which are always special in a []
// range after '\'.
// REGEXP_ABBR contains all characters which act as abbreviations after '\'.
// These are:
//  \n  - New line (NL).
//  \r  - Carriage Return (CR).
//  \t  - Tab (TAB).
//  \e  - Escape (ESC).
//  \b  - Backspace (Ctrl_H).
//  \d  - Character code in decimal, eg \d123
//  \o  - Character code in octal, eg \o80
//  \x  - Character code in hex, eg \x4a
//  \u  - Multibyte character code, eg \u20ac
//  \U  - Long multibyte character code, eg \U12345678
static char REGEXP_INRANGE[] = "]^-n\\";
static char REGEXP_ABBR[] = "nrtebdoxuU";

// Translate '\x' to its control character, except "\n", which is Magic.
static int backslash_trans(int c)
{
  switch (c) {
  case 'r':
    return CAR;
  case 't':
    return TAB;
  case 'e':
    return ESC;
  case 'b':
    return BS;
  }
  return c;
}

enum {
  CLASS_ALNUM = 0,
  CLASS_ALPHA,
  CLASS_BLANK,
  CLASS_CNTRL,
  CLASS_DIGIT,
  CLASS_GRAPH,
  CLASS_LOWER,
  CLASS_PRINT,
  CLASS_PUNCT,
  CLASS_SPACE,
  CLASS_UPPER,
  CLASS_XDIGIT,
  CLASS_TAB,
  CLASS_RETURN,
  CLASS_BACKSPACE,
  CLASS_ESCAPE,
  CLASS_IDENT,
  CLASS_KEYWORD,
  CLASS_FNAME,
  CLASS_NONE = 99,
};

/// Check for a character class name "[:name:]".  "pp" points to the '['.
/// Returns one of the CLASS_ items. CLASS_NONE means that no item was
/// recognized.  Otherwise "pp" is advanced to after the item.
static int get_char_class(char **pp)
{
  // must be sorted by the 'value' field because it is used by bsearch()!
  static keyvalue_T char_class_tab[] = {
    KEYVALUE_ENTRY(CLASS_ALNUM, "alnum:]"),
    KEYVALUE_ENTRY(CLASS_ALPHA, "alpha:]"),
    KEYVALUE_ENTRY(CLASS_BACKSPACE, "backspace:]"),
    KEYVALUE_ENTRY(CLASS_BLANK, "blank:]"),
    KEYVALUE_ENTRY(CLASS_CNTRL, "cntrl:]"),
    KEYVALUE_ENTRY(CLASS_DIGIT, "digit:]"),
    KEYVALUE_ENTRY(CLASS_ESCAPE, "escape:]"),
    KEYVALUE_ENTRY(CLASS_FNAME, "fname:]"),
    KEYVALUE_ENTRY(CLASS_GRAPH, "graph:]"),
    KEYVALUE_ENTRY(CLASS_IDENT, "ident:]"),
    KEYVALUE_ENTRY(CLASS_KEYWORD, "keyword:]"),
    KEYVALUE_ENTRY(CLASS_LOWER, "lower:]"),
    KEYVALUE_ENTRY(CLASS_PRINT, "print:]"),
    KEYVALUE_ENTRY(CLASS_PUNCT, "punct:]"),
    KEYVALUE_ENTRY(CLASS_RETURN, "return:]"),
    KEYVALUE_ENTRY(CLASS_SPACE, "space:]"),
    KEYVALUE_ENTRY(CLASS_TAB, "tab:]"),
    KEYVALUE_ENTRY(CLASS_UPPER, "upper:]"),
    KEYVALUE_ENTRY(CLASS_XDIGIT, "xdigit:]")
  };

  // check that the value of "pp" has a chance of matching
  if ((*pp)[1] == ':' && ASCII_ISLOWER((*pp)[2])
      && ASCII_ISLOWER((*pp)[3]) && ASCII_ISLOWER((*pp)[4])) {
    // this function can be called repeatedly with the same value for "pp"
    // so we cache the last found entry.
    static keyvalue_T *last_entry = NULL;

    keyvalue_T target = {
      .key = 0,
      .value = *pp + 2,
      .length = 0,  // not used, see cmp_keyvalue_value_n()
    };

    keyvalue_T *entry;
    if (last_entry != NULL && cmp_keyvalue_value_n(&target, last_entry) == 0) {
      entry = last_entry;
    } else {
      entry = (keyvalue_T *)bsearch(&target, &char_class_tab,
                                    ARRAY_SIZE(char_class_tab),
                                    sizeof(char_class_tab[0]), cmp_keyvalue_value_n);
    }
    if (entry != NULL) {
      last_entry = entry;
      *pp += entry->length + 2;
      return entry->key;
    }
  }
  return CLASS_NONE;
}

// Specific version of character class functions.
// Using a table to keep this fast.
static int16_t class_tab[256];

#define     RI_DIGIT    0x01
#define     RI_HEX      0x02
#define     RI_OCTAL    0x04
#define     RI_WORD     0x08
#define     RI_HEAD     0x10
#define     RI_ALPHA    0x20
#define     RI_LOWER    0x40
#define     RI_UPPER    0x80
#define     RI_WHITE    0x100

static void init_class_tab(void)
{
  int i;
  static int done = false;

  if (done) {
    return;
  }

  for (i = 0; i < 256; i++) {
    if (i >= '0' && i <= '7') {
      class_tab[i] = RI_DIGIT + RI_HEX + RI_OCTAL + RI_WORD;
    } else if (i >= '8' && i <= '9') {
      class_tab[i] = RI_DIGIT + RI_HEX + RI_WORD;
    } else if (i >= 'a' && i <= 'f') {
      class_tab[i] = RI_HEX + RI_WORD + RI_HEAD + RI_ALPHA + RI_LOWER;
    } else if (i >= 'g' && i <= 'z') {
      class_tab[i] = RI_WORD + RI_HEAD + RI_ALPHA + RI_LOWER;
    } else if (i >= 'A' && i <= 'F') {
      class_tab[i] = RI_HEX + RI_WORD + RI_HEAD + RI_ALPHA + RI_UPPER;
    } else if (i >= 'G' && i <= 'Z') {
      class_tab[i] = RI_WORD + RI_HEAD + RI_ALPHA + RI_UPPER;
    } else if (i == '_') {
      class_tab[i] = RI_WORD + RI_HEAD;
    } else {
      class_tab[i] = 0;
    }
  }
  class_tab[' '] |= RI_WHITE;
  class_tab['\t'] |= RI_WHITE;
  done = true;
}

#define ri_digit(c)    ((c) < 0x100 && (class_tab[c] & RI_DIGIT))
#define ri_hex(c)      ((c) < 0x100 && (class_tab[c] & RI_HEX))
#define ri_octal(c)    ((c) < 0x100 && (class_tab[c] & RI_OCTAL))
#define ri_word(c)     ((c) < 0x100 && (class_tab[c] & RI_WORD))
#define ri_head(c)     ((c) < 0x100 && (class_tab[c] & RI_HEAD))
#define ri_alpha(c)    ((c) < 0x100 && (class_tab[c] & RI_ALPHA))
#define ri_lower(c)    ((c) < 0x100 && (class_tab[c] & RI_LOWER))
#define ri_upper(c)    ((c) < 0x100 && (class_tab[c] & RI_UPPER))
#define ri_white(c)    ((c) < 0x100 && (class_tab[c] & RI_WHITE))

// flags for regflags
#define RF_ICASE    1   // ignore case
#define RF_NOICASE  2   // don't ignore case
#define RF_HASNL    4   // can match a NL
#define RF_ICOMBINE 8   // ignore combining characters
#define RF_LOOKBH   16  // uses "\@<=" or "\@<!"

// Global work variables for vim_regcomp().

static char *regparse;          ///< Input-scan pointer.
static int regnpar;             ///< () count.
static bool wants_nfa;          ///< regex should use NFA engine
static int regnzpar;            ///< \z() count.
static int re_has_z;            ///< \z item detected
static unsigned regflags;       ///< RF_ flags for prog
static int had_eol;             ///< true when EOL found by vim_regcomp()

static magic_T reg_magic;       ///< magicness of the pattern

static int reg_string;          // matching with a string instead of a buffer
                                // line
static int reg_strict;          // "[abc" is illegal

// META contains all characters that may be magic, except '^' and '$'.

// uncrustify:off

// META[] is used often enough to justify turning it into a table.
static uint8_t META_flags[] = {
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
//                 %  &     (  )  *  +        .
    0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 1, 0,
//     1  2  3  4  5  6  7  8  9        <  =  >  ?
    0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1,
//  @  A     C  D     F     H  I     K  L  M     O
    1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 0, 1,
//  P        S     U  V  W  X     Z  [           _
    1, 0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 1, 0, 0, 0, 1,
//     a     c  d     f     h  i     k  l  m  n  o
    0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1,
//  p        s     u  v  w  x     z  {  |     ~
    1, 0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1
};

// uncrustify:on

static int curchr;              // currently parsed character
// Previous character.  Note: prevchr is sometimes -1 when we are not at the
// start, eg in /[ ^I]^ the pattern was never found even if it existed,
// because ^ was taken to be magic -- webb
static int prevchr;
static int prevprevchr;         // previous-previous character
static int nextchr;             // used for ungetchr()

// arguments for reg()
#define REG_NOPAREN     0       // toplevel reg()
#define REG_PAREN       1       // \(\)
#define REG_ZPAREN      2       // \z(\)
#define REG_NPAREN      3       // \%(\)

typedef struct {
  char *regparse;
  int prevchr_len;
  int curchr;
  int prevchr;
  int prevprevchr;
  int nextchr;
  int at_start;
  int prev_at_start;
  int regnpar;
} parse_state_T;

static regengine_T bt_regengine;
static regengine_T nfa_regengine;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "regexp.c.generated.h"
#endif

// Return true if compiled regular expression "prog" can match a line break.
int re_multiline(const regprog_T *prog)
  FUNC_ATTR_NONNULL_ALL
{
  return prog->regflags & RF_HASNL;
}

// Check for an equivalence class name "[=a=]".  "pp" points to the '['.
// Returns a character representing the class. Zero means that no item was
// recognized.  Otherwise "pp" is advanced to after the item.
static int get_equi_class(char **pp)
{
  int c;
  int l = 1;
  char *p = *pp;

  if (p[1] == '=' && p[2] != NUL) {
    l = utfc_ptr2len(p + 2);
    if (p[l + 2] == '=' && p[l + 3] == ']') {
      c = utf_ptr2char(p + 2);
      *pp += l + 4;
      return c;
    }
  }
  return 0;
}

// Check for a collating element "[.a.]".  "pp" points to the '['.
// Returns a character. Zero means that no item was recognized.  Otherwise
// "pp" is advanced to after the item.
// Currently only single characters are recognized!
static int get_coll_element(char **pp)
{
  int c;
  int l = 1;
  char *p = *pp;

  if (p[0] != NUL && p[1] == '.' && p[2] != NUL) {
    l = utfc_ptr2len(p + 2);
    if (p[l + 2] == '.' && p[l + 3] == ']') {
      c = utf_ptr2char(p + 2);
      *pp += l + 4;
      return c;
    }
  }
  return 0;
}

static int reg_cpo_lit;  // 'cpoptions' contains 'l' flag

static void get_cpo_flags(void)
{
  reg_cpo_lit = vim_strchr(p_cpo, CPO_LITERAL) != NULL;
}

/// Skip over a "[]" range.
/// "p" must point to the character after the '['.
/// The returned pointer is on the matching ']', or the terminating NUL.
static char *skip_anyof(char *p)
{
  int l;

  if (*p == '^') {  // Complement of range.
    p++;
  }
  if (*p == ']' || *p == '-') {
    p++;
  }
  while (*p != NUL && *p != ']') {
    if ((l = utfc_ptr2len(p)) > 1) {
      p += l;
    } else if (*p == '-') {
      p++;
      if (*p != ']' && *p != NUL) {
        MB_PTR_ADV(p);
      }
    } else if (*p == '\\'
               && (vim_strchr(REGEXP_INRANGE, (uint8_t)p[1]) != NULL
                   || (!reg_cpo_lit
                       && vim_strchr(REGEXP_ABBR, (uint8_t)p[1]) != NULL))) {
      p += 2;
    } else if (*p == '[') {
      if (get_char_class(&p) == CLASS_NONE
          && get_equi_class(&p) == 0
          && get_coll_element(&p) == 0
          && *p != NUL) {
        p++;          // It is not a class name and not NUL
      }
    } else {
      p++;
    }
  }

  return p;
}

/// Skip past regular expression.
/// Stop at end of "startp" or where "delim" is found ('/', '?', etc).
/// Take care of characters with a backslash in front of it.
/// Skip strings inside [ and ].
char *skip_regexp(char *startp, int delim, int magic)
{
  return skip_regexp_ex(startp, delim, magic, NULL, NULL, NULL);
}

/// Call skip_regexp() and when the delimiter does not match give an error and
/// return NULL.
char *skip_regexp_err(char *startp, int delim, int magic)
{
  char *p = skip_regexp(startp, delim, magic);

  if (*p != delim) {
    semsg(_(e_missing_delimiter_after_search_pattern_str), startp);
    return NULL;
  }
  return p;
}

/// skip_regexp() with extra arguments:
/// When "newp" is not NULL and "dirc" is '?', make an allocated copy of the
/// expression and change "\?" to "?".  If "*newp" is not NULL the expression
/// is changed in-place.
/// If a "\?" is changed to "?" then "dropped" is incremented, unless NULL.
/// If "magic_val" is not NULL, returns the effective magicness of the pattern
char *skip_regexp_ex(char *startp, int dirc, int magic, char **newp, int *dropped,
                     magic_T *magic_val)
{
  magic_T mymagic;
  char *p = startp;
  size_t startplen = 0;

  if (magic) {
    mymagic = MAGIC_ON;
  } else {
    mymagic = MAGIC_OFF;
  }
  get_cpo_flags();

  for (; p[0] != NUL; MB_PTR_ADV(p)) {
    if (p[0] == dirc) {         // found end of regexp
      break;
    }
    if ((p[0] == '[' && mymagic >= MAGIC_ON)
        || (p[0] == '\\' && p[1] == '[' && mymagic <= MAGIC_OFF)) {
      p = skip_anyof(p + 1);
      if (p[0] == NUL) {
        break;
      }
    } else if (p[0] == '\\' && p[1] != NUL) {
      if (dirc == '?' && newp != NULL && p[1] == '?') {
        // change "\?" to "?", make a copy first.
        if (startplen == 0) {
          startplen = strlen(startp);
        }
        if (*newp == NULL) {
          *newp = xstrnsave(startp, startplen);
          p = *newp + (p - startp);
          startp = *newp;
        }
        if (dropped != NULL) {
          (*dropped)++;
        }
        memmove(p, p + 1, startplen - (size_t)((p + 1) - startp) + 1);
      } else {
        p++;            // skip next character
      }
      if (*p == 'v') {
        mymagic = MAGIC_ALL;
      } else if (*p == 'V') {
        mymagic = MAGIC_NONE;
      }
    }
  }
  if (magic_val != NULL) {
    *magic_val = mymagic;
  }
  return p;
}

// variables used for parsing
static int prevchr_len;    // byte length of previous char
static int at_start;       // True when on the first character
static int prev_at_start;  // True when on the second character

// Start parsing at "str".
static void initchr(char *str)
{
  regparse = str;
  prevchr_len = 0;
  curchr = prevprevchr = prevchr = nextchr = -1;
  at_start = true;
  prev_at_start = false;
}

// Save the current parse state, so that it can be restored and parsing
// starts in the same state again.
static void save_parse_state(parse_state_T *ps)
{
  ps->regparse = regparse;
  ps->prevchr_len = prevchr_len;
  ps->curchr = curchr;
  ps->prevchr = prevchr;
  ps->prevprevchr = prevprevchr;
  ps->nextchr = nextchr;
  ps->at_start = at_start;
  ps->prev_at_start = prev_at_start;
  ps->regnpar = regnpar;
}

// Restore a previously saved parse state.
static void restore_parse_state(parse_state_T *ps)
{
  regparse = ps->regparse;
  prevchr_len = ps->prevchr_len;
  curchr = ps->curchr;
  prevchr = ps->prevchr;
  prevprevchr = ps->prevprevchr;
  nextchr = ps->nextchr;
  at_start = ps->at_start;
  prev_at_start = ps->prev_at_start;
  regnpar = ps->regnpar;
}

// Get the next character without advancing.
static int peekchr(void)
{
  static int after_slash = false;

  if (curchr != -1) {
    return curchr;
  }

  switch (curchr = (uint8_t)regparse[0]) {
  case '.':
  case '[':
  case '~':
    // magic when 'magic' is on
    if (reg_magic >= MAGIC_ON) {
      curchr = Magic(curchr);
    }
    break;
  case '(':
  case ')':
  case '{':
  case '%':
  case '+':
  case '=':
  case '?':
  case '@':
  case '!':
  case '&':
  case '|':
  case '<':
  case '>':
  case '#':           // future ext.
  case '"':           // future ext.
  case '\'':          // future ext.
  case ',':           // future ext.
  case '-':           // future ext.
  case ':':           // future ext.
  case ';':           // future ext.
  case '`':           // future ext.
  case '/':           // Can't be used in / command
    // magic only after "\v"
    if (reg_magic == MAGIC_ALL) {
      curchr = Magic(curchr);
    }
    break;
  case '*':
    // * is not magic as the very first character, eg "?*ptr", when
    // after '^', eg "/^*ptr" and when after "\(", "\|", "\&".  But
    // "\(\*" is not magic, thus must be magic if "after_slash"
    if (reg_magic >= MAGIC_ON
        && !at_start
        && !(prev_at_start && prevchr == Magic('^'))
        && (after_slash
            || (prevchr != Magic('(')
                && prevchr != Magic('&')
                && prevchr != Magic('|')))) {
      curchr = Magic('*');
    }
    break;
  case '^':
    // '^' is only magic as the very first character and if it's after
    // "\(", "\|", "\&' or "\n"
    if (reg_magic >= MAGIC_OFF
        && (at_start
            || reg_magic == MAGIC_ALL
            || prevchr == Magic('(')
            || prevchr == Magic('|')
            || prevchr == Magic('&')
            || prevchr == Magic('n')
            || (no_Magic(prevchr) == '('
                && prevprevchr == Magic('%')))) {
      curchr = Magic('^');
      at_start = true;
      prev_at_start = false;
    }
    break;
  case '$':
    // '$' is only magic as the very last char and if it's in front of
    // either "\|", "\)", "\&", or "\n"
    if (reg_magic >= MAGIC_OFF) {
      uint8_t *p = (uint8_t *)regparse + 1;
      bool is_magic_all = (reg_magic == MAGIC_ALL);

      // ignore \c \C \m \M \v \V and \Z after '$'
      while (p[0] == '\\' && (p[1] == 'c' || p[1] == 'C'
                              || p[1] == 'm' || p[1] == 'M'
                              || p[1] == 'v' || p[1] == 'V'
                              || p[1] == 'Z')) {
        if (p[1] == 'v') {
          is_magic_all = true;
        } else if (p[1] == 'm' || p[1] == 'M' || p[1] == 'V') {
          is_magic_all = false;
        }
        p += 2;
      }
      if (p[0] == NUL
          || (p[0] == '\\'
              && (p[1] == '|' || p[1] == '&' || p[1] == ')'
                  || p[1] == 'n'))
          || (is_magic_all
              && (p[0] == '|' || p[0] == '&' || p[0] == ')'))
          || reg_magic == MAGIC_ALL) {
        curchr = Magic('$');
      }
    }
    break;
  case '\\': {
    int c = (uint8_t)regparse[1];

    if (c == NUL) {
      curchr = '\\';  // trailing '\'
    } else if (c <= '~' && META_flags[c]) {
      // META contains everything that may be magic sometimes,
      // except ^ and $ ("\^" and "\$" are only magic after
      // "\V").  We now fetch the next character and toggle its
      // magicness.  Therefore, \ is so meta-magic that it is
      // not in META.
      curchr = -1;
      prev_at_start = at_start;
      at_start = false;  // be able to say "/\*ptr"
      regparse++;
      after_slash++;
      (void)peekchr();
      regparse--;
      after_slash--;
      curchr = toggle_Magic(curchr);
    } else if (vim_strchr(REGEXP_ABBR, c)) {
      // Handle abbreviations, like "\t" for TAB -- webb
      curchr = backslash_trans(c);
    } else if (reg_magic == MAGIC_NONE && (c == '$' || c == '^')) {
      curchr = toggle_Magic(c);
    } else {
      // Next character can never be (made) magic?
      // Then backslashing it won't do anything.
      curchr = utf_ptr2char(regparse + 1);
    }
    break;
  }

  default:
    curchr = utf_ptr2char(regparse);
  }

  return curchr;
}

// Eat one lexed character.  Do this in a way that we can undo it.
static void skipchr(void)
{
  // peekchr() eats a backslash, do the same here
  if (*regparse == '\\') {
    prevchr_len = 1;
  } else {
    prevchr_len = 0;
  }
  if (regparse[prevchr_len] != NUL) {
    // Exclude composing chars that utfc_ptr2len does include.
    prevchr_len += utf_ptr2len(regparse + prevchr_len);
  }
  regparse += prevchr_len;
  prev_at_start = at_start;
  at_start = false;
  prevprevchr = prevchr;
  prevchr = curchr;
  curchr = nextchr;         // use previously unget char, or -1
  nextchr = -1;
}

// Skip a character while keeping the value of prev_at_start for at_start.
// prevchr and prevprevchr are also kept.
static void skipchr_keepstart(void)
{
  int as = prev_at_start;
  int pr = prevchr;
  int prpr = prevprevchr;

  skipchr();
  at_start = as;
  prevchr = pr;
  prevprevchr = prpr;
}

// Get the next character from the pattern. We know about magic and such, so
// therefore we need a lexical analyzer.
static int getchr(void)
{
  int chr = peekchr();

  skipchr();
  return chr;
}

// put character back.  Works only once!
static void ungetchr(void)
{
  nextchr = curchr;
  curchr = prevchr;
  prevchr = prevprevchr;
  at_start = prev_at_start;
  prev_at_start = false;

  // Backup regparse, so that it's at the same position as before the
  // getchr().
  regparse -= prevchr_len;
}

// Get and return the value of the hex string at the current position.
// Return -1 if there is no valid hex number.
// The position is updated:
//     blahblah\%x20asdf
//         before-^ ^-after
// The parameter controls the maximum number of input characters. This will be
// 2 when reading a \%x20 sequence and 4 when reading a \%u20AC sequence.
static int64_t gethexchrs(int maxinputlen)
{
  int64_t nr = 0;
  int c;
  int i;

  for (i = 0; i < maxinputlen; i++) {
    c = (uint8_t)regparse[0];
    if (!ascii_isxdigit(c)) {
      break;
    }
    nr <<= 4;
    nr |= hex2nr(c);
    regparse++;
  }

  if (i == 0) {
    return -1;
  }
  return nr;
}

// Get and return the value of the decimal string immediately after the
// current position. Return -1 for invalid.  Consumes all digits.
static int64_t getdecchrs(void)
{
  int64_t nr = 0;
  int c;
  int i;

  for (i = 0;; i++) {
    c = (uint8_t)regparse[0];
    if (c < '0' || c > '9') {
      break;
    }
    nr *= 10;
    nr += c - '0';
    regparse++;
    curchr = -1;     // no longer valid
  }

  if (i == 0) {
    return -1;
  }
  return nr;
}

// get and return the value of the octal string immediately after the current
// position. Return -1 for invalid, or 0-255 for valid. Smart enough to handle
// numbers > 377 correctly (for example, 400 is treated as 40) and doesn't
// treat 8 or 9 as recognised characters. Position is updated:
//     blahblah\%o210asdf
//         before-^  ^-after
static int64_t getoctchrs(void)
{
  int64_t nr = 0;
  int c;
  int i;

  for (i = 0; i < 3 && nr < 040; i++) {
    c = (uint8_t)regparse[0];
    if (c < '0' || c > '7') {
      break;
    }
    nr <<= 3;
    nr |= hex2nr(c);
    regparse++;
  }

  if (i == 0) {
    return -1;
  }
  return nr;
}

// read_limits - Read two integers to be taken as a minimum and maximum.
// If the first character is '-', then the range is reversed.
// Should end with 'end'.  If minval is missing, zero is default, if maxval is
// missing, a very big number is the default.
static int read_limits(int *minval, int *maxval)
{
  int reverse = false;
  char *first_char;
  int tmp;

  if (*regparse == '-') {
    // Starts with '-', so reverse the range later.
    regparse++;
    reverse = true;
  }
  first_char = regparse;
  *minval = getdigits_int(&regparse, false, 0);
  if (*regparse == ',') {           // There is a comma.
    if (ascii_isdigit(*++regparse)) {
      *maxval = getdigits_int(&regparse, false, MAX_LIMIT);
    } else {
      *maxval = MAX_LIMIT;
    }
  } else if (ascii_isdigit(*first_char)) {
    *maxval = *minval;              // It was \{n} or \{-n}
  } else {
    *maxval = MAX_LIMIT;            // It was \{} or \{-}
  }
  if (*regparse == '\\') {
    regparse++;         // Allow either \{...} or \{...\}
  }
  if (*regparse != '}') {
    EMSG2_RET_FAIL(_("E554: Syntax error in %s{...}"), reg_magic == MAGIC_ALL);
  }

  // Reverse the range if there was a '-', or make sure it is in the right
  // order otherwise.
  if ((!reverse && *minval > *maxval) || (reverse && *minval < *maxval)) {
    tmp = *minval;
    *minval = *maxval;
    *maxval = tmp;
  }
  skipchr();            // let's be friends with the lexer again
  return OK;
}

// vim_regexec and friends

// Global work variables for vim_regexec().

// Sometimes need to save a copy of a line.  Since alloc()/free() is very
// slow, we keep one allocated piece of memory and only re-allocate it when
// it's too small.  It's freed in bt_regexec_both() when finished.
static uint8_t *reg_tofree = NULL;
static unsigned reg_tofreelen;

// Structure used to store the execution state of the regex engine.
// Which ones are set depends on whether a single-line or multi-line match is
// done:
//                      single-line             multi-line
// reg_match            &regmatch_T             NULL
// reg_mmatch           NULL                    &regmmatch_T
// reg_startp           reg_match->startp       <invalid>
// reg_endp             reg_match->endp         <invalid>
// reg_startpos         <invalid>               reg_mmatch->startpos
// reg_endpos           <invalid>               reg_mmatch->endpos
// reg_win              NULL                    window in which to search
// reg_buf              curbuf                  buffer in which to search
// reg_firstlnum        <invalid>               first line in which to search
// reg_maxline          0                       last line nr
// reg_line_lbr         false or true           false
typedef struct {
  regmatch_T *reg_match;
  regmmatch_T *reg_mmatch;

  uint8_t **reg_startp;
  uint8_t **reg_endp;
  lpos_T *reg_startpos;
  lpos_T *reg_endpos;

  win_T *reg_win;
  buf_T *reg_buf;
  linenr_T reg_firstlnum;
  linenr_T reg_maxline;
  bool reg_line_lbr;  // "\n" in string is line break

  // The current match-position is remembered with these variables:
  linenr_T lnum;  ///< line number, relative to first line
  uint8_t *line;   ///< start of current line
  uint8_t *input;  ///< current input, points into "line"

  int need_clear_subexpr;   ///< subexpressions still need to be cleared
  int need_clear_zsubexpr;  ///< extmatch subexpressions still need to be
                            ///< cleared

  // Internal copy of 'ignorecase'.  It is set at each call to vim_regexec().
  // Normally it gets the value of "rm_ic" or "rmm_ic", but when the pattern
  // contains '\c' or '\C' the value is overruled.
  bool reg_ic;

  // Similar to "reg_ic", but only for 'combining' characters.  Set with \Z
  // flag in the regexp.  Defaults to false, always.
  bool reg_icombine;

  bool reg_nobreak;

  // Copy of "rmm_maxcol": maximum column to search for a match.  Zero when
  // there is no maximum.
  colnr_T reg_maxcol;

  // State for the NFA engine regexec.
  int nfa_has_zend;     ///< NFA regexp \ze operator encountered.
  int nfa_has_backref;  ///< NFA regexp \1 .. \9 encountered.
  int nfa_nsubexpr;     ///< Number of sub expressions actually being used
                        ///< during execution. 1 if only the whole match
                        ///< (subexpr 0) is used.
  // listid is global, so that it increases on recursive calls to
  // nfa_regmatch(), which means we don't have to clear the lastlist field of
  // all the states.
  int nfa_listid;
  int nfa_alt_listid;

  int nfa_has_zsubexpr;  ///< NFA regexp has \z( ), set zsubexpr.
} regexec_T;

static regexec_T rex;
static bool rex_in_use = false;

static void reg_breakcheck(void)
{
  if (!rex.reg_nobreak) {
    fast_breakcheck();
  }
}

// Return true if character 'c' is included in 'iskeyword' option for
// "reg_buf" buffer.
static bool reg_iswordc(int c)
{
  return vim_iswordc_buf(c, rex.reg_buf);
}

static bool can_f_submatch = false;  ///< true when submatch() can be used

/// These pointers are used for reg_submatch().  Needed for when the
/// substitution string is an expression that contains a call to substitute()
/// and submatch().
typedef struct {
  regmatch_T *sm_match;
  regmmatch_T *sm_mmatch;
  linenr_T sm_firstlnum;
  linenr_T sm_maxline;
  int sm_line_lbr;
} regsubmatch_T;

static regsubmatch_T rsm;  ///< can only be used when can_f_submatch is true

/// Common code for reg_getline(), reg_getline_len(), reg_getline_submatch() and
/// reg_getline_submatch_len().
///
/// @param flags  a bitmask that controls what info is to be returned
///               and whether or not submatch is in effect.
static void reg_getline_common(linenr_T lnum, reg_getline_flags_T flags, char **line,
                               colnr_T *length)
{
  bool get_line = flags & RGLF_LINE;
  bool get_length = flags & RGLF_LENGTH;
  linenr_T firstlnum;
  linenr_T maxline;

  if (flags & RGLF_SUBMATCH) {
    firstlnum = rsm.sm_firstlnum + lnum;
    maxline = rsm.sm_maxline;
  } else {
    firstlnum = rex.reg_firstlnum + lnum;
    maxline = rex.reg_maxline;
  }

  // when looking behind for a match/no-match lnum is negative. but we
  // can't go before line 1.
  if (firstlnum < 1) {
    if (get_line) {
      *line = NULL;
    }
    if (get_length) {
      *length = 0;
    }

    return;
  }

  if (lnum > maxline) {
    // must have matched the "\n" in the last line.
    if (get_line) {
      *line = "";
    }
    if (get_length) {
      *length = 0;
    }

    return;
  }

  if (get_line) {
    *line = ml_get_buf(rex.reg_buf, firstlnum);
  }
  if (get_length) {
    *length = ml_get_buf_len(rex.reg_buf, firstlnum);
  }
}

/// Get pointer to the line "lnum", which is relative to "reg_firstlnum".
static char *reg_getline(linenr_T lnum)
{
  char *line;
  reg_getline_common(lnum, RGLF_LINE, &line, NULL);
  return line;
}

/// Get length of line "lnum", which is relative to "reg_firstlnum".
static colnr_T reg_getline_len(linenr_T lnum)
{
  colnr_T length;
  reg_getline_common(lnum, RGLF_LENGTH, NULL, &length);
  return length;
}

static uint8_t *reg_startzp[NSUBEXP];  // Workspace to mark beginning
static uint8_t *reg_endzp[NSUBEXP];    //   and end of \z(...\) matches
static lpos_T reg_startzpos[NSUBEXP];   // idem, beginning pos
static lpos_T reg_endzpos[NSUBEXP];     // idem, end pos

// true if using multi-line regexp.
#define REG_MULTI       (rex.reg_match == NULL)

// Create a new extmatch and mark it as referenced once.
static reg_extmatch_T *make_extmatch(void)
  FUNC_ATTR_NONNULL_RET
{
  reg_extmatch_T *em = xcalloc(1, sizeof(reg_extmatch_T));
  em->refcnt = 1;
  return em;
}

// Add a reference to an extmatch.
reg_extmatch_T *ref_extmatch(reg_extmatch_T *em)
{
  if (em != NULL) {
    em->refcnt++;
  }
  return em;
}

// Remove a reference to an extmatch.  If there are no references left, free
// the info.
void unref_extmatch(reg_extmatch_T *em)
{
  int i;

  if (em != NULL && --em->refcnt <= 0) {
    for (i = 0; i < NSUBEXP; i++) {
      xfree(em->matches[i]);
    }
    xfree(em);
  }
}

// Get class of previous character.
static int reg_prev_class(void)
{
  if (rex.input > rex.line) {
    return mb_get_class_tab((char *)rex.input - 1 -
                            utf_head_off((char *)rex.line, (char *)rex.input - 1),
                            rex.reg_buf->b_chartab);
  }
  return -1;
}

// Return true if the current rex.input position matches the Visual area.
static bool reg_match_visual(void)
{
  pos_T top, bot;
  linenr_T lnum;
  colnr_T col;
  win_T *wp = rex.reg_win == NULL ? curwin : rex.reg_win;
  int mode;
  colnr_T start, end;
  colnr_T start2, end2;
  colnr_T curswant;

  // Check if the buffer is the current buffer and not using a string.
  if (rex.reg_buf != curbuf || VIsual.lnum == 0 || !REG_MULTI) {
    return false;
  }

  if (VIsual_active) {
    if (lt(VIsual, wp->w_cursor)) {
      top = VIsual;
      bot = wp->w_cursor;
    } else {
      top = wp->w_cursor;
      bot = VIsual;
    }
    mode = VIsual_mode;
    curswant = wp->w_curswant;
  } else {
    if (lt(curbuf->b_visual.vi_start, curbuf->b_visual.vi_end)) {
      top = curbuf->b_visual.vi_start;
      bot = curbuf->b_visual.vi_end;
    } else {
      top = curbuf->b_visual.vi_end;
      bot = curbuf->b_visual.vi_start;
    }
    // a substitute command may have removed some lines
    if (bot.lnum > curbuf->b_ml.ml_line_count) {
      bot.lnum = curbuf->b_ml.ml_line_count;
    }
    mode = curbuf->b_visual.vi_mode;
    curswant = curbuf->b_visual.vi_curswant;
  }
  lnum = rex.lnum + rex.reg_firstlnum;
  if (lnum < top.lnum || lnum > bot.lnum) {
    return false;
  }

  col = (colnr_T)(rex.input - rex.line);
  if (mode == 'v') {
    if ((lnum == top.lnum && col < top.col)
        || (lnum == bot.lnum && col >= bot.col + (*p_sel != 'e'))) {
      return false;
    }
  } else if (mode == Ctrl_V) {
    getvvcol(wp, &top, &start, NULL, &end);
    getvvcol(wp, &bot, &start2, NULL, &end2);
    if (start2 < start) {
      start = start2;
    }
    if (end2 > end) {
      end = end2;
    }
    if (top.col == MAXCOL || bot.col == MAXCOL || curswant == MAXCOL) {
      end = MAXCOL;
    }

    // getvvcol() flushes rex.line, need to get it again
    rex.line = (uint8_t *)reg_getline(rex.lnum);
    rex.input = rex.line + col;

    colnr_T cols = win_linetabsize(wp, rex.reg_firstlnum + rex.lnum, (char *)rex.line, col);
    if (cols < start || cols > end - (*p_sel == 'e')) {
      return false;
    }
  }
  return true;
}

// Check the regexp program for its magic number.
// Return true if it's wrong.
static int prog_magic_wrong(void)
{
  regprog_T *prog;

  prog = REG_MULTI ? rex.reg_mmatch->regprog : rex.reg_match->regprog;
  if (prog->engine == &nfa_regengine) {
    // For NFA matcher we don't check the magic
    return false;
  }

  if (UCHARAT(((bt_regprog_T *)prog)->program) != REGMAGIC) {
    emsg(_(e_re_corr));
    return true;
  }
  return false;
}

// Cleanup the subexpressions, if this wasn't done yet.
// This construction is used to clear the subexpressions only when they are
// used (to increase speed).
static void cleanup_subexpr(void)
{
  if (!rex.need_clear_subexpr) {
    return;
  }

  if (REG_MULTI) {
    // Use 0xff to set lnum to -1
    memset(rex.reg_startpos, 0xff, sizeof(lpos_T) * NSUBEXP);
    memset(rex.reg_endpos, 0xff, sizeof(lpos_T) * NSUBEXP);
  } else {
    memset(rex.reg_startp, 0, sizeof(char *) * NSUBEXP);
    memset(rex.reg_endp, 0, sizeof(char *) * NSUBEXP);
  }
  rex.need_clear_subexpr = false;
}

static void cleanup_zsubexpr(void)
{
  if (!rex.need_clear_zsubexpr) {
    return;
  }

  if (REG_MULTI) {
    // Use 0xff to set lnum to -1
    memset(reg_startzpos, 0xff, sizeof(lpos_T) * NSUBEXP);
    memset(reg_endzpos, 0xff, sizeof(lpos_T) * NSUBEXP);
  } else {
    memset(reg_startzp, 0, sizeof(char *) * NSUBEXP);
    memset(reg_endzp, 0, sizeof(char *) * NSUBEXP);
  }
  rex.need_clear_zsubexpr = false;
}

// Advance rex.lnum, rex.line and rex.input to the next line.
static void reg_nextline(void)
{
  rex.line = (uint8_t *)reg_getline(++rex.lnum);
  rex.input = rex.line;
  reg_breakcheck();
}

// Check whether a backreference matches.
// Returns RA_FAIL, RA_NOMATCH or RA_MATCH.
// If "bytelen" is not NULL, it is set to the byte length of the match in the
// last line.
static int match_with_backref(linenr_T start_lnum, colnr_T start_col, linenr_T end_lnum,
                              colnr_T end_col, int *bytelen)
{
  linenr_T clnum = start_lnum;
  colnr_T ccol = start_col;
  int len;
  char *p;

  if (bytelen != NULL) {
    *bytelen = 0;
  }
  while (true) {
    // Since getting one line may invalidate the other, need to make copy.
    // Slow!
    if (rex.line != reg_tofree) {
      len = (int)strlen((char *)rex.line);
      if (reg_tofree == NULL || len >= (int)reg_tofreelen) {
        len += 50;              // get some extra
        xfree(reg_tofree);
        reg_tofree = xmalloc((size_t)len);
        reg_tofreelen = (unsigned)len;
      }
      STRCPY(reg_tofree, rex.line);
      rex.input = reg_tofree + (rex.input - rex.line);
      rex.line = reg_tofree;
    }

    // Get the line to compare with.
    p = reg_getline(clnum);
    assert(p);

    if (clnum == end_lnum) {
      len = end_col - ccol;
    } else {
      len = reg_getline_len(clnum) - ccol;
    }

    if (cstrncmp(p + ccol, (char *)rex.input, &len) != 0) {
      return RA_NOMATCH;  // doesn't match
    }
    if (bytelen != NULL) {
      *bytelen += len;
    }
    if (clnum == end_lnum) {
      break;  // match and at end!
    }
    if (rex.lnum >= rex.reg_maxline) {
      return RA_NOMATCH;  // text too short
    }

    // Advance to next line.
    reg_nextline();
    if (bytelen != NULL) {
      *bytelen = 0;
    }
    clnum++;
    ccol = 0;
    if (got_int) {
      return RA_FAIL;
    }
  }

  // found a match!  Note that rex.line may now point to a copy of the line,
  // that should not matter.
  return RA_MATCH;
}

/// Used in a place where no * or \+ can follow.
static bool re_mult_next(char *what)
{
  if (re_multi_type(peekchr()) == MULTI_MULT) {
    semsg(_("E888: (NFA regexp) cannot repeat %s"), what);
    rc_did_emsg = true;
    return false;
  }
  return true;
}

typedef struct {
  int a, b, c;
} decomp_T;

// 0xfb20 - 0xfb4f
static decomp_T decomp_table[0xfb4f - 0xfb20 + 1] = {
  { 0x5e2, 0, 0 },          // 0xfb20       alt ayin
  { 0x5d0, 0, 0 },          // 0xfb21       alt alef
  { 0x5d3, 0, 0 },          // 0xfb22       alt dalet
  { 0x5d4, 0, 0 },          // 0xfb23       alt he
  { 0x5db, 0, 0 },          // 0xfb24       alt kaf
  { 0x5dc, 0, 0 },          // 0xfb25       alt lamed
  { 0x5dd, 0, 0 },          // 0xfb26       alt mem-sofit
  { 0x5e8, 0, 0 },          // 0xfb27       alt resh
  { 0x5ea, 0, 0 },          // 0xfb28       alt tav
  { '+', 0, 0 },            // 0xfb29       alt plus
  { 0x5e9, 0x5c1, 0 },      // 0xfb2a       shin+shin-dot
  { 0x5e9, 0x5c2, 0 },      // 0xfb2b       shin+sin-dot
  { 0x5e9, 0x5c1, 0x5bc },  // 0xfb2c       shin+shin-dot+dagesh
  { 0x5e9, 0x5c2, 0x5bc },  // 0xfb2d       shin+sin-dot+dagesh
  { 0x5d0, 0x5b7, 0 },      // 0xfb2e       alef+patah
  { 0x5d0, 0x5b8, 0 },      // 0xfb2f       alef+qamats
  { 0x5d0, 0x5b4, 0 },      // 0xfb30       alef+hiriq
  { 0x5d1, 0x5bc, 0 },      // 0xfb31       bet+dagesh
  { 0x5d2, 0x5bc, 0 },      // 0xfb32       gimel+dagesh
  { 0x5d3, 0x5bc, 0 },      // 0xfb33       dalet+dagesh
  { 0x5d4, 0x5bc, 0 },      // 0xfb34       he+dagesh
  { 0x5d5, 0x5bc, 0 },      // 0xfb35       vav+dagesh
  { 0x5d6, 0x5bc, 0 },      // 0xfb36       zayin+dagesh
  { 0xfb37, 0, 0 },         // 0xfb37 -- UNUSED
  { 0x5d8, 0x5bc, 0 },      // 0xfb38       tet+dagesh
  { 0x5d9, 0x5bc, 0 },      // 0xfb39       yud+dagesh
  { 0x5da, 0x5bc, 0 },      // 0xfb3a       kaf sofit+dagesh
  { 0x5db, 0x5bc, 0 },      // 0xfb3b       kaf+dagesh
  { 0x5dc, 0x5bc, 0 },      // 0xfb3c       lamed+dagesh
  { 0xfb3d, 0, 0 },         // 0xfb3d -- UNUSED
  { 0x5de, 0x5bc, 0 },      // 0xfb3e       mem+dagesh
  { 0xfb3f, 0, 0 },         // 0xfb3f -- UNUSED
  { 0x5e0, 0x5bc, 0 },      // 0xfb40       nun+dagesh
  { 0x5e1, 0x5bc, 0 },      // 0xfb41       samech+dagesh
  { 0xfb42, 0, 0 },         // 0xfb42 -- UNUSED
  { 0x5e3, 0x5bc, 0 },      // 0xfb43       pe sofit+dagesh
  { 0x5e4, 0x5bc, 0 },      // 0xfb44       pe+dagesh
  { 0xfb45, 0, 0 },         // 0xfb45 -- UNUSED
  { 0x5e6, 0x5bc, 0 },      // 0xfb46       tsadi+dagesh
  { 0x5e7, 0x5bc, 0 },      // 0xfb47       qof+dagesh
  { 0x5e8, 0x5bc, 0 },      // 0xfb48       resh+dagesh
  { 0x5e9, 0x5bc, 0 },      // 0xfb49       shin+dagesh
  { 0x5ea, 0x5bc, 0 },      // 0xfb4a       tav+dagesh
  { 0x5d5, 0x5b9, 0 },      // 0xfb4b       vav+holam
  { 0x5d1, 0x5bf, 0 },      // 0xfb4c       bet+rafe
  { 0x5db, 0x5bf, 0 },      // 0xfb4d       kaf+rafe
  { 0x5e4, 0x5bf, 0 },      // 0xfb4e       pe+rafe
  { 0x5d0, 0x5dc, 0 }       // 0xfb4f       alef-lamed
};

static void mb_decompose(int c, int *c1, int *c2, int *c3)
{
  decomp_T d;

  if (c >= 0xfb20 && c <= 0xfb4f) {
    d = decomp_table[c - 0xfb20];
    *c1 = d.a;
    *c2 = d.b;
    *c3 = d.c;
  } else {
    *c1 = c;
    *c2 = *c3 = 0;
  }
}

/// Compare two strings, ignore case if rex.reg_ic set.
/// Return 0 if strings match, non-zero otherwise.
/// Correct the length "*n" when composing characters are ignored
/// or when both utf codepoints are considered equal because of
/// case-folding but have different length (e.g. 's' and 'ſ')
static int cstrncmp(char *s1, char *s2, int *n)
{
  int result;

  if (!rex.reg_ic) {
    result = strncmp(s1, s2, (size_t)(*n));
  } else {
    char *p = s1;
    int n2 = 0;
    int n1 = *n;
    // count the number of characters for byte-length of s1
    while (n1 > 0 && *p != NUL) {
      n1 -= utfc_ptr2len(s1);
      MB_PTR_ADV(p);
      n2++;
    }
    // count the number of bytes to advance the same number of chars for s2
    p = s2;
    while (n2-- > 0 && *p != NUL) {
      MB_PTR_ADV(p);
    }

    n2 = (int)(p - s2);

    result = utf_strnicmp(s1, s2, (size_t)(*n), (size_t)n2);
    if (result == 0 && n2 < *n) {
      *n = n2;
    }
  }

  // if it failed and it's utf8 and we want to combineignore:
  if (result != 0 && rex.reg_icombine) {
    const char *str1, *str2;
    int c1, c2, c11, c12;
    int junk;

    // we have to handle the strcmp ourselves, since it is necessary to
    // deal with the composing characters by ignoring them:
    str1 = s1;
    str2 = s2;
    c1 = c2 = 0;
    while ((int)(str1 - s1) < *n) {
      c1 = mb_ptr2char_adv(&str1);
      c2 = mb_ptr2char_adv(&str2);

      // decompose the character if necessary, into 'base' characters
      // because I don't care about Arabic, I will hard-code the Hebrew
      // which I *do* care about!  So sue me...
      if (c1 != c2 && (!rex.reg_ic || utf_fold(c1) != utf_fold(c2))) {
        // decomposition necessary?
        mb_decompose(c1, &c11, &junk, &junk);
        mb_decompose(c2, &c12, &junk, &junk);
        c1 = c11;
        c2 = c12;
        if (c11 != c12 && (!rex.reg_ic || utf_fold(c11) != utf_fold(c12))) {
          break;
        }
      }
    }
    result = c2 - c1;
    if (result == 0) {
      *n = (int)(str2 - s2);
    }
  }

  return result;
}

/// Wrapper around strchr which accounts for case-insensitive searches and
/// non-ASCII characters.
///
/// This function is used a lot for simple searches, keep it fast!
///
/// @param  s  string to search
/// @param  c  character to find in @a s
///
/// @return  NULL if no match, otherwise pointer to the position in @a s
static inline char *cstrchr(const char *const s, const int c)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
  FUNC_ATTR_ALWAYS_INLINE
{
  if (!rex.reg_ic) {
    return vim_strchr(s, c);
  }

  int cc, lc;
  if (c > 0x80) {
    cc = utf_fold(c);
    lc = cc;
  } else if (ASCII_ISUPPER(c)) {
    cc = TOLOWER_ASC(c);
    lc = cc;
  } else if (ASCII_ISLOWER(c)) {
    cc = TOUPPER_ASC(c);
    lc = c;
  } else {
    return vim_strchr(s, c);
  }

  for (const char *p = s; *p != NUL; p += utfc_ptr2len(p)) {
    const int uc = utf_ptr2char(p);
    if (c > 0x80 || uc > 0x80) {
      // Do not match an illegal byte.  E.g. 0xff matches 0xc3 0xbf, not 0xff.
      // Compare with lower case of the character.
      if ((uc < 0x80 || uc != (uint8_t)(*p)) && utf_fold(uc) == lc) {
        return (char *)p;
      }
    } else if ((uint8_t)(*p) == c || (uint8_t)(*p) == cc) {
      return (char *)p;
    }
  }

  return NULL;
}

////////////////////////////////////////////////////////////////
//                    regsub stuff                            //
////////////////////////////////////////////////////////////////

static void do_upper(int *d, int c)
{
  *d = mb_toupper(c);
}

static void do_lower(int *d, int c)
{
  *d = mb_tolower(c);
}

/// regtilde(): Replace tildes in the pattern by the old pattern.
///
/// Short explanation of the tilde: It stands for the previous replacement
/// pattern.  If that previous pattern also contains a ~ we should go back a
/// step further...  But we insert the previous pattern into the current one
/// and remember that.
/// This still does not handle the case where "magic" changes.  So require the
/// user to keep his hands off of "magic".
///
/// The tildes are parsed once before the first call to vim_regsub().
char *regtilde(char *source, int magic, bool preview)
{
  char *newsub = source;
  size_t newsublen = 0;
  char tilde[3] = { '~', NUL, NUL };
  size_t tildelen = 1;
  bool error = false;

  if (!magic) {
    tilde[0] = '\\';
    tilde[1] = '~';
    tilde[2] = NUL;
    tildelen = 2;
  }

  char *p;
  for (p = newsub; *p; p++) {
    if (strncmp(p, tilde, tildelen) == 0) {
      size_t prefixlen = (size_t)(p - newsub);  // not including the tilde
      char *postfix = p + tildelen;
      size_t postfixlen;
      size_t tmpsublen;

      if (newsublen == 0) {
        newsublen = strlen(newsub);
      }
      newsublen -= tildelen;
      postfixlen = newsublen - prefixlen;
      tmpsublen = prefixlen + reg_prev_sublen + postfixlen;

      if (tmpsublen > 0 && reg_prev_sub != NULL) {
        // Avoid making the text longer than MAXCOL, it will cause
        // trouble at some point.
        if (tmpsublen > MAXCOL) {
          emsg(_(e_resulting_text_too_long));
          error = true;
          break;
        }

        char *tmpsub = xmalloc(tmpsublen + 1);
        // copy prefix
        memmove(tmpsub, newsub, prefixlen);
        // interpret tilde
        memmove(tmpsub + prefixlen, reg_prev_sub, reg_prev_sublen);
        // copy postfix
        STRCPY(tmpsub + prefixlen + reg_prev_sublen, postfix);

        if (newsub != source) {  // allocated newsub before
          xfree(newsub);
        }
        newsub = tmpsub;
        newsublen = tmpsublen;
        p = newsub + prefixlen + reg_prev_sublen;
      } else {
        memmove(p, postfix, postfixlen + 1);  // remove the tilde (+1 for the NUL)
      }
      p--;
    } else {
      if (*p == '\\' && p[1]) {  // skip escaped characters
        p++;
      }
      p += utfc_ptr2len(p) - 1;
    }
  }

  if (error) {
    if (newsub != source) {
      xfree(newsub);
    }
    return source;
  }

  // Only change reg_prev_sub when not previewing.
  if (!preview) {
    // Store a copy of newsub  in reg_prev_sub.  It is always allocated,
    // because recursive calls may make the returned string invalid.
    // Only store it if there something to store.
    newsublen = (size_t)(p - newsub);
    if (newsublen == 0) {
      XFREE_CLEAR(reg_prev_sub);
    } else {
      xfree(reg_prev_sub);
      reg_prev_sub = xstrnsave(newsub, newsublen);
    }
    reg_prev_sublen = newsublen;
  }

  return newsub;
}

/// Put the submatches in "argv[argskip]" which is a list passed into
/// call_func() by vim_regsub_both().
static int fill_submatch_list(int argc FUNC_ATTR_UNUSED, typval_T *argv, int argskip, ufunc_T *fp)
  FUNC_ATTR_NONNULL_ALL
{
  typval_T *listarg = argv + argskip;

  if (!fp->uf_varargs && fp->uf_args.ga_len <= argskip) {
    // called function doesn't take a submatches argument
    return argskip;
  }

  // Relies on sl_list to be the first item in staticList10_T.
  tv_list_init_static10((staticList10_T *)listarg->vval.v_list);

  // There are always 10 list items in staticList10_T.
  listitem_T *li = tv_list_first(listarg->vval.v_list);
  for (int i = 0; i < 10; i++) {
    char *s = rsm.sm_match->startp[i];
    if (s == NULL || rsm.sm_match->endp[i] == NULL) {
      s = NULL;
    } else {
      s = xstrnsave(s, (size_t)(rsm.sm_match->endp[i] - s));
    }
    TV_LIST_ITEM_TV(li)->v_type = VAR_STRING;
    TV_LIST_ITEM_TV(li)->vval.v_string = s;
    li = TV_LIST_ITEM_NEXT(argv->vval.v_list, li);
  }
  return argskip + 1;
}

static void clear_submatch_list(staticList10_T *sl)
{
  TV_LIST_ITER(&sl->sl_list, li, {
    xfree(TV_LIST_ITEM_TV(li)->vval.v_string);
  });
}

/// vim_regsub() - perform substitutions after a vim_regexec() or
/// vim_regexec_multi() match.
///
/// If "flags" has REGSUB_COPY really copy into "dest[destlen]".
/// Otherwise nothing is copied, only compute the length of the result.
///
/// If "flags" has REGSUB_MAGIC then behave like 'magic' is set.
///
/// If "flags" has REGSUB_BACKSLASH a backslash will be removed later, need to
/// double them to keep them, and insert a backslash before a CR to avoid it
/// being replaced with a line break later.
///
/// Note: The matched text must not change between the call of
/// vim_regexec()/vim_regexec_multi() and vim_regsub()!  It would make the back
/// references invalid!
///
/// Returns the size of the replacement, including terminating NUL.
int vim_regsub(regmatch_T *rmp, char *source, typval_T *expr, char *dest, int destlen, int flags)
{
  regexec_T rex_save;
  bool rex_in_use_save = rex_in_use;

  if (rex_in_use) {
    // Being called recursively, save the state.
    rex_save = rex;
  }
  rex_in_use = true;

  rex.reg_match = rmp;
  rex.reg_mmatch = NULL;
  rex.reg_maxline = 0;
  rex.reg_buf = curbuf;
  rex.reg_line_lbr = true;
  int result = vim_regsub_both(source, expr, dest, destlen, flags);

  rex_in_use = rex_in_use_save;
  if (rex_in_use) {
    rex = rex_save;
  }

  return result;
}

int vim_regsub_multi(regmmatch_T *rmp, linenr_T lnum, char *source, char *dest, int destlen,
                     int flags)
{
  regexec_T rex_save;
  bool rex_in_use_save = rex_in_use;

  if (rex_in_use) {
    // Being called recursively, save the state.
    rex_save = rex;
  }
  rex_in_use = true;

  rex.reg_match = NULL;
  rex.reg_mmatch = rmp;
  rex.reg_buf = curbuf;  // always works on the current buffer!
  rex.reg_firstlnum = lnum;
  rex.reg_maxline = curbuf->b_ml.ml_line_count - lnum;
  rex.reg_line_lbr = false;
  int result = vim_regsub_both(source, NULL, dest, destlen, flags);

  rex_in_use = rex_in_use_save;
  if (rex_in_use) {
    rex = rex_save;
  }

  return result;
}

// When nesting more than a couple levels it's probably a mistake.
#define MAX_REGSUB_NESTING 4
static char *eval_result[MAX_REGSUB_NESTING] = { NULL, NULL, NULL, NULL };

#if defined(EXITFREE)
void free_resub_eval_result(void)
{
  for (int i = 0; i < MAX_REGSUB_NESTING; i++) {
    XFREE_CLEAR(eval_result[i]);
  }
}
#endif

static int vim_regsub_both(char *source, typval_T *expr, char *dest, int destlen, int flags)
{
  char *src;
  char *dst;
  char *s;
  int c;
  int cc;
  int no = -1;
  fptr_T func_all = (fptr_T)NULL;
  fptr_T func_one = (fptr_T)NULL;
  linenr_T clnum = 0;           // init for GCC
  int len = 0;                  // init for GCC
  static int nesting = 0;
  bool copy = flags & REGSUB_COPY;

  // Be paranoid...
  if ((source == NULL && expr == NULL) || dest == NULL) {
    emsg(_(e_null));
    return 0;
  }
  if (prog_magic_wrong()) {
    return 0;
  }
  if (nesting == MAX_REGSUB_NESTING) {
    emsg(_(e_substitute_nesting_too_deep));
    return 0;
  }
  int nested = nesting;
  src = source;
  dst = dest;

  // When the substitute part starts with "\=" evaluate it as an expression.
  if (expr != NULL || (source[0] == '\\' && source[1] == '=')) {
    // To make sure that the length doesn't change between checking the
    // length and copying the string, and to speed up things, the
    // resulting string is saved from the call with
    // "flags & REGSUB_COPY" == 0 to the call with
    // "flags & REGSUB_COPY" != 0.
    if (copy) {
      if (eval_result[nested] != NULL) {
        size_t eval_len = strlen(eval_result[nested]);
        if (eval_len < (size_t)destlen) {
          STRCPY(dest, eval_result[nested]);
          dst += eval_len;
          XFREE_CLEAR(eval_result[nested]);
        }
      }
    } else {
      const bool prev_can_f_submatch = can_f_submatch;
      regsubmatch_T rsm_save;

      XFREE_CLEAR(eval_result[nested]);

      // The expression may contain substitute(), which calls us
      // recursively.  Make sure submatch() gets the text from the first
      // level.
      if (can_f_submatch) {
        rsm_save = rsm;
      }
      can_f_submatch = true;
      rsm.sm_match = rex.reg_match;
      rsm.sm_mmatch = rex.reg_mmatch;
      rsm.sm_firstlnum = rex.reg_firstlnum;
      rsm.sm_maxline = rex.reg_maxline;
      rsm.sm_line_lbr = rex.reg_line_lbr;

      // Although unlikely, it is possible that the expression invokes a
      // substitute command (it might fail, but still).  Therefore keep
      // an array of eval results.
      nesting++;

      if (expr != NULL) {
        typval_T argv[2];
        typval_T rettv;
        staticList10_T matchList = TV_LIST_STATIC10_INIT;
        rettv.v_type = VAR_STRING;
        rettv.vval.v_string = NULL;
        argv[0].v_type = VAR_LIST;
        argv[0].vval.v_list = &matchList.sl_list;
        funcexe_T funcexe = FUNCEXE_INIT;
        funcexe.fe_argv_func = fill_submatch_list;
        funcexe.fe_evaluate = true;
        if (expr->v_type == VAR_FUNC) {
          s = expr->vval.v_string;
          call_func(s, -1, &rettv, 1, argv, &funcexe);
        } else if (expr->v_type == VAR_PARTIAL) {
          partial_T *partial = expr->vval.v_partial;

          s = partial_name(partial);
          funcexe.fe_partial = partial;
          call_func(s, -1, &rettv, 1, argv, &funcexe);
        }
        if (tv_list_len(&matchList.sl_list) > 0) {
          // fill_submatch_list() was called.
          clear_submatch_list(&matchList);
        }
        if (rettv.v_type == VAR_UNKNOWN) {
          // something failed, no need to report another error
          eval_result[nested] = NULL;
        } else {
          char buf[NUMBUFLEN];
          eval_result[nested] = (char *)tv_get_string_buf_chk(&rettv, buf);
          if (eval_result[nested] != NULL) {
            eval_result[nested] = xstrdup(eval_result[nested]);
          }
        }
        tv_clear(&rettv);
      } else {
        eval_result[nested] = eval_to_string(source + 2, true, false);
      }
      nesting--;

      if (eval_result[nested] != NULL) {
        int had_backslash = false;

        for (s = eval_result[nested]; *s != NUL; MB_PTR_ADV(s)) {
          // Change NL to CR, so that it becomes a line break,
          // unless called from vim_regexec_nl().
          // Skip over a backslashed character.
          if (*s == NL && !rsm.sm_line_lbr) {
            *s = CAR;
          } else if (*s == '\\' && s[1] != NUL) {
            s++;
            // Change NL to CR here too, so that this works:
            // :s/abc\\\ndef/\="aaa\\\nbbb"/  on text:
            //   abc{backslash}
            //   def
            // Not when called from vim_regexec_nl().
            if (*s == NL && !rsm.sm_line_lbr) {
              *s = CAR;
            }
            had_backslash = true;
          }
        }
        if (had_backslash && (flags & REGSUB_BACKSLASH)) {
          // Backslashes will be consumed, need to double them.
          s = vim_strsave_escaped(eval_result[nested], "\\");
          xfree(eval_result[nested]);
          eval_result[nested] = s;
        }

        dst += strlen(eval_result[nested]);
      }

      can_f_submatch = prev_can_f_submatch;
      if (can_f_submatch) {
        rsm = rsm_save;
      }
    }
  } else {
    while ((c = (uint8_t)(*src++)) != NUL) {
      if (c == '&' && (flags & REGSUB_MAGIC)) {
        no = 0;
      } else if (c == '\\' && *src != NUL) {
        if (*src == '&' && !(flags & REGSUB_MAGIC)) {
          src++;
          no = 0;
        } else if ('0' <= *src && *src <= '9') {
          no = *src++ - '0';
        } else if (vim_strchr("uUlLeE", (uint8_t)(*src))) {
          switch (*src++) {
          case 'u':
            func_one = do_upper;
            continue;
          case 'U':
            func_all = do_upper;
            continue;
          case 'l':
            func_one = do_lower;
            continue;
          case 'L':
            func_all = do_lower;
            continue;
          case 'e':
          case 'E':
            func_one = func_all = (fptr_T)NULL;
            continue;
          }
        }
      }
      if (no < 0) {           // Ordinary character.
        if (c == K_SPECIAL && src[0] != NUL && src[1] != NUL) {
          // Copy a special key as-is.
          if (copy) {
            if (dst + 3 > dest + destlen) {
              iemsg("vim_regsub_both(): not enough space");
              return 0;
            }
            *dst++ = (char)c;
            *dst++ = *src++;
            *dst++ = *src++;
          } else {
            dst += 3;
            src += 2;
          }
          continue;
        }

        if (c == '\\' && *src != NUL) {
          // Check for abbreviations -- webb
          switch (*src) {
          case 'r':
            c = CAR;        ++src;  break;
          case 'n':
            c = NL;         ++src;  break;
          case 't':
            c = TAB;        ++src;  break;
          // Oh no!  \e already has meaning in subst pat :-(
          // case 'e':   c = ESC;        ++src;  break;
          case 'b':
            c = Ctrl_H;     ++src;  break;

          // If "backslash" is true the backslash will be removed
          // later.  Used to insert a literal CR.
          default:
            if (flags & REGSUB_BACKSLASH) {
              if (copy) {
                if (dst + 1 > dest + destlen) {
                  iemsg("vim_regsub_both(): not enough space");
                  return 0;
                }
                *dst = '\\';
              }
              dst++;
            }
            c = (uint8_t)(*src++);
          }
        } else {
          c = utf_ptr2char(src - 1);
        }

        // Write to buffer, if copy is set.
        if (func_one != NULL) {
          func_one(&cc, c);
          func_one = NULL;
        } else if (func_all != NULL) {
          func_all(&cc, c);
        } else {
          // just copy
          cc = c;
        }

        int totlen = utfc_ptr2len(src - 1);
        int charlen = utf_char2len(cc);

        if (copy) {
          if (dst + charlen > dest + destlen) {
            iemsg("vim_regsub_both(): not enough space");
            return 0;
          }
          utf_char2bytes(cc, dst);
        }
        dst += charlen - 1;
        int clen = utf_ptr2len(src - 1);

        // If the character length is shorter than "totlen", there
        // are composing characters; copy them as-is.
        if (clen < totlen) {
          if (copy) {
            if (dst + totlen - clen > dest + destlen) {
              iemsg("vim_regsub_both(): not enough space");
              return 0;
            }
            memmove(dst + 1, src - 1 + clen, (size_t)(totlen - clen));
          }
          dst += totlen - clen;
        }
        src += totlen - 1;
        dst++;
      } else {
        if (REG_MULTI) {
          clnum = rex.reg_mmatch->startpos[no].lnum;
          if (clnum < 0 || rex.reg_mmatch->endpos[no].lnum < 0) {
            s = NULL;
          } else {
            s = reg_getline(clnum) + rex.reg_mmatch->startpos[no].col;
            if (rex.reg_mmatch->endpos[no].lnum == clnum) {
              len = rex.reg_mmatch->endpos[no].col
                    - rex.reg_mmatch->startpos[no].col;
            } else {
              len = reg_getline_len(clnum) - rex.reg_mmatch->startpos[no].col;
            }
          }
        } else {
          s = rex.reg_match->startp[no];
          if (rex.reg_match->endp[no] == NULL) {
            s = NULL;
          } else {
            len = (int)(rex.reg_match->endp[no] - s);
          }
        }
        if (s != NULL) {
          while (true) {
            if (len == 0) {
              if (REG_MULTI) {
                if (rex.reg_mmatch->endpos[no].lnum == clnum) {
                  break;
                }
                if (copy) {
                  if (dst + 1 > dest + destlen) {
                    iemsg("vim_regsub_both(): not enough space");
                    return 0;
                  }
                  *dst = CAR;
                }
                dst++;
                s = reg_getline(++clnum);
                if (rex.reg_mmatch->endpos[no].lnum == clnum) {
                  len = rex.reg_mmatch->endpos[no].col;
                } else {
                  len = reg_getline_len(clnum);
                }
              } else {
                break;
              }
            } else if (*s == NUL) {  // we hit NUL.
              if (copy) {
                iemsg(_(e_re_damg));
              }
              goto exit;
            } else {
              if ((flags & REGSUB_BACKSLASH) && (*s == CAR || *s == '\\')) {
                // Insert a backslash in front of a CR, otherwise
                // it will be replaced by a line break.
                // Number of backslashes will be halved later,
                // double them here.
                if (copy) {
                  if (dst + 2 > dest + destlen) {
                    iemsg("vim_regsub_both(): not enough space");
                    return 0;
                  }
                  dst[0] = '\\';
                  dst[1] = *s;
                }
                dst += 2;
              } else {
                c = utf_ptr2char(s);

                if (func_one != (fptr_T)NULL) {
                  func_one(&cc, c);
                  func_one = NULL;
                } else if (func_all != (fptr_T)NULL) {
                  func_all(&cc, c);
                } else {  // just copy
                  cc = c;
                }

                {
                  int l;
                  int charlen;

                  // Copy composing characters separately, one
                  // at a time.
                  l = utf_ptr2len(s) - 1;

                  s += l;
                  len -= l;
                  charlen = utf_char2len(cc);
                  if (copy) {
                    if (dst + charlen > dest + destlen) {
                      iemsg("vim_regsub_both(): not enough space");
                      return 0;
                    }
                    utf_char2bytes(cc, dst);
                  }
                  dst += charlen - 1;
                }
                dst++;
              }

              s++;
              len--;
            }
          }
        }
        no = -1;
      }
    }
  }
  if (copy) {
    *dst = NUL;
  }

exit:
  return (int)((dst - dest) + 1);
}

static char *reg_getline_submatch(linenr_T lnum)
{
  char *line;
  reg_getline_common(lnum, RGLF_LINE | RGLF_SUBMATCH, &line, NULL);
  return line;
}

static colnr_T reg_getline_submatch_len(linenr_T lnum)
{
  colnr_T length;
  reg_getline_common(lnum, RGLF_LENGTH | RGLF_SUBMATCH, NULL, &length);
  return length;
}

/// Used for the submatch() function: get the string from the n'th submatch in
/// allocated memory.
///
/// @return  NULL when not in a ":s" command and for a non-existing submatch.
char *reg_submatch(int no)
{
  char *retval = NULL;
  char *s;
  int round;
  linenr_T lnum;

  if (!can_f_submatch || no < 0) {
    return NULL;
  }

  if (rsm.sm_match == NULL) {
    ssize_t len;

    // First round: compute the length and allocate memory.
    // Second round: copy the text.
    for (round = 1; round <= 2; round++) {
      lnum = rsm.sm_mmatch->startpos[no].lnum;
      if (lnum < 0 || rsm.sm_mmatch->endpos[no].lnum < 0) {
        return NULL;
      }

      s = reg_getline_submatch(lnum);
      if (s == NULL) {  // anti-crash check, cannot happen?
        break;
      }
      s += rsm.sm_mmatch->startpos[no].col;
      if (rsm.sm_mmatch->endpos[no].lnum == lnum) {
        // Within one line: take form start to end col.
        len = rsm.sm_mmatch->endpos[no].col - rsm.sm_mmatch->startpos[no].col;
        if (round == 2) {
          xmemcpyz(retval, s, (size_t)len);
        }
        len++;
      } else {
        // Multiple lines: take start line from start col, middle
        // lines completely and end line up to end col.
        len = reg_getline_submatch_len(lnum) - rsm.sm_mmatch->startpos[no].col;
        if (round == 2) {
          STRCPY(retval, s);
          retval[len] = '\n';
        }
        len++;
        lnum++;
        while (lnum < rsm.sm_mmatch->endpos[no].lnum) {
          s = reg_getline_submatch(lnum);
          if (round == 2) {
            STRCPY(retval + len, s);
          }
          len += reg_getline_submatch_len(lnum);
          if (round == 2) {
            retval[len] = '\n';
          }
          len++;
          lnum++;
        }
        if (round == 2) {
          strncpy(retval + len,  // NOLINT(runtime/printf)
                  reg_getline_submatch(lnum),
                  (size_t)rsm.sm_mmatch->endpos[no].col);
        }
        len += rsm.sm_mmatch->endpos[no].col;
        if (round == 2) {
          retval[len] = NUL;
        }
        len++;
      }

      if (retval == NULL) {
        retval = xmalloc((size_t)len);
      }
    }
  } else {
    s = rsm.sm_match->startp[no];
    if (s == NULL || rsm.sm_match->endp[no] == NULL) {
      retval = NULL;
    } else {
      retval = xstrnsave(s, (size_t)(rsm.sm_match->endp[no] - s));
    }
  }

  return retval;
}

// Used for the submatch() function with the optional non-zero argument: get
// the list of strings from the n'th submatch in allocated memory with NULs
// represented in NLs.
// Returns a list of allocated strings.  Returns NULL when not in a ":s"
// command, for a non-existing submatch and for any error.
list_T *reg_submatch_list(int no)
{
  if (!can_f_submatch || no < 0) {
    return NULL;
  }

  linenr_T slnum;
  linenr_T elnum;
  list_T *list;
  const char *s;

  if (rsm.sm_match == NULL) {
    slnum = rsm.sm_mmatch->startpos[no].lnum;
    elnum = rsm.sm_mmatch->endpos[no].lnum;
    if (slnum < 0 || elnum < 0) {
      return NULL;
    }

    colnr_T scol = rsm.sm_mmatch->startpos[no].col;
    colnr_T ecol = rsm.sm_mmatch->endpos[no].col;

    list = tv_list_alloc(elnum - slnum + 1);

    s = reg_getline_submatch(slnum) + scol;
    if (slnum == elnum) {
      tv_list_append_string(list, s, ecol - scol);
    } else {
      int max_lnum = elnum - slnum;
      tv_list_append_string(list, s, -1);
      for (int i = 1; i < max_lnum; i++) {
        s = reg_getline_submatch(slnum + i);
        tv_list_append_string(list, s, -1);
      }
      s = reg_getline_submatch(elnum);
      tv_list_append_string(list, s, ecol);
    }
  } else {
    s = rsm.sm_match->startp[no];
    if (s == NULL || rsm.sm_match->endp[no] == NULL) {
      return NULL;
    }
    list = tv_list_alloc(1);
    tv_list_append_string(list, s, rsm.sm_match->endp[no] - s);
  }

  tv_list_ref(list);
  return list;
}

/// Initialize the values used for matching against multiple lines
///
/// @param win   window in which to search or NULL
/// @param buf   buffer in which to search
/// @param lnum  nr of line to start looking for match
static void init_regexec_multi(regmmatch_T *rmp, win_T *win, buf_T *buf, linenr_T lnum)
{
  rex.reg_match = NULL;
  rex.reg_mmatch = rmp;
  rex.reg_buf = buf;
  rex.reg_win = win;
  rex.reg_firstlnum = lnum;
  rex.reg_maxline = rex.reg_buf->b_ml.ml_line_count - lnum;
  rex.reg_line_lbr = false;
  rex.reg_ic = rmp->rmm_ic;
  rex.reg_icombine = false;
  rex.reg_nobreak = rmp->regprog->re_flags & RE_NOBREAK;
  rex.reg_maxcol = rmp->rmm_maxcol;
}

// regexp_bt.c {{{1

// Backtracking regular expression implementation.
//
// NOTICE:
//
// This is NOT the original regular expression code as written by Henry
// Spencer.  This code has been modified specifically for use with the VIM
// editor, and should not be used separately from Vim.  If you want a good
// regular expression library, get the original code.  The copyright notice
// that follows is from the original.
//
// END NOTICE
//
//      Copyright (c) 1986 by University of Toronto.
//      Written by Henry Spencer.  Not derived from licensed software.
//
//      Permission is granted to anyone to use this software for any
//      purpose on any computer system, and to redistribute it freely,
//      subject to the following restrictions:
//
//      1. The author is not responsible for the consequences of use of
//              this software, no matter how awful, even if they arise
//              from defects in it.
//
//      2. The origin of this software must not be misrepresented, either
//              by explicit claim or by omission.
//
//      3. Altered versions must be plainly marked as such, and must not
//              be misrepresented as being the original software.
//
// Beware that some of this code is subtly aware of the way operator
// precedence is structured in regular expressions.  Serious changes in
// regular-expression syntax might require a total rethink.
//
// Changes have been made by Tony Andrews, Olaf 'Rhialto' Seibert, Robert
// Webb, Ciaran McCreesh and Bram Moolenaar.
// Named character class support added by Walter Briscoe (1998 Jul 01)

// The "internal use only" fields in regexp_defs.h are present to pass info from
// compile to execute that permits the execute phase to run lots faster on
// simple cases.  They are:
//
// regstart     char that must begin a match; NUL if none obvious; Can be a
//              multi-byte character.
// reganch      is the match anchored (at beginning-of-line only)?
// regmust      string (pointer into program) that match must include, or NULL
// regmlen      length of regmust string
// regflags     RF_ values or'ed together
//
// Regstart and reganch permit very fast decisions on suitable starting points
// for a match, cutting down the work a lot.  Regmust permits fast rejection
// of lines that cannot possibly match.  The regmust tests are costly enough
// that vim_regcomp() supplies a regmust only if the r.e. contains something
// potentially expensive (at present, the only such thing detected is * or +
// at the start of the r.e., which can involve a lot of backup).  Regmlen is
// supplied because the test in vim_regexec() needs it and vim_regcomp() is
// computing it anyway.

// Structure for regexp "program".  This is essentially a linear encoding
// of a nondeterministic finite-state machine (aka syntax charts or
// "railroad normal form" in parsing technology).  Each node is an opcode
// plus a "next" pointer, possibly plus an operand.  "Next" pointers of
// all nodes except BRANCH and BRACES_COMPLEX implement concatenation; a "next"
// pointer with a BRANCH on both ends of it is connecting two alternatives.
// (Here we have one of the subtle syntax dependencies: an individual BRANCH
// (as opposed to a collection of them) is never concatenated with anything
// because of operator precedence).  The "next" pointer of a BRACES_COMPLEX
// node points to the node after the stuff to be repeated.
// The operand of some types of node is a literal string; for others, it is a
// node leading into a sub-FSM.  In particular, the operand of a BRANCH node
// is the first node of the branch.
// (NB this is *not* a tree structure: the tail of the branch connects to the
// thing following the set of BRANCHes.)
//
// pattern      is coded like:
//
//                        +-----------------+
//                        |                 V
// <aa>\|<bb>   BRANCH <aa> BRANCH <bb> --> END
//                   |      ^    |          ^
//                   +------+    +----------+
//
//
//                     +------------------+
//                     V                  |
// <aa>*        BRANCH BRANCH <aa> --> BACK BRANCH --> NOTHING --> END
//                   |      |               ^                      ^
//                   |      +---------------+                      |
//                   +---------------------------------------------+
//
//
//                     +----------------------+
//                     V                      |
// <aa>\+       BRANCH <aa> --> BRANCH --> BACK  BRANCH --> NOTHING --> END
//                   |               |           ^                      ^
//                   |               +-----------+                      |
//                   +--------------------------------------------------+
//
//
//                                      +-------------------------+
//                                      V                         |
// <aa>\{}      BRANCH BRACE_LIMITS --> BRACE_COMPLEX <aa> --> BACK  END
//                   |                              |                ^
//                   |                              +----------------+
//                   +-----------------------------------------------+
//
//
// <aa>\@!<bb>  BRANCH NOMATCH <aa> --> END  <bb> --> END
//                   |       |                ^       ^
//                   |       +----------------+       |
//                   +--------------------------------+
//
//                                                    +---------+
//                                                    |         V
// \z[abc]      BRANCH BRANCH  a  BRANCH  b  BRANCH  c  BRANCH  NOTHING --> END
//                   |      |          |          |     ^                   ^
//                   |      |          |          +-----+                   |
//                   |      |          +----------------+                   |
//                   |      +---------------------------+                   |
//                   +------------------------------------------------------+
//
// They all start with a BRANCH for "\|" alternatives, even when there is only
// one alternative.

// The opcodes are:

// definition   number             opnd?    meaning
#define END             0       //      End of program or NOMATCH operand.
#define BOL             1       //      Match "" at beginning of line.
#define EOL             2       //      Match "" at end of line.
#define BRANCH          3       // node Match this alternative, or the
                                //      next...
#define BACK            4       //      Match "", "next" ptr points backward.
#define EXACTLY         5       // str  Match this string.
#define NOTHING         6       //      Match empty string.
#define STAR            7       // node Match this (simple) thing 0 or more
                                //      times.
#define PLUS            8       // node Match this (simple) thing 1 or more
                                //      times.
#define MATCH           9       // node match the operand zero-width
#define NOMATCH         10      // node check for no match with operand
#define BEHIND          11      // node look behind for a match with operand
#define NOBEHIND        12      // node look behind for no match with operand
#define SUBPAT          13      // node match the operand here
#define BRACE_SIMPLE    14      // node Match this (simple) thing between m and
                                //      n times (\{m,n\}).
#define BOW             15      //      Match "" after [^a-zA-Z0-9_]
#define EOW             16      //      Match "" at    [^a-zA-Z0-9_]
#define BRACE_LIMITS    17      // nr nr  define the min & max for BRACE_SIMPLE
                                //      and BRACE_COMPLEX.
#define NEWL            18      //      Match line-break
#define BHPOS           19      //      End position for BEHIND or NOBEHIND

// character classes: 20-48 normal, 50-78 include a line-break
#define ADD_NL          30
#define FIRST_NL        ANY + ADD_NL
#define ANY             20      //      Match any one character.
#define ANYOF           21      // str  Match any character in this string.
#define ANYBUT          22      // str  Match any character not in this
                                //      string.
#define IDENT           23      //      Match identifier char
#define SIDENT          24      //      Match identifier char but no digit
#define KWORD           25      //      Match keyword char
#define SKWORD          26      //      Match word char but no digit
#define FNAME           27      //      Match file name char
#define SFNAME          28      //      Match file name char but no digit
#define PRINT           29      //      Match printable char
#define SPRINT          30      //      Match printable char but no digit
#define WHITE           31      //      Match whitespace char
#define NWHITE          32      //      Match non-whitespace char
#define DIGIT           33      //      Match digit char
#define NDIGIT          34      //      Match non-digit char
#define HEX             35      //      Match hex char
#define NHEX            36      //      Match non-hex char
#define OCTAL           37      //      Match octal char
#define NOCTAL          38      //      Match non-octal char
#define WORD            39      //      Match word char
#define NWORD           40      //      Match non-word char
#define HEAD            41      //      Match head char
#define NHEAD           42      //      Match non-head char
#define ALPHA           43      //      Match alpha char
#define NALPHA          44      //      Match non-alpha char
#define LOWER           45      //      Match lowercase char
#define NLOWER          46      //      Match non-lowercase char
#define UPPER           47      //      Match uppercase char
#define NUPPER          48      //      Match non-uppercase char
#define LAST_NL         NUPPER + ADD_NL
#define WITH_NL(op)     ((op) >= FIRST_NL && (op) <= LAST_NL)

#define MOPEN           80   // -89 Mark this point in input as start of
                             //     \( … \) subexpr.  MOPEN + 0 marks start of
                             //     match.
#define MCLOSE          90   // -99 Analogous to MOPEN.  MCLOSE + 0 marks
                             //     end of match.
#define BACKREF         100  // -109 node Match same string again \1-\9.

#define ZOPEN          110  // -119 Mark this point in input as start of
                            //  \z( … \) subexpr.
#define ZCLOSE         120  // -129 Analogous to ZOPEN.
#define ZREF           130  // -139 node Match external submatch \z1-\z9

#define BRACE_COMPLEX   140  // -149 node Match nodes between m & n times

#define NOPEN           150     // Mark this point in input as start of
                                // \%( subexpr.
#define NCLOSE          151     // Analogous to NOPEN.

#define MULTIBYTECODE   200     // mbc  Match one multi-byte character
#define RE_BOF          201     //      Match "" at beginning of file.
#define RE_EOF          202     //      Match "" at end of file.
#define CURSOR          203     //      Match location of cursor.

#define RE_LNUM         204     // nr cmp  Match line number
#define RE_COL          205     // nr cmp  Match column number
#define RE_VCOL         206     // nr cmp  Match virtual column number

#define RE_MARK         207     // mark cmp  Match mark position
#define RE_VISUAL       208     //      Match Visual area
#define RE_COMPOSING    209     // any composing characters

// Flags to be passed up and down.
#define HASWIDTH        0x1     // Known never to match null string.
#define SIMPLE          0x2     // Simple enough to be STAR/PLUS operand.
#define SPSTART         0x4     // Starts with * or +.
#define HASNL           0x8     // Contains some \n.
#define HASLOOKBH       0x10    // Contains "\@<=" or "\@<!".
#define WORST           0       // Worst case.

static int prevchr_len;         ///< byte length of previous char
static int num_complex_braces;  ///< Complex \{...} count
static uint8_t *regcode;         ///< Code-emit pointer, or JUST_CALC_SIZE
static int64_t regsize;            ///< Code size.
static int reg_toolong;         ///< true when offset out of range
static uint8_t had_endbrace[NSUBEXP];  ///< flags, true if end of () found
static int64_t brace_min[10];        ///< Minimums for complex brace repeats
static int64_t brace_max[10];        ///< Maximums for complex brace repeats
static int brace_count[10];       ///< Current counts for complex brace repeats
static int one_exactly = false;   ///< only do one char for EXACTLY

// When making changes to classchars also change nfa_classcodes.
static uint8_t *classchars = (uint8_t *)".iIkKfFpPsSdDxXoOwWhHaAlLuU";
static int classcodes[] = {
  ANY, IDENT, SIDENT, KWORD, SKWORD,
  FNAME, SFNAME, PRINT, SPRINT,
  WHITE, NWHITE, DIGIT, NDIGIT,
  HEX, NHEX, OCTAL, NOCTAL,
  WORD, NWORD, HEAD, NHEAD,
  ALPHA, NALPHA, LOWER, NLOWER,
  UPPER, NUPPER
};

// When regcode is set to this value, code is not emitted and size is computed
// instead.
#define JUST_CALC_SIZE  ((uint8_t *)-1)

// used for STAR, PLUS and BRACE_SIMPLE matching
typedef struct regstar_S {
  int nextb;            // next byte
  int nextb_ic;         // next byte reverse case
  int64_t count;
  int64_t minval;
  int64_t maxval;
} regstar_T;

// used to store input position when a BACK was encountered, so that we now if
// we made any progress since the last time.
typedef struct backpos_S {
  uint8_t *bp_scan;         // "scan" where BACK was encountered
  regsave_T bp_pos;           // last input position
} backpos_T;

// "regstack" and "backpos" are used by regmatch().  They are kept over calls
// to avoid invoking malloc() and free() often.
// "regstack" is a stack with regitem_T items, sometimes preceded by regstar_T
// or regbehind_T.
// "backpos_T" is a table with backpos_T for BACK
static garray_T regstack = GA_EMPTY_INIT_VALUE;
static garray_T backpos = GA_EMPTY_INIT_VALUE;

static regsave_T behind_pos;

// Both for regstack and backpos tables we use the following strategy of
// allocation (to reduce malloc/free calls):
// - Initial size is fairly small.
// - When needed, the tables are grown bigger (8 times at first, double after
//   that).
// - After executing the match we free the memory only if the array has grown.
//   Thus the memory is kept allocated when it's at the initial size.
// This makes it fast while not keeping a lot of memory allocated.
// A three times speed increase was observed when using many simple patterns.
#define REGSTACK_INITIAL        2048
#define BACKPOS_INITIAL         64

// Opcode notes:
//
// BRANCH       The set of branches constituting a single choice are hooked
//              together with their "next" pointers, since precedence prevents
//              anything being concatenated to any individual branch.  The
//              "next" pointer of the last BRANCH in a choice points to the
//              thing following the whole choice.  This is also where the
//              final "next" pointer of each individual branch points; each
//              branch starts with the operand node of a BRANCH node.
//
// BACK         Normal "next" pointers all implicitly point forward; BACK
//              exists to make loop structures possible.
//
// STAR,PLUS    '=', and complex '*' and '+', are implemented as circular
//              BRANCH structures using BACK.  Simple cases (one character
//              per match) are implemented with STAR and PLUS for speed
//              and to minimize recursive plunges.
//
// BRACE_LIMITS This is always followed by a BRACE_SIMPLE or BRACE_COMPLEX
//              node, and defines the min and max limits to be used for that
//              node.
//
// MOPEN,MCLOSE ...are numbered at compile time.
// ZOPEN,ZCLOSE ...ditto
///
//
//
// A node is one char of opcode followed by two chars of "next" pointer.
// "Next" pointers are stored as two 8-bit bytes, high order first.  The
// value is a positive offset from the opcode of the node containing it.
// An operand, if any, simply follows the node.  (Note that much of the
// code generation knows about this implicit relationship.)
//
// Using two bytes for the "next" pointer is vast overkill for most things,
// but allows patterns to get big without disasters.
#define OP(p)           ((int)(*(p)))
#define NEXT(p)         (((*((p) + 1) & 0377) << 8) + (*((p) + 2) & 0377))
#define OPERAND(p)      ((p) + 3)
// Obtain an operand that was stored as four bytes, MSB first.
#define OPERAND_MIN(p)  (((int64_t)(p)[3] << 24) + ((int64_t)(p)[4] << 16) \
                         + ((int64_t)(p)[5] << 8) + (int64_t)(p)[6])
// Obtain a second operand stored as four bytes.
#define OPERAND_MAX(p)  OPERAND_MIN((p) + 4)
// Obtain a second single-byte operand stored after a four bytes operand.
#define OPERAND_CMP(p)  (p)[7]

static uint8_t *reg(int paren, int *flagp);

#ifdef BT_REGEXP_DUMP
static void     regdump(uint8_t *, bt_regprog_T *);
#endif

#ifdef REGEXP_DEBUG
static uint8_t *regprop(uint8_t *);

static int regnarrate = 0;
#endif

// Setup to parse the regexp.  Used once to get the length and once to do it.
static void regcomp_start(uint8_t *expr, int re_flags)                        // see vim_regcomp()
{
  initchr((char *)expr);
  if (re_flags & RE_MAGIC) {
    reg_magic = MAGIC_ON;
  } else {
    reg_magic = MAGIC_OFF;
  }
  reg_string = (re_flags & RE_STRING);
  reg_strict = (re_flags & RE_STRICT);
  get_cpo_flags();

  num_complex_braces = 0;
  regnpar = 1;
  CLEAR_FIELD(had_endbrace);
  regnzpar = 1;
  re_has_z = 0;
  regsize = 0L;
  reg_toolong = false;
  regflags = 0;
  had_eol = false;
}

// Return true if MULTIBYTECODE should be used instead of EXACTLY for
// character "c".
static bool use_multibytecode(int c)
{
  return utf_char2len(c) > 1
         && (re_multi_type(peekchr()) != NOT_MULTI
             || utf_iscomposing(c));
}

// Emit (if appropriate) a byte of code
static void regc(int b)
{
  if (regcode == JUST_CALC_SIZE) {
    regsize++;
  } else {
    *regcode++ = (uint8_t)b;
  }
}

// Emit (if appropriate) a multi-byte character of code
static void regmbc(int c)
{
  if (regcode == JUST_CALC_SIZE) {
    regsize += utf_char2len(c);
  } else {
    regcode += utf_char2bytes(c, (char *)regcode);
  }
}

// Produce the bytes for equivalence class "c".
// Currently only handles latin1, latin9 and utf-8.
// NOTE: When changing this function, also change nfa_emit_equi_class()
static void reg_equi_class(int c)
{
  {
    switch (c) {
    // Do not use '\300' style, it results in a negative number.
    case 'A':
    case 0xc0:
    case 0xc1:
    case 0xc2:
    case 0xc3:
    case 0xc4:
    case 0xc5:
    case 0x100:
    case 0x102:
    case 0x104:
    case 0x1cd:
    case 0x1de:
    case 0x1e0:
    case 0x1fa:
    case 0x202:
    case 0x226:
    case 0x23a:
    case 0x1e00:
    case 0x1ea0:
    case 0x1ea2:
    case 0x1ea4:
    case 0x1ea6:
    case 0x1ea8:
    case 0x1eaa:
    case 0x1eac:
    case 0x1eae:
    case 0x1eb0:
    case 0x1eb2:
    case 0x1eb4:
    case 0x1eb6:
      regmbc('A'); regmbc(0xc0); regmbc(0xc1); regmbc(0xc2);
      regmbc(0xc3); regmbc(0xc4); regmbc(0xc5);
      regmbc(0x100); regmbc(0x102); regmbc(0x104);
      regmbc(0x1cd); regmbc(0x1de); regmbc(0x1e0);
      regmbc(0x1fa); regmbc(0x202); regmbc(0x226);
      regmbc(0x23a); regmbc(0x1e00); regmbc(0x1ea0);
      regmbc(0x1ea2); regmbc(0x1ea4); regmbc(0x1ea6);
      regmbc(0x1ea8); regmbc(0x1eaa); regmbc(0x1eac);
      regmbc(0x1eae); regmbc(0x1eb0); regmbc(0x1eb2);
      regmbc(0x1eb4); regmbc(0x1eb6);
      return;
    case 'B':
    case 0x181:
    case 0x243:
    case 0x1e02:
    case 0x1e04:
    case 0x1e06:
      regmbc('B');
      regmbc(0x181); regmbc(0x243); regmbc(0x1e02);
      regmbc(0x1e04); regmbc(0x1e06);
      return;
    case 'C':
    case 0xc7:
    case 0x106:
    case 0x108:
    case 0x10a:
    case 0x10c:
    case 0x187:
    case 0x23b:
    case 0x1e08:
    case 0xa792:
      regmbc('C'); regmbc(0xc7);
      regmbc(0x106); regmbc(0x108); regmbc(0x10a);
      regmbc(0x10c); regmbc(0x187); regmbc(0x23b);
      regmbc(0x1e08); regmbc(0xa792);
      return;
    case 'D':
    case 0x10e:
    case 0x110:
    case 0x18a:
    case 0x1e0a:
    case 0x1e0c:
    case 0x1e0e:
    case 0x1e10:
    case 0x1e12:
      regmbc('D'); regmbc(0x10e); regmbc(0x110);
      regmbc(0x18a); regmbc(0x1e0a); regmbc(0x1e0c);
      regmbc(0x1e0e); regmbc(0x1e10); regmbc(0x1e12);
      return;
    case 'E':
    case 0xc8:
    case 0xc9:
    case 0xca:
    case 0xcb:
    case 0x112:
    case 0x114:
    case 0x116:
    case 0x118:
    case 0x11a:
    case 0x204:
    case 0x206:
    case 0x228:
    case 0x246:
    case 0x1e14:
    case 0x1e16:
    case 0x1e18:
    case 0x1e1a:
    case 0x1e1c:
    case 0x1eb8:
    case 0x1eba:
    case 0x1ebc:
    case 0x1ebe:
    case 0x1ec0:
    case 0x1ec2:
    case 0x1ec4:
    case 0x1ec6:
      regmbc('E'); regmbc(0xc8); regmbc(0xc9);
      regmbc(0xca); regmbc(0xcb); regmbc(0x112);
      regmbc(0x114); regmbc(0x116); regmbc(0x118);
      regmbc(0x11a); regmbc(0x204); regmbc(0x206);
      regmbc(0x228); regmbc(0x246); regmbc(0x1e14);
      regmbc(0x1e16); regmbc(0x1e18); regmbc(0x1e1a);
      regmbc(0x1e1c); regmbc(0x1eb8); regmbc(0x1eba);
      regmbc(0x1ebc); regmbc(0x1ebe); regmbc(0x1ec0);
      regmbc(0x1ec2); regmbc(0x1ec4); regmbc(0x1ec6);
      return;
    case 'F':
    case 0x191:
    case 0x1e1e:
    case 0xa798:
      regmbc('F'); regmbc(0x191); regmbc(0x1e1e);
      regmbc(0xa798);
      return;
    case 'G':
    case 0x11c:
    case 0x11e:
    case 0x120:
    case 0x122:
    case 0x193:
    case 0x1e4:
    case 0x1e6:
    case 0x1f4:
    case 0x1e20:
    case 0xa7a0:
      regmbc('G'); regmbc(0x11c); regmbc(0x11e);
      regmbc(0x120); regmbc(0x122); regmbc(0x193);
      regmbc(0x1e4); regmbc(0x1e6); regmbc(0x1f4);
      regmbc(0x1e20); regmbc(0xa7a0);
      return;
    case 'H':
    case 0x124:
    case 0x126:
    case 0x21e:
    case 0x1e22:
    case 0x1e24:
    case 0x1e26:
    case 0x1e28:
    case 0x1e2a:
    case 0x2c67:
      regmbc('H'); regmbc(0x124); regmbc(0x126);
      regmbc(0x21e); regmbc(0x1e22); regmbc(0x1e24);
      regmbc(0x1e26); regmbc(0x1e28); regmbc(0x1e2a);
      regmbc(0x2c67);
      return;
    case 'I':
    case 0xcc:
    case 0xcd:
    case 0xce:
    case 0xcf:
    case 0x128:
    case 0x12a:
    case 0x12c:
    case 0x12e:
    case 0x130:
    case 0x197:
    case 0x1cf:
    case 0x208:
    case 0x20a:
    case 0x1e2c:
    case 0x1e2e:
    case 0x1ec8:
    case 0x1eca:
      regmbc('I'); regmbc(0xcc); regmbc(0xcd);
      regmbc(0xce); regmbc(0xcf); regmbc(0x128);
      regmbc(0x12a); regmbc(0x12c); regmbc(0x12e);
      regmbc(0x130); regmbc(0x197); regmbc(0x1cf);
      regmbc(0x208); regmbc(0x20a); regmbc(0x1e2c);
      regmbc(0x1e2e); regmbc(0x1ec8); regmbc(0x1eca);
      return;
    case 'J':
    case 0x134:
    case 0x248:
      regmbc('J'); regmbc(0x134); regmbc(0x248);
      return;
    case 'K':
    case 0x136:
    case 0x198:
    case 0x1e8:
    case 0x1e30:
    case 0x1e32:
    case 0x1e34:
    case 0x2c69:
    case 0xa740:
      regmbc('K'); regmbc(0x136); regmbc(0x198);
      regmbc(0x1e8); regmbc(0x1e30); regmbc(0x1e32);
      regmbc(0x1e34); regmbc(0x2c69); regmbc(0xa740);
      return;
    case 'L':
    case 0x139:
    case 0x13b:
    case 0x13d:
    case 0x13f:
    case 0x141:
    case 0x23d:
    case 0x1e36:
    case 0x1e38:
    case 0x1e3a:
    case 0x1e3c:
    case 0x2c60:
      regmbc('L'); regmbc(0x139); regmbc(0x13b);
      regmbc(0x13d); regmbc(0x13f); regmbc(0x141);
      regmbc(0x23d); regmbc(0x1e36); regmbc(0x1e38);
      regmbc(0x1e3a); regmbc(0x1e3c); regmbc(0x2c60);
      return;
    case 'M':
    case 0x1e3e:
    case 0x1e40:
    case 0x1e42:
      regmbc('M'); regmbc(0x1e3e); regmbc(0x1e40);
      regmbc(0x1e42);
      return;
    case 'N':
    case 0xd1:
    case 0x143:
    case 0x145:
    case 0x147:
    case 0x1f8:
    case 0x1e44:
    case 0x1e46:
    case 0x1e48:
    case 0x1e4a:
    case 0xa7a4:
      regmbc('N'); regmbc(0xd1);
      regmbc(0x143); regmbc(0x145); regmbc(0x147);
      regmbc(0x1f8); regmbc(0x1e44); regmbc(0x1e46);
      regmbc(0x1e48); regmbc(0x1e4a); regmbc(0xa7a4);
      return;
    case 'O':
    case 0xd2:
    case 0xd3:
    case 0xd4:
    case 0xd5:
    case 0xd6:
    case 0xd8:
    case 0x14c:
    case 0x14e:
    case 0x150:
    case 0x19f:
    case 0x1a0:
    case 0x1d1:
    case 0x1ea:
    case 0x1ec:
    case 0x1fe:
    case 0x20c:
    case 0x20e:
    case 0x22a:
    case 0x22c:
    case 0x22e:
    case 0x230:
    case 0x1e4c:
    case 0x1e4e:
    case 0x1e50:
    case 0x1e52:
    case 0x1ecc:
    case 0x1ece:
    case 0x1ed0:
    case 0x1ed2:
    case 0x1ed4:
    case 0x1ed6:
    case 0x1ed8:
    case 0x1eda:
    case 0x1edc:
    case 0x1ede:
    case 0x1ee0:
    case 0x1ee2:
      regmbc('O'); regmbc(0xd2); regmbc(0xd3); regmbc(0xd4);
      regmbc(0xd5); regmbc(0xd6); regmbc(0xd8);
      regmbc(0x14c); regmbc(0x14e); regmbc(0x150);
      regmbc(0x19f); regmbc(0x1a0); regmbc(0x1d1);
      regmbc(0x1ea); regmbc(0x1ec); regmbc(0x1fe);
      regmbc(0x20c); regmbc(0x20e); regmbc(0x22a);
      regmbc(0x22c); regmbc(0x22e); regmbc(0x230);
      regmbc(0x1e4c); regmbc(0x1e4e); regmbc(0x1e50);
      regmbc(0x1e52); regmbc(0x1ecc); regmbc(0x1ece);
      regmbc(0x1ed0); regmbc(0x1ed2); regmbc(0x1ed4);
      regmbc(0x1ed6); regmbc(0x1ed8); regmbc(0x1eda);
      regmbc(0x1edc); regmbc(0x1ede); regmbc(0x1ee0);
      regmbc(0x1ee2);
      return;
    case 'P':
    case 0x1a4:
    case 0x1e54:
    case 0x1e56:
    case 0x2c63:
      regmbc('P'); regmbc(0x1a4); regmbc(0x1e54);
      regmbc(0x1e56); regmbc(0x2c63);
      return;
    case 'Q':
    case 0x24a:
      regmbc('Q'); regmbc(0x24a);
      return;
    case 'R':
    case 0x154:
    case 0x156:
    case 0x158:
    case 0x210:
    case 0x212:
    case 0x24c:
    case 0x1e58:
    case 0x1e5a:
    case 0x1e5c:
    case 0x1e5e:
    case 0x2c64:
    case 0xa7a6:
      regmbc('R'); regmbc(0x154); regmbc(0x156);
      regmbc(0x210); regmbc(0x212); regmbc(0x158);
      regmbc(0x24c); regmbc(0x1e58); regmbc(0x1e5a);
      regmbc(0x1e5c); regmbc(0x1e5e); regmbc(0x2c64);
      regmbc(0xa7a6);
      return;
    case 'S':
    case 0x15a:
    case 0x15c:
    case 0x15e:
    case 0x160:
    case 0x218:
    case 0x1e60:
    case 0x1e62:
    case 0x1e64:
    case 0x1e66:
    case 0x1e68:
    case 0x2c7e:
    case 0xa7a8:
      regmbc('S'); regmbc(0x15a); regmbc(0x15c);
      regmbc(0x15e); regmbc(0x160); regmbc(0x218);
      regmbc(0x1e60); regmbc(0x1e62); regmbc(0x1e64);
      regmbc(0x1e66); regmbc(0x1e68); regmbc(0x2c7e);
      regmbc(0xa7a8);
      return;
    case 'T':
    case 0x162:
    case 0x164:
    case 0x166:
    case 0x1ac:
    case 0x1ae:
    case 0x21a:
    case 0x23e:
    case 0x1e6a:
    case 0x1e6c:
    case 0x1e6e:
    case 0x1e70:
      regmbc('T'); regmbc(0x162); regmbc(0x164);
      regmbc(0x166); regmbc(0x1ac); regmbc(0x23e);
      regmbc(0x1ae); regmbc(0x21a); regmbc(0x1e6a);
      regmbc(0x1e6c); regmbc(0x1e6e); regmbc(0x1e70);
      return;
    case 'U':
    case 0xd9:
    case 0xda:
    case 0xdb:
    case 0xdc:
    case 0x168:
    case 0x16a:
    case 0x16c:
    case 0x16e:
    case 0x170:
    case 0x172:
    case 0x1af:
    case 0x1d3:
    case 0x1d5:
    case 0x1d7:
    case 0x1d9:
    case 0x1db:
    case 0x214:
    case 0x216:
    case 0x244:
    case 0x1e72:
    case 0x1e74:
    case 0x1e76:
    case 0x1e78:
    case 0x1e7a:
    case 0x1ee4:
    case 0x1ee6:
    case 0x1ee8:
    case 0x1eea:
    case 0x1eec:
    case 0x1eee:
    case 0x1ef0:
      regmbc('U'); regmbc(0xd9); regmbc(0xda);
      regmbc(0xdb); regmbc(0xdc); regmbc(0x168);
      regmbc(0x16a); regmbc(0x16c); regmbc(0x16e);
      regmbc(0x170); regmbc(0x172); regmbc(0x1af);
      regmbc(0x1d3); regmbc(0x1d5); regmbc(0x1d7);
      regmbc(0x1d9); regmbc(0x1db); regmbc(0x214);
      regmbc(0x216); regmbc(0x244); regmbc(0x1e72);
      regmbc(0x1e74); regmbc(0x1e76); regmbc(0x1e78);
      regmbc(0x1e7a); regmbc(0x1ee4); regmbc(0x1ee6);
      regmbc(0x1ee8); regmbc(0x1eea); regmbc(0x1eec);
      regmbc(0x1eee); regmbc(0x1ef0);
      return;
    case 'V':
    case 0x1b2:
    case 0x1e7c:
    case 0x1e7e:
      regmbc('V'); regmbc(0x1b2); regmbc(0x1e7c);
      regmbc(0x1e7e);
      return;
    case 'W':
    case 0x174:
    case 0x1e80:
    case 0x1e82:
    case 0x1e84:
    case 0x1e86:
    case 0x1e88:
      regmbc('W'); regmbc(0x174); regmbc(0x1e80);
      regmbc(0x1e82); regmbc(0x1e84); regmbc(0x1e86);
      regmbc(0x1e88);
      return;
    case 'X':
    case 0x1e8a:
    case 0x1e8c:
      regmbc('X'); regmbc(0x1e8a); regmbc(0x1e8c);
      return;
    case 'Y':
    case 0xdd:
    case 0x176:
    case 0x178:
    case 0x1b3:
    case 0x232:
    case 0x24e:
    case 0x1e8e:
    case 0x1ef2:
    case 0x1ef6:
    case 0x1ef4:
    case 0x1ef8:
      regmbc('Y'); regmbc(0xdd); regmbc(0x176);
      regmbc(0x178); regmbc(0x1b3); regmbc(0x232);
      regmbc(0x24e); regmbc(0x1e8e); regmbc(0x1ef2);
      regmbc(0x1ef4); regmbc(0x1ef6); regmbc(0x1ef8);
      return;
    case 'Z':
    case 0x179:
    case 0x17b:
    case 0x17d:
    case 0x1b5:
    case 0x1e90:
    case 0x1e92:
    case 0x1e94:
    case 0x2c6b:
      regmbc('Z'); regmbc(0x179); regmbc(0x17b);
      regmbc(0x17d); regmbc(0x1b5); regmbc(0x1e90);
      regmbc(0x1e92); regmbc(0x1e94); regmbc(0x2c6b);
      return;
    case 'a':
    case 0xe0:
    case 0xe1:
    case 0xe2:
    case 0xe3:
    case 0xe4:
    case 0xe5:
    case 0x101:
    case 0x103:
    case 0x105:
    case 0x1ce:
    case 0x1df:
    case 0x1e1:
    case 0x1fb:
    case 0x201:
    case 0x203:
    case 0x227:
    case 0x1d8f:
    case 0x1e01:
    case 0x1e9a:
    case 0x1ea1:
    case 0x1ea3:
    case 0x1ea5:
    case 0x1ea7:
    case 0x1ea9:
    case 0x1eab:
    case 0x1ead:
    case 0x1eaf:
    case 0x1eb1:
    case 0x1eb3:
    case 0x1eb5:
    case 0x1eb7:
    case 0x2c65:
      regmbc('a'); regmbc(0xe0); regmbc(0xe1);
      regmbc(0xe2); regmbc(0xe3); regmbc(0xe4);
      regmbc(0xe5); regmbc(0x101); regmbc(0x103);
      regmbc(0x105); regmbc(0x1ce); regmbc(0x1df);
      regmbc(0x1e1); regmbc(0x1fb); regmbc(0x201);
      regmbc(0x203); regmbc(0x227); regmbc(0x1d8f);
      regmbc(0x1e01); regmbc(0x1e9a); regmbc(0x1ea1);
      regmbc(0x1ea3); regmbc(0x1ea5); regmbc(0x1ea7);
      regmbc(0x1ea9); regmbc(0x1eab); regmbc(0x1ead);
      regmbc(0x1eaf); regmbc(0x1eb1); regmbc(0x1eb3);
      regmbc(0x1eb5); regmbc(0x1eb7); regmbc(0x2c65);
      return;
    case 'b':
    case 0x180:
    case 0x253:
    case 0x1d6c:
    case 0x1d80:
    case 0x1e03:
    case 0x1e05:
    case 0x1e07:
      regmbc('b');
      regmbc(0x180); regmbc(0x253); regmbc(0x1d6c);
      regmbc(0x1d80); regmbc(0x1e03); regmbc(0x1e05);
      regmbc(0x1e07);
      return;
    case 'c':
    case 0xe7:
    case 0x107:
    case 0x109:
    case 0x10b:
    case 0x10d:
    case 0x188:
    case 0x23c:
    case 0x1e09:
    case 0xa793:
    case 0xa794:
      regmbc('c'); regmbc(0xe7); regmbc(0x107);
      regmbc(0x109); regmbc(0x10b); regmbc(0x10d);
      regmbc(0x188); regmbc(0x23c); regmbc(0x1e09);
      regmbc(0xa793); regmbc(0xa794);
      return;
    case 'd':
    case 0x10f:
    case 0x111:
    case 0x257:
    case 0x1d6d:
    case 0x1d81:
    case 0x1d91:
    case 0x1e0b:
    case 0x1e0d:
    case 0x1e0f:
    case 0x1e11:
    case 0x1e13:
      regmbc('d'); regmbc(0x10f); regmbc(0x111);
      regmbc(0x257); regmbc(0x1d6d); regmbc(0x1d81);
      regmbc(0x1d91); regmbc(0x1e0b); regmbc(0x1e0d);
      regmbc(0x1e0f); regmbc(0x1e11); regmbc(0x1e13);
      return;
    case 'e':
    case 0xe8:
    case 0xe9:
    case 0xea:
    case 0xeb:
    case 0x113:
    case 0x115:
    case 0x117:
    case 0x119:
    case 0x11b:
    case 0x205:
    case 0x207:
    case 0x229:
    case 0x247:
    case 0x1d92:
    case 0x1e15:
    case 0x1e17:
    case 0x1e19:
    case 0x1e1b:
    case 0x1eb9:
    case 0x1ebb:
    case 0x1e1d:
    case 0x1ebd:
    case 0x1ebf:
    case 0x1ec1:
    case 0x1ec3:
    case 0x1ec5:
    case 0x1ec7:
      regmbc('e'); regmbc(0xe8); regmbc(0xe9);
      regmbc(0xea); regmbc(0xeb); regmbc(0x113);
      regmbc(0x115); regmbc(0x117); regmbc(0x119);
      regmbc(0x11b); regmbc(0x205); regmbc(0x207);
      regmbc(0x229); regmbc(0x247); regmbc(0x1d92);
      regmbc(0x1e15); regmbc(0x1e17); regmbc(0x1e19);
      regmbc(0x1e1b); regmbc(0x1e1d); regmbc(0x1eb9);
      regmbc(0x1ebb); regmbc(0x1ebd); regmbc(0x1ebf);
      regmbc(0x1ec1); regmbc(0x1ec3); regmbc(0x1ec5);
      regmbc(0x1ec7);
      return;
    case 'f':
    case 0x192:
    case 0x1d6e:
    case 0x1d82:
    case 0x1e1f:
    case 0xa799:
      regmbc('f'); regmbc(0x192); regmbc(0x1d6e);
      regmbc(0x1d82); regmbc(0x1e1f); regmbc(0xa799);
      return;
    case 'g':
    case 0x11d:
    case 0x11f:
    case 0x121:
    case 0x123:
    case 0x1e5:
    case 0x1e7:
    case 0x260:
    case 0x1f5:
    case 0x1d83:
    case 0x1e21:
    case 0xa7a1:
      regmbc('g'); regmbc(0x11d); regmbc(0x11f);
      regmbc(0x121); regmbc(0x123); regmbc(0x1e5);
      regmbc(0x1e7); regmbc(0x1f5); regmbc(0x260);
      regmbc(0x1d83); regmbc(0x1e21); regmbc(0xa7a1);
      return;
    case 'h':
    case 0x125:
    case 0x127:
    case 0x21f:
    case 0x1e23:
    case 0x1e25:
    case 0x1e27:
    case 0x1e29:
    case 0x1e2b:
    case 0x1e96:
    case 0x2c68:
    case 0xa795:
      regmbc('h'); regmbc(0x125); regmbc(0x127);
      regmbc(0x21f); regmbc(0x1e23); regmbc(0x1e25);
      regmbc(0x1e27); regmbc(0x1e29); regmbc(0x1e2b);
      regmbc(0x1e96); regmbc(0x2c68); regmbc(0xa795);
      return;
    case 'i':
    case 0xec:
    case 0xed:
    case 0xee:
    case 0xef:
    case 0x129:
    case 0x12b:
    case 0x12d:
    case 0x12f:
    case 0x1d0:
    case 0x209:
    case 0x20b:
    case 0x268:
    case 0x1d96:
    case 0x1e2d:
    case 0x1e2f:
    case 0x1ec9:
    case 0x1ecb:
      regmbc('i'); regmbc(0xec); regmbc(0xed);
      regmbc(0xee); regmbc(0xef); regmbc(0x129);
      regmbc(0x12b); regmbc(0x12d); regmbc(0x12f);
      regmbc(0x1d0); regmbc(0x209); regmbc(0x20b);
      regmbc(0x268); regmbc(0x1d96); regmbc(0x1e2d);
      regmbc(0x1e2f); regmbc(0x1ec9); regmbc(0x1ecb);
      return;
    case 'j':
    case 0x135:
    case 0x1f0:
    case 0x249:
      regmbc('j'); regmbc(0x135); regmbc(0x1f0);
      regmbc(0x249);
      return;
    case 'k':
    case 0x137:
    case 0x199:
    case 0x1e9:
    case 0x1d84:
    case 0x1e31:
    case 0x1e33:
    case 0x1e35:
    case 0x2c6a:
    case 0xa741:
      regmbc('k'); regmbc(0x137); regmbc(0x199);
      regmbc(0x1e9); regmbc(0x1d84); regmbc(0x1e31);
      regmbc(0x1e33); regmbc(0x1e35); regmbc(0x2c6a);
      regmbc(0xa741);
      return;
    case 'l':
    case 0x13a:
    case 0x13c:
    case 0x13e:
    case 0x140:
    case 0x142:
    case 0x19a:
    case 0x1e37:
    case 0x1e39:
    case 0x1e3b:
    case 0x1e3d:
    case 0x2c61:
      regmbc('l'); regmbc(0x13a); regmbc(0x13c);
      regmbc(0x13e); regmbc(0x140); regmbc(0x142);
      regmbc(0x19a); regmbc(0x1e37); regmbc(0x1e39);
      regmbc(0x1e3b); regmbc(0x1e3d); regmbc(0x2c61);
      return;
    case 'm':
    case 0x1d6f:
    case 0x1e3f:
    case 0x1e41:
    case 0x1e43:
      regmbc('m'); regmbc(0x1d6f); regmbc(0x1e3f);
      regmbc(0x1e41); regmbc(0x1e43);
      return;
    case 'n':
    case 0xf1:
    case 0x144:
    case 0x146:
    case 0x148:
    case 0x149:
    case 0x1f9:
    case 0x1d70:
    case 0x1d87:
    case 0x1e45:
    case 0x1e47:
    case 0x1e49:
    case 0x1e4b:
    case 0xa7a5:
      regmbc('n'); regmbc(0xf1); regmbc(0x144);
      regmbc(0x146); regmbc(0x148); regmbc(0x149);
      regmbc(0x1f9); regmbc(0x1d70); regmbc(0x1d87);
      regmbc(0x1e45); regmbc(0x1e47); regmbc(0x1e49);
      regmbc(0x1e4b); regmbc(0xa7a5);
      return;
    case 'o':
    case 0xf2:
    case 0xf3:
    case 0xf4:
    case 0xf5:
    case 0xf6:
    case 0xf8:
    case 0x14d:
    case 0x14f:
    case 0x151:
    case 0x1a1:
    case 0x1d2:
    case 0x1eb:
    case 0x1ed:
    case 0x1ff:
    case 0x20d:
    case 0x20f:
    case 0x22b:
    case 0x22d:
    case 0x22f:
    case 0x231:
    case 0x275:
    case 0x1e4d:
    case 0x1e4f:
    case 0x1e51:
    case 0x1e53:
    case 0x1ecd:
    case 0x1ecf:
    case 0x1ed1:
    case 0x1ed3:
    case 0x1ed5:
    case 0x1ed7:
    case 0x1ed9:
    case 0x1edb:
    case 0x1edd:
    case 0x1edf:
    case 0x1ee1:
    case 0x1ee3:
      regmbc('o'); regmbc(0xf2); regmbc(0xf3);
      regmbc(0xf4); regmbc(0xf5); regmbc(0xf6);
      regmbc(0xf8); regmbc(0x14d); regmbc(0x14f);
      regmbc(0x151); regmbc(0x1a1); regmbc(0x1d2);
      regmbc(0x1eb); regmbc(0x1ed); regmbc(0x1ff);
      regmbc(0x20d); regmbc(0x20f); regmbc(0x22b);
      regmbc(0x22d); regmbc(0x22f); regmbc(0x231);
      regmbc(0x275); regmbc(0x1e4d); regmbc(0x1e4f);
      regmbc(0x1e51); regmbc(0x1e53); regmbc(0x1ecd);
      regmbc(0x1ecf); regmbc(0x1ed1); regmbc(0x1ed3);
      regmbc(0x1ed5); regmbc(0x1ed7); regmbc(0x1ed9);
      regmbc(0x1edb); regmbc(0x1edd); regmbc(0x1edf);
      regmbc(0x1ee1); regmbc(0x1ee3);
      return;
    case 'p':
    case 0x1a5:
    case 0x1d71:
    case 0x1d88:
    case 0x1d7d:
    case 0x1e55:
    case 0x1e57:
      regmbc('p'); regmbc(0x1a5); regmbc(0x1d71);
      regmbc(0x1d7d); regmbc(0x1d88); regmbc(0x1e55);
      regmbc(0x1e57);
      return;
    case 'q':
    case 0x24b:
    case 0x2a0:
      regmbc('q'); regmbc(0x24b); regmbc(0x2a0);
      return;
    case 'r':
    case 0x155:
    case 0x157:
    case 0x159:
    case 0x211:
    case 0x213:
    case 0x24d:
    case 0x27d:
    case 0x1d72:
    case 0x1d73:
    case 0x1d89:
    case 0x1e59:
    case 0x1e5b:
    case 0x1e5d:
    case 0x1e5f:
    case 0xa7a7:
      regmbc('r'); regmbc(0x155); regmbc(0x157);
      regmbc(0x159); regmbc(0x211); regmbc(0x213);
      regmbc(0x24d); regmbc(0x1d72); regmbc(0x1d73);
      regmbc(0x1d89); regmbc(0x1e59); regmbc(0x27d);
      regmbc(0x1e5b); regmbc(0x1e5d); regmbc(0x1e5f);
      regmbc(0xa7a7);
      return;
    case 's':
    case 0x15b:
    case 0x15d:
    case 0x15f:
    case 0x161:
    case 0x1e61:
    case 0x219:
    case 0x23f:
    case 0x1d74:
    case 0x1d8a:
    case 0x1e63:
    case 0x1e65:
    case 0x1e67:
    case 0x1e69:
    case 0xa7a9:
      regmbc('s'); regmbc(0x15b); regmbc(0x15d);
      regmbc(0x15f); regmbc(0x161); regmbc(0x23f);
      regmbc(0x219); regmbc(0x1d74); regmbc(0x1d8a);
      regmbc(0x1e61); regmbc(0x1e63); regmbc(0x1e65);
      regmbc(0x1e67); regmbc(0x1e69); regmbc(0xa7a9);
      return;
    case 't':
    case 0x163:
    case 0x165:
    case 0x167:
    case 0x1ab:
    case 0x1ad:
    case 0x21b:
    case 0x288:
    case 0x1d75:
    case 0x1e6b:
    case 0x1e6d:
    case 0x1e6f:
    case 0x1e71:
    case 0x1e97:
    case 0x2c66:
      regmbc('t'); regmbc(0x163); regmbc(0x165);
      regmbc(0x167); regmbc(0x1ab); regmbc(0x21b);
      regmbc(0x1ad); regmbc(0x288); regmbc(0x1d75);
      regmbc(0x1e6b); regmbc(0x1e6d); regmbc(0x1e6f);
      regmbc(0x1e71); regmbc(0x1e97); regmbc(0x2c66);
      return;
    case 'u':
    case 0xf9:
    case 0xfa:
    case 0xfb:
    case 0xfc:
    case 0x169:
    case 0x16b:
    case 0x16d:
    case 0x16f:
    case 0x171:
    case 0x173:
    case 0x1b0:
    case 0x1d4:
    case 0x1d6:
    case 0x1d8:
    case 0x1da:
    case 0x1dc:
    case 0x215:
    case 0x217:
    case 0x289:
    case 0x1e73:
    case 0x1d7e:
    case 0x1d99:
    case 0x1e75:
    case 0x1e77:
    case 0x1e79:
    case 0x1e7b:
    case 0x1ee5:
    case 0x1ee7:
    case 0x1ee9:
    case 0x1eeb:
    case 0x1eed:
    case 0x1eef:
    case 0x1ef1:
      regmbc('u'); regmbc(0xf9); regmbc(0xfa);
      regmbc(0xfb); regmbc(0xfc); regmbc(0x169);
      regmbc(0x16b); regmbc(0x16d); regmbc(0x16f);
      regmbc(0x171); regmbc(0x173); regmbc(0x1d6);
      regmbc(0x1d8); regmbc(0x1da); regmbc(0x1dc);
      regmbc(0x215); regmbc(0x217); regmbc(0x1b0);
      regmbc(0x1d4); regmbc(0x289); regmbc(0x1d7e);
      regmbc(0x1d99); regmbc(0x1e73); regmbc(0x1e75);
      regmbc(0x1e77); regmbc(0x1e79); regmbc(0x1e7b);
      regmbc(0x1ee5); regmbc(0x1ee7); regmbc(0x1ee9);
      regmbc(0x1eeb); regmbc(0x1eed); regmbc(0x1eef);
      regmbc(0x1ef1);
      return;
    case 'v':
    case 0x28b:
    case 0x1d8c:
    case 0x1e7d:
    case 0x1e7f:
      regmbc('v'); regmbc(0x28b); regmbc(0x1d8c);
      regmbc(0x1e7d); regmbc(0x1e7f);
      return;
    case 'w':
    case 0x175:
    case 0x1e81:
    case 0x1e83:
    case 0x1e85:
    case 0x1e87:
    case 0x1e89:
    case 0x1e98:
      regmbc('w'); regmbc(0x175); regmbc(0x1e81);
      regmbc(0x1e83); regmbc(0x1e85); regmbc(0x1e87);
      regmbc(0x1e89); regmbc(0x1e98);
      return;
    case 'x':
    case 0x1e8b:
    case 0x1e8d:
      regmbc('x'); regmbc(0x1e8b); regmbc(0x1e8d);
      return;
    case 'y':
    case 0xfd:
    case 0xff:
    case 0x177:
    case 0x1b4:
    case 0x233:
    case 0x24f:
    case 0x1e8f:
    case 0x1e99:
    case 0x1ef3:
    case 0x1ef5:
    case 0x1ef7:
    case 0x1ef9:
      regmbc('y'); regmbc(0xfd); regmbc(0xff);
      regmbc(0x177); regmbc(0x1b4); regmbc(0x233);
      regmbc(0x24f); regmbc(0x1e8f); regmbc(0x1e99);
      regmbc(0x1ef3); regmbc(0x1ef5); regmbc(0x1ef7);
      regmbc(0x1ef9);
      return;
    case 'z':
    case 0x17a:
    case 0x17c:
    case 0x17e:
    case 0x1b6:
    case 0x1d76:
    case 0x1d8e:
    case 0x1e91:
    case 0x1e93:
    case 0x1e95:
    case 0x2c6c:
      regmbc('z'); regmbc(0x17a); regmbc(0x17c);
      regmbc(0x17e); regmbc(0x1b6); regmbc(0x1d76);
      regmbc(0x1d8e); regmbc(0x1e91); regmbc(0x1e93);
      regmbc(0x1e95); regmbc(0x2c6c);
      return;
    }
  }
  regmbc(c);
}

// Emit a node.
// Return pointer to generated code.
static uint8_t *regnode(int op)
{
  uint8_t *ret;

  ret = regcode;
  if (ret == JUST_CALC_SIZE) {
    regsize += 3;
  } else {
    *regcode++ = (uint8_t)op;
    *regcode++ = NUL;                   // Null "next" pointer.
    *regcode++ = NUL;
  }
  return ret;
}

// Write a four bytes number at "p" and return pointer to the next char.
static uint8_t *re_put_uint32(uint8_t *p, uint32_t val)
{
  *p++ = (uint8_t)((val >> 24) & 0377);
  *p++ = (uint8_t)((val >> 16) & 0377);
  *p++ = (uint8_t)((val >> 8) & 0377);
  *p++ = (uint8_t)(val & 0377);
  return p;
}

// regnext - dig the "next" pointer out of a node
// Returns NULL when calculating size, when there is no next item and when
// there is an error.
static uint8_t *regnext(uint8_t *p)
  FUNC_ATTR_NONNULL_ALL
{
  int offset;

  if (p == JUST_CALC_SIZE || reg_toolong) {
    return NULL;
  }

  offset = NEXT(p);
  if (offset == 0) {
    return NULL;
  }

  if (OP(p) == BACK) {
    return p - offset;
  } else {
    return p + offset;
  }
}

// Set the next-pointer at the end of a node chain.
static void regtail(uint8_t *p, const uint8_t *val)
{
  int offset;

  if (p == JUST_CALC_SIZE) {
    return;
  }

  // Find last node.
  uint8_t *scan = p;
  while (true) {
    uint8_t *temp = regnext(scan);
    if (temp == NULL) {
      break;
    }
    scan = temp;
  }

  if (OP(scan) == BACK) {
    offset = (int)(scan - val);
  } else {
    offset = (int)(val - scan);
  }
  // When the offset uses more than 16 bits it can no longer fit in the two
  // bytes available.  Use a global flag to avoid having to check return
  // values in too many places.
  if (offset > 0xffff) {
    reg_toolong = true;
  } else {
    *(scan + 1) = (uint8_t)(((unsigned)offset >> 8) & 0377);
    *(scan + 2) = (uint8_t)(offset & 0377);
  }
}

// Like regtail, on item after a BRANCH; nop if none.
static void regoptail(uint8_t *p, uint8_t *val)
{
  // When op is neither BRANCH nor BRACE_COMPLEX0-9, it is "operandless"
  if (p == NULL || p == JUST_CALC_SIZE
      || (OP(p) != BRANCH
          && (OP(p) < BRACE_COMPLEX || OP(p) > BRACE_COMPLEX + 9))) {
    return;
  }
  regtail(OPERAND(p), val);
}

// Insert an operator in front of already-emitted operand
//
// Means relocating the operand.
static void reginsert(int op, uint8_t *opnd)
{
  uint8_t *src;
  uint8_t *dst;
  uint8_t *place;

  if (regcode == JUST_CALC_SIZE) {
    regsize += 3;
    return;
  }
  src = regcode;
  regcode += 3;
  dst = regcode;
  while (src > opnd) {
    *--dst = *--src;
  }

  place = opnd;                 // Op node, where operand used to be.
  *place++ = (uint8_t)op;
  *place++ = NUL;
  *place = NUL;
}

// Insert an operator in front of already-emitted operand.
// Add a number to the operator.
static void reginsert_nr(int op, int64_t val, uint8_t *opnd)
{
  uint8_t *src;
  uint8_t *dst;
  uint8_t *place;

  if (regcode == JUST_CALC_SIZE) {
    regsize += 7;
    return;
  }
  src = regcode;
  regcode += 7;
  dst = regcode;
  while (src > opnd) {
    *--dst = *--src;
  }

  place = opnd;                 // Op node, where operand used to be.
  *place++ = (uint8_t)op;
  *place++ = NUL;
  *place++ = NUL;
  assert(val >= 0 && (uintmax_t)val <= UINT32_MAX);
  re_put_uint32(place, (uint32_t)val);
}

// Insert an operator in front of already-emitted operand.
// The operator has the given limit values as operands.  Also set next pointer.
//
// Means relocating the operand.
static void reginsert_limits(int op, int64_t minval, int64_t maxval, uint8_t *opnd)
{
  uint8_t *src;
  uint8_t *dst;
  uint8_t *place;

  if (regcode == JUST_CALC_SIZE) {
    regsize += 11;
    return;
  }
  src = regcode;
  regcode += 11;
  dst = regcode;
  while (src > opnd) {
    *--dst = *--src;
  }

  place = opnd;                 // Op node, where operand used to be.
  *place++ = (uint8_t)op;
  *place++ = NUL;
  *place++ = NUL;
  assert(minval >= 0 && (uintmax_t)minval <= UINT32_MAX);
  place = re_put_uint32(place, (uint32_t)minval);
  assert(maxval >= 0 && (uintmax_t)maxval <= UINT32_MAX);
  place = re_put_uint32(place, (uint32_t)maxval);
  regtail(opnd, place);
}

/// Return true if the back reference is legal. We must have seen the close
/// brace.
/// TODO(vim): Should also check that we don't refer to something repeated
/// (+*=): what instance of the repetition should we match?
static int seen_endbrace(int refnum)
{
  if (!had_endbrace[refnum]) {
    uint8_t *p;

    // Trick: check if "@<=" or "@<!" follows, in which case
    // the \1 can appear before the referenced match.
    for (p = (uint8_t *)regparse; *p != NUL; p++) {
      if (p[0] == '@' && p[1] == '<' && (p[2] == '!' || p[2] == '=')) {
        break;
      }
    }

    if (*p == NUL) {
      emsg(_("E65: Illegal back reference"));
      rc_did_emsg = true;
      return false;
    }
  }
  return true;
}

// Parse the lowest level.
//
// Optimization:  gobbles an entire sequence of ordinary characters so that
// it can turn them into a single node, which is smaller to store and
// faster to run.  Don't do this when one_exactly is set.
static uint8_t *regatom(int *flagp)
{
  uint8_t *ret;
  int flags;
  int c;
  uint8_t *p;
  int extra = 0;
  int save_prev_at_start = prev_at_start;

  *flagp = WORST;               // Tentatively.

  c = getchr();
  switch (c) {
  case Magic('^'):
    ret = regnode(BOL);
    break;

  case Magic('$'):
    ret = regnode(EOL);
    had_eol = true;
    break;

  case Magic('<'):
    ret = regnode(BOW);
    break;

  case Magic('>'):
    ret = regnode(EOW);
    break;

  case Magic('_'):
    c = no_Magic(getchr());
    if (c == '^') {             // "\_^" is start-of-line
      ret = regnode(BOL);
      break;
    }
    if (c == '$') {             // "\_$" is end-of-line
      ret = regnode(EOL);
      had_eol = true;
      break;
    }

    extra = ADD_NL;
    *flagp |= HASNL;

    // "\_[" is character range plus newline
    if (c == '[') {
      goto collection;
    }

    // "\_x" is character class plus newline
    FALLTHROUGH;

  // Character classes.
  case Magic('.'):
  case Magic('i'):
  case Magic('I'):
  case Magic('k'):
  case Magic('K'):
  case Magic('f'):
  case Magic('F'):
  case Magic('p'):
  case Magic('P'):
  case Magic('s'):
  case Magic('S'):
  case Magic('d'):
  case Magic('D'):
  case Magic('x'):
  case Magic('X'):
  case Magic('o'):
  case Magic('O'):
  case Magic('w'):
  case Magic('W'):
  case Magic('h'):
  case Magic('H'):
  case Magic('a'):
  case Magic('A'):
  case Magic('l'):
  case Magic('L'):
  case Magic('u'):
  case Magic('U'):
    p = (uint8_t *)vim_strchr((char *)classchars, no_Magic(c));
    if (p == NULL) {
      EMSG_RET_NULL(_(e_invalid_use_of_underscore));
    }
    // When '.' is followed by a composing char ignore the dot, so that
    // the composing char is matched here.
    if (c == Magic('.') && utf_iscomposing(peekchr())) {
      c = getchr();
      goto do_multibyte;
    }
    ret = regnode(classcodes[p - classchars] + extra);
    *flagp |= HASWIDTH | SIMPLE;
    break;

  case Magic('n'):
    if (reg_string) {
      // In a string "\n" matches a newline character.
      ret = regnode(EXACTLY);
      regc(NL);
      regc(NUL);
      *flagp |= HASWIDTH | SIMPLE;
    } else {
      // In buffer text "\n" matches the end of a line.
      ret = regnode(NEWL);
      *flagp |= HASWIDTH | HASNL;
    }
    break;

  case Magic('('):
    if (one_exactly) {
      EMSG_ONE_RET_NULL;
    }
    ret = reg(REG_PAREN, &flags);
    if (ret == NULL) {
      return NULL;
    }
    *flagp |= flags & (HASWIDTH | SPSTART | HASNL | HASLOOKBH);
    break;

  case NUL:
  case Magic('|'):
  case Magic('&'):
  case Magic(')'):
    if (one_exactly) {
      EMSG_ONE_RET_NULL;
    }
    IEMSG_RET_NULL(_(e_internal));       // Supposed to be caught earlier.
  // NOTREACHED

  case Magic('='):
  case Magic('?'):
  case Magic('+'):
  case Magic('@'):
  case Magic('{'):
  case Magic('*'):
    c = no_Magic(c);
    EMSG3_RET_NULL(_("E64: %s%c follows nothing"),
                   (c == '*' ? reg_magic >= MAGIC_ON : reg_magic == MAGIC_ALL), c);
  // NOTREACHED

  case Magic('~'):              // previous substitute pattern
    if (reg_prev_sub != NULL) {
      uint8_t *lp;

      ret = regnode(EXACTLY);
      lp = (uint8_t *)reg_prev_sub;
      while (*lp != NUL) {
        regc(*lp++);
      }
      regc(NUL);
      if (*reg_prev_sub != NUL) {
        *flagp |= HASWIDTH;
        if ((lp - (uint8_t *)reg_prev_sub) == 1) {
          *flagp |= SIMPLE;
        }
      }
    } else {
      EMSG_RET_NULL(_(e_nopresub));
    }
    break;

  case Magic('1'):
  case Magic('2'):
  case Magic('3'):
  case Magic('4'):
  case Magic('5'):
  case Magic('6'):
  case Magic('7'):
  case Magic('8'):
  case Magic('9'): {
    int refnum;

    refnum = c - Magic('0');
    if (!seen_endbrace(refnum)) {
      return NULL;
    }
    ret = regnode(BACKREF + refnum);
  }
  break;

  case Magic('z'):
    c = no_Magic(getchr());
    switch (c) {
    case '(':
      if ((reg_do_extmatch & REX_SET) == 0) {
        EMSG_RET_NULL(_(e_z_not_allowed));
      }
      if (one_exactly) {
        EMSG_ONE_RET_NULL;
      }
      ret = reg(REG_ZPAREN, &flags);
      if (ret == NULL) {
        return NULL;
      }
      *flagp |= flags & (HASWIDTH|SPSTART|HASNL|HASLOOKBH);
      re_has_z = REX_SET;
      break;

    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
      if ((reg_do_extmatch & REX_USE) == 0) {
        EMSG_RET_NULL(_(e_z1_not_allowed));
      }
      ret = regnode(ZREF + c - '0');
      re_has_z = REX_USE;
      break;

    case 's':
      ret = regnode(MOPEN + 0);
      if (!re_mult_next("\\zs")) {
        return NULL;
      }
      break;

    case 'e':
      ret = regnode(MCLOSE + 0);
      if (!re_mult_next("\\ze")) {
        return NULL;
      }
      break;

    default:
      EMSG_RET_NULL(_("E68: Invalid character after \\z"));
    }
    break;

  case Magic('%'):
    c = no_Magic(getchr());
    switch (c) {
    // () without a back reference
    case '(':
      if (one_exactly) {
        EMSG_ONE_RET_NULL;
      }
      ret = reg(REG_NPAREN, &flags);
      if (ret == NULL) {
        return NULL;
      }
      *flagp |= flags & (HASWIDTH | SPSTART | HASNL | HASLOOKBH);
      break;

    // Catch \%^ and \%$ regardless of where they appear in the
    // pattern -- regardless of whether or not it makes sense.
    case '^':
      ret = regnode(RE_BOF);
      break;

    case '$':
      ret = regnode(RE_EOF);
      break;

    case '#':
      if (regparse[0] == '=' && regparse[1] >= 48 && regparse[1] <= 50) {
        // misplaced \%#=1
        semsg(_(e_atom_engine_must_be_at_start_of_pattern), regparse[1]);
        return FAIL;
      }
      ret = regnode(CURSOR);
      break;

    case 'V':
      ret = regnode(RE_VISUAL);
      break;

    case 'C':
      ret = regnode(RE_COMPOSING);
      break;

    // \%[abc]: Emit as a list of branches, all ending at the last
    // branch which matches nothing.
    case '[':
      if (one_exactly) {                        // doesn't nest
        EMSG_ONE_RET_NULL;
      }
      {
        uint8_t *lastbranch;
        uint8_t *lastnode = NULL;
        uint8_t *br;

        ret = NULL;
        while ((c = getchr()) != ']') {
          if (c == NUL) {
            EMSG2_RET_NULL(_(e_missing_sb),
                           reg_magic == MAGIC_ALL);
          }
          br = regnode(BRANCH);
          if (ret == NULL) {
            ret = br;
          } else {
            regtail(lastnode, br);
            if (reg_toolong) {
              return NULL;
            }
          }

          ungetchr();
          one_exactly = true;
          lastnode = regatom(flagp);
          one_exactly = false;
          if (lastnode == NULL) {
            return NULL;
          }
        }
        if (ret == NULL) {
          EMSG2_RET_NULL(_(e_empty_sb),
                         reg_magic == MAGIC_ALL);
        }
        lastbranch = regnode(BRANCH);
        br = regnode(NOTHING);
        if (ret != JUST_CALC_SIZE) {
          regtail(lastnode, br);
          regtail(lastbranch, br);
          // connect all branches to the NOTHING
          // branch at the end
          for (br = ret; br != lastnode;) {
            if (OP(br) == BRANCH) {
              regtail(br, lastbranch);
              if (reg_toolong) {
                return NULL;
              }
              br = OPERAND(br);
            } else {
              br = regnext(br);
            }
          }
        }
        *flagp &= ~(HASWIDTH | SIMPLE);
        break;
      }

    case 'd':               // %d123 decimal
    case 'o':               // %o123 octal
    case 'x':               // %xab hex 2
    case 'u':               // %uabcd hex 4
    case 'U':               // %U1234abcd hex 8
    {
      int64_t i;

      switch (c) {
      case 'd':
        i = getdecchrs(); break;
      case 'o':
        i = getoctchrs(); break;
      case 'x':
        i = gethexchrs(2); break;
      case 'u':
        i = gethexchrs(4); break;
      case 'U':
        i = gethexchrs(8); break;
      default:
        i = -1; break;
      }

      if (i < 0 || i > INT_MAX) {
        EMSG2_RET_NULL(_("E678: Invalid character after %s%%[dxouU]"),
                       reg_magic == MAGIC_ALL);
      }
      if (use_multibytecode((int)i)) {
        ret = regnode(MULTIBYTECODE);
      } else {
        ret = regnode(EXACTLY);
      }
      if (i == 0) {
        regc(0x0a);
      } else {
        regmbc((int)i);
      }
      regc(NUL);
      *flagp |= HASWIDTH;
      break;
    }

    default:
      if (ascii_isdigit(c) || c == '<' || c == '>' || c == '\'' || c == '.') {
        uint32_t n = 0;
        int cmp;
        bool cur = false;
        bool got_digit = false;

        cmp = c;
        if (cmp == '<' || cmp == '>') {
          c = getchr();
        }
        if (no_Magic(c) == '.') {
          cur = true;
          c = getchr();
        }
        while (ascii_isdigit(c)) {
          got_digit = true;
          n = n * 10 + (uint32_t)(c - '0');
          c = getchr();
        }
        if (no_Magic(c) == '\'' && n == 0) {
          // "\%'m", "\%<'m" and "\%>'m": Mark
          c = getchr();
          ret = regnode(RE_MARK);
          if (ret == JUST_CALC_SIZE) {
            regsize += 2;
          } else {
            *regcode++ = (uint8_t)c;
            *regcode++ = (uint8_t)cmp;
          }
          break;
        } else if ((c == 'l' || c == 'c' || c == 'v') && (cur || got_digit)) {
          if (cur && n) {
            semsg(_(e_regexp_number_after_dot_pos_search_chr), no_Magic(c));
            rc_did_emsg = true;
            return NULL;
          }
          if (c == 'l') {
            if (cur) {
              n = (uint32_t)curwin->w_cursor.lnum;
            }
            ret = regnode(RE_LNUM);
            if (save_prev_at_start) {
              at_start = true;
            }
          } else if (c == 'c') {
            if (cur) {
              n = (uint32_t)curwin->w_cursor.col;
              n++;
            }
            ret = regnode(RE_COL);
          } else {
            if (cur) {
              colnr_T vcol = 0;
              getvvcol(curwin, &curwin->w_cursor, NULL, NULL, &vcol);
              n = (uint32_t)(++vcol);
            }
            ret = regnode(RE_VCOL);
          }
          if (ret == JUST_CALC_SIZE) {
            regsize += 5;
          } else {
            // put the number and the optional
            // comparator after the opcode
            regcode = re_put_uint32(regcode, n);
            *regcode++ = (uint8_t)cmp;
          }
          break;
        }
      }

      EMSG2_RET_NULL(_("E71: Invalid character after %s%%"),
                     reg_magic == MAGIC_ALL);
    }
    break;

  case Magic('['):
collection:
    {
      uint8_t *lp;

      // If there is no matching ']', we assume the '[' is a normal
      // character.  This makes 'incsearch' and ":help [" work.
      lp = (uint8_t *)skip_anyof(regparse);
      if (*lp == ']') {         // there is a matching ']'
        int startc = -1;                // > 0 when next '-' is a range
        int endc;

        // In a character class, different parsing rules apply.
        // Not even \ is special anymore, nothing is.
        if (*regparse == '^') {             // Complement of range.
          ret = regnode(ANYBUT + extra);
          regparse++;
        } else {
          ret = regnode(ANYOF + extra);
        }

        // At the start ']' and '-' mean the literal character.
        if (*regparse == ']' || *regparse == '-') {
          startc = (uint8_t)(*regparse);
          regc(*regparse++);
        }

        while (*regparse != NUL && *regparse != ']') {
          if (*regparse == '-') {
            regparse++;
            // The '-' is not used for a range at the end and
            // after or before a '\n'.
            if (*regparse == ']' || *regparse == NUL
                || startc == -1
                || (regparse[0] == '\\' && regparse[1] == 'n')) {
              regc('-');
              startc = '-';                     // [--x] is a range
            } else {
              // Also accept "a-[.z.]"
              endc = 0;
              if (*regparse == '[') {
                endc = get_coll_element(&regparse);
              }
              if (endc == 0) {
                endc = mb_ptr2char_adv((const char **)&regparse);
              }

              // Handle \o40, \x20 and \u20AC style sequences
              if (endc == '\\' && !reg_cpo_lit) {
                endc = coll_get_char();
              }

              if (startc > endc) {
                EMSG_RET_NULL(_(e_reverse_range));
              }
              if (utf_char2len(startc) > 1
                  || utf_char2len(endc) > 1) {
                // Limit to a range of 256 chars
                if (endc > startc + 256) {
                  EMSG_RET_NULL(_(e_large_class));
                }
                while (++startc <= endc) {
                  regmbc(startc);
                }
              } else {
                while (++startc <= endc) {
                  regc(startc);
                }
              }
              startc = -1;
            }
          }
          // Only "\]", "\^", "\]" and "\\" are special in Vi.  Vim
          // accepts "\t", "\e", etc., but only when the 'l' flag in
          // 'cpoptions' is not included.
          else if (*regparse == '\\'
                   && (vim_strchr(REGEXP_INRANGE, (uint8_t)regparse[1]) != NULL
                       || (!reg_cpo_lit
                           && vim_strchr(REGEXP_ABBR,
                                         (uint8_t)regparse[1]) != NULL))) {
            regparse++;
            if (*regparse == 'n') {
              // '\n' in range: also match NL
              if (ret != JUST_CALC_SIZE) {
                // Using \n inside [^] does not change what
                // matches. "[^\n]" is the same as ".".
                if (*ret == ANYOF) {
                  *ret = ANYOF + ADD_NL;
                  *flagp |= HASNL;
                }
                // else: must have had a \n already
              }
              regparse++;
              startc = -1;
            } else if (*regparse == 'd'
                       || *regparse == 'o'
                       || *regparse == 'x'
                       || *regparse == 'u'
                       || *regparse == 'U') {
              startc = coll_get_char();
              if (startc == 0) {
                regc(0x0a);
              } else {
                regmbc(startc);
              }
            } else {
              startc = backslash_trans(*regparse++);
              regc(startc);
            }
          } else if (*regparse == '[') {
            int c_class;
            int cu;

            c_class = get_char_class(&regparse);
            startc = -1;
            // Characters assumed to be 8 bits!
            switch (c_class) {
            case CLASS_NONE:
              c_class = get_equi_class(&regparse);
              if (c_class != 0) {
                // produce equivalence class
                reg_equi_class(c_class);
              } else if ((c_class = get_coll_element(&regparse)) != 0) {
                // produce a collating element
                regmbc(c_class);
              } else {
                // literal '[', allow [[-x] as a range
                startc = (uint8_t)(*regparse++);
                regc(startc);
              }
              break;
            case CLASS_ALNUM:
              for (cu = 1; cu < 128; cu++) {
                if (isalnum(cu)) {
                  regmbc(cu);
                }
              }
              break;
            case CLASS_ALPHA:
              for (cu = 1; cu < 128; cu++) {
                if (isalpha(cu)) {
                  regmbc(cu);
                }
              }
              break;
            case CLASS_BLANK:
              regc(' ');
              regc('\t');
              break;
            case CLASS_CNTRL:
              for (cu = 1; cu <= 127; cu++) {
                if (iscntrl(cu)) {
                  regmbc(cu);
                }
              }
              break;
            case CLASS_DIGIT:
              for (cu = 1; cu <= 127; cu++) {
                if (ascii_isdigit(cu)) {
                  regmbc(cu);
                }
              }
              break;
            case CLASS_GRAPH:
              for (cu = 1; cu <= 127; cu++) {
                if (isgraph(cu)) {
                  regmbc(cu);
                }
              }
              break;
            case CLASS_LOWER:
              for (cu = 1; cu <= 255; cu++) {
                if (mb_islower(cu) && cu != 170 && cu != 186) {
                  regmbc(cu);
                }
              }
              break;
            case CLASS_PRINT:
              for (cu = 1; cu <= 255; cu++) {
                if (vim_isprintc(cu)) {
                  regmbc(cu);
                }
              }
              break;
            case CLASS_PUNCT:
              for (cu = 1; cu < 128; cu++) {
                if (ispunct(cu)) {
                  regmbc(cu);
                }
              }
              break;
            case CLASS_SPACE:
              for (cu = 9; cu <= 13; cu++) {
                regc(cu);
              }
              regc(' ');
              break;
            case CLASS_UPPER:
              for (cu = 1; cu <= 255; cu++) {
                if (mb_isupper(cu)) {
                  regmbc(cu);
                }
              }
              break;
            case CLASS_XDIGIT:
              for (cu = 1; cu <= 255; cu++) {
                if (ascii_isxdigit(cu)) {
                  regmbc(cu);
                }
              }
              break;
            case CLASS_TAB:
              regc('\t');
              break;
            case CLASS_RETURN:
              regc('\r');
              break;
            case CLASS_BACKSPACE:
              regc('\b');
              break;
            case CLASS_ESCAPE:
              regc(ESC);
              break;
            case CLASS_IDENT:
              for (cu = 1; cu <= 255; cu++) {
                if (vim_isIDc(cu)) {
                  regmbc(cu);
                }
              }
              break;
            case CLASS_KEYWORD:
              for (cu = 1; cu <= 255; cu++) {
                if (reg_iswordc(cu)) {
                  regmbc(cu);
                }
              }
              break;
            case CLASS_FNAME:
              for (cu = 1; cu <= 255; cu++) {
                if (vim_isfilec(cu)) {
                  regmbc(cu);
                }
              }
              break;
            }
          } else {
            // produce a multibyte character, including any
            // following composing characters.
            startc = utf_ptr2char(regparse);
            int len = utfc_ptr2len(regparse);
            if (utf_char2len(startc) != len) {
              // composing chars
              startc = -1;
            }
            while (--len >= 0) {
              regc(*regparse++);
            }
          }
        }
        regc(NUL);
        prevchr_len = 1;                // last char was the ']'
        if (*regparse != ']') {
          EMSG_RET_NULL(_(e_toomsbra));                 // Cannot happen?
        }
        skipchr();                  // let's be friends with the lexer again
        *flagp |= HASWIDTH | SIMPLE;
        break;
      } else if (reg_strict) {
        EMSG2_RET_NULL(_(e_missingbracket), reg_magic > MAGIC_OFF);
      }
    }
    FALLTHROUGH;

  default: {
    int len;

    // A multi-byte character is handled as a separate atom if it's
    // before a multi and when it's a composing char.
    if (use_multibytecode(c)) {
do_multibyte:
      ret = regnode(MULTIBYTECODE);
      regmbc(c);
      *flagp |= HASWIDTH | SIMPLE;
      break;
    }

    ret = regnode(EXACTLY);

    // Append characters as long as:
    // - there is no following multi, we then need the character in
    //   front of it as a single character operand
    // - not running into a Magic character
    // - "one_exactly" is not set
    // But always emit at least one character.  Might be a Multi,
    // e.g., a "[" without matching "]".
    for (len = 0; c != NUL && (len == 0
                               || (re_multi_type(peekchr()) == NOT_MULTI
                                   && !one_exactly
                                   && !is_Magic(c))); len++) {
      c = no_Magic(c);
      {
        regmbc(c);
        {
          int l;

          // Need to get composing character too.
          while (true) {
            l = utf_ptr2len(regparse);
            if (!utf_composinglike(regparse, regparse + l)) {
              break;
            }
            regmbc(utf_ptr2char(regparse));
            skipchr();
          }
        }
      }
      c = getchr();
    }
    ungetchr();

    regc(NUL);
    *flagp |= HASWIDTH;
    if (len == 1) {
      *flagp |= SIMPLE;
    }
  }
  break;
  }

  return ret;
}

// Parse something followed by possible [*+=].
//
// Note that the branching code sequences used for = and the general cases
// of * and + are somewhat optimized:  they use the same NOTHING node as
// both the endmarker for their branch list and the body of the last branch.
// It might seem that this node could be dispensed with entirely, but the
// endmarker role is not redundant.
static uint8_t *regpiece(int *flagp)
{
  uint8_t *ret;
  int op;
  uint8_t *next;
  int flags;
  int minval;
  int maxval;

  ret = regatom(&flags);
  if (ret == NULL) {
    return NULL;
  }

  op = peekchr();
  if (re_multi_type(op) == NOT_MULTI) {
    *flagp = flags;
    return ret;
  }
  // default flags
  *flagp = (WORST | SPSTART | (flags & (HASNL | HASLOOKBH)));

  skipchr();
  switch (op) {
  case Magic('*'):
    if (flags & SIMPLE) {
      reginsert(STAR, ret);
    } else {
      // Emit x* as (x&|), where & means "self".
      reginsert(BRANCH, ret);           // Either x
      regoptail(ret, regnode(BACK));            // and loop
      regoptail(ret, ret);              // back
      regtail(ret, regnode(BRANCH));            // or
      regtail(ret, regnode(NOTHING));           // null.
    }
    break;

  case Magic('+'):
    if (flags & SIMPLE) {
      reginsert(PLUS, ret);
    } else {
      // Emit x+ as x(&|), where & means "self".
      next = regnode(BRANCH);           // Either
      regtail(ret, next);
      regtail(regnode(BACK), ret);              // loop back
      regtail(next, regnode(BRANCH));           // or
      regtail(ret, regnode(NOTHING));           // null.
    }
    *flagp = (WORST | HASWIDTH | (flags & (HASNL | HASLOOKBH)));
    break;

  case Magic('@'): {
    int lop = END;
    int64_t nr = getdecchrs();

    switch (no_Magic(getchr())) {
    case '=':
      lop = MATCH; break;                                 // \@=
    case '!':
      lop = NOMATCH; break;                               // \@!
    case '>':
      lop = SUBPAT; break;                                // \@>
    case '<':
      switch (no_Magic(getchr())) {
      case '=':
        lop = BEHIND; break;                               // \@<=
      case '!':
        lop = NOBEHIND; break;                             // \@<!
      }
    }
    if (lop == END) {
      EMSG2_RET_NULL(_(e_invalid_character_after_str_at),
                     reg_magic == MAGIC_ALL);
    }
    // Look behind must match with behind_pos.
    if (lop == BEHIND || lop == NOBEHIND) {
      regtail(ret, regnode(BHPOS));
      *flagp |= HASLOOKBH;
    }
    regtail(ret, regnode(END));             // operand ends
    if (lop == BEHIND || lop == NOBEHIND) {
      if (nr < 0) {
        nr = 0;                 // no limit is same as zero limit
      }
      reginsert_nr(lop, (uint32_t)nr, ret);
    } else {
      reginsert(lop, ret);
    }
    break;
  }

  case Magic('?'):
  case Magic('='):
    // Emit x= as (x|)
    reginsert(BRANCH, ret);                     // Either x
    regtail(ret, regnode(BRANCH));              // or
    next = regnode(NOTHING);                    // null.
    regtail(ret, next);
    regoptail(ret, next);
    break;

  case Magic('{'):
    if (!read_limits(&minval, &maxval)) {
      return NULL;
    }
    if (flags & SIMPLE) {
      reginsert(BRACE_SIMPLE, ret);
      reginsert_limits(BRACE_LIMITS, minval, maxval, ret);
    } else {
      if (num_complex_braces >= 10) {
        EMSG2_RET_NULL(_("E60: Too many complex %s{...}s"),
                       reg_magic == MAGIC_ALL);
      }
      reginsert(BRACE_COMPLEX + num_complex_braces, ret);
      regoptail(ret, regnode(BACK));
      regoptail(ret, ret);
      reginsert_limits(BRACE_LIMITS, minval, maxval, ret);
      num_complex_braces++;
    }
    if (minval > 0 && maxval > 0) {
      *flagp = (HASWIDTH | (flags & (HASNL | HASLOOKBH)));
    }
    break;
  }
  if (re_multi_type(peekchr()) != NOT_MULTI) {
    // Can't have a multi follow a multi.
    if (peekchr() == Magic('*')) {
      EMSG2_RET_NULL(_("E61: Nested %s*"), reg_magic >= MAGIC_ON);
    }
    EMSG3_RET_NULL(_("E62: Nested %s%c"), reg_magic == MAGIC_ALL, no_Magic(peekchr()));
  }

  return ret;
}

// Parse one alternative of an | or & operator.
// Implements the concatenation operator.
static uint8_t *regconcat(int *flagp)
{
  uint8_t *first = NULL;
  uint8_t *chain = NULL;
  uint8_t *latest;
  int flags;
  int cont = true;

  *flagp = WORST;               // Tentatively.

  while (cont) {
    switch (peekchr()) {
    case NUL:
    case Magic('|'):
    case Magic('&'):
    case Magic(')'):
      cont = false;
      break;
    case Magic('Z'):
      regflags |= RF_ICOMBINE;
      skipchr_keepstart();
      break;
    case Magic('c'):
      regflags |= RF_ICASE;
      skipchr_keepstart();
      break;
    case Magic('C'):
      regflags |= RF_NOICASE;
      skipchr_keepstart();
      break;
    case Magic('v'):
      reg_magic = MAGIC_ALL;
      skipchr_keepstart();
      curchr = -1;
      break;
    case Magic('m'):
      reg_magic = MAGIC_ON;
      skipchr_keepstart();
      curchr = -1;
      break;
    case Magic('M'):
      reg_magic = MAGIC_OFF;
      skipchr_keepstart();
      curchr = -1;
      break;
    case Magic('V'):
      reg_magic = MAGIC_NONE;
      skipchr_keepstart();
      curchr = -1;
      break;
    default:
      latest = regpiece(&flags);
      if (latest == NULL || reg_toolong) {
        return NULL;
      }
      *flagp |= flags & (HASWIDTH | HASNL | HASLOOKBH);
      if (chain == NULL) {                      // First piece.
        *flagp |= flags & SPSTART;
      } else {
        regtail(chain, latest);
      }
      chain = latest;
      if (first == NULL) {
        first = latest;
      }
      break;
    }
  }
  if (first == NULL) {          // Loop ran zero times.
    first = regnode(NOTHING);
  }
  return first;
}

// Parse one alternative of an | operator.
// Implements the & operator.
static uint8_t *regbranch(int *flagp)
{
  uint8_t *ret;
  uint8_t *chain = NULL;
  uint8_t *latest;
  int flags;

  *flagp = WORST | HASNL;               // Tentatively.

  ret = regnode(BRANCH);
  while (true) {
    latest = regconcat(&flags);
    if (latest == NULL) {
      return NULL;
    }
    // If one of the branches has width, the whole thing has.  If one of
    // the branches anchors at start-of-line, the whole thing does.
    // If one of the branches uses look-behind, the whole thing does.
    *flagp |= flags & (HASWIDTH | SPSTART | HASLOOKBH);
    // If one of the branches doesn't match a line-break, the whole thing
    // doesn't.
    *flagp &= ~HASNL | (flags & HASNL);
    if (chain != NULL) {
      regtail(chain, latest);
    }
    if (peekchr() != Magic('&')) {
      break;
    }
    skipchr();
    regtail(latest, regnode(END));     // operand ends
    if (reg_toolong) {
      break;
    }
    reginsert(MATCH, latest);
    chain = latest;
  }

  return ret;
}

/// Parse regular expression, i.e. main body or parenthesized thing.
///
/// Caller must absorb opening parenthesis.
///
/// Combining parenthesis handling with the base level of regular expression
/// is a trifle forced, but the need to tie the tails of the branches to what
/// follows makes it hard to avoid.
///
/// @param paren  REG_NOPAREN, REG_PAREN, REG_NPAREN or REG_ZPAREN
static uint8_t *reg(int paren, int *flagp)
{
  uint8_t *ret;
  uint8_t *br;
  uint8_t *ender;
  int parno = 0;
  int flags;

  *flagp = HASWIDTH;            // Tentatively.

  if (paren == REG_ZPAREN) {
    // Make a ZOPEN node.
    if (regnzpar >= NSUBEXP) {
      EMSG_RET_NULL(_("E50: Too many \\z("));
    }
    parno = regnzpar;
    regnzpar++;
    ret = regnode(ZOPEN + parno);
  } else if (paren == REG_PAREN) {
    // Make a MOPEN node.
    if (regnpar >= NSUBEXP) {
      EMSG2_RET_NULL(_("E51: Too many %s("), reg_magic == MAGIC_ALL);
    }
    parno = regnpar;
    regnpar++;
    ret = regnode(MOPEN + parno);
  } else if (paren == REG_NPAREN) {
    // Make a NOPEN node.
    ret = regnode(NOPEN);
  } else {
    ret = NULL;
  }

  // Pick up the branches, linking them together.
  br = regbranch(&flags);
  if (br == NULL) {
    return NULL;
  }
  if (ret != NULL) {
    regtail(ret, br);           // [MZ]OPEN -> first.
  } else {
    ret = br;
  }
  // If one of the branches can be zero-width, the whole thing can.
  // If one of the branches has * at start or matches a line-break, the
  // whole thing can.
  if (!(flags & HASWIDTH)) {
    *flagp &= ~HASWIDTH;
  }
  *flagp |= flags & (SPSTART | HASNL | HASLOOKBH);
  while (peekchr() == Magic('|')) {
    skipchr();
    br = regbranch(&flags);
    if (br == NULL || reg_toolong) {
      return NULL;
    }
    regtail(ret, br);           // BRANCH -> BRANCH.
    if (!(flags & HASWIDTH)) {
      *flagp &= ~HASWIDTH;
    }
    *flagp |= flags & (SPSTART | HASNL | HASLOOKBH);
  }

  // Make a closing node, and hook it on the end.
  ender = regnode(paren == REG_ZPAREN ? ZCLOSE + parno
                                      : paren == REG_PAREN ? MCLOSE + parno
                                                           : paren == REG_NPAREN ? NCLOSE : END);
  regtail(ret, ender);

  // Hook the tails of the branches to the closing node.
  for (br = ret; br != NULL; br = regnext(br)) {
    regoptail(br, ender);
  }

  // Check for proper termination.
  if (paren != REG_NOPAREN && getchr() != Magic(')')) {
    if (paren == REG_ZPAREN) {
      EMSG_RET_NULL(_("E52: Unmatched \\z("));
    } else if (paren == REG_NPAREN) {
      EMSG2_RET_NULL(_(e_unmatchedpp), reg_magic == MAGIC_ALL);
    } else {
      EMSG2_RET_NULL(_(e_unmatchedp), reg_magic == MAGIC_ALL);
    }
  } else if (paren == REG_NOPAREN && peekchr() != NUL) {
    if (curchr == Magic(')')) {
      EMSG2_RET_NULL(_(e_unmatchedpar), reg_magic == MAGIC_ALL);
    } else {
      EMSG_RET_NULL(_(e_trailing));             // "Can't happen".
    }
    // NOTREACHED
  }
  // Here we set the flag allowing back references to this set of
  // parentheses.
  if (paren == REG_PAREN) {
    had_endbrace[parno] = true;  // have seen the close paren
  }
  return ret;
}

// bt_regcomp() - compile a regular expression into internal code for the
// traditional back track matcher.
// Returns the program in allocated space.  Returns NULL for an error.
//
// We can't allocate space until we know how big the compiled form will be,
// but we can't compile it (and thus know how big it is) until we've got a
// place to put the code.  So we cheat:  we compile it twice, once with code
// generation turned off and size counting turned on, and once "for real".
// This also means that we don't allocate space until we are sure that the
// thing really will compile successfully, and we never have to move the
// code and thus invalidate pointers into it.  (Note that it has to be in
// one piece because free() must be able to free it all.)
//
// Whether upper/lower case is to be ignored is decided when executing the
// program, it does not matter here.
//
// Beware that the optimization-preparation code in here knows about some
// of the structure of the compiled regexp.
// "re_flags": RE_MAGIC and/or RE_STRING.
static regprog_T *bt_regcomp(uint8_t *expr, int re_flags)
{
  uint8_t *scan;
  uint8_t *longest;
  int len;
  int flags;

  if (expr == NULL) {
    IEMSG_RET_NULL(_(e_null));
  }

  init_class_tab();

  // First pass: determine size, legality.
  regcomp_start(expr, re_flags);
  regcode = JUST_CALC_SIZE;
  regc(REGMAGIC);
  if (reg(REG_NOPAREN, &flags) == NULL) {
    return NULL;
  }

  // Allocate space.
  bt_regprog_T *r = xmalloc(offsetof(bt_regprog_T, program) + (size_t)regsize);
  r->re_in_use = false;

  // Second pass: emit code.
  regcomp_start(expr, re_flags);
  regcode = r->program;
  regc(REGMAGIC);
  if (reg(REG_NOPAREN, &flags) == NULL || reg_toolong) {
    xfree(r);
    if (reg_toolong) {
      EMSG_RET_NULL(_("E339: Pattern too long"));
    }
    return NULL;
  }

  // Dig out information for optimizations.
  r->regstart = NUL;            // Worst-case defaults.
  r->reganch = 0;
  r->regmust = NULL;
  r->regmlen = 0;
  r->regflags = regflags;
  if (flags & HASNL) {
    r->regflags |= RF_HASNL;
  }
  if (flags & HASLOOKBH) {
    r->regflags |= RF_LOOKBH;
  }
  // Remember whether this pattern has any \z specials in it.
  r->reghasz = (uint8_t)re_has_z;
  scan = &r->program[1];  // First BRANCH.
  if (OP(regnext(scan)) == END) {   // Only one top-level choice.
    scan = OPERAND(scan);

    // Starting-point info.
    if (OP(scan) == BOL || OP(scan) == RE_BOF) {
      r->reganch++;
      scan = regnext(scan);
    }

    if (OP(scan) == EXACTLY) {
      r->regstart = utf_ptr2char((char *)OPERAND(scan));
    } else if (OP(scan) == BOW
               || OP(scan) == EOW
               || OP(scan) == NOTHING
               || OP(scan) == MOPEN + 0 || OP(scan) == NOPEN
               || OP(scan) == MCLOSE + 0 || OP(scan) == NCLOSE) {
      uint8_t *regnext_scan = regnext(scan);
      if (OP(regnext_scan) == EXACTLY) {
        r->regstart = utf_ptr2char((char *)OPERAND(regnext_scan));
      }
    }

    // If there's something expensive in the r.e., find the longest
    // literal string that must appear and make it the regmust.  Resolve
    // ties in favor of later strings, since the regstart check works
    // with the beginning of the r.e. and avoiding duplication
    // strengthens checking.  Not a strong reason, but sufficient in the
    // absence of others.

    // When the r.e. starts with BOW, it is faster to look for a regmust
    // first. Used a lot for "#" and "*" commands. (Added by mool).
    if ((flags & SPSTART || OP(scan) == BOW || OP(scan) == EOW)
        && !(flags & HASNL)) {
      longest = NULL;
      len = 0;
      for (; scan != NULL; scan = regnext(scan)) {
        if (OP(scan) == EXACTLY) {
          size_t scanlen = strlen((char *)OPERAND(scan));
          if (scanlen >= (size_t)len) {
            longest = OPERAND(scan);
            len = (int)scanlen;
          }
        }
      }
      r->regmust = longest;
      r->regmlen = len;
    }
  }
#ifdef BT_REGEXP_DUMP
  regdump(expr, r);
#endif
  r->engine = &bt_regengine;
  return (regprog_T *)r;
}

// Check if during the previous call to vim_regcomp the EOL item "$" has been
// found.  This is messy, but it works fine.
int vim_regcomp_had_eol(void)
{
  return had_eol;
}

// Get a number after a backslash that is inside [].
// When nothing is recognized return a backslash.
static int coll_get_char(void)
{
  int64_t nr = -1;

  switch (*regparse++) {
  case 'd':
    nr = getdecchrs(); break;
  case 'o':
    nr = getoctchrs(); break;
  case 'x':
    nr = gethexchrs(2); break;
  case 'u':
    nr = gethexchrs(4); break;
  case 'U':
    nr = gethexchrs(8); break;
  }
  if (nr < 0 || nr > INT_MAX) {
    // If getting the number fails be backwards compatible: the character
    // is a backslash.
    regparse--;
    nr = '\\';
  }
  return (int)nr;
}

// Free a compiled regexp program, returned by bt_regcomp().
static void bt_regfree(regprog_T *prog)
{
  xfree(prog);
}

#define ADVANCE_REGINPUT() MB_PTR_ADV(rex.input)

// The arguments from BRACE_LIMITS are stored here.  They are actually local
// to regmatch(), but they are here to reduce the amount of stack space used
// (it can be called recursively many times).
static int64_t bl_minval;
static int64_t bl_maxval;

// Save the input line and position in a regsave_T.
static void reg_save(regsave_T *save, garray_T *gap)
  FUNC_ATTR_NONNULL_ALL
{
  if (REG_MULTI) {
    save->rs_u.pos.col = (colnr_T)(rex.input - rex.line);
    save->rs_u.pos.lnum = rex.lnum;
  } else {
    save->rs_u.ptr = rex.input;
  }
  save->rs_len = gap->ga_len;
}

// Restore the input line and position from a regsave_T.
static void reg_restore(regsave_T *save, garray_T *gap)
  FUNC_ATTR_NONNULL_ALL
{
  if (REG_MULTI) {
    if (rex.lnum != save->rs_u.pos.lnum) {
      // only call reg_getline() when the line number changed to save
      // a bit of time
      rex.lnum = save->rs_u.pos.lnum;
      rex.line = (uint8_t *)reg_getline(rex.lnum);
    }
    rex.input = rex.line + save->rs_u.pos.col;
  } else {
    rex.input = save->rs_u.ptr;
  }
  gap->ga_len = save->rs_len;
}

// Return true if current position is equal to saved position.
static bool reg_save_equal(const regsave_T *save)
  FUNC_ATTR_NONNULL_ALL
{
  if (REG_MULTI) {
    return rex.lnum == save->rs_u.pos.lnum
           && rex.input == rex.line + save->rs_u.pos.col;
  }
  return rex.input == save->rs_u.ptr;
}

// Save the sub-expressions before attempting a match.
#define save_se(savep, posp, pp) \
  REG_MULTI ? save_se_multi((savep), (posp)) : save_se_one((savep), (pp))

// After a failed match restore the sub-expressions.
#define restore_se(savep, posp, pp) { \
  if (REG_MULTI) \
  *(posp) = (savep)->se_u.pos; \
  else \
  *(pp) = (savep)->se_u.ptr; }

// Tentatively set the sub-expression start to the current position (after
// calling regmatch() they will have changed).  Need to save the existing
// values for when there is no match.
// Use se_save() to use pointer (save_se_multi()) or position (save_se_one()),
// depending on REG_MULTI.
static void save_se_multi(save_se_T *savep, lpos_T *posp)
{
  savep->se_u.pos = *posp;
  posp->lnum = rex.lnum;
  posp->col = (colnr_T)(rex.input - rex.line);
}

static void save_se_one(save_se_T *savep, uint8_t **pp)
{
  savep->se_u.ptr = *pp;
  *pp = rex.input;
}

/// regrepeat - repeatedly match something simple, return how many.
/// Advances rex.input (and rex.lnum) to just after the matched chars.
///
/// @param maxcount  maximum number of matches allowed
static int regrepeat(uint8_t *p, int64_t maxcount)
{
  int64_t count = 0;
  uint8_t *opnd;
  int mask;
  int testval = 0;

  uint8_t *scan = rex.input;  // Make local copy of rex.input for speed.
  opnd = OPERAND(p);
  switch (OP(p)) {
  case ANY:
  case ANY + ADD_NL:
    while (count < maxcount) {
      // Matching anything means we continue until end-of-line (or
      // end-of-file for ANY + ADD_NL), only limited by maxcount.
      while (*scan != NUL && count < maxcount) {
        count++;
        MB_PTR_ADV(scan);
      }
      if (!REG_MULTI || !WITH_NL(OP(p)) || rex.lnum > rex.reg_maxline
          || rex.reg_line_lbr || count == maxcount) {
        break;
      }
      count++;  // count the line-break
      reg_nextline();
      scan = rex.input;
      if (got_int) {
        break;
      }
    }
    break;

  case IDENT:
  case IDENT + ADD_NL:
    testval = 1;
    FALLTHROUGH;
  case SIDENT:
  case SIDENT + ADD_NL:
    while (count < maxcount) {
      if (vim_isIDc(utf_ptr2char((char *)scan)) && (testval || !ascii_isdigit(*scan))) {
        MB_PTR_ADV(scan);
      } else if (*scan == NUL) {
        if (!REG_MULTI || !WITH_NL(OP(p)) || rex.lnum > rex.reg_maxline
            || rex.reg_line_lbr) {
          break;
        }
        reg_nextline();
        scan = rex.input;
        if (got_int) {
          break;
        }
      } else if (rex.reg_line_lbr && *scan == '\n' && WITH_NL(OP(p))) {
        scan++;
      } else {
        break;
      }
      count++;
    }
    break;

  case KWORD:
  case KWORD + ADD_NL:
    testval = 1;
    FALLTHROUGH;
  case SKWORD:
  case SKWORD + ADD_NL:
    while (count < maxcount) {
      if (vim_iswordp_buf((char *)scan, rex.reg_buf)
          && (testval || !ascii_isdigit(*scan))) {
        MB_PTR_ADV(scan);
      } else if (*scan == NUL) {
        if (!REG_MULTI || !WITH_NL(OP(p)) || rex.lnum > rex.reg_maxline
            || rex.reg_line_lbr) {
          break;
        }
        reg_nextline();
        scan = rex.input;
        if (got_int) {
          break;
        }
      } else if (rex.reg_line_lbr && *scan == '\n' && WITH_NL(OP(p))) {
        scan++;
      } else {
        break;
      }
      count++;
    }
    break;

  case FNAME:
  case FNAME + ADD_NL:
    testval = 1;
    FALLTHROUGH;
  case SFNAME:
  case SFNAME + ADD_NL:
    while (count < maxcount) {
      if (vim_isfilec(utf_ptr2char((char *)scan)) && (testval || !ascii_isdigit(*scan))) {
        MB_PTR_ADV(scan);
      } else if (*scan == NUL) {
        if (!REG_MULTI || !WITH_NL(OP(p)) || rex.lnum > rex.reg_maxline
            || rex.reg_line_lbr) {
          break;
        }
        reg_nextline();
        scan = rex.input;
        if (got_int) {
          break;
        }
      } else if (rex.reg_line_lbr && *scan == '\n' && WITH_NL(OP(p))) {
        scan++;
      } else {
        break;
      }
      count++;
    }
    break;

  case PRINT:
  case PRINT + ADD_NL:
    testval = 1;
    FALLTHROUGH;
  case SPRINT:
  case SPRINT + ADD_NL:
    while (count < maxcount) {
      if (*scan == NUL) {
        if (!REG_MULTI || !WITH_NL(OP(p)) || rex.lnum > rex.reg_maxline
            || rex.reg_line_lbr) {
          break;
        }
        reg_nextline();
        scan = rex.input;
        if (got_int) {
          break;
        }
      } else if (vim_isprintc(utf_ptr2char((char *)scan)) == 1
                 && (testval || !ascii_isdigit(*scan))) {
        MB_PTR_ADV(scan);
      } else if (rex.reg_line_lbr && *scan == '\n' && WITH_NL(OP(p))) {
        scan++;
      } else {
        break;
      }
      count++;
    }
    break;

  case WHITE:
  case WHITE + ADD_NL:
    testval = mask = RI_WHITE;
do_class:
    while (count < maxcount) {
      int l;
      if (*scan == NUL) {
        if (!REG_MULTI || !WITH_NL(OP(p)) || rex.lnum > rex.reg_maxline
            || rex.reg_line_lbr) {
          break;
        }
        reg_nextline();
        scan = rex.input;
        if (got_int) {
          break;
        }
      } else if ((l = utfc_ptr2len((char *)scan)) > 1) {
        if (testval != 0) {
          break;
        }
        scan += l;
      } else if ((class_tab[*scan] & mask) == testval) {
        scan++;
      } else if (rex.reg_line_lbr && *scan == '\n' && WITH_NL(OP(p))) {
        scan++;
      } else {
        break;
      }
      count++;
    }
    break;

  case NWHITE:
  case NWHITE + ADD_NL:
    mask = RI_WHITE;
    goto do_class;
  case DIGIT:
  case DIGIT + ADD_NL:
    testval = mask = RI_DIGIT;
    goto do_class;
  case NDIGIT:
  case NDIGIT + ADD_NL:
    mask = RI_DIGIT;
    goto do_class;
  case HEX:
  case HEX + ADD_NL:
    testval = mask = RI_HEX;
    goto do_class;
  case NHEX:
  case NHEX + ADD_NL:
    mask = RI_HEX;
    goto do_class;
  case OCTAL:
  case OCTAL + ADD_NL:
    testval = mask = RI_OCTAL;
    goto do_class;
  case NOCTAL:
  case NOCTAL + ADD_NL:
    mask = RI_OCTAL;
    goto do_class;
  case WORD:
  case WORD + ADD_NL:
    testval = mask = RI_WORD;
    goto do_class;
  case NWORD:
  case NWORD + ADD_NL:
    mask = RI_WORD;
    goto do_class;
  case HEAD:
  case HEAD + ADD_NL:
    testval = mask = RI_HEAD;
    goto do_class;
  case NHEAD:
  case NHEAD + ADD_NL:
    mask = RI_HEAD;
    goto do_class;
  case ALPHA:
  case ALPHA + ADD_NL:
    testval = mask = RI_ALPHA;
    goto do_class;
  case NALPHA:
  case NALPHA + ADD_NL:
    mask = RI_ALPHA;
    goto do_class;
  case LOWER:
  case LOWER + ADD_NL:
    testval = mask = RI_LOWER;
    goto do_class;
  case NLOWER:
  case NLOWER + ADD_NL:
    mask = RI_LOWER;
    goto do_class;
  case UPPER:
  case UPPER + ADD_NL:
    testval = mask = RI_UPPER;
    goto do_class;
  case NUPPER:
  case NUPPER + ADD_NL:
    mask = RI_UPPER;
    goto do_class;

  case EXACTLY: {
    int cu, cl;

    // This doesn't do a multi-byte character, because a MULTIBYTECODE
    // would have been used for it.  It does handle single-byte
    // characters, such as latin1.
    if (rex.reg_ic) {
      cu = mb_toupper(*opnd);
      cl = mb_tolower(*opnd);
      while (count < maxcount && (*scan == cu || *scan == cl)) {
        count++;
        scan++;
      }
    } else {
      cu = *opnd;
      while (count < maxcount && *scan == cu) {
        count++;
        scan++;
      }
    }
    break;
  }

  case MULTIBYTECODE: {
    int i, len, cf = 0;

    // Safety check (just in case 'encoding' was changed since
    // compiling the program).
    if ((len = utfc_ptr2len((char *)opnd)) > 1) {
      if (rex.reg_ic) {
        cf = utf_fold(utf_ptr2char((char *)opnd));
      }
      while (count < maxcount && utfc_ptr2len((char *)scan) >= len) {
        for (i = 0; i < len; i++) {
          if (opnd[i] != scan[i]) {
            break;
          }
        }
        if (i < len && (!rex.reg_ic
                        || utf_fold(utf_ptr2char((char *)scan)) != cf)) {
          break;
        }
        scan += len;
        count++;
      }
    }
  }
  break;

  case ANYOF:
  case ANYOF + ADD_NL:
    testval = 1;
    FALLTHROUGH;

  case ANYBUT:
  case ANYBUT + ADD_NL:
    while (count < maxcount) {
      int len;
      if (*scan == NUL) {
        if (!REG_MULTI || !WITH_NL(OP(p)) || rex.lnum > rex.reg_maxline
            || rex.reg_line_lbr) {
          break;
        }
        reg_nextline();
        scan = rex.input;
        if (got_int) {
          break;
        }
      } else if (rex.reg_line_lbr && *scan == '\n' && WITH_NL(OP(p))) {
        scan++;
      } else if ((len = utfc_ptr2len((char *)scan)) > 1) {
        if ((cstrchr((char *)opnd, utf_ptr2char((char *)scan)) == NULL) == testval) {
          break;
        }
        scan += len;
      } else {
        if ((cstrchr((char *)opnd, *scan) == NULL) == testval) {
          break;
        }
        scan++;
      }
      count++;
    }
    break;

  case NEWL:
    while (count < maxcount
           && ((*scan == NUL && rex.lnum <= rex.reg_maxline && !rex.reg_line_lbr
                && REG_MULTI) || (*scan == '\n' && rex.reg_line_lbr))) {
      count++;
      if (rex.reg_line_lbr) {
        ADVANCE_REGINPUT();
      } else {
        reg_nextline();
      }
      scan = rex.input;
      if (got_int) {
        break;
      }
    }
    break;

  default:  // Oh dear.  Called inappropriately.
    iemsg(_(e_re_corr));
#ifdef REGEXP_DEBUG
    printf("Called regrepeat with op code %d\n", OP(p));
#endif
    break;
  }

  rex.input = scan;

  return (int)count;
}

// Push an item onto the regstack.
// Returns pointer to new item.  Returns NULL when out of memory.
static regitem_T *regstack_push(regstate_T state, uint8_t *scan)
{
  regitem_T *rp;

  if ((int64_t)((unsigned)regstack.ga_len >> 10) >= p_mmp) {
    emsg(_(e_pattern_uses_more_memory_than_maxmempattern));
    return NULL;
  }
  ga_grow(&regstack, sizeof(regitem_T));

  rp = (regitem_T *)((char *)regstack.ga_data + regstack.ga_len);
  rp->rs_state = state;
  rp->rs_scan = scan;

  regstack.ga_len += (int)sizeof(regitem_T);
  return rp;
}

// Pop an item from the regstack.
static void regstack_pop(uint8_t **scan)
{
  regitem_T *rp;

  rp = (regitem_T *)((char *)regstack.ga_data + regstack.ga_len) - 1;
  *scan = rp->rs_scan;

  regstack.ga_len -= (int)sizeof(regitem_T);
}

// Save the current subexpr to "bp", so that they can be restored
// later by restore_subexpr().
static void save_subexpr(regbehind_T *bp)
  FUNC_ATTR_NONNULL_ALL
{
  // When "rex.need_clear_subexpr" is set we don't need to save the values, only
  // remember that this flag needs to be set again when restoring.
  bp->save_need_clear_subexpr = rex.need_clear_subexpr;
  if (rex.need_clear_subexpr) {
    return;
  }

  for (int i = 0; i < NSUBEXP; i++) {
    if (REG_MULTI) {
      bp->save_start[i].se_u.pos = rex.reg_startpos[i];
      bp->save_end[i].se_u.pos = rex.reg_endpos[i];
    } else {
      bp->save_start[i].se_u.ptr = rex.reg_startp[i];
      bp->save_end[i].se_u.ptr = rex.reg_endp[i];
    }
  }
}

// Restore the subexpr from "bp".
static void restore_subexpr(regbehind_T *bp)
  FUNC_ATTR_NONNULL_ALL
{
  // Only need to restore saved values when they are not to be cleared.
  rex.need_clear_subexpr = bp->save_need_clear_subexpr;
  if (rex.need_clear_subexpr) {
    return;
  }

  for (int i = 0; i < NSUBEXP; i++) {
    if (REG_MULTI) {
      rex.reg_startpos[i] = bp->save_start[i].se_u.pos;
      rex.reg_endpos[i] = bp->save_end[i].se_u.pos;
    } else {
      rex.reg_startp[i] = bp->save_start[i].se_u.ptr;
      rex.reg_endp[i] = bp->save_end[i].se_u.ptr;
    }
  }
}
/// Main matching routine
///
/// Conceptually the strategy is simple: Check to see whether the current node
/// matches, push an item onto the regstack and loop to see whether the rest
/// matches, and then act accordingly.  In practice we make some effort to
/// avoid using the regstack, in particular by going through "ordinary" nodes
/// (that don't need to know whether the rest of the match failed) by a nested
/// loop.
///
/// @param scan       Current node.
/// @param tm         timeout limit or NULL
/// @param timed_out  flag set on timeout or NULL
///
/// @return - true when there is a match.  Leaves rex.input and rex.lnum
///         just after the last matched character.
///         - false when there is no match.  Leaves rex.input and rex.lnum in an
///         undefined state!
static bool regmatch(uint8_t *scan, const proftime_T *tm, int *timed_out)
{
  uint8_t *next;          // Next node.
  int op;
  int c;
  regitem_T *rp;
  int no;
  int status;                   // one of the RA_ values:
  int tm_count = 0;

  // Make "regstack" and "backpos" empty.  They are allocated and freed in
  // bt_regexec_both() to reduce malloc()/free() calls.
  regstack.ga_len = 0;
  backpos.ga_len = 0;

  // Repeat until "regstack" is empty.
  while (true) {
    // Some patterns may take a long time to match, e.g., "\([a-z]\+\)\+Q".
    // Allow interrupting them with CTRL-C.
    reg_breakcheck();

#ifdef REGEXP_DEBUG
    if (scan != NULL && regnarrate) {
      fprintf(stderr, "%s", (char *)regprop(scan));
      fprintf(stderr, "%s", "(\n");
    }
#endif

    // Repeat for items that can be matched sequentially, without using the
    // regstack.
    while (true) {
      if (got_int || scan == NULL) {
        status = RA_FAIL;
        break;
      }
      // Check for timeout once in a 100 times to avoid overhead.
      if (tm != NULL && ++tm_count == 100) {
        tm_count = 0;
        if (profile_passed_limit(*tm)) {
          if (timed_out != NULL) {
            *timed_out = true;
          }
          status = RA_FAIL;
          break;
        }
      }
      status = RA_CONT;

#ifdef REGEXP_DEBUG
      if (regnarrate) {
        fprintf(stderr, "%s", (char *)regprop(scan));
        fprintf(stderr, "%s", "...\n");
        if (re_extmatch_in != NULL) {
          int i;

          fprintf(stderr, _("External submatches:\n"));
          for (i = 0; i < NSUBEXP; i++) {
            fprintf(stderr, "%s", "    \"");
            if (re_extmatch_in->matches[i] != NULL) {
              fprintf(stderr, "%s", (char *)re_extmatch_in->matches[i]);
            }
            fprintf(stderr, "%s", "\"\n");
          }
        }
      }
#endif
      next = regnext(scan);

      op = OP(scan);
      // Check for character class with NL added.
      if (!rex.reg_line_lbr && WITH_NL(op) && REG_MULTI
          && *rex.input == NUL && rex.lnum <= rex.reg_maxline) {
        reg_nextline();
      } else if (rex.reg_line_lbr && WITH_NL(op) && *rex.input == '\n') {
        ADVANCE_REGINPUT();
      } else {
        if (WITH_NL(op)) {
          op -= ADD_NL;
        }
        c = utf_ptr2char((char *)rex.input);
        switch (op) {
        case BOL:
          if (rex.input != rex.line) {
            status = RA_NOMATCH;
          }
          break;

        case EOL:
          if (c != NUL) {
            status = RA_NOMATCH;
          }
          break;

        case RE_BOF:
          // We're not at the beginning of the file when below the first
          // line where we started, not at the start of the line or we
          // didn't start at the first line of the buffer.
          if (rex.lnum != 0 || rex.input != rex.line
              || (REG_MULTI && rex.reg_firstlnum > 1)) {
            status = RA_NOMATCH;
          }
          break;

        case RE_EOF:
          if (rex.lnum != rex.reg_maxline || c != NUL) {
            status = RA_NOMATCH;
          }
          break;

        case CURSOR:
          // Check if the buffer is in a window and compare the
          // rex.reg_win->w_cursor position to the match position.
          if (rex.reg_win == NULL
              || (rex.lnum + rex.reg_firstlnum != rex.reg_win->w_cursor.lnum)
              || ((colnr_T)(rex.input - rex.line) !=
                  rex.reg_win->w_cursor.col)) {
            status = RA_NOMATCH;
          }
          break;

        case RE_MARK:
          // Compare the mark position to the match position.
        {
          int mark = OPERAND(scan)[0];
          int cmp = OPERAND(scan)[1];
          pos_T *pos;
          size_t col = REG_MULTI ? (size_t)(rex.input - rex.line) : 0;
          fmark_T *fm = mark_get(rex.reg_buf, curwin, NULL, kMarkBufLocal, mark);

          // Line may have been freed, get it again.
          if (REG_MULTI) {
            rex.line = (uint8_t *)reg_getline(rex.lnum);
            rex.input = rex.line + col;
          }

          if (fm == NULL                    // mark doesn't exist
              || fm->mark.lnum <= 0) {           // mark isn't set in reg_buf
            status = RA_NOMATCH;
          } else {
            pos = &fm->mark;
            const colnr_T pos_col = pos->lnum == rex.lnum + rex.reg_firstlnum
                                    && pos->col == MAXCOL
                                    ? reg_getline_len(pos->lnum - rex.reg_firstlnum)
                                    : pos->col;

            if (pos->lnum == rex.lnum + rex.reg_firstlnum
                ? (pos_col == (colnr_T)(rex.input - rex.line)
                   ? (cmp == '<' || cmp == '>')
                   : (pos_col < (colnr_T)(rex.input - rex.line)
                      ? cmp != '>'
                      : cmp != '<'))
                : (pos->lnum < rex.lnum + rex.reg_firstlnum
                   ? cmp != '>'
                   : cmp != '<')) {
              status = RA_NOMATCH;
            }
          }
        }
        break;

        case RE_VISUAL:
          if (!reg_match_visual()) {
            status = RA_NOMATCH;
          }
          break;

        case RE_LNUM:
          assert(rex.lnum + rex.reg_firstlnum >= 0
                 && (uintmax_t)(rex.lnum + rex.reg_firstlnum) <= UINT32_MAX);
          if (!REG_MULTI
              || !re_num_cmp((uint32_t)(rex.lnum + rex.reg_firstlnum), scan)) {
            status = RA_NOMATCH;
          }
          break;

        case RE_COL:
          assert(rex.input - rex.line + 1 >= 0
                 && (uintmax_t)(rex.input - rex.line + 1) <= UINT32_MAX);
          if (!re_num_cmp((uint32_t)(rex.input - rex.line + 1), scan)) {
            status = RA_NOMATCH;
          }
          break;

        case RE_VCOL: {
          win_T *wp = rex.reg_win == NULL ? curwin : rex.reg_win;
          linenr_T lnum = REG_MULTI ? rex.reg_firstlnum + rex.lnum : 1;
          if (REG_MULTI && (lnum <= 0 || lnum > wp->w_buffer->b_ml.ml_line_count)) {
            lnum = 1;
          }
          int vcol = win_linetabsize(wp, lnum, (char *)rex.line,
                                     (colnr_T)(rex.input - rex.line));
          if (!re_num_cmp((uint32_t)vcol + 1, scan)) {
            status = RA_NOMATCH;
          }
          break;
        }
        break;

        case BOW:  // \<word; rex.input points to w
          if (c == NUL) {  // Can't match at end of line
            status = RA_NOMATCH;
          } else {
            // Get class of current and previous char (if it exists).
            const int this_class =
              mb_get_class_tab((char *)rex.input, rex.reg_buf->b_chartab);
            if (this_class <= 1) {
              status = RA_NOMATCH;  // Not on a word at all.
            } else if (reg_prev_class() == this_class) {
              status = RA_NOMATCH;  // Previous char is in same word.
            }
          }
          break;

        case EOW:  // word\>; rex.input points after d
          if (rex.input == rex.line) {  // Can't match at start of line
            status = RA_NOMATCH;
          } else {
            int this_class, prev_class;

            // Get class of current and previous char (if it exists).
            this_class = mb_get_class_tab((char *)rex.input, rex.reg_buf->b_chartab);
            prev_class = reg_prev_class();
            if (this_class == prev_class
                || prev_class == 0 || prev_class == 1) {
              status = RA_NOMATCH;
            }
          }
          break;  // Matched with EOW

        case ANY:
          // ANY does not match new lines.
          if (c == NUL) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case IDENT:
          if (!vim_isIDc(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case SIDENT:
          if (ascii_isdigit(*rex.input) || !vim_isIDc(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case KWORD:
          if (!vim_iswordp_buf((char *)rex.input, rex.reg_buf)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case SKWORD:
          if (ascii_isdigit(*rex.input)
              || !vim_iswordp_buf((char *)rex.input, rex.reg_buf)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case FNAME:
          if (!vim_isfilec(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case SFNAME:
          if (ascii_isdigit(*rex.input) || !vim_isfilec(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case PRINT:
          if (!vim_isprintc(utf_ptr2char((char *)rex.input))) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case SPRINT:
          if (ascii_isdigit(*rex.input) || !vim_isprintc(utf_ptr2char((char *)rex.input))) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case WHITE:
          if (!ascii_iswhite(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case NWHITE:
          if (c == NUL || ascii_iswhite(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case DIGIT:
          if (!ri_digit(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case NDIGIT:
          if (c == NUL || ri_digit(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case HEX:
          if (!ri_hex(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case NHEX:
          if (c == NUL || ri_hex(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case OCTAL:
          if (!ri_octal(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case NOCTAL:
          if (c == NUL || ri_octal(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case WORD:
          if (!ri_word(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case NWORD:
          if (c == NUL || ri_word(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case HEAD:
          if (!ri_head(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case NHEAD:
          if (c == NUL || ri_head(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case ALPHA:
          if (!ri_alpha(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case NALPHA:
          if (c == NUL || ri_alpha(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case LOWER:
          if (!ri_lower(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case NLOWER:
          if (c == NUL || ri_lower(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case UPPER:
          if (!ri_upper(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case NUPPER:
          if (c == NUL || ri_upper(c)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case EXACTLY: {
          int len;
          uint8_t *opnd;

          opnd = OPERAND(scan);
          // Inline the first byte, for speed.
          if (*opnd != *rex.input
              && (!rex.reg_ic)) {
            status = RA_NOMATCH;
          } else if (*opnd == NUL) {
            // match empty string always works; happens when "~" is
            // empty.
          } else {
            if (opnd[1] == NUL && !rex.reg_ic) {
              len = 1;  // matched a single byte above
            } else {
              // Need to match first byte again for multi-byte.
              len = (int)strlen((char *)opnd);
              if (cstrncmp((char *)opnd, (char *)rex.input, &len) != 0) {
                status = RA_NOMATCH;
              }
            }
            // Check for following composing character, unless %C
            // follows (skips over all composing chars).
            if (status != RA_NOMATCH
                && utf_composinglike((char *)rex.input, (char *)rex.input + len)
                && !rex.reg_icombine
                && OP(next) != RE_COMPOSING) {
              // raaron: This code makes a composing character get
              // ignored, which is the correct behavior (sometimes)
              // for voweled Hebrew texts.
              status = RA_NOMATCH;
            }
            if (status != RA_NOMATCH) {
              rex.input += len;
            }
          }
        }
        break;

        case ANYOF:
        case ANYBUT: {
          uint8_t *q = OPERAND(scan);

          if (c == NUL) {
            status = RA_NOMATCH;
          } else if ((cstrchr((char *)q, c) == NULL) == (op == ANYOF)) {
            status = RA_NOMATCH;
          } else {  // Check following combining characters
            int len = utfc_ptr2len((char *)q) - utf_ptr2len((char *)q);

            rex.input += utf_ptr2len((char *)rex.input);
            q += utf_ptr2len((char *)q);

            if (len == 0) {
              break;
            }

            for (int i = 0; i < len; i++) {
              if (q[i] != rex.input[i]) {
                status = RA_NOMATCH;
                break;
              }
            }
            rex.input += len;
          }
          break;
        }

        case MULTIBYTECODE: {
          int i, len;

          const uint8_t *opnd = OPERAND(scan);
          // Safety check (just in case 'encoding' was changed since
          // compiling the program).
          if ((len = utfc_ptr2len((char *)opnd)) < 2) {
            status = RA_NOMATCH;
            break;
          }
          const int opndc = utf_ptr2char((char *)opnd);
          if (utf_iscomposing(opndc)) {
            // When only a composing char is given match at any
            // position where that composing char appears.
            status = RA_NOMATCH;
            for (i = 0; rex.input[i] != NUL;
                 i += utf_ptr2len((char *)rex.input + i)) {
              const int inpc = utf_ptr2char((char *)rex.input + i);
              if (!utf_iscomposing(inpc)) {
                if (i > 0) {
                  break;
                }
              } else if (opndc == inpc) {
                // Include all following composing chars.
                len = i + utfc_ptr2len((char *)rex.input + i);
                status = RA_MATCH;
                break;
              }
            }
          } else {
            if (cstrncmp((char *)opnd, (char *)rex.input, &len) != 0) {
              status = RA_NOMATCH;
              break;
            }
          }
          rex.input += len;
        }
        break;

        case RE_COMPOSING:
          // Skip composing characters.
          while (utf_iscomposing(utf_ptr2char((char *)rex.input))) {
            rex.input += utf_ptr2len((char *)rex.input);
          }
          break;

        case NOTHING:
          break;

        case BACK: {
          int i;

          // When we run into BACK we need to check if we don't keep
          // looping without matching any input.  The second and later
          // times a BACK is encountered it fails if the input is still
          // at the same position as the previous time.
          // The positions are stored in "backpos" and found by the
          // current value of "scan", the position in the RE program.
          backpos_T *bp = (backpos_T *)backpos.ga_data;
          for (i = 0; i < backpos.ga_len; i++) {
            if (bp[i].bp_scan == scan) {
              break;
            }
          }
          if (i == backpos.ga_len) {
            backpos_T *p = GA_APPEND_VIA_PTR(backpos_T, &backpos);
            p->bp_scan = scan;
          } else if (reg_save_equal(&bp[i].bp_pos)) {
            // Still at same position as last time, fail.
            status = RA_NOMATCH;
          }

          assert(status != RA_FAIL);
          if (status != RA_NOMATCH) {
            reg_save(&bp[i].bp_pos, &backpos);
          }
        }
        break;

        case MOPEN + 0:     // Match start: \zs
        case MOPEN + 1:     // \(
        case MOPEN + 2:
        case MOPEN + 3:
        case MOPEN + 4:
        case MOPEN + 5:
        case MOPEN + 6:
        case MOPEN + 7:
        case MOPEN + 8:
        case MOPEN + 9:
          no = op - MOPEN;
          cleanup_subexpr();
          rp = regstack_push(RS_MOPEN, scan);
          if (rp == NULL) {
            status = RA_FAIL;
          } else {
            rp->rs_no = (int16_t)no;
            save_se(&rp->rs_un.sesave, &rex.reg_startpos[no],
                    &rex.reg_startp[no]);
            // We simply continue and handle the result when done.
          }
          break;

        case NOPEN:         // \%(
        case NCLOSE:        // \) after \%(
          if (regstack_push(RS_NOPEN, scan) == NULL) {
            status = RA_FAIL;
          }
          // We simply continue and handle the result when done.
          break;

        case ZOPEN + 1:
        case ZOPEN + 2:
        case ZOPEN + 3:
        case ZOPEN + 4:
        case ZOPEN + 5:
        case ZOPEN + 6:
        case ZOPEN + 7:
        case ZOPEN + 8:
        case ZOPEN + 9:
          no = op - ZOPEN;
          cleanup_zsubexpr();
          rp = regstack_push(RS_ZOPEN, scan);
          if (rp == NULL) {
            status = RA_FAIL;
          } else {
            rp->rs_no = (int16_t)no;
            save_se(&rp->rs_un.sesave, &reg_startzpos[no],
                    &reg_startzp[no]);
            // We simply continue and handle the result when done.
          }
          break;

        case MCLOSE + 0:    // Match end: \ze
        case MCLOSE + 1:    // \)
        case MCLOSE + 2:
        case MCLOSE + 3:
        case MCLOSE + 4:
        case MCLOSE + 5:
        case MCLOSE + 6:
        case MCLOSE + 7:
        case MCLOSE + 8:
        case MCLOSE + 9:
          no = op - MCLOSE;
          cleanup_subexpr();
          rp = regstack_push(RS_MCLOSE, scan);
          if (rp == NULL) {
            status = RA_FAIL;
          } else {
            rp->rs_no = (int16_t)no;
            save_se(&rp->rs_un.sesave, &rex.reg_endpos[no], &rex.reg_endp[no]);
            // We simply continue and handle the result when done.
          }
          break;

        case ZCLOSE + 1:    // \) after \z(
        case ZCLOSE + 2:
        case ZCLOSE + 3:
        case ZCLOSE + 4:
        case ZCLOSE + 5:
        case ZCLOSE + 6:
        case ZCLOSE + 7:
        case ZCLOSE + 8:
        case ZCLOSE + 9:
          no = op - ZCLOSE;
          cleanup_zsubexpr();
          rp = regstack_push(RS_ZCLOSE, scan);
          if (rp == NULL) {
            status = RA_FAIL;
          } else {
            rp->rs_no = (int16_t)no;
            save_se(&rp->rs_un.sesave, &reg_endzpos[no],
                    &reg_endzp[no]);
            // We simply continue and handle the result when done.
          }
          break;

        case BACKREF + 1:
        case BACKREF + 2:
        case BACKREF + 3:
        case BACKREF + 4:
        case BACKREF + 5:
        case BACKREF + 6:
        case BACKREF + 7:
        case BACKREF + 8:
        case BACKREF + 9: {
          int len;

          no = op - BACKREF;
          cleanup_subexpr();
          if (!REG_MULTI) {  // Single-line regexp
            if (rex.reg_startp[no] == NULL || rex.reg_endp[no] == NULL) {
              // Backref was not set: Match an empty string.
              len = 0;
            } else {
              // Compare current input with back-ref in the same line.
              len = (int)(rex.reg_endp[no] - rex.reg_startp[no]);
              if (cstrncmp((char *)rex.reg_startp[no], (char *)rex.input, &len) != 0) {
                status = RA_NOMATCH;
              }
            }
          } else {  // Multi-line regexp
            if (rex.reg_startpos[no].lnum < 0 || rex.reg_endpos[no].lnum < 0) {
              // Backref was not set: Match an empty string.
              len = 0;
            } else {
              if (rex.reg_startpos[no].lnum == rex.lnum
                  && rex.reg_endpos[no].lnum == rex.lnum) {
                // Compare back-ref within the current line.
                len = rex.reg_endpos[no].col - rex.reg_startpos[no].col;
                if (cstrncmp((char *)rex.line + rex.reg_startpos[no].col,
                             (char *)rex.input, &len) != 0) {
                  status = RA_NOMATCH;
                }
              } else {
                // Messy situation: Need to compare between two lines.
                int r = match_with_backref(rex.reg_startpos[no].lnum,
                                           rex.reg_startpos[no].col,
                                           rex.reg_endpos[no].lnum,
                                           rex.reg_endpos[no].col,
                                           &len);
                if (r != RA_MATCH) {
                  status = r;
                }
              }
            }
          }

          // Matched the backref, skip over it.
          rex.input += len;
        }
        break;

        case ZREF + 1:
        case ZREF + 2:
        case ZREF + 3:
        case ZREF + 4:
        case ZREF + 5:
        case ZREF + 6:
        case ZREF + 7:
        case ZREF + 8:
        case ZREF + 9:
          cleanup_zsubexpr();
          no = op - ZREF;
          if (re_extmatch_in != NULL
              && re_extmatch_in->matches[no] != NULL) {
            int len = (int)strlen((char *)re_extmatch_in->matches[no]);
            if (cstrncmp((char *)re_extmatch_in->matches[no], (char *)rex.input, &len) != 0) {
              status = RA_NOMATCH;
            } else {
              rex.input += len;
            }
          } else {
            // Backref was not set: Match an empty string.
          }
          break;

        case BRANCH:
          if (OP(next) != BRANCH) {     // No choice.
            next = OPERAND(scan);               // Avoid recursion.
          } else {
            rp = regstack_push(RS_BRANCH, scan);
            if (rp == NULL) {
              status = RA_FAIL;
            } else {
              status = RA_BREAK;                // rest is below
            }
          }
          break;

        case BRACE_LIMITS:
          if (OP(next) == BRACE_SIMPLE) {
            bl_minval = OPERAND_MIN(scan);
            bl_maxval = OPERAND_MAX(scan);
          } else if (OP(next) >= BRACE_COMPLEX
                     && OP(next) < BRACE_COMPLEX + 10) {
            no = OP(next) - BRACE_COMPLEX;
            brace_min[no] = OPERAND_MIN(scan);
            brace_max[no] = OPERAND_MAX(scan);
            brace_count[no] = 0;
          } else {
            internal_error("BRACE_LIMITS");
            status = RA_FAIL;
          }
          break;

        case BRACE_COMPLEX + 0:
        case BRACE_COMPLEX + 1:
        case BRACE_COMPLEX + 2:
        case BRACE_COMPLEX + 3:
        case BRACE_COMPLEX + 4:
        case BRACE_COMPLEX + 5:
        case BRACE_COMPLEX + 6:
        case BRACE_COMPLEX + 7:
        case BRACE_COMPLEX + 8:
        case BRACE_COMPLEX + 9:
          no = op - BRACE_COMPLEX;
          brace_count[no]++;

          // If not matched enough times yet, try one more
          if (brace_count[no] <= (brace_min[no] <= brace_max[no]
                                  ? brace_min[no] : brace_max[no])) {
            rp = regstack_push(RS_BRCPLX_MORE, scan);
            if (rp == NULL) {
              status = RA_FAIL;
            } else {
              rp->rs_no = (int16_t)no;
              reg_save(&rp->rs_un.regsave, &backpos);
              next = OPERAND(scan);
              // We continue and handle the result when done.
            }
            break;
          }

          // If matched enough times, may try matching some more
          if (brace_min[no] <= brace_max[no]) {
            // Range is the normal way around, use longest match
            if (brace_count[no] <= brace_max[no]) {
              rp = regstack_push(RS_BRCPLX_LONG, scan);
              if (rp == NULL) {
                status = RA_FAIL;
              } else {
                rp->rs_no = (int16_t)no;
                reg_save(&rp->rs_un.regsave, &backpos);
                next = OPERAND(scan);
                // We continue and handle the result when done.
              }
            }
          } else {
            // Range is backwards, use shortest match first
            if (brace_count[no] <= brace_min[no]) {
              rp = regstack_push(RS_BRCPLX_SHORT, scan);
              if (rp == NULL) {
                status = RA_FAIL;
              } else {
                reg_save(&rp->rs_un.regsave, &backpos);
                // We continue and handle the result when done.
              }
            }
          }
          break;

        case BRACE_SIMPLE:
        case STAR:
        case PLUS: {
          regstar_T rst;

          // Lookahead to avoid useless match attempts when we know
          // what character comes next.
          if (OP(next) == EXACTLY) {
            rst.nextb = *OPERAND(next);
            if (rex.reg_ic) {
              if (mb_isupper(rst.nextb)) {
                rst.nextb_ic = mb_tolower(rst.nextb);
              } else {
                rst.nextb_ic = mb_toupper(rst.nextb);
              }
            } else {
              rst.nextb_ic = rst.nextb;
            }
          } else {
            rst.nextb = NUL;
            rst.nextb_ic = NUL;
          }
          if (op != BRACE_SIMPLE) {
            rst.minval = (op == STAR) ? 0 : 1;
            rst.maxval = MAX_LIMIT;
          } else {
            rst.minval = bl_minval;
            rst.maxval = bl_maxval;
          }

          // When maxval > minval, try matching as much as possible, up
          // to maxval.  When maxval < minval, try matching at least the
          // minimal number (since the range is backwards, that's also
          // maxval!).
          rst.count = regrepeat(OPERAND(scan), rst.maxval);
          if (got_int) {
            status = RA_FAIL;
            break;
          }
          if (rst.minval <= rst.maxval
              ? rst.count >= rst.minval : rst.count >= rst.maxval) {
            // It could match.  Prepare for trying to match what
            // follows.  The code is below.  Parameters are stored in
            // a regstar_T on the regstack.
            if ((int64_t)((unsigned)regstack.ga_len >> 10) >= p_mmp) {
              emsg(_(e_pattern_uses_more_memory_than_maxmempattern));
              status = RA_FAIL;
            } else {
              ga_grow(&regstack, sizeof(regstar_T));
              regstack.ga_len += (int)sizeof(regstar_T);
              rp = regstack_push(rst.minval <= rst.maxval ? RS_STAR_LONG : RS_STAR_SHORT, scan);
              if (rp == NULL) {
                status = RA_FAIL;
              } else {
                *(((regstar_T *)rp) - 1) = rst;
                status = RA_BREAK;                  // skip the restore bits
              }
            }
          } else {
            status = RA_NOMATCH;
          }
        }
        break;

        case NOMATCH:
        case MATCH:
        case SUBPAT:
          rp = regstack_push(RS_NOMATCH, scan);
          if (rp == NULL) {
            status = RA_FAIL;
          } else {
            rp->rs_no = (int16_t)op;
            reg_save(&rp->rs_un.regsave, &backpos);
            next = OPERAND(scan);
            // We continue and handle the result when done.
          }
          break;

        case BEHIND:
        case NOBEHIND:
          // Need a bit of room to store extra positions.
          if ((int64_t)((unsigned)regstack.ga_len >> 10) >= p_mmp) {
            emsg(_(e_pattern_uses_more_memory_than_maxmempattern));
            status = RA_FAIL;
          } else {
            ga_grow(&regstack, sizeof(regbehind_T));
            regstack.ga_len += (int)sizeof(regbehind_T);
            rp = regstack_push(RS_BEHIND1, scan);
            if (rp == NULL) {
              status = RA_FAIL;
            } else {
              // Need to save the subexpr to be able to restore them
              // when there is a match but we don't use it.
              save_subexpr(((regbehind_T *)rp) - 1);

              rp->rs_no = (int16_t)op;
              reg_save(&rp->rs_un.regsave, &backpos);
              // First try if what follows matches.  If it does then we
              // check the behind match by looping.
            }
          }
          break;

        case BHPOS:
          if (REG_MULTI) {
            if (behind_pos.rs_u.pos.col != (colnr_T)(rex.input - rex.line)
                || behind_pos.rs_u.pos.lnum != rex.lnum) {
              status = RA_NOMATCH;
            }
          } else if (behind_pos.rs_u.ptr != rex.input) {
            status = RA_NOMATCH;
          }
          break;

        case NEWL:
          if ((c != NUL || !REG_MULTI || rex.lnum > rex.reg_maxline
               || rex.reg_line_lbr) && (c != '\n' || !rex.reg_line_lbr)) {
            status = RA_NOMATCH;
          } else if (rex.reg_line_lbr) {
            ADVANCE_REGINPUT();
          } else {
            reg_nextline();
          }
          break;

        case END:
          status = RA_MATCH;    // Success!
          break;

        default:
          iemsg(_(e_re_corr));
#ifdef REGEXP_DEBUG
          printf("Illegal op code %d\n", op);
#endif
          status = RA_FAIL;
          break;
        }
      }

      // If we can't continue sequentially, break the inner loop.
      if (status != RA_CONT) {
        break;
      }

      // Continue in inner loop, advance to next item.
      scan = next;
    }  // end of inner loop

    // If there is something on the regstack execute the code for the state.
    // If the state is popped then loop and use the older state.
    while (!GA_EMPTY(&regstack) && status != RA_FAIL) {
      rp = (regitem_T *)((char *)regstack.ga_data + regstack.ga_len) - 1;
      switch (rp->rs_state) {
      case RS_NOPEN:
        // Result is passed on as-is, simply pop the state.
        regstack_pop(&scan);
        break;

      case RS_MOPEN:
        // Pop the state.  Restore pointers when there is no match.
        if (status == RA_NOMATCH) {
          restore_se(&rp->rs_un.sesave, &rex.reg_startpos[rp->rs_no],
                     &rex.reg_startp[rp->rs_no]);
        }
        regstack_pop(&scan);
        break;

      case RS_ZOPEN:
        // Pop the state.  Restore pointers when there is no match.
        if (status == RA_NOMATCH) {
          restore_se(&rp->rs_un.sesave, &reg_startzpos[rp->rs_no],
                     &reg_startzp[rp->rs_no]);
        }
        regstack_pop(&scan);
        break;

      case RS_MCLOSE:
        // Pop the state.  Restore pointers when there is no match.
        if (status == RA_NOMATCH) {
          restore_se(&rp->rs_un.sesave, &rex.reg_endpos[rp->rs_no],
                     &rex.reg_endp[rp->rs_no]);
        }
        regstack_pop(&scan);
        break;

      case RS_ZCLOSE:
        // Pop the state.  Restore pointers when there is no match.
        if (status == RA_NOMATCH) {
          restore_se(&rp->rs_un.sesave, &reg_endzpos[rp->rs_no],
                     &reg_endzp[rp->rs_no]);
        }
        regstack_pop(&scan);
        break;

      case RS_BRANCH:
        if (status == RA_MATCH) {
          // this branch matched, use it
          regstack_pop(&scan);
        } else {
          if (status != RA_BREAK) {
            // After a non-matching branch: try next one.
            reg_restore(&rp->rs_un.regsave, &backpos);
            scan = rp->rs_scan;
          }
          if (scan == NULL || OP(scan) != BRANCH) {
            // no more branches, didn't find a match
            status = RA_NOMATCH;
            regstack_pop(&scan);
          } else {
            // Prepare to try a branch.
            rp->rs_scan = regnext(scan);
            reg_save(&rp->rs_un.regsave, &backpos);
            scan = OPERAND(scan);
          }
        }
        break;

      case RS_BRCPLX_MORE:
        // Pop the state.  Restore pointers when there is no match.
        if (status == RA_NOMATCH) {
          reg_restore(&rp->rs_un.regsave, &backpos);
          brace_count[rp->rs_no]--;             // decrement match count
        }
        regstack_pop(&scan);
        break;

      case RS_BRCPLX_LONG:
        // Pop the state.  Restore pointers when there is no match.
        if (status == RA_NOMATCH) {
          // There was no match, but we did find enough matches.
          reg_restore(&rp->rs_un.regsave, &backpos);
          brace_count[rp->rs_no]--;
          // continue with the items after "\{}"
          status = RA_CONT;
        }
        regstack_pop(&scan);
        if (status == RA_CONT) {
          scan = regnext(scan);
        }
        break;

      case RS_BRCPLX_SHORT:
        // Pop the state.  Restore pointers when there is no match.
        if (status == RA_NOMATCH) {
          // There was no match, try to match one more item.
          reg_restore(&rp->rs_un.regsave, &backpos);
        }
        regstack_pop(&scan);
        if (status == RA_NOMATCH) {
          scan = OPERAND(scan);
          status = RA_CONT;
        }
        break;

      case RS_NOMATCH:
        // Pop the state.  If the operand matches for NOMATCH or
        // doesn't match for MATCH/SUBPAT, we fail.  Otherwise backup,
        // except for SUBPAT, and continue with the next item.
        if (status == (rp->rs_no == NOMATCH ? RA_MATCH : RA_NOMATCH)) {
          status = RA_NOMATCH;
        } else {
          status = RA_CONT;
          if (rp->rs_no != SUBPAT) {            // zero-width
            reg_restore(&rp->rs_un.regsave, &backpos);
          }
        }
        regstack_pop(&scan);
        if (status == RA_CONT) {
          scan = regnext(scan);
        }
        break;

      case RS_BEHIND1:
        if (status == RA_NOMATCH) {
          regstack_pop(&scan);
          regstack.ga_len -= (int)sizeof(regbehind_T);
        } else {
          // The stuff after BEHIND/NOBEHIND matches.  Now try if
          // the behind part does (not) match before the current
          // position in the input.  This must be done at every
          // position in the input and checking if the match ends at
          // the current position.

          // save the position after the found match for next
          reg_save(&(((regbehind_T *)rp) - 1)->save_after, &backpos);

          // Start looking for a match with operand at the current
          // position.  Go back one character until we find the
          // result, hitting the start of the line or the previous
          // line (for multi-line matching).
          // Set behind_pos to where the match should end, BHPOS
          // will match it.  Save the current value.
          (((regbehind_T *)rp) - 1)->save_behind = behind_pos;
          behind_pos = rp->rs_un.regsave;

          rp->rs_state = RS_BEHIND2;

          reg_restore(&rp->rs_un.regsave, &backpos);
          scan = OPERAND(rp->rs_scan) + 4;
        }
        break;

      case RS_BEHIND2:
        // Looping for BEHIND / NOBEHIND match.
        if (status == RA_MATCH && reg_save_equal(&behind_pos)) {
          // found a match that ends where "next" started
          behind_pos = (((regbehind_T *)rp) - 1)->save_behind;
          if (rp->rs_no == BEHIND) {
            reg_restore(&(((regbehind_T *)rp) - 1)->save_after,
                        &backpos);
          } else {
            // But we didn't want a match.  Need to restore the
            // subexpr, because what follows matched, so they have
            // been set.
            status = RA_NOMATCH;
            restore_subexpr(((regbehind_T *)rp) - 1);
          }
          regstack_pop(&scan);
          regstack.ga_len -= (int)sizeof(regbehind_T);
        } else {
          int64_t limit;

          // No match or a match that doesn't end where we want it: Go
          // back one character.  May go to previous line once.
          no = OK;
          limit = OPERAND_MIN(rp->rs_scan);
          if (REG_MULTI) {
            if (limit > 0
                && ((rp->rs_un.regsave.rs_u.pos.lnum
                     < behind_pos.rs_u.pos.lnum
                     ? (colnr_T)strlen((char *)rex.line)
                     : behind_pos.rs_u.pos.col)
                    - rp->rs_un.regsave.rs_u.pos.col >= limit)) {
              no = FAIL;
            } else if (rp->rs_un.regsave.rs_u.pos.col == 0) {
              if (rp->rs_un.regsave.rs_u.pos.lnum
                  < behind_pos.rs_u.pos.lnum
                  || reg_getline(--rp->rs_un.regsave.rs_u.pos.lnum)
                  == NULL) {
                no = FAIL;
              } else {
                reg_restore(&rp->rs_un.regsave, &backpos);
                rp->rs_un.regsave.rs_u.pos.col =
                  (colnr_T)strlen((char *)rex.line);
              }
            } else {
              const uint8_t *const line =
                (uint8_t *)reg_getline(rp->rs_un.regsave.rs_u.pos.lnum);

              rp->rs_un.regsave.rs_u.pos.col -=
                utf_head_off((char *)line,
                             (char *)line + rp->rs_un.regsave.rs_u.pos.col - 1)
                + 1;
            }
          } else {
            if (rp->rs_un.regsave.rs_u.ptr == rex.line) {
              no = FAIL;
            } else {
              MB_PTR_BACK(rex.line, rp->rs_un.regsave.rs_u.ptr);
              if (limit > 0
                  && (behind_pos.rs_u.ptr - rp->rs_un.regsave.rs_u.ptr) > (ptrdiff_t)limit) {
                no = FAIL;
              }
            }
          }
          if (no == OK) {
            // Advanced, prepare for finding match again.
            reg_restore(&rp->rs_un.regsave, &backpos);
            scan = OPERAND(rp->rs_scan) + 4;
            if (status == RA_MATCH) {
              // We did match, so subexpr may have been changed,
              // need to restore them for the next try.
              status = RA_NOMATCH;
              restore_subexpr(((regbehind_T *)rp) - 1);
            }
          } else {
            // Can't advance.  For NOBEHIND that's a match.
            behind_pos = (((regbehind_T *)rp) - 1)->save_behind;
            if (rp->rs_no == NOBEHIND) {
              reg_restore(&(((regbehind_T *)rp) - 1)->save_after,
                          &backpos);
              status = RA_MATCH;
            } else {
              // We do want a proper match.  Need to restore the
              // subexpr if we had a match, because they may have
              // been set.
              if (status == RA_MATCH) {
                status = RA_NOMATCH;
                restore_subexpr(((regbehind_T *)rp) - 1);
              }
            }
            regstack_pop(&scan);
            regstack.ga_len -= (int)sizeof(regbehind_T);
          }
        }
        break;

      case RS_STAR_LONG:
      case RS_STAR_SHORT: {
        regstar_T *rst = ((regstar_T *)rp) - 1;

        if (status == RA_MATCH) {
          regstack_pop(&scan);
          regstack.ga_len -= (int)sizeof(regstar_T);
          break;
        }

        // Tried once already, restore input pointers.
        if (status != RA_BREAK) {
          reg_restore(&rp->rs_un.regsave, &backpos);
        }

        // Repeat until we found a position where it could match.
        while (true) {
          if (status != RA_BREAK) {
            // Tried first position already, advance.
            if (rp->rs_state == RS_STAR_LONG) {
              // Trying for longest match, but couldn't or
              // didn't match -- back up one char.
              if (--rst->count < rst->minval) {
                break;
              }
              if (rex.input == rex.line) {
                // backup to last char of previous line
                if (rex.lnum == 0) {
                  status = RA_NOMATCH;
                  break;
                }
                rex.lnum--;
                rex.line = (uint8_t *)reg_getline(rex.lnum);
                // Just in case regrepeat() didn't count right.
                if (rex.line == NULL) {
                  break;
                }
                rex.input = rex.line + reg_getline_len(rex.lnum);
                reg_breakcheck();
              } else {
                MB_PTR_BACK(rex.line, rex.input);
              }
            } else {
              // Range is backwards, use shortest match first.
              // Careful: maxval and minval are exchanged!
              // Couldn't or didn't match: try advancing one
              // char.
              if (rst->count == rst->minval
                  || regrepeat(OPERAND(rp->rs_scan), 1L) == 0) {
                break;
              }
              rst->count++;
            }
            if (got_int) {
              break;
            }
          } else {
            status = RA_NOMATCH;
          }

          // If it could match, try it.
          if (rst->nextb == NUL || *rex.input == rst->nextb
              || *rex.input == rst->nextb_ic) {
            reg_save(&rp->rs_un.regsave, &backpos);
            scan = regnext(rp->rs_scan);
            status = RA_CONT;
            break;
          }
        }
        if (status != RA_CONT) {
          // Failed.
          regstack_pop(&scan);
          regstack.ga_len -= (int)sizeof(regstar_T);
          status = RA_NOMATCH;
        }
      }
      break;
      }

      // If we want to continue the inner loop or didn't pop a state
      // continue matching loop
      if (status == RA_CONT || rp == (regitem_T *)
          ((char *)regstack.ga_data + regstack.ga_len) - 1) {
        break;
      }
    }

    // May need to continue with the inner loop, starting at "scan".
    if (status == RA_CONT) {
      continue;
    }

    // If the regstack is empty or something failed we are done.
    if (GA_EMPTY(&regstack) || status == RA_FAIL) {
      if (scan == NULL) {
        // We get here only if there's trouble -- normally "case END" is
        // the terminating point.
        iemsg(_(e_re_corr));
#ifdef REGEXP_DEBUG
        printf("Premature EOL\n");
#endif
      }
      return status == RA_MATCH;
    }
  }  // End of loop until the regstack is empty.

  // NOTREACHED
}

/// Try match of "prog" with at rex.line["col"].
///
/// @param tm         timeout limit or NULL
/// @param timed_out  flag set on timeout or NULL
///
/// @return  0 for failure, or number of lines contained in the match.
static int regtry(bt_regprog_T *prog, colnr_T col, proftime_T *tm, int *timed_out)
{
  rex.input = rex.line + col;
  rex.need_clear_subexpr = true;
  // Clear the external match subpointers if necessaey.
  rex.need_clear_zsubexpr = (prog->reghasz == REX_SET);

  if (regmatch(&prog->program[1], tm, timed_out) == 0) {
    return 0;
  }

  cleanup_subexpr();
  if (REG_MULTI) {
    if (rex.reg_startpos[0].lnum < 0) {
      rex.reg_startpos[0].lnum = 0;
      rex.reg_startpos[0].col = col;
    }
    if (rex.reg_endpos[0].lnum < 0) {
      rex.reg_endpos[0].lnum = rex.lnum;
      rex.reg_endpos[0].col = (int)(rex.input - rex.line);
    } else {
      // Use line number of "\ze".
      rex.lnum = rex.reg_endpos[0].lnum;
    }
  } else {
    if (rex.reg_startp[0] == NULL) {
      rex.reg_startp[0] = rex.line + col;
    }
    if (rex.reg_endp[0] == NULL) {
      rex.reg_endp[0] = rex.input;
    }
  }
  // Package any found \z(...\) matches for export. Default is none.
  unref_extmatch(re_extmatch_out);
  re_extmatch_out = NULL;

  if (prog->reghasz == REX_SET) {
    int i;

    cleanup_zsubexpr();
    re_extmatch_out = make_extmatch();
    for (i = 0; i < NSUBEXP; i++) {
      if (REG_MULTI) {
        // Only accept single line matches.
        if (reg_startzpos[i].lnum >= 0
            && reg_endzpos[i].lnum == reg_startzpos[i].lnum
            && reg_endzpos[i].col >= reg_startzpos[i].col) {
          re_extmatch_out->matches[i] =
            (uint8_t *)xstrnsave(reg_getline(reg_startzpos[i].lnum) + reg_startzpos[i].col,
                                 (size_t)(reg_endzpos[i].col - reg_startzpos[i].col));
        }
      } else {
        if (reg_startzp[i] != NULL && reg_endzp[i] != NULL) {
          re_extmatch_out->matches[i] =
            (uint8_t *)xstrnsave((char *)reg_startzp[i], (size_t)(reg_endzp[i] - reg_startzp[i]));
        }
      }
    }
  }
  return 1 + rex.lnum;
}

/// Match a regexp against a string ("line" points to the string) or multiple
/// lines (if "line" is NULL, use reg_getline()).
///
/// @param startcol   column to start looking for match
/// @param tm         timeout limit or NULL
/// @param timed_out  flag set on timeout or NULL
///
/// @return  0 for failure, or number of lines contained in the match.
static int bt_regexec_both(uint8_t *line, colnr_T startcol, proftime_T *tm, int *timed_out)
{
  bt_regprog_T *prog;
  uint8_t *s;
  colnr_T col = startcol;
  int retval = 0;

  // Create "regstack" and "backpos" if they are not allocated yet.
  // We allocate *_INITIAL amount of bytes first and then set the grow size
  // to much bigger value to avoid many malloc calls in case of deep regular
  // expressions.
  if (regstack.ga_data == NULL) {
    // Use an item size of 1 byte, since we push different things
    // onto the regstack.
    ga_init(&regstack, 1, REGSTACK_INITIAL);
    ga_grow(&regstack, REGSTACK_INITIAL);
    ga_set_growsize(&regstack, REGSTACK_INITIAL * 8);
  }

  if (backpos.ga_data == NULL) {
    ga_init(&backpos, sizeof(backpos_T), BACKPOS_INITIAL);
    ga_grow(&backpos, BACKPOS_INITIAL);
    ga_set_growsize(&backpos, BACKPOS_INITIAL * 8);
  }

  if (REG_MULTI) {
    prog = (bt_regprog_T *)rex.reg_mmatch->regprog;
    line = (uint8_t *)reg_getline(0);
    rex.reg_startpos = rex.reg_mmatch->startpos;
    rex.reg_endpos = rex.reg_mmatch->endpos;
  } else {
    prog = (bt_regprog_T *)rex.reg_match->regprog;
    rex.reg_startp = (uint8_t **)rex.reg_match->startp;
    rex.reg_endp = (uint8_t **)rex.reg_match->endp;
  }

  // Be paranoid...
  if (prog == NULL || line == NULL) {
    iemsg(_(e_null));
    goto theend;
  }

  // Check validity of program.
  if (prog_magic_wrong()) {
    goto theend;
  }

  // If the start column is past the maximum column: no need to try.
  if (rex.reg_maxcol > 0 && col >= rex.reg_maxcol) {
    goto theend;
  }

  // If pattern contains "\c" or "\C": overrule value of rex.reg_ic
  if (prog->regflags & RF_ICASE) {
    rex.reg_ic = true;
  } else if (prog->regflags & RF_NOICASE) {
    rex.reg_ic = false;
  }

  // If pattern contains "\Z" overrule value of rex.reg_icombine
  if (prog->regflags & RF_ICOMBINE) {
    rex.reg_icombine = true;
  }

  // If there is a "must appear" string, look for it.
  if (prog->regmust != NULL) {
    int c = utf_ptr2char((char *)prog->regmust);
    s = line + col;

    // This is used very often, esp. for ":global".  Use two versions of
    // the loop to avoid overhead of conditions.
    if (!rex.reg_ic) {
      while ((s = (uint8_t *)vim_strchr((char *)s, c)) != NULL) {
        if (cstrncmp((char *)s, (char *)prog->regmust, &prog->regmlen) == 0) {
          break;  // Found it.
        }
        MB_PTR_ADV(s);
      }
    } else {
      while ((s = (uint8_t *)cstrchr((char *)s, c)) != NULL) {
        if (cstrncmp((char *)s, (char *)prog->regmust, &prog->regmlen) == 0) {
          break;  // Found it.
        }
        MB_PTR_ADV(s);
      }
    }
    if (s == NULL) {  // Not present.
      goto theend;
    }
  }

  rex.line = line;
  rex.lnum = 0;
  reg_toolong = false;

  // Simplest case: Anchored match need be tried only once.
  if (prog->reganch) {
    int c = utf_ptr2char((char *)rex.line + col);
    if (prog->regstart == NUL
        || prog->regstart == c
        || (rex.reg_ic
            && (utf_fold(prog->regstart) == utf_fold(c)
                || (c < 255 && prog->regstart < 255
                    && mb_tolower(prog->regstart) == mb_tolower(c))))) {
      retval = regtry(prog, col, tm, timed_out);
    } else {
      retval = 0;
    }
  } else {
    int tm_count = 0;
    // Messy cases:  unanchored match.
    while (!got_int) {
      if (prog->regstart != NUL) {
        // Skip until the char we know it must start with.
        s = (uint8_t *)cstrchr((char *)rex.line + col, prog->regstart);
        if (s == NULL) {
          retval = 0;
          break;
        }
        col = (int)(s - rex.line);
      }

      // Check for maximum column to try.
      if (rex.reg_maxcol > 0 && col >= rex.reg_maxcol) {
        retval = 0;
        break;
      }

      retval = regtry(prog, col, tm, timed_out);
      if (retval > 0) {
        break;
      }

      // if not currently on the first line, get it again
      if (rex.lnum != 0) {
        rex.lnum = 0;
        rex.line = (uint8_t *)reg_getline(0);
      }
      if (rex.line[col] == NUL) {
        break;
      }
      col += utfc_ptr2len((char *)rex.line + col);
      // Check for timeout once in a twenty times to avoid overhead.
      if (tm != NULL && ++tm_count == 20) {
        tm_count = 0;
        if (profile_passed_limit(*tm)) {
          if (timed_out != NULL) {
            *timed_out = true;
          }
          break;
        }
      }
    }
  }

theend:
  // Free "reg_tofree" when it's a bit big.
  // Free regstack and backpos if they are bigger than their initial size.
  if (reg_tofreelen > 400) {
    XFREE_CLEAR(reg_tofree);
  }
  if (regstack.ga_maxlen > REGSTACK_INITIAL) {
    ga_clear(&regstack);
  }
  if (backpos.ga_maxlen > BACKPOS_INITIAL) {
    ga_clear(&backpos);
  }

  if (retval > 0) {
    // Make sure the end is never before the start.  Can happen when \zs
    // and \ze are used.
    if (REG_MULTI) {
      const lpos_T *const start = &rex.reg_mmatch->startpos[0];
      const lpos_T *const end = &rex.reg_mmatch->endpos[0];

      if (end->lnum < start->lnum
          || (end->lnum == start->lnum && end->col < start->col)) {
        rex.reg_mmatch->endpos[0] = rex.reg_mmatch->startpos[0];
      }

      // startpos[0] may be set by "\zs", also return the column where
      // the whole pattern matched.
      rex.reg_mmatch->rmm_matchcol = col;
    } else {
      if (rex.reg_match->endp[0] < rex.reg_match->startp[0]) {
        rex.reg_match->endp[0] = rex.reg_match->startp[0];
      }

      // startpos[0] may be set by "\zs", also return the column where
      // the whole pattern matched.
      rex.reg_match->rm_matchcol = col;
    }
  }

  return retval;
}

/// Match a regexp against a string.
/// "rmp->regprog" is a compiled regexp as returned by vim_regcomp().
/// Uses curbuf for line count and 'iskeyword'.
/// If "line_lbr" is true, consider a "\n" in "line" to be a line break.
///
/// @param line  string to match against
/// @param col   column to start looking for match
///
/// @return  0 for failure, number of lines contained in the match otherwise.
static int bt_regexec_nl(regmatch_T *rmp, uint8_t *line, colnr_T col, bool line_lbr)
{
  rex.reg_match = rmp;
  rex.reg_mmatch = NULL;
  rex.reg_maxline = 0;
  rex.reg_line_lbr = line_lbr;
  rex.reg_buf = curbuf;
  rex.reg_win = NULL;
  rex.reg_ic = rmp->rm_ic;
  rex.reg_icombine = false;
  rex.reg_nobreak = rmp->regprog->re_flags & RE_NOBREAK;
  rex.reg_maxcol = 0;

  int64_t r = bt_regexec_both(line, col, NULL, NULL);
  assert(r <= INT_MAX);
  return (int)r;
}

/// Matches a regexp against multiple lines.
/// "rmp->regprog" is a compiled regexp as returned by vim_regcomp().
/// Uses curbuf for line count and 'iskeyword'.
///
/// @param win Window in which to search or NULL
/// @param buf Buffer in which to search
/// @param lnum Number of line to start looking for match
/// @param col Column to start looking for match
/// @param tm Timeout limit or NULL
///
/// @return zero if there is no match and number of lines contained in the match
///         otherwise.
static int bt_regexec_multi(regmmatch_T *rmp, win_T *win, buf_T *buf, linenr_T lnum, colnr_T col,
                            proftime_T *tm, int *timed_out)
{
  init_regexec_multi(rmp, win, buf, lnum);
  return bt_regexec_both(NULL, col, tm, timed_out);
}

// Compare a number with the operand of RE_LNUM, RE_COL or RE_VCOL.
static int re_num_cmp(uint32_t val, const uint8_t *scan)
{
  uint32_t n = (uint32_t)OPERAND_MIN(scan);

  if (OPERAND_CMP(scan) == '>') {
    return val > n;
  }
  if (OPERAND_CMP(scan) == '<') {
    return val < n;
  }
  return val == n;
}

#ifdef BT_REGEXP_DUMP

// regdump - dump a regexp onto stdout in vaguely comprehensible form
static void regdump(uint8_t *pattern, bt_regprog_T *r)
{
  uint8_t *s;
  int op = EXACTLY;             // Arbitrary non-END op.
  uint8_t *next;
  uint8_t *end = NULL;
  FILE *f;

# ifdef BT_REGEXP_LOG
  f = fopen("bt_regexp_log.log", "a");
# else
  f = stdout;
# endif
  if (f == NULL) {
    return;
  }
  fprintf(f, "-------------------------------------\n\r\nregcomp(%s):\r\n",
          pattern);

  s = &r->program[1];
  // Loop until we find the END that isn't before a referred next (an END
  // can also appear in a NOMATCH operand).
  while (op != END || s <= end) {
    op = OP(s);
    fprintf(f, "%2d%s", (int)(s - r->program), regprop(s));     // Where, what.
    next = regnext(s);
    if (next == NULL) {         // Next ptr.
      fprintf(f, "(0)");
    } else {
      fprintf(f, "(%d)", (int)((s - r->program) + (next - s)));
    }
    if (end < next) {
      end = next;
    }
    if (op == BRACE_LIMITS) {
      // Two ints
      fprintf(f, " minval %" PRId64 ", maxval %" PRId64,
              (int64_t)OPERAND_MIN(s), (int64_t)OPERAND_MAX(s));
      s += 8;
    } else if (op == BEHIND || op == NOBEHIND) {
      // one int
      fprintf(f, " count %" PRId64, (int64_t)OPERAND_MIN(s));
      s += 4;
    } else if (op == RE_LNUM || op == RE_COL || op == RE_VCOL) {
      // one int plus comparator
      fprintf(f, " count %" PRId64, (int64_t)OPERAND_MIN(s));
      s += 5;
    }
    s += 3;
    if (op == ANYOF || op == ANYOF + ADD_NL
        || op == ANYBUT || op == ANYBUT + ADD_NL
        || op == EXACTLY) {
      // Literal string, where present.
      fprintf(f, "\nxxxxxxxxx\n");
      while (*s != NUL) {
        fprintf(f, "%c", *s++);
      }
      fprintf(f, "\nxxxxxxxxx\n");
      s++;
    }
    fprintf(f, "\r\n");
  }

  // Header fields of interest.
  if (r->regstart != NUL) {
    fprintf(f, "start `%s' 0x%x; ", r->regstart < 256
            ? (char *)transchar(r->regstart)
            : "multibyte", r->regstart);
  }
  if (r->reganch) {
    fprintf(f, "anchored; ");
  }
  if (r->regmust != NULL) {
    fprintf(f, "must have \"%s\"", r->regmust);
  }
  fprintf(f, "\r\n");

# ifdef BT_REGEXP_LOG
  fclose(f);
# endif
}
#endif      // BT_REGEXP_DUMP

#ifdef REGEXP_DEBUG

// regprop - printable representation of opcode
static uint8_t *regprop(uint8_t *op)
{
  char *p;
  static char buf[50];
  static size_t buflen = 0;

  STRCPY(buf, ":");
  buflen = 1;

  switch ((int)OP(op)) {
  case BOL:
    p = "BOL";
    break;
  case EOL:
    p = "EOL";
    break;
  case RE_BOF:
    p = "BOF";
    break;
  case RE_EOF:
    p = "EOF";
    break;
  case CURSOR:
    p = "CURSOR";
    break;
  case RE_VISUAL:
    p = "RE_VISUAL";
    break;
  case RE_LNUM:
    p = "RE_LNUM";
    break;
  case RE_MARK:
    p = "RE_MARK";
    break;
  case RE_COL:
    p = "RE_COL";
    break;
  case RE_VCOL:
    p = "RE_VCOL";
    break;
  case BOW:
    p = "BOW";
    break;
  case EOW:
    p = "EOW";
    break;
  case ANY:
    p = "ANY";
    break;
  case ANY + ADD_NL:
    p = "ANY+NL";
    break;
  case ANYOF:
    p = "ANYOF";
    break;
  case ANYOF + ADD_NL:
    p = "ANYOF+NL";
    break;
  case ANYBUT:
    p = "ANYBUT";
    break;
  case ANYBUT + ADD_NL:
    p = "ANYBUT+NL";
    break;
  case IDENT:
    p = "IDENT";
    break;
  case IDENT + ADD_NL:
    p = "IDENT+NL";
    break;
  case SIDENT:
    p = "SIDENT";
    break;
  case SIDENT + ADD_NL:
    p = "SIDENT+NL";
    break;
  case KWORD:
    p = "KWORD";
    break;
  case KWORD + ADD_NL:
    p = "KWORD+NL";
    break;
  case SKWORD:
    p = "SKWORD";
    break;
  case SKWORD + ADD_NL:
    p = "SKWORD+NL";
    break;
  case FNAME:
    p = "FNAME";
    break;
  case FNAME + ADD_NL:
    p = "FNAME+NL";
    break;
  case SFNAME:
    p = "SFNAME";
    break;
  case SFNAME + ADD_NL:
    p = "SFNAME+NL";
    break;
  case PRINT:
    p = "PRINT";
    break;
  case PRINT + ADD_NL:
    p = "PRINT+NL";
    break;
  case SPRINT:
    p = "SPRINT";
    break;
  case SPRINT + ADD_NL:
    p = "SPRINT+NL";
    break;
  case WHITE:
    p = "WHITE";
    break;
  case WHITE + ADD_NL:
    p = "WHITE+NL";
    break;
  case NWHITE:
    p = "NWHITE";
    break;
  case NWHITE + ADD_NL:
    p = "NWHITE+NL";
    break;
  case DIGIT:
    p = "DIGIT";
    break;
  case DIGIT + ADD_NL:
    p = "DIGIT+NL";
    break;
  case NDIGIT:
    p = "NDIGIT";
    break;
  case NDIGIT + ADD_NL:
    p = "NDIGIT+NL";
    break;
  case HEX:
    p = "HEX";
    break;
  case HEX + ADD_NL:
    p = "HEX+NL";
    break;
  case NHEX:
    p = "NHEX";
    break;
  case NHEX + ADD_NL:
    p = "NHEX+NL";
    break;
  case OCTAL:
    p = "OCTAL";
    break;
  case OCTAL + ADD_NL:
    p = "OCTAL+NL";
    break;
  case NOCTAL:
    p = "NOCTAL";
    break;
  case NOCTAL + ADD_NL:
    p = "NOCTAL+NL";
    break;
  case WORD:
    p = "WORD";
    break;
  case WORD + ADD_NL:
    p = "WORD+NL";
    break;
  case NWORD:
    p = "NWORD";
    break;
  case NWORD + ADD_NL:
    p = "NWORD+NL";
    break;
  case HEAD:
    p = "HEAD";
    break;
  case HEAD + ADD_NL:
    p = "HEAD+NL";
    break;
  case NHEAD:
    p = "NHEAD";
    break;
  case NHEAD + ADD_NL:
    p = "NHEAD+NL";
    break;
  case ALPHA:
    p = "ALPHA";
    break;
  case ALPHA + ADD_NL:
    p = "ALPHA+NL";
    break;
  case NALPHA:
    p = "NALPHA";
    break;
  case NALPHA + ADD_NL:
    p = "NALPHA+NL";
    break;
  case LOWER:
    p = "LOWER";
    break;
  case LOWER + ADD_NL:
    p = "LOWER+NL";
    break;
  case NLOWER:
    p = "NLOWER";
    break;
  case NLOWER + ADD_NL:
    p = "NLOWER+NL";
    break;
  case UPPER:
    p = "UPPER";
    break;
  case UPPER + ADD_NL:
    p = "UPPER+NL";
    break;
  case NUPPER:
    p = "NUPPER";
    break;
  case NUPPER + ADD_NL:
    p = "NUPPER+NL";
    break;
  case BRANCH:
    p = "BRANCH";
    break;
  case EXACTLY:
    p = "EXACTLY";
    break;
  case NOTHING:
    p = "NOTHING";
    break;
  case BACK:
    p = "BACK";
    break;
  case END:
    p = "END";
    break;
  case MOPEN + 0:
    p = "MATCH START";
    break;
  case MOPEN + 1:
  case MOPEN + 2:
  case MOPEN + 3:
  case MOPEN + 4:
  case MOPEN + 5:
  case MOPEN + 6:
  case MOPEN + 7:
  case MOPEN + 8:
  case MOPEN + 9:
    buflen += (size_t)snprintf(buf + buflen, sizeof(buf) - buflen,
                               "MOPEN%d", OP(op) - MOPEN);
    p = NULL;
    break;
  case MCLOSE + 0:
    p = "MATCH END";
    break;
  case MCLOSE + 1:
  case MCLOSE + 2:
  case MCLOSE + 3:
  case MCLOSE + 4:
  case MCLOSE + 5:
  case MCLOSE + 6:
  case MCLOSE + 7:
  case MCLOSE + 8:
  case MCLOSE + 9:
    buflen += (size_t)snprintf(buf + buflen, sizeof(buf) - buflen,
                               "MCLOSE%d", OP(op) - MCLOSE);
    p = NULL;
    break;
  case BACKREF + 1:
  case BACKREF + 2:
  case BACKREF + 3:
  case BACKREF + 4:
  case BACKREF + 5:
  case BACKREF + 6:
  case BACKREF + 7:
  case BACKREF + 8:
  case BACKREF + 9:
    buflen += (size_t)snprintf(buf + buflen, sizeof(buf) - buflen,
                               "BACKREF%d", OP(op) - BACKREF);
    p = NULL;
    break;
  case NOPEN:
    p = "NOPEN";
    break;
  case NCLOSE:
    p = "NCLOSE";
    break;
  case ZOPEN + 1:
  case ZOPEN + 2:
  case ZOPEN + 3:
  case ZOPEN + 4:
  case ZOPEN + 5:
  case ZOPEN + 6:
  case ZOPEN + 7:
  case ZOPEN + 8:
  case ZOPEN + 9:
    buflen += (size_t)snprintf(buf + buflen, sizeof(buf) - buflen,
                               "ZOPEN%d", OP(op) - ZOPEN);
    p = NULL;
    break;
  case ZCLOSE + 1:
  case ZCLOSE + 2:
  case ZCLOSE + 3:
  case ZCLOSE + 4:
  case ZCLOSE + 5:
  case ZCLOSE + 6:
  case ZCLOSE + 7:
  case ZCLOSE + 8:
  case ZCLOSE + 9:
    buflen += (size_t)snprintf(buf + buflen, sizeof(buf) - buflen,
                               "ZCLOSE%d", OP(op) - ZCLOSE);
    p = NULL;
    break;
  case ZREF + 1:
  case ZREF + 2:
  case ZREF + 3:
  case ZREF + 4:
  case ZREF + 5:
  case ZREF + 6:
  case ZREF + 7:
  case ZREF + 8:
  case ZREF + 9:
    buflen += (size_t)snprintf(buf + buflen, sizeof(buf) - buflen,
                               "ZREF%d", OP(op) - ZREF);
    p = NULL;
    break;
  case STAR:
    p = "STAR";
    break;
  case PLUS:
    p = "PLUS";
    break;
  case NOMATCH:
    p = "NOMATCH";
    break;
  case MATCH:
    p = "MATCH";
    break;
  case BEHIND:
    p = "BEHIND";
    break;
  case NOBEHIND:
    p = "NOBEHIND";
    break;
  case SUBPAT:
    p = "SUBPAT";
    break;
  case BRACE_LIMITS:
    p = "BRACE_LIMITS";
    break;
  case BRACE_SIMPLE:
    p = "BRACE_SIMPLE";
    break;
  case BRACE_COMPLEX + 0:
  case BRACE_COMPLEX + 1:
  case BRACE_COMPLEX + 2:
  case BRACE_COMPLEX + 3:
  case BRACE_COMPLEX + 4:
  case BRACE_COMPLEX + 5:
  case BRACE_COMPLEX + 6:
  case BRACE_COMPLEX + 7:
  case BRACE_COMPLEX + 8:
  case BRACE_COMPLEX + 9:
    buflen += (size_t)snprintf(buf + buflen, sizeof(buf) - buflen,
                               "BRACE_COMPLEX%d", OP(op) - BRACE_COMPLEX);
    p = NULL;
    break;
  case MULTIBYTECODE:
    p = "MULTIBYTECODE";
    break;
  case NEWL:
    p = "NEWL";
    break;
  default:
    buflen += (size_t)snprintf(buf + buflen, sizeof(buf) - buflen,
                               "corrupt %d", OP(op));
    p = NULL;
    break;
  }
  if (p != NULL) {
    STRCPY(buf + buflen, p);
  }
  return (uint8_t *)buf;
}
#endif      // REGEXP_DEBUG

// }}}1

// regexp_nfa.c {{{1
// NFA regular expression implementation.

// Logging of NFA engine.
//
// The NFA engine can write four log files:
// - Error log: Contains NFA engine's fatal errors.
// - Dump log: Contains compiled NFA state machine's information.
// - Run log: Contains information of matching procedure.
// - Debug log: Contains detailed information of matching procedure. Can be
//   disabled by undefining NFA_REGEXP_DEBUG_LOG.
// The first one can also be used without debug mode.
// The last three are enabled when compiled as debug mode and individually
// disabled by commenting them out.
// The log files can get quite big!
// To disable all of this when compiling Vim for debugging, undefine REGEXP_DEBUG in
// regexp.c
#ifdef REGEXP_DEBUG
# define NFA_REGEXP_ERROR_LOG   "nfa_regexp_error.log"
# define NFA_REGEXP_DUMP_LOG    "nfa_regexp_dump.log"
# define NFA_REGEXP_RUN_LOG     "nfa_regexp_run.log"
# define NFA_REGEXP_DEBUG_LOG   "nfa_regexp_debug.log"
#endif

// Added to NFA_ANY - NFA_NUPPER_IC to include a NL.
#define NFA_ADD_NL              31

enum {
  NFA_SPLIT = -1024,
  NFA_MATCH,
  NFA_EMPTY,                        // matches 0-length

  NFA_START_COLL,                   // [abc] start
  NFA_END_COLL,                     // [abc] end
  NFA_START_NEG_COLL,               // [^abc] start
  NFA_END_NEG_COLL,                 // [^abc] end (postfix only)
  NFA_RANGE,                        // range of the two previous items
                                    // (postfix only)
  NFA_RANGE_MIN,                    // low end of a range
  NFA_RANGE_MAX,                    // high end of a range

  NFA_CONCAT,                       // concatenate two previous items (postfix
                                    // only)
  NFA_OR,                           // \| (postfix only)
  NFA_STAR,                         // greedy * (postfix only)
  NFA_STAR_NONGREEDY,               // non-greedy * (postfix only)
  NFA_QUEST,                        // greedy \? (postfix only)
  NFA_QUEST_NONGREEDY,              // non-greedy \? (postfix only)

  NFA_BOL,                          // ^    Begin line
  NFA_EOL,                          // $    End line
  NFA_BOW,                          // \<   Begin word
  NFA_EOW,                          // \>   End word
  NFA_BOF,                          // \%^  Begin file
  NFA_EOF,                          // \%$  End file
  NFA_NEWL,
  NFA_ZSTART,                       // Used for \zs
  NFA_ZEND,                         // Used for \ze
  NFA_NOPEN,                        // Start of subexpression marked with \%(
  NFA_NCLOSE,                       // End of subexpr. marked with \%( ... \)
  NFA_START_INVISIBLE,
  NFA_START_INVISIBLE_FIRST,
  NFA_START_INVISIBLE_NEG,
  NFA_START_INVISIBLE_NEG_FIRST,
  NFA_START_INVISIBLE_BEFORE,
  NFA_START_INVISIBLE_BEFORE_FIRST,
  NFA_START_INVISIBLE_BEFORE_NEG,
  NFA_START_INVISIBLE_BEFORE_NEG_FIRST,
  NFA_START_PATTERN,
  NFA_END_INVISIBLE,
  NFA_END_INVISIBLE_NEG,
  NFA_END_PATTERN,
  NFA_COMPOSING,                    // Next nodes in NFA are part of the
                                    // composing multibyte char
  NFA_END_COMPOSING,                // End of a composing char in the NFA
  NFA_ANY_COMPOSING,                // \%C: Any composing characters.
  NFA_OPT_CHARS,                    // \%[abc]

  // The following are used only in the postfix form, not in the NFA
  NFA_PREV_ATOM_NO_WIDTH,           // Used for \@=
  NFA_PREV_ATOM_NO_WIDTH_NEG,       // Used for \@!
  NFA_PREV_ATOM_JUST_BEFORE,        // Used for \@<=
  NFA_PREV_ATOM_JUST_BEFORE_NEG,    // Used for \@<!
  NFA_PREV_ATOM_LIKE_PATTERN,       // Used for \@>

  NFA_BACKREF1,                     // \1
  NFA_BACKREF2,                     // \2
  NFA_BACKREF3,                     // \3
  NFA_BACKREF4,                     // \4
  NFA_BACKREF5,                     // \5
  NFA_BACKREF6,                     // \6
  NFA_BACKREF7,                     // \7
  NFA_BACKREF8,                     // \8
  NFA_BACKREF9,                     // \9
  NFA_ZREF1,                        // \z1
  NFA_ZREF2,                        // \z2
  NFA_ZREF3,                        // \z3
  NFA_ZREF4,                        // \z4
  NFA_ZREF5,                        // \z5
  NFA_ZREF6,                        // \z6
  NFA_ZREF7,                        // \z7
  NFA_ZREF8,                        // \z8
  NFA_ZREF9,                        // \z9
  NFA_SKIP,                         // Skip characters

  NFA_MOPEN,
  NFA_MOPEN1,
  NFA_MOPEN2,
  NFA_MOPEN3,
  NFA_MOPEN4,
  NFA_MOPEN5,
  NFA_MOPEN6,
  NFA_MOPEN7,
  NFA_MOPEN8,
  NFA_MOPEN9,

  NFA_MCLOSE,
  NFA_MCLOSE1,
  NFA_MCLOSE2,
  NFA_MCLOSE3,
  NFA_MCLOSE4,
  NFA_MCLOSE5,
  NFA_MCLOSE6,
  NFA_MCLOSE7,
  NFA_MCLOSE8,
  NFA_MCLOSE9,

  NFA_ZOPEN,
  NFA_ZOPEN1,
  NFA_ZOPEN2,
  NFA_ZOPEN3,
  NFA_ZOPEN4,
  NFA_ZOPEN5,
  NFA_ZOPEN6,
  NFA_ZOPEN7,
  NFA_ZOPEN8,
  NFA_ZOPEN9,

  NFA_ZCLOSE,
  NFA_ZCLOSE1,
  NFA_ZCLOSE2,
  NFA_ZCLOSE3,
  NFA_ZCLOSE4,
  NFA_ZCLOSE5,
  NFA_ZCLOSE6,
  NFA_ZCLOSE7,
  NFA_ZCLOSE8,
  NFA_ZCLOSE9,

  // NFA_FIRST_NL
  NFA_ANY,              //      Match any one character.
  NFA_IDENT,            //      Match identifier char
  NFA_SIDENT,           //      Match identifier char but no digit
  NFA_KWORD,            //      Match keyword char
  NFA_SKWORD,           //      Match word char but no digit
  NFA_FNAME,            //      Match file name char
  NFA_SFNAME,           //      Match file name char but no digit
  NFA_PRINT,            //      Match printable char
  NFA_SPRINT,           //      Match printable char but no digit
  NFA_WHITE,            //      Match whitespace char
  NFA_NWHITE,           //      Match non-whitespace char
  NFA_DIGIT,            //      Match digit char
  NFA_NDIGIT,           //      Match non-digit char
  NFA_HEX,              //      Match hex char
  NFA_NHEX,             //      Match non-hex char
  NFA_OCTAL,            //      Match octal char
  NFA_NOCTAL,           //      Match non-octal char
  NFA_WORD,             //      Match word char
  NFA_NWORD,            //      Match non-word char
  NFA_HEAD,             //      Match head char
  NFA_NHEAD,            //      Match non-head char
  NFA_ALPHA,            //      Match alpha char
  NFA_NALPHA,           //      Match non-alpha char
  NFA_LOWER,            //      Match lowercase char
  NFA_NLOWER,           //      Match non-lowercase char
  NFA_UPPER,            //      Match uppercase char
  NFA_NUPPER,           //      Match non-uppercase char
  NFA_LOWER_IC,         //      Match [a-z]
  NFA_NLOWER_IC,        //      Match [^a-z]
  NFA_UPPER_IC,         //      Match [A-Z]
  NFA_NUPPER_IC,        //      Match [^A-Z]

  NFA_FIRST_NL = NFA_ANY + NFA_ADD_NL,
  NFA_LAST_NL = NFA_NUPPER_IC + NFA_ADD_NL,

  NFA_CURSOR,           //      Match cursor pos
  NFA_LNUM,             //      Match line number
  NFA_LNUM_GT,          //      Match > line number
  NFA_LNUM_LT,          //      Match < line number
  NFA_COL,              //      Match cursor column
  NFA_COL_GT,           //      Match > cursor column
  NFA_COL_LT,           //      Match < cursor column
  NFA_VCOL,             //      Match cursor virtual column
  NFA_VCOL_GT,          //      Match > cursor virtual column
  NFA_VCOL_LT,          //      Match < cursor virtual column
  NFA_MARK,             //      Match mark
  NFA_MARK_GT,          //      Match > mark
  NFA_MARK_LT,          //      Match < mark
  NFA_VISUAL,           //      Match Visual area

  // Character classes [:alnum:] etc
  NFA_CLASS_ALNUM,
  NFA_CLASS_ALPHA,
  NFA_CLASS_BLANK,
  NFA_CLASS_CNTRL,
  NFA_CLASS_DIGIT,
  NFA_CLASS_GRAPH,
  NFA_CLASS_LOWER,
  NFA_CLASS_PRINT,
  NFA_CLASS_PUNCT,
  NFA_CLASS_SPACE,
  NFA_CLASS_UPPER,
  NFA_CLASS_XDIGIT,
  NFA_CLASS_TAB,
  NFA_CLASS_RETURN,
  NFA_CLASS_BACKSPACE,
  NFA_CLASS_ESCAPE,
  NFA_CLASS_IDENT,
  NFA_CLASS_KEYWORD,
  NFA_CLASS_FNAME,
};

// Keep in sync with classchars.
static int nfa_classcodes[] = {
  NFA_ANY, NFA_IDENT, NFA_SIDENT, NFA_KWORD, NFA_SKWORD,
  NFA_FNAME, NFA_SFNAME, NFA_PRINT, NFA_SPRINT,
  NFA_WHITE, NFA_NWHITE, NFA_DIGIT, NFA_NDIGIT,
  NFA_HEX, NFA_NHEX, NFA_OCTAL, NFA_NOCTAL,
  NFA_WORD, NFA_NWORD, NFA_HEAD, NFA_NHEAD,
  NFA_ALPHA, NFA_NALPHA, NFA_LOWER, NFA_NLOWER,
  NFA_UPPER, NFA_NUPPER
};

static const char e_nul_found[] = N_("E865: (NFA) Regexp end encountered prematurely");
static const char e_misplaced[] = N_("E866: (NFA regexp) Misplaced %c");
static const char e_ill_char_class[] = N_("E877: (NFA regexp) Invalid character class: %" PRId64);
static const char e_value_too_large[] = N_("E951: \\% value too large");

// Variables only used in nfa_regcomp() and descendants.
static int nfa_re_flags;  ///< re_flags passed to nfa_regcomp().
static int *post_start;   ///< holds the postfix form of r.e.
static int *post_end;
static int *post_ptr;

// Set when the pattern should use the NFA engine.
// E.g. [[:upper:]] only allows 8bit characters for BT engine,
// while NFA engine handles multibyte characters correctly.
static bool wants_nfa;

static int nstate;  ///< Number of states in the NFA. Also used when executing.
static int istate;  ///< Index in the state vector, used in alloc_state()

// If not NULL match must end at this position
static save_se_T *nfa_endp = NULL;

// 0 for first call to nfa_regmatch(), 1 for recursive call.
static int nfa_ll_index = 0;

// Helper functions used when doing re2post() ... regatom() parsing
#define EMIT(c) \
  do { \
    if (post_ptr >= post_end) { \
      realloc_post_list(); \
    } \
    *post_ptr++ = c; \
  } while (0)

/// Initialize internal variables before NFA compilation.
///
/// @param re_flags  @see vim_regcomp()
static void nfa_regcomp_start(uint8_t *expr, int re_flags)
{
  size_t postfix_size;
  size_t nstate_max;

  nstate = 0;
  istate = 0;
  // A reasonable estimation for maximum size
  nstate_max = (strlen((char *)expr) + 1) * 25;

  // Some items blow up in size, such as [A-z].  Add more space for that.
  // When it is still not enough realloc_post_list() will be used.
  nstate_max += 1000;

  // Size for postfix representation of expr.
  postfix_size = sizeof(int) * nstate_max;

  post_start = (int *)xmalloc(postfix_size);
  post_ptr = post_start;
  post_end = post_start + nstate_max;
  wants_nfa = false;
  rex.nfa_has_zend = false;
  rex.nfa_has_backref = false;

  // shared with BT engine
  regcomp_start(expr, re_flags);
}

// Figure out if the NFA state list starts with an anchor, must match at start
// of the line.
static int nfa_get_reganch(nfa_state_T *start, int depth)
{
  nfa_state_T *p = start;

  if (depth > 4) {
    return 0;
  }

  while (p != NULL) {
    switch (p->c) {
    case NFA_BOL:
    case NFA_BOF:
      return 1;           // yes!

    case NFA_ZSTART:
    case NFA_ZEND:
    case NFA_CURSOR:
    case NFA_VISUAL:

    case NFA_MOPEN:
    case NFA_MOPEN1:
    case NFA_MOPEN2:
    case NFA_MOPEN3:
    case NFA_MOPEN4:
    case NFA_MOPEN5:
    case NFA_MOPEN6:
    case NFA_MOPEN7:
    case NFA_MOPEN8:
    case NFA_MOPEN9:
    case NFA_NOPEN:
    case NFA_ZOPEN:
    case NFA_ZOPEN1:
    case NFA_ZOPEN2:
    case NFA_ZOPEN3:
    case NFA_ZOPEN4:
    case NFA_ZOPEN5:
    case NFA_ZOPEN6:
    case NFA_ZOPEN7:
    case NFA_ZOPEN8:
    case NFA_ZOPEN9:
      p = p->out;
      break;

    case NFA_SPLIT:
      return nfa_get_reganch(p->out, depth + 1)
             && nfa_get_reganch(p->out1, depth + 1);

    default:
      return 0;           // noooo
    }
  }
  return 0;
}

// Figure out if the NFA state list starts with a character which must match
// at start of the match.
static int nfa_get_regstart(nfa_state_T *start, int depth)
{
  nfa_state_T *p = start;

  if (depth > 4) {
    return 0;
  }

  while (p != NULL) {
    switch (p->c) {
    // all kinds of zero-width matches
    case NFA_BOL:
    case NFA_BOF:
    case NFA_BOW:
    case NFA_EOW:
    case NFA_ZSTART:
    case NFA_ZEND:
    case NFA_CURSOR:
    case NFA_VISUAL:
    case NFA_LNUM:
    case NFA_LNUM_GT:
    case NFA_LNUM_LT:
    case NFA_COL:
    case NFA_COL_GT:
    case NFA_COL_LT:
    case NFA_VCOL:
    case NFA_VCOL_GT:
    case NFA_VCOL_LT:
    case NFA_MARK:
    case NFA_MARK_GT:
    case NFA_MARK_LT:

    case NFA_MOPEN:
    case NFA_MOPEN1:
    case NFA_MOPEN2:
    case NFA_MOPEN3:
    case NFA_MOPEN4:
    case NFA_MOPEN5:
    case NFA_MOPEN6:
    case NFA_MOPEN7:
    case NFA_MOPEN8:
    case NFA_MOPEN9:
    case NFA_NOPEN:
    case NFA_ZOPEN:
    case NFA_ZOPEN1:
    case NFA_ZOPEN2:
    case NFA_ZOPEN3:
    case NFA_ZOPEN4:
    case NFA_ZOPEN5:
    case NFA_ZOPEN6:
    case NFA_ZOPEN7:
    case NFA_ZOPEN8:
    case NFA_ZOPEN9:
      p = p->out;
      break;

    case NFA_SPLIT: {
      int c1 = nfa_get_regstart(p->out, depth + 1);
      int c2 = nfa_get_regstart(p->out1, depth + 1);

      if (c1 == c2) {
        return c1;             // yes!
      }
      return 0;
    }

    default:
      if (p->c > 0) {
        return p->c;             // yes!
      }
      return 0;
    }
  }
  return 0;
}

// Figure out if the NFA state list contains just literal text and nothing
// else.  If so return a string in allocated memory with what must match after
// regstart.  Otherwise return NULL.
static uint8_t *nfa_get_match_text(nfa_state_T *start)
{
  nfa_state_T *p = start;
  int len = 0;
  uint8_t *ret;
  uint8_t *s;

  if (p->c != NFA_MOPEN) {
    return NULL;     // just in case
  }
  p = p->out;
  while (p->c > 0) {
    len += utf_char2len(p->c);
    p = p->out;
  }
  if (p->c != NFA_MCLOSE || p->out->c != NFA_MATCH) {
    return NULL;
  }

  ret = xmalloc((size_t)len);
  p = start->out->out;     // skip first char, it goes into regstart
  s = ret;
  while (p->c > 0) {
    s += utf_char2bytes(p->c, (char *)s);
    p = p->out;
  }
  *s = NUL;

  return ret;
}

// Allocate more space for post_start.  Called when
// running above the estimated number of states.
static void realloc_post_list(void)
{
  // For weird patterns the number of states can be very high. Increasing by
  // 50% seems a reasonable compromise between memory use and speed.
  const size_t new_max = (size_t)(post_end - post_start) * 3 / 2;
  int *new_start = xrealloc(post_start, new_max * sizeof(int));
  post_ptr = new_start + (post_ptr - post_start);
  post_end = new_start + new_max;
  post_start = new_start;
}

// Search between "start" and "end" and try to recognize a
// character class in expanded form. For example [0-9].
// On success, return the id the character class to be emitted.
// On failure, return 0 (=FAIL)
// Start points to the first char of the range, while end should point
// to the closing brace.
// Keep in mind that 'ignorecase' applies at execution time, thus [a-z] may
// need to be interpreted as [a-zA-Z].
static int nfa_recognize_char_class(uint8_t *start, const uint8_t *end, int extra_newl)
{
#define CLASS_not            0x80
#define CLASS_af             0x40
#define CLASS_AF             0x20
#define CLASS_az             0x10
#define CLASS_AZ             0x08
#define CLASS_o7             0x04
#define CLASS_o9             0x02
#define CLASS_underscore     0x01

  uint8_t *p;
  int config = 0;

  bool newl = extra_newl == true;

  if (*end != ']') {
    return FAIL;
  }
  p = start;
  if (*p == '^') {
    config |= CLASS_not;
    p++;
  }

  while (p < end) {
    if (p + 2 < end && *(p + 1) == '-') {
      switch (*p) {
      case '0':
        if (*(p + 2) == '9') {
          config |= CLASS_o9;
          break;
        } else if (*(p + 2) == '7') {
          config |= CLASS_o7;
          break;
        }
        return FAIL;
      case 'a':
        if (*(p + 2) == 'z') {
          config |= CLASS_az;
          break;
        } else if (*(p + 2) == 'f') {
          config |= CLASS_af;
          break;
        }
        return FAIL;
      case 'A':
        if (*(p + 2) == 'Z') {
          config |= CLASS_AZ;
          break;
        } else if (*(p + 2) == 'F') {
          config |= CLASS_AF;
          break;
        }
        return FAIL;
      default:
        return FAIL;
      }
      p += 3;
    } else if (p + 1 < end && *p == '\\' && *(p + 1) == 'n') {
      newl = true;
      p += 2;
    } else if (*p == '_') {
      config |= CLASS_underscore;
      p++;
    } else if (*p == '\n') {
      newl = true;
      p++;
    } else {
      return FAIL;
    }
  }   // while (p < end)

  if (p != end) {
    return FAIL;
  }

  if (newl == true) {
    extra_newl = NFA_ADD_NL;
  }

  switch (config) {
  case CLASS_o9:
    return extra_newl + NFA_DIGIT;
  case CLASS_not |  CLASS_o9:
    return extra_newl + NFA_NDIGIT;
  case CLASS_af | CLASS_AF | CLASS_o9:
    return extra_newl + NFA_HEX;
  case CLASS_not | CLASS_af | CLASS_AF | CLASS_o9:
    return extra_newl + NFA_NHEX;
  case CLASS_o7:
    return extra_newl + NFA_OCTAL;
  case CLASS_not | CLASS_o7:
    return extra_newl + NFA_NOCTAL;
  case CLASS_az | CLASS_AZ | CLASS_o9 | CLASS_underscore:
    return extra_newl + NFA_WORD;
  case CLASS_not | CLASS_az | CLASS_AZ | CLASS_o9 | CLASS_underscore:
    return extra_newl + NFA_NWORD;
  case CLASS_az | CLASS_AZ | CLASS_underscore:
    return extra_newl + NFA_HEAD;
  case CLASS_not | CLASS_az | CLASS_AZ | CLASS_underscore:
    return extra_newl + NFA_NHEAD;
  case CLASS_az | CLASS_AZ:
    return extra_newl + NFA_ALPHA;
  case CLASS_not | CLASS_az | CLASS_AZ:
    return extra_newl + NFA_NALPHA;
  case CLASS_az:
    return extra_newl + NFA_LOWER_IC;
  case CLASS_not | CLASS_az:
    return extra_newl + NFA_NLOWER_IC;
  case CLASS_AZ:
    return extra_newl + NFA_UPPER_IC;
  case CLASS_not | CLASS_AZ:
    return extra_newl + NFA_NUPPER_IC;
  }
  return FAIL;
}

// Produce the bytes for equivalence class "c".
// Currently only handles latin1, latin9 and utf-8.
// Emits bytes in postfix notation: 'a,b,NFA_OR,c,NFA_OR' is
// equivalent to 'a OR b OR c'
//
// NOTE! When changing this function, also update reg_equi_class()
static void nfa_emit_equi_class(int c)
{
#define EMIT2(c)   EMIT(c); EMIT(NFA_CONCAT);

  {
#define A_grave 0xc0
#define A_acute 0xc1
#define A_circumflex 0xc2
#define A_virguilla 0xc3
#define A_diaeresis 0xc4
#define A_ring 0xc5
#define C_cedilla 0xc7
#define E_grave 0xc8
#define E_acute 0xc9
#define E_circumflex 0xca
#define E_diaeresis 0xcb
#define I_grave 0xcc
#define I_acute 0xcd
#define I_circumflex 0xce
#define I_diaeresis 0xcf
#define N_virguilla 0xd1
#define O_grave 0xd2
#define O_acute 0xd3
#define O_circumflex 0xd4
#define O_virguilla 0xd5
#define O_diaeresis 0xd6
#define O_slash 0xd8
#define U_grave 0xd9
#define U_acute 0xda
#define U_circumflex 0xdb
#define U_diaeresis 0xdc
#define Y_acute 0xdd
#define a_grave 0xe0
#define a_acute 0xe1
#define a_circumflex 0xe2
#define a_virguilla 0xe3
#define a_diaeresis 0xe4
#define a_ring 0xe5
#define c_cedilla 0xe7
#define e_grave 0xe8
#define e_acute 0xe9
#define e_circumflex 0xea
#define e_diaeresis 0xeb
#define i_grave 0xec
#define i_acute 0xed
#define i_circumflex 0xee
#define i_diaeresis 0xef
#define n_virguilla 0xf1
#define o_grave 0xf2
#define o_acute 0xf3
#define o_circumflex 0xf4
#define o_virguilla 0xf5
#define o_diaeresis 0xf6
#define o_slash 0xf8
#define u_grave 0xf9
#define u_acute 0xfa
#define u_circumflex 0xfb
#define u_diaeresis 0xfc
#define y_acute 0xfd
#define y_diaeresis 0xff
    switch (c) {
    case 'A':
    case A_grave:
    case A_acute:
    case A_circumflex:
    case A_virguilla:
    case A_diaeresis:
    case A_ring:
    case 0x100:
    case 0x102:
    case 0x104:
    case 0x1cd:
    case 0x1de:
    case 0x1e0:
    case 0x1fa:
    case 0x200:
    case 0x202:
    case 0x226:
    case 0x23a:
    case 0x1e00:
    case 0x1ea0:
    case 0x1ea2:
    case 0x1ea4:
    case 0x1ea6:
    case 0x1ea8:
    case 0x1eaa:
    case 0x1eac:
    case 0x1eae:
    case 0x1eb0:
    case 0x1eb2:
    case 0x1eb4:
    case 0x1eb6:
      EMIT2('A') EMIT2(A_grave) EMIT2(A_acute)
      EMIT2(A_circumflex) EMIT2(A_virguilla)
      EMIT2(A_diaeresis) EMIT2(A_ring)
      EMIT2(0x100) EMIT2(0x102) EMIT2(0x104)
      EMIT2(0x1cd) EMIT2(0x1de) EMIT2(0x1e0)
      EMIT2(0x1fa) EMIT2(0x200) EMIT2(0x202)
      EMIT2(0x226) EMIT2(0x23a) EMIT2(0x1e00)
      EMIT2(0x1ea0) EMIT2(0x1ea2) EMIT2(0x1ea4)
      EMIT2(0x1ea6) EMIT2(0x1ea8) EMIT2(0x1eaa)
      EMIT2(0x1eac) EMIT2(0x1eae) EMIT2(0x1eb0)
      EMIT2(0x1eb2) EMIT2(0x1eb6) EMIT2(0x1eb4)
      return;

    case 'B':
    case 0x181:
    case 0x243:
    case 0x1e02:
    case 0x1e04:
    case 0x1e06:
      EMIT2('B')
      EMIT2(0x181) EMIT2(0x243) EMIT2(0x1e02)
      EMIT2(0x1e04) EMIT2(0x1e06)
      return;

    case 'C':
    case C_cedilla:
    case 0x106:
    case 0x108:
    case 0x10a:
    case 0x10c:
    case 0x187:
    case 0x23b:
    case 0x1e08:
    case 0xa792:
      EMIT2('C') EMIT2(C_cedilla)
      EMIT2(0x106) EMIT2(0x108) EMIT2(0x10a)
      EMIT2(0x10c) EMIT2(0x187) EMIT2(0x23b)
      EMIT2(0x1e08) EMIT2(0xa792)
      return;

    case 'D':
    case 0x10e:
    case 0x110:
    case 0x18a:
    case 0x1e0a:
    case 0x1e0c:
    case 0x1e0e:
    case 0x1e10:
    case 0x1e12:
      EMIT2('D') EMIT2(0x10e) EMIT2(0x110) EMIT2(0x18a)
      EMIT2(0x1e0a) EMIT2(0x1e0c) EMIT2(0x1e0e)
      EMIT2(0x1e10) EMIT2(0x1e12)
      return;

    case 'E':
    case E_grave:
    case E_acute:
    case E_circumflex:
    case E_diaeresis:
    case 0x112:
    case 0x114:
    case 0x116:
    case 0x118:
    case 0x11a:
    case 0x204:
    case 0x206:
    case 0x228:
    case 0x246:
    case 0x1e14:
    case 0x1e16:
    case 0x1e18:
    case 0x1e1a:
    case 0x1e1c:
    case 0x1eb8:
    case 0x1eba:
    case 0x1ebc:
    case 0x1ebe:
    case 0x1ec0:
    case 0x1ec2:
    case 0x1ec4:
    case 0x1ec6:
      EMIT2('E') EMIT2(E_grave) EMIT2(E_acute)
      EMIT2(E_circumflex) EMIT2(E_diaeresis)
      EMIT2(0x112) EMIT2(0x114) EMIT2(0x116)
      EMIT2(0x118) EMIT2(0x11a) EMIT2(0x204)
      EMIT2(0x206) EMIT2(0x228) EMIT2(0x246)
      EMIT2(0x1e14) EMIT2(0x1e16) EMIT2(0x1e18)
      EMIT2(0x1e1a) EMIT2(0x1e1c) EMIT2(0x1eb8)
      EMIT2(0x1eba) EMIT2(0x1ebc) EMIT2(0x1ebe)
      EMIT2(0x1ec0) EMIT2(0x1ec2) EMIT2(0x1ec4)
      EMIT2(0x1ec6)
      return;

    case 'F':
    case 0x191:
    case 0x1e1e:
    case 0xa798:
      EMIT2('F') EMIT2(0x191) EMIT2(0x1e1e) EMIT2(0xa798)
      return;

    case 'G':
    case 0x11c:
    case 0x11e:
    case 0x120:
    case 0x122:
    case 0x193:
    case 0x1e4:
    case 0x1e6:
    case 0x1f4:
    case 0x1e20:
    case 0xa7a0:
      EMIT2('G') EMIT2(0x11c) EMIT2(0x11e) EMIT2(0x120)
      EMIT2(0x122) EMIT2(0x193) EMIT2(0x1e4)
      EMIT2(0x1e6) EMIT2(0x1f4) EMIT2(0x1e20)
      EMIT2(0xa7a0)
      return;

    case 'H':
    case 0x124:
    case 0x126:
    case 0x21e:
    case 0x1e22:
    case 0x1e24:
    case 0x1e26:
    case 0x1e28:
    case 0x1e2a:
    case 0x2c67:
      EMIT2('H') EMIT2(0x124) EMIT2(0x126) EMIT2(0x21e)
      EMIT2(0x1e22) EMIT2(0x1e24) EMIT2(0x1e26)
      EMIT2(0x1e28) EMIT2(0x1e2a) EMIT2(0x2c67)
      return;

    case 'I':
    case I_grave:
    case I_acute:
    case I_circumflex:
    case I_diaeresis:
    case 0x128:
    case 0x12a:
    case 0x12c:
    case 0x12e:
    case 0x130:
    case 0x197:
    case 0x1cf:
    case 0x208:
    case 0x20a:
    case 0x1e2c:
    case 0x1e2e:
    case 0x1ec8:
    case 0x1eca:
      EMIT2('I') EMIT2(I_grave) EMIT2(I_acute)
      EMIT2(I_circumflex) EMIT2(I_diaeresis)
      EMIT2(0x128) EMIT2(0x12a) EMIT2(0x12c)
      EMIT2(0x12e) EMIT2(0x130) EMIT2(0x197)
      EMIT2(0x1cf) EMIT2(0x208) EMIT2(0x20a)
      EMIT2(0x1e2c) EMIT2(0x1e2e) EMIT2(0x1ec8)
      EMIT2(0x1eca)
      return;

    case 'J':
    case 0x134:
    case 0x248:
      EMIT2('J') EMIT2(0x134) EMIT2(0x248)
      return;

    case 'K':
    case 0x136:
    case 0x198:
    case 0x1e8:
    case 0x1e30:
    case 0x1e32:
    case 0x1e34:
    case 0x2c69:
    case 0xa740:
      EMIT2('K') EMIT2(0x136) EMIT2(0x198) EMIT2(0x1e8)
      EMIT2(0x1e30) EMIT2(0x1e32) EMIT2(0x1e34)
      EMIT2(0x2c69) EMIT2(0xa740)
      return;

    case 'L':
    case 0x139:
    case 0x13b:
    case 0x13d:
    case 0x13f:
    case 0x141:
    case 0x23d:
    case 0x1e36:
    case 0x1e38:
    case 0x1e3a:
    case 0x1e3c:
    case 0x2c60:
      EMIT2('L') EMIT2(0x139) EMIT2(0x13b)
      EMIT2(0x13d) EMIT2(0x13f) EMIT2(0x141)
      EMIT2(0x23d) EMIT2(0x1e36) EMIT2(0x1e38)
      EMIT2(0x1e3a) EMIT2(0x1e3c) EMIT2(0x2c60)
      return;

    case 'M':
    case 0x1e3e:
    case 0x1e40:
    case 0x1e42:
      EMIT2('M') EMIT2(0x1e3e) EMIT2(0x1e40)
      EMIT2(0x1e42)
      return;

    case 'N':
    case N_virguilla:
    case 0x143:
    case 0x145:
    case 0x147:
    case 0x1f8:
    case 0x1e44:
    case 0x1e46:
    case 0x1e48:
    case 0x1e4a:
    case 0xa7a4:
      EMIT2('N') EMIT2(N_virguilla)
      EMIT2(0x143) EMIT2(0x145) EMIT2(0x147)
      EMIT2(0x1f8) EMIT2(0x1e44) EMIT2(0x1e46)
      EMIT2(0x1e48) EMIT2(0x1e4a) EMIT2(0xa7a4)
      return;

    case 'O':
    case O_grave:
    case O_acute:
    case O_circumflex:
    case O_virguilla:
    case O_diaeresis:
    case O_slash:
    case 0x14c:
    case 0x14e:
    case 0x150:
    case 0x19f:
    case 0x1a0:
    case 0x1d1:
    case 0x1ea:
    case 0x1ec:
    case 0x1fe:
    case 0x20c:
    case 0x20e:
    case 0x22a:
    case 0x22c:
    case 0x22e:
    case 0x230:
    case 0x1e4c:
    case 0x1e4e:
    case 0x1e50:
    case 0x1e52:
    case 0x1ecc:
    case 0x1ece:
    case 0x1ed0:
    case 0x1ed2:
    case 0x1ed4:
    case 0x1ed6:
    case 0x1ed8:
    case 0x1eda:
    case 0x1edc:
    case 0x1ede:
    case 0x1ee0:
    case 0x1ee2:
      EMIT2('O') EMIT2(O_grave) EMIT2(O_acute)
      EMIT2(O_circumflex) EMIT2(O_virguilla)
      EMIT2(O_diaeresis) EMIT2(O_slash)
      EMIT2(0x14c) EMIT2(0x14e) EMIT2(0x150)
      EMIT2(0x19f) EMIT2(0x1a0) EMIT2(0x1d1)
      EMIT2(0x1ea) EMIT2(0x1ec) EMIT2(0x1fe)
      EMIT2(0x20c) EMIT2(0x20e) EMIT2(0x22a)
      EMIT2(0x22c) EMIT2(0x22e) EMIT2(0x230)
      EMIT2(0x1e4c) EMIT2(0x1e4e) EMIT2(0x1e50)
      EMIT2(0x1e52) EMIT2(0x1ecc) EMIT2(0x1ece)
      EMIT2(0x1ed0) EMIT2(0x1ed2) EMIT2(0x1ed4)
      EMIT2(0x1ed6) EMIT2(0x1ed8) EMIT2(0x1eda)
      EMIT2(0x1edc) EMIT2(0x1ede) EMIT2(0x1ee0)
      EMIT2(0x1ee2)
      return;

    case 'P':
    case 0x1a4:
    case 0x1e54:
    case 0x1e56:
    case 0x2c63:
      EMIT2('P') EMIT2(0x1a4) EMIT2(0x1e54) EMIT2(0x1e56)
      EMIT2(0x2c63)
      return;

    case 'Q':
    case 0x24a:
      EMIT2('Q') EMIT2(0x24a)
      return;

    case 'R':
    case 0x154:
    case 0x156:
    case 0x158:
    case 0x210:
    case 0x212:
    case 0x24c:
    case 0x1e58:
    case 0x1e5a:
    case 0x1e5c:
    case 0x1e5e:
    case 0x2c64:
    case 0xa7a6:
      EMIT2('R') EMIT2(0x154) EMIT2(0x156) EMIT2(0x158)
      EMIT2(0x210) EMIT2(0x212) EMIT2(0x24c) EMIT2(0x1e58)
      EMIT2(0x1e5a) EMIT2(0x1e5c) EMIT2(0x1e5e) EMIT2(0x2c64)
      EMIT2(0xa7a6)
      return;

    case 'S':
    case 0x15a:
    case 0x15c:
    case 0x15e:
    case 0x160:
    case 0x218:
    case 0x1e60:
    case 0x1e62:
    case 0x1e64:
    case 0x1e66:
    case 0x1e68:
    case 0x2c7e:
    case 0xa7a8:
      EMIT2('S') EMIT2(0x15a) EMIT2(0x15c) EMIT2(0x15e)
      EMIT2(0x160) EMIT2(0x218) EMIT2(0x1e60) EMIT2(0x1e62)
      EMIT2(0x1e64) EMIT2(0x1e66) EMIT2(0x1e68) EMIT2(0x2c7e)
      EMIT2(0xa7a8)
      return;

    case 'T':
    case 0x162:
    case 0x164:
    case 0x166:
    case 0x1ac:
    case 0x1ae:
    case 0x21a:
    case 0x23e:
    case 0x1e6a:
    case 0x1e6c:
    case 0x1e6e:
    case 0x1e70:
      EMIT2('T') EMIT2(0x162) EMIT2(0x164) EMIT2(0x166)
      EMIT2(0x1ac) EMIT2(0x1ae) EMIT2(0x23e) EMIT2(0x21a)
      EMIT2(0x1e6a) EMIT2(0x1e6c) EMIT2(0x1e6e) EMIT2(0x1e70)
      return;

    case 'U':
    case U_grave:
    case U_acute:
    case U_diaeresis:
    case U_circumflex:
    case 0x168:
    case 0x16a:
    case 0x16c:
    case 0x16e:
    case 0x170:
    case 0x172:
    case 0x1af:
    case 0x1d3:
    case 0x1d5:
    case 0x1d7:
    case 0x1d9:
    case 0x1db:
    case 0x214:
    case 0x216:
    case 0x244:
    case 0x1e72:
    case 0x1e74:
    case 0x1e76:
    case 0x1e78:
    case 0x1e7a:
    case 0x1ee4:
    case 0x1ee6:
    case 0x1ee8:
    case 0x1eea:
    case 0x1eec:
    case 0x1eee:
    case 0x1ef0:
      EMIT2('U') EMIT2(U_grave) EMIT2(U_acute)
      EMIT2(U_diaeresis) EMIT2(U_circumflex)
      EMIT2(0x168) EMIT2(0x16a)
      EMIT2(0x16c) EMIT2(0x16e) EMIT2(0x170)
      EMIT2(0x172) EMIT2(0x1af) EMIT2(0x1d3)
      EMIT2(0x1d5) EMIT2(0x1d7) EMIT2(0x1d9)
      EMIT2(0x1db) EMIT2(0x214) EMIT2(0x216)
      EMIT2(0x244) EMIT2(0x1e72) EMIT2(0x1e74)
      EMIT2(0x1e76) EMIT2(0x1e78) EMIT2(0x1e7a)
      EMIT2(0x1ee4) EMIT2(0x1ee6) EMIT2(0x1ee8)
      EMIT2(0x1eea) EMIT2(0x1eec) EMIT2(0x1eee)
      EMIT2(0x1ef0)
      return;

    case 'V':
    case 0x1b2:
    case 0x1e7c:
    case 0x1e7e:
      EMIT2('V') EMIT2(0x1b2) EMIT2(0x1e7c) EMIT2(0x1e7e)
      return;

    case 'W':
    case 0x174:
    case 0x1e80:
    case 0x1e82:
    case 0x1e84:
    case 0x1e86:
    case 0x1e88:
      EMIT2('W') EMIT2(0x174) EMIT2(0x1e80) EMIT2(0x1e82)
      EMIT2(0x1e84) EMIT2(0x1e86) EMIT2(0x1e88)
      return;

    case 'X':
    case 0x1e8a:
    case 0x1e8c:
      EMIT2('X') EMIT2(0x1e8a) EMIT2(0x1e8c)
      return;

    case 'Y':
    case Y_acute:
    case 0x176:
    case 0x178:
    case 0x1b3:
    case 0x232:
    case 0x24e:
    case 0x1e8e:
    case 0x1ef2:
    case 0x1ef4:
    case 0x1ef6:
    case 0x1ef8:
      EMIT2('Y') EMIT2(Y_acute)
      EMIT2(0x176) EMIT2(0x178) EMIT2(0x1b3)
      EMIT2(0x232) EMIT2(0x24e) EMIT2(0x1e8e)
      EMIT2(0x1ef2) EMIT2(0x1ef4) EMIT2(0x1ef6)
      EMIT2(0x1ef8)
      return;

    case 'Z':
    case 0x179:
    case 0x17b:
    case 0x17d:
    case 0x1b5:
    case 0x1e90:
    case 0x1e92:
    case 0x1e94:
    case 0x2c6b:
      EMIT2('Z') EMIT2(0x179) EMIT2(0x17b) EMIT2(0x17d)
      EMIT2(0x1b5) EMIT2(0x1e90) EMIT2(0x1e92)
      EMIT2(0x1e94) EMIT2(0x2c6b)
      return;

    case 'a':
    case a_grave:
    case a_acute:
    case a_circumflex:
    case a_virguilla:
    case a_diaeresis:
    case a_ring:
    case 0x101:
    case 0x103:
    case 0x105:
    case 0x1ce:
    case 0x1df:
    case 0x1e1:
    case 0x1fb:
    case 0x201:
    case 0x203:
    case 0x227:
    case 0x1d8f:
    case 0x1e01:
    case 0x1e9a:
    case 0x1ea1:
    case 0x1ea3:
    case 0x1ea5:
    case 0x1ea7:
    case 0x1ea9:
    case 0x1eab:
    case 0x1ead:
    case 0x1eaf:
    case 0x1eb1:
    case 0x1eb3:
    case 0x1eb5:
    case 0x1eb7:
    case 0x2c65:
      EMIT2('a') EMIT2(a_grave) EMIT2(a_acute)
      EMIT2(a_circumflex) EMIT2(a_virguilla)
      EMIT2(a_diaeresis) EMIT2(a_ring)
      EMIT2(0x101) EMIT2(0x103) EMIT2(0x105)
      EMIT2(0x1ce) EMIT2(0x1df) EMIT2(0x1e1)
      EMIT2(0x1fb) EMIT2(0x201) EMIT2(0x203)
      EMIT2(0x227) EMIT2(0x1d8f) EMIT2(0x1e01)
      EMIT2(0x1e9a) EMIT2(0x1ea1) EMIT2(0x1ea3)
      EMIT2(0x1ea5) EMIT2(0x1ea7) EMIT2(0x1ea9)
      EMIT2(0x1eab) EMIT2(0x1ead) EMIT2(0x1eaf)
      EMIT2(0x1eb1) EMIT2(0x1eb3) EMIT2(0x1eb5)
      EMIT2(0x1eb7) EMIT2(0x2c65)
      return;

    case 'b':
    case 0x180:
    case 0x253:
    case 0x1d6c:
    case 0x1d80:
    case 0x1e03:
    case 0x1e05:
    case 0x1e07:
      EMIT2('b') EMIT2(0x180) EMIT2(0x253) EMIT2(0x1d6c)
      EMIT2(0x1d80) EMIT2(0x1e03) EMIT2(0x1e05) EMIT2(0x1e07)
      return;

    case 'c':
    case c_cedilla:
    case 0x107:
    case 0x109:
    case 0x10b:
    case 0x10d:
    case 0x188:
    case 0x23c:
    case 0x1e09:
    case 0xa793:
    case 0xa794:
      EMIT2('c') EMIT2(c_cedilla)
      EMIT2(0x107) EMIT2(0x109) EMIT2(0x10b)
      EMIT2(0x10d) EMIT2(0x188) EMIT2(0x23c)
      EMIT2(0x1e09) EMIT2(0xa793) EMIT2(0xa794)
      return;

    case 'd':
    case 0x10f:
    case 0x111:
    case 0x257:
    case 0x1d6d:
    case 0x1d81:
    case 0x1d91:
    case 0x1e0b:
    case 0x1e0d:
    case 0x1e0f:
    case 0x1e11:
    case 0x1e13:
      EMIT2('d') EMIT2(0x10f) EMIT2(0x111)
      EMIT2(0x257) EMIT2(0x1d6d) EMIT2(0x1d81)
      EMIT2(0x1d91) EMIT2(0x1e0b) EMIT2(0x1e0d)
      EMIT2(0x1e0f) EMIT2(0x1e11) EMIT2(0x1e13)
      return;

    case 'e':
    case e_grave:
    case e_acute:
    case e_circumflex:
    case e_diaeresis:
    case 0x113:
    case 0x115:
    case 0x117:
    case 0x119:
    case 0x11b:
    case 0x205:
    case 0x207:
    case 0x229:
    case 0x247:
    case 0x1d92:
    case 0x1e15:
    case 0x1e17:
    case 0x1e19:
    case 0x1e1b:
    case 0x1e1d:
    case 0x1eb9:
    case 0x1ebb:
    case 0x1ebd:
    case 0x1ebf:
    case 0x1ec1:
    case 0x1ec3:
    case 0x1ec5:
    case 0x1ec7:
      EMIT2('e') EMIT2(e_grave) EMIT2(e_acute)
      EMIT2(e_circumflex) EMIT2(e_diaeresis)
      EMIT2(0x113) EMIT2(0x115)
      EMIT2(0x117) EMIT2(0x119) EMIT2(0x11b)
      EMIT2(0x205) EMIT2(0x207) EMIT2(0x229)
      EMIT2(0x247) EMIT2(0x1d92) EMIT2(0x1e15)
      EMIT2(0x1e17) EMIT2(0x1e19) EMIT2(0x1e1b)
      EMIT2(0x1e1d) EMIT2(0x1eb9) EMIT2(0x1ebb)
      EMIT2(0x1ebd) EMIT2(0x1ebf) EMIT2(0x1ec1)
      EMIT2(0x1ec3) EMIT2(0x1ec5) EMIT2(0x1ec7)
      return;

    case 'f':
    case 0x192:
    case 0x1d6e:
    case 0x1d82:
    case 0x1e1f:
    case 0xa799:
      EMIT2('f') EMIT2(0x192) EMIT2(0x1d6e) EMIT2(0x1d82)
      EMIT2(0x1e1f) EMIT2(0xa799)
      return;

    case 'g':
    case 0x11d:
    case 0x11f:
    case 0x121:
    case 0x123:
    case 0x1e5:
    case 0x1e7:
    case 0x1f5:
    case 0x260:
    case 0x1d83:
    case 0x1e21:
    case 0xa7a1:
      EMIT2('g') EMIT2(0x11d) EMIT2(0x11f) EMIT2(0x121)
      EMIT2(0x123) EMIT2(0x1e5) EMIT2(0x1e7)
      EMIT2(0x1f5) EMIT2(0x260) EMIT2(0x1d83)
      EMIT2(0x1e21) EMIT2(0xa7a1)
      return;

    case 'h':
    case 0x125:
    case 0x127:
    case 0x21f:
    case 0x1e23:
    case 0x1e25:
    case 0x1e27:
    case 0x1e29:
    case 0x1e2b:
    case 0x1e96:
    case 0x2c68:
    case 0xa795:
      EMIT2('h') EMIT2(0x125) EMIT2(0x127) EMIT2(0x21f)
      EMIT2(0x1e23) EMIT2(0x1e25) EMIT2(0x1e27)
      EMIT2(0x1e29) EMIT2(0x1e2b) EMIT2(0x1e96)
      EMIT2(0x2c68) EMIT2(0xa795)
      return;

    case 'i':
    case i_grave:
    case i_acute:
    case i_circumflex:
    case i_diaeresis:
    case 0x129:
    case 0x12b:
    case 0x12d:
    case 0x12f:
    case 0x1d0:
    case 0x209:
    case 0x20b:
    case 0x268:
    case 0x1d96:
    case 0x1e2d:
    case 0x1e2f:
    case 0x1ec9:
    case 0x1ecb:
      EMIT2('i') EMIT2(i_grave) EMIT2(i_acute)
      EMIT2(i_circumflex) EMIT2(i_diaeresis)
      EMIT2(0x129) EMIT2(0x12b) EMIT2(0x12d)
      EMIT2(0x12f) EMIT2(0x1d0) EMIT2(0x209)
      EMIT2(0x20b) EMIT2(0x268) EMIT2(0x1d96)
      EMIT2(0x1e2d) EMIT2(0x1e2f) EMIT2(0x1ec9)
      EMIT2(0x1ecb) EMIT2(0x1ecb)
      return;

    case 'j':
    case 0x135:
    case 0x1f0:
    case 0x249:
      EMIT2('j') EMIT2(0x135) EMIT2(0x1f0) EMIT2(0x249)
      return;

    case 'k':
    case 0x137:
    case 0x199:
    case 0x1e9:
    case 0x1d84:
    case 0x1e31:
    case 0x1e33:
    case 0x1e35:
    case 0x2c6a:
    case 0xa741:
      EMIT2('k') EMIT2(0x137) EMIT2(0x199) EMIT2(0x1e9)
      EMIT2(0x1d84) EMIT2(0x1e31) EMIT2(0x1e33)
      EMIT2(0x1e35) EMIT2(0x2c6a) EMIT2(0xa741)
      return;

    case 'l':
    case 0x13a:
    case 0x13c:
    case 0x13e:
    case 0x140:
    case 0x142:
    case 0x19a:
    case 0x1e37:
    case 0x1e39:
    case 0x1e3b:
    case 0x1e3d:
    case 0x2c61:
      EMIT2('l') EMIT2(0x13a) EMIT2(0x13c)
      EMIT2(0x13e) EMIT2(0x140) EMIT2(0x142)
      EMIT2(0x19a) EMIT2(0x1e37) EMIT2(0x1e39)
      EMIT2(0x1e3b) EMIT2(0x1e3d) EMIT2(0x2c61)
      return;

    case 'm':
    case 0x1d6f:
    case 0x1e3f:
    case 0x1e41:
    case 0x1e43:
      EMIT2('m') EMIT2(0x1d6f) EMIT2(0x1e3f)
      EMIT2(0x1e41) EMIT2(0x1e43)
      return;

    case 'n':
    case n_virguilla:
    case 0x144:
    case 0x146:
    case 0x148:
    case 0x149:
    case 0x1f9:
    case 0x1d70:
    case 0x1d87:
    case 0x1e45:
    case 0x1e47:
    case 0x1e49:
    case 0x1e4b:
    case 0xa7a5:
      EMIT2('n') EMIT2(n_virguilla)
      EMIT2(0x144) EMIT2(0x146) EMIT2(0x148)
      EMIT2(0x149) EMIT2(0x1f9) EMIT2(0x1d70)
      EMIT2(0x1d87) EMIT2(0x1e45) EMIT2(0x1e47)
      EMIT2(0x1e49) EMIT2(0x1e4b) EMIT2(0xa7a5)
      return;

    case 'o':
    case o_grave:
    case o_acute:
    case o_circumflex:
    case o_virguilla:
    case o_diaeresis:
    case o_slash:
    case 0x14d:
    case 0x14f:
    case 0x151:
    case 0x1a1:
    case 0x1d2:
    case 0x1eb:
    case 0x1ed:
    case 0x1ff:
    case 0x20d:
    case 0x20f:
    case 0x22b:
    case 0x22d:
    case 0x22f:
    case 0x231:
    case 0x275:
    case 0x1e4d:
    case 0x1e4f:
    case 0x1e51:
    case 0x1e53:
    case 0x1ecd:
    case 0x1ecf:
    case 0x1ed1:
    case 0x1ed3:
    case 0x1ed5:
    case 0x1ed7:
    case 0x1ed9:
    case 0x1edb:
    case 0x1edd:
    case 0x1edf:
    case 0x1ee1:
    case 0x1ee3:
      EMIT2('o') EMIT2(o_grave) EMIT2(o_acute)
      EMIT2(o_circumflex) EMIT2(o_virguilla)
      EMIT2(o_diaeresis) EMIT2(o_slash)
      EMIT2(0x14d) EMIT2(0x14f) EMIT2(0x151)
      EMIT2(0x1a1) EMIT2(0x1d2) EMIT2(0x1eb)
      EMIT2(0x1ed) EMIT2(0x1ff) EMIT2(0x20d)
      EMIT2(0x20f) EMIT2(0x22b) EMIT2(0x22d)
      EMIT2(0x22f) EMIT2(0x231) EMIT2(0x275)
      EMIT2(0x1e4d) EMIT2(0x1e4f) EMIT2(0x1e51)
      EMIT2(0x1e53) EMIT2(0x1ecd) EMIT2(0x1ecf)
      EMIT2(0x1ed1) EMIT2(0x1ed3) EMIT2(0x1ed5)
      EMIT2(0x1ed7) EMIT2(0x1ed9) EMIT2(0x1edb)
      EMIT2(0x1edd) EMIT2(0x1edf) EMIT2(0x1ee1)
      EMIT2(0x1ee3)
      return;

    case 'p':
    case 0x1a5:
    case 0x1d71:
    case 0x1d7d:
    case 0x1d88:
    case 0x1e55:
    case 0x1e57:
      EMIT2('p') EMIT2(0x1a5) EMIT2(0x1d71) EMIT2(0x1d7d)
      EMIT2(0x1d88) EMIT2(0x1e55) EMIT2(0x1e57)
      return;

    case 'q':
    case 0x24b:
    case 0x2a0:
      EMIT2('q') EMIT2(0x24b) EMIT2(0x2a0)
      return;

    case 'r':
    case 0x155:
    case 0x157:
    case 0x159:
    case 0x211:
    case 0x213:
    case 0x24d:
    case 0x27d:
    case 0x1d72:
    case 0x1d73:
    case 0x1d89:
    case 0x1e59:
    case 0x1e5b:
    case 0x1e5d:
    case 0x1e5f:
    case 0xa7a7:
      EMIT2('r') EMIT2(0x155) EMIT2(0x157) EMIT2(0x159)
      EMIT2(0x211) EMIT2(0x213) EMIT2(0x24d) EMIT2(0x27d)
      EMIT2(0x1d72) EMIT2(0x1d73) EMIT2(0x1d89) EMIT2(0x1e59)
      EMIT2(0x1e5b) EMIT2(0x1e5d) EMIT2(0x1e5f) EMIT2(0xa7a7)
      return;

    case 's':
    case 0x15b:
    case 0x15d:
    case 0x15f:
    case 0x161:
    case 0x219:
    case 0x23f:
    case 0x1d74:
    case 0x1d8a:
    case 0x1e61:
    case 0x1e63:
    case 0x1e65:
    case 0x1e67:
    case 0x1e69:
    case 0xa7a9:
      EMIT2('s') EMIT2(0x15b) EMIT2(0x15d) EMIT2(0x15f)
      EMIT2(0x161) EMIT2(0x219) EMIT2(0x23f) EMIT2(0x1d74)
      EMIT2(0x1d8a) EMIT2(0x1e61) EMIT2(0x1e63) EMIT2(0x1e65)
      EMIT2(0x1e67) EMIT2(0x1e69) EMIT2(0xa7a9)
      return;

    case 't':
    case 0x163:
    case 0x165:
    case 0x167:
    case 0x1ab:
    case 0x1ad:
    case 0x21b:
    case 0x288:
    case 0x1d75:
    case 0x1e6b:
    case 0x1e6d:
    case 0x1e6f:
    case 0x1e71:
    case 0x1e97:
    case 0x2c66:
      EMIT2('t') EMIT2(0x163) EMIT2(0x165) EMIT2(0x167)
      EMIT2(0x1ab) EMIT2(0x1ad) EMIT2(0x21b) EMIT2(0x288)
      EMIT2(0x1d75) EMIT2(0x1e6b) EMIT2(0x1e6d) EMIT2(0x1e6f)
      EMIT2(0x1e71) EMIT2(0x1e97) EMIT2(0x2c66)
      return;

    case 'u':
    case u_grave:
    case u_acute:
    case u_circumflex:
    case u_diaeresis:
    case 0x169:
    case 0x16b:
    case 0x16d:
    case 0x16f:
    case 0x171:
    case 0x173:
    case 0x1b0:
    case 0x1d4:
    case 0x1d6:
    case 0x1d8:
    case 0x1da:
    case 0x1dc:
    case 0x215:
    case 0x217:
    case 0x289:
    case 0x1d7e:
    case 0x1d99:
    case 0x1e73:
    case 0x1e75:
    case 0x1e77:
    case 0x1e79:
    case 0x1e7b:
    case 0x1ee5:
    case 0x1ee7:
    case 0x1ee9:
    case 0x1eeb:
    case 0x1eed:
    case 0x1eef:
    case 0x1ef1:
      EMIT2('u') EMIT2(u_grave) EMIT2(u_acute)
      EMIT2(u_circumflex) EMIT2(u_diaeresis)
      EMIT2(0x169) EMIT2(0x16b)
      EMIT2(0x16d) EMIT2(0x16f) EMIT2(0x171)
      EMIT2(0x173) EMIT2(0x1d6) EMIT2(0x1d8)
      EMIT2(0x215) EMIT2(0x217) EMIT2(0x1b0)
      EMIT2(0x1d4) EMIT2(0x1da) EMIT2(0x1dc)
      EMIT2(0x289) EMIT2(0x1e73) EMIT2(0x1d7e)
      EMIT2(0x1d99) EMIT2(0x1e75) EMIT2(0x1e77)
      EMIT2(0x1e79) EMIT2(0x1e7b) EMIT2(0x1ee5)
      EMIT2(0x1ee7) EMIT2(0x1ee9) EMIT2(0x1eeb)
      EMIT2(0x1eed) EMIT2(0x1eef) EMIT2(0x1ef1)
      return;

    case 'v':
    case 0x28b:
    case 0x1d8c:
    case 0x1e7d:
    case 0x1e7f:
      EMIT2('v') EMIT2(0x28b) EMIT2(0x1d8c) EMIT2(0x1e7d)
      EMIT2(0x1e7f)
      return;

    case 'w':
    case 0x175:
    case 0x1e81:
    case 0x1e83:
    case 0x1e85:
    case 0x1e87:
    case 0x1e89:
    case 0x1e98:
      EMIT2('w') EMIT2(0x175) EMIT2(0x1e81) EMIT2(0x1e83)
      EMIT2(0x1e85) EMIT2(0x1e87) EMIT2(0x1e89) EMIT2(0x1e98)
      return;

    case 'x':
    case 0x1e8b:
    case 0x1e8d:
      EMIT2('x') EMIT2(0x1e8b) EMIT2(0x1e8d)
      return;

    case 'y':
    case y_acute:
    case y_diaeresis:
    case 0x177:
    case 0x1b4:
    case 0x233:
    case 0x24f:
    case 0x1e8f:
    case 0x1e99:
    case 0x1ef3:
    case 0x1ef5:
    case 0x1ef7:
    case 0x1ef9:
      EMIT2('y') EMIT2(y_acute) EMIT2(y_diaeresis)
      EMIT2(0x177) EMIT2(0x1b4) EMIT2(0x233) EMIT2(0x24f)
      EMIT2(0x1e8f) EMIT2(0x1e99) EMIT2(0x1ef3)
      EMIT2(0x1ef5) EMIT2(0x1ef7) EMIT2(0x1ef9)
      return;

    case 'z':
    case 0x17a:
    case 0x17c:
    case 0x17e:
    case 0x1b6:
    case 0x1d76:
    case 0x1d8e:
    case 0x1e91:
    case 0x1e93:
    case 0x1e95:
    case 0x2c6c:
      EMIT2('z') EMIT2(0x17a) EMIT2(0x17c) EMIT2(0x17e)
      EMIT2(0x1b6) EMIT2(0x1d76) EMIT2(0x1d8e) EMIT2(0x1e91)
      EMIT2(0x1e93) EMIT2(0x1e95) EMIT2(0x2c6c)
      return;

      // default: character itself
    }
  }

  EMIT2(c);
#undef EMIT2
}

// Code to parse regular expression.
//
// We try to reuse parsing functions in regexp.c to
// minimize surprise and keep the syntax consistent.

// Parse the lowest level.
//
// An atom can be one of a long list of items.  Many atoms match one character
// in the text.  It is often an ordinary character or a character class.
// Braces can be used to make a pattern into an atom.  The "\z(\)" construct
// is only for syntax highlighting.
//
// atom    ::=     ordinary-atom
//     or  \( pattern \)
//     or  \%( pattern \)
//     or  \z( pattern \)
static int nfa_regatom(void)
{
  int c;
  int charclass;
  int equiclass;
  int collclass;
  int got_coll_char;
  uint8_t *p;
  uint8_t *endp;
  uint8_t *old_regparse = (uint8_t *)regparse;
  int extra = 0;
  int emit_range;
  int negated;
  int startc = -1;
  int save_prev_at_start = prev_at_start;

  c = getchr();
  switch (c) {
  case NUL:
    EMSG_RET_FAIL(_(e_nul_found));

  case Magic('^'):
    EMIT(NFA_BOL);
    break;

  case Magic('$'):
    EMIT(NFA_EOL);
    had_eol = true;
    break;

  case Magic('<'):
    EMIT(NFA_BOW);
    break;

  case Magic('>'):
    EMIT(NFA_EOW);
    break;

  case Magic('_'):
    c = no_Magic(getchr());
    if (c == NUL) {
      EMSG_RET_FAIL(_(e_nul_found));
    }

    if (c == '^') {             // "\_^" is start-of-line
      EMIT(NFA_BOL);
      break;
    }
    if (c == '$') {             // "\_$" is end-of-line
      EMIT(NFA_EOL);
      had_eol = true;
      break;
    }

    extra = NFA_ADD_NL;

    // "\_[" is collection plus newline
    if (c == '[') {
      goto collection;
    }

    // "\_x" is character class plus newline
    FALLTHROUGH;

  // Character classes.
  case Magic('.'):
  case Magic('i'):
  case Magic('I'):
  case Magic('k'):
  case Magic('K'):
  case Magic('f'):
  case Magic('F'):
  case Magic('p'):
  case Magic('P'):
  case Magic('s'):
  case Magic('S'):
  case Magic('d'):
  case Magic('D'):
  case Magic('x'):
  case Magic('X'):
  case Magic('o'):
  case Magic('O'):
  case Magic('w'):
  case Magic('W'):
  case Magic('h'):
  case Magic('H'):
  case Magic('a'):
  case Magic('A'):
  case Magic('l'):
  case Magic('L'):
  case Magic('u'):
  case Magic('U'):
    p = (uint8_t *)vim_strchr((char *)classchars, no_Magic(c));
    if (p == NULL) {
      if (extra == NFA_ADD_NL) {
        semsg(_(e_ill_char_class), (int64_t)c);
        rc_did_emsg = true;
        return FAIL;
      }
      siemsg("INTERNAL: Unknown character class char: %" PRId64, (int64_t)c);
      return FAIL;
    }
    // When '.' is followed by a composing char ignore the dot, so that
    // the composing char is matched here.
    if (c == Magic('.') && utf_iscomposing(peekchr())) {
      old_regparse = (uint8_t *)regparse;
      c = getchr();
      goto nfa_do_multibyte;
    }
    EMIT(nfa_classcodes[p - classchars]);
    if (extra == NFA_ADD_NL) {
      EMIT(NFA_NEWL);
      EMIT(NFA_OR);
      regflags |= RF_HASNL;
    }
    break;

  case Magic('n'):
    if (reg_string) {
      // In a string "\n" matches a newline character.
      EMIT(NL);
    } else {
      // In buffer text "\n" matches the end of a line.
      EMIT(NFA_NEWL);
      regflags |= RF_HASNL;
    }
    break;

  case Magic('('):
    if (nfa_reg(REG_PAREN) == FAIL) {
      return FAIL;                  // cascaded error
    }
    break;

  case Magic('|'):
  case Magic('&'):
  case Magic(')'):
    semsg(_(e_misplaced), (char)no_Magic(c));
    return FAIL;

  case Magic('='):
  case Magic('?'):
  case Magic('+'):
  case Magic('@'):
  case Magic('*'):
  case Magic('{'):
    // these should follow an atom, not form an atom
    semsg(_(e_misplaced), (char)no_Magic(c));
    return FAIL;

  case Magic('~'): {
    uint8_t *lp;

    // Previous substitute pattern.
    // Generated as "\%(pattern\)".
    if (reg_prev_sub == NULL) {
      emsg(_(e_nopresub));
      return FAIL;
    }
    for (lp = (uint8_t *)reg_prev_sub; *lp != NUL; lp += utf_ptr2len((char *)lp)) {
      EMIT(utf_ptr2char((char *)lp));
      if (lp != (uint8_t *)reg_prev_sub) {
        EMIT(NFA_CONCAT);
      }
    }
    EMIT(NFA_NOPEN);
    break;
  }

  case Magic('1'):
  case Magic('2'):
  case Magic('3'):
  case Magic('4'):
  case Magic('5'):
  case Magic('6'):
  case Magic('7'):
  case Magic('8'):
  case Magic('9'): {
    int refnum = no_Magic(c) - '1';

    if (!seen_endbrace(refnum + 1)) {
      return FAIL;
    }
    EMIT(NFA_BACKREF1 + refnum);
    rex.nfa_has_backref = true;
  }
  break;

  case Magic('z'):
    c = no_Magic(getchr());
    switch (c) {
    case 's':
      EMIT(NFA_ZSTART);
      if (!re_mult_next("\\zs")) {
        return false;
      }
      break;
    case 'e':
      EMIT(NFA_ZEND);
      rex.nfa_has_zend = true;
      if (!re_mult_next("\\zs")) {
        return false;
      }
      break;
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
      // \z1...\z9
      if ((reg_do_extmatch & REX_USE) == 0) {
        EMSG_RET_FAIL(_(e_z1_not_allowed));
      }
      EMIT(NFA_ZREF1 + (no_Magic(c) - '1'));
      // No need to set rex.nfa_has_backref, the sub-matches don't
      // change when \z1 .. \z9 matches or not.
      re_has_z = REX_USE;
      break;
    case '(':
      // \z(
      if (reg_do_extmatch != REX_SET) {
        EMSG_RET_FAIL(_(e_z_not_allowed));
      }
      if (nfa_reg(REG_ZPAREN) == FAIL) {
        return FAIL;                        // cascaded error
      }
      re_has_z = REX_SET;
      break;
    default:
      semsg(_("E867: (NFA) Unknown operator '\\z%c'"),
            no_Magic(c));
      return FAIL;
    }
    break;

  case Magic('%'):
    c = no_Magic(getchr());
    switch (c) {
    // () without a back reference
    case '(':
      if (nfa_reg(REG_NPAREN) == FAIL) {
        return FAIL;
      }
      EMIT(NFA_NOPEN);
      break;

    case 'd':               // %d123 decimal
    case 'o':               // %o123 octal
    case 'x':               // %xab hex 2
    case 'u':               // %uabcd hex 4
    case 'U':               // %U1234abcd hex 8
    {
      int64_t nr;

      switch (c) {
      case 'd':
        nr = getdecchrs(); break;
      case 'o':
        nr = getoctchrs(); break;
      case 'x':
        nr = gethexchrs(2); break;
      case 'u':
        nr = gethexchrs(4); break;
      case 'U':
        nr = gethexchrs(8); break;
      default:
        nr = -1; break;
      }

      if (nr < 0 || nr > INT_MAX) {
        EMSG2_RET_FAIL(_("E678: Invalid character after %s%%[dxouU]"),
                       reg_magic == MAGIC_ALL);
      }
      // A NUL is stored in the text as NL
      // TODO(vim): what if a composing character follows?
      EMIT(nr == 0 ? 0x0a : (int)nr);
    }
    break;

    // Catch \%^ and \%$ regardless of where they appear in the
    // pattern -- regardless of whether or not it makes sense.
    case '^':
      EMIT(NFA_BOF);
      break;

    case '$':
      EMIT(NFA_EOF);
      break;

    case '#':
      if (regparse[0] == '=' && regparse[1] >= 48
          && regparse[1] <= 50) {
        // misplaced \%#=1
        semsg(_(e_atom_engine_must_be_at_start_of_pattern), regparse[1]);
        return FAIL;
      }
      EMIT(NFA_CURSOR);
      break;

    case 'V':
      EMIT(NFA_VISUAL);
      break;

    case 'C':
      EMIT(NFA_ANY_COMPOSING);
      break;

    case '[': {
      int n;

      // \%[abc]
      for (n = 0; (c = peekchr()) != ']'; n++) {
        if (c == NUL) {
          EMSG2_RET_FAIL(_(e_missing_sb),
                         reg_magic == MAGIC_ALL);
        }
        // recursive call!
        if (nfa_regatom() == FAIL) {
          return FAIL;
        }
      }
      (void)getchr();  // get the ]
      if (n == 0) {
        EMSG2_RET_FAIL(_(e_empty_sb), reg_magic == MAGIC_ALL);
      }
      EMIT(NFA_OPT_CHARS);
      EMIT(n);

      // Emit as "\%(\%[abc]\)" to be able to handle
      // "\%[abc]*" which would cause the empty string to be
      // matched an unlimited number of times. NFA_NOPEN is
      // added only once at a position, while NFA_SPLIT is
      // added multiple times.  This is more efficient than
      // not allowing NFA_SPLIT multiple times, it is used
      // a lot.
      EMIT(NFA_NOPEN);
      break;
    }

    default: {
      int64_t n = 0;
      const int cmp = c;
      bool cur = false;
      bool got_digit = false;

      if (c == '<' || c == '>') {
        c = getchr();
      }
      if (no_Magic(c) == '.') {
        cur = true;
        c = getchr();
      }
      while (ascii_isdigit(c)) {
        if (cur) {
          semsg(_(e_regexp_number_after_dot_pos_search_chr), no_Magic(c));
          return FAIL;
        }
        if (n > (INT32_MAX - (c - '0')) / 10) {
          // overflow.
          emsg(_(e_value_too_large));
          return FAIL;
        }
        n = n * 10 + (c - '0');
        c = getchr();
        got_digit = true;
      }
      if (c == 'l' || c == 'c' || c == 'v') {
        int32_t limit = INT32_MAX;

        if (!cur && !got_digit) {
          semsg(_(e_nfa_regexp_missing_value_in_chr), no_Magic(c));
          return FAIL;
        }
        if (c == 'l') {
          if (cur) {
            n = curwin->w_cursor.lnum;
          }
          // \%{n}l  \%{n}<l  \%{n}>l
          EMIT(cmp == '<' ? NFA_LNUM_LT
                          : cmp == '>' ? NFA_LNUM_GT : NFA_LNUM);
          if (save_prev_at_start) {
            at_start = true;
          }
        } else if (c == 'c') {
          if (cur) {
            n = curwin->w_cursor.col;
            n++;
          }
          // \%{n}c  \%{n}<c  \%{n}>c
          EMIT(cmp == '<' ? NFA_COL_LT
                          : cmp == '>' ? NFA_COL_GT : NFA_COL);
        } else {
          if (cur) {
            colnr_T vcol = 0;
            getvvcol(curwin, &curwin->w_cursor, NULL, NULL, &vcol);
            n = ++vcol;
          }
          // \%{n}v  \%{n}<v  \%{n}>v
          EMIT(cmp == '<' ? NFA_VCOL_LT
                          : cmp == '>' ? NFA_VCOL_GT : NFA_VCOL);
          limit = INT32_MAX / MB_MAXBYTES;
        }
        if (n >= limit) {
          emsg(_(e_value_too_large));
          return FAIL;
        }
        EMIT((int)n);
        break;
      } else if (no_Magic(c) == '\'' && n == 0) {
        // \%'m  \%<'m  \%>'m
        EMIT(cmp == '<' ? NFA_MARK_LT
                        : cmp == '>' ? NFA_MARK_GT : NFA_MARK);
        EMIT(getchr());
        break;
      }
    }
      semsg(_("E867: (NFA) Unknown operator '\\%%%c'"),
            no_Magic(c));
      return FAIL;
    }
    break;

  case Magic('['):
collection:
    // [abc]  uses NFA_START_COLL - NFA_END_COLL
    // [^abc] uses NFA_START_NEG_COLL - NFA_END_NEG_COLL
    // Each character is produced as a regular state, using
    // NFA_CONCAT to bind them together.
    // Besides normal characters there can be:
    // - character classes  NFA_CLASS_*
    // - ranges, two characters followed by NFA_RANGE.

    p = (uint8_t *)regparse;
    endp = (uint8_t *)skip_anyof((char *)p);
    if (*endp == ']') {
      // Try to reverse engineer character classes. For example,
      // recognize that [0-9] stands for \d and [A-Za-z_] for \h,
      // and perform the necessary substitutions in the NFA.
      int result = nfa_recognize_char_class((uint8_t *)regparse, endp, extra == NFA_ADD_NL);
      if (result != FAIL) {
        if (result >= NFA_FIRST_NL && result <= NFA_LAST_NL) {
          EMIT(result - NFA_ADD_NL);
          EMIT(NFA_NEWL);
          EMIT(NFA_OR);
        } else {
          EMIT(result);
        }
        regparse = (char *)endp;
        MB_PTR_ADV(regparse);
        return OK;
      }
      // Failed to recognize a character class. Use the simple
      // version that turns [abc] into 'a' OR 'b' OR 'c'
      negated = false;
      if (*regparse == '^') {                           // negated range
        negated = true;
        MB_PTR_ADV(regparse);
        EMIT(NFA_START_NEG_COLL);
      } else {
        EMIT(NFA_START_COLL);
      }
      if (*regparse == '-') {
        startc = '-';
        EMIT(startc);
        EMIT(NFA_CONCAT);
        MB_PTR_ADV(regparse);
      }
      // Emit the OR branches for each character in the []
      emit_range = false;
      while ((uint8_t *)regparse < endp) {
        int oldstartc = startc;
        startc = -1;
        got_coll_char = false;
        if (*regparse == '[') {
          // Check for [: :], [= =], [. .]
          equiclass = collclass = 0;
          charclass = get_char_class(&regparse);
          if (charclass == CLASS_NONE) {
            equiclass = get_equi_class(&regparse);
            if (equiclass == 0) {
              collclass = get_coll_element(&regparse);
            }
          }

          // Character class like [:alpha:]
          if (charclass != CLASS_NONE) {
            switch (charclass) {
            case CLASS_ALNUM:
              EMIT(NFA_CLASS_ALNUM);
              break;
            case CLASS_ALPHA:
              EMIT(NFA_CLASS_ALPHA);
              break;
            case CLASS_BLANK:
              EMIT(NFA_CLASS_BLANK);
              break;
            case CLASS_CNTRL:
              EMIT(NFA_CLASS_CNTRL);
              break;
            case CLASS_DIGIT:
              EMIT(NFA_CLASS_DIGIT);
              break;
            case CLASS_GRAPH:
              EMIT(NFA_CLASS_GRAPH);
              break;
            case CLASS_LOWER:
              wants_nfa = true;
              EMIT(NFA_CLASS_LOWER);
              break;
            case CLASS_PRINT:
              EMIT(NFA_CLASS_PRINT);
              break;
            case CLASS_PUNCT:
              EMIT(NFA_CLASS_PUNCT);
              break;
            case CLASS_SPACE:
              EMIT(NFA_CLASS_SPACE);
              break;
            case CLASS_UPPER:
              wants_nfa = true;
              EMIT(NFA_CLASS_UPPER);
              break;
            case CLASS_XDIGIT:
              EMIT(NFA_CLASS_XDIGIT);
              break;
            case CLASS_TAB:
              EMIT(NFA_CLASS_TAB);
              break;
            case CLASS_RETURN:
              EMIT(NFA_CLASS_RETURN);
              break;
            case CLASS_BACKSPACE:
              EMIT(NFA_CLASS_BACKSPACE);
              break;
            case CLASS_ESCAPE:
              EMIT(NFA_CLASS_ESCAPE);
              break;
            case CLASS_IDENT:
              EMIT(NFA_CLASS_IDENT);
              break;
            case CLASS_KEYWORD:
              EMIT(NFA_CLASS_KEYWORD);
              break;
            case CLASS_FNAME:
              EMIT(NFA_CLASS_FNAME);
              break;
            }
            EMIT(NFA_CONCAT);
            continue;
          }
          // Try equivalence class [=a=] and the like
          if (equiclass != 0) {
            nfa_emit_equi_class(equiclass);
            continue;
          }
          // Try collating class like [. .]
          if (collclass != 0) {
            startc = collclass;                  // allow [.a.]-x as a range
            // Will emit the proper atom at the end of the
            // while loop.
          }
        }
        // Try a range like 'a-x' or '\t-z'. Also allows '-' as a
        // start character.
        if (*regparse == '-' && oldstartc != -1) {
          emit_range = true;
          startc = oldstartc;
          MB_PTR_ADV(regparse);
          continue;                         // reading the end of the range
        }

        // Now handle simple and escaped characters.
        // Only "\]", "\^", "\]" and "\\" are special in Vi.  Vim
        // accepts "\t", "\e", etc., but only when the 'l' flag in
        // 'cpoptions' is not included.
        if (*regparse == '\\'
            && (uint8_t *)regparse + 1 <= endp
            && (vim_strchr(REGEXP_INRANGE, (uint8_t)regparse[1]) != NULL
                || (!reg_cpo_lit
                    && vim_strchr(REGEXP_ABBR, (uint8_t)regparse[1])
                    != NULL))) {
          MB_PTR_ADV(regparse);

          if (*regparse == 'n') {
            startc = (reg_string || emit_range || regparse[1] == '-')
                     ? NL : NFA_NEWL;
          } else if (*regparse == 'd'
                     || *regparse == 'o'
                     || *regparse == 'x'
                     || *regparse == 'u'
                     || *regparse == 'U') {
            // TODO(RE): This needs more testing
            startc = coll_get_char();
            got_coll_char = true;
            MB_PTR_BACK(old_regparse, regparse);
          } else {
            // \r,\t,\e,\b
            startc = backslash_trans(*regparse);
          }
        }

        // Normal printable char
        if (startc == -1) {
          startc = utf_ptr2char(regparse);
        }

        // Previous char was '-', so this char is end of range.
        if (emit_range) {
          int endc = startc;
          startc = oldstartc;
          if (startc > endc) {
            EMSG_RET_FAIL(_(e_reverse_range));
          }

          if (endc > startc + 2) {
            // Emit a range instead of the sequence of
            // individual characters.
            if (startc == 0) {
              // \x00 is translated to \x0a, start at \x01.
              EMIT(1);
            } else {
              post_ptr--;                   // remove NFA_CONCAT
            }
            EMIT(endc);
            EMIT(NFA_RANGE);
            EMIT(NFA_CONCAT);
          } else if (utf_char2len(startc) > 1
                     || utf_char2len(endc) > 1) {
            // Emit the characters in the range.
            // "startc" was already emitted, so skip it.
            for (c = startc + 1; c <= endc; c++) {
              EMIT(c);
              EMIT(NFA_CONCAT);
            }
          } else {
            // Emit the range. "startc" was already emitted, so
            // skip it.
            for (c = startc + 1; c <= endc; c++) {
              EMIT(c);
              EMIT(NFA_CONCAT);
            }
          }
          emit_range = false;
          startc = -1;
        } else {
          // This char (startc) is not part of a range. Just
          // emit it.
          // Normally, simply emit startc. But if we get char
          // code=0 from a collating char, then replace it with
          // 0x0a.
          // This is needed to completely mimic the behaviour of
          // the backtracking engine.
          if (startc == NFA_NEWL) {
            // Line break can't be matched as part of the
            // collection, add an OR below. But not for negated
            // range.
            if (!negated) {
              extra = NFA_ADD_NL;
            }
          } else {
            if (got_coll_char == true && startc == 0) {
              EMIT(0x0a);
              EMIT(NFA_CONCAT);
            } else {
              EMIT(startc);
              if (utf_ptr2len(regparse) == utfc_ptr2len(regparse)) {
                EMIT(NFA_CONCAT);
              }
            }
          }
        }

        int plen;
        if (utf_ptr2len(regparse) != (plen = utfc_ptr2len(regparse))) {
          int i = utf_ptr2len(regparse);

          c = utf_ptr2char(regparse + i);

          // Add composing characters
          while (true) {
            if (c == 0) {
              // \x00 is translated to \x0a, start at \x01.
              EMIT(1);
            } else {
              EMIT(c);
            }
            EMIT(NFA_CONCAT);
            if ((i += utf_char2len(c)) >= plen) {
              break;
            }
            c = utf_ptr2char(regparse + i);
          }
          EMIT(NFA_COMPOSING);
          EMIT(NFA_CONCAT);
        }
        MB_PTR_ADV(regparse);
      }           // while (p < endp)

      MB_PTR_BACK(old_regparse, regparse);
      if (*regparse == '-') {               // if last, '-' is just a char
        EMIT('-');
        EMIT(NFA_CONCAT);
      }

      // skip the trailing ]
      regparse = (char *)endp;
      MB_PTR_ADV(regparse);

      // Mark end of the collection.
      if (negated == true) {
        EMIT(NFA_END_NEG_COLL);
      } else {
        EMIT(NFA_END_COLL);
      }

      // \_[] also matches \n but it's not negated
      if (extra == NFA_ADD_NL) {
        EMIT(reg_string ? NL : NFA_NEWL);
        EMIT(NFA_OR);
      }

      return OK;
    }         // if exists closing ]

    if (reg_strict) {
      EMSG_RET_FAIL(_(e_missingbracket));
    }
    FALLTHROUGH;

  default: {
    int plen;

nfa_do_multibyte:
    // plen is length of current char with composing chars
    if (utf_char2len(c) != (plen = utfc_ptr2len((char *)old_regparse))
        || utf_iscomposing(c)) {
      int i = 0;

      // A base character plus composing characters, or just one
      // or more composing characters.
      // This requires creating a separate atom as if enclosing
      // the characters in (), where NFA_COMPOSING is the ( and
      // NFA_END_COMPOSING is the ). Note that right now we are
      // building the postfix form, not the NFA itself;
      // a composing char could be: a, b, c, NFA_COMPOSING
      // where 'b' and 'c' are chars with codes > 256.
      while (true) {
        EMIT(c);
        if (i > 0) {
          EMIT(NFA_CONCAT);
        }
        if ((i += utf_char2len(c)) >= plen) {
          break;
        }
        c = utf_ptr2char((char *)old_regparse + i);
      }
      EMIT(NFA_COMPOSING);
      regparse = (char *)old_regparse + plen;
    } else {
      c = no_Magic(c);
      EMIT(c);
    }
    return OK;
  }
  }

  return OK;
}

// Parse something followed by possible [*+=].
//
// A piece is an atom, possibly followed by a multi, an indication of how many
// times the atom can be matched.  Example: "a*" matches any sequence of "a"
// characters: "", "a", "aa", etc.
//
// piece   ::=      atom
//      or  atom  multi
static int nfa_regpiece(void)
{
  int i;
  int op;
  int ret;
  int minval, maxval;
  bool greedy = true;  // Braces are prefixed with '-' ?
  parse_state_T old_state;
  parse_state_T new_state;
  int64_t c2;
  int old_post_pos;
  int my_post_start;
  int quest;

  // Save the current parse state, so that we can use it if <atom>{m,n} is
  // next.
  save_parse_state(&old_state);

  // store current pos in the postfix form, for \{m,n} involving 0s
  my_post_start = (int)(post_ptr - post_start);

  ret = nfa_regatom();
  if (ret == FAIL) {
    return FAIL;            // cascaded error
  }
  op = peekchr();
  if (re_multi_type(op) == NOT_MULTI) {
    return OK;
  }

  skipchr();
  switch (op) {
  case Magic('*'):
    EMIT(NFA_STAR);
    break;

  case Magic('+'):
    // Trick: Normally, (a*)\+ would match the whole input "aaa".  The
    // first and only submatch would be "aaa". But the backtracking
    // engine interprets the plus as "try matching one more time", and
    // a* matches a second time at the end of the input, the empty
    // string.
    // The submatch will be the empty string.
    //
    // In order to be consistent with the old engine, we replace
    // <atom>+ with <atom><atom>*
    restore_parse_state(&old_state);
    curchr = -1;
    if (nfa_regatom() == FAIL) {
      return FAIL;
    }
    EMIT(NFA_STAR);
    EMIT(NFA_CONCAT);
    skipchr();                  // skip the \+
    break;

  case Magic('@'):
    c2 = getdecchrs();
    op = no_Magic(getchr());
    i = 0;
    switch (op) {
    case '=':
      // \@=
      i = NFA_PREV_ATOM_NO_WIDTH;
      break;
    case '!':
      // \@!
      i = NFA_PREV_ATOM_NO_WIDTH_NEG;
      break;
    case '<':
      op = no_Magic(getchr());
      if (op == '=') {
        // \@<=
        i = NFA_PREV_ATOM_JUST_BEFORE;
      } else if (op == '!') {
        // \@<!
        i = NFA_PREV_ATOM_JUST_BEFORE_NEG;
      }
      break;
    case '>':
      // \@>
      i = NFA_PREV_ATOM_LIKE_PATTERN;
      break;
    }
    if (i == 0) {
      semsg(_("E869: (NFA) Unknown operator '\\@%c'"), op);
      return FAIL;
    }
    EMIT(i);
    if (i == NFA_PREV_ATOM_JUST_BEFORE
        || i == NFA_PREV_ATOM_JUST_BEFORE_NEG) {
      EMIT((int)c2);
    }
    break;

  case Magic('?'):
  case Magic('='):
    EMIT(NFA_QUEST);
    break;

  case Magic('{'):
    // a{2,5} will expand to 'aaa?a?a?'
    // a{-1,3} will expand to 'aa??a??', where ?? is the nongreedy
    // version of '?'
    // \v(ab){2,3} will expand to '(ab)(ab)(ab)?', where all the
    // parenthesis have the same id

    greedy = true;
    c2 = peekchr();
    if (c2 == '-' || c2 == Magic('-')) {
      skipchr();
      greedy = false;
    }
    if (!read_limits(&minval, &maxval)) {
      EMSG_RET_FAIL(_("E870: (NFA regexp) Error reading repetition limits"));
    }

    //  <atom>{0,inf}, <atom>{0,} and <atom>{}  are equivalent to
    //  <atom>*
    if (minval == 0 && maxval == MAX_LIMIT) {
      if (greedy) {
        // \{}, \{0,}
        EMIT(NFA_STAR);
      } else {
        // \{-}, \{-0,}
        EMIT(NFA_STAR_NONGREEDY);
      }
      break;
    }

    // Special case: x{0} or x{-0}
    if (maxval == 0) {
      // Ignore result of previous call to nfa_regatom()
      post_ptr = post_start + my_post_start;
      // NFA_EMPTY is 0-length and works everywhere
      EMIT(NFA_EMPTY);
      return OK;
    }

    // The engine is very inefficient (uses too many states) when the
    // maximum is much larger than the minimum and when the maximum is
    // large.  However, when maxval is MAX_LIMIT, it is okay, as this
    // will emit NFA_STAR.
    // Bail out if we can use the other engine, but only, when the
    // pattern does not need the NFA engine like (e.g. [[:upper:]]\{2,\}
    // does not work with characters > 8 bit with the BT engine)
    if ((nfa_re_flags & RE_AUTO)
        && (maxval > 500 || maxval > minval + 200)
        && (maxval != MAX_LIMIT && minval < 200)
        && !wants_nfa) {
      return FAIL;
    }

    // Ignore previous call to nfa_regatom()
    post_ptr = post_start + my_post_start;
    // Save parse state after the repeated atom and the \{}
    save_parse_state(&new_state);

    quest = (greedy == true ? NFA_QUEST : NFA_QUEST_NONGREEDY);
    for (i = 0; i < maxval; i++) {
      // Goto beginning of the repeated atom
      restore_parse_state(&old_state);
      old_post_pos = (int)(post_ptr - post_start);
      if (nfa_regatom() == FAIL) {
        return FAIL;
      }
      // after "minval" times, atoms are optional
      if (i + 1 > minval) {
        if (maxval == MAX_LIMIT) {
          if (greedy) {
            EMIT(NFA_STAR);
          } else {
            EMIT(NFA_STAR_NONGREEDY);
          }
        } else {
          EMIT(quest);
        }
      }
      if (old_post_pos != my_post_start) {
        EMIT(NFA_CONCAT);
      }
      if (i + 1 > minval && maxval == MAX_LIMIT) {
        break;
      }
    }

    // Go to just after the repeated atom and the \{}
    restore_parse_state(&new_state);
    curchr = -1;

    break;

  default:
    break;
  }     // end switch

  if (re_multi_type(peekchr()) != NOT_MULTI) {
    // Can't have a multi follow a multi.
    EMSG_RET_FAIL(_("E871: (NFA regexp) Can't have a multi follow a multi"));
  }

  return OK;
}

// Parse one or more pieces, concatenated.  It matches a match for the
// first piece, followed by a match for the second piece, etc.  Example:
// "f[0-9]b", first matches "f", then a digit and then "b".
//
// concat  ::=      piece
//      or  piece piece
//      or  piece piece piece
//      etc.
static int nfa_regconcat(void)
{
  bool cont = true;
  bool first = true;

  while (cont) {
    switch (peekchr()) {
    case NUL:
    case Magic('|'):
    case Magic('&'):
    case Magic(')'):
      cont = false;
      break;

    case Magic('Z'):
      regflags |= RF_ICOMBINE;
      skipchr_keepstart();
      break;
    case Magic('c'):
      regflags |= RF_ICASE;
      skipchr_keepstart();
      break;
    case Magic('C'):
      regflags |= RF_NOICASE;
      skipchr_keepstart();
      break;
    case Magic('v'):
      reg_magic = MAGIC_ALL;
      skipchr_keepstart();
      curchr = -1;
      break;
    case Magic('m'):
      reg_magic = MAGIC_ON;
      skipchr_keepstart();
      curchr = -1;
      break;
    case Magic('M'):
      reg_magic = MAGIC_OFF;
      skipchr_keepstart();
      curchr = -1;
      break;
    case Magic('V'):
      reg_magic = MAGIC_NONE;
      skipchr_keepstart();
      curchr = -1;
      break;

    default:
      if (nfa_regpiece() == FAIL) {
        return FAIL;
      }
      if (first == false) {
        EMIT(NFA_CONCAT);
      } else {
        first = false;
      }
      break;
    }
  }

  return OK;
}

// Parse a branch, one or more concats, separated by "\&".  It matches the
// last concat, but only if all the preceding concats also match at the same
// position.  Examples:
//      "foobeep\&..." matches "foo" in "foobeep".
//      ".*Peter\&.*Bob" matches in a line containing both "Peter" and "Bob"
//
// branch ::=       concat
//              or  concat \& concat
//              or  concat \& concat \& concat
//              etc.
static int nfa_regbranch(void)
{
  int old_post_pos;

  old_post_pos = (int)(post_ptr - post_start);

  // First branch, possibly the only one
  if (nfa_regconcat() == FAIL) {
    return FAIL;
  }

  // Try next concats
  while (peekchr() == Magic('&')) {
    skipchr();
    // if concat is empty do emit a node
    if (old_post_pos == (int)(post_ptr - post_start)) {
      EMIT(NFA_EMPTY);
    }
    EMIT(NFA_NOPEN);
    EMIT(NFA_PREV_ATOM_NO_WIDTH);
    old_post_pos = (int)(post_ptr - post_start);
    if (nfa_regconcat() == FAIL) {
      return FAIL;
    }
    // if concat is empty do emit a node
    if (old_post_pos == (int)(post_ptr - post_start)) {
      EMIT(NFA_EMPTY);
    }
    EMIT(NFA_CONCAT);
  }

  // if a branch is empty, emit one node for it
  if (old_post_pos == (int)(post_ptr - post_start)) {
    EMIT(NFA_EMPTY);
  }

  return OK;
}

///  Parse a pattern, one or more branches, separated by "\|".  It matches
///  anything that matches one of the branches.  Example: "foo\|beep" matches
///  "foo" and matches "beep".  If more than one branch matches, the first one
///  is used.
///
///  pattern ::=     branch
///      or  branch \| branch
///      or  branch \| branch \| branch
///      etc.
///
/// @param paren  REG_NOPAREN, REG_PAREN, REG_NPAREN or REG_ZPAREN
static int nfa_reg(int paren)
{
  int parno = 0;

  if (paren == REG_PAREN) {
    if (regnpar >= NSUBEXP) {   // Too many `('
      EMSG_RET_FAIL(_("E872: (NFA regexp) Too many '('"));
    }
    parno = regnpar++;
  } else if (paren == REG_ZPAREN) {
    // Make a ZOPEN node.
    if (regnzpar >= NSUBEXP) {
      EMSG_RET_FAIL(_("E879: (NFA regexp) Too many \\z("));
    }
    parno = regnzpar++;
  }

  if (nfa_regbranch() == FAIL) {
    return FAIL;            // cascaded error
  }
  while (peekchr() == Magic('|')) {
    skipchr();
    if (nfa_regbranch() == FAIL) {
      return FAIL;          // cascaded error
    }
    EMIT(NFA_OR);
  }

  // Check for proper termination.
  if (paren != REG_NOPAREN && getchr() != Magic(')')) {
    if (paren == REG_NPAREN) {
      EMSG2_RET_FAIL(_(e_unmatchedpp), reg_magic == MAGIC_ALL);
    } else {
      EMSG2_RET_FAIL(_(e_unmatchedp), reg_magic == MAGIC_ALL);
    }
  } else if (paren == REG_NOPAREN && peekchr() != NUL) {
    if (peekchr() == Magic(')')) {
      EMSG2_RET_FAIL(_(e_unmatchedpar), reg_magic == MAGIC_ALL);
    } else {
      EMSG_RET_FAIL(_("E873: (NFA regexp) proper termination error"));
    }
  }
  // Here we set the flag allowing back references to this set of
  // parentheses.
  if (paren == REG_PAREN) {
    had_endbrace[parno] = true;  // have seen the close paren
    EMIT(NFA_MOPEN + parno);
  } else if (paren == REG_ZPAREN) {
    EMIT(NFA_ZOPEN + parno);
  }

  return OK;
}

#ifdef REGEXP_DEBUG
static uint8_t code[50];

static void nfa_set_code(int c)
{
  int addnl = false;

  if (c >= NFA_FIRST_NL && c <= NFA_LAST_NL) {
    addnl = true;
    c -= NFA_ADD_NL;
  }

  STRCPY(code, "");
  switch (c) {
  case NFA_MATCH:
    STRCPY(code, "NFA_MATCH "); break;
  case NFA_SPLIT:
    STRCPY(code, "NFA_SPLIT "); break;
  case NFA_CONCAT:
    STRCPY(code, "NFA_CONCAT "); break;
  case NFA_NEWL:
    STRCPY(code, "NFA_NEWL "); break;
  case NFA_ZSTART:
    STRCPY(code, "NFA_ZSTART"); break;
  case NFA_ZEND:
    STRCPY(code, "NFA_ZEND"); break;

  case NFA_BACKREF1:
    STRCPY(code, "NFA_BACKREF1"); break;
  case NFA_BACKREF2:
    STRCPY(code, "NFA_BACKREF2"); break;
  case NFA_BACKREF3:
    STRCPY(code, "NFA_BACKREF3"); break;
  case NFA_BACKREF4:
    STRCPY(code, "NFA_BACKREF4"); break;
  case NFA_BACKREF5:
    STRCPY(code, "NFA_BACKREF5"); break;
  case NFA_BACKREF6:
    STRCPY(code, "NFA_BACKREF6"); break;
  case NFA_BACKREF7:
    STRCPY(code, "NFA_BACKREF7"); break;
  case NFA_BACKREF8:
    STRCPY(code, "NFA_BACKREF8"); break;
  case NFA_BACKREF9:
    STRCPY(code, "NFA_BACKREF9"); break;
  case NFA_ZREF1:
    STRCPY(code, "NFA_ZREF1"); break;
  case NFA_ZREF2:
    STRCPY(code, "NFA_ZREF2"); break;
  case NFA_ZREF3:
    STRCPY(code, "NFA_ZREF3"); break;
  case NFA_ZREF4:
    STRCPY(code, "NFA_ZREF4"); break;
  case NFA_ZREF5:
    STRCPY(code, "NFA_ZREF5"); break;
  case NFA_ZREF6:
    STRCPY(code, "NFA_ZREF6"); break;
  case NFA_ZREF7:
    STRCPY(code, "NFA_ZREF7"); break;
  case NFA_ZREF8:
    STRCPY(code, "NFA_ZREF8"); break;
  case NFA_ZREF9:
    STRCPY(code, "NFA_ZREF9"); break;
  case NFA_SKIP:
    STRCPY(code, "NFA_SKIP"); break;

  case NFA_PREV_ATOM_NO_WIDTH:
    STRCPY(code, "NFA_PREV_ATOM_NO_WIDTH"); break;
  case NFA_PREV_ATOM_NO_WIDTH_NEG:
    STRCPY(code, "NFA_PREV_ATOM_NO_WIDTH_NEG"); break;
  case NFA_PREV_ATOM_JUST_BEFORE:
    STRCPY(code, "NFA_PREV_ATOM_JUST_BEFORE"); break;
  case NFA_PREV_ATOM_JUST_BEFORE_NEG:
    STRCPY(code, "NFA_PREV_ATOM_JUST_BEFORE_NEG"); break;
  case NFA_PREV_ATOM_LIKE_PATTERN:
    STRCPY(code, "NFA_PREV_ATOM_LIKE_PATTERN"); break;

  case NFA_NOPEN:
    STRCPY(code, "NFA_NOPEN"); break;
  case NFA_NCLOSE:
    STRCPY(code, "NFA_NCLOSE"); break;
  case NFA_START_INVISIBLE:
    STRCPY(code, "NFA_START_INVISIBLE"); break;
  case NFA_START_INVISIBLE_FIRST:
    STRCPY(code, "NFA_START_INVISIBLE_FIRST"); break;
  case NFA_START_INVISIBLE_NEG:
    STRCPY(code, "NFA_START_INVISIBLE_NEG"); break;
  case NFA_START_INVISIBLE_NEG_FIRST:
    STRCPY(code, "NFA_START_INVISIBLE_NEG_FIRST"); break;
  case NFA_START_INVISIBLE_BEFORE:
    STRCPY(code, "NFA_START_INVISIBLE_BEFORE"); break;
  case NFA_START_INVISIBLE_BEFORE_FIRST:
    STRCPY(code, "NFA_START_INVISIBLE_BEFORE_FIRST"); break;
  case NFA_START_INVISIBLE_BEFORE_NEG:
    STRCPY(code, "NFA_START_INVISIBLE_BEFORE_NEG"); break;
  case NFA_START_INVISIBLE_BEFORE_NEG_FIRST:
    STRCPY(code, "NFA_START_INVISIBLE_BEFORE_NEG_FIRST"); break;
  case NFA_START_PATTERN:
    STRCPY(code, "NFA_START_PATTERN"); break;
  case NFA_END_INVISIBLE:
    STRCPY(code, "NFA_END_INVISIBLE"); break;
  case NFA_END_INVISIBLE_NEG:
    STRCPY(code, "NFA_END_INVISIBLE_NEG"); break;
  case NFA_END_PATTERN:
    STRCPY(code, "NFA_END_PATTERN"); break;

  case NFA_COMPOSING:
    STRCPY(code, "NFA_COMPOSING"); break;
  case NFA_END_COMPOSING:
    STRCPY(code, "NFA_END_COMPOSING"); break;
  case NFA_OPT_CHARS:
    STRCPY(code, "NFA_OPT_CHARS"); break;

  case NFA_MOPEN:
  case NFA_MOPEN1:
  case NFA_MOPEN2:
  case NFA_MOPEN3:
  case NFA_MOPEN4:
  case NFA_MOPEN5:
  case NFA_MOPEN6:
  case NFA_MOPEN7:
  case NFA_MOPEN8:
  case NFA_MOPEN9:
    STRCPY(code, "NFA_MOPEN(x)");
    code[10] = c - NFA_MOPEN + '0';
    break;
  case NFA_MCLOSE:
  case NFA_MCLOSE1:
  case NFA_MCLOSE2:
  case NFA_MCLOSE3:
  case NFA_MCLOSE4:
  case NFA_MCLOSE5:
  case NFA_MCLOSE6:
  case NFA_MCLOSE7:
  case NFA_MCLOSE8:
  case NFA_MCLOSE9:
    STRCPY(code, "NFA_MCLOSE(x)");
    code[11] = c - NFA_MCLOSE + '0';
    break;
  case NFA_ZOPEN:
  case NFA_ZOPEN1:
  case NFA_ZOPEN2:
  case NFA_ZOPEN3:
  case NFA_ZOPEN4:
  case NFA_ZOPEN5:
  case NFA_ZOPEN6:
  case NFA_ZOPEN7:
  case NFA_ZOPEN8:
  case NFA_ZOPEN9:
    STRCPY(code, "NFA_ZOPEN(x)");
    code[10] = c - NFA_ZOPEN + '0';
    break;
  case NFA_ZCLOSE:
  case NFA_ZCLOSE1:
  case NFA_ZCLOSE2:
  case NFA_ZCLOSE3:
  case NFA_ZCLOSE4:
  case NFA_ZCLOSE5:
  case NFA_ZCLOSE6:
  case NFA_ZCLOSE7:
  case NFA_ZCLOSE8:
  case NFA_ZCLOSE9:
    STRCPY(code, "NFA_ZCLOSE(x)");
    code[11] = c - NFA_ZCLOSE + '0';
    break;
  case NFA_EOL:
    STRCPY(code, "NFA_EOL "); break;
  case NFA_BOL:
    STRCPY(code, "NFA_BOL "); break;
  case NFA_EOW:
    STRCPY(code, "NFA_EOW "); break;
  case NFA_BOW:
    STRCPY(code, "NFA_BOW "); break;
  case NFA_EOF:
    STRCPY(code, "NFA_EOF "); break;
  case NFA_BOF:
    STRCPY(code, "NFA_BOF "); break;
  case NFA_LNUM:
    STRCPY(code, "NFA_LNUM "); break;
  case NFA_LNUM_GT:
    STRCPY(code, "NFA_LNUM_GT "); break;
  case NFA_LNUM_LT:
    STRCPY(code, "NFA_LNUM_LT "); break;
  case NFA_COL:
    STRCPY(code, "NFA_COL "); break;
  case NFA_COL_GT:
    STRCPY(code, "NFA_COL_GT "); break;
  case NFA_COL_LT:
    STRCPY(code, "NFA_COL_LT "); break;
  case NFA_VCOL:
    STRCPY(code, "NFA_VCOL "); break;
  case NFA_VCOL_GT:
    STRCPY(code, "NFA_VCOL_GT "); break;
  case NFA_VCOL_LT:
    STRCPY(code, "NFA_VCOL_LT "); break;
  case NFA_MARK:
    STRCPY(code, "NFA_MARK "); break;
  case NFA_MARK_GT:
    STRCPY(code, "NFA_MARK_GT "); break;
  case NFA_MARK_LT:
    STRCPY(code, "NFA_MARK_LT "); break;
  case NFA_CURSOR:
    STRCPY(code, "NFA_CURSOR "); break;
  case NFA_VISUAL:
    STRCPY(code, "NFA_VISUAL "); break;
  case NFA_ANY_COMPOSING:
    STRCPY(code, "NFA_ANY_COMPOSING "); break;

  case NFA_STAR:
    STRCPY(code, "NFA_STAR "); break;
  case NFA_STAR_NONGREEDY:
    STRCPY(code, "NFA_STAR_NONGREEDY "); break;
  case NFA_QUEST:
    STRCPY(code, "NFA_QUEST"); break;
  case NFA_QUEST_NONGREEDY:
    STRCPY(code, "NFA_QUEST_NON_GREEDY"); break;
  case NFA_EMPTY:
    STRCPY(code, "NFA_EMPTY"); break;
  case NFA_OR:
    STRCPY(code, "NFA_OR"); break;

  case NFA_START_COLL:
    STRCPY(code, "NFA_START_COLL"); break;
  case NFA_END_COLL:
    STRCPY(code, "NFA_END_COLL"); break;
  case NFA_START_NEG_COLL:
    STRCPY(code, "NFA_START_NEG_COLL"); break;
  case NFA_END_NEG_COLL:
    STRCPY(code, "NFA_END_NEG_COLL"); break;
  case NFA_RANGE:
    STRCPY(code, "NFA_RANGE"); break;
  case NFA_RANGE_MIN:
    STRCPY(code, "NFA_RANGE_MIN"); break;
  case NFA_RANGE_MAX:
    STRCPY(code, "NFA_RANGE_MAX"); break;

  case NFA_CLASS_ALNUM:
    STRCPY(code, "NFA_CLASS_ALNUM"); break;
  case NFA_CLASS_ALPHA:
    STRCPY(code, "NFA_CLASS_ALPHA"); break;
  case NFA_CLASS_BLANK:
    STRCPY(code, "NFA_CLASS_BLANK"); break;
  case NFA_CLASS_CNTRL:
    STRCPY(code, "NFA_CLASS_CNTRL"); break;
  case NFA_CLASS_DIGIT:
    STRCPY(code, "NFA_CLASS_DIGIT"); break;
  case NFA_CLASS_GRAPH:
    STRCPY(code, "NFA_CLASS_GRAPH"); break;
  case NFA_CLASS_LOWER:
    STRCPY(code, "NFA_CLASS_LOWER"); break;
  case NFA_CLASS_PRINT:
    STRCPY(code, "NFA_CLASS_PRINT"); break;
  case NFA_CLASS_PUNCT:
    STRCPY(code, "NFA_CLASS_PUNCT"); break;
  case NFA_CLASS_SPACE:
    STRCPY(code, "NFA_CLASS_SPACE"); break;
  case NFA_CLASS_UPPER:
    STRCPY(code, "NFA_CLASS_UPPER"); break;
  case NFA_CLASS_XDIGIT:
    STRCPY(code, "NFA_CLASS_XDIGIT"); break;
  case NFA_CLASS_TAB:
    STRCPY(code, "NFA_CLASS_TAB"); break;
  case NFA_CLASS_RETURN:
    STRCPY(code, "NFA_CLASS_RETURN"); break;
  case NFA_CLASS_BACKSPACE:
    STRCPY(code, "NFA_CLASS_BACKSPACE"); break;
  case NFA_CLASS_ESCAPE:
    STRCPY(code, "NFA_CLASS_ESCAPE"); break;
  case NFA_CLASS_IDENT:
    STRCPY(code, "NFA_CLASS_IDENT"); break;
  case NFA_CLASS_KEYWORD:
    STRCPY(code, "NFA_CLASS_KEYWORD"); break;
  case NFA_CLASS_FNAME:
    STRCPY(code, "NFA_CLASS_FNAME"); break;

  case NFA_ANY:
    STRCPY(code, "NFA_ANY"); break;
  case NFA_IDENT:
    STRCPY(code, "NFA_IDENT"); break;
  case NFA_SIDENT:
    STRCPY(code, "NFA_SIDENT"); break;
  case NFA_KWORD:
    STRCPY(code, "NFA_KWORD"); break;
  case NFA_SKWORD:
    STRCPY(code, "NFA_SKWORD"); break;
  case NFA_FNAME:
    STRCPY(code, "NFA_FNAME"); break;
  case NFA_SFNAME:
    STRCPY(code, "NFA_SFNAME"); break;
  case NFA_PRINT:
    STRCPY(code, "NFA_PRINT"); break;
  case NFA_SPRINT:
    STRCPY(code, "NFA_SPRINT"); break;
  case NFA_WHITE:
    STRCPY(code, "NFA_WHITE"); break;
  case NFA_NWHITE:
    STRCPY(code, "NFA_NWHITE"); break;
  case NFA_DIGIT:
    STRCPY(code, "NFA_DIGIT"); break;
  case NFA_NDIGIT:
    STRCPY(code, "NFA_NDIGIT"); break;
  case NFA_HEX:
    STRCPY(code, "NFA_HEX"); break;
  case NFA_NHEX:
    STRCPY(code, "NFA_NHEX"); break;
  case NFA_OCTAL:
    STRCPY(code, "NFA_OCTAL"); break;
  case NFA_NOCTAL:
    STRCPY(code, "NFA_NOCTAL"); break;
  case NFA_WORD:
    STRCPY(code, "NFA_WORD"); break;
  case NFA_NWORD:
    STRCPY(code, "NFA_NWORD"); break;
  case NFA_HEAD:
    STRCPY(code, "NFA_HEAD"); break;
  case NFA_NHEAD:
    STRCPY(code, "NFA_NHEAD"); break;
  case NFA_ALPHA:
    STRCPY(code, "NFA_ALPHA"); break;
  case NFA_NALPHA:
    STRCPY(code, "NFA_NALPHA"); break;
  case NFA_LOWER:
    STRCPY(code, "NFA_LOWER"); break;
  case NFA_NLOWER:
    STRCPY(code, "NFA_NLOWER"); break;
  case NFA_UPPER:
    STRCPY(code, "NFA_UPPER"); break;
  case NFA_NUPPER:
    STRCPY(code, "NFA_NUPPER"); break;
  case NFA_LOWER_IC:
    STRCPY(code, "NFA_LOWER_IC"); break;
  case NFA_NLOWER_IC:
    STRCPY(code, "NFA_NLOWER_IC"); break;
  case NFA_UPPER_IC:
    STRCPY(code, "NFA_UPPER_IC"); break;
  case NFA_NUPPER_IC:
    STRCPY(code, "NFA_NUPPER_IC"); break;

  default:
    STRCPY(code, "CHAR(x)");
    code[5] = c;
  }

  if (addnl == true) {
    strcat(code, " + NEWLINE ");
  }
}

static FILE *log_fd;
static const uint8_t e_log_open_failed[] =
  N_("Could not open temporary log file for writing, displaying on stderr... ");

// Print the postfix notation of the current regexp.
static void nfa_postfix_dump(uint8_t *expr, int retval)
{
  int *p;
  FILE *f;

  f = fopen(NFA_REGEXP_DUMP_LOG, "a");
  if (f == NULL) {
    return;
  }

  fprintf(f, "\n-------------------------\n");
  if (retval == FAIL) {
    fprintf(f, ">>> NFA engine failed... \n");
  } else if (retval == OK) {
    fprintf(f, ">>> NFA engine succeeded !\n");
  }
  fprintf(f, "Regexp: \"%s\"\nPostfix notation (char): \"", expr);
  for (p = post_start; *p && p < post_ptr; p++) {
    nfa_set_code(*p);
    fprintf(f, "%s, ", code);
  }
  fprintf(f, "\"\nPostfix notation (int): ");
  for (p = post_start; *p && p < post_ptr; p++) {
    fprintf(f, "%d ", *p);
  }
  fprintf(f, "\n\n");
  fclose(f);
}

// Print the NFA starting with a root node "state".
static void nfa_print_state(FILE *debugf, nfa_state_T *state)
{
  garray_T indent;

  ga_init(&indent, 1, 64);
  ga_append(&indent, NUL);
  nfa_print_state2(debugf, state, &indent);
  ga_clear(&indent);
}

static void nfa_print_state2(FILE *debugf, nfa_state_T *state, garray_T *indent)
{
  uint8_t *p;

  if (state == NULL) {
    return;
  }

  fprintf(debugf, "(%2d)", abs(state->id));

  // Output indent
  p = (uint8_t *)indent->ga_data;
  if (indent->ga_len >= 3) {
    int last = indent->ga_len - 3;
    uint8_t save[2];

    strncpy(save, &p[last], 2);  // NOLINT(runtime/printf)
    memcpy(&p[last], "+-", 2);
    fprintf(debugf, " %s", p);
    strncpy(&p[last], save, 2);  // NOLINT(runtime/printf)
  } else {
    fprintf(debugf, " %s", p);
  }

  nfa_set_code(state->c);
  fprintf(debugf, "%s (%d) (id=%d) val=%d\n",
          code,
          state->c,
          abs(state->id),
          state->val);
  if (state->id < 0) {
    return;
  }

  state->id = abs(state->id) * -1;

  // grow indent for state->out
  indent->ga_len -= 1;
  if (state->out1) {
    ga_concat(indent, (uint8_t *)"| ");
  } else {
    ga_concat(indent, (uint8_t *)"  ");
  }
  ga_append(indent, NUL);

  nfa_print_state2(debugf, state->out, indent);

  // replace last part of indent for state->out1
  indent->ga_len -= 3;
  ga_concat(indent, (uint8_t *)"  ");
  ga_append(indent, NUL);

  nfa_print_state2(debugf, state->out1, indent);

  // shrink indent
  indent->ga_len -= 3;
  ga_append(indent, NUL);
}

// Print the NFA state machine.
static void nfa_dump(nfa_regprog_T *prog)
{
  FILE *debugf = fopen(NFA_REGEXP_DUMP_LOG, "a");

  if (debugf == NULL) {
    return;
  }

  nfa_print_state(debugf, prog->start);

  if (prog->reganch) {
    fprintf(debugf, "reganch: %d\n", prog->reganch);
  }
  if (prog->regstart != NUL) {
    fprintf(debugf, "regstart: %c (decimal: %d)\n",
            prog->regstart, prog->regstart);
  }
  if (prog->match_text != NULL) {
    fprintf(debugf, "match_text: \"%s\"\n", prog->match_text);
  }

  fclose(debugf);
}
#endif  // REGEXP_DEBUG

// Parse r.e. @expr and convert it into postfix form.
// Return the postfix string on success, NULL otherwise.
static int *re2post(void)
{
  if (nfa_reg(REG_NOPAREN) == FAIL) {
    return NULL;
  }
  EMIT(NFA_MOPEN);
  return post_start;
}

// NB. Some of the code below is inspired by Russ's.

// Represents an NFA state plus zero or one or two arrows exiting.
// if c == MATCH, no arrows out; matching state.
// If c == SPLIT, unlabeled arrows to out and out1 (if != NULL).
// If c < 256, labeled arrow with character c to out.

static nfa_state_T *state_ptr;  // points to nfa_prog->state

// Allocate and initialize nfa_state_T.
static nfa_state_T *alloc_state(int c, nfa_state_T *out, nfa_state_T *out1)
{
  nfa_state_T *s;

  if (istate >= nstate) {
    return NULL;
  }

  s = &state_ptr[istate++];

  s->c = c;
  s->out = out;
  s->out1 = out1;
  s->val = 0;

  s->id = istate;
  s->lastlist[0] = 0;
  s->lastlist[1] = 0;

  return s;
}

// A partially built NFA without the matching state filled in.
// Frag_T.start points at the start state.
// Frag_T.out is a list of places that need to be set to the
// next state for this fragment.

// Initialize a Frag_T struct and return it.
static Frag_T frag(nfa_state_T *start, Ptrlist *out)
{
  Frag_T n;

  n.start = start;
  n.out = out;
  return n;
}

// Create singleton list containing just outp.
static Ptrlist *list1(nfa_state_T **outp)
{
  Ptrlist *l;

  l = (Ptrlist *)outp;
  l->next = NULL;
  return l;
}

// Patch the list of states at out to point to start.
static void patch(Ptrlist *l, nfa_state_T *s)
{
  Ptrlist *next;

  for (; l; l = next) {
    next = l->next;
    l->s = s;
  }
}

// Join the two lists l1 and l2, returning the combination.
static Ptrlist *append(Ptrlist *l1, Ptrlist *l2)
{
  Ptrlist *oldl1;

  oldl1 = l1;
  while (l1->next) {
    l1 = l1->next;
  }
  l1->next = l2;
  return oldl1;
}

// Stack used for transforming postfix form into NFA.
static Frag_T empty;

static void st_error(int *postfix, int *end, int *p)
{
#ifdef NFA_REGEXP_ERROR_LOG
  FILE *df;
  int *p2;

  df = fopen(NFA_REGEXP_ERROR_LOG, "a");
  if (df) {
    fprintf(df, "Error popping the stack!\n");
# ifdef REGEXP_DEBUG
    fprintf(df, "Current regexp is \"%s\"\n", nfa_regengine.expr);
# endif
    fprintf(df, "Postfix form is: ");
# ifdef REGEXP_DEBUG
    for (p2 = postfix; p2 < end; p2++) {
      nfa_set_code(*p2);
      fprintf(df, "%s, ", code);
    }
    nfa_set_code(*p);
    fprintf(df, "\nCurrent position is: ");
    for (p2 = postfix; p2 <= p; p2++) {
      nfa_set_code(*p2);
      fprintf(df, "%s, ", code);
    }
# else
    for (p2 = postfix; p2 < end; p2++) {
      fprintf(df, "%d, ", *p2);
    }
    fprintf(df, "\nCurrent position is: ");
    for (p2 = postfix; p2 <= p; p2++) {
      fprintf(df, "%d, ", *p2);
    }
# endif
    fprintf(df, "\n--------------------------\n");
    fclose(df);
  }
#endif
  emsg(_("E874: (NFA) Could not pop the stack!"));
}

// Push an item onto the stack.
static void st_push(Frag_T s, Frag_T **p, Frag_T *stack_end)
{
  Frag_T *stackp = *p;

  if (stackp >= stack_end) {
    return;
  }
  *stackp = s;
  *p = *p + 1;
}

// Pop an item from the stack.
static Frag_T st_pop(Frag_T **p, Frag_T *stack)
{
  Frag_T *stackp;

  *p = *p - 1;
  stackp = *p;
  if (stackp < stack) {
    return empty;
  }
  return **p;
}

// Estimate the maximum byte length of anything matching "state".
// When unknown or unlimited return -1.
static int nfa_max_width(nfa_state_T *startstate, int depth)
{
  int l, r;
  nfa_state_T *state = startstate;
  int len = 0;

  // detect looping in a NFA_SPLIT
  if (depth > 4) {
    return -1;
  }

  while (state != NULL) {
    switch (state->c) {
    case NFA_END_INVISIBLE:
    case NFA_END_INVISIBLE_NEG:
      // the end, return what we have
      return len;

    case NFA_SPLIT:
      // two alternatives, use the maximum
      l = nfa_max_width(state->out, depth + 1);
      r = nfa_max_width(state->out1, depth + 1);
      if (l < 0 || r < 0) {
        return -1;
      }
      return len + (l > r ? l : r);

    case NFA_ANY:
    case NFA_START_COLL:
    case NFA_START_NEG_COLL:
      // Matches some character, including composing chars.
      len += MB_MAXBYTES;
      if (state->c != NFA_ANY) {
        // Skip over the characters.
        state = state->out1->out;
        continue;
      }
      break;

    case NFA_DIGIT:
    case NFA_WHITE:
    case NFA_HEX:
    case NFA_OCTAL:
      // ascii
      len++;
      break;

    case NFA_IDENT:
    case NFA_SIDENT:
    case NFA_KWORD:
    case NFA_SKWORD:
    case NFA_FNAME:
    case NFA_SFNAME:
    case NFA_PRINT:
    case NFA_SPRINT:
    case NFA_NWHITE:
    case NFA_NDIGIT:
    case NFA_NHEX:
    case NFA_NOCTAL:
    case NFA_WORD:
    case NFA_NWORD:
    case NFA_HEAD:
    case NFA_NHEAD:
    case NFA_ALPHA:
    case NFA_NALPHA:
    case NFA_LOWER:
    case NFA_NLOWER:
    case NFA_UPPER:
    case NFA_NUPPER:
    case NFA_LOWER_IC:
    case NFA_NLOWER_IC:
    case NFA_UPPER_IC:
    case NFA_NUPPER_IC:
    case NFA_ANY_COMPOSING:
      // possibly non-ascii
      len += 3;
      break;

    case NFA_START_INVISIBLE:
    case NFA_START_INVISIBLE_NEG:
    case NFA_START_INVISIBLE_BEFORE:
    case NFA_START_INVISIBLE_BEFORE_NEG:
      // zero-width, out1 points to the END state
      state = state->out1->out;
      continue;

    case NFA_BACKREF1:
    case NFA_BACKREF2:
    case NFA_BACKREF3:
    case NFA_BACKREF4:
    case NFA_BACKREF5:
    case NFA_BACKREF6:
    case NFA_BACKREF7:
    case NFA_BACKREF8:
    case NFA_BACKREF9:
    case NFA_ZREF1:
    case NFA_ZREF2:
    case NFA_ZREF3:
    case NFA_ZREF4:
    case NFA_ZREF5:
    case NFA_ZREF6:
    case NFA_ZREF7:
    case NFA_ZREF8:
    case NFA_ZREF9:
    case NFA_NEWL:
    case NFA_SKIP:
      // unknown width
      return -1;

    case NFA_BOL:
    case NFA_EOL:
    case NFA_BOF:
    case NFA_EOF:
    case NFA_BOW:
    case NFA_EOW:
    case NFA_MOPEN:
    case NFA_MOPEN1:
    case NFA_MOPEN2:
    case NFA_MOPEN3:
    case NFA_MOPEN4:
    case NFA_MOPEN5:
    case NFA_MOPEN6:
    case NFA_MOPEN7:
    case NFA_MOPEN8:
    case NFA_MOPEN9:
    case NFA_ZOPEN:
    case NFA_ZOPEN1:
    case NFA_ZOPEN2:
    case NFA_ZOPEN3:
    case NFA_ZOPEN4:
    case NFA_ZOPEN5:
    case NFA_ZOPEN6:
    case NFA_ZOPEN7:
    case NFA_ZOPEN8:
    case NFA_ZOPEN9:
    case NFA_ZCLOSE:
    case NFA_ZCLOSE1:
    case NFA_ZCLOSE2:
    case NFA_ZCLOSE3:
    case NFA_ZCLOSE4:
    case NFA_ZCLOSE5:
    case NFA_ZCLOSE6:
    case NFA_ZCLOSE7:
    case NFA_ZCLOSE8:
    case NFA_ZCLOSE9:
    case NFA_MCLOSE:
    case NFA_MCLOSE1:
    case NFA_MCLOSE2:
    case NFA_MCLOSE3:
    case NFA_MCLOSE4:
    case NFA_MCLOSE5:
    case NFA_MCLOSE6:
    case NFA_MCLOSE7:
    case NFA_MCLOSE8:
    case NFA_MCLOSE9:
    case NFA_NOPEN:
    case NFA_NCLOSE:

    case NFA_LNUM_GT:
    case NFA_LNUM_LT:
    case NFA_COL_GT:
    case NFA_COL_LT:
    case NFA_VCOL_GT:
    case NFA_VCOL_LT:
    case NFA_MARK_GT:
    case NFA_MARK_LT:
    case NFA_VISUAL:
    case NFA_LNUM:
    case NFA_CURSOR:
    case NFA_COL:
    case NFA_VCOL:
    case NFA_MARK:

    case NFA_ZSTART:
    case NFA_ZEND:
    case NFA_OPT_CHARS:
    case NFA_EMPTY:
    case NFA_START_PATTERN:
    case NFA_END_PATTERN:
    case NFA_COMPOSING:
    case NFA_END_COMPOSING:
      // zero-width
      break;

    default:
      if (state->c < 0) {
        // don't know what this is
        return -1;
      }
      // normal character
      len += utf_char2len(state->c);
      break;
    }

    // normal way to continue
    state = state->out;
  }

  // unrecognized, "cannot happen"
  return -1;
}

// Convert a postfix form into its equivalent NFA.
// Return the NFA start state on success, NULL otherwise.
static nfa_state_T *post2nfa(int *postfix, int *end, int nfa_calc_size)
{
  int *p;
  int mopen;
  int mclose;
  Frag_T *stack = NULL;
  Frag_T *stackp = NULL;
  Frag_T *stack_end = NULL;
  Frag_T e1;
  Frag_T e2;
  Frag_T e;
  nfa_state_T *s;
  nfa_state_T *s1;
  nfa_state_T *matchstate;
  nfa_state_T *ret = NULL;

  if (postfix == NULL) {
    return NULL;
  }

#define PUSH(s)     st_push((s), &stackp, stack_end)
#define POP()       st_pop(&stackp, stack); \
  if (stackp < stack) { \
    st_error(postfix, end, p); \
    xfree(stack); \
    return NULL; \
  }

  if (nfa_calc_size == false) {
    // Allocate space for the stack. Max states on the stack: "nstate".
    stack = xmalloc((size_t)(nstate + 1) * sizeof(Frag_T));
    stackp = stack;
    stack_end = stack + (nstate + 1);
  }

  for (p = postfix; p < end; p++) {
    switch (*p) {
    case NFA_CONCAT:
      // Concatenation.
      // Pay attention: this operator does not exist in the r.e. itself
      // (it is implicit, really).  It is added when r.e. is translated
      // to postfix form in re2post().
      if (nfa_calc_size == true) {
        // nstate += 0;
        break;
      }
      e2 = POP();
      e1 = POP();
      patch(e1.out, e2.start);
      PUSH(frag(e1.start, e2.out));
      break;

    case NFA_OR:
      // Alternation
      if (nfa_calc_size == true) {
        nstate++;
        break;
      }
      e2 = POP();
      e1 = POP();
      s = alloc_state(NFA_SPLIT, e1.start, e2.start);
      if (s == NULL) {
        goto theend;
      }
      PUSH(frag(s, append(e1.out, e2.out)));
      break;

    case NFA_STAR:
      // Zero or more, prefer more
      if (nfa_calc_size == true) {
        nstate++;
        break;
      }
      e = POP();
      s = alloc_state(NFA_SPLIT, e.start, NULL);
      if (s == NULL) {
        goto theend;
      }
      patch(e.out, s);
      PUSH(frag(s, list1(&s->out1)));
      break;

    case NFA_STAR_NONGREEDY:
      // Zero or more, prefer zero
      if (nfa_calc_size == true) {
        nstate++;
        break;
      }
      e = POP();
      s = alloc_state(NFA_SPLIT, NULL, e.start);
      if (s == NULL) {
        goto theend;
      }
      patch(e.out, s);
      PUSH(frag(s, list1(&s->out)));
      break;

    case NFA_QUEST:
      // one or zero atoms=> greedy match
      if (nfa_calc_size == true) {
        nstate++;
        break;
      }
      e = POP();
      s = alloc_state(NFA_SPLIT, e.start, NULL);
      if (s == NULL) {
        goto theend;
      }
      PUSH(frag(s, append(e.out, list1(&s->out1))));
      break;

    case NFA_QUEST_NONGREEDY:
      // zero or one atoms => non-greedy match
      if (nfa_calc_size == true) {
        nstate++;
        break;
      }
      e = POP();
      s = alloc_state(NFA_SPLIT, NULL, e.start);
      if (s == NULL) {
        goto theend;
      }
      PUSH(frag(s, append(e.out, list1(&s->out))));
      break;

    case NFA_END_COLL:
    case NFA_END_NEG_COLL:
      // On the stack is the sequence starting with NFA_START_COLL or
      // NFA_START_NEG_COLL and all possible characters. Patch it to
      // add the output to the start.
      if (nfa_calc_size == true) {
        nstate++;
        break;
      }
      e = POP();
      s = alloc_state(NFA_END_COLL, NULL, NULL);
      if (s == NULL) {
        goto theend;
      }
      patch(e.out, s);
      e.start->out1 = s;
      PUSH(frag(e.start, list1(&s->out)));
      break;

    case NFA_RANGE:
      // Before this are two characters, the low and high end of a
      // range.  Turn them into two states with MIN and MAX.
      if (nfa_calc_size == true) {
        // nstate += 0;
        break;
      }
      e2 = POP();
      e1 = POP();
      e2.start->val = e2.start->c;
      e2.start->c = NFA_RANGE_MAX;
      e1.start->val = e1.start->c;
      e1.start->c = NFA_RANGE_MIN;
      patch(e1.out, e2.start);
      PUSH(frag(e1.start, e2.out));
      break;

    case NFA_EMPTY:
      // 0-length, used in a repetition with max/min count of 0
      if (nfa_calc_size == true) {
        nstate++;
        break;
      }
      s = alloc_state(NFA_EMPTY, NULL, NULL);
      if (s == NULL) {
        goto theend;
      }
      PUSH(frag(s, list1(&s->out)));
      break;

    case NFA_OPT_CHARS: {
      int n;

      // \%[abc] implemented as:
      //    NFA_SPLIT
      //    +-CHAR(a)
      //    | +-NFA_SPLIT
      //    |   +-CHAR(b)
      //    |   | +-NFA_SPLIT
      //    |   |   +-CHAR(c)
      //    |   |   | +-next
      //    |   |   +- next
      //    |   +- next
      //    +- next
      n = *++p;  // get number of characters
      if (nfa_calc_size == true) {
        nstate += n;
        break;
      }
      s = NULL;       // avoid compiler warning
      e1.out = NULL;       // stores list with out1's
      s1 = NULL;       // previous NFA_SPLIT to connect to
      while (n-- > 0) {
        e = POP();         // get character
        s = alloc_state(NFA_SPLIT, e.start, NULL);
        if (s == NULL) {
          goto theend;
        }
        if (e1.out == NULL) {
          e1 = e;
        }
        patch(e.out, s1);
        append(e1.out, list1(&s->out1));
        s1 = s;
      }
      PUSH(frag(s, e1.out));
      break;
    }

    case NFA_PREV_ATOM_NO_WIDTH:
    case NFA_PREV_ATOM_NO_WIDTH_NEG:
    case NFA_PREV_ATOM_JUST_BEFORE:
    case NFA_PREV_ATOM_JUST_BEFORE_NEG:
    case NFA_PREV_ATOM_LIKE_PATTERN: {
      int before = (*p == NFA_PREV_ATOM_JUST_BEFORE
                    || *p == NFA_PREV_ATOM_JUST_BEFORE_NEG);
      int pattern = (*p == NFA_PREV_ATOM_LIKE_PATTERN);
      int start_state;
      int end_state;
      int n = 0;
      nfa_state_T *zend;
      nfa_state_T *skip;

      switch (*p) {
      case NFA_PREV_ATOM_NO_WIDTH:
        start_state = NFA_START_INVISIBLE;
        end_state = NFA_END_INVISIBLE;
        break;
      case NFA_PREV_ATOM_NO_WIDTH_NEG:
        start_state = NFA_START_INVISIBLE_NEG;
        end_state = NFA_END_INVISIBLE_NEG;
        break;
      case NFA_PREV_ATOM_JUST_BEFORE:
        start_state = NFA_START_INVISIBLE_BEFORE;
        end_state = NFA_END_INVISIBLE;
        break;
      case NFA_PREV_ATOM_JUST_BEFORE_NEG:
        start_state = NFA_START_INVISIBLE_BEFORE_NEG;
        end_state = NFA_END_INVISIBLE_NEG;
        break;
      default:           // NFA_PREV_ATOM_LIKE_PATTERN:
        start_state = NFA_START_PATTERN;
        end_state = NFA_END_PATTERN;
        break;
      }

      if (before) {
        n = *++p;         // get the count
      }
      // The \@= operator: match the preceding atom with zero width.
      // The \@! operator: no match for the preceding atom.
      // The \@<= operator: match for the preceding atom.
      // The \@<! operator: no match for the preceding atom.
      // Surrounds the preceding atom with START_INVISIBLE and
      // END_INVISIBLE, similarly to MOPEN.

      if (nfa_calc_size == true) {
        nstate += pattern ? 4 : 2;
        break;
      }
      e = POP();
      s1 = alloc_state(end_state, NULL, NULL);
      if (s1 == NULL) {
        goto theend;
      }

      s = alloc_state(start_state, e.start, s1);
      if (s == NULL) {
        goto theend;
      }
      if (pattern) {
        // NFA_ZEND -> NFA_END_PATTERN -> NFA_SKIP -> what follows.
        skip = alloc_state(NFA_SKIP, NULL, NULL);
        if (skip == NULL) {
          goto theend;
        }
        zend = alloc_state(NFA_ZEND, s1, NULL);
        if (zend == NULL) {
          goto theend;
        }
        s1->out = skip;
        patch(e.out, zend);
        PUSH(frag(s, list1(&skip->out)));
      } else {
        patch(e.out, s1);
        PUSH(frag(s, list1(&s1->out)));
        if (before) {
          if (n <= 0) {
            // See if we can guess the maximum width, it avoids a
            // lot of pointless tries.
            n = nfa_max_width(e.start, 0);
          }
          s->val = n;           // store the count
        }
      }
      break;
    }

    case NFA_COMPOSING:         // char with composing char
      FALLTHROUGH;

    case NFA_MOPEN:     // \( \) Submatch
    case NFA_MOPEN1:
    case NFA_MOPEN2:
    case NFA_MOPEN3:
    case NFA_MOPEN4:
    case NFA_MOPEN5:
    case NFA_MOPEN6:
    case NFA_MOPEN7:
    case NFA_MOPEN8:
    case NFA_MOPEN9:
    case NFA_ZOPEN:     // \z( \) Submatch
    case NFA_ZOPEN1:
    case NFA_ZOPEN2:
    case NFA_ZOPEN3:
    case NFA_ZOPEN4:
    case NFA_ZOPEN5:
    case NFA_ZOPEN6:
    case NFA_ZOPEN7:
    case NFA_ZOPEN8:
    case NFA_ZOPEN9:
    case NFA_NOPEN:     // \%( \) "Invisible Submatch"
      if (nfa_calc_size == true) {
        nstate += 2;
        break;
      }

      mopen = *p;
      switch (*p) {
      case NFA_NOPEN:
        mclose = NFA_NCLOSE; break;
      case NFA_ZOPEN:
        mclose = NFA_ZCLOSE; break;
      case NFA_ZOPEN1:
        mclose = NFA_ZCLOSE1; break;
      case NFA_ZOPEN2:
        mclose = NFA_ZCLOSE2; break;
      case NFA_ZOPEN3:
        mclose = NFA_ZCLOSE3; break;
      case NFA_ZOPEN4:
        mclose = NFA_ZCLOSE4; break;
      case NFA_ZOPEN5:
        mclose = NFA_ZCLOSE5; break;
      case NFA_ZOPEN6:
        mclose = NFA_ZCLOSE6; break;
      case NFA_ZOPEN7:
        mclose = NFA_ZCLOSE7; break;
      case NFA_ZOPEN8:
        mclose = NFA_ZCLOSE8; break;
      case NFA_ZOPEN9:
        mclose = NFA_ZCLOSE9; break;
      case NFA_COMPOSING:
        mclose = NFA_END_COMPOSING; break;
      default:
        // NFA_MOPEN, NFA_MOPEN1 .. NFA_MOPEN9
        mclose = *p + NSUBEXP;
        break;
      }

      // Allow "NFA_MOPEN" as a valid postfix representation for
      // the empty regexp "". In this case, the NFA will be
      // NFA_MOPEN -> NFA_MCLOSE. Note that this also allows
      // empty groups of parenthesis, and empty mbyte chars
      if (stackp == stack) {
        s = alloc_state(mopen, NULL, NULL);
        if (s == NULL) {
          goto theend;
        }
        s1 = alloc_state(mclose, NULL, NULL);
        if (s1 == NULL) {
          goto theend;
        }
        patch(list1(&s->out), s1);
        PUSH(frag(s, list1(&s1->out)));
        break;
      }

      // At least one node was emitted before NFA_MOPEN, so
      // at least one node will be between NFA_MOPEN and NFA_MCLOSE
      e = POP();
      s = alloc_state(mopen, e.start, NULL);         // `('
      if (s == NULL) {
        goto theend;
      }

      s1 = alloc_state(mclose, NULL, NULL);         // `)'
      if (s1 == NULL) {
        goto theend;
      }
      patch(e.out, s1);

      if (mopen == NFA_COMPOSING) {
        // COMPOSING->out1 = END_COMPOSING
        patch(list1(&s->out1), s1);
      }

      PUSH(frag(s, list1(&s1->out)));
      break;

    case NFA_BACKREF1:
    case NFA_BACKREF2:
    case NFA_BACKREF3:
    case NFA_BACKREF4:
    case NFA_BACKREF5:
    case NFA_BACKREF6:
    case NFA_BACKREF7:
    case NFA_BACKREF8:
    case NFA_BACKREF9:
    case NFA_ZREF1:
    case NFA_ZREF2:
    case NFA_ZREF3:
    case NFA_ZREF4:
    case NFA_ZREF5:
    case NFA_ZREF6:
    case NFA_ZREF7:
    case NFA_ZREF8:
    case NFA_ZREF9:
      if (nfa_calc_size == true) {
        nstate += 2;
        break;
      }
      s = alloc_state(*p, NULL, NULL);
      if (s == NULL) {
        goto theend;
      }
      s1 = alloc_state(NFA_SKIP, NULL, NULL);
      if (s1 == NULL) {
        goto theend;
      }
      patch(list1(&s->out), s1);
      PUSH(frag(s, list1(&s1->out)));
      break;

    case NFA_LNUM:
    case NFA_LNUM_GT:
    case NFA_LNUM_LT:
    case NFA_VCOL:
    case NFA_VCOL_GT:
    case NFA_VCOL_LT:
    case NFA_COL:
    case NFA_COL_GT:
    case NFA_COL_LT:
    case NFA_MARK:
    case NFA_MARK_GT:
    case NFA_MARK_LT: {
      int n = *++p;       // lnum, col or mark name

      if (nfa_calc_size == true) {
        nstate += 1;
        break;
      }
      s = alloc_state(p[-1], NULL, NULL);
      if (s == NULL) {
        goto theend;
      }
      s->val = n;
      PUSH(frag(s, list1(&s->out)));
      break;
    }

    case NFA_ZSTART:
    case NFA_ZEND:
    default:
      // Operands
      if (nfa_calc_size == true) {
        nstate++;
        break;
      }
      s = alloc_state(*p, NULL, NULL);
      if (s == NULL) {
        goto theend;
      }
      PUSH(frag(s, list1(&s->out)));
      break;
    }     // switch(*p)
  }   // for(p = postfix; *p; ++p)

  if (nfa_calc_size == true) {
    nstate++;
    goto theend;        // Return value when counting size is ignored anyway
  }

  e = POP();
  if (stackp != stack) {
    xfree(stack);
    EMSG_RET_NULL(_("E875: (NFA regexp) (While converting from postfix to NFA),"
                    "too many states left on stack"));
  }

  if (istate >= nstate) {
    xfree(stack);
    EMSG_RET_NULL(_("E876: (NFA regexp) "
                    "Not enough space to store the whole NFA "));
  }

  matchstate = &state_ptr[istate++];   // the match state
  matchstate->c = NFA_MATCH;
  matchstate->out = matchstate->out1 = NULL;
  matchstate->id = 0;

  patch(e.out, matchstate);
  ret = e.start;

theend:
  xfree(stack);
  return ret;

#undef POP1
#undef PUSH1
#undef POP2
#undef PUSH2
#undef POP
#undef PUSH
}

// After building the NFA program, inspect it to add optimization hints.
static void nfa_postprocess(nfa_regprog_T *prog)
{
  int i;
  int c;

  for (i = 0; i < prog->nstate; i++) {
    c = prog->state[i].c;
    if (c == NFA_START_INVISIBLE
        || c == NFA_START_INVISIBLE_NEG
        || c == NFA_START_INVISIBLE_BEFORE
        || c == NFA_START_INVISIBLE_BEFORE_NEG) {
      int directly;

      // Do it directly when what follows is possibly the end of the
      // match.
      if (match_follows(prog->state[i].out1->out, 0)) {
        directly = true;
      } else {
        int ch_invisible = failure_chance(prog->state[i].out, 0);
        int ch_follows = failure_chance(prog->state[i].out1->out, 0);

        // Postpone when the invisible match is expensive or has a
        // lower chance of failing.
        if (c == NFA_START_INVISIBLE_BEFORE
            || c == NFA_START_INVISIBLE_BEFORE_NEG) {
          // "before" matches are very expensive when
          // unbounded, always prefer what follows then,
          // unless what follows will always match.
          // Otherwise strongly prefer what follows.
          if (prog->state[i].val <= 0 && ch_follows > 0) {
            directly = false;
          } else {
            directly = ch_follows * 10 < ch_invisible;
          }
        } else {
          // normal invisible, first do the one with the
          // highest failure chance
          directly = ch_follows < ch_invisible;
        }
      }
      if (directly) {
        // switch to the _FIRST state
        prog->state[i].c++;
      }
    }
  }
}

/////////////////////////////////////////////////////////////////
// NFA execution code.
/////////////////////////////////////////////////////////////////

// Values for done in nfa_pim_T.
#define NFA_PIM_UNUSED   0      // pim not used
#define NFA_PIM_TODO     1      // pim not done yet
#define NFA_PIM_MATCH    2      // pim executed, matches
#define NFA_PIM_NOMATCH  3      // pim executed, no match

#ifdef REGEXP_DEBUG
static void log_subsexpr(regsubs_T *subs)
{
  log_subexpr(&subs->norm);
  if (rex.nfa_has_zsubexpr) {
    log_subexpr(&subs->synt);
  }
}

static void log_subexpr(regsub_T *sub)
{
  int j;

  for (j = 0; j < sub->in_use; j++) {
    if (REG_MULTI) {
      fprintf(log_fd, "*** group %d, start: c=%d, l=%d, end: c=%d, l=%d\n",
              j,
              sub->list.multi[j].start_col,
              (int)sub->list.multi[j].start_lnum,
              sub->list.multi[j].end_col,
              (int)sub->list.multi[j].end_lnum);
    } else {
      char *s = (char *)sub->list.line[j].start;
      char *e = (char *)sub->list.line[j].end;

      fprintf(log_fd, "*** group %d, start: \"%s\", end: \"%s\"\n",
              j,
              s == NULL ? "NULL" : s,
              e == NULL ? "NULL" : e);
    }
  }
}

static char *pim_info(const nfa_pim_T *pim)
{
  static char buf[30];

  if (pim == NULL || pim->result == NFA_PIM_UNUSED) {
    buf[0] = NUL;
  } else {
    snprintf(buf, sizeof(buf), " PIM col %d",
             REG_MULTI
             ? (int)pim->end.pos.col
             : (int)(pim->end.ptr - rex.input));
  }
  return buf;
}

#endif

// Used during execution: whether a match has been found.
static int nfa_match;
static proftime_T *nfa_time_limit;
static int *nfa_timed_out;
static int nfa_time_count;

// Copy postponed invisible match info from "from" to "to".
static void copy_pim(nfa_pim_T *to, nfa_pim_T *from)
{
  to->result = from->result;
  to->state = from->state;
  copy_sub(&to->subs.norm, &from->subs.norm);
  if (rex.nfa_has_zsubexpr) {
    copy_sub(&to->subs.synt, &from->subs.synt);
  }
  to->end = from->end;
}

static void clear_sub(regsub_T *sub)
{
  if (REG_MULTI) {
    // Use 0xff to set lnum to -1
    memset(sub->list.multi, 0xff, sizeof(struct multipos) * (size_t)rex.nfa_nsubexpr);
  } else {
    memset(sub->list.line, 0, sizeof(struct linepos) * (size_t)rex.nfa_nsubexpr);
  }
  sub->in_use = 0;
}

// Copy the submatches from "from" to "to".
static void copy_sub(regsub_T *to, regsub_T *from)
{
  to->in_use = from->in_use;
  if (from->in_use <= 0) {
    return;
  }

  // Copy the match start and end positions.
  if (REG_MULTI) {
    memmove(&to->list.multi[0], &from->list.multi[0],
            sizeof(struct multipos) * (size_t)from->in_use);
    to->orig_start_col = from->orig_start_col;
  } else {
    memmove(&to->list.line[0], &from->list.line[0],
            sizeof(struct linepos) * (size_t)from->in_use);
  }
}

// Like copy_sub() but exclude the main match.
static void copy_sub_off(regsub_T *to, regsub_T *from)
{
  if (to->in_use < from->in_use) {
    to->in_use = from->in_use;
  }
  if (from->in_use <= 1) {
    return;
  }

  // Copy the match start and end positions.
  if (REG_MULTI) {
    memmove(&to->list.multi[1], &from->list.multi[1],
            sizeof(struct multipos) * (size_t)(from->in_use - 1));
  } else {
    memmove(&to->list.line[1], &from->list.line[1],
            sizeof(struct linepos) * (size_t)(from->in_use - 1));
  }
}

// Like copy_sub() but only do the end of the main match if \ze is present.
static void copy_ze_off(regsub_T *to, regsub_T *from)
{
  if (!rex.nfa_has_zend) {
    return;
  }

  if (REG_MULTI) {
    if (from->list.multi[0].end_lnum >= 0) {
      to->list.multi[0].end_lnum = from->list.multi[0].end_lnum;
      to->list.multi[0].end_col = from->list.multi[0].end_col;
    }
  } else {
    if (from->list.line[0].end != NULL) {
      to->list.line[0].end = from->list.line[0].end;
    }
  }
}

// Return true if "sub1" and "sub2" have the same start positions.
// When using back-references also check the end position.
static bool sub_equal(regsub_T *sub1, regsub_T *sub2)
{
  int i;
  int todo;
  linenr_T s1;
  linenr_T s2;
  uint8_t *sp1;
  uint8_t *sp2;

  todo = sub1->in_use > sub2->in_use ? sub1->in_use : sub2->in_use;
  if (REG_MULTI) {
    for (i = 0; i < todo; i++) {
      if (i < sub1->in_use) {
        s1 = sub1->list.multi[i].start_lnum;
      } else {
        s1 = -1;
      }
      if (i < sub2->in_use) {
        s2 = sub2->list.multi[i].start_lnum;
      } else {
        s2 = -1;
      }
      if (s1 != s2) {
        return false;
      }
      if (s1 != -1 && sub1->list.multi[i].start_col
          != sub2->list.multi[i].start_col) {
        return false;
      }
      if (rex.nfa_has_backref) {
        if (i < sub1->in_use) {
          s1 = sub1->list.multi[i].end_lnum;
        } else {
          s1 = -1;
        }
        if (i < sub2->in_use) {
          s2 = sub2->list.multi[i].end_lnum;
        } else {
          s2 = -1;
        }
        if (s1 != s2) {
          return false;
        }
        if (s1 != -1
            && sub1->list.multi[i].end_col != sub2->list.multi[i].end_col) {
          return false;
        }
      }
    }
  } else {
    for (i = 0; i < todo; i++) {
      if (i < sub1->in_use) {
        sp1 = sub1->list.line[i].start;
      } else {
        sp1 = NULL;
      }
      if (i < sub2->in_use) {
        sp2 = sub2->list.line[i].start;
      } else {
        sp2 = NULL;
      }
      if (sp1 != sp2) {
        return false;
      }
      if (rex.nfa_has_backref) {
        if (i < sub1->in_use) {
          sp1 = sub1->list.line[i].end;
        } else {
          sp1 = NULL;
        }
        if (i < sub2->in_use) {
          sp2 = sub2->list.line[i].end;
        } else {
          sp2 = NULL;
        }
        if (sp1 != sp2) {
          return false;
        }
      }
    }
  }

  return true;
}

#ifdef REGEXP_DEBUG
static void open_debug_log(TriState result)
{
  log_fd = fopen(NFA_REGEXP_RUN_LOG, "a");
  if (log_fd == NULL) {
    emsg(_(e_log_open_failed));
    log_fd = stderr;
  }

  fprintf(log_fd, "****************************\n");
  fprintf(log_fd, "FINISHED RUNNING nfa_regmatch() recursively\n");
  fprintf(log_fd, "MATCH = %s\n", result == kTrue ? "OK" : result == kNone ? "MAYBE" : "FALSE");
  fprintf(log_fd, "****************************\n");
}

static void report_state(char *action, regsub_T *sub, nfa_state_T *state, int lid, nfa_pim_T *pim)
{
  int col;

  if (sub->in_use <= 0) {
    col = -1;
  } else if (REG_MULTI) {
    col = sub->list.multi[0].start_col;
  } else {
    col = (int)(sub->list.line[0].start - rex.line);
  }
  nfa_set_code(state->c);
  if (log_fd == NULL) {
    open_debug_log(kNone);
  }
  fprintf(log_fd, "> %s state %d to list %d. char %d: %s (start col %d)%s\n",
          action, abs(state->id), lid, state->c, code, col,
          pim_info(pim));
}

#endif

/// @param l      runtime state list
/// @param state  state to update
/// @param subs   pointers to subexpressions
/// @param pim    postponed match or NULL
///
/// @return  true if the same state is already in list "l" with the same
///          positions as "subs".
static bool has_state_with_pos(nfa_list_T *l, nfa_state_T *state, regsubs_T *subs, nfa_pim_T *pim)
  FUNC_ATTR_NONNULL_ARG(1, 2, 3)
{
  for (int i = 0; i < l->n; i++) {
    nfa_thread_T *thread = &l->t[i];
    if (thread->state->id == state->id
        && sub_equal(&thread->subs.norm, &subs->norm)
        && (!rex.nfa_has_zsubexpr
            || sub_equal(&thread->subs.synt, &subs->synt))
        && pim_equal(&thread->pim, pim)) {
      return true;
    }
  }
  return false;
}

// Return true if "one" and "two" are equal.  That includes when both are not
// set.
static bool pim_equal(const nfa_pim_T *one, const nfa_pim_T *two)
{
  const bool one_unused = (one == NULL || one->result == NFA_PIM_UNUSED);
  const bool two_unused = (two == NULL || two->result == NFA_PIM_UNUSED);

  if (one_unused) {
    // one is unused: equal when two is also unused
    return two_unused;
  }
  if (two_unused) {
    // one is used and two is not: not equal
    return false;
  }
  // compare the state id
  if (one->state->id != two->state->id) {
    return false;
  }
  // compare the position
  if (REG_MULTI) {
    return one->end.pos.lnum == two->end.pos.lnum
           && one->end.pos.col == two->end.pos.col;
  }
  return one->end.ptr == two->end.ptr;
}

// Return true if "state" leads to a NFA_MATCH without advancing the input.
static bool match_follows(const nfa_state_T *startstate, int depth)
  FUNC_ATTR_NONNULL_ALL
{
  const nfa_state_T *state = startstate;

  // avoid too much recursion
  if (depth > 10) {
    return false;
  }
  while (state != NULL) {
    switch (state->c) {
    case NFA_MATCH:
    case NFA_MCLOSE:
    case NFA_END_INVISIBLE:
    case NFA_END_INVISIBLE_NEG:
    case NFA_END_PATTERN:
      return true;

    case NFA_SPLIT:
      return match_follows(state->out, depth + 1)
             || match_follows(state->out1, depth + 1);

    case NFA_START_INVISIBLE:
    case NFA_START_INVISIBLE_FIRST:
    case NFA_START_INVISIBLE_BEFORE:
    case NFA_START_INVISIBLE_BEFORE_FIRST:
    case NFA_START_INVISIBLE_NEG:
    case NFA_START_INVISIBLE_NEG_FIRST:
    case NFA_START_INVISIBLE_BEFORE_NEG:
    case NFA_START_INVISIBLE_BEFORE_NEG_FIRST:
    case NFA_COMPOSING:
      // skip ahead to next state
      state = state->out1->out;
      continue;

    case NFA_ANY:
    case NFA_ANY_COMPOSING:
    case NFA_IDENT:
    case NFA_SIDENT:
    case NFA_KWORD:
    case NFA_SKWORD:
    case NFA_FNAME:
    case NFA_SFNAME:
    case NFA_PRINT:
    case NFA_SPRINT:
    case NFA_WHITE:
    case NFA_NWHITE:
    case NFA_DIGIT:
    case NFA_NDIGIT:
    case NFA_HEX:
    case NFA_NHEX:
    case NFA_OCTAL:
    case NFA_NOCTAL:
    case NFA_WORD:
    case NFA_NWORD:
    case NFA_HEAD:
    case NFA_NHEAD:
    case NFA_ALPHA:
    case NFA_NALPHA:
    case NFA_LOWER:
    case NFA_NLOWER:
    case NFA_UPPER:
    case NFA_NUPPER:
    case NFA_LOWER_IC:
    case NFA_NLOWER_IC:
    case NFA_UPPER_IC:
    case NFA_NUPPER_IC:
    case NFA_START_COLL:
    case NFA_START_NEG_COLL:
    case NFA_NEWL:
      // state will advance input
      return false;

    default:
      if (state->c > 0) {
        // state will advance input
        return false;
      }
      // Others: zero-width or possibly zero-width, might still find
      // a match at the same position, keep looking.
      break;
    }
    state = state->out;
  }
  return false;
}

/// @param l      runtime state list
/// @param state  state to update
/// @param subs   pointers to subexpressions
///
/// @return  true if "state" is already in list "l".
static bool state_in_list(nfa_list_T *l, nfa_state_T *state, regsubs_T *subs)
  FUNC_ATTR_NONNULL_ALL
{
  if (state->lastlist[nfa_ll_index] == l->id) {
    if (!rex.nfa_has_backref || has_state_with_pos(l, state, subs, NULL)) {
      return true;
    }
  }
  return false;
}

// Offset used for "off" by addstate_here().
#define ADDSTATE_HERE_OFFSET 10

/// Add "state" and possibly what follows to state list ".".
///
/// @param l         runtime state list
/// @param state     state to update
/// @param subs_arg  pointers to subexpressions
/// @param pim       postponed look-behind match
/// @param off_arg   byte offset, when -1 go to next line
///
/// @return  "subs_arg", possibly copied into temp_subs.
///          NULL when recursiveness is too deep.
static regsubs_T *addstate(nfa_list_T *l, nfa_state_T *state, regsubs_T *subs_arg, nfa_pim_T *pim,
                           int off_arg)
  FUNC_ATTR_NONNULL_ARG(1, 2) FUNC_ATTR_WARN_UNUSED_RESULT
{
  int subidx;
  int off = off_arg;
  int add_here = false;
  int listindex = 0;
  int k;
  int found = false;
  nfa_thread_T *thread;
  struct multipos save_multipos;
  int save_in_use;
  uint8_t *save_ptr;
  int i;
  regsub_T *sub;
  regsubs_T *subs = subs_arg;
  static regsubs_T temp_subs;
#ifdef REGEXP_DEBUG
  int did_print = false;
#endif
  static int depth = 0;

  // This function is called recursively.  When the depth is too much we run
  // out of stack and crash, limit recursiveness here.
  if (++depth >= 5000 || subs == NULL) {
    depth--;
    return NULL;
  }

  if (off_arg <= -ADDSTATE_HERE_OFFSET) {
    add_here = true;
    off = 0;
    listindex = -(off_arg + ADDSTATE_HERE_OFFSET);
  }

  switch (state->c) {
  case NFA_NCLOSE:
  case NFA_MCLOSE:
  case NFA_MCLOSE1:
  case NFA_MCLOSE2:
  case NFA_MCLOSE3:
  case NFA_MCLOSE4:
  case NFA_MCLOSE5:
  case NFA_MCLOSE6:
  case NFA_MCLOSE7:
  case NFA_MCLOSE8:
  case NFA_MCLOSE9:
  case NFA_ZCLOSE:
  case NFA_ZCLOSE1:
  case NFA_ZCLOSE2:
  case NFA_ZCLOSE3:
  case NFA_ZCLOSE4:
  case NFA_ZCLOSE5:
  case NFA_ZCLOSE6:
  case NFA_ZCLOSE7:
  case NFA_ZCLOSE8:
  case NFA_ZCLOSE9:
  case NFA_MOPEN:
  case NFA_ZEND:
  case NFA_SPLIT:
  case NFA_EMPTY:
    // These nodes are not added themselves but their "out" and/or
    // "out1" may be added below.
    break;

  case NFA_BOL:
  case NFA_BOF:
    // "^" won't match past end-of-line, don't bother trying.
    // Except when at the end of the line, or when we are going to the
    // next line for a look-behind match.
    if (rex.input > rex.line
        && *rex.input != NUL
        && (nfa_endp == NULL
            || !REG_MULTI
            || rex.lnum == nfa_endp->se_u.pos.lnum)) {
      goto skip_add;
    }
    FALLTHROUGH;

  case NFA_MOPEN1:
  case NFA_MOPEN2:
  case NFA_MOPEN3:
  case NFA_MOPEN4:
  case NFA_MOPEN5:
  case NFA_MOPEN6:
  case NFA_MOPEN7:
  case NFA_MOPEN8:
  case NFA_MOPEN9:
  case NFA_ZOPEN:
  case NFA_ZOPEN1:
  case NFA_ZOPEN2:
  case NFA_ZOPEN3:
  case NFA_ZOPEN4:
  case NFA_ZOPEN5:
  case NFA_ZOPEN6:
  case NFA_ZOPEN7:
  case NFA_ZOPEN8:
  case NFA_ZOPEN9:
  case NFA_NOPEN:
  case NFA_ZSTART:
  // These nodes need to be added so that we can bail out when it
  // was added to this list before at the same position to avoid an
  // endless loop for "\(\)*"

  default:
    if (state->lastlist[nfa_ll_index] == l->id && state->c != NFA_SKIP) {
      // This state is already in the list, don't add it again,
      // unless it is an MOPEN that is used for a backreference or
      // when there is a PIM. For NFA_MATCH check the position,
      // lower position is preferred.
      if (!rex.nfa_has_backref && pim == NULL && !l->has_pim
          && state->c != NFA_MATCH) {
        // When called from addstate_here() do insert before
        // existing states.
        if (add_here) {
          for (k = 0; k < l->n && k < listindex; k++) {
            if (l->t[k].state->id == state->id) {
              found = true;
              break;
            }
          }
        }

        if (!add_here || found) {
skip_add:
#ifdef REGEXP_DEBUG
          nfa_set_code(state->c);
          fprintf(log_fd,
                  "> Not adding state %d to list %d. char %d: %s pim: %s has_pim: %d found: %d\n",
                  abs(state->id), l->id, state->c, code,
                  pim == NULL ? "NULL" : "yes", l->has_pim, found);
#endif
          depth--;
          return subs;
        }
      }

      // Do not add the state again when it exists with the same
      // positions.
      if (has_state_with_pos(l, state, subs, pim)) {
        goto skip_add;
      }
    }

    // When there are backreferences or PIMs the number of states may
    // be (a lot) bigger than anticipated.
    if (l->n == l->len) {
      const int newlen = l->len * 3 / 2 + 50;
      const size_t newsize = (size_t)newlen * sizeof(nfa_thread_T);

      if ((int64_t)(newsize >> 10) >= p_mmp) {
        emsg(_(e_pattern_uses_more_memory_than_maxmempattern));
        depth--;
        return NULL;
      }
      if (subs != &temp_subs) {
        // "subs" may point into the current array, need to make a
        // copy before it becomes invalid.
        copy_sub(&temp_subs.norm, &subs->norm);
        if (rex.nfa_has_zsubexpr) {
          copy_sub(&temp_subs.synt, &subs->synt);
        }
        subs = &temp_subs;
      }

      nfa_thread_T *const newt = xrealloc(l->t, newsize);
      l->t = newt;
      l->len = newlen;
    }

    // add the state to the list
    state->lastlist[nfa_ll_index] = l->id;
    thread = &l->t[l->n++];
    thread->state = state;
    if (pim == NULL) {
      thread->pim.result = NFA_PIM_UNUSED;
    } else {
      copy_pim(&thread->pim, pim);
      l->has_pim = true;
    }
    copy_sub(&thread->subs.norm, &subs->norm);
    if (rex.nfa_has_zsubexpr) {
      copy_sub(&thread->subs.synt, &subs->synt);
    }
#ifdef REGEXP_DEBUG
    report_state("Adding", &thread->subs.norm, state, l->id, pim);
    did_print = true;
#endif
  }

#ifdef REGEXP_DEBUG
  if (!did_print) {
    report_state("Processing", &subs->norm, state, l->id, pim);
  }
#endif
  switch (state->c) {
  case NFA_MATCH:
    break;

  case NFA_SPLIT:
    // order matters here
    subs = addstate(l, state->out, subs, pim, off_arg);
    subs = addstate(l, state->out1, subs, pim, off_arg);
    break;

  case NFA_EMPTY:
  case NFA_NOPEN:
  case NFA_NCLOSE:
    subs = addstate(l, state->out, subs, pim, off_arg);
    break;

  case NFA_MOPEN:
  case NFA_MOPEN1:
  case NFA_MOPEN2:
  case NFA_MOPEN3:
  case NFA_MOPEN4:
  case NFA_MOPEN5:
  case NFA_MOPEN6:
  case NFA_MOPEN7:
  case NFA_MOPEN8:
  case NFA_MOPEN9:
  case NFA_ZOPEN:
  case NFA_ZOPEN1:
  case NFA_ZOPEN2:
  case NFA_ZOPEN3:
  case NFA_ZOPEN4:
  case NFA_ZOPEN5:
  case NFA_ZOPEN6:
  case NFA_ZOPEN7:
  case NFA_ZOPEN8:
  case NFA_ZOPEN9:
  case NFA_ZSTART:
    if (state->c == NFA_ZSTART) {
      subidx = 0;
      sub = &subs->norm;
    } else if (state->c >= NFA_ZOPEN && state->c <= NFA_ZOPEN9) {
      subidx = state->c - NFA_ZOPEN;
      sub = &subs->synt;
    } else {
      subidx = state->c - NFA_MOPEN;
      sub = &subs->norm;
    }

    // avoid compiler warnings
    save_ptr = NULL;
    CLEAR_FIELD(save_multipos);

    // Set the position (with "off" added) in the subexpression.  Save
    // and restore it when it was in use.  Otherwise fill any gap.
    if (REG_MULTI) {
      if (subidx < sub->in_use) {
        save_multipos = sub->list.multi[subidx];
        save_in_use = -1;
      } else {
        save_in_use = sub->in_use;
        for (i = sub->in_use; i < subidx; i++) {
          sub->list.multi[i].start_lnum = -1;
          sub->list.multi[i].end_lnum = -1;
        }
        sub->in_use = subidx + 1;
      }
      if (off == -1) {
        sub->list.multi[subidx].start_lnum = rex.lnum + 1;
        sub->list.multi[subidx].start_col = 0;
      } else {
        sub->list.multi[subidx].start_lnum = rex.lnum;
        sub->list.multi[subidx].start_col =
          (colnr_T)(rex.input - rex.line + off);
      }
      sub->list.multi[subidx].end_lnum = -1;
    } else {
      if (subidx < sub->in_use) {
        save_ptr = sub->list.line[subidx].start;
        save_in_use = -1;
      } else {
        save_in_use = sub->in_use;
        for (i = sub->in_use; i < subidx; i++) {
          sub->list.line[i].start = NULL;
          sub->list.line[i].end = NULL;
        }
        sub->in_use = subidx + 1;
      }
      sub->list.line[subidx].start = rex.input + off;
    }

    subs = addstate(l, state->out, subs, pim, off_arg);
    if (subs == NULL) {
      break;
    }
    // "subs" may have changed, need to set "sub" again.
    if (state->c >= NFA_ZOPEN && state->c <= NFA_ZOPEN9) {
      sub = &subs->synt;
    } else {
      sub = &subs->norm;
    }

    if (save_in_use == -1) {
      if (REG_MULTI) {
        sub->list.multi[subidx] = save_multipos;
      } else {
        sub->list.line[subidx].start = save_ptr;
      }
    } else {
      sub->in_use = save_in_use;
    }
    break;

  case NFA_MCLOSE:
    if (rex.nfa_has_zend
        && (REG_MULTI
            ? subs->norm.list.multi[0].end_lnum >= 0
            : subs->norm.list.line[0].end != NULL)) {
      // Do not overwrite the position set by \ze.
      subs = addstate(l, state->out, subs, pim, off_arg);
      break;
    }
    FALLTHROUGH;
  case NFA_MCLOSE1:
  case NFA_MCLOSE2:
  case NFA_MCLOSE3:
  case NFA_MCLOSE4:
  case NFA_MCLOSE5:
  case NFA_MCLOSE6:
  case NFA_MCLOSE7:
  case NFA_MCLOSE8:
  case NFA_MCLOSE9:
  case NFA_ZCLOSE:
  case NFA_ZCLOSE1:
  case NFA_ZCLOSE2:
  case NFA_ZCLOSE3:
  case NFA_ZCLOSE4:
  case NFA_ZCLOSE5:
  case NFA_ZCLOSE6:
  case NFA_ZCLOSE7:
  case NFA_ZCLOSE8:
  case NFA_ZCLOSE9:
  case NFA_ZEND:
    if (state->c == NFA_ZEND) {
      subidx = 0;
      sub = &subs->norm;
    } else if (state->c >= NFA_ZCLOSE && state->c <= NFA_ZCLOSE9) {
      subidx = state->c - NFA_ZCLOSE;
      sub = &subs->synt;
    } else {
      subidx = state->c - NFA_MCLOSE;
      sub = &subs->norm;
    }

    // We don't fill in gaps here, there must have been an MOPEN that
    // has done that.
    save_in_use = sub->in_use;
    if (sub->in_use <= subidx) {
      sub->in_use = subidx + 1;
    }
    if (REG_MULTI) {
      save_multipos = sub->list.multi[subidx];
      if (off == -1) {
        sub->list.multi[subidx].end_lnum = rex.lnum + 1;
        sub->list.multi[subidx].end_col = 0;
      } else {
        sub->list.multi[subidx].end_lnum = rex.lnum;
        sub->list.multi[subidx].end_col =
          (colnr_T)(rex.input - rex.line + off);
      }
      // avoid compiler warnings
      save_ptr = NULL;
    } else {
      save_ptr = sub->list.line[subidx].end;
      sub->list.line[subidx].end = rex.input + off;
      // avoid compiler warnings
      CLEAR_FIELD(save_multipos);
    }

    subs = addstate(l, state->out, subs, pim, off_arg);
    if (subs == NULL) {
      break;
    }
    // "subs" may have changed, need to set "sub" again.
    if (state->c >= NFA_ZCLOSE && state->c <= NFA_ZCLOSE9) {
      sub = &subs->synt;
    } else {
      sub = &subs->norm;
    }

    if (REG_MULTI) {
      sub->list.multi[subidx] = save_multipos;
    } else {
      sub->list.line[subidx].end = save_ptr;
    }
    sub->in_use = save_in_use;
    break;
  }
  depth--;
  return subs;
}

/// Like addstate(), but the new state(s) are put at position "*ip".
/// Used for zero-width matches, next state to use is the added one.
/// This makes sure the order of states to be tried does not change, which
/// matters for alternatives.
///
/// @param l      runtime state list
/// @param state  state to update
/// @param subs   pointers to subexpressions
/// @param pim    postponed look-behind match
static regsubs_T *addstate_here(nfa_list_T *l, nfa_state_T *state, regsubs_T *subs, nfa_pim_T *pim,
                                int *ip)
  FUNC_ATTR_NONNULL_ARG(1, 2, 5) FUNC_ATTR_WARN_UNUSED_RESULT
{
  int tlen = l->n;
  int count;
  int listidx = *ip;

  // First add the state(s) at the end, so that we know how many there are.
  // Pass the listidx as offset (avoids adding another argument to
  // addstate()).
  regsubs_T *r = addstate(l, state, subs, pim, -listidx - ADDSTATE_HERE_OFFSET);
  if (r == NULL) {
    return NULL;
  }

  // when "*ip" was at the end of the list, nothing to do
  if (listidx + 1 == tlen) {
    return r;
  }

  // re-order to put the new state at the current position
  count = l->n - tlen;
  if (count == 0) {
    return r;  // no state got added
  }
  if (count == 1) {
    // overwrite the current state
    l->t[listidx] = l->t[l->n - 1];
  } else if (count > 1) {
    if (l->n + count - 1 >= l->len) {
      // not enough space to move the new states, reallocate the list
      // and move the states to the right position
      const int newlen = l->len * 3 / 2 + 50;
      const size_t newsize = (size_t)newlen * sizeof(nfa_thread_T);

      if ((int64_t)(newsize >> 10) >= p_mmp) {
        emsg(_(e_pattern_uses_more_memory_than_maxmempattern));
        return NULL;
      }
      nfa_thread_T *const newl = xmalloc(newsize);
      l->len = newlen;
      memmove(&(newl[0]),
              &(l->t[0]),
              sizeof(nfa_thread_T) * (size_t)listidx);
      memmove(&(newl[listidx]),
              &(l->t[l->n - count]),
              sizeof(nfa_thread_T) * (size_t)count);
      memmove(&(newl[listidx + count]),
              &(l->t[listidx + 1]),
              sizeof(nfa_thread_T) * (size_t)(l->n - count - listidx - 1));
      xfree(l->t);
      l->t = newl;
    } else {
      // make space for new states, then move them from the
      // end to the current position
      memmove(&(l->t[listidx + count]),
              &(l->t[listidx + 1]),
              sizeof(nfa_thread_T) * (size_t)(l->n - listidx - 1));
      memmove(&(l->t[listidx]),
              &(l->t[l->n - 1]),
              sizeof(nfa_thread_T) * (size_t)count);
    }
  }
  l->n--;
  *ip = listidx - 1;

  return r;
}

// Check character class "class" against current character c.
static int check_char_class(int cls, int c)
{
  switch (cls) {
  case NFA_CLASS_ALNUM:
    if (c >= 1 && c < 128 && isalnum(c)) {
      return OK;
    }
    break;
  case NFA_CLASS_ALPHA:
    if (c >= 1 && c < 128 && isalpha(c)) {
      return OK;
    }
    break;
  case NFA_CLASS_BLANK:
    if (c == ' ' || c == '\t') {
      return OK;
    }
    break;
  case NFA_CLASS_CNTRL:
    if (c >= 1 && c <= 127 && iscntrl(c)) {
      return OK;
    }
    break;
  case NFA_CLASS_DIGIT:
    if (ascii_isdigit(c)) {
      return OK;
    }
    break;
  case NFA_CLASS_GRAPH:
    if (c >= 1 && c <= 127 && isgraph(c)) {
      return OK;
    }
    break;
  case NFA_CLASS_LOWER:
    if (mb_islower(c) && c != 170 && c != 186) {
      return OK;
    }
    break;
  case NFA_CLASS_PRINT:
    if (vim_isprintc(c)) {
      return OK;
    }
    break;
  case NFA_CLASS_PUNCT:
    if (c >= 1 && c < 128 && ispunct(c)) {
      return OK;
    }
    break;
  case NFA_CLASS_SPACE:
    if ((c >= 9 && c <= 13) || (c == ' ')) {
      return OK;
    }
    break;
  case NFA_CLASS_UPPER:
    if (mb_isupper(c)) {
      return OK;
    }
    break;
  case NFA_CLASS_XDIGIT:
    if (ascii_isxdigit(c)) {
      return OK;
    }
    break;
  case NFA_CLASS_TAB:
    if (c == '\t') {
      return OK;
    }
    break;
  case NFA_CLASS_RETURN:
    if (c == '\r') {
      return OK;
    }
    break;
  case NFA_CLASS_BACKSPACE:
    if (c == '\b') {
      return OK;
    }
    break;
  case NFA_CLASS_ESCAPE:
    if (c == ESC) {
      return OK;
    }
    break;
  case NFA_CLASS_IDENT:
    if (vim_isIDc(c)) {
      return OK;
    }
    break;
  case NFA_CLASS_KEYWORD:
    if (reg_iswordc(c)) {
      return OK;
    }
    break;
  case NFA_CLASS_FNAME:
    if (vim_isfilec(c)) {
      return OK;
    }
    break;

  default:
    // should not be here :P
    siemsg(_(e_ill_char_class), (int64_t)cls);
    return FAIL;
  }
  return FAIL;
}

/// Check for a match with subexpression "subidx".
///
/// @param sub      pointers to subexpressions
/// @param bytelen  out: length of match in bytes
///
/// @return  true if it matches.
static int match_backref(regsub_T *sub, int subidx, int *bytelen)
{
  int len;

  if (sub->in_use <= subidx) {
retempty:
    // backref was not set, match an empty string
    *bytelen = 0;
    return true;
  }

  if (REG_MULTI) {
    if (sub->list.multi[subidx].start_lnum < 0
        || sub->list.multi[subidx].end_lnum < 0) {
      goto retempty;
    }
    if (sub->list.multi[subidx].start_lnum == rex.lnum
        && sub->list.multi[subidx].end_lnum == rex.lnum) {
      len = sub->list.multi[subidx].end_col
            - sub->list.multi[subidx].start_col;
      if (cstrncmp((char *)rex.line + sub->list.multi[subidx].start_col,
                   (char *)rex.input, &len) == 0) {
        *bytelen = len;
        return true;
      }
    } else {
      if (match_with_backref(sub->list.multi[subidx].start_lnum,
                             sub->list.multi[subidx].start_col,
                             sub->list.multi[subidx].end_lnum,
                             sub->list.multi[subidx].end_col,
                             bytelen) == RA_MATCH) {
        return true;
      }
    }
  } else {
    if (sub->list.line[subidx].start == NULL
        || sub->list.line[subidx].end == NULL) {
      goto retempty;
    }
    len = (int)(sub->list.line[subidx].end - sub->list.line[subidx].start);
    if (cstrncmp((char *)sub->list.line[subidx].start, (char *)rex.input, &len) == 0) {
      *bytelen = len;
      return true;
    }
  }
  return false;
}

/// Check for a match with \z subexpression "subidx".
///
/// @param bytelen  out: length of match in bytes
///
/// @return  true if it matches.
static int match_zref(int subidx, int *bytelen)
{
  int len;

  cleanup_zsubexpr();
  if (re_extmatch_in == NULL || re_extmatch_in->matches[subidx] == NULL) {
    // backref was not set, match an empty string
    *bytelen = 0;
    return true;
  }

  len = (int)strlen((char *)re_extmatch_in->matches[subidx]);
  if (cstrncmp((char *)re_extmatch_in->matches[subidx], (char *)rex.input, &len) == 0) {
    *bytelen = len;
    return true;
  }
  return false;
}

// Save list IDs for all NFA states of "prog" into "list".
// Also reset the IDs to zero.
// Only used for the recursive value lastlist[1].
static void nfa_save_listids(nfa_regprog_T *prog, int *list)
{
  int i;
  nfa_state_T *p;

  // Order in the list is reverse, it's a bit faster that way.
  p = &prog->state[0];
  for (i = prog->nstate; --i >= 0;) {
    list[i] = p->lastlist[1];
    p->lastlist[1] = 0;
    p++;
  }
}

// Restore list IDs from "list" to all NFA states.
static void nfa_restore_listids(nfa_regprog_T *prog, const int *list)
{
  int i;
  nfa_state_T *p;

  p = &prog->state[0];
  for (i = prog->nstate; --i >= 0;) {
    p->lastlist[1] = list[i];
    p++;
  }
}

static bool nfa_re_num_cmp(uintmax_t val, int op, uintmax_t pos)
{
  if (op == 1) {
    return pos > val;
  }
  if (op == 2) {
    return pos < val;
  }
  return val == pos;
}

// Recursively call nfa_regmatch()
// "pim" is NULL or contains info about a Postponed Invisible Match (start
// position).
static int recursive_regmatch(nfa_state_T *state, nfa_pim_T *pim, nfa_regprog_T *prog,
                              regsubs_T *submatch, regsubs_T *m, int **listids, int *listids_len)
  FUNC_ATTR_NONNULL_ARG(1, 3, 5, 6, 7)
{
  const int save_reginput_col = (int)(rex.input - rex.line);
  const int save_reglnum = rex.lnum;
  const int save_nfa_match = nfa_match;
  const int save_nfa_listid = rex.nfa_listid;
  save_se_T *const save_nfa_endp = nfa_endp;
  save_se_T endpos;
  save_se_T *endposp = NULL;
  int need_restore = false;

  if (pim != NULL) {
    // start at the position where the postponed match was
    if (REG_MULTI) {
      rex.input = rex.line + pim->end.pos.col;
    } else {
      rex.input = pim->end.ptr;
    }
  }

  if (state->c == NFA_START_INVISIBLE_BEFORE
      || state->c == NFA_START_INVISIBLE_BEFORE_FIRST
      || state->c == NFA_START_INVISIBLE_BEFORE_NEG
      || state->c == NFA_START_INVISIBLE_BEFORE_NEG_FIRST) {
    // The recursive match must end at the current position. When "pim" is
    // not NULL it specifies the current position.
    endposp = &endpos;
    if (REG_MULTI) {
      if (pim == NULL) {
        endpos.se_u.pos.col = (int)(rex.input - rex.line);
        endpos.se_u.pos.lnum = rex.lnum;
      } else {
        endpos.se_u.pos = pim->end.pos;
      }
    } else {
      if (pim == NULL) {
        endpos.se_u.ptr = rex.input;
      } else {
        endpos.se_u.ptr = pim->end.ptr;
      }
    }

    // Go back the specified number of bytes, or as far as the
    // start of the previous line, to try matching "\@<=" or
    // not matching "\@<!". This is very inefficient, limit the number of
    // bytes if possible.
    if (state->val <= 0) {
      if (REG_MULTI) {
        rex.line = (uint8_t *)reg_getline(--rex.lnum);
        if (rex.line == NULL) {
          // can't go before the first line
          rex.line = (uint8_t *)reg_getline(++rex.lnum);
        }
      }
      rex.input = rex.line;
    } else {
      if (REG_MULTI && (int)(rex.input - rex.line) < state->val) {
        // Not enough bytes in this line, go to end of
        // previous line.
        rex.line = (uint8_t *)reg_getline(--rex.lnum);
        if (rex.line == NULL) {
          // can't go before the first line
          rex.line = (uint8_t *)reg_getline(++rex.lnum);
          rex.input = rex.line;
        } else {
          rex.input = rex.line + reg_getline_len(rex.lnum);
        }
      }
      if ((int)(rex.input - rex.line) >= state->val) {
        rex.input -= state->val;
        rex.input -= utf_head_off((char *)rex.line, (char *)rex.input);
      } else {
        rex.input = rex.line;
      }
    }
  }

#ifdef REGEXP_DEBUG
  if (log_fd != stderr) {
    fclose(log_fd);
  }
  log_fd = NULL;
#endif
  // Have to clear the lastlist field of the NFA nodes, so that
  // nfa_regmatch() and addstate() can run properly after recursion.
  if (nfa_ll_index == 1) {
    // Already calling nfa_regmatch() recursively.  Save the lastlist[1]
    // values and clear them.
    if (*listids == NULL || *listids_len < prog->nstate) {
      xfree(*listids);
      *listids = xmalloc(sizeof(**listids) * (size_t)prog->nstate);
      *listids_len = prog->nstate;
    }
    nfa_save_listids(prog, *listids);
    need_restore = true;
    // any value of rex.nfa_listid will do
  } else {
    // First recursive nfa_regmatch() call, switch to the second lastlist
    // entry.  Make sure rex.nfa_listid is different from a previous
    // recursive call, because some states may still have this ID.
    nfa_ll_index++;
    if (rex.nfa_listid <= rex.nfa_alt_listid) {
      rex.nfa_listid = rex.nfa_alt_listid;
    }
  }

  // Call nfa_regmatch() to check if the current concat matches at this
  // position. The concat ends with the node NFA_END_INVISIBLE
  nfa_endp = endposp;
  const int result = nfa_regmatch(prog, state->out, submatch, m);

  if (need_restore) {
    nfa_restore_listids(prog, *listids);
  } else {
    nfa_ll_index--;
    rex.nfa_alt_listid = rex.nfa_listid;
  }

  // restore position in input text
  rex.lnum = save_reglnum;
  if (REG_MULTI) {
    rex.line = (uint8_t *)reg_getline(rex.lnum);
  }
  rex.input = rex.line + save_reginput_col;
  if (result != NFA_TOO_EXPENSIVE) {
    nfa_match = save_nfa_match;
    rex.nfa_listid = save_nfa_listid;
  }
  nfa_endp = save_nfa_endp;

#ifdef REGEXP_DEBUG
  open_debug_log(result);
#endif

  return result;
}

// Estimate the chance of a match with "state" failing.
// empty match: 0
// NFA_ANY: 1
// specific character: 99
static int failure_chance(nfa_state_T *state, int depth)
{
  int c = state->c;
  int l, r;

  // detect looping
  if (depth > 4) {
    return 1;
  }

  switch (c) {
  case NFA_SPLIT:
    if (state->out->c == NFA_SPLIT || state->out1->c == NFA_SPLIT) {
      // avoid recursive stuff
      return 1;
    }
    // two alternatives, use the lowest failure chance
    l = failure_chance(state->out, depth + 1);
    r = failure_chance(state->out1, depth + 1);
    return l < r ? l : r;

  case NFA_ANY:
    // matches anything, unlikely to fail
    return 1;

  case NFA_MATCH:
  case NFA_MCLOSE:
  case NFA_ANY_COMPOSING:
    // empty match works always
    return 0;

  case NFA_START_INVISIBLE:
  case NFA_START_INVISIBLE_FIRST:
  case NFA_START_INVISIBLE_NEG:
  case NFA_START_INVISIBLE_NEG_FIRST:
  case NFA_START_INVISIBLE_BEFORE:
  case NFA_START_INVISIBLE_BEFORE_FIRST:
  case NFA_START_INVISIBLE_BEFORE_NEG:
  case NFA_START_INVISIBLE_BEFORE_NEG_FIRST:
  case NFA_START_PATTERN:
    // recursive regmatch is expensive, use low failure chance
    return 5;

  case NFA_BOL:
  case NFA_EOL:
  case NFA_BOF:
  case NFA_EOF:
  case NFA_NEWL:
    return 99;

  case NFA_BOW:
  case NFA_EOW:
    return 90;

  case NFA_MOPEN:
  case NFA_MOPEN1:
  case NFA_MOPEN2:
  case NFA_MOPEN3:
  case NFA_MOPEN4:
  case NFA_MOPEN5:
  case NFA_MOPEN6:
  case NFA_MOPEN7:
  case NFA_MOPEN8:
  case NFA_MOPEN9:
  case NFA_ZOPEN:
  case NFA_ZOPEN1:
  case NFA_ZOPEN2:
  case NFA_ZOPEN3:
  case NFA_ZOPEN4:
  case NFA_ZOPEN5:
  case NFA_ZOPEN6:
  case NFA_ZOPEN7:
  case NFA_ZOPEN8:
  case NFA_ZOPEN9:
  case NFA_ZCLOSE:
  case NFA_ZCLOSE1:
  case NFA_ZCLOSE2:
  case NFA_ZCLOSE3:
  case NFA_ZCLOSE4:
  case NFA_ZCLOSE5:
  case NFA_ZCLOSE6:
  case NFA_ZCLOSE7:
  case NFA_ZCLOSE8:
  case NFA_ZCLOSE9:
  case NFA_NOPEN:
  case NFA_MCLOSE1:
  case NFA_MCLOSE2:
  case NFA_MCLOSE3:
  case NFA_MCLOSE4:
  case NFA_MCLOSE5:
  case NFA_MCLOSE6:
  case NFA_MCLOSE7:
  case NFA_MCLOSE8:
  case NFA_MCLOSE9:
  case NFA_NCLOSE:
    return failure_chance(state->out, depth + 1);

  case NFA_BACKREF1:
  case NFA_BACKREF2:
  case NFA_BACKREF3:
  case NFA_BACKREF4:
  case NFA_BACKREF5:
  case NFA_BACKREF6:
  case NFA_BACKREF7:
  case NFA_BACKREF8:
  case NFA_BACKREF9:
  case NFA_ZREF1:
  case NFA_ZREF2:
  case NFA_ZREF3:
  case NFA_ZREF4:
  case NFA_ZREF5:
  case NFA_ZREF6:
  case NFA_ZREF7:
  case NFA_ZREF8:
  case NFA_ZREF9:
    // backreferences don't match in many places
    return 94;

  case NFA_LNUM_GT:
  case NFA_LNUM_LT:
  case NFA_COL_GT:
  case NFA_COL_LT:
  case NFA_VCOL_GT:
  case NFA_VCOL_LT:
  case NFA_MARK_GT:
  case NFA_MARK_LT:
  case NFA_VISUAL:
    // before/after positions don't match very often
    return 85;

  case NFA_LNUM:
    return 90;

  case NFA_CURSOR:
  case NFA_COL:
  case NFA_VCOL:
  case NFA_MARK:
    // specific positions rarely match
    return 98;

  case NFA_COMPOSING:
    return 95;

  default:
    if (c > 0) {
      // character match fails often
      return 95;
    }
  }

  // something else, includes character classes
  return 50;
}

// Skip until the char "c" we know a match must start with.
static int skip_to_start(int c, colnr_T *colp)
{
  const uint8_t *const s = (uint8_t *)cstrchr((char *)rex.line + *colp, c);
  if (s == NULL) {
    return FAIL;
  }
  *colp = (int)(s - rex.line);
  return OK;
}

// Check for a match with match_text.
// Called after skip_to_start() has found regstart.
// Returns zero for no match, 1 for a match.
static int find_match_text(colnr_T *startcol, int regstart, uint8_t *match_text)
{
  colnr_T col = *startcol;
  const int regstart_len = utf_char2len(regstart);

  while (true) {
    bool match = true;
    uint8_t *s1 = match_text;
    // skip regstart
    int regstart_len2 = regstart_len;
    if (regstart_len2 > 1 && utf_ptr2len((char *)rex.line + col) != regstart_len2) {
      // because of case-folding of the previously matched text, we may need
      // to skip fewer bytes than utf_char2len(regstart)
      regstart_len2 = utf_char2len(utf_fold(regstart));
    }
    uint8_t *s2 = rex.line + col + regstart_len2;
    while (*s1) {
      int c1_len = utf_ptr2len((char *)s1);
      int c1 = utf_ptr2char((char *)s1);
      int c2_len = utf_ptr2len((char *)s2);
      int c2 = utf_ptr2char((char *)s2);
      if (c1 != c2 && (!rex.reg_ic || utf_fold(c1) != utf_fold(c2))) {
        match = false;
        break;
      }
      s1 += c1_len;
      s2 += c2_len;
    }
    if (match
        // check that no composing char follows
        && !utf_iscomposing(utf_ptr2char((char *)s2))) {
      cleanup_subexpr();
      if (REG_MULTI) {
        rex.reg_startpos[0].lnum = rex.lnum;
        rex.reg_startpos[0].col = col;
        rex.reg_endpos[0].lnum = rex.lnum;
        rex.reg_endpos[0].col = (colnr_T)(s2 - rex.line);
      } else {
        rex.reg_startp[0] = rex.line + col;
        rex.reg_endp[0] = s2;
      }
      *startcol = col;
      return 1L;
    }

    // Try finding regstart after the current match.
    col += regstart_len;  // skip regstart
    if (skip_to_start(regstart, &col) == FAIL) {
      break;
    }
  }

  *startcol = col;
  return 0L;
}

static int nfa_did_time_out(void)
{
  if (nfa_time_limit != NULL && profile_passed_limit(*nfa_time_limit)) {
    if (nfa_timed_out != NULL) {
      *nfa_timed_out = true;
    }
    return true;
  }
  return false;
}

/// Main matching routine.
///
/// Run NFA to determine whether it matches rex.input.
///
/// When "nfa_endp" is not NULL it is a required end-of-match position.
///
/// Return true if there is a match, false if there is no match,
/// NFA_TOO_EXPENSIVE if we end up with too many states.
/// When there is a match "submatch" contains the positions.
///
/// Note: Caller must ensure that: start != NULL.
static int nfa_regmatch(nfa_regprog_T *prog, nfa_state_T *start, regsubs_T *submatch, regsubs_T *m)
  FUNC_ATTR_NONNULL_ARG(1, 2, 4)
{
  int result = false;
  int flag = 0;
  bool go_to_nextline = false;
  nfa_thread_T *t;
  nfa_list_T list[2];
  int listidx;
  nfa_list_T *thislist;
  nfa_list_T *nextlist;
  int *listids = NULL;
  int listids_len = 0;
  nfa_state_T *add_state;
  bool add_here;
  int add_count;
  int add_off = 0;
  int toplevel = start->c == NFA_MOPEN;
  regsubs_T *r;
  // Some patterns may take a long time to match, especially when using
  // recursive_regmatch(). Allow interrupting them with CTRL-C.
  reg_breakcheck();
  if (got_int) {
    return false;
  }
  if (nfa_did_time_out()) {
    return false;
  }

#ifdef NFA_REGEXP_DEBUG_LOG
  FILE *debug = fopen(NFA_REGEXP_DEBUG_LOG, "a");

  if (debug == NULL) {
    semsg("(NFA) COULD NOT OPEN %s!", NFA_REGEXP_DEBUG_LOG);
    return false;
  }
#endif
  nfa_match = false;

  // Allocate memory for the lists of nodes.
  size_t size = (size_t)(prog->nstate + 1) * sizeof(nfa_thread_T);
  list[0].t = xmalloc(size);
  list[0].len = prog->nstate + 1;
  list[1].t = xmalloc(size);
  list[1].len = prog->nstate + 1;

#ifdef REGEXP_DEBUG
  log_fd = fopen(NFA_REGEXP_RUN_LOG, "a");
  if (log_fd == NULL) {
    emsg(_(e_log_open_failed));
    log_fd = stderr;
  }
  fprintf(log_fd, "**********************************\n");
  nfa_set_code(start->c);
  fprintf(log_fd, " RUNNING nfa_regmatch() starting with state %d, code %s\n",
          abs(start->id), code);
  fprintf(log_fd, "**********************************\n");
#endif

  thislist = &list[0];
  thislist->n = 0;
  thislist->has_pim = false;
  nextlist = &list[1];
  nextlist->n = 0;
  nextlist->has_pim = false;
#ifdef REGEXP_DEBUG
  fprintf(log_fd, "(---) STARTSTATE first\n");
#endif
  thislist->id = rex.nfa_listid + 1;

  // Inline optimized code for addstate(thislist, start, m, 0) if we know
  // it's the first MOPEN.
  if (toplevel) {
    if (REG_MULTI) {
      m->norm.list.multi[0].start_lnum = rex.lnum;
      m->norm.list.multi[0].start_col = (colnr_T)(rex.input - rex.line);
      m->norm.orig_start_col = m->norm.list.multi[0].start_col;
    } else {
      m->norm.list.line[0].start = rex.input;
    }
    m->norm.in_use = 1;
    r = addstate(thislist, start->out, m, NULL, 0);
  } else {
    r = addstate(thislist, start, m, NULL, 0);
  }
  if (r == NULL) {
    nfa_match = NFA_TOO_EXPENSIVE;
    goto theend;
  }

#define ADD_STATE_IF_MATCH(state) \
  if (result) { \
    add_state = (state)->out; \
    add_off = clen; \
  }

  // Run for each character.
  while (true) {
    int curc = utf_ptr2char((char *)rex.input);
    int clen = utfc_ptr2len((char *)rex.input);
    if (curc == NUL) {
      clen = 0;
      go_to_nextline = false;
    }

    // swap lists
    thislist = &list[flag];
    nextlist = &list[flag ^= 1];
    nextlist->n = 0;                // clear nextlist
    nextlist->has_pim = false;
    rex.nfa_listid++;
    if (prog->re_engine == AUTOMATIC_ENGINE
        && (rex.nfa_listid >= NFA_MAX_STATES)) {
      // Too many states, retry with old engine.
      nfa_match = NFA_TOO_EXPENSIVE;
      goto theend;
    }

    thislist->id = rex.nfa_listid;
    nextlist->id = rex.nfa_listid + 1;

#ifdef REGEXP_DEBUG
    fprintf(log_fd, "------------------------------------------\n");
    fprintf(log_fd, ">>> Reginput is \"%s\"\n", rex.input);
    fprintf(log_fd,
            ">>> Advanced one character... Current char is %c (code %d) \n",
            curc,
            (int)curc);
    fprintf(log_fd, ">>> Thislist has %d states available: ", thislist->n);
    {
      int i;

      for (i = 0; i < thislist->n; i++) {
        fprintf(log_fd, "%d  ", abs(thislist->t[i].state->id));
      }
    }
    fprintf(log_fd, "\n");
#endif

#ifdef NFA_REGEXP_DEBUG_LOG
    fprintf(debug, "\n-------------------\n");
#endif
    // If the state lists are empty we can stop.
    if (thislist->n == 0) {
      break;
    }

    // compute nextlist
    for (listidx = 0; listidx < thislist->n; listidx++) {
      // If the list gets very long there probably is something wrong.
      // At least allow interrupting with CTRL-C.
      reg_breakcheck();
      if (got_int) {
        break;
      }
      if (nfa_time_limit != NULL && ++nfa_time_count == 20) {
        nfa_time_count = 0;
        if (nfa_did_time_out()) {
          break;
        }
      }
      t = &thislist->t[listidx];

#ifdef NFA_REGEXP_DEBUG_LOG
      nfa_set_code(t->state->c);
      fprintf(debug, "%s, ", code);
#endif
#ifdef REGEXP_DEBUG
      {
        int col;

        if (t->subs.norm.in_use <= 0) {
          col = -1;
        } else if (REG_MULTI) {
          col = t->subs.norm.list.multi[0].start_col;
        } else {
          col = (int)(t->subs.norm.list.line[0].start - rex.line);
        }
        nfa_set_code(t->state->c);
        fprintf(log_fd, "(%d) char %d %s (start col %d)%s... \n",
                abs(t->state->id), (int)t->state->c, code, col,
                pim_info(&t->pim));
      }
#endif

      // Handle the possible codes of the current state.
      // The most important is NFA_MATCH.
      add_state = NULL;
      add_here = false;
      add_count = 0;
      switch (t->state->c) {
      case NFA_MATCH:
        // If the match is not at the start of the line, ends before a
        // composing characters and rex.reg_icombine is not set, that
        // is not really a match.
        if (!rex.reg_icombine
            && rex.input != rex.line
            && utf_iscomposing(curc)) {
          break;
        }
        nfa_match = true;
        copy_sub(&submatch->norm, &t->subs.norm);
        if (rex.nfa_has_zsubexpr) {
          copy_sub(&submatch->synt, &t->subs.synt);
        }
#ifdef REGEXP_DEBUG
        log_subsexpr(&t->subs);
#endif
        // Found the left-most longest match, do not look at any other
        // states at this position.  When the list of states is going
        // to be empty quit without advancing, so that "rex.input" is
        // correct.
        if (nextlist->n == 0) {
          clen = 0;
        }
        goto nextchar;

      case NFA_END_INVISIBLE:
      case NFA_END_INVISIBLE_NEG:
      case NFA_END_PATTERN:
        // This is only encountered after a NFA_START_INVISIBLE or
        // NFA_START_INVISIBLE_BEFORE node.
        // They surround a zero-width group, used with "\@=", "\&",
        // "\@!", "\@<=" and "\@<!".
        // If we got here, it means that the current "invisible" group
        // finished successfully, so return control to the parent
        // nfa_regmatch().  For a look-behind match only when it ends
        // in the position in "nfa_endp".
        // Submatches are stored in *m, and used in the parent call.
#ifdef REGEXP_DEBUG
        if (nfa_endp != NULL) {
          if (REG_MULTI) {
            fprintf(log_fd,
                    "Current lnum: %d, endp lnum: %d;"
                    " current col: %d, endp col: %d\n",
                    (int)rex.lnum,
                    (int)nfa_endp->se_u.pos.lnum,
                    (int)(rex.input - rex.line),
                    nfa_endp->se_u.pos.col);
          } else {
            fprintf(log_fd, "Current col: %d, endp col: %d\n",
                    (int)(rex.input - rex.line),
                    (int)(nfa_endp->se_u.ptr - rex.input));
          }
        }
#endif
        // If "nfa_endp" is set it's only a match if it ends at
        // "nfa_endp"
        if (nfa_endp != NULL
            && (REG_MULTI
                ? (rex.lnum != nfa_endp->se_u.pos.lnum
                   || (int)(rex.input - rex.line) != nfa_endp->se_u.pos.col)
                : rex.input != nfa_endp->se_u.ptr)) {
          break;
        }
        // do not set submatches for \@!
        if (t->state->c != NFA_END_INVISIBLE_NEG) {
          copy_sub(&m->norm, &t->subs.norm);
          if (rex.nfa_has_zsubexpr) {
            copy_sub(&m->synt, &t->subs.synt);
          }
        }
#ifdef REGEXP_DEBUG
        fprintf(log_fd, "Match found:\n");
        log_subsexpr(m);
#endif
        nfa_match = true;
        // See comment above at "goto nextchar".
        if (nextlist->n == 0) {
          clen = 0;
        }
        goto nextchar;

      case NFA_START_INVISIBLE:
      case NFA_START_INVISIBLE_FIRST:
      case NFA_START_INVISIBLE_NEG:
      case NFA_START_INVISIBLE_NEG_FIRST:
      case NFA_START_INVISIBLE_BEFORE:
      case NFA_START_INVISIBLE_BEFORE_FIRST:
      case NFA_START_INVISIBLE_BEFORE_NEG:
      case NFA_START_INVISIBLE_BEFORE_NEG_FIRST:
#ifdef REGEXP_DEBUG
        fprintf(log_fd, "Failure chance invisible: %d, what follows: %d\n",
                failure_chance(t->state->out, 0),
                failure_chance(t->state->out1->out, 0));
#endif
        // Do it directly if there already is a PIM or when
        // nfa_postprocess() detected it will work better.
        if (t->pim.result != NFA_PIM_UNUSED
            || t->state->c == NFA_START_INVISIBLE_FIRST
            || t->state->c == NFA_START_INVISIBLE_NEG_FIRST
            || t->state->c == NFA_START_INVISIBLE_BEFORE_FIRST
            || t->state->c == NFA_START_INVISIBLE_BEFORE_NEG_FIRST) {
          int in_use = m->norm.in_use;

          // Copy submatch info for the recursive call, opposite
          // of what happens on success below.
          copy_sub_off(&m->norm, &t->subs.norm);
          if (rex.nfa_has_zsubexpr) {
            copy_sub_off(&m->synt, &t->subs.synt);
          }
          // First try matching the invisible match, then what
          // follows.
          result = recursive_regmatch(t->state, NULL, prog, submatch, m,
                                      &listids, &listids_len);
          if (result == NFA_TOO_EXPENSIVE) {
            nfa_match = result;
            goto theend;
          }

          // for \@! and \@<! it is a match when the result is
          // false
          if (result != (t->state->c == NFA_START_INVISIBLE_NEG
                         || t->state->c == NFA_START_INVISIBLE_NEG_FIRST
                         || t->state->c
                         == NFA_START_INVISIBLE_BEFORE_NEG
                         || t->state->c
                         == NFA_START_INVISIBLE_BEFORE_NEG_FIRST)) {
            // Copy submatch info from the recursive call
            copy_sub_off(&t->subs.norm, &m->norm);
            if (rex.nfa_has_zsubexpr) {
              copy_sub_off(&t->subs.synt, &m->synt);
            }
            // If the pattern has \ze and it matched in the
            // sub pattern, use it.
            copy_ze_off(&t->subs.norm, &m->norm);

            // t->state->out1 is the corresponding
            // END_INVISIBLE node; Add its out to the current
            // list (zero-width match).
            add_here = true;
            add_state = t->state->out1->out;
          }
          m->norm.in_use = in_use;
        } else {
          nfa_pim_T pim;

          // First try matching what follows.  Only if a match
          // is found verify the invisible match matches.  Add a
          // nfa_pim_T to the following states, it contains info
          // about the invisible match.
          pim.state = t->state;
          pim.result = NFA_PIM_TODO;
          pim.subs.norm.in_use = 0;
          pim.subs.synt.in_use = 0;
          if (REG_MULTI) {
            pim.end.pos.col = (int)(rex.input - rex.line);
            pim.end.pos.lnum = rex.lnum;
          } else {
            pim.end.ptr = rex.input;
          }
          // t->state->out1 is the corresponding END_INVISIBLE
          // node; Add its out to the current list (zero-width
          // match).
          if (addstate_here(thislist, t->state->out1->out, &t->subs,
                            &pim, &listidx) == NULL) {
            nfa_match = NFA_TOO_EXPENSIVE;
            goto theend;
          }
        }
        break;

      case NFA_START_PATTERN: {
        nfa_state_T *skip = NULL;
#ifdef REGEXP_DEBUG
        int skip_lid = 0;
#endif

        // There is no point in trying to match the pattern if the
        // output state is not going to be added to the list.
        if (state_in_list(nextlist, t->state->out1->out, &t->subs)) {
          skip = t->state->out1->out;
#ifdef REGEXP_DEBUG
          skip_lid = nextlist->id;
#endif
        } else if (state_in_list(nextlist,
                                 t->state->out1->out->out, &t->subs)) {
          skip = t->state->out1->out->out;
#ifdef REGEXP_DEBUG
          skip_lid = nextlist->id;
#endif
        } else if (state_in_list(thislist,
                                 t->state->out1->out->out, &t->subs)) {
          skip = t->state->out1->out->out;
#ifdef REGEXP_DEBUG
          skip_lid = thislist->id;
#endif
        }
        if (skip != NULL) {
#ifdef REGEXP_DEBUG
          nfa_set_code(skip->c);
          fprintf(log_fd,
                  "> Not trying to match pattern, output state %d is already in list %d. char %d: %s\n",
                  abs(skip->id), skip_lid, skip->c, code);
#endif
          break;
        }
        // Copy submatch info to the recursive call, opposite of what
        // happens afterwards.
        copy_sub_off(&m->norm, &t->subs.norm);
        if (rex.nfa_has_zsubexpr) {
          copy_sub_off(&m->synt, &t->subs.synt);
        }

        // First try matching the pattern.
        result = recursive_regmatch(t->state, NULL, prog, submatch, m,
                                    &listids, &listids_len);
        if (result == NFA_TOO_EXPENSIVE) {
          nfa_match = result;
          goto theend;
        }
        if (result) {
          int bytelen;

#ifdef REGEXP_DEBUG
          fprintf(log_fd, "NFA_START_PATTERN matches:\n");
          log_subsexpr(m);
#endif
          // Copy submatch info from the recursive call
          copy_sub_off(&t->subs.norm, &m->norm);
          if (rex.nfa_has_zsubexpr) {
            copy_sub_off(&t->subs.synt, &m->synt);
          }
          // Now we need to skip over the matched text and then
          // continue with what follows.
          if (REG_MULTI) {
            // TODO(RE): multi-line match
            bytelen = m->norm.list.multi[0].end_col
                      - (int)(rex.input - rex.line);
          } else {
            bytelen = (int)(m->norm.list.line[0].end - rex.input);
          }

#ifdef REGEXP_DEBUG
          fprintf(log_fd, "NFA_START_PATTERN length: %d\n", bytelen);
#endif
          if (bytelen == 0) {
            // empty match, output of corresponding
            // NFA_END_PATTERN/NFA_SKIP to be used at current
            // position
            add_here = true;
            add_state = t->state->out1->out->out;
          } else if (bytelen <= clen) {
            // match current character, output of corresponding
            // NFA_END_PATTERN to be used at next position.
            add_state = t->state->out1->out->out;
            add_off = clen;
          } else {
            // skip over the matched characters, set character
            // count in NFA_SKIP
            add_state = t->state->out1->out;
            add_off = bytelen;
            add_count = bytelen - clen;
          }
        }
        break;
      }

      case NFA_BOL:
        if (rex.input == rex.line) {
          add_here = true;
          add_state = t->state->out;
        }
        break;

      case NFA_EOL:
        if (curc == NUL) {
          add_here = true;
          add_state = t->state->out;
        }
        break;

      case NFA_BOW:
        result = true;

        if (curc == NUL) {
          result = false;
        } else {
          int this_class;

          // Get class of current and previous char (if it exists).
          this_class = mb_get_class_tab((char *)rex.input, rex.reg_buf->b_chartab);
          if (this_class <= 1) {
            result = false;
          } else if (reg_prev_class() == this_class) {
            result = false;
          }
        }
        if (result) {
          add_here = true;
          add_state = t->state->out;
        }
        break;

      case NFA_EOW:
        result = true;
        if (rex.input == rex.line) {
          result = false;
        } else {
          int this_class, prev_class;

          // Get class of current and previous char (if it exists).
          this_class = mb_get_class_tab((char *)rex.input, rex.reg_buf->b_chartab);
          prev_class = reg_prev_class();
          if (this_class == prev_class
              || prev_class == 0 || prev_class == 1) {
            result = false;
          }
        }
        if (result) {
          add_here = true;
          add_state = t->state->out;
        }
        break;

      case NFA_BOF:
        if (rex.lnum == 0 && rex.input == rex.line
            && (!REG_MULTI || rex.reg_firstlnum == 1)) {
          add_here = true;
          add_state = t->state->out;
        }
        break;

      case NFA_EOF:
        if (rex.lnum == rex.reg_maxline && curc == NUL) {
          add_here = true;
          add_state = t->state->out;
        }
        break;

      case NFA_COMPOSING: {
        int mc = curc;
        int len = 0;
        nfa_state_T *end;
        nfa_state_T *sta;
        int cchars[MAX_MCO];
        int ccount = 0;
        int j;

        sta = t->state->out;
        len = 0;
        if (utf_iscomposing(sta->c)) {
          // Only match composing character(s), ignore base
          // character.  Used for ".{composing}" and "{composing}"
          // (no preceding character).
          len += utf_char2len(mc);
        }
        if (rex.reg_icombine && len == 0) {
          // If \Z was present, then ignore composing characters.
          // When ignoring the base character this always matches.
          if (sta->c != curc) {
            result = FAIL;
          } else {
            result = OK;
          }
          while (sta->c != NFA_END_COMPOSING) {
            sta = sta->out;
          }
        } else if (len > 0 || mc == sta->c) {
          // Check base character matches first, unless ignored.
          if (len == 0) {
            len += utf_char2len(mc);
            sta = sta->out;
          }

          // We don't care about the order of composing characters.
          // Get them into cchars[] first.
          while (len < clen) {
            mc = utf_ptr2char((char *)rex.input + len);
            cchars[ccount++] = mc;
            len += utf_char2len(mc);
            if (ccount == MAX_MCO) {
              break;
            }
          }

          // Check that each composing char in the pattern matches a
          // composing char in the text.  We do not check if all
          // composing chars are matched.
          result = OK;
          while (sta->c != NFA_END_COMPOSING) {
            for (j = 0; j < ccount; j++) {
              if (cchars[j] == sta->c) {
                break;
              }
            }
            if (j == ccount) {
              result = FAIL;
              break;
            }
            sta = sta->out;
          }
        } else {
          result = FAIL;
        }

        end = t->state->out1;               // NFA_END_COMPOSING
        ADD_STATE_IF_MATCH(end);
        break;
      }

      case NFA_NEWL:
        if (curc == NUL && !rex.reg_line_lbr && REG_MULTI
            && rex.lnum <= rex.reg_maxline) {
          go_to_nextline = true;
          // Pass -1 for the offset, which means taking the position
          // at the start of the next line.
          add_state = t->state->out;
          add_off = -1;
        } else if (curc == '\n' && rex.reg_line_lbr) {
          // match \n as if it is an ordinary character
          add_state = t->state->out;
          add_off = 1;
        }
        break;

      case NFA_START_COLL:
      case NFA_START_NEG_COLL: {
        // What follows is a list of characters, until NFA_END_COLL.
        // One of them must match or none of them must match.
        nfa_state_T *state;
        int result_if_matched;
        int c1, c2;

        // Never match EOL. If it's part of the collection it is added
        // as a separate state with an OR.
        if (curc == NUL) {
          break;
        }

        state = t->state->out;
        result_if_matched = (t->state->c == NFA_START_COLL);
        while (true) {
          if (state->c == NFA_COMPOSING) {
            int mc = curc;
            int len = 0;
            nfa_state_T *end;
            nfa_state_T *sta;
            int cchars[MAX_MCO];
            int ccount = 0;
            int j;

            sta = t->state->out->out;
            if (utf_iscomposing(sta->c)) {
              // Only match composing character(s), ignore base
              // character.  Used for ".{composing}" and "{composing}"
              // (no preceding character).
              len += utf_char2len(mc);
            }
            if (rex.reg_icombine && len == 0) {
              // If \Z was present, then ignore composing characters.
              // When ignoring the base character this always matches.
              if (sta->c != curc) {
                result = FAIL;
              } else {
                result = OK;
              }
              while (sta->c != NFA_END_COMPOSING) {
                sta = sta->out;
              }
            }
            // Check base character matches first, unless ignored.
            else if (len > 0 || mc == sta->c) {
              if (len == 0) {
                len += utf_char2len(mc);
                sta = sta->out;
              }

              // We don't care about the order of composing characters.
              // Get them into cchars[] first.
              while (len < clen) {
                mc = utf_ptr2char((char *)rex.input + len);
                cchars[ccount++] = mc;
                len += utf_char2len(mc);
                if (ccount == MAX_MCO) {
                  break;
                }
              }

              // Check that each composing char in the pattern matches a
              // composing char in the text.  We do not check if all
              // composing chars are matched.
              result = OK;
              while (sta->c != NFA_END_COMPOSING) {
                for (j = 0; j < ccount; j++) {
                  if (cchars[j] == sta->c) {
                    break;
                  }
                }
                if (j == ccount) {
                  result = FAIL;
                  break;
                }
                sta = sta->out;
              }
            } else {
              result = FAIL;
            }

            if (t->state->out->out1->c == NFA_END_COMPOSING) {
              end = t->state->out->out1;
              ADD_STATE_IF_MATCH(end);
            }
            break;
          }
          if (state->c == NFA_END_COLL) {
            result = !result_if_matched;
            break;
          }
          if (state->c == NFA_RANGE_MIN) {
            c1 = state->val;
            state = state->out;             // advance to NFA_RANGE_MAX
            c2 = state->val;
#ifdef REGEXP_DEBUG
            fprintf(log_fd, "NFA_RANGE_MIN curc=%d c1=%d c2=%d\n",
                    curc, c1, c2);
#endif
            if (curc >= c1 && curc <= c2) {
              result = result_if_matched;
              break;
            }
            if (rex.reg_ic) {
              int curc_low = utf_fold(curc);
              int done = false;

              for (; c1 <= c2; c1++) {
                if (utf_fold(c1) == curc_low) {
                  result = result_if_matched;
                  done = true;
                  break;
                }
              }
              if (done) {
                break;
              }
            }
          } else if (state->c < 0 ? check_char_class(state->c, curc)
                                  : (curc == state->c
                                     || (rex.reg_ic
                                         && utf_fold(curc) == utf_fold(state->c)))) {
            result = result_if_matched;
            break;
          }
          state = state->out;
        }
        if (result) {
          // next state is in out of the NFA_END_COLL, out1 of
          // START points to the END state
          add_state = t->state->out1->out;
          add_off = clen;
        }
        break;
      }

      case NFA_ANY:
        // Any char except NUL, (end of input) does not match.
        if (curc > 0) {
          add_state = t->state->out;
          add_off = clen;
        }
        break;

      case NFA_ANY_COMPOSING:
        // On a composing character skip over it.  Otherwise do
        // nothing.  Always matches.
        if (utf_iscomposing(curc)) {
          add_off = clen;
        } else {
          add_here = true;
          add_off = 0;
        }
        add_state = t->state->out;
        break;

      // Character classes like \a for alpha, \d for digit etc.
      case NFA_IDENT:           //  \i
        result = vim_isIDc(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_SIDENT:          //  \I
        result = !ascii_isdigit(curc) && vim_isIDc(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_KWORD:           //  \k
        result = vim_iswordp_buf((char *)rex.input, rex.reg_buf);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_SKWORD:          //  \K
        result = !ascii_isdigit(curc)
                 && vim_iswordp_buf((char *)rex.input, rex.reg_buf);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_FNAME:           //  \f
        result = vim_isfilec(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_SFNAME:          //  \F
        result = !ascii_isdigit(curc) && vim_isfilec(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_PRINT:           //  \p
        result = vim_isprintc(utf_ptr2char((char *)rex.input));
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_SPRINT:          //  \P
        result = !ascii_isdigit(curc) && vim_isprintc(utf_ptr2char((char *)rex.input));
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_WHITE:           //  \s
        result = ascii_iswhite(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_NWHITE:          //  \S
        result = curc != NUL && !ascii_iswhite(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_DIGIT:           //  \d
        result = ri_digit(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_NDIGIT:          //  \D
        result = curc != NUL && !ri_digit(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_HEX:             //  \x
        result = ri_hex(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_NHEX:            //  \X
        result = curc != NUL && !ri_hex(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_OCTAL:           //  \o
        result = ri_octal(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_NOCTAL:          //  \O
        result = curc != NUL && !ri_octal(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_WORD:            //  \w
        result = ri_word(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_NWORD:           //  \W
        result = curc != NUL && !ri_word(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_HEAD:            //  \h
        result = ri_head(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_NHEAD:           //  \H
        result = curc != NUL && !ri_head(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_ALPHA:           //  \a
        result = ri_alpha(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_NALPHA:          //  \A
        result = curc != NUL && !ri_alpha(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_LOWER:           //  \l
        result = ri_lower(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_NLOWER:          //  \L
        result = curc != NUL && !ri_lower(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_UPPER:           //  \u
        result = ri_upper(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_NUPPER:          // \U
        result = curc != NUL && !ri_upper(curc);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_LOWER_IC:        // [a-z]
        result = ri_lower(curc) || (rex.reg_ic && ri_upper(curc));
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_NLOWER_IC:       // [^a-z]
        result = curc != NUL
                 && !(ri_lower(curc) || (rex.reg_ic && ri_upper(curc)));
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_UPPER_IC:        // [A-Z]
        result = ri_upper(curc) || (rex.reg_ic && ri_lower(curc));
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_NUPPER_IC:       // [^A-Z]
        result = curc != NUL
                 && !(ri_upper(curc) || (rex.reg_ic && ri_lower(curc)));
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_BACKREF1:
      case NFA_BACKREF2:
      case NFA_BACKREF3:
      case NFA_BACKREF4:
      case NFA_BACKREF5:
      case NFA_BACKREF6:
      case NFA_BACKREF7:
      case NFA_BACKREF8:
      case NFA_BACKREF9:
      case NFA_ZREF1:
      case NFA_ZREF2:
      case NFA_ZREF3:
      case NFA_ZREF4:
      case NFA_ZREF5:
      case NFA_ZREF6:
      case NFA_ZREF7:
      case NFA_ZREF8:
      case NFA_ZREF9:
        // \1 .. \9  \z1 .. \z9
      {
        int subidx;
        int bytelen;

        if (t->state->c <= NFA_BACKREF9) {
          subidx = t->state->c - NFA_BACKREF1 + 1;
          result = match_backref(&t->subs.norm, subidx, &bytelen);
        } else {
          subidx = t->state->c - NFA_ZREF1 + 1;
          result = match_zref(subidx, &bytelen);
        }

        if (result) {
          if (bytelen == 0) {
            // empty match always works, output of NFA_SKIP to be
            // used next
            add_here = true;
            add_state = t->state->out->out;
          } else if (bytelen <= clen) {
            // match current character, jump ahead to out of
            // NFA_SKIP
            add_state = t->state->out->out;
            add_off = clen;
          } else {
            // skip over the matched characters, set character
            // count in NFA_SKIP
            add_state = t->state->out;
            add_off = bytelen;
            add_count = bytelen - clen;
          }
        }
        break;
      }
      case NFA_SKIP:
        // character of previous matching \1 .. \9  or \@>
        if (t->count - clen <= 0) {
          // end of match, go to what follows
          add_state = t->state->out;
          add_off = clen;
        } else {
          // add state again with decremented count
          add_state = t->state;
          add_off = 0;
          add_count = t->count - clen;
        }
        break;

      case NFA_LNUM:
      case NFA_LNUM_GT:
      case NFA_LNUM_LT:
        assert(t->state->val >= 0
               && !((rex.reg_firstlnum > 0
                     && rex.lnum > LONG_MAX - rex.reg_firstlnum)
                    || (rex.reg_firstlnum < 0
                        && rex.lnum < LONG_MIN + rex.reg_firstlnum))
               && rex.lnum + rex.reg_firstlnum >= 0);
        result = (REG_MULTI
                  && nfa_re_num_cmp((uintmax_t)t->state->val,
                                    t->state->c - NFA_LNUM,
                                    (uintmax_t)rex.lnum + (uintmax_t)rex.reg_firstlnum));
        if (result) {
          add_here = true;
          add_state = t->state->out;
        }
        break;

      case NFA_COL:
      case NFA_COL_GT:
      case NFA_COL_LT:
        assert(t->state->val >= 0
               && rex.input >= rex.line
               && (uintmax_t)(rex.input - rex.line) <= UINTMAX_MAX - 1);
        result = nfa_re_num_cmp((uintmax_t)t->state->val,
                                t->state->c - NFA_COL,
                                (uintmax_t)(rex.input - rex.line + 1));
        if (result) {
          add_here = true;
          add_state = t->state->out;
        }
        break;

      case NFA_VCOL:
      case NFA_VCOL_GT:
      case NFA_VCOL_LT: {
        int op = t->state->c - NFA_VCOL;
        colnr_T col = (colnr_T)(rex.input - rex.line);

        // Bail out quickly when there can't be a match, avoid the overhead of
        // win_linetabsize() on long lines.
        if (op != 1 && col > t->state->val * MB_MAXBYTES) {
          break;
        }

        result = false;
        win_T *wp = rex.reg_win == NULL ? curwin : rex.reg_win;
        if (op == 1 && col - 1 > t->state->val && col > 100) {
          int64_t ts = (int64_t)wp->w_buffer->b_p_ts;

          // Guess that a character won't use more columns than 'tabstop',
          // with a minimum of 4.
          if (ts < 4) {
            ts = 4;
          }
          result = col > t->state->val * ts;
        }
        if (!result) {
          linenr_T lnum = REG_MULTI ? rex.reg_firstlnum + rex.lnum : 1;
          if (REG_MULTI && (lnum <= 0 || lnum > wp->w_buffer->b_ml.ml_line_count)) {
            lnum = 1;
          }
          int vcol = win_linetabsize(wp, lnum, (char *)rex.line, col);
          assert(t->state->val >= 0);
          result = nfa_re_num_cmp((uintmax_t)t->state->val, op, (uintmax_t)vcol + 1);
        }
        if (result) {
          add_here = true;
          add_state = t->state->out;
        }
      }
      break;

      case NFA_MARK:
      case NFA_MARK_GT:
      case NFA_MARK_LT: {
        size_t col = REG_MULTI ? (size_t)(rex.input - rex.line) : 0;
        fmark_T *fm = mark_get(rex.reg_buf, curwin, NULL, kMarkBufLocal, t->state->val);

        // Line may have been freed, get it again.
        if (REG_MULTI) {
          rex.line = (uint8_t *)reg_getline(rex.lnum);
          rex.input = rex.line + col;
        }

        // Compare the mark position to the match position, if the mark
        // exists and mark is set in reg_buf.
        if (fm != NULL && fm->mark.lnum > 0) {
          pos_T *pos = &fm->mark;
          const colnr_T pos_col = pos->lnum == rex.lnum + rex.reg_firstlnum
                                  && pos->col == MAXCOL
                                  ? reg_getline_len(pos->lnum - rex.reg_firstlnum)
                                  : pos->col;

          result = pos->lnum == rex.lnum + rex.reg_firstlnum
                   ? (pos_col == (colnr_T)(rex.input - rex.line)
                      ? t->state->c == NFA_MARK
                      : (pos_col < (colnr_T)(rex.input - rex.line)
                         ? t->state->c == NFA_MARK_GT
                         : t->state->c == NFA_MARK_LT))
                   : (pos->lnum < rex.lnum + rex.reg_firstlnum
                      ? t->state->c == NFA_MARK_GT
                      : t->state->c == NFA_MARK_LT);
          if (result) {
            add_here = true;
            add_state = t->state->out;
          }
        }
        break;
      }

      case NFA_CURSOR:
        result = rex.reg_win != NULL
                 && (rex.lnum + rex.reg_firstlnum == rex.reg_win->w_cursor.lnum)
                 && ((colnr_T)(rex.input - rex.line) == rex.reg_win->w_cursor.col);
        if (result) {
          add_here = true;
          add_state = t->state->out;
        }
        break;

      case NFA_VISUAL:
        result = reg_match_visual();
        if (result) {
          add_here = true;
          add_state = t->state->out;
        }
        break;

      case NFA_MOPEN1:
      case NFA_MOPEN2:
      case NFA_MOPEN3:
      case NFA_MOPEN4:
      case NFA_MOPEN5:
      case NFA_MOPEN6:
      case NFA_MOPEN7:
      case NFA_MOPEN8:
      case NFA_MOPEN9:
      case NFA_ZOPEN:
      case NFA_ZOPEN1:
      case NFA_ZOPEN2:
      case NFA_ZOPEN3:
      case NFA_ZOPEN4:
      case NFA_ZOPEN5:
      case NFA_ZOPEN6:
      case NFA_ZOPEN7:
      case NFA_ZOPEN8:
      case NFA_ZOPEN9:
      case NFA_NOPEN:
      case NFA_ZSTART:
        // These states are only added to be able to bail out when
        // they are added again, nothing is to be done.
        break;

      default:          // regular character
      {
        int c = t->state->c;

#ifdef REGEXP_DEBUG
        if (c < 0) {
          siemsg("INTERNAL: Negative state char: %" PRId64, (int64_t)c);
        }
#endif
        result = (c == curc);

        if (!result && rex.reg_ic) {
          result = utf_fold(c) == utf_fold(curc);
        }

        // If rex.reg_icombine is not set only skip over the character
        // itself.  When it is set skip over composing characters.
        if (result && !rex.reg_icombine) {
          clen = utf_ptr2len((char *)rex.input);
        }

        ADD_STATE_IF_MATCH(t->state);
        break;
      }
      }       // switch (t->state->c)

      if (add_state != NULL) {
        nfa_pim_T *pim;
        nfa_pim_T pim_copy;

        if (t->pim.result == NFA_PIM_UNUSED) {
          pim = NULL;
        } else {
          pim = &t->pim;
        }

        // Handle the postponed invisible match if the match might end
        // without advancing and before the end of the line.
        if (pim != NULL && (clen == 0 || match_follows(add_state, 0))) {
          if (pim->result == NFA_PIM_TODO) {
#ifdef REGEXP_DEBUG
            fprintf(log_fd, "\n");
            fprintf(log_fd, "==================================\n");
            fprintf(log_fd, "Postponed recursive nfa_regmatch()\n");
            fprintf(log_fd, "\n");
#endif
            result = recursive_regmatch(pim->state, pim, prog, submatch, m,
                                        &listids, &listids_len);
            pim->result = result ? NFA_PIM_MATCH : NFA_PIM_NOMATCH;
            // for \@! and \@<! it is a match when the result is
            // false
            if (result != (pim->state->c == NFA_START_INVISIBLE_NEG
                           || pim->state->c == NFA_START_INVISIBLE_NEG_FIRST
                           || pim->state->c
                           == NFA_START_INVISIBLE_BEFORE_NEG
                           || pim->state->c
                           == NFA_START_INVISIBLE_BEFORE_NEG_FIRST)) {
              // Copy submatch info from the recursive call
              copy_sub_off(&pim->subs.norm, &m->norm);
              if (rex.nfa_has_zsubexpr) {
                copy_sub_off(&pim->subs.synt, &m->synt);
              }
            }
          } else {
            result = (pim->result == NFA_PIM_MATCH);
#ifdef REGEXP_DEBUG
            fprintf(log_fd, "\n");
            fprintf(log_fd,
                    "Using previous recursive nfa_regmatch() result, result == %d\n",
                    pim->result);
            fprintf(log_fd, "MATCH = %s\n", result ? "OK" : "false");
            fprintf(log_fd, "\n");
#endif
          }

          // for \@! and \@<! it is a match when result is false
          if (result != (pim->state->c == NFA_START_INVISIBLE_NEG
                         || pim->state->c == NFA_START_INVISIBLE_NEG_FIRST
                         || pim->state->c
                         == NFA_START_INVISIBLE_BEFORE_NEG
                         || pim->state->c
                         == NFA_START_INVISIBLE_BEFORE_NEG_FIRST)) {
            // Copy submatch info from the recursive call
            copy_sub_off(&t->subs.norm, &pim->subs.norm);
            if (rex.nfa_has_zsubexpr) {
              copy_sub_off(&t->subs.synt, &pim->subs.synt);
            }
          } else {
            // look-behind match failed, don't add the state
            continue;
          }

          // Postponed invisible match was handled, don't add it to
          // following states.
          pim = NULL;
        }

        // If "pim" points into l->t it will become invalid when
        // adding the state causes the list to be reallocated.  Make a
        // local copy to avoid that.
        if (pim == &t->pim) {
          copy_pim(&pim_copy, pim);
          pim = &pim_copy;
        }

        if (add_here) {
          r = addstate_here(thislist, add_state, &t->subs, pim, &listidx);
        } else {
          r = addstate(nextlist, add_state, &t->subs, pim, add_off);
          if (add_count > 0) {
            nextlist->t[nextlist->n - 1].count = add_count;
          }
        }
        if (r == NULL) {
          nfa_match = NFA_TOO_EXPENSIVE;
          goto theend;
        }
      }
    }     // for (thislist = thislist; thislist->state; thislist++)

    // Look for the start of a match in the current position by adding the
    // start state to the list of states.
    // The first found match is the leftmost one, thus the order of states
    // matters!
    // Do not add the start state in recursive calls of nfa_regmatch(),
    // because recursive calls should only start in the first position.
    // Unless "nfa_endp" is not NULL, then we match the end position.
    // Also don't start a match past the first line.
    if (!nfa_match
        && ((toplevel
             && rex.lnum == 0
             && clen != 0
             && (rex.reg_maxcol == 0
                 || (colnr_T)(rex.input - rex.line) < rex.reg_maxcol))
            || (nfa_endp != NULL
                && (REG_MULTI
                    ? (rex.lnum < nfa_endp->se_u.pos.lnum
                       || (rex.lnum == nfa_endp->se_u.pos.lnum
                           && (int)(rex.input - rex.line)
                           < nfa_endp->se_u.pos.col))
                    : rex.input < nfa_endp->se_u.ptr)))) {
#ifdef REGEXP_DEBUG
      fprintf(log_fd, "(---) STARTSTATE\n");
#endif
      // Inline optimized code for addstate() if we know the state is
      // the first MOPEN.
      if (toplevel) {
        int add = true;

        if (prog->regstart != NUL && clen != 0) {
          if (nextlist->n == 0) {
            colnr_T col = (colnr_T)(rex.input - rex.line) + clen;

            // Nextlist is empty, we can skip ahead to the
            // character that must appear at the start.
            if (skip_to_start(prog->regstart, &col) == FAIL) {
              break;
            }
#ifdef REGEXP_DEBUG
            fprintf(log_fd, "  Skipping ahead %d bytes to regstart\n",
                    col - ((colnr_T)(rex.input - rex.line) + clen));
#endif
            rex.input = rex.line + col - clen;
          } else {
            // Checking if the required start character matches is
            // cheaper than adding a state that won't match.
            const int c = utf_ptr2char((char *)rex.input + clen);
            if (c != prog->regstart
                && (!rex.reg_ic
                    || utf_fold(c) != utf_fold(prog->regstart))) {
#ifdef REGEXP_DEBUG
              fprintf(log_fd,
                      "  Skipping start state, regstart does not match\n");
#endif
              add = false;
            }
          }
        }

        if (add) {
          if (REG_MULTI) {
            m->norm.list.multi[0].start_col =
              (colnr_T)(rex.input - rex.line) + clen;
            m->norm.orig_start_col =
              m->norm.list.multi[0].start_col;
          } else {
            m->norm.list.line[0].start = rex.input + clen;
          }
          if (addstate(nextlist, start->out, m, NULL, clen) == NULL) {
            nfa_match = NFA_TOO_EXPENSIVE;
            goto theend;
          }
        }
      } else {
        if (addstate(nextlist, start, m, NULL, clen) == NULL) {
          nfa_match = NFA_TOO_EXPENSIVE;
          goto theend;
        }
      }
    }

#ifdef REGEXP_DEBUG
    fprintf(log_fd, ">>> Thislist had %d states available: ", thislist->n);
    {
      int i;

      for (i = 0; i < thislist->n; i++) {
        fprintf(log_fd, "%d  ", abs(thislist->t[i].state->id));
      }
    }
    fprintf(log_fd, "\n");
#endif

nextchar:
    // Advance to the next character, or advance to the next line, or
    // finish.
    if (clen != 0) {
      rex.input += clen;
    } else if (go_to_nextline || (nfa_endp != NULL && REG_MULTI
                                  && rex.lnum < nfa_endp->se_u.pos.lnum)) {
      reg_nextline();
    } else {
      break;
    }

    // Allow interrupting with CTRL-C.
    reg_breakcheck();
    if (got_int) {
      break;
    }
    // Check for timeout once every twenty times to avoid overhead.
    if (nfa_time_limit != NULL && ++nfa_time_count == 20) {
      nfa_time_count = 0;
      if (nfa_did_time_out()) {
        break;
      }
    }
  }

#ifdef REGEXP_DEBUG
  if (log_fd != stderr) {
    fclose(log_fd);
  }
  log_fd = NULL;
#endif

theend:
  // Free memory
  xfree(list[0].t);
  xfree(list[1].t);
  xfree(listids);
#undef ADD_STATE_IF_MATCH
#ifdef NFA_REGEXP_DEBUG_LOG
  fclose(debug);
#endif

  return nfa_match;
}

/// Try match of "prog" with at rex.line["col"].
///
/// @param tm         timeout limit or NULL
/// @param timed_out  flag set on timeout or NULL
///
/// @return  <= 0 for failure, number of lines contained in the match otherwise.
static int nfa_regtry(nfa_regprog_T *prog, colnr_T col, proftime_T *tm, int *timed_out)
{
  int i;
  regsubs_T subs, m;
  nfa_state_T *start = prog->start;
#ifdef REGEXP_DEBUG
  FILE *f;
#endif

  rex.input = rex.line + col;
  nfa_time_limit = tm;
  nfa_timed_out = timed_out;
  nfa_time_count = 0;

#ifdef REGEXP_DEBUG
  f = fopen(NFA_REGEXP_RUN_LOG, "a");
  if (f != NULL) {
    fprintf(f,
            "\n\n\t=======================================================\n");
# ifdef REGEXP_DEBUG
    fprintf(f, "\tRegexp is \"%s\"\n", nfa_regengine.expr);
# endif
    fprintf(f, "\tInput text is \"%s\" \n", rex.input);
    fprintf(f, "\t=======================================================\n\n");
    nfa_print_state(f, start);
    fprintf(f, "\n\n");
    fclose(f);
  } else {
    emsg("Could not open temporary log file for writing");
  }
#endif

  clear_sub(&subs.norm);
  clear_sub(&m.norm);
  clear_sub(&subs.synt);
  clear_sub(&m.synt);

  int result = nfa_regmatch(prog, start, &subs, &m);
  if (!result) {
    return 0;
  } else if (result == NFA_TOO_EXPENSIVE) {
    return result;
  }

  cleanup_subexpr();
  if (REG_MULTI) {
    for (i = 0; i < subs.norm.in_use; i++) {
      rex.reg_startpos[i].lnum = subs.norm.list.multi[i].start_lnum;
      rex.reg_startpos[i].col = subs.norm.list.multi[i].start_col;

      rex.reg_endpos[i].lnum = subs.norm.list.multi[i].end_lnum;
      rex.reg_endpos[i].col = subs.norm.list.multi[i].end_col;
    }
    if (rex.reg_mmatch != NULL) {
      rex.reg_mmatch->rmm_matchcol = subs.norm.orig_start_col;
    }

    if (rex.reg_startpos[0].lnum < 0) {
      rex.reg_startpos[0].lnum = 0;
      rex.reg_startpos[0].col = col;
    }
    if (rex.reg_endpos[0].lnum < 0) {
      // pattern has a \ze but it didn't match, use current end
      rex.reg_endpos[0].lnum = rex.lnum;
      rex.reg_endpos[0].col = (int)(rex.input - rex.line);
    } else {
      // Use line number of "\ze".
      rex.lnum = rex.reg_endpos[0].lnum;
    }
  } else {
    for (i = 0; i < subs.norm.in_use; i++) {
      rex.reg_startp[i] = subs.norm.list.line[i].start;
      rex.reg_endp[i] = subs.norm.list.line[i].end;
    }

    if (rex.reg_startp[0] == NULL) {
      rex.reg_startp[0] = rex.line + col;
    }
    if (rex.reg_endp[0] == NULL) {
      rex.reg_endp[0] = rex.input;
    }
  }

  // Package any found \z(...\) matches for export. Default is none.
  unref_extmatch(re_extmatch_out);
  re_extmatch_out = NULL;

  if (prog->reghasz == REX_SET) {
    cleanup_zsubexpr();
    re_extmatch_out = make_extmatch();
    // Loop over \z1, \z2, etc.  There is no \z0.
    for (i = 1; i < subs.synt.in_use; i++) {
      if (REG_MULTI) {
        struct multipos *mpos = &subs.synt.list.multi[i];

        // Only accept single line matches that are valid.
        if (mpos->start_lnum >= 0
            && mpos->start_lnum == mpos->end_lnum
            && mpos->end_col >= mpos->start_col) {
          re_extmatch_out->matches[i] =
            (uint8_t *)xstrnsave(reg_getline(mpos->start_lnum) + mpos->start_col,
                                 (size_t)(mpos->end_col - mpos->start_col));
        }
      } else {
        struct linepos *lpos = &subs.synt.list.line[i];

        if (lpos->start != NULL && lpos->end != NULL) {
          re_extmatch_out->matches[i] =
            (uint8_t *)xstrnsave((char *)lpos->start, (size_t)(lpos->end - lpos->start));
        }
      }
    }
  }

  return 1 + rex.lnum;
}

/// Match a regexp against a string ("line" points to the string) or multiple
/// lines (if "line" is NULL, use reg_getline()).
///
/// @param line String in which to search or NULL
/// @param startcol Column to start looking for match
/// @param tm Timeout limit or NULL
/// @param timed_out Flag set on timeout or NULL
///
/// @return <= 0 if there is no match and number of lines contained in the
/// match otherwise.
static int nfa_regexec_both(uint8_t *line, colnr_T startcol, proftime_T *tm, int *timed_out)
{
  nfa_regprog_T *prog;
  int retval = 0;
  colnr_T col = startcol;

  if (REG_MULTI) {
    prog = (nfa_regprog_T *)rex.reg_mmatch->regprog;
    line = (uint8_t *)reg_getline(0);  // relative to the cursor
    rex.reg_startpos = rex.reg_mmatch->startpos;
    rex.reg_endpos = rex.reg_mmatch->endpos;
  } else {
    prog = (nfa_regprog_T *)rex.reg_match->regprog;
    rex.reg_startp = (uint8_t **)rex.reg_match->startp;
    rex.reg_endp = (uint8_t **)rex.reg_match->endp;
  }

  // Be paranoid...
  if (prog == NULL || line == NULL) {
    iemsg(_(e_null));
    goto theend;
  }

  // If pattern contains "\c" or "\C": overrule value of rex.reg_ic
  if (prog->regflags & RF_ICASE) {
    rex.reg_ic = true;
  } else if (prog->regflags & RF_NOICASE) {
    rex.reg_ic = false;
  }

  // If pattern contains "\Z" overrule value of rex.reg_icombine
  if (prog->regflags & RF_ICOMBINE) {
    rex.reg_icombine = true;
  }

  rex.line = line;
  rex.lnum = 0;  // relative to line

  rex.nfa_has_zend = prog->has_zend;
  rex.nfa_has_backref = prog->has_backref;
  rex.nfa_nsubexpr = prog->nsubexp;
  rex.nfa_listid = 1;
  rex.nfa_alt_listid = 2;
#ifdef REGEXP_DEBUG
  nfa_regengine.expr = prog->pattern;
#endif

  if (prog->reganch && col > 0) {
    return 0L;
  }

  rex.need_clear_subexpr = true;
  // Clear the external match subpointers if necessary.
  if (prog->reghasz == REX_SET) {
    rex.nfa_has_zsubexpr = true;
    rex.need_clear_zsubexpr = true;
  } else {
    rex.nfa_has_zsubexpr = false;
    rex.need_clear_zsubexpr = false;
  }

  if (prog->regstart != NUL) {
    // Skip ahead until a character we know the match must start with.
    // When there is none there is no match.
    if (skip_to_start(prog->regstart, &col) == FAIL) {
      return 0L;
    }

    // If match_text is set it contains the full text that must match.
    // Nothing else to try. Doesn't handle combining chars well.
    if (prog->match_text != NULL && *prog->match_text != NUL && !rex.reg_icombine) {
      retval = find_match_text(&col, prog->regstart, prog->match_text);
      if (REG_MULTI) {
        rex.reg_mmatch->rmm_matchcol = col;
      } else {
        rex.reg_match->rm_matchcol = col;
      }
      return retval;
    }
  }

  // If the start column is past the maximum column: no need to try.
  if (rex.reg_maxcol > 0 && col >= rex.reg_maxcol) {
    goto theend;
  }

  // Set the "nstate" used by nfa_regcomp() to zero to trigger an error when
  // it's accidentally used during execution.
  nstate = 0;
  for (int i = 0; i < prog->nstate; i++) {
    prog->state[i].id = i;
    prog->state[i].lastlist[0] = 0;
    prog->state[i].lastlist[1] = 0;
  }

  retval = nfa_regtry(prog, col, tm, timed_out);

#ifdef REGEXP_DEBUG
  nfa_regengine.expr = NULL;
#endif

theend:
  if (retval > 0) {
    // Make sure the end is never before the start.  Can happen when \zs and
    // \ze are used.
    if (REG_MULTI) {
      const lpos_T *const start = &rex.reg_mmatch->startpos[0];
      const lpos_T *const end = &rex.reg_mmatch->endpos[0];

      if (end->lnum < start->lnum
          || (end->lnum == start->lnum && end->col < start->col)) {
        rex.reg_mmatch->endpos[0] = rex.reg_mmatch->startpos[0];
      }
    } else {
      if (rex.reg_match->endp[0] < rex.reg_match->startp[0]) {
        rex.reg_match->endp[0] = rex.reg_match->startp[0];
      }

      // startpos[0] may be set by "\zs", also return the column where
      // the whole pattern matched.
      rex.reg_match->rm_matchcol = col;
    }
  }

  return retval;
}

// Compile a regular expression into internal code for the NFA matcher.
// Returns the program in allocated space.  Returns NULL for an error.
static regprog_T *nfa_regcomp(uint8_t *expr, int re_flags)
{
  nfa_regprog_T *prog = NULL;
  int *postfix;

  if (expr == NULL) {
    return NULL;
  }

#ifdef REGEXP_DEBUG
  nfa_regengine.expr = expr;
#endif
  nfa_re_flags = re_flags;

  init_class_tab();

  nfa_regcomp_start(expr, re_flags);

  // Build postfix form of the regexp. Needed to build the NFA
  // (and count its size).
  postfix = re2post();
  if (postfix == NULL) {
    goto fail;              // Cascaded (syntax?) error
  }

  // In order to build the NFA, we parse the input regexp twice:
  // 1. first pass to count size (so we can allocate space)
  // 2. second to emit code
#ifdef REGEXP_DEBUG
  {
    FILE *f = fopen(NFA_REGEXP_RUN_LOG, "a");

    if (f != NULL) {
      fprintf(f,
              "\n*****************************\n\n\n\n\t"
              "Compiling regexp \"%s\"... hold on !\n",
              expr);
      fclose(f);
    }
  }
#endif

  // PASS 1
  // Count number of NFA states in "nstate". Do not build the NFA.
  post2nfa(postfix, post_ptr, true);

  // allocate the regprog with space for the compiled regexp
  size_t prog_size = offsetof(nfa_regprog_T, state) + sizeof(nfa_state_T) * (size_t)nstate;
  prog = xmalloc(prog_size);
  state_ptr = prog->state;
  prog->re_in_use = false;

  // PASS 2
  // Build the NFA
  prog->start = post2nfa(postfix, post_ptr, false);
  if (prog->start == NULL) {
    goto fail;
  }
  prog->regflags = regflags;
  prog->engine = &nfa_regengine;
  prog->nstate = nstate;
  prog->has_zend = rex.nfa_has_zend;
  prog->has_backref = rex.nfa_has_backref;
  prog->nsubexp = regnpar;

  nfa_postprocess(prog);

  prog->reganch = nfa_get_reganch(prog->start, 0);
  prog->regstart = nfa_get_regstart(prog->start, 0);
  prog->match_text = nfa_get_match_text(prog->start);

#ifdef REGEXP_DEBUG
  nfa_postfix_dump(expr, OK);
  nfa_dump(prog);
#endif
  // Remember whether this pattern has any \z specials in it.
  prog->reghasz = re_has_z;
  prog->pattern = xstrdup((char *)expr);
#ifdef REGEXP_DEBUG
  nfa_regengine.expr = NULL;
#endif

out:
  xfree(post_start);
  post_start = post_ptr = post_end = NULL;
  state_ptr = NULL;
  return (regprog_T *)prog;

fail:
  XFREE_CLEAR(prog);
#ifdef REGEXP_DEBUG
  nfa_postfix_dump(expr, FAIL);
  nfa_regengine.expr = NULL;
#endif
  goto out;
}

// Free a compiled regexp program, returned by nfa_regcomp().
static void nfa_regfree(regprog_T *prog)
{
  if (prog == NULL) {
    return;
  }

  xfree(((nfa_regprog_T *)prog)->match_text);
  xfree(((nfa_regprog_T *)prog)->pattern);
  xfree(prog);
}

/// Match a regexp against a string.
/// "rmp->regprog" is a compiled regexp as returned by nfa_regcomp().
/// Uses curbuf for line count and 'iskeyword'.
/// If "line_lbr" is true, consider a "\n" in "line" to be a line break.
///
/// @param line  string to match against
/// @param col   column to start looking for match
///
/// @return  <= 0 for failure, number of lines contained in the match otherwise.
static int nfa_regexec_nl(regmatch_T *rmp, uint8_t *line, colnr_T col, bool line_lbr)
{
  rex.reg_match = rmp;
  rex.reg_mmatch = NULL;
  rex.reg_maxline = 0;
  rex.reg_line_lbr = line_lbr;
  rex.reg_buf = curbuf;
  rex.reg_win = NULL;
  rex.reg_ic = rmp->rm_ic;
  rex.reg_icombine = false;
  rex.reg_nobreak = rmp->regprog->re_flags & RE_NOBREAK;
  rex.reg_maxcol = 0;
  return nfa_regexec_both(line, col, NULL, NULL);
}

/// Matches a regexp against multiple lines.
/// "rmp->regprog" is a compiled regexp as returned by vim_regcomp().
/// Uses curbuf for line count and 'iskeyword'.
///
/// @param win Window in which to search or NULL
/// @param buf Buffer in which to search
/// @param lnum Number of line to start looking for match
/// @param col Column to start looking for match
/// @param tm Timeout limit or NULL
/// @param timed_out Flag set on timeout or NULL
///
/// @return <= 0 if there is no match and number of lines contained in the match
/// otherwise.
///
/// @note The body is the same as bt_regexec() except for nfa_regexec_both()
///
/// @warning
/// Match may actually be in another line. e.g.:
/// when r.e. is \nc, cursor is at 'a' and the text buffer looks like
///
/// @par
///
///     +-------------------------+
///     |a                        |
///     |b                        |
///     |c                        |
///     |                         |
///     +-------------------------+
///
/// @par
/// then nfa_regexec_multi() returns 3. while the original vim_regexec_multi()
/// returns 0 and a second call at line 2 will return 2.
///
/// @par
/// FIXME if this behavior is not compatible.
static int nfa_regexec_multi(regmmatch_T *rmp, win_T *win, buf_T *buf, linenr_T lnum, colnr_T col,
                             proftime_T *tm, int *timed_out)
{
  init_regexec_multi(rmp, win, buf, lnum);
  return nfa_regexec_both(NULL, col, tm, timed_out);
}
// }}}1

static regengine_T bt_regengine = {
  bt_regcomp,
  bt_regfree,
  bt_regexec_nl,
  bt_regexec_multi,
#ifdef REGEXP_DEBUG
  "",
#endif
};

static regengine_T nfa_regengine = {
  nfa_regcomp,
  nfa_regfree,
  nfa_regexec_nl,
  nfa_regexec_multi,
#ifdef REGEXP_DEBUG
  "",
#endif
};

// Which regexp engine to use? Needed for vim_regcomp().
// Must match with 'regexpengine'.
static int regexp_engine = 0;

#ifdef REGEXP_DEBUG
static uint8_t regname[][30] = {
  "AUTOMATIC Regexp Engine",
  "BACKTRACKING Regexp Engine",
  "NFA Regexp Engine"
};
#endif

// Compile a regular expression into internal code.
// Returns the program in allocated memory.
// Use vim_regfree() to free the memory.
// Returns NULL for an error.
regprog_T *vim_regcomp(const char *expr_arg, int re_flags)
{
  regprog_T *prog = NULL;
  const char *expr = expr_arg;

  regexp_engine = (int)p_re;

  // Check for prefix "\%#=", that sets the regexp engine
  if (strncmp(expr, "\\%#=", 4) == 0) {
    int newengine = expr[4] - '0';

    if (newengine == AUTOMATIC_ENGINE
        || newengine == BACKTRACKING_ENGINE
        || newengine == NFA_ENGINE) {
      regexp_engine = expr[4] - '0';
      expr += 5;
#ifdef REGEXP_DEBUG
      smsg(0, "New regexp mode selected (%d): %s",
           regexp_engine,
           regname[newengine]);
#endif
    } else {
      emsg(_("E864: \\%#= can only be followed by 0, 1, or 2. The automatic engine will be used "));
      regexp_engine = AUTOMATIC_ENGINE;
    }
  }
#ifdef REGEXP_DEBUG
  bt_regengine.expr = expr;
  nfa_regengine.expr = expr;
#endif
  // reg_iswordc() uses rex.reg_buf
  rex.reg_buf = curbuf;

  //
  // First try the NFA engine, unless backtracking was requested.
  //
  const int called_emsg_before = called_emsg;
  if (regexp_engine != BACKTRACKING_ENGINE) {
    prog = nfa_regengine.regcomp((uint8_t *)expr,
                                 re_flags + (regexp_engine == AUTOMATIC_ENGINE ? RE_AUTO : 0));
  } else {
    prog = bt_regengine.regcomp((uint8_t *)expr, re_flags);
  }

  // Check for error compiling regexp with initial engine.
  if (prog == NULL) {
#ifdef BT_REGEXP_DEBUG_LOG
    // Debugging log for BT engine.
    if (regexp_engine != BACKTRACKING_ENGINE) {
      FILE *f = fopen(BT_REGEXP_DEBUG_LOG_NAME, "a");
      if (f) {
        fprintf(f, "Syntax error in \"%s\"\n", expr);
        fclose(f);
      } else {
        semsg("(NFA) Could not open \"%s\" to write !!!",
              BT_REGEXP_DEBUG_LOG_NAME);
      }
    }
#endif
    // If the NFA engine failed, try the backtracking engine. The NFA engine
    // also fails for patterns that it can't handle well but are still valid
    // patterns, thus a retry should work.
    // But don't try if an error message was given.
    if (regexp_engine == AUTOMATIC_ENGINE && called_emsg == called_emsg_before) {
      regexp_engine = BACKTRACKING_ENGINE;
      report_re_switch(expr);
      prog = bt_regengine.regcomp((uint8_t *)expr, re_flags);
    }
  }

  if (prog != NULL) {
    // Store the info needed to call regcomp() again when the engine turns out
    // to be very slow when executing it.
    prog->re_engine = (unsigned)regexp_engine;
    prog->re_flags = (unsigned)re_flags;
  }

  return prog;
}

// Free a compiled regexp program, returned by vim_regcomp().
void vim_regfree(regprog_T *prog)
{
  if (prog != NULL) {
    prog->engine->regfree(prog);
  }
}

#if defined(EXITFREE)
void free_regexp_stuff(void)
{
  ga_clear(&regstack);
  ga_clear(&backpos);
  xfree(reg_tofree);
  xfree(reg_prev_sub);
}

#endif

static void report_re_switch(const char *pat)
{
  if (p_verbose > 0) {
    verbose_enter();
    msg_puts(_("Switching to backtracking RE engine for pattern: "));
    msg_puts(pat);
    verbose_leave();
  }
}

/// Match a regexp against a string.
/// "rmp->regprog" must be a compiled regexp as returned by vim_regcomp().
/// Note: "rmp->regprog" may be freed and changed.
/// Uses curbuf for line count and 'iskeyword'.
/// When "nl" is true consider a "\n" in "line" to be a line break.
///
/// @param rmp
/// @param line the string to match against
/// @param col  the column to start looking for match
/// @param nl
///
/// @return true if there is a match, false if not.
static bool vim_regexec_string(regmatch_T *rmp, const char *line, colnr_T col, bool nl)
{
  regexec_T rex_save;
  bool rex_in_use_save = rex_in_use;

  // Cannot use the same prog recursively, it contains state.
  if (rmp->regprog->re_in_use) {
    emsg(_(e_recursive));
    return false;
  }
  rmp->regprog->re_in_use = true;

  if (rex_in_use) {
    // Being called recursively, save the state.
    rex_save = rex;
  }
  rex_in_use = true;

  rex.reg_startp = NULL;
  rex.reg_endp = NULL;
  rex.reg_startpos = NULL;
  rex.reg_endpos = NULL;

  int result = rmp->regprog->engine->regexec_nl(rmp, (uint8_t *)line, col, nl);
  rmp->regprog->re_in_use = false;

  // NFA engine aborted because it's very slow, use backtracking engine instead.
  if (rmp->regprog->re_engine == AUTOMATIC_ENGINE
      && result == NFA_TOO_EXPENSIVE) {
    int save_p_re = (int)p_re;
    int re_flags = (int)rmp->regprog->re_flags;
    char *pat = xstrdup(((nfa_regprog_T *)rmp->regprog)->pattern);

    p_re = BACKTRACKING_ENGINE;
    vim_regfree(rmp->regprog);
    report_re_switch(pat);
    rmp->regprog = vim_regcomp(pat, re_flags);
    if (rmp->regprog != NULL) {
      rmp->regprog->re_in_use = true;
      result = rmp->regprog->engine->regexec_nl(rmp, (uint8_t *)line, col, nl);
      rmp->regprog->re_in_use = false;
    }

    xfree(pat);
    p_re = save_p_re;
  }

  rex_in_use = rex_in_use_save;
  if (rex_in_use) {
    rex = rex_save;
  }

  return result > 0;
}

// Note: "*prog" may be freed and changed.
// Return true if there is a match, false if not.
bool vim_regexec_prog(regprog_T **prog, bool ignore_case, const char *line, colnr_T col)
{
  regmatch_T regmatch = { .regprog = *prog, .rm_ic = ignore_case };
  bool r = vim_regexec_string(&regmatch, line, col, false);
  *prog = regmatch.regprog;
  return r;
}

// Note: "rmp->regprog" may be freed and changed.
// Return true if there is a match, false if not.
bool vim_regexec(regmatch_T *rmp, const char *line, colnr_T col)
{
  return vim_regexec_string(rmp, line, col, false);
}

// Like vim_regexec(), but consider a "\n" in "line" to be a line break.
// Note: "rmp->regprog" may be freed and changed.
// Return true if there is a match, false if not.
bool vim_regexec_nl(regmatch_T *rmp, const char *line, colnr_T col)
{
  return vim_regexec_string(rmp, line, col, true);
}

/// Match a regexp against multiple lines.
/// "rmp->regprog" must be a compiled regexp as returned by vim_regcomp().
/// Note: "rmp->regprog" may be freed and changed, even set to NULL.
/// Uses curbuf for line count and 'iskeyword'.
///
/// @param win        window in which to search or NULL
/// @param buf        buffer in which to search
/// @param lnum       nr of line to start looking for match
/// @param col        column to start looking for match
/// @param tm         timeout limit or NULL
/// @param timed_out  flag is set when timeout limit reached
///
/// @return  zero if there is no match.  Return number of lines contained in the
///          match otherwise.
int vim_regexec_multi(regmmatch_T *rmp, win_T *win, buf_T *buf, linenr_T lnum, colnr_T col,
                      proftime_T *tm, int *timed_out)
  FUNC_ATTR_NONNULL_ARG(1)
{
  regexec_T rex_save;
  bool rex_in_use_save = rex_in_use;

  // Cannot use the same prog recursively, it contains state.
  if (rmp->regprog->re_in_use) {
    emsg(_(e_recursive));
    return false;
  }
  rmp->regprog->re_in_use = true;

  if (rex_in_use) {
    // Being called recursively, save the state.
    rex_save = rex;
  }
  rex_in_use = true;

  int result = rmp->regprog->engine->regexec_multi(rmp, win, buf, lnum, col, tm, timed_out);
  rmp->regprog->re_in_use = false;

  // NFA engine aborted because it's very slow, use backtracking engine instead.
  if (rmp->regprog->re_engine == AUTOMATIC_ENGINE
      && result == NFA_TOO_EXPENSIVE) {
    int save_p_re = (int)p_re;
    int re_flags = (int)rmp->regprog->re_flags;
    char *pat = xstrdup(((nfa_regprog_T *)rmp->regprog)->pattern);

    p_re = BACKTRACKING_ENGINE;
    regprog_T *prev_prog = rmp->regprog;

    report_re_switch(pat);
    // checking for \z misuse was already done when compiling for NFA,
    // allow all here
    reg_do_extmatch = REX_ALL;
    rmp->regprog = vim_regcomp(pat, re_flags);
    reg_do_extmatch = 0;

    if (rmp->regprog == NULL) {
      // Somehow compiling the pattern failed now, put back the
      // previous one to avoid "regprog" becoming NULL.
      rmp->regprog = prev_prog;
    } else {
      vim_regfree(prev_prog);

      rmp->regprog->re_in_use = true;
      result = rmp->regprog->engine->regexec_multi(rmp, win, buf, lnum, col, tm, timed_out);
      rmp->regprog->re_in_use = false;
    }

    xfree(pat);
    p_re = save_p_re;
  }

  rex_in_use = rex_in_use_save;
  if (rex_in_use) {
    rex = rex_save;
  }

  return result <= 0 ? 0 : result;
}
