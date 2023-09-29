// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// NFA regular expression implementation.
//
// This file is included in "regexp.c".

#include <assert.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>

#include "nvim/ascii.h"
#include "nvim/garray.h"
#include "nvim/os/input.h"

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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "regexp_nfa.c.generated.h"
#endif

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
static int nfa_recognize_char_class(uint8_t *start, uint8_t *end, int extra_newl)
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
      EMIT2('A') EMIT2(A_grave) EMIT2(A_acute)  // NOLINT(whitespace/cast)
      EMIT2(A_circumflex) EMIT2(A_virguilla)    // NOLINT(whitespace/cast)
      EMIT2(A_diaeresis) EMIT2(A_ring)          // NOLINT(whitespace/cast)
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
      EMIT2('E') EMIT2(E_grave) EMIT2(E_acute)  // NOLINT(whitespace/cast)
      EMIT2(E_circumflex) EMIT2(E_diaeresis)    // NOLINT(whitespace/cast)
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
      EMIT2('I') EMIT2(I_grave) EMIT2(I_acute)  // NOLINT(whitespace/cast)
      EMIT2(I_circumflex) EMIT2(I_diaeresis)    // NOLINT(whitespace/cast)
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
      EMIT2('O') EMIT2(O_grave) EMIT2(O_acute)  // NOLINT(whitespace/cast)
      EMIT2(O_circumflex) EMIT2(O_virguilla)    // NOLINT(whitespace/cast)
      EMIT2(O_diaeresis) EMIT2(O_slash)         // NOLINT(whitespace/cast)
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
      EMIT2('U') EMIT2(U_grave) EMIT2(U_acute)  // NOLINT(whitespace/cast)
      EMIT2(U_diaeresis) EMIT2(U_circumflex)    // NOLINT(whitespace/cast)
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
      EMIT2('a') EMIT2(a_grave) EMIT2(a_acute)  // NOLINT(whitespace/cast)
      EMIT2(a_circumflex) EMIT2(a_virguilla)    // NOLINT(whitespace/cast)
      EMIT2(a_diaeresis) EMIT2(a_ring)          // NOLINT(whitespace/cast)
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
      EMIT2('e') EMIT2(e_grave) EMIT2(e_acute)  // NOLINT(whitespace/cast)
      EMIT2(e_circumflex) EMIT2(e_diaeresis)    // NOLINT(whitespace/cast)
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
      EMIT2('i') EMIT2(i_grave) EMIT2(i_acute)  // NOLINT(whitespace/cast)
      EMIT2(i_circumflex) EMIT2(i_diaeresis)    // NOLINT(whitespace/cast)
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
      EMIT2('o') EMIT2(o_grave) EMIT2(o_acute)  // NOLINT(whitespace/cast)
      EMIT2(o_circumflex) EMIT2(o_virguilla)    // NOLINT(whitespace/cast)
      EMIT2(o_diaeresis) EMIT2(o_slash)         // NOLINT(whitespace/cast)
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
      EMIT2('u') EMIT2(u_grave) EMIT2(u_acute)  // NOLINT(whitespace/cast)
      EMIT2(u_circumflex) EMIT2(u_diaeresis)    // NOLINT(whitespace/cast)
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
      EMIT2('y') EMIT2(y_acute) EMIT2(y_diaeresis)  // NOLINT(whitespace/cast)
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
    semsg(_(e_misplaced), (char)no_Magic(c));  // -V1037
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
    for (lp = (uint8_t *)reg_prev_sub; *lp != NUL; MB_CPTR_ADV(lp)) {
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
          EMIT(cmp == '<' ? NFA_LNUM_LT :
               cmp == '>' ? NFA_LNUM_GT : NFA_LNUM);
          if (save_prev_at_start) {
            at_start = true;
          }
        } else if (c == 'c') {
          if (cur) {
            n = curwin->w_cursor.col;
            n++;
          }
          // \%{n}c  \%{n}<c  \%{n}>c
          EMIT(cmp == '<' ? NFA_COL_LT :
               cmp == '>' ? NFA_COL_GT : NFA_COL);
        } else {
          if (cur) {
            colnr_T vcol = 0;
            getvvcol(curwin, &curwin->w_cursor, NULL, NULL, &vcol);
            n = ++vcol;
          }
          // \%{n}v  \%{n}<v  \%{n}>v
          EMIT(cmp == '<' ? NFA_VCOL_LT :
               cmp == '>' ? NFA_VCOL_GT : NFA_VCOL);
          limit = INT32_MAX / MB_MAXBYTES;
        }
        if (n >= limit) {
          emsg(_(e_value_too_large));
          return FAIL;
        }
        EMIT((int)n);
        break;
      } else if (c == '\'' && n == 0) {
        // \%'m  \%<'m  \%>'m
        EMIT(cmp == '<' ? NFA_MARK_LT :
             cmp == '>' ? NFA_MARK_GT : NFA_MARK);
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
          startc = utf_ptr2char((char *)regparse);
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
            } else {
              EMIT(startc);
            }
            EMIT(NFA_CONCAT);
          }
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
      // where 'b' and 'c' are chars with codes > 256. */
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
    STRCAT(code, " + NEWLINE ");
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
  ga_append(&indent, '\0');
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

  s->c    = c;
  s->out  = out;
  s->out1 = out1;
  s->val  = 0;

  s->id   = istate;
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
        s1->out= skip;
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

      if ((long)(newsize >> 10) >= p_mmp) {
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
    } else if (state->c >= NFA_ZOPEN && state->c <= NFA_ZOPEN9) {  // -V560
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
    if (state->c >= NFA_ZOPEN && state->c <= NFA_ZOPEN9) {  // -V560
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
    } else if (state->c >= NFA_ZCLOSE && state->c <= NFA_ZCLOSE9) {  // -V560
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
    if (state->c >= NFA_ZCLOSE && state->c <= NFA_ZCLOSE9) {  // -V560
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

      if ((long)(newsize >> 10) >= p_mmp) {
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
static void nfa_restore_listids(nfa_regprog_T *prog, int *list)
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
          rex.input = rex.line + strlen((char *)rex.line);
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
#define PTR2LEN(x) utf_ptr2len(x)

  colnr_T col = *startcol;
  int regstart_len = PTR2LEN((char *)rex.line + col);

  while (true) {
    bool match = true;
    uint8_t *s1 = match_text;
    uint8_t *s2 = rex.line + col + regstart_len;  // skip regstart
    while (*s1) {
      int c1_len = PTR2LEN((char *)s1);
      int c1 = utf_ptr2char((char *)s1);
      int c2_len = PTR2LEN((char *)s2);
      int c2 = utf_ptr2char((char *)s2);

      if ((c1 != c2 && (!rex.reg_ic || utf_fold(c1) != utf_fold(c2)))
          || c1_len != c2_len) {
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

#undef PTR2LEN
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
                  "> Not trying to match pattern, output state %d is already in list %d. char %d: %s\n",  // NOLINT(whitespace/line_length)
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
        // Any char except '\0', (end of input) does not match.
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
                                    (uintmax_t)(rex.lnum + rex.reg_firstlnum)));
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
          long ts = (long)wp->w_buffer->b_p_ts;

          // Guess that a character won't use more columns than 'tabstop',
          // with a minimum of 4.
          if (ts < 4) {
            ts = 4;
          }
          result = col > t->state->val * ts;
        }
        if (!result) {
          uintmax_t lts = win_linetabsize(wp, rex.reg_firstlnum + rex.lnum, (char *)rex.line, col);
          assert(t->state->val >= 0);
          result = nfa_re_num_cmp((uintmax_t)t->state->val, op, lts + 1);
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
            ? (colnr_T)strlen((char *)reg_getline(pos->lnum - rex.reg_firstlnum))
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
            (uint8_t *)xstrnsave((char *)reg_getline(mpos->start_lnum) + mpos->start_col,
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
    line = (uint8_t *)reg_getline((linenr_T)0);  // relative to the cursor
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
    if (prog->match_text != NULL && !rex.reg_icombine) {
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
  return (int)nfa_regexec_both(line, col, NULL, NULL);
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
