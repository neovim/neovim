// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/*
 * NFA regular expression implementation.
 *
 * This file is included in "regexp.c".
 */

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
#include <limits.h>

#include "nvim/ascii.h"
#include "nvim/garray.h"

/*
 * Logging of NFA engine.
 *
 * The NFA engine can write four log files:
 * - Error log: Contains NFA engine's fatal errors.
 * - Dump log: Contains compiled NFA state machine's information.
 * - Run log: Contains information of matching procedure.
 * - Debug log: Contains detailed information of matching procedure. Can be
 *   disabled by undefining NFA_REGEXP_DEBUG_LOG.
 * The first one can also be used without debug mode.
 * The last three are enabled when compiled as debug mode and individually
 * disabled by commenting them out.
 * The log files can get quite big!
 * Do disable all of this when compiling Vim for debugging, undefine REGEXP_DEBUG in
 * regexp.c
 */
#ifdef REGEXP_DEBUG
# define NFA_REGEXP_ERROR_LOG   "nfa_regexp_error.log"
# define NFA_REGEXP_DUMP_LOG    "nfa_regexp_dump.log"
# define NFA_REGEXP_RUN_LOG     "nfa_regexp_run.log"
# define NFA_REGEXP_DEBUG_LOG   "nfa_regexp_debug.log"
#endif

/* Added to NFA_ANY - NFA_NUPPER_IC to include a NL. */
#define NFA_ADD_NL              31

enum {
  NFA_SPLIT = -1024,
  NFA_MATCH,
  NFA_EMPTY,                        /* matches 0-length */

  NFA_START_COLL,                   /* [abc] start */
  NFA_END_COLL,                     /* [abc] end */
  NFA_START_NEG_COLL,               /* [^abc] start */
  NFA_END_NEG_COLL,                 /* [^abc] end (postfix only) */
  NFA_RANGE,                        /* range of the two previous items
                                     * (postfix only) */
  NFA_RANGE_MIN,                    /* low end of a range  */
  NFA_RANGE_MAX,                    /* high end of a range  */

  NFA_CONCAT,                       // concatenate two previous items (postfix
                                    // only)
  NFA_OR,                           // \| (postfix only)
  NFA_STAR,                         // greedy * (postfix only)
  NFA_STAR_NONGREEDY,               // non-greedy * (postfix only)
  NFA_QUEST,                        // greedy \? (postfix only)
  NFA_QUEST_NONGREEDY,              // non-greedy \? (postfix only)

  NFA_BOL,                          /* ^    Begin line */
  NFA_EOL,                          /* $    End line */
  NFA_BOW,                          /* \<   Begin word */
  NFA_EOW,                          /* \>   End word */
  NFA_BOF,                          /* \%^  Begin file */
  NFA_EOF,                          /* \%$  End file */
  NFA_NEWL,
  NFA_ZSTART,                       /* Used for \zs */
  NFA_ZEND,                         /* Used for \ze */
  NFA_NOPEN,                        /* Start of subexpression marked with \%( */
  NFA_NCLOSE,                       /* End of subexpr. marked with \%( ... \) */
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
  NFA_COMPOSING,                    /* Next nodes in NFA are part of the
                                       composing multibyte char */
  NFA_END_COMPOSING,                /* End of a composing char in the NFA */
  NFA_ANY_COMPOSING,                // \%C: Any composing characters.
  NFA_OPT_CHARS,                    /* \%[abc] */

  /* The following are used only in the postfix form, not in the NFA */
  NFA_PREV_ATOM_NO_WIDTH,           /* Used for \@= */
  NFA_PREV_ATOM_NO_WIDTH_NEG,       /* Used for \@! */
  NFA_PREV_ATOM_JUST_BEFORE,        /* Used for \@<= */
  NFA_PREV_ATOM_JUST_BEFORE_NEG,    /* Used for \@<! */
  NFA_PREV_ATOM_LIKE_PATTERN,       /* Used for \@> */

  NFA_BACKREF1,                     /* \1 */
  NFA_BACKREF2,                     /* \2 */
  NFA_BACKREF3,                     /* \3 */
  NFA_BACKREF4,                     /* \4 */
  NFA_BACKREF5,                     /* \5 */
  NFA_BACKREF6,                     /* \6 */
  NFA_BACKREF7,                     /* \7 */
  NFA_BACKREF8,                     /* \8 */
  NFA_BACKREF9,                     /* \9 */
  NFA_ZREF1,                        /* \z1 */
  NFA_ZREF2,                        /* \z2 */
  NFA_ZREF3,                        /* \z3 */
  NFA_ZREF4,                        /* \z4 */
  NFA_ZREF5,                        /* \z5 */
  NFA_ZREF6,                        /* \z6 */
  NFA_ZREF7,                        /* \z7 */
  NFA_ZREF8,                        /* \z8 */
  NFA_ZREF9,                        /* \z9 */
  NFA_SKIP,                         /* Skip characters */

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

  /* NFA_FIRST_NL */
  NFA_ANY,              /*	Match any one character. */
  NFA_IDENT,            /*	Match identifier char */
  NFA_SIDENT,           /*	Match identifier char but no digit */
  NFA_KWORD,            /*	Match keyword char */
  NFA_SKWORD,           /*	Match word char but no digit */
  NFA_FNAME,            /*	Match file name char */
  NFA_SFNAME,           /*	Match file name char but no digit */
  NFA_PRINT,            /*	Match printable char */
  NFA_SPRINT,           /*	Match printable char but no digit */
  NFA_WHITE,            /*	Match whitespace char */
  NFA_NWHITE,           /*	Match non-whitespace char */
  NFA_DIGIT,            /*	Match digit char */
  NFA_NDIGIT,           /*	Match non-digit char */
  NFA_HEX,              /*	Match hex char */
  NFA_NHEX,             /*	Match non-hex char */
  NFA_OCTAL,            /*	Match octal char */
  NFA_NOCTAL,           /*	Match non-octal char */
  NFA_WORD,             /*	Match word char */
  NFA_NWORD,            /*	Match non-word char */
  NFA_HEAD,             /*	Match head char */
  NFA_NHEAD,            /*	Match non-head char */
  NFA_ALPHA,            /*	Match alpha char */
  NFA_NALPHA,           /*	Match non-alpha char */
  NFA_LOWER,            /*	Match lowercase char */
  NFA_NLOWER,           /*	Match non-lowercase char */
  NFA_UPPER,            /*	Match uppercase char */
  NFA_NUPPER,           /*	Match non-uppercase char */
  NFA_LOWER_IC,         /*	Match [a-z] */
  NFA_NLOWER_IC,        /*	Match [^a-z] */
  NFA_UPPER_IC,         /*	Match [A-Z] */
  NFA_NUPPER_IC,        /*	Match [^A-Z] */

  NFA_FIRST_NL = NFA_ANY + NFA_ADD_NL,
  NFA_LAST_NL = NFA_NUPPER_IC + NFA_ADD_NL,

  NFA_CURSOR,           /*	Match cursor pos */
  NFA_LNUM,             /*	Match line number */
  NFA_LNUM_GT,          /*	Match > line number */
  NFA_LNUM_LT,          /*	Match < line number */
  NFA_COL,              /*	Match cursor column */
  NFA_COL_GT,           /*	Match > cursor column */
  NFA_COL_LT,           /*	Match < cursor column */
  NFA_VCOL,             /*	Match cursor virtual column */
  NFA_VCOL_GT,          /*	Match > cursor virtual column */
  NFA_VCOL_LT,          /*	Match < cursor virtual column */
  NFA_MARK,             /*	Match mark */
  NFA_MARK_GT,          /*	Match > mark */
  NFA_MARK_LT,          /*	Match < mark */
  NFA_VISUAL,           /*	Match Visual area */

  /* Character classes [:alnum:] etc */
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
  NFA_CLASS_ESCAPE
};

/* Keep in sync with classchars. */
static int nfa_classcodes[] = {
  NFA_ANY, NFA_IDENT, NFA_SIDENT, NFA_KWORD,NFA_SKWORD,
  NFA_FNAME, NFA_SFNAME, NFA_PRINT, NFA_SPRINT,
  NFA_WHITE, NFA_NWHITE, NFA_DIGIT, NFA_NDIGIT,
  NFA_HEX, NFA_NHEX, NFA_OCTAL, NFA_NOCTAL,
  NFA_WORD, NFA_NWORD, NFA_HEAD, NFA_NHEAD,
  NFA_ALPHA, NFA_NALPHA, NFA_LOWER, NFA_NLOWER,
  NFA_UPPER, NFA_NUPPER
};

static char_u e_nul_found[] = N_(
    "E865: (NFA) Regexp end encountered prematurely");
static char_u e_misplaced[] = N_("E866: (NFA regexp) Misplaced %c");
static char_u e_ill_char_class[] = N_(
    "E877: (NFA regexp) Invalid character class: %" PRId64);

/* Since the out pointers in the list are always
 * uninitialized, we use the pointers themselves
 * as storage for the Ptrlists. */
typedef union Ptrlist Ptrlist;
union Ptrlist {
  Ptrlist     *next;
  nfa_state_T *s;
};

struct Frag {
  nfa_state_T *start;
  Ptrlist     *out;
};
typedef struct Frag Frag_T;

typedef struct {
  int in_use;       /* number of subexpr with useful info */

  /* When REG_MULTI is TRUE list.multi is used, otherwise list.line. */
  union {
    struct multipos {
      linenr_T  start_lnum;
      linenr_T  end_lnum;
      colnr_T start_col;
      colnr_T end_col;
    } multi[NSUBEXP];
    struct linepos {
      char_u      *start;
      char_u      *end;
    } line[NSUBEXP];
  } list;
} regsub_T;

typedef struct {
  regsub_T norm;      /* \( .. \) matches */
  regsub_T synt;      /* \z( .. \) matches */
} regsubs_T;

/* nfa_pim_T stores a Postponed Invisible Match. */
typedef struct nfa_pim_S nfa_pim_T;
struct nfa_pim_S {
  int result;                   /* NFA_PIM_*, see below */
  nfa_state_T *state;           /* the invisible match start state */
  regsubs_T subs;               /* submatch info, only party used */
  union {
    lpos_T pos;
    char_u  *ptr;
  } end;                        /* where the match must end */
};

/* nfa_thread_T contains execution information of a NFA state */
typedef struct {
  nfa_state_T *state;
  int count;
  nfa_pim_T pim;                /* if pim.result != NFA_PIM_UNUSED: postponed
                                 * invisible match */
  regsubs_T subs;               /* submatch info, only party used */
} nfa_thread_T;

/* nfa_list_T contains the alternative NFA execution states. */
typedef struct {
  nfa_thread_T    *t;           /* allocated array of states */
  int n;                        /* nr of states currently in "t" */
  int len;                      /* max nr of states in "t" */
  int id;                       /* ID of the list */
  int has_pim;                  /* TRUE when any state has a PIM */
} nfa_list_T;

/// re_flags passed to nfa_regcomp().
static int nfa_re_flags;

/* NFA regexp \ze operator encountered. */
static int nfa_has_zend;

/* NFA regexp \1 .. \9 encountered. */
static int nfa_has_backref;

/* NFA regexp has \z( ), set zsubexpr. */
static int nfa_has_zsubexpr;

/* Number of sub expressions actually being used during execution. 1 if only
 * the whole match (subexpr 0) is used. */
static int nfa_nsubexpr;

static int *post_start;  /* holds the postfix form of r.e. */
static int *post_end;
static int *post_ptr;

static int nstate;      /* Number of states in the NFA. Also used when
                         * executing. */
static int istate;      /* Index in the state vector, used in alloc_state() */

/* If not NULL match must end at this position */
static save_se_T *nfa_endp = NULL;

/* listid is global, so that it increases on recursive calls to
 * nfa_regmatch(), which means we don't have to clear the lastlist field of
 * all the states. */
static int nfa_listid;
static int nfa_alt_listid;

/* 0 for first call to nfa_regmatch(), 1 for recursive call. */
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

/*
 * Initialize internal variables before NFA compilation.
 */
static void
nfa_regcomp_start (
    char_u *expr,
    int re_flags                       /* see vim_regcomp() */
)
{
  size_t postfix_size;
  size_t nstate_max;

  nstate = 0;
  istate = 0;
  /* A reasonable estimation for maximum size */
  nstate_max = (STRLEN(expr) + 1) * 25;

  /* Some items blow up in size, such as [A-z].  Add more space for that.
   * When it is still not enough realloc_post_list() will be used. */
  nstate_max += 1000;

  /* Size for postfix representation of expr. */
  postfix_size = sizeof(int) * nstate_max;

  post_start = (int *)xmalloc(postfix_size);
  post_ptr = post_start;
  post_end = post_start + nstate_max;
  nfa_has_zend = FALSE;
  nfa_has_backref = FALSE;

  /* shared with BT engine */
  regcomp_start(expr, re_flags);
}

/*
 * Figure out if the NFA state list starts with an anchor, must match at start
 * of the line.
 */
static int nfa_get_reganch(nfa_state_T *start, int depth)
{
  nfa_state_T *p = start;

  if (depth > 4)
    return 0;

  while (p != NULL) {
    switch (p->c) {
    case NFA_BOL:
    case NFA_BOF:
      return 1;           /* yes! */

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
      return 0;           /* noooo */
    }
  }
  return 0;
}

/*
 * Figure out if the NFA state list starts with a character which must match
 * at start of the match.
 */
static int nfa_get_regstart(nfa_state_T *start, int depth)
{
  nfa_state_T *p = start;

  if (depth > 4)
    return 0;

  while (p != NULL) {
    switch (p->c) {
    /* all kinds of zero-width matches */
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

    case NFA_SPLIT:
    {
      int c1 = nfa_get_regstart(p->out, depth + 1);
      int c2 = nfa_get_regstart(p->out1, depth + 1);

      if (c1 == c2)
        return c1;             /* yes! */
      return 0;
    }

    default:
      if (p->c > 0)
        return p->c;             /* yes! */
      return 0;
    }
  }
  return 0;
}

/*
 * Figure out if the NFA state list contains just literal text and nothing
 * else.  If so return a string in allocated memory with what must match after
 * regstart.  Otherwise return NULL.
 */
static char_u *nfa_get_match_text(nfa_state_T *start)
{
  nfa_state_T *p = start;
  int len = 0;
  char_u      *ret;
  char_u      *s;

  if (p->c != NFA_MOPEN)
    return NULL;     /* just in case */
  p = p->out;
  while (p->c > 0) {
    len += MB_CHAR2LEN(p->c);
    p = p->out;
  }
  if (p->c != NFA_MCLOSE || p->out->c != NFA_MATCH)
    return NULL;

  ret = xmalloc(len);
  p = start->out->out;     /* skip first char, it goes into regstart */
  s = ret;
  while (p->c > 0) {
    if (has_mbyte)
      s += (*mb_char2bytes)(p->c, s);
    else
      *s++ = p->c;
    p = p->out;
  }
  *s = NUL;

  return ret;
}

/*
 * Allocate more space for post_start.  Called when
 * running above the estimated number of states.
 */
static void realloc_post_list(void)
{
  size_t new_max = (post_end - post_start) + 1000;
  int *new_start = xrealloc(post_start, new_max * sizeof(int));
  post_ptr = new_start + (post_ptr - post_start);
  post_end = new_start + new_max;
  post_start = new_start;
}

/*
 * Search between "start" and "end" and try to recognize a
 * character class in expanded form. For example [0-9].
 * On success, return the id the character class to be emitted.
 * On failure, return 0 (=FAIL)
 * Start points to the first char of the range, while end should point
 * to the closing brace.
 * Keep in mind that 'ignorecase' applies at execution time, thus [a-z] may
 * need to be interpreted as [a-zA-Z].
 */
static int nfa_recognize_char_class(char_u *start, char_u *end, int extra_newl)
{
#   define CLASS_not            0x80
#   define CLASS_af             0x40
#   define CLASS_AF             0x20
#   define CLASS_az             0x10
#   define CLASS_AZ             0x08
#   define CLASS_o7             0x04
#   define CLASS_o9             0x02
#   define CLASS_underscore     0x01

  int newl = FALSE;
  char_u      *p;
  int config = 0;

  if (extra_newl == TRUE)
    newl = TRUE;

  if (*end != ']')
    return FAIL;
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
      newl = TRUE;
      p += 2;
    } else if (*p == '_') {
      config |= CLASS_underscore;
      p++;
    } else if (*p == '\n') {
      newl = TRUE;
      p++;
    } else
      return FAIL;
  }   /* while (p < end) */

  if (p != end)
    return FAIL;

  if (newl == TRUE)
    extra_newl = NFA_ADD_NL;

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

/*
 * Produce the bytes for equivalence class "c".
 * Currently only handles latin1, latin9 and utf-8.
 * Emits bytes in postfix notation: 'a,b,NFA_OR,c,NFA_OR' is
 * equivalent to 'a OR b OR c'
 *
 * NOTE! When changing this function, also update reg_equi_class()
 */
static void nfa_emit_equi_class(int c)
{
#define EMIT2(c)   EMIT(c); EMIT(NFA_CONCAT);
#define EMITMBC(c) EMIT(c); EMIT(NFA_CONCAT);

  if (enc_utf8 || STRCMP(p_enc, "latin1") == 0
      || STRCMP(p_enc, "iso-8859-15") == 0) {
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
    case 'A': case A_grave: case A_acute: case A_circumflex:
              case A_virguilla: case A_diaeresis: case A_ring:
              CASEMBC(0x100) CASEMBC(0x102) CASEMBC(0x104)
              CASEMBC(0x1cd) CASEMBC(0x1de) CASEMBC(0x1e0)
              CASEMBC(0x1ea2)
      EMIT2('A'); EMIT2(A_grave); EMIT2(A_acute);
      EMIT2(A_circumflex); EMIT2(A_virguilla);
      EMIT2(A_diaeresis); EMIT2(A_ring);
      EMITMBC(0x100) EMITMBC(0x102) EMITMBC(0x104)
      EMITMBC(0x1cd) EMITMBC(0x1de) EMITMBC(0x1e0)
      EMITMBC(0x1ea2)
      return;

    case 'B': CASEMBC(0x1e02) CASEMBC(0x1e06)
      EMIT2('B'); EMITMBC(0x1e02) EMITMBC(0x1e06)
      return;

    case 'C': case C_cedilla: CASEMBC(0x106) CASEMBC(0x108) CASEMBC(0x10a)
              CASEMBC(0x10c)
      EMIT2('C'); EMIT2(C_cedilla); EMITMBC(0x106) EMITMBC(0x108)
      EMITMBC(0x10a) EMITMBC(0x10c)
      return;

    case 'D': CASEMBC(0x10e) CASEMBC(0x110) CASEMBC(0x1e0a)
              CASEMBC(0x1e0e) CASEMBC(0x1e10)
      EMIT2('D'); EMITMBC(0x10e) EMITMBC(0x110) EMITMBC(0x1e0a)
      EMITMBC(0x1e0e) EMITMBC(0x1e10)
      return;

    case 'E': case E_grave: case E_acute: case E_circumflex:
              case E_diaeresis: CASEMBC(0x112) CASEMBC(0x114)
              CASEMBC(0x116) CASEMBC(0x118) CASEMBC(0x11a)
              CASEMBC(0x1eba) CASEMBC(0x1ebc)
      EMIT2('E'); EMIT2(E_grave); EMIT2(E_acute);
      EMIT2(E_circumflex); EMIT2(E_diaeresis);
      EMITMBC(0x112) EMITMBC(0x114) EMITMBC(0x116)
      EMITMBC(0x118) EMITMBC(0x11a) EMITMBC(0x1eba)
      EMITMBC(0x1ebc)
      return;

    case 'F': CASEMBC(0x1e1e)
      EMIT2('F'); EMITMBC(0x1e1e)
      return;

    case 'G': CASEMBC(0x11c) CASEMBC(0x11e) CASEMBC(0x120)
              CASEMBC(0x122) CASEMBC(0x1e4) CASEMBC(0x1e6)
              CASEMBC(0x1f4) CASEMBC(0x1e20)
      EMIT2('G'); EMITMBC(0x11c) EMITMBC(0x11e) EMITMBC(0x120)
      EMITMBC(0x122) EMITMBC(0x1e4) EMITMBC(0x1e6)
      EMITMBC(0x1f4) EMITMBC(0x1e20)
      return;

    case 'H': CASEMBC(0x124) CASEMBC(0x126) CASEMBC(0x1e22)
              CASEMBC(0x1e26) CASEMBC(0x1e28)
      EMIT2('H'); EMITMBC(0x124) EMITMBC(0x126) EMITMBC(0x1e22)
      EMITMBC(0x1e26) EMITMBC(0x1e28)
      return;

    case 'I': case I_grave: case I_acute: case I_circumflex:
              case I_diaeresis: CASEMBC(0x128) CASEMBC(0x12a)
              CASEMBC(0x12c) CASEMBC(0x12e) CASEMBC(0x130)
              CASEMBC(0x1cf) CASEMBC(0x1ec8)
      EMIT2('I'); EMIT2(I_grave); EMIT2(I_acute);
      EMIT2(I_circumflex); EMIT2(I_diaeresis);
      EMITMBC(0x128) EMITMBC(0x12a)
      EMITMBC(0x12c) EMITMBC(0x12e) EMITMBC(0x130)
      EMITMBC(0x1cf) EMITMBC(0x1ec8)
      return;

    case 'J': CASEMBC(0x134)
      EMIT2('J'); EMITMBC(0x134)
      return;

    case 'K': CASEMBC(0x136) CASEMBC(0x1e8) CASEMBC(0x1e30)
              CASEMBC(0x1e34)
      EMIT2('K'); EMITMBC(0x136) EMITMBC(0x1e8) EMITMBC(0x1e30)
      EMITMBC(0x1e34)
      return;

    case 'L': CASEMBC(0x139) CASEMBC(0x13b) CASEMBC(0x13d)
              CASEMBC(0x13f) CASEMBC(0x141) CASEMBC(0x1e3a)
      EMIT2('L'); EMITMBC(0x139) EMITMBC(0x13b) EMITMBC(0x13d)
      EMITMBC(0x13f) EMITMBC(0x141) EMITMBC(0x1e3a)
      return;

    case 'M': CASEMBC(0x1e3e) CASEMBC(0x1e40)
      EMIT2('M'); EMITMBC(0x1e3e) EMITMBC(0x1e40)
      return;

    case 'N': case N_virguilla: CASEMBC(0x143) CASEMBC(0x145)
              CASEMBC(0x147) CASEMBC(0x1e44) CASEMBC(0x1e48)
      EMIT2('N'); EMIT2(N_virguilla);
      EMITMBC(0x143) EMITMBC(0x145)
      EMITMBC(0x147) EMITMBC(0x1e44) EMITMBC(0x1e48)
      return;

    case 'O': case O_grave: case O_acute: case O_circumflex:
              case O_virguilla: case O_diaeresis: case O_slash:
              CASEMBC(0x14c) CASEMBC(0x14e) CASEMBC(0x150)
              CASEMBC(0x1a0) CASEMBC(0x1d1) CASEMBC(0x1ea)
              CASEMBC(0x1ec) CASEMBC(0x1ece)
      EMIT2('O'); EMIT2(O_grave); EMIT2(O_acute);
      EMIT2(O_circumflex); EMIT2(O_virguilla);
      EMIT2(O_diaeresis); EMIT2(O_slash);
      EMITMBC(0x14c) EMITMBC(0x14e) EMITMBC(0x150)
      EMITMBC(0x1a0) EMITMBC(0x1d1) EMITMBC(0x1ea)
      EMITMBC(0x1ec) EMITMBC(0x1ece)
      return;

    case 'P': case 0x1e54: case 0x1e56:
      EMIT2('P'); EMITMBC(0x1e54) EMITMBC(0x1e56)
      return;

    case 'R': CASEMBC(0x154) CASEMBC(0x156) CASEMBC(0x158)
              CASEMBC(0x1e58) CASEMBC(0x1e5e)
      EMIT2('R'); EMITMBC(0x154) EMITMBC(0x156) EMITMBC(0x158)
      EMITMBC(0x1e58) EMITMBC(0x1e5e)
      return;

    case 'S': CASEMBC(0x15a) CASEMBC(0x15c) CASEMBC(0x15e)
              CASEMBC(0x160) CASEMBC(0x1e60)
      EMIT2('S'); EMITMBC(0x15a) EMITMBC(0x15c) EMITMBC(0x15e)
      EMITMBC(0x160) EMITMBC(0x1e60)
      return;

    case 'T': CASEMBC(0x162) CASEMBC(0x164) CASEMBC(0x166)
              CASEMBC(0x1e6a) CASEMBC(0x1e6e)
      EMIT2('T'); EMITMBC(0x162) EMITMBC(0x164) EMITMBC(0x166)
      EMITMBC(0x1e6a) EMITMBC(0x1e6e)
      return;

    case 'U': case U_grave: case U_acute: case U_diaeresis:
              case U_circumflex: CASEMBC(0x168) CASEMBC(0x16a)
              CASEMBC(0x16c) CASEMBC(0x16e) CASEMBC(0x170)
              CASEMBC(0x172) CASEMBC(0x1af) CASEMBC(0x1d3)
              CASEMBC(0x1ee6)
      EMIT2('U'); EMIT2(U_grave); EMIT2(U_acute);
      EMIT2(U_diaeresis); EMIT2(U_circumflex);
      EMITMBC(0x168) EMITMBC(0x16a)
      EMITMBC(0x16c) EMITMBC(0x16e) EMITMBC(0x170)
      EMITMBC(0x172) EMITMBC(0x1af) EMITMBC(0x1d3)
      EMITMBC(0x1ee6)
      return;

    case 'V': CASEMBC(0x1e7c)
      EMIT2('V'); EMITMBC(0x1e7c)
      return;

    case 'W': CASEMBC(0x174) CASEMBC(0x1e80) CASEMBC(0x1e82)
              CASEMBC(0x1e84) CASEMBC(0x1e86)
      EMIT2('W'); EMITMBC(0x174) EMITMBC(0x1e80) EMITMBC(0x1e82)
      EMITMBC(0x1e84) EMITMBC(0x1e86)
      return;

    case 'X': CASEMBC(0x1e8a) CASEMBC(0x1e8c)
      EMIT2('X'); EMITMBC(0x1e8a) EMITMBC(0x1e8c)
      return;

    case 'Y': case Y_acute: CASEMBC(0x176) CASEMBC(0x178)
              CASEMBC(0x1e8e) CASEMBC(0x1ef2) CASEMBC(0x1ef6)
              CASEMBC(0x1ef8)
      EMIT2('Y'); EMIT2(Y_acute);
      EMITMBC(0x176) EMITMBC(0x178)
      EMITMBC(0x1e8e) EMITMBC(0x1ef2) EMITMBC(0x1ef6)
      EMITMBC(0x1ef8)
      return;

    case 'Z': CASEMBC(0x179) CASEMBC(0x17b) CASEMBC(0x17d)
              CASEMBC(0x1b5) CASEMBC(0x1e90) CASEMBC(0x1e94)
      EMIT2('Z'); EMITMBC(0x179) EMITMBC(0x17b) EMITMBC(0x17d)
      EMITMBC(0x1b5) EMITMBC(0x1e90) EMITMBC(0x1e94)
      return;

    case 'a': case a_grave: case a_acute: case a_circumflex:
              case a_virguilla: case a_diaeresis: case a_ring:
              CASEMBC(0x101) CASEMBC(0x103) CASEMBC(0x105)
              CASEMBC(0x1ce) CASEMBC(0x1df) CASEMBC(0x1e1)
              CASEMBC(0x1ea3)
      EMIT2('a'); EMIT2(a_grave); EMIT2(a_acute);
      EMIT2(a_circumflex); EMIT2(a_virguilla);
      EMIT2(a_diaeresis); EMIT2(a_ring);
      EMITMBC(0x101) EMITMBC(0x103) EMITMBC(0x105)
      EMITMBC(0x1ce) EMITMBC(0x1df) EMITMBC(0x1e1)
      EMITMBC(0x1ea3)
      return;

    case 'b': CASEMBC(0x1e03) CASEMBC(0x1e07)
      EMIT2('b'); EMITMBC(0x1e03) EMITMBC(0x1e07)
      return;

    case 'c': case c_cedilla: CASEMBC(0x107) CASEMBC(0x109)
              CASEMBC(0x10b) CASEMBC(0x10d)
      EMIT2('c'); EMIT2(c_cedilla);
      EMITMBC(0x107) EMITMBC(0x109)
      EMITMBC(0x10b) EMITMBC(0x10d)
      return;

    case 'd': CASEMBC(0x10f) CASEMBC(0x111) CASEMBC(0x1e0b)
              CASEMBC(0x1e0f) CASEMBC(0x1e11)
      EMIT2('d'); EMITMBC(0x10f) EMITMBC(0x111) EMITMBC(0x1e0b)
      EMITMBC(0x1e0f) EMITMBC(0x1e11)
      return;

    case 'e': case e_grave: case e_acute: case e_circumflex:
              case e_diaeresis: CASEMBC(0x113) CASEMBC(0x115)
              CASEMBC(0x117) CASEMBC(0x119) CASEMBC(0x11b)
              CASEMBC(0x1ebb) CASEMBC(0x1ebd)
      EMIT2('e'); EMIT2(e_grave); EMIT2(e_acute);
      EMIT2(e_circumflex); EMIT2(e_diaeresis);
      EMITMBC(0x113) EMITMBC(0x115)
      EMITMBC(0x117) EMITMBC(0x119) EMITMBC(0x11b)
      EMITMBC(0x1ebb) EMITMBC(0x1ebd)
      return;

    case 'f': CASEMBC(0x1e1f)
      EMIT2('f'); EMITMBC(0x1e1f)
      return;

    case 'g': CASEMBC(0x11d) CASEMBC(0x11f) CASEMBC(0x121)
              CASEMBC(0x123) CASEMBC(0x1e5) CASEMBC(0x1e7)
              CASEMBC(0x1f5) CASEMBC(0x1e21)
      EMIT2('g'); EMITMBC(0x11d) EMITMBC(0x11f) EMITMBC(0x121)
      EMITMBC(0x123) EMITMBC(0x1e5) EMITMBC(0x1e7)
      EMITMBC(0x1f5) EMITMBC(0x1e21)
      return;

    case 'h': CASEMBC(0x125) CASEMBC(0x127) CASEMBC(0x1e23)
              CASEMBC(0x1e27) CASEMBC(0x1e29) CASEMBC(0x1e96)
      EMIT2('h'); EMITMBC(0x125) EMITMBC(0x127) EMITMBC(0x1e23)
      EMITMBC(0x1e27) EMITMBC(0x1e29) EMITMBC(0x1e96)
      return;

    case 'i': case i_grave: case i_acute: case i_circumflex:
              case i_diaeresis: CASEMBC(0x129) CASEMBC(0x12b)
              CASEMBC(0x12d) CASEMBC(0x12f) CASEMBC(0x1d0)
              CASEMBC(0x1ec9)
      EMIT2('i'); EMIT2(i_grave); EMIT2(i_acute);
      EMIT2(i_circumflex); EMIT2(i_diaeresis);
      EMITMBC(0x129) EMITMBC(0x12b)
      EMITMBC(0x12d) EMITMBC(0x12f) EMITMBC(0x1d0)
      EMITMBC(0x1ec9)
      return;

    case 'j': CASEMBC(0x135) CASEMBC(0x1f0)
      EMIT2('j'); EMITMBC(0x135) EMITMBC(0x1f0)
      return;

    case 'k': CASEMBC(0x137) CASEMBC(0x1e9) CASEMBC(0x1e31)
              CASEMBC(0x1e35)
      EMIT2('k'); EMITMBC(0x137) EMITMBC(0x1e9) EMITMBC(0x1e31)
      EMITMBC(0x1e35)
      return;

    case 'l': CASEMBC(0x13a) CASEMBC(0x13c) CASEMBC(0x13e)
              CASEMBC(0x140) CASEMBC(0x142) CASEMBC(0x1e3b)
      EMIT2('l'); EMITMBC(0x13a) EMITMBC(0x13c) EMITMBC(0x13e)
      EMITMBC(0x140) EMITMBC(0x142) EMITMBC(0x1e3b)
      return;

    case 'm': CASEMBC(0x1e3f) CASEMBC(0x1e41)
      EMIT2('m'); EMITMBC(0x1e3f) EMITMBC(0x1e41)
      return;

    case 'n': case n_virguilla: CASEMBC(0x144) CASEMBC(0x146)
              CASEMBC(0x148) CASEMBC(0x149) CASEMBC(0x1e45)
              CASEMBC(0x1e49)
      EMIT2('n'); EMIT2(n_virguilla);
      EMITMBC(0x144) EMITMBC(0x146)
      EMITMBC(0x148) EMITMBC(0x149) EMITMBC(0x1e45)
      EMITMBC(0x1e49)
      return;

    case 'o': case o_grave: case o_acute: case o_circumflex:
              case o_virguilla: case o_diaeresis: case o_slash:
              CASEMBC(0x14d) CASEMBC(0x14f) CASEMBC(0x151)
              CASEMBC(0x1a1) CASEMBC(0x1d2) CASEMBC(0x1eb)
              CASEMBC(0x1ed) CASEMBC(0x1ecf)
      EMIT2('o'); EMIT2(o_grave); EMIT2(o_acute);
      EMIT2(o_circumflex); EMIT2(o_virguilla);
      EMIT2(o_diaeresis); EMIT2(o_slash);
      EMITMBC(0x14d) EMITMBC(0x14f) EMITMBC(0x151)
      EMITMBC(0x1a1) EMITMBC(0x1d2) EMITMBC(0x1eb)
      EMITMBC(0x1ed) EMITMBC(0x1ecf)
      return;

    case 'p': CASEMBC(0x1e55) CASEMBC(0x1e57)
      EMIT2('p'); EMITMBC(0x1e55) EMITMBC(0x1e57)
      return;

    case 'r': CASEMBC(0x155) CASEMBC(0x157) CASEMBC(0x159)
              CASEMBC(0x1e59) CASEMBC(0x1e5f)
      EMIT2('r'); EMITMBC(0x155) EMITMBC(0x157) EMITMBC(0x159)
      EMITMBC(0x1e59) EMITMBC(0x1e5f)
      return;

    case 's': CASEMBC(0x15b) CASEMBC(0x15d) CASEMBC(0x15f)
              CASEMBC(0x161) CASEMBC(0x1e61)
      EMIT2('s'); EMITMBC(0x15b) EMITMBC(0x15d) EMITMBC(0x15f)
      EMITMBC(0x161) EMITMBC(0x1e61)
      return;

    case 't': CASEMBC(0x163) CASEMBC(0x165) CASEMBC(0x167)
              CASEMBC(0x1e6b) CASEMBC(0x1e6f) CASEMBC(0x1e97)
      EMIT2('t'); EMITMBC(0x163) EMITMBC(0x165) EMITMBC(0x167)
      EMITMBC(0x1e6b) EMITMBC(0x1e6f) EMITMBC(0x1e97)
      return;

    case 'u': case u_grave: case u_acute: case u_circumflex:
              case u_diaeresis: CASEMBC(0x169) CASEMBC(0x16b)
              CASEMBC(0x16d) CASEMBC(0x16f) CASEMBC(0x171)
              CASEMBC(0x173) CASEMBC(0x1b0) CASEMBC(0x1d4)
              CASEMBC(0x1ee7)
      EMIT2('u'); EMIT2(u_grave); EMIT2(u_acute);
      EMIT2(u_circumflex); EMIT2(u_diaeresis);
      EMITMBC(0x169) EMITMBC(0x16b)
      EMITMBC(0x16d) EMITMBC(0x16f) EMITMBC(0x171)
      EMITMBC(0x173) EMITMBC(0x1b0) EMITMBC(0x1d4)
      EMITMBC(0x1ee7)
      return;

    case 'v': CASEMBC(0x1e7d)
      EMIT2('v'); EMITMBC(0x1e7d)
      return;

    case 'w': CASEMBC(0x175) CASEMBC(0x1e81) CASEMBC(0x1e83)
              CASEMBC(0x1e85) CASEMBC(0x1e87) CASEMBC(0x1e98)
      EMIT2('w'); EMITMBC(0x175) EMITMBC(0x1e81) EMITMBC(0x1e83)
      EMITMBC(0x1e85) EMITMBC(0x1e87) EMITMBC(0x1e98)
      return;

    case 'x': CASEMBC(0x1e8b) CASEMBC(0x1e8d)
      EMIT2('x'); EMITMBC(0x1e8b) EMITMBC(0x1e8d)
      return;

    case 'y': case y_acute: case y_diaeresis: CASEMBC(0x177)
              CASEMBC(0x1e8f) CASEMBC(0x1e99) CASEMBC(0x1ef3)
              CASEMBC(0x1ef7) CASEMBC(0x1ef9)
      EMIT2('y'); EMIT2(y_acute); EMIT2(y_diaeresis);
      EMITMBC(0x177)
      EMITMBC(0x1e8f) EMITMBC(0x1e99) EMITMBC(0x1ef3)
      EMITMBC(0x1ef7) EMITMBC(0x1ef9)
      return;

    case 'z': CASEMBC(0x17a) CASEMBC(0x17c) CASEMBC(0x17e)
              CASEMBC(0x1b6) CASEMBC(0x1e91) CASEMBC(0x1e95)
      EMIT2('z'); EMITMBC(0x17a) EMITMBC(0x17c) EMITMBC(0x17e)
      EMITMBC(0x1b6) EMITMBC(0x1e91) EMITMBC(0x1e95)
      return;

      /* default: character itself */
    }
  }

  EMIT2(c);
#undef EMIT2
#undef EMITMBC
}

/*
 * Code to parse regular expression.
 *
 * We try to reuse parsing functions in regexp.c to
 * minimize surprise and keep the syntax consistent.
 */

/*
 * Parse the lowest level.
 *
 * An atom can be one of a long list of items.  Many atoms match one character
 * in the text.  It is often an ordinary character or a character class.
 * Braces can be used to make a pattern into an atom.  The "\z(\)" construct
 * is only for syntax highlighting.
 *
 * atom    ::=     ordinary-atom
 *     or  \( pattern \)
 *     or  \%( pattern \)
 *     or  \z( pattern \)
 */
static int nfa_regatom(void)
{
  int c;
  int charclass;
  int equiclass;
  int collclass;
  int got_coll_char;
  char_u      *p;
  char_u      *endp;
  char_u      *old_regparse = regparse;
  int extra = 0;
  int emit_range;
  int negated;
  int startc = -1;
  int endc = -1;
  int oldstartc = -1;
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
    had_eol = TRUE;
    break;

  case Magic('<'):
    EMIT(NFA_BOW);
    break;

  case Magic('>'):
    EMIT(NFA_EOW);
    break;

  case Magic('_'):
    c = no_Magic(getchr());
    if (c == NUL)
      EMSG_RET_FAIL(_(e_nul_found));

    if (c == '^') {             /* "\_^" is start-of-line */
      EMIT(NFA_BOL);
      break;
    }
    if (c == '$') {             /* "\_$" is end-of-line */
      EMIT(NFA_EOL);
      had_eol = TRUE;
      break;
    }

    extra = NFA_ADD_NL;

    /* "\_[" is collection plus newline */
    if (c == '[')
      goto collection;

  /* "\_x" is character class plus newline */
  /*FALLTHROUGH*/

  /*
   * Character classes.
   */
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
    p = vim_strchr(classchars, no_Magic(c));
    if (p == NULL) {
      if (extra == NFA_ADD_NL) {
        EMSGN(_(e_ill_char_class), c);
        rc_did_emsg = TRUE;
        return FAIL;
      }
      IEMSGN("INTERNAL: Unknown character class char: %" PRId64, c);
      return FAIL;
    }
    /* When '.' is followed by a composing char ignore the dot, so that
     * the composing char is matched here. */
    if (enc_utf8 && c == Magic('.') && utf_iscomposing(peekchr())) {
      old_regparse = regparse;
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
    if (reg_string)
      /* In a string "\n" matches a newline character. */
      EMIT(NL);
    else {
      /* In buffer text "\n" matches the end of a line. */
      EMIT(NFA_NEWL);
      regflags |= RF_HASNL;
    }
    break;

  case Magic('('):
    if (nfa_reg(REG_PAREN) == FAIL)
      return FAIL;                  /* cascaded error */
    break;

  case Magic('|'):
  case Magic('&'):
  case Magic(')'):
    EMSGN(_(e_misplaced), no_Magic(c));
    return FAIL;

  case Magic('='):
  case Magic('?'):
  case Magic('+'):
  case Magic('@'):
  case Magic('*'):
  case Magic('{'):
    /* these should follow an atom, not form an atom */
    EMSGN(_(e_misplaced), no_Magic(c));
    return FAIL;

  case Magic('~'):
  {
    char_u      *lp;

    /* Previous substitute pattern.
     * Generated as "\%(pattern\)". */
    if (reg_prev_sub == NULL) {
      EMSG(_(e_nopresub));
      return FAIL;
    }
    for (lp = reg_prev_sub; *lp != NUL; mb_cptr_adv(lp)) {
      EMIT(PTR2CHAR(lp));
      if (lp != reg_prev_sub)
        EMIT(NFA_CONCAT);
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
  case Magic('9'):
    EMIT(NFA_BACKREF1 + (no_Magic(c) - '1'));
    nfa_has_backref = TRUE;
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
      nfa_has_zend = true;
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
      /* \z1...\z9 */
      if (reg_do_extmatch != REX_USE)
        EMSG_RET_FAIL(_(e_z1_not_allowed));
      EMIT(NFA_ZREF1 + (no_Magic(c) - '1'));
      /* No need to set nfa_has_backref, the sub-matches don't
       * change when \z1 .. \z9 matches or not. */
      re_has_z = REX_USE;
      break;
    case '(':
      /* \z(  */
      if (reg_do_extmatch != REX_SET)
        EMSG_RET_FAIL(_(e_z_not_allowed));
      if (nfa_reg(REG_ZPAREN) == FAIL)
        return FAIL;                        /* cascaded error */
      re_has_z = REX_SET;
      break;
    default:
      EMSGN(_("E867: (NFA) Unknown operator '\\z%c'"),
          no_Magic(c));
      return FAIL;
    }
    break;

  case Magic('%'):
    c = no_Magic(getchr());
    switch (c) {
    /* () without a back reference */
    case '(':
      if (nfa_reg(REG_NPAREN) == FAIL)
        return FAIL;
      EMIT(NFA_NOPEN);
      break;

    case 'd':               /* %d123 decimal */
    case 'o':               /* %o123 octal */
    case 'x':               /* %xab hex 2 */
    case 'u':               /* %uabcd hex 4 */
    case 'U':               /* %U1234abcd hex 8 */
    {
      int nr;

      switch (c) {
      case 'd': nr = getdecchrs(); break;
      case 'o': nr = getoctchrs(); break;
      case 'x': nr = gethexchrs(2); break;
      case 'u': nr = gethexchrs(4); break;
      case 'U': nr = gethexchrs(8); break;
      default:  nr = -1; break;
      }

      if (nr < 0)
        EMSG2_RET_FAIL(
            _("E678: Invalid character after %s%%[dxouU]"),
            reg_magic == MAGIC_ALL);
      /* A NUL is stored in the text as NL */
      /* TODO: what if a composing character follows? */
      EMIT(nr == 0 ? 0x0a : nr);
    }
    break;

    /* Catch \%^ and \%$ regardless of where they appear in the
     * pattern -- regardless of whether or not it makes sense. */
    case '^':
      EMIT(NFA_BOF);
      break;

    case '$':
      EMIT(NFA_EOF);
      break;

    case '#':
      EMIT(NFA_CURSOR);
      break;

    case 'V':
      EMIT(NFA_VISUAL);
      break;

    case 'C':
      EMIT(NFA_ANY_COMPOSING);
      break;

    case '[':
    {
      int n;

      /* \%[abc] */
      for (n = 0; (c = peekchr()) != ']'; ++n) {
        if (c == NUL)
          EMSG2_RET_FAIL(_(e_missing_sb),
              reg_magic == MAGIC_ALL);
        /* recursive call! */
        if (nfa_regatom() == FAIL)
          return FAIL;
      }
      getchr();                    /* get the ] */
      if (n == 0)
        EMSG2_RET_FAIL(_(e_empty_sb),
            reg_magic == MAGIC_ALL);
      EMIT(NFA_OPT_CHARS);
      EMIT(n);

      /* Emit as "\%(\%[abc]\)" to be able to handle
       * "\%[abc]*" which would cause the empty string to be
       * matched an unlimited number of times. NFA_NOPEN is
       * added only once at a position, while NFA_SPLIT is
       * added multiple times.  This is more efficient than
       * not allowing NFA_SPLIT multiple times, it is used
       * a lot. */
      EMIT(NFA_NOPEN);
      break;
    }

    default:
    {
      int n = 0;
      int cmp = c;

      if (c == '<' || c == '>')
        c = getchr();
      while (ascii_isdigit(c)) {
        n = n * 10 + (c - '0');
        c = getchr();
      }
      if (c == 'l' || c == 'c' || c == 'v') {
        if (c == 'l') {
          // \%{n}l  \%{n}<l  \%{n}>l
          EMIT(cmp == '<' ? NFA_LNUM_LT :
               cmp == '>' ? NFA_LNUM_GT : NFA_LNUM);
          if (save_prev_at_start) {
            at_start = true;
          }
        } else if (c == 'c') {
          // \%{n}c  \%{n}<c  \%{n}>c
          EMIT(cmp == '<' ? NFA_COL_LT :
               cmp == '>' ? NFA_COL_GT : NFA_COL);
        } else {
          // \%{n}v  \%{n}<v  \%{n}>v
          EMIT(cmp == '<' ? NFA_VCOL_LT :
               cmp == '>' ? NFA_VCOL_GT : NFA_VCOL);
        }
        EMIT(n);
        break;
      } else if (c == '\'' && n == 0) {
        /* \%'m  \%<'m  \%>'m  */
        EMIT(cmp == '<' ? NFA_MARK_LT :
            cmp == '>' ? NFA_MARK_GT : NFA_MARK);
        EMIT(getchr());
        break;
      }
    }
      EMSGN(_("E867: (NFA) Unknown operator '\\%%%c'"),
          no_Magic(c));
      return FAIL;
    }
    break;

  case Magic('['):
collection:
    /*
     * [abc]  uses NFA_START_COLL - NFA_END_COLL
     * [^abc] uses NFA_START_NEG_COLL - NFA_END_NEG_COLL
     * Each character is produced as a regular state, using
     * NFA_CONCAT to bind them together.
     * Besides normal characters there can be:
     * - character classes  NFA_CLASS_*
     * - ranges, two characters followed by NFA_RANGE.
     */

    p = regparse;
    endp = skip_anyof(p);
    if (*endp == ']') {
      /*
       * Try to reverse engineer character classes. For example,
       * recognize that [0-9] stands for \d and [A-Za-z_] for \h,
       * and perform the necessary substitutions in the NFA.
       */
      int result = nfa_recognize_char_class(regparse, endp,
                                            extra == NFA_ADD_NL);
      if (result != FAIL) {
        if (result >= NFA_FIRST_NL && result <= NFA_LAST_NL) {
          EMIT(result - NFA_ADD_NL);
          EMIT(NFA_NEWL);
          EMIT(NFA_OR);
        } else
          EMIT(result);
        regparse = endp;
        mb_ptr_adv(regparse);
        return OK;
      }
      /*
       * Failed to recognize a character class. Use the simple
       * version that turns [abc] into 'a' OR 'b' OR 'c'
       */
      startc = endc = oldstartc = -1;
      negated = FALSE;
      if (*regparse == '^') {                           /* negated range */
        negated = TRUE;
        mb_ptr_adv(regparse);
        EMIT(NFA_START_NEG_COLL);
      } else
        EMIT(NFA_START_COLL);
      if (*regparse == '-') {
        startc = '-';
        EMIT(startc);
        EMIT(NFA_CONCAT);
        mb_ptr_adv(regparse);
      }
      /* Emit the OR branches for each character in the [] */
      emit_range = FALSE;
      while (regparse < endp) {
        oldstartc = startc;
        startc = -1;
        got_coll_char = FALSE;
        if (*regparse == '[') {
          /* Check for [: :], [= =], [. .] */
          equiclass = collclass = 0;
          charclass = get_char_class(&regparse);
          if (charclass == CLASS_NONE) {
            equiclass = get_equi_class(&regparse);
            if (equiclass == 0)
              collclass = get_coll_element(&regparse);
          }

          /* Character class like [:alpha:]  */
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
            }
            EMIT(NFA_CONCAT);
            continue;
          }
          /* Try equivalence class [=a=] and the like */
          if (equiclass != 0) {
            nfa_emit_equi_class(equiclass);
            continue;
          }
          /* Try collating class like [. .]  */
          if (collclass != 0) {
            startc = collclass;                  /* allow [.a.]-x as a range */
            /* Will emit the proper atom at the end of the
             * while loop. */
          }
        }
        /* Try a range like 'a-x' or '\t-z'. Also allows '-' as a
         * start character. */
        if (*regparse == '-' && oldstartc != -1) {
          emit_range = TRUE;
          startc = oldstartc;
          mb_ptr_adv(regparse);
          continue;                         /* reading the end of the range */
        }

        /* Now handle simple and escaped characters.
         * Only "\]", "\^", "\]" and "\\" are special in Vi.  Vim
         * accepts "\t", "\e", etc., but only when the 'l' flag in
         * 'cpoptions' is not included.
         */
        if (*regparse == '\\'
            && regparse + 1 <= endp
            && (vim_strchr(REGEXP_INRANGE, regparse[1]) != NULL
                || (!reg_cpo_lit
                    && vim_strchr(REGEXP_ABBR, regparse[1])
                    != NULL)
                )
            ) {
          mb_ptr_adv(regparse);

          if (*regparse == 'n')
            startc = reg_string ? NL : NFA_NEWL;
          else if  (*regparse == 'd'
                    || *regparse == 'o'
                    || *regparse == 'x'
                    || *regparse == 'u'
                    || *regparse == 'U'
                    ) {
            /* TODO(RE) This needs more testing */
            startc = coll_get_char();
            got_coll_char = TRUE;
            mb_ptr_back(old_regparse, regparse);
          } else {
            /* \r,\t,\e,\b */
            startc = backslash_trans(*regparse);
          }
        }

        /* Normal printable char */
        if (startc == -1)
          startc = PTR2CHAR(regparse);

        /* Previous char was '-', so this char is end of range. */
        if (emit_range) {
          endc = startc;
          startc = oldstartc;
          if (startc > endc)
            EMSG_RET_FAIL(_(e_invrange));

          if (endc > startc + 2) {
            /* Emit a range instead of the sequence of
             * individual characters. */
            if (startc == 0)
              /* \x00 is translated to \x0a, start at \x01. */
              EMIT(1);
            else
              --post_ptr;                   /* remove NFA_CONCAT */
            EMIT(endc);
            EMIT(NFA_RANGE);
            EMIT(NFA_CONCAT);
          } else if (has_mbyte && ((*mb_char2len)(startc) > 1
                                   || (*mb_char2len)(endc) > 1)) {
            /* Emit the characters in the range.
             * "startc" was already emitted, so skip it.
             * */
            for (c = startc + 1; c <= endc; c++) {
              EMIT(c);
              EMIT(NFA_CONCAT);
            }
          } else {
            /* Emit the range. "startc" was already emitted, so
             * skip it. */
            for (c = startc + 1; c <= endc; c++) {
              EMIT(c);
              EMIT(NFA_CONCAT);
            }
          }
          emit_range = FALSE;
          startc = -1;
        } else {
          /* This char (startc) is not part of a range. Just
           * emit it.
           * Normally, simply emit startc. But if we get char
           * code=0 from a collating char, then replace it with
           * 0x0a.
           * This is needed to completely mimic the behaviour of
           * the backtracking engine. */
          if (startc == NFA_NEWL) {
            /* Line break can't be matched as part of the
             * collection, add an OR below. But not for negated
             * range. */
            if (!negated)
              extra = NFA_ADD_NL;
          } else {
            if (got_coll_char == TRUE && startc == 0)
              EMIT(0x0a);
            else
              EMIT(startc);
            EMIT(NFA_CONCAT);
          }
        }

        mb_ptr_adv(regparse);
      }           /* while (p < endp) */

      mb_ptr_back(old_regparse, regparse);
      if (*regparse == '-') {               /* if last, '-' is just a char */
        EMIT('-');
        EMIT(NFA_CONCAT);
      }

      /* skip the trailing ] */
      regparse = endp;
      mb_ptr_adv(regparse);

      /* Mark end of the collection. */
      if (negated == TRUE)
        EMIT(NFA_END_NEG_COLL);
      else
        EMIT(NFA_END_COLL);

      /* \_[] also matches \n but it's not negated */
      if (extra == NFA_ADD_NL) {
        EMIT(reg_string ? NL : NFA_NEWL);
        EMIT(NFA_OR);
      }

      return OK;
    }         /* if exists closing ] */

    if (reg_strict)
      EMSG_RET_FAIL(_(e_missingbracket));
  /* FALLTHROUGH */

  default:
  {
    int plen;

nfa_do_multibyte:
    /* plen is length of current char with composing chars */
    if (enc_utf8 && ((*mb_char2len)(c)
                     != (plen = (*mb_ptr2len)(old_regparse))
                     || utf_iscomposing(c))) {
      int i = 0;

      /* A base character plus composing characters, or just one
       * or more composing characters.
       * This requires creating a separate atom as if enclosing
       * the characters in (), where NFA_COMPOSING is the ( and
       * NFA_END_COMPOSING is the ). Note that right now we are
       * building the postfix form, not the NFA itself;
       * a composing char could be: a, b, c, NFA_COMPOSING
       * where 'b' and 'c' are chars with codes > 256. */
      for (;; ) {
        EMIT(c);
        if (i > 0)
          EMIT(NFA_CONCAT);
        if ((i += utf_char2len(c)) >= plen)
          break;
        c = utf_ptr2char(old_regparse + i);
      }
      EMIT(NFA_COMPOSING);
      regparse = old_regparse + plen;
    } else {
      c = no_Magic(c);
      EMIT(c);
    }
    return OK;
  }
  }

  return OK;
}

/*
 * Parse something followed by possible [*+=].
 *
 * A piece is an atom, possibly followed by a multi, an indication of how many
 * times the atom can be matched.  Example: "a*" matches any sequence of "a"
 * characters: "", "a", "aa", etc.
 *
 * piece   ::=	    atom
 *	or  atom  multi
 */
static int nfa_regpiece(void)
{
  int i;
  int op;
  int ret;
  long minval, maxval;
  int greedy = TRUE;                /* Braces are prefixed with '-' ? */
  parse_state_T old_state;
  parse_state_T new_state;
  int c2;
  int old_post_pos;
  int my_post_start;
  int quest;

  /* Save the current parse state, so that we can use it if <atom>{m,n} is
   * next. */
  save_parse_state(&old_state);

  /* store current pos in the postfix form, for \{m,n} involving 0s */
  my_post_start = (int)(post_ptr - post_start);

  ret = nfa_regatom();
  if (ret == FAIL)
    return FAIL;            /* cascaded error */

  op = peekchr();
  if (re_multi_type(op) == NOT_MULTI)
    return OK;

  skipchr();
  switch (op) {
  case Magic('*'):
    EMIT(NFA_STAR);
    break;

  case Magic('+'):
    /*
     * Trick: Normally, (a*)\+ would match the whole input "aaa".  The
     * first and only submatch would be "aaa". But the backtracking
     * engine interprets the plus as "try matching one more time", and
     * a* matches a second time at the end of the input, the empty
     * string.
     * The submatch will be the empty string.
     *
     * In order to be consistent with the old engine, we replace
     * <atom>+ with <atom><atom>*
     */
    restore_parse_state(&old_state);
    curchr = -1;
    if (nfa_regatom() == FAIL)
      return FAIL;
    EMIT(NFA_STAR);
    EMIT(NFA_CONCAT);
    skipchr();                  /* skip the \+	*/
    break;

  case Magic('@'):
    c2 = getdecchrs();
    op = no_Magic(getchr());
    i = 0;
    switch(op) {
    case '=':
      /* \@= */
      i = NFA_PREV_ATOM_NO_WIDTH;
      break;
    case '!':
      /* \@! */
      i = NFA_PREV_ATOM_NO_WIDTH_NEG;
      break;
    case '<':
      op = no_Magic(getchr());
      if (op == '=')
        /* \@<= */
        i = NFA_PREV_ATOM_JUST_BEFORE;
      else if (op == '!')
        /* \@<! */
        i = NFA_PREV_ATOM_JUST_BEFORE_NEG;
      break;
    case '>':
      /* \@>  */
      i = NFA_PREV_ATOM_LIKE_PATTERN;
      break;
    }
    if (i == 0) {
      EMSGN(_("E869: (NFA) Unknown operator '\\@%c'"), op);
      return FAIL;
    }
    EMIT(i);
    if (i == NFA_PREV_ATOM_JUST_BEFORE
        || i == NFA_PREV_ATOM_JUST_BEFORE_NEG)
      EMIT(c2);
    break;

  case Magic('?'):
  case Magic('='):
    EMIT(NFA_QUEST);
    break;

  case Magic('{'):
    /* a{2,5} will expand to 'aaa?a?a?'
     * a{-1,3} will expand to 'aa??a??', where ?? is the nongreedy
     * version of '?'
     * \v(ab){2,3} will expand to '(ab)(ab)(ab)?', where all the
     * parenthesis have the same id
     */

    greedy = TRUE;
    c2 = peekchr();
    if (c2 == '-' || c2 == Magic('-')) {
      skipchr();
      greedy = FALSE;
    }
    if (!read_limits(&minval, &maxval))
      EMSG_RET_FAIL(_("E870: (NFA regexp) Error reading repetition limits"));

    /*  <atom>{0,inf}, <atom>{0,} and <atom>{}  are equivalent to
     *  <atom>*  */
    if (minval == 0 && maxval == MAX_LIMIT) {
      if (greedy)
        /* \{}, \{0,} */
        EMIT(NFA_STAR);
      else
        /* \{-}, \{-0,} */
        EMIT(NFA_STAR_NONGREEDY);
      break;
    }

    /* Special case: x{0} or x{-0} */
    if (maxval == 0) {
      /* Ignore result of previous call to nfa_regatom() */
      post_ptr = post_start + my_post_start;
      /* NFA_EMPTY is 0-length and works everywhere */
      EMIT(NFA_EMPTY);
      return OK;
    }

    // The engine is very inefficient (uses too many states) when the maximum
    // is much larger than the minimum and when the maximum is large. Bail out
    // if we can use the other engine.
    if ((nfa_re_flags & RE_AUTO) && (maxval > 500 || maxval > minval + 200)) {
      return FAIL;
    }

    /* Ignore previous call to nfa_regatom() */
    post_ptr = post_start + my_post_start;
    /* Save parse state after the repeated atom and the \{} */
    save_parse_state(&new_state);

    quest = (greedy == TRUE ? NFA_QUEST : NFA_QUEST_NONGREEDY);
    for (i = 0; i < maxval; i++) {
      /* Goto beginning of the repeated atom */
      restore_parse_state(&old_state);
      old_post_pos = (int)(post_ptr - post_start);
      if (nfa_regatom() == FAIL)
        return FAIL;
      /* after "minval" times, atoms are optional */
      if (i + 1 > minval) {
        if (maxval == MAX_LIMIT) {
          if (greedy)
            EMIT(NFA_STAR);
          else
            EMIT(NFA_STAR_NONGREEDY);
        } else
          EMIT(quest);
      }
      if (old_post_pos != my_post_start)
        EMIT(NFA_CONCAT);
      if (i + 1 > minval && maxval == MAX_LIMIT)
        break;
    }

    /* Go to just after the repeated atom and the \{} */
    restore_parse_state(&new_state);
    curchr = -1;

    break;


  default:
    break;
  }     /* end switch */

  if (re_multi_type(peekchr()) != NOT_MULTI)
    /* Can't have a multi follow a multi. */
    EMSG_RET_FAIL(_("E871: (NFA regexp) Can't have a multi follow a multi !"));

  return OK;
}

/*
 * Parse one or more pieces, concatenated.  It matches a match for the
 * first piece, followed by a match for the second piece, etc.  Example:
 * "f[0-9]b", first matches "f", then a digit and then "b".
 *
 * concat  ::=	    piece
 *	or  piece piece
 *	or  piece piece piece
 *	etc.
 */
static int nfa_regconcat(void)
{
  int cont = TRUE;
  int first = TRUE;

  while (cont) {
    switch (peekchr()) {
    case NUL:
    case Magic('|'):
    case Magic('&'):
    case Magic(')'):
      cont = FALSE;
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
      if (nfa_regpiece() == FAIL)
        return FAIL;
      if (first == FALSE)
        EMIT(NFA_CONCAT);
      else
        first = FALSE;
      break;
    }
  }

  return OK;
}

/*
 * Parse a branch, one or more concats, separated by "\&".  It matches the
 * last concat, but only if all the preceding concats also match at the same
 * position.  Examples:
 *      "foobeep\&..." matches "foo" in "foobeep".
 *      ".*Peter\&.*Bob" matches in a line containing both "Peter" and "Bob"
 *
 * branch ::=	    concat
 *		or  concat \& concat
 *		or  concat \& concat \& concat
 *		etc.
 */
static int nfa_regbranch(void)
{
  int ch;
  int old_post_pos;

  old_post_pos = (int)(post_ptr - post_start);

  /* First branch, possibly the only one */
  if (nfa_regconcat() == FAIL)
    return FAIL;

  ch = peekchr();
  /* Try next concats */
  while (ch == Magic('&')) {
    skipchr();
    EMIT(NFA_NOPEN);
    EMIT(NFA_PREV_ATOM_NO_WIDTH);
    old_post_pos = (int)(post_ptr - post_start);
    if (nfa_regconcat() == FAIL)
      return FAIL;
    /* if concat is empty do emit a node */
    if (old_post_pos == (int)(post_ptr - post_start))
      EMIT(NFA_EMPTY);
    EMIT(NFA_CONCAT);
    ch = peekchr();
  }

  /* if a branch is empty, emit one node for it */
  if (old_post_pos == (int)(post_ptr - post_start))
    EMIT(NFA_EMPTY);

  return OK;
}

/*
 *  Parse a pattern, one or more branches, separated by "\|".  It matches
 *  anything that matches one of the branches.  Example: "foo\|beep" matches
 *  "foo" and matches "beep".  If more than one branch matches, the first one
 *  is used.
 *
 *  pattern ::=	    branch
 *	or  branch \| branch
 *	or  branch \| branch \| branch
 *	etc.
 */
static int 
nfa_reg (
    int paren              /* REG_NOPAREN, REG_PAREN, REG_NPAREN or REG_ZPAREN */
)
{
  int parno = 0;

  if (paren == REG_PAREN) {
    if (regnpar >= NSUBEXP)     /* Too many `(' */
      EMSG_RET_FAIL(_("E872: (NFA regexp) Too many '('"));
    parno = regnpar++;
  } else if (paren == REG_ZPAREN) {
    /* Make a ZOPEN node. */
    if (regnzpar >= NSUBEXP)
      EMSG_RET_FAIL(_("E879: (NFA regexp) Too many \\z("));
    parno = regnzpar++;
  }

  if (nfa_regbranch() == FAIL)
    return FAIL;            /* cascaded error */

  while (peekchr() == Magic('|')) {
    skipchr();
    if (nfa_regbranch() == FAIL)
      return FAIL;          /* cascaded error */
    EMIT(NFA_OR);
  }

  /* Check for proper termination. */
  if (paren != REG_NOPAREN && getchr() != Magic(')')) {
    if (paren == REG_NPAREN)
      EMSG2_RET_FAIL(_(e_unmatchedpp), reg_magic == MAGIC_ALL);
    else
      EMSG2_RET_FAIL(_(e_unmatchedp), reg_magic == MAGIC_ALL);
  } else if (paren == REG_NOPAREN && peekchr() != NUL) {
    if (peekchr() == Magic(')'))
      EMSG2_RET_FAIL(_(e_unmatchedpar), reg_magic == MAGIC_ALL);
    else
      EMSG_RET_FAIL(_("E873: (NFA regexp) proper termination error"));
  }
  /*
   * Here we set the flag allowing back references to this set of
   * parentheses.
   */
  if (paren == REG_PAREN) {
    had_endbrace[parno] = TRUE;         /* have seen the close paren */
    EMIT(NFA_MOPEN + parno);
  } else if (paren == REG_ZPAREN)
    EMIT(NFA_ZOPEN + parno);

  return OK;
}

#ifdef REGEXP_DEBUG
static char_u code[50];

static void nfa_set_code(int c)
{
  int addnl = FALSE;

  if (c >= NFA_FIRST_NL && c <= NFA_LAST_NL) {
    addnl = TRUE;
    c -= NFA_ADD_NL;
  }

  STRCPY(code, "");
  switch (c) {
  case NFA_MATCH:     STRCPY(code, "NFA_MATCH "); break;
  case NFA_SPLIT:     STRCPY(code, "NFA_SPLIT "); break;
  case NFA_CONCAT:    STRCPY(code, "NFA_CONCAT "); break;
  case NFA_NEWL:      STRCPY(code, "NFA_NEWL "); break;
  case NFA_ZSTART:    STRCPY(code, "NFA_ZSTART"); break;
  case NFA_ZEND:      STRCPY(code, "NFA_ZEND"); break;

  case NFA_BACKREF1:  STRCPY(code, "NFA_BACKREF1"); break;
  case NFA_BACKREF2:  STRCPY(code, "NFA_BACKREF2"); break;
  case NFA_BACKREF3:  STRCPY(code, "NFA_BACKREF3"); break;
  case NFA_BACKREF4:  STRCPY(code, "NFA_BACKREF4"); break;
  case NFA_BACKREF5:  STRCPY(code, "NFA_BACKREF5"); break;
  case NFA_BACKREF6:  STRCPY(code, "NFA_BACKREF6"); break;
  case NFA_BACKREF7:  STRCPY(code, "NFA_BACKREF7"); break;
  case NFA_BACKREF8:  STRCPY(code, "NFA_BACKREF8"); break;
  case NFA_BACKREF9:  STRCPY(code, "NFA_BACKREF9"); break;
  case NFA_ZREF1:     STRCPY(code, "NFA_ZREF1"); break;
  case NFA_ZREF2:     STRCPY(code, "NFA_ZREF2"); break;
  case NFA_ZREF3:     STRCPY(code, "NFA_ZREF3"); break;
  case NFA_ZREF4:     STRCPY(code, "NFA_ZREF4"); break;
  case NFA_ZREF5:     STRCPY(code, "NFA_ZREF5"); break;
  case NFA_ZREF6:     STRCPY(code, "NFA_ZREF6"); break;
  case NFA_ZREF7:     STRCPY(code, "NFA_ZREF7"); break;
  case NFA_ZREF8:     STRCPY(code, "NFA_ZREF8"); break;
  case NFA_ZREF9:     STRCPY(code, "NFA_ZREF9"); break;
  case NFA_SKIP:      STRCPY(code, "NFA_SKIP"); break;

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

  case NFA_NOPEN:             STRCPY(code, "NFA_NOPEN"); break;
  case NFA_NCLOSE:            STRCPY(code, "NFA_NCLOSE"); break;
  case NFA_START_INVISIBLE:   STRCPY(code, "NFA_START_INVISIBLE"); break;
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
  case NFA_START_PATTERN:   STRCPY(code, "NFA_START_PATTERN"); break;
  case NFA_END_INVISIBLE:     STRCPY(code, "NFA_END_INVISIBLE"); break;
  case NFA_END_INVISIBLE_NEG: STRCPY(code, "NFA_END_INVISIBLE_NEG"); break;
  case NFA_END_PATTERN:       STRCPY(code, "NFA_END_PATTERN"); break;

  case NFA_COMPOSING:         STRCPY(code, "NFA_COMPOSING"); break;
  case NFA_END_COMPOSING:     STRCPY(code, "NFA_END_COMPOSING"); break;
  case NFA_OPT_CHARS:         STRCPY(code, "NFA_OPT_CHARS"); break;

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
  case NFA_EOL:           STRCPY(code, "NFA_EOL "); break;
  case NFA_BOL:           STRCPY(code, "NFA_BOL "); break;
  case NFA_EOW:           STRCPY(code, "NFA_EOW "); break;
  case NFA_BOW:           STRCPY(code, "NFA_BOW "); break;
  case NFA_EOF:           STRCPY(code, "NFA_EOF "); break;
  case NFA_BOF:           STRCPY(code, "NFA_BOF "); break;
  case NFA_LNUM:          STRCPY(code, "NFA_LNUM "); break;
  case NFA_LNUM_GT:       STRCPY(code, "NFA_LNUM_GT "); break;
  case NFA_LNUM_LT:       STRCPY(code, "NFA_LNUM_LT "); break;
  case NFA_COL:           STRCPY(code, "NFA_COL "); break;
  case NFA_COL_GT:        STRCPY(code, "NFA_COL_GT "); break;
  case NFA_COL_LT:        STRCPY(code, "NFA_COL_LT "); break;
  case NFA_VCOL:          STRCPY(code, "NFA_VCOL "); break;
  case NFA_VCOL_GT:       STRCPY(code, "NFA_VCOL_GT "); break;
  case NFA_VCOL_LT:       STRCPY(code, "NFA_VCOL_LT "); break;
  case NFA_MARK:          STRCPY(code, "NFA_MARK "); break;
  case NFA_MARK_GT:       STRCPY(code, "NFA_MARK_GT "); break;
  case NFA_MARK_LT:       STRCPY(code, "NFA_MARK_LT "); break;
  case NFA_CURSOR:        STRCPY(code, "NFA_CURSOR "); break;
  case NFA_VISUAL:        STRCPY(code, "NFA_VISUAL "); break;
  case NFA_ANY_COMPOSING: STRCPY(code, "NFA_ANY_COMPOSING "); break;

  case NFA_STAR:          STRCPY(code, "NFA_STAR "); break;
  case NFA_STAR_NONGREEDY: STRCPY(code, "NFA_STAR_NONGREEDY "); break;
  case NFA_QUEST:         STRCPY(code, "NFA_QUEST"); break;
  case NFA_QUEST_NONGREEDY: STRCPY(code, "NFA_QUEST_NON_GREEDY"); break;
  case NFA_EMPTY:         STRCPY(code, "NFA_EMPTY"); break;
  case NFA_OR:            STRCPY(code, "NFA_OR"); break;

  case NFA_START_COLL:    STRCPY(code, "NFA_START_COLL"); break;
  case NFA_END_COLL:      STRCPY(code, "NFA_END_COLL"); break;
  case NFA_START_NEG_COLL: STRCPY(code, "NFA_START_NEG_COLL"); break;
  case NFA_END_NEG_COLL:  STRCPY(code, "NFA_END_NEG_COLL"); break;
  case NFA_RANGE:         STRCPY(code, "NFA_RANGE"); break;
  case NFA_RANGE_MIN:     STRCPY(code, "NFA_RANGE_MIN"); break;
  case NFA_RANGE_MAX:     STRCPY(code, "NFA_RANGE_MAX"); break;

  case NFA_CLASS_ALNUM:   STRCPY(code, "NFA_CLASS_ALNUM"); break;
  case NFA_CLASS_ALPHA:   STRCPY(code, "NFA_CLASS_ALPHA"); break;
  case NFA_CLASS_BLANK:   STRCPY(code, "NFA_CLASS_BLANK"); break;
  case NFA_CLASS_CNTRL:   STRCPY(code, "NFA_CLASS_CNTRL"); break;
  case NFA_CLASS_DIGIT:   STRCPY(code, "NFA_CLASS_DIGIT"); break;
  case NFA_CLASS_GRAPH:   STRCPY(code, "NFA_CLASS_GRAPH"); break;
  case NFA_CLASS_LOWER:   STRCPY(code, "NFA_CLASS_LOWER"); break;
  case NFA_CLASS_PRINT:   STRCPY(code, "NFA_CLASS_PRINT"); break;
  case NFA_CLASS_PUNCT:   STRCPY(code, "NFA_CLASS_PUNCT"); break;
  case NFA_CLASS_SPACE:   STRCPY(code, "NFA_CLASS_SPACE"); break;
  case NFA_CLASS_UPPER:   STRCPY(code, "NFA_CLASS_UPPER"); break;
  case NFA_CLASS_XDIGIT:  STRCPY(code, "NFA_CLASS_XDIGIT"); break;
  case NFA_CLASS_TAB:     STRCPY(code, "NFA_CLASS_TAB"); break;
  case NFA_CLASS_RETURN:  STRCPY(code, "NFA_CLASS_RETURN"); break;
  case NFA_CLASS_BACKSPACE:   STRCPY(code, "NFA_CLASS_BACKSPACE"); break;
  case NFA_CLASS_ESCAPE:  STRCPY(code, "NFA_CLASS_ESCAPE"); break;

  case NFA_ANY:   STRCPY(code, "NFA_ANY"); break;
  case NFA_IDENT: STRCPY(code, "NFA_IDENT"); break;
  case NFA_SIDENT: STRCPY(code, "NFA_SIDENT"); break;
  case NFA_KWORD: STRCPY(code, "NFA_KWORD"); break;
  case NFA_SKWORD: STRCPY(code, "NFA_SKWORD"); break;
  case NFA_FNAME: STRCPY(code, "NFA_FNAME"); break;
  case NFA_SFNAME: STRCPY(code, "NFA_SFNAME"); break;
  case NFA_PRINT: STRCPY(code, "NFA_PRINT"); break;
  case NFA_SPRINT: STRCPY(code, "NFA_SPRINT"); break;
  case NFA_WHITE: STRCPY(code, "NFA_WHITE"); break;
  case NFA_NWHITE: STRCPY(code, "NFA_NWHITE"); break;
  case NFA_DIGIT: STRCPY(code, "NFA_DIGIT"); break;
  case NFA_NDIGIT: STRCPY(code, "NFA_NDIGIT"); break;
  case NFA_HEX:   STRCPY(code, "NFA_HEX"); break;
  case NFA_NHEX:  STRCPY(code, "NFA_NHEX"); break;
  case NFA_OCTAL: STRCPY(code, "NFA_OCTAL"); break;
  case NFA_NOCTAL: STRCPY(code, "NFA_NOCTAL"); break;
  case NFA_WORD:  STRCPY(code, "NFA_WORD"); break;
  case NFA_NWORD: STRCPY(code, "NFA_NWORD"); break;
  case NFA_HEAD:  STRCPY(code, "NFA_HEAD"); break;
  case NFA_NHEAD: STRCPY(code, "NFA_NHEAD"); break;
  case NFA_ALPHA: STRCPY(code, "NFA_ALPHA"); break;
  case NFA_NALPHA: STRCPY(code, "NFA_NALPHA"); break;
  case NFA_LOWER: STRCPY(code, "NFA_LOWER"); break;
  case NFA_NLOWER: STRCPY(code, "NFA_NLOWER"); break;
  case NFA_UPPER: STRCPY(code, "NFA_UPPER"); break;
  case NFA_NUPPER: STRCPY(code, "NFA_NUPPER"); break;
  case NFA_LOWER_IC:  STRCPY(code, "NFA_LOWER_IC"); break;
  case NFA_NLOWER_IC: STRCPY(code, "NFA_NLOWER_IC"); break;
  case NFA_UPPER_IC:  STRCPY(code, "NFA_UPPER_IC"); break;
  case NFA_NUPPER_IC: STRCPY(code, "NFA_NUPPER_IC"); break;

  default:
    STRCPY(code, "CHAR(x)");
    code[5] = c;
  }

  if (addnl == TRUE)
    STRCAT(code, " + NEWLINE ");

}

static FILE *log_fd;

/*
 * Print the postfix notation of the current regexp.
 */
static void nfa_postfix_dump(char_u *expr, int retval)
{
  int *p;
  FILE *f;

  f = fopen(NFA_REGEXP_DUMP_LOG, "a");
  if (f != NULL) {
    fprintf(f, "\n-------------------------\n");
    if (retval == FAIL)
      fprintf(f, ">>> NFA engine failed ... \n");
    else if (retval == OK)
      fprintf(f, ">>> NFA engine succeeded !\n");
    fprintf(f, "Regexp: \"%s\"\nPostfix notation (char): \"", expr);
    for (p = post_start; *p && p < post_ptr; p++) {
      nfa_set_code(*p);
      fprintf(f, "%s, ", code);
    }
    fprintf(f, "\"\nPostfix notation (int): ");
    for (p = post_start; *p && p < post_ptr; p++)
      fprintf(f, "%d ", *p);
    fprintf(f, "\n\n");
    fclose(f);
  }
}

/*
 * Print the NFA starting with a root node "state".
 */
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
  char_u  *p;

  if (state == NULL)
    return;

  fprintf(debugf, "(%2d)", abs(state->id));

  /* Output indent */
  p = (char_u *)indent->ga_data;
  if (indent->ga_len >= 3) {
    int last = indent->ga_len - 3;
    char_u save[2];

    STRNCPY(save, &p[last], 2);
    STRNCPY(&p[last], "+-", 2);
    fprintf(debugf, " %s", p);
    STRNCPY(&p[last], save, 2);
  } else
    fprintf(debugf, " %s", p);

  nfa_set_code(state->c);
  fprintf(debugf, "%s (%d) (id=%d) val=%d\n",
      code,
      state->c,
      abs(state->id),
      state->val);
  if (state->id < 0)
    return;

  state->id = abs(state->id) * -1;

  /* grow indent for state->out */
  indent->ga_len -= 1;
  if (state->out1)
    ga_concat(indent, (char_u *)"| ");
  else
    ga_concat(indent, (char_u *)"  ");
  ga_append(indent, '\0');

  nfa_print_state2(debugf, state->out, indent);

  /* replace last part of indent for state->out1 */
  indent->ga_len -= 3;
  ga_concat(indent, (char_u *)"  ");
  ga_append(indent, '\0');

  nfa_print_state2(debugf, state->out1, indent);

  /* shrink indent */
  indent->ga_len -= 3;
  ga_append(indent, '\0');
}

/*
 * Print the NFA state machine.
 */
static void nfa_dump(nfa_regprog_T *prog)
{
  FILE *debugf = fopen(NFA_REGEXP_DUMP_LOG, "a");

  if (debugf != NULL) {
    nfa_print_state(debugf, prog->start);

    if (prog->reganch)
      fprintf(debugf, "reganch: %d\n", prog->reganch);
    if (prog->regstart != NUL)
      fprintf(debugf, "regstart: %c (decimal: %d)\n",
          prog->regstart, prog->regstart);
    if (prog->match_text != NULL)
      fprintf(debugf, "match_text: \"%s\"\n", prog->match_text);

    fclose(debugf);
  }
}
#endif      /* REGEXP_DEBUG */

/*
 * Parse r.e. @expr and convert it into postfix form.
 * Return the postfix string on success, NULL otherwise.
 */
static int *re2post(void)
{
  if (nfa_reg(REG_NOPAREN) == FAIL)
    return NULL;
  EMIT(NFA_MOPEN);
  return post_start;
}

/* NB. Some of the code below is inspired by Russ's. */

/*
 * Represents an NFA state plus zero or one or two arrows exiting.
 * if c == MATCH, no arrows out; matching state.
 * If c == SPLIT, unlabeled arrows to out and out1 (if != NULL).
 * If c < 256, labeled arrow with character c to out.
 */

static nfa_state_T      *state_ptr; /* points to nfa_prog->state */

/*
 * Allocate and initialize nfa_state_T.
 */
static nfa_state_T *alloc_state(int c, nfa_state_T *out, nfa_state_T *out1)
{
  nfa_state_T *s;

  if (istate >= nstate)
    return NULL;

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

/*
 * A partially built NFA without the matching state filled in.
 * Frag_T.start points at the start state.
 * Frag_T.out is a list of places that need to be set to the
 * next state for this fragment.
 */


/*
 * Initialize a Frag_T struct and return it.
 */
static Frag_T frag(nfa_state_T *start, Ptrlist *out)
{
  Frag_T n;

  n.start = start;
  n.out = out;
  return n;
}

/*
 * Create singleton list containing just outp.
 */
static Ptrlist *list1(nfa_state_T **outp)
{
  Ptrlist *l;

  l = (Ptrlist *)outp;
  l->next = NULL;
  return l;
}

/*
 * Patch the list of states at out to point to start.
 */
static void patch(Ptrlist *l, nfa_state_T *s)
{
  Ptrlist *next;

  for (; l; l = next) {
    next = l->next;
    l->s = s;
  }
}


/*
 * Join the two lists l1 and l2, returning the combination.
 */
static Ptrlist *append(Ptrlist *l1, Ptrlist *l2)
{
  Ptrlist *oldl1;

  oldl1 = l1;
  while (l1->next)
    l1 = l1->next;
  l1->next = l2;
  return oldl1;
}

/*
 * Stack used for transforming postfix form into NFA.
 */
static Frag_T empty;

static void st_error(int *postfix, int *end, int *p)
{
#ifdef NFA_REGEXP_ERROR_LOG
  FILE *df;
  int *p2;

  df = fopen(NFA_REGEXP_ERROR_LOG, "a");
  if (df) {
    fprintf(df, "Error popping the stack!\n");
#ifdef REGEXP_DEBUG
    fprintf(df, "Current regexp is \"%s\"\n", nfa_regengine.expr);
#endif
    fprintf(df, "Postfix form is: ");
#ifdef REGEXP_DEBUG
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
#else
    for (p2 = postfix; p2 < end; p2++) {
      fprintf(df, "%d, ", *p2);
    }
    fprintf(df, "\nCurrent position is: ");
    for (p2 = postfix; p2 <= p; p2++) {
      fprintf(df, "%d, ", *p2);
    }
#endif
    fprintf(df, "\n--------------------------\n");
    fclose(df);
  }
#endif
  EMSG(_("E874: (NFA) Could not pop the stack !"));
}

/*
 * Push an item onto the stack.
 */
static void st_push(Frag_T s, Frag_T **p, Frag_T *stack_end)
{
  Frag_T *stackp = *p;

  if (stackp >= stack_end)
    return;
  *stackp = s;
  *p = *p + 1;
}

/*
 * Pop an item from the stack.
 */
static Frag_T st_pop(Frag_T **p, Frag_T *stack)
{
  Frag_T *stackp;

  *p = *p - 1;
  stackp = *p;
  if (stackp < stack)
    return empty;
  return **p;
}

/*
 * Estimate the maximum byte length of anything matching "state".
 * When unknown or unlimited return -1.
 */
static int nfa_max_width(nfa_state_T *startstate, int depth)
{
  int l, r;
  nfa_state_T     *state = startstate;
  int len = 0;

  /* detect looping in a NFA_SPLIT */
  if (depth > 4)
    return -1;

  while (state != NULL) {
    switch (state->c) {
    case NFA_END_INVISIBLE:
    case NFA_END_INVISIBLE_NEG:
      /* the end, return what we have */
      return len;

    case NFA_SPLIT:
      /* two alternatives, use the maximum */
      l = nfa_max_width(state->out, depth + 1);
      r = nfa_max_width(state->out1, depth + 1);
      if (l < 0 || r < 0)
        return -1;
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
      /* ascii */
      ++len;
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
      /* possibly non-ascii */
      if (has_mbyte)
        len += 3;
      else
        ++len;
      break;

    case NFA_START_INVISIBLE:
    case NFA_START_INVISIBLE_NEG:
    case NFA_START_INVISIBLE_BEFORE:
    case NFA_START_INVISIBLE_BEFORE_NEG:
      /* zero-width, out1 points to the END state */
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
      /* unknown width */
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
      /* zero-width */
      break;

    default:
      if (state->c < 0)
        /* don't know what this is */
        return -1;
      /* normal character */
      len += MB_CHAR2LEN(state->c);
      break;
    }

    /* normal way to continue */
    state = state->out;
  }

  /* unrecognized, "cannot happen" */
  return -1;
}

/*
 * Convert a postfix form into its equivalent NFA.
 * Return the NFA start state on success, NULL otherwise.
 */
static nfa_state_T *post2nfa(int *postfix, int *end, int nfa_calc_size)
{
  int         *p;
  int mopen;
  int mclose;
  Frag_T      *stack = NULL;
  Frag_T      *stackp = NULL;
  Frag_T      *stack_end = NULL;
  Frag_T e1;
  Frag_T e2;
  Frag_T e;
  nfa_state_T *s;
  nfa_state_T *s1;
  nfa_state_T *matchstate;
  nfa_state_T *ret = NULL;

  if (postfix == NULL)
    return NULL;

#define PUSH(s)     st_push((s), &stackp, stack_end)
#define POP()       st_pop(&stackp, stack); \
  if (stackp < stack) { \
    st_error(postfix, end, p); \
    xfree(stack); \
    return NULL; \
  }

  if (nfa_calc_size == FALSE) {
    /* Allocate space for the stack. Max states on the stack : nstate */
    stack = xmalloc((nstate + 1) * sizeof(Frag_T));
    stackp = stack;
    stack_end = stack + (nstate + 1);
  }

  for (p = postfix; p < end; ++p) {
    switch (*p) {
    case NFA_CONCAT:
      /* Concatenation.
       * Pay attention: this operator does not exist in the r.e. itself
       * (it is implicit, really).  It is added when r.e. is translated
       * to postfix form in re2post(). */
      if (nfa_calc_size == TRUE) {
        /* nstate += 0; */
        break;
      }
      e2 = POP();
      e1 = POP();
      patch(e1.out, e2.start);
      PUSH(frag(e1.start, e2.out));
      break;

    case NFA_OR:
      /* Alternation */
      if (nfa_calc_size == TRUE) {
        nstate++;
        break;
      }
      e2 = POP();
      e1 = POP();
      s = alloc_state(NFA_SPLIT, e1.start, e2.start);
      if (s == NULL)
        goto theend;
      PUSH(frag(s, append(e1.out, e2.out)));
      break;

    case NFA_STAR:
      /* Zero or more, prefer more */
      if (nfa_calc_size == TRUE) {
        nstate++;
        break;
      }
      e = POP();
      s = alloc_state(NFA_SPLIT, e.start, NULL);
      if (s == NULL)
        goto theend;
      patch(e.out, s);
      PUSH(frag(s, list1(&s->out1)));
      break;

    case NFA_STAR_NONGREEDY:
      /* Zero or more, prefer zero */
      if (nfa_calc_size == TRUE) {
        nstate++;
        break;
      }
      e = POP();
      s = alloc_state(NFA_SPLIT, NULL, e.start);
      if (s == NULL)
        goto theend;
      patch(e.out, s);
      PUSH(frag(s, list1(&s->out)));
      break;

    case NFA_QUEST:
      /* one or zero atoms=> greedy match */
      if (nfa_calc_size == TRUE) {
        nstate++;
        break;
      }
      e = POP();
      s = alloc_state(NFA_SPLIT, e.start, NULL);
      if (s == NULL)
        goto theend;
      PUSH(frag(s, append(e.out, list1(&s->out1))));
      break;

    case NFA_QUEST_NONGREEDY:
      /* zero or one atoms => non-greedy match */
      if (nfa_calc_size == TRUE) {
        nstate++;
        break;
      }
      e = POP();
      s = alloc_state(NFA_SPLIT, NULL, e.start);
      if (s == NULL)
        goto theend;
      PUSH(frag(s, append(e.out, list1(&s->out))));
      break;

    case NFA_END_COLL:
    case NFA_END_NEG_COLL:
      /* On the stack is the sequence starting with NFA_START_COLL or
       * NFA_START_NEG_COLL and all possible characters. Patch it to
       * add the output to the start. */
      if (nfa_calc_size == TRUE) {
        nstate++;
        break;
      }
      e = POP();
      s = alloc_state(NFA_END_COLL, NULL, NULL);
      if (s == NULL)
        goto theend;
      patch(e.out, s);
      e.start->out1 = s;
      PUSH(frag(e.start, list1(&s->out)));
      break;

    case NFA_RANGE:
      /* Before this are two characters, the low and high end of a
       * range.  Turn them into two states with MIN and MAX. */
      if (nfa_calc_size == TRUE) {
        /* nstate += 0; */
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
      /* 0-length, used in a repetition with max/min count of 0 */
      if (nfa_calc_size == TRUE) {
        nstate++;
        break;
      }
      s = alloc_state(NFA_EMPTY, NULL, NULL);
      if (s == NULL)
        goto theend;
      PUSH(frag(s, list1(&s->out)));
      break;

    case NFA_OPT_CHARS:
    {
      int n;

      /* \%[abc] implemented as:
       *    NFA_SPLIT
       *    +-CHAR(a)
       *    | +-NFA_SPLIT
       *    |   +-CHAR(b)
       *    |   | +-NFA_SPLIT
       *    |   |   +-CHAR(c)
       *    |   |   | +-next
       *    |   |   +- next
       *    |   +- next
       *    +- next
       */
      n = *++p;       /* get number of characters */
      if (nfa_calc_size == TRUE) {
        nstate += n;
        break;
      }
      s = NULL;       /* avoid compiler warning */
      e1.out = NULL;       /* stores list with out1's */
      s1 = NULL;       /* previous NFA_SPLIT to connect to */
      while (n-- > 0) {
        e = POP();         /* get character */
        s = alloc_state(NFA_SPLIT, e.start, NULL);
        if (s == NULL)
          goto theend;
        if (e1.out == NULL)
          e1 = e;
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
    case NFA_PREV_ATOM_LIKE_PATTERN:
    {
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
      default:           /* NFA_PREV_ATOM_LIKE_PATTERN: */
        start_state = NFA_START_PATTERN;
        end_state = NFA_END_PATTERN;
        break;
      }

      if (before)
        n = *++p;         /* get the count */

      /* The \@= operator: match the preceding atom with zero width.
       * The \@! operator: no match for the preceding atom.
       * The \@<= operator: match for the preceding atom.
       * The \@<! operator: no match for the preceding atom.
       * Surrounds the preceding atom with START_INVISIBLE and
       * END_INVISIBLE, similarly to MOPEN. */

      if (nfa_calc_size == TRUE) {
        nstate += pattern ? 4 : 2;
        break;
      }
      e = POP();
      s1 = alloc_state(end_state, NULL, NULL);
      if (s1 == NULL)
        goto theend;

      s = alloc_state(start_state, e.start, s1);
      if (s == NULL)
        goto theend;
      if (pattern) {
        /* NFA_ZEND -> NFA_END_PATTERN -> NFA_SKIP -> what follows. */
        skip = alloc_state(NFA_SKIP, NULL, NULL);
        zend = alloc_state(NFA_ZEND, s1, NULL);
        s1->out= skip;
        patch(e.out, zend);
        PUSH(frag(s, list1(&skip->out)));
      } else {
        patch(e.out, s1);
        PUSH(frag(s, list1(&s1->out)));
        if (before) {
          if (n <= 0)
            /* See if we can guess the maximum width, it avoids a
             * lot of pointless tries. */
            n = nfa_max_width(e.start, 0);
          s->val = n;           /* store the count */
        }
      }
      break;
    }

    case NFA_COMPOSING:         /* char with composing char */
    /* FALLTHROUGH */

    case NFA_MOPEN:     /* \( \) Submatch */
    case NFA_MOPEN1:
    case NFA_MOPEN2:
    case NFA_MOPEN3:
    case NFA_MOPEN4:
    case NFA_MOPEN5:
    case NFA_MOPEN6:
    case NFA_MOPEN7:
    case NFA_MOPEN8:
    case NFA_MOPEN9:
    case NFA_ZOPEN:     /* \z( \) Submatch */
    case NFA_ZOPEN1:
    case NFA_ZOPEN2:
    case NFA_ZOPEN3:
    case NFA_ZOPEN4:
    case NFA_ZOPEN5:
    case NFA_ZOPEN6:
    case NFA_ZOPEN7:
    case NFA_ZOPEN8:
    case NFA_ZOPEN9:
    case NFA_NOPEN:     /* \%( \) "Invisible Submatch" */
      if (nfa_calc_size == TRUE) {
        nstate += 2;
        break;
      }

      mopen = *p;
      switch (*p) {
      case NFA_NOPEN: mclose = NFA_NCLOSE; break;
      case NFA_ZOPEN: mclose = NFA_ZCLOSE; break;
      case NFA_ZOPEN1: mclose = NFA_ZCLOSE1; break;
      case NFA_ZOPEN2: mclose = NFA_ZCLOSE2; break;
      case NFA_ZOPEN3: mclose = NFA_ZCLOSE3; break;
      case NFA_ZOPEN4: mclose = NFA_ZCLOSE4; break;
      case NFA_ZOPEN5: mclose = NFA_ZCLOSE5; break;
      case NFA_ZOPEN6: mclose = NFA_ZCLOSE6; break;
      case NFA_ZOPEN7: mclose = NFA_ZCLOSE7; break;
      case NFA_ZOPEN8: mclose = NFA_ZCLOSE8; break;
      case NFA_ZOPEN9: mclose = NFA_ZCLOSE9; break;
      case NFA_COMPOSING: mclose = NFA_END_COMPOSING; break;
      default:
        /* NFA_MOPEN, NFA_MOPEN1 .. NFA_MOPEN9 */
        mclose = *p + NSUBEXP;
        break;
      }

      /* Allow "NFA_MOPEN" as a valid postfix representation for
       * the empty regexp "". In this case, the NFA will be
       * NFA_MOPEN -> NFA_MCLOSE. Note that this also allows
       * empty groups of parenthesis, and empty mbyte chars */
      if (stackp == stack) {
        s = alloc_state(mopen, NULL, NULL);
        if (s == NULL)
          goto theend;
        s1 = alloc_state(mclose, NULL, NULL);
        if (s1 == NULL)
          goto theend;
        patch(list1(&s->out), s1);
        PUSH(frag(s, list1(&s1->out)));
        break;
      }

      /* At least one node was emitted before NFA_MOPEN, so
       * at least one node will be between NFA_MOPEN and NFA_MCLOSE */
      e = POP();
      s = alloc_state(mopen, e.start, NULL);         /* `(' */
      if (s == NULL)
        goto theend;

      s1 = alloc_state(mclose, NULL, NULL);         /* `)' */
      if (s1 == NULL)
        goto theend;
      patch(e.out, s1);

      if (mopen == NFA_COMPOSING)
        /* COMPOSING->out1 = END_COMPOSING */
        patch(list1(&s->out1), s1);

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
      if (nfa_calc_size == TRUE) {
        nstate += 2;
        break;
      }
      s = alloc_state(*p, NULL, NULL);
      if (s == NULL)
        goto theend;
      s1 = alloc_state(NFA_SKIP, NULL, NULL);
      if (s1 == NULL)
        goto theend;
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
    case NFA_MARK_LT:
    {
      int n = *++p;       /* lnum, col or mark name */

      if (nfa_calc_size == TRUE) {
        nstate += 1;
        break;
      }
      s = alloc_state(p[-1], NULL, NULL);
      if (s == NULL)
        goto theend;
      s->val = n;
      PUSH(frag(s, list1(&s->out)));
      break;
    }

    case NFA_ZSTART:
    case NFA_ZEND:
    default:
      /* Operands */
      if (nfa_calc_size == TRUE) {
        nstate++;
        break;
      }
      s = alloc_state(*p, NULL, NULL);
      if (s == NULL)
        goto theend;
      PUSH(frag(s, list1(&s->out)));
      break;

    }     /* switch(*p) */

  }   /* for(p = postfix; *p; ++p) */

  if (nfa_calc_size == TRUE) {
    nstate++;
    goto theend;        /* Return value when counting size is ignored anyway */
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

  matchstate = &state_ptr[istate++];   /* the match state */
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

/*
 * After building the NFA program, inspect it to add optimization hints.
 */
static void nfa_postprocess(nfa_regprog_T *prog)
{
  int i;
  int c;

  for (i = 0; i < prog->nstate; ++i) {
    c = prog->state[i].c;
    if (c == NFA_START_INVISIBLE
        || c == NFA_START_INVISIBLE_NEG
        || c == NFA_START_INVISIBLE_BEFORE
        || c == NFA_START_INVISIBLE_BEFORE_NEG) {
      int directly;

      /* Do it directly when what follows is possibly the end of the
       * match. */
      if (match_follows(prog->state[i].out1->out, 0))
        directly = TRUE;
      else {
        int ch_invisible = failure_chance(prog->state[i].out, 0);
        int ch_follows = failure_chance(prog->state[i].out1->out, 0);

        /* Postpone when the invisible match is expensive or has a
         * lower chance of failing. */
        if (c == NFA_START_INVISIBLE_BEFORE
            || c == NFA_START_INVISIBLE_BEFORE_NEG) {
          /* "before" matches are very expensive when
           * unbounded, always prefer what follows then,
           * unless what follows will always match.
           * Otherwise strongly prefer what follows. */
          if (prog->state[i].val <= 0 && ch_follows > 0)
            directly = FALSE;
          else
            directly = ch_follows * 10 < ch_invisible;
        } else {
          /* normal invisible, first do the one with the
           * highest failure chance */
          directly = ch_follows < ch_invisible;
        }
      }
      if (directly)
        /* switch to the _FIRST state */
        ++prog->state[i].c;
    }
  }
}

/****************************************************************
* NFA execution code.
****************************************************************/

/* Values for done in nfa_pim_T. */
#define NFA_PIM_UNUSED   0      /* pim not used */
#define NFA_PIM_TODO     1      /* pim not done yet */
#define NFA_PIM_MATCH    2      /* pim executed, matches */
#define NFA_PIM_NOMATCH  3      /* pim executed, no match */


#ifdef REGEXP_DEBUG
static void log_subsexpr(regsubs_T *subs)
{
  log_subexpr(&subs->norm);
  if (nfa_has_zsubexpr)
    log_subexpr(&subs->synt);
}

static void log_subexpr(regsub_T *sub)
{
  int j;

  for (j = 0; j < sub->in_use; j++)
    if (REG_MULTI)
      fprintf(log_fd, "*** group %d, start: c=%d, l=%d, end: c=%d, l=%d\n",
          j,
          sub->list.multi[j].start_col,
          (int)sub->list.multi[j].start_lnum,
          sub->list.multi[j].end_col,
          (int)sub->list.multi[j].end_lnum);
    else {
      char *s = (char *)sub->list.line[j].start;
      char *e = (char *)sub->list.line[j].end;

      fprintf(log_fd, "*** group %d, start: \"%s\", end: \"%s\"\n",
          j,
          s == NULL ? "NULL" : s,
          e == NULL ? "NULL" : e);
    }
}

static char *pim_info(nfa_pim_T *pim)
{
  static char buf[30];

  if (pim == NULL || pim->result == NFA_PIM_UNUSED)
    buf[0] = NUL;
  else {
    sprintf(buf, " PIM col %d", REG_MULTI ? (int)pim->end.pos.col
        : (int)(pim->end.ptr - reginput));
  }
  return buf;
}

#endif

// Used during execution: whether a match has been found.
static int nfa_match;
static proftime_T *nfa_time_limit;
static int nfa_time_count;

// Copy postponed invisible match info from "from" to "to".
static void copy_pim(nfa_pim_T *to, nfa_pim_T *from)
{
  to->result = from->result;
  to->state = from->state;
  copy_sub(&to->subs.norm, &from->subs.norm);
  if (nfa_has_zsubexpr)
    copy_sub(&to->subs.synt, &from->subs.synt);
  to->end = from->end;
}

static void clear_sub(regsub_T *sub)
{
  if (REG_MULTI)
    /* Use 0xff to set lnum to -1 */
    memset(sub->list.multi, 0xff,
        sizeof(struct multipos) * nfa_nsubexpr);
  else
    memset(sub->list.line, 0, sizeof(struct linepos) * nfa_nsubexpr);
  sub->in_use = 0;
}

/*
 * Copy the submatches from "from" to "to".
 */
static void copy_sub(regsub_T *to, regsub_T *from)
{
  to->in_use = from->in_use;
  if (from->in_use > 0) {
    /* Copy the match start and end positions. */
    if (REG_MULTI)
      memmove(&to->list.multi[0],
          &from->list.multi[0],
          sizeof(struct multipos) * from->in_use);
    else
      memmove(&to->list.line[0],
          &from->list.line[0],
          sizeof(struct linepos) * from->in_use);
  }
}

/*
 * Like copy_sub() but exclude the main match.
 */
static void copy_sub_off(regsub_T *to, regsub_T *from)
{
  if (to->in_use < from->in_use)
    to->in_use = from->in_use;
  if (from->in_use > 1) {
    /* Copy the match start and end positions. */
    if (REG_MULTI)
      memmove(&to->list.multi[1],
          &from->list.multi[1],
          sizeof(struct multipos) * (from->in_use - 1));
    else
      memmove(&to->list.line[1],
          &from->list.line[1],
          sizeof(struct linepos) * (from->in_use - 1));
  }
}

/*
 * Like copy_sub() but only do the end of the main match if \ze is present.
 */
static void copy_ze_off(regsub_T *to, regsub_T *from)
{
  if (nfa_has_zend) {
    if (REG_MULTI) {
      if (from->list.multi[0].end_lnum >= 0){
        to->list.multi[0].end_lnum = from->list.multi[0].end_lnum;
        to->list.multi[0].end_col = from->list.multi[0].end_col;
      }
    } else {
      if (from->list.line[0].end != NULL)
        to->list.line[0].end = from->list.line[0].end;
    }
  }
}

// Return TRUE if "sub1" and "sub2" have the same start positions.
// When using back-references also check the end position.
static int sub_equal(regsub_T *sub1, regsub_T *sub2)
{
  int i;
  int todo;
  linenr_T s1;
  linenr_T s2;
  char_u      *sp1;
  char_u      *sp2;

  todo = sub1->in_use > sub2->in_use ? sub1->in_use : sub2->in_use;
  if (REG_MULTI) {
    for (i = 0; i < todo; ++i) {
      if (i < sub1->in_use)
        s1 = sub1->list.multi[i].start_lnum;
      else
        s1 = -1;
      if (i < sub2->in_use)
        s2 = sub2->list.multi[i].start_lnum;
      else
        s2 = -1;
      if (s1 != s2)
        return FALSE;
      if (s1 != -1 && sub1->list.multi[i].start_col
          != sub2->list.multi[i].start_col)
        return FALSE;

      if (nfa_has_backref) {
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
          return FALSE;
        }
        if (s1 != -1
            && sub1->list.multi[i].end_col != sub2->list.multi[i].end_col) {
          return FALSE;
        }
      }
    }
  } else {
    for (i = 0; i < todo; ++i) {
      if (i < sub1->in_use)
        sp1 = sub1->list.line[i].start;
      else
        sp1 = NULL;
      if (i < sub2->in_use)
        sp2 = sub2->list.line[i].start;
      else
        sp2 = NULL;
      if (sp1 != sp2)
        return FALSE;

      if (nfa_has_backref) {
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
          return FALSE;
        }
      }
    }
  }

  return TRUE;
}

#ifdef REGEXP_DEBUG
static void report_state(char *action,
    regsub_T *sub,
    nfa_state_T *state,
    int lid,
    nfa_pim_T *pim) {
  int col;

  if (sub->in_use <= 0)
    col = -1;
  else if (REG_MULTI)
    col = sub->list.multi[0].start_col;
  else
    col = (int)(sub->list.line[0].start - regline);
  nfa_set_code(state->c);
  fprintf(log_fd, "> %s state %d to list %d. char %d: %s (start col %d)%s\n",
      action, abs(state->id), lid, state->c, code, col,
      pim_info(pim));
}

#endif

/*
 * Return TRUE if the same state is already in list "l" with the same
 * positions as "subs".
 */
static int 
has_state_with_pos (
    nfa_list_T *l,         /* runtime state list */
    nfa_state_T *state,     /* state to update */
    regsubs_T *subs,      /* pointers to subexpressions */
    nfa_pim_T *pim       /* postponed match or NULL */
)
{
  nfa_thread_T        *thread;
  int i;

  for (i = 0; i < l->n; ++i) {
    thread = &l->t[i];
    if (thread->state->id == state->id
        && sub_equal(&thread->subs.norm, &subs->norm)
        && (!nfa_has_zsubexpr
            || sub_equal(&thread->subs.synt, &subs->synt))
        && pim_equal(&thread->pim, pim))
      return TRUE;
  }
  return FALSE;
}

/*
 * Return TRUE if "one" and "two" are equal.  That includes when both are not
 * set.
 */
static int pim_equal(nfa_pim_T *one, nfa_pim_T *two)
{
  int one_unused = (one == NULL || one->result == NFA_PIM_UNUSED);
  int two_unused = (two == NULL || two->result == NFA_PIM_UNUSED);

  if (one_unused)
    /* one is unused: equal when two is also unused */
    return two_unused;
  if (two_unused)
    /* one is used and two is not: not equal */
    return FALSE;
  /* compare the state id */
  if (one->state->id != two->state->id)
    return FALSE;
  /* compare the position */
  if (REG_MULTI)
    return one->end.pos.lnum == two->end.pos.lnum
           && one->end.pos.col == two->end.pos.col;
  return one->end.ptr == two->end.ptr;
}

/*
 * Return TRUE if "state" leads to a NFA_MATCH without advancing the input.
 */
static int match_follows(nfa_state_T *startstate, int depth)
{
  nfa_state_T     *state = startstate;

  /* avoid too much recursion */
  if (depth > 10)
    return FALSE;

  while (state != NULL) {
    switch (state->c) {
    case NFA_MATCH:
    case NFA_MCLOSE:
    case NFA_END_INVISIBLE:
    case NFA_END_INVISIBLE_NEG:
    case NFA_END_PATTERN:
      return TRUE;

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
      /* skip ahead to next state */
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
      /* state will advance input */
      return FALSE;

    default:
      if (state->c > 0)
        /* state will advance input */
        return FALSE;

      /* Others: zero-width or possibly zero-width, might still find
       * a match at the same position, keep looking. */
      break;
    }
    state = state->out;
  }
  return FALSE;
}


/*
 * Return TRUE if "state" is already in list "l".
 */
static int 
state_in_list (
    nfa_list_T *l,         /* runtime state list */
    nfa_state_T *state,     /* state to update */
    regsubs_T *subs      /* pointers to subexpressions */
)
{
  if (state->lastlist[nfa_ll_index] == l->id) {
    if (!nfa_has_backref || has_state_with_pos(l, state, subs, NULL))
      return TRUE;
  }
  return FALSE;
}

// Offset used for "off" by addstate_here().
#define ADDSTATE_HERE_OFFSET 10

// Add "state" and possibly what follows to state list ".".
// Returns "subs_arg", possibly copied into temp_subs.
static regsubs_T *
addstate (
    nfa_list_T *l,             /* runtime state list */
    nfa_state_T *state,         /* state to update */
    regsubs_T *subs_arg,      /* pointers to subexpressions */
    nfa_pim_T *pim,           /* postponed look-behind match */
    int off_arg)    /* byte offset, when -1 go to next line */
{
  int subidx;
  int off = off_arg;
  int add_here = FALSE;
  int listindex = 0;
  int k;
  int found = FALSE;
  nfa_thread_T        *thread;
  struct multipos     save_multipos;
  int save_in_use;
  char_u              *save_ptr;
  int i;
  regsub_T            *sub;
  regsubs_T           *subs = subs_arg;
  static regsubs_T temp_subs;
#ifdef REGEXP_DEBUG
  int did_print = FALSE;
#endif

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
    /* These nodes are not added themselves but their "out" and/or
     * "out1" may be added below.  */
    break;

  case NFA_BOL:
  case NFA_BOF:
    /* "^" won't match past end-of-line, don't bother trying.
     * Except when at the end of the line, or when we are going to the
     * next line for a look-behind match. */
    if (reginput > regline
        && *reginput != NUL
        && (nfa_endp == NULL
            || !REG_MULTI
            || reglnum == nfa_endp->se_u.pos.lnum))
      goto skip_add;
  /* FALLTHROUGH */

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
  /* These nodes need to be added so that we can bail out when it
   * was added to this list before at the same position to avoid an
   * endless loop for "\(\)*" */

  default:
    if (state->lastlist[nfa_ll_index] == l->id && state->c != NFA_SKIP) {
      /* This state is already in the list, don't add it again,
       * unless it is an MOPEN that is used for a backreference or
       * when there is a PIM. For NFA_MATCH check the position,
       * lower position is preferred. */
      if (!nfa_has_backref && pim == NULL && !l->has_pim
          && state->c != NFA_MATCH) {

        /* When called from addstate_here() do insert before
         * existing states. */
        if (add_here) {
          for (k = 0; k < l->n && k < listindex; ++k) {
            if (l->t[k].state->id == state->id) {
              found = TRUE;
              break;
            }
          }
        }

        if (!add_here || found) {
skip_add:
#ifdef REGEXP_DEBUG
          nfa_set_code(state->c);
          fprintf(log_fd, "> Not adding state %d to list %d. char %d: %s pim: %s has_pim: %d found: %d\n",
                  abs(state->id), l->id, state->c, code,
                  pim == NULL ? "NULL" : "yes", l->has_pim, found);
#endif
        return subs;
        }
      }

      /* Do not add the state again when it exists with the same
       * positions. */
      if (has_state_with_pos(l, state, subs, pim))
        goto skip_add;
    }

    /* When there are backreferences or PIMs the number of states may
     * be (a lot) bigger than anticipated. */
    if (l->n == l->len) {
      int newlen = l->len * 3 / 2 + 50;

      if (subs != &temp_subs) {
        /* "subs" may point into the current array, need to make a
         * copy before it becomes invalid. */
        copy_sub(&temp_subs.norm, &subs->norm);
        if (nfa_has_zsubexpr)
          copy_sub(&temp_subs.synt, &subs->synt);
        subs = &temp_subs;
      }

      l->t = xrealloc(l->t, newlen * sizeof(nfa_thread_T));
      l->len = newlen;
    }

    /* add the state to the list */
    state->lastlist[nfa_ll_index] = l->id;
    thread = &l->t[l->n++];
    thread->state = state;
    if (pim == NULL)
      thread->pim.result = NFA_PIM_UNUSED;
    else {
      copy_pim(&thread->pim, pim);
      l->has_pim = TRUE;
    }
    copy_sub(&thread->subs.norm, &subs->norm);
    if (nfa_has_zsubexpr)
      copy_sub(&thread->subs.synt, &subs->synt);
#ifdef REGEXP_DEBUG
    report_state("Adding", &thread->subs.norm, state, l->id, pim);
    did_print = TRUE;
#endif
  }

#ifdef REGEXP_DEBUG
  if (!did_print)
    report_state("Processing", &subs->norm, state, l->id, pim);
#endif
  switch (state->c) {
  case NFA_MATCH:
    break;

  case NFA_SPLIT:
    /* order matters here */
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

    /* avoid compiler warnings */
    save_ptr = NULL;
    memset(&save_multipos, 0, sizeof(save_multipos));

    /* Set the position (with "off" added) in the subexpression.  Save
     * and restore it when it was in use.  Otherwise fill any gap. */
    if (REG_MULTI) {
      if (subidx < sub->in_use) {
        save_multipos = sub->list.multi[subidx];
        save_in_use = -1;
      } else {
        save_in_use = sub->in_use;
        for (i = sub->in_use; i < subidx; ++i) {
          sub->list.multi[i].start_lnum = -1;
          sub->list.multi[i].end_lnum = -1;
        }
        sub->in_use = subidx + 1;
      }
      if (off == -1) {
        sub->list.multi[subidx].start_lnum = reglnum + 1;
        sub->list.multi[subidx].start_col = 0;
      } else {

        sub->list.multi[subidx].start_lnum = reglnum;
        sub->list.multi[subidx].start_col =
          (colnr_T)(reginput - regline + off);
      }
      sub->list.multi[subidx].end_lnum = -1;
    } else {
      if (subidx < sub->in_use) {
        save_ptr = sub->list.line[subidx].start;
        save_in_use = -1;
      } else {
        save_in_use = sub->in_use;
        for (i = sub->in_use; i < subidx; ++i) {
          sub->list.line[i].start = NULL;
          sub->list.line[i].end = NULL;
        }
        sub->in_use = subidx + 1;
      }
      sub->list.line[subidx].start = reginput + off;
    }

    subs = addstate(l, state->out, subs, pim, off_arg);
    // "subs" may have changed, need to set "sub" again.
    if (state->c >= NFA_ZOPEN && state->c <= NFA_ZOPEN9) {  // -V560
      sub = &subs->synt;
    } else {
      sub = &subs->norm;
    }

    if (save_in_use == -1) {
      if (REG_MULTI) {
        sub->list.multi[subidx] = save_multipos;
      }
      else
        sub->list.line[subidx].start = save_ptr;
    } else
      sub->in_use = save_in_use;
    break;

  case NFA_MCLOSE:
    if (nfa_has_zend && (REG_MULTI
                         ? subs->norm.list.multi[0].end_lnum >= 0
                         : subs->norm.list.line[0].end != NULL)) {
      /* Do not overwrite the position set by \ze. */
      subs = addstate(l, state->out, subs, pim, off_arg);
      break;
    }
    // fallthrough
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

    /* We don't fill in gaps here, there must have been an MOPEN that
     * has done that. */
    save_in_use = sub->in_use;
    if (sub->in_use <= subidx)
      sub->in_use = subidx + 1;
    if (REG_MULTI) {
      save_multipos = sub->list.multi[subidx];
      if (off == -1) {
        sub->list.multi[subidx].end_lnum = reglnum + 1;
        sub->list.multi[subidx].end_col = 0;
      } else {
        sub->list.multi[subidx].end_lnum = reglnum;
        sub->list.multi[subidx].end_col =
          (colnr_T)(reginput - regline + off);
      }
      /* avoid compiler warnings */
      save_ptr = NULL;
    } else {
      save_ptr = sub->list.line[subidx].end;
      sub->list.line[subidx].end = reginput + off;
      // avoid compiler warnings
      memset(&save_multipos, 0, sizeof(save_multipos));
    }

    subs = addstate(l, state->out, subs, pim, off_arg);
    // "subs" may have changed, need to set "sub" again.
    if (state->c >= NFA_ZCLOSE && state->c <= NFA_ZCLOSE9) {  // -V560
      sub = &subs->synt;
    } else {
      sub = &subs->norm;
    }

    if (REG_MULTI) {
      sub->list.multi[subidx] = save_multipos;
    }
    else
      sub->list.line[subidx].end = save_ptr;
    sub->in_use = save_in_use;
    break;
  }
  return subs;
}

/*
 * Like addstate(), but the new state(s) are put at position "*ip".
 * Used for zero-width matches, next state to use is the added one.
 * This makes sure the order of states to be tried does not change, which
 * matters for alternatives.
 */
static void 
addstate_here (
    nfa_list_T *l,         /* runtime state list */
    nfa_state_T *state,     /* state to update */
    regsubs_T *subs,      /* pointers to subexpressions */
    nfa_pim_T *pim,       /* postponed look-behind match */
    int *ip
)
{
  int tlen = l->n;
  int count;
  int listidx = *ip;

  /* First add the state(s) at the end, so that we know how many there are.
   * Pass the listidx as offset (avoids adding another argument to
   * addstate(). */
  addstate(l, state, subs, pim, -listidx - ADDSTATE_HERE_OFFSET);

  /* when "*ip" was at the end of the list, nothing to do */
  if (listidx + 1 == tlen)
    return;

  /* re-order to put the new state at the current position */
  count = l->n - tlen;
  if (count == 0)
    return;     /* no state got added */
  if (count == 1) {
    /* overwrite the current state */
    l->t[listidx] = l->t[l->n - 1];
  } else if (count > 1) {
    if (l->n + count - 1 >= l->len) {
      /* not enough space to move the new states, reallocate the list
       * and move the states to the right position */

      l->len = l->len * 3 / 2 + 50;
      nfa_thread_T *newl = xmalloc(l->len * sizeof(nfa_thread_T));
      memmove(&(newl[0]),
          &(l->t[0]),
          sizeof(nfa_thread_T) * listidx);
      memmove(&(newl[listidx]),
          &(l->t[l->n - count]),
          sizeof(nfa_thread_T) * count);
      memmove(&(newl[listidx + count]),
          &(l->t[listidx + 1]),
          sizeof(nfa_thread_T) * (l->n - count - listidx - 1));
      xfree(l->t);
      l->t = newl;
    } else {
      /* make space for new states, then move them from the
       * end to the current position */
      memmove(&(l->t[listidx + count]),
          &(l->t[listidx + 1]),
          sizeof(nfa_thread_T) * (l->n - listidx - 1));
      memmove(&(l->t[listidx]),
          &(l->t[l->n - 1]),
          sizeof(nfa_thread_T) * count);
    }
  }
  --l->n;
  *ip = listidx - 1;
}

/*
 * Check character class "class" against current character c.
 */
static int check_char_class(int class, int c)
{
  switch (class) {
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
    if (c == ' ' || c == '\t')
      return OK;
    break;
  case NFA_CLASS_CNTRL:
    if (c >= 1 && c <= 255 && iscntrl(c))
      return OK;
    break;
  case NFA_CLASS_DIGIT:
    if (ascii_isdigit(c))
      return OK;
    break;
  case NFA_CLASS_GRAPH:
    if (c >= 1 && c <= 255 && isgraph(c))
      return OK;
    break;
  case NFA_CLASS_LOWER:
    if (mb_islower(c) && c != 170 && c != 186) {
      return OK;
    }
    break;
  case NFA_CLASS_PRINT:
    if (vim_isprintc(c))
      return OK;
    break;
  case NFA_CLASS_PUNCT:
    if (c >= 1 && c < 128 && ispunct(c)) {
      return OK;
    }
    break;
  case NFA_CLASS_SPACE:
    if ((c >= 9 && c <= 13) || (c == ' '))
      return OK;
    break;
  case NFA_CLASS_UPPER:
    if (mb_isupper(c)) {
      return OK;
    }
    break;
  case NFA_CLASS_XDIGIT:
    if (ascii_isxdigit(c))
      return OK;
    break;
  case NFA_CLASS_TAB:
    if (c == '\t')
      return OK;
    break;
  case NFA_CLASS_RETURN:
    if (c == '\r')
      return OK;
    break;
  case NFA_CLASS_BACKSPACE:
    if (c == '\b')
      return OK;
    break;
  case NFA_CLASS_ESCAPE:
    if (c == ESC) {
      return OK;
    }
    break;

  default:
    // should not be here :P
    IEMSGN(_(e_ill_char_class), class);
    return FAIL;
  }
  return FAIL;
}

/*
 * Check for a match with subexpression "subidx".
 * Return TRUE if it matches.
 */
static int 
match_backref (
    regsub_T *sub,           /* pointers to subexpressions */
    int subidx,
    int *bytelen       /* out: length of match in bytes */
)
{
  int len;

  if (sub->in_use <= subidx) {
retempty:
    /* backref was not set, match an empty string */
    *bytelen = 0;
    return TRUE;
  }

  if (REG_MULTI) {
    if (sub->list.multi[subidx].start_lnum < 0
        || sub->list.multi[subidx].end_lnum < 0)
      goto retempty;
    if (sub->list.multi[subidx].start_lnum == reglnum
        && sub->list.multi[subidx].end_lnum == reglnum) {
      len = sub->list.multi[subidx].end_col
            - sub->list.multi[subidx].start_col;
      if (cstrncmp(regline + sub->list.multi[subidx].start_col,
              reginput, &len) == 0) {
        *bytelen = len;
        return TRUE;
      }
    } else {
      if (match_with_backref(
              sub->list.multi[subidx].start_lnum,
              sub->list.multi[subidx].start_col,
              sub->list.multi[subidx].end_lnum,
              sub->list.multi[subidx].end_col,
              bytelen) == RA_MATCH)
        return TRUE;
    }
  } else {
    if (sub->list.line[subidx].start == NULL
        || sub->list.line[subidx].end == NULL)
      goto retempty;
    len = (int)(sub->list.line[subidx].end - sub->list.line[subidx].start);
    if (cstrncmp(sub->list.line[subidx].start, reginput, &len) == 0) {
      *bytelen = len;
      return TRUE;
    }
  }
  return FALSE;
}



/*
 * Check for a match with \z subexpression "subidx".
 * Return TRUE if it matches.
 */
static int 
match_zref (
    int subidx,
    int *bytelen       /* out: length of match in bytes */
)
{
  int len;

  cleanup_zsubexpr();
  if (re_extmatch_in == NULL || re_extmatch_in->matches[subidx] == NULL) {
    /* backref was not set, match an empty string */
    *bytelen = 0;
    return TRUE;
  }

  len = (int)STRLEN(re_extmatch_in->matches[subidx]);
  if (cstrncmp(re_extmatch_in->matches[subidx], reginput, &len) == 0) {
    *bytelen = len;
    return TRUE;
  }
  return FALSE;
}

/*
 * Save list IDs for all NFA states of "prog" into "list".
 * Also reset the IDs to zero.
 * Only used for the recursive value lastlist[1].
 */
static void nfa_save_listids(nfa_regprog_T *prog, int *list)
{
  int i;
  nfa_state_T     *p;

  /* Order in the list is reverse, it's a bit faster that way. */
  p = &prog->state[0];
  for (i = prog->nstate; --i >= 0; ) {
    list[i] = p->lastlist[1];
    p->lastlist[1] = 0;
    ++p;
  }
}

/*
 * Restore list IDs from "list" to all NFA states.
 */
static void nfa_restore_listids(nfa_regprog_T *prog, int *list)
{
  int i;
  nfa_state_T     *p;

  p = &prog->state[0];
  for (i = prog->nstate; --i >= 0; ) {
    p->lastlist[1] = list[i];
    ++p;
  }
}

static bool nfa_re_num_cmp(uintmax_t val, int op, uintmax_t pos)
{
  if (op == 1) return pos > val;
  if (op == 2) return pos < val;
  return val == pos;
}


/*
 * Recursively call nfa_regmatch()
 * "pim" is NULL or contains info about a Postponed Invisible Match (start
 * position).
 */
static int recursive_regmatch(nfa_state_T *state, nfa_pim_T *pim, nfa_regprog_T *prog, regsubs_T *submatch, regsubs_T *m, int **listids)
{
  int save_reginput_col = (int)(reginput - regline);
  int save_reglnum = reglnum;
  int save_nfa_match = nfa_match;
  int save_nfa_listid = nfa_listid;
  save_se_T   *save_nfa_endp = nfa_endp;
  save_se_T endpos;
  save_se_T   *endposp = NULL;
  int result;
  int need_restore = FALSE;

  if (pim != NULL) {
    /* start at the position where the postponed match was */
    if (REG_MULTI)
      reginput = regline + pim->end.pos.col;
    else
      reginput = pim->end.ptr;
  }

  if (state->c == NFA_START_INVISIBLE_BEFORE
      || state->c == NFA_START_INVISIBLE_BEFORE_FIRST
      || state->c == NFA_START_INVISIBLE_BEFORE_NEG
      || state->c == NFA_START_INVISIBLE_BEFORE_NEG_FIRST) {
    /* The recursive match must end at the current position. When "pim" is
     * not NULL it specifies the current position. */
    endposp = &endpos;
    if (REG_MULTI) {
      if (pim == NULL) {
        endpos.se_u.pos.col = (int)(reginput - regline);
        endpos.se_u.pos.lnum = reglnum;
      } else
        endpos.se_u.pos = pim->end.pos;
    } else {
      if (pim == NULL)
        endpos.se_u.ptr = reginput;
      else
        endpos.se_u.ptr = pim->end.ptr;
    }

    /* Go back the specified number of bytes, or as far as the
     * start of the previous line, to try matching "\@<=" or
     * not matching "\@<!". This is very inefficient, limit the number of
     * bytes if possible. */
    if (state->val <= 0) {
      if (REG_MULTI) {
        regline = reg_getline(--reglnum);
        if (regline == NULL)
          /* can't go before the first line */
          regline = reg_getline(++reglnum);
      }
      reginput = regline;
    } else {
      if (REG_MULTI && (int)(reginput - regline) < state->val) {
        /* Not enough bytes in this line, go to end of
         * previous line. */
        regline = reg_getline(--reglnum);
        if (regline == NULL) {
          /* can't go before the first line */
          regline = reg_getline(++reglnum);
          reginput = regline;
        } else
          reginput = regline + STRLEN(regline);
      }
      if ((int)(reginput - regline) >= state->val) {
        reginput -= state->val;
        if (has_mbyte)
          reginput -= mb_head_off(regline, reginput);
      } else
        reginput = regline;
    }
  }

#ifdef REGEXP_DEBUG
  if (log_fd != stderr)
    fclose(log_fd);
  log_fd = NULL;
#endif
  /* Have to clear the lastlist field of the NFA nodes, so that
   * nfa_regmatch() and addstate() can run properly after recursion. */
  if (nfa_ll_index == 1) {
    /* Already calling nfa_regmatch() recursively.  Save the lastlist[1]
     * values and clear them. */
    if (*listids == NULL) {
      *listids = xmalloc(sizeof(**listids) * nstate);
    }
    nfa_save_listids(prog, *listids);
    need_restore = TRUE;
    /* any value of nfa_listid will do */
  } else {
    /* First recursive nfa_regmatch() call, switch to the second lastlist
     * entry.  Make sure nfa_listid is different from a previous recursive
     * call, because some states may still have this ID. */
    ++nfa_ll_index;
    if (nfa_listid <= nfa_alt_listid)
      nfa_listid = nfa_alt_listid;
  }

  /* Call nfa_regmatch() to check if the current concat matches at this
   * position. The concat ends with the node NFA_END_INVISIBLE */
  nfa_endp = endposp;
  result = nfa_regmatch(prog, state->out, submatch, m);

  if (need_restore)
    nfa_restore_listids(prog, *listids);
  else {
    --nfa_ll_index;
    nfa_alt_listid = nfa_listid;
  }

  /* restore position in input text */
  reglnum = save_reglnum;
  if (REG_MULTI)
    regline = reg_getline(reglnum);
  reginput = regline + save_reginput_col;
  if (result != NFA_TOO_EXPENSIVE) {
    nfa_match = save_nfa_match;
    nfa_listid = save_nfa_listid;
  }
  nfa_endp = save_nfa_endp;

#ifdef REGEXP_DEBUG
  log_fd = fopen(NFA_REGEXP_RUN_LOG, "a");
  if (log_fd != NULL) {
    fprintf(log_fd, "****************************\n");
    fprintf(log_fd, "FINISHED RUNNING nfa_regmatch() recursively\n");
    fprintf(log_fd, "MATCH = %s\n", !result ? "FALSE" : "OK");
    fprintf(log_fd, "****************************\n");
  } else {
    EMSG(_(
            "Could not open temporary log file for writing, displaying on stderr ... "));
    log_fd = stderr;
  }
#endif

  return result;
}


/*
 * Estimate the chance of a match with "state" failing.
 * empty match: 0
 * NFA_ANY: 1
 * specific character: 99
 */
static int failure_chance(nfa_state_T *state, int depth)
{
  int c = state->c;
  int l, r;

  /* detect looping */
  if (depth > 4)
    return 1;

  switch (c) {
  case NFA_SPLIT:
    if (state->out->c == NFA_SPLIT || state->out1->c == NFA_SPLIT)
      /* avoid recursive stuff */
      return 1;
    /* two alternatives, use the lowest failure chance */
    l = failure_chance(state->out, depth + 1);
    r = failure_chance(state->out1, depth + 1);
    return l < r ? l : r;

  case NFA_ANY:
    /* matches anything, unlikely to fail */
    return 1;

  case NFA_MATCH:
  case NFA_MCLOSE:
  case NFA_ANY_COMPOSING:
    /* empty match works always */
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
    /* recursive regmatch is expensive, use low failure chance */
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
    /* backreferences don't match in many places */
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
    /* before/after positions don't match very often */
    return 85;

  case NFA_LNUM:
    return 90;

  case NFA_CURSOR:
  case NFA_COL:
  case NFA_VCOL:
  case NFA_MARK:
    /* specific positions rarely match */
    return 98;

  case NFA_COMPOSING:
    return 95;

  default:
    if (c > 0)
      /* character match fails often */
      return 95;
  }

  /* something else, includes character classes */
  return 50;
}

/*
 * Skip until the char "c" we know a match must start with.
 */
static int skip_to_start(int c, colnr_T *colp)
{
  const char_u *const s = cstrchr(regline + *colp, c);
  if (s == NULL) {
    return FAIL;
  }
  *colp = (int)(s - regline);
  return OK;
}

/*
 * Check for a match with match_text.
 * Called after skip_to_start() has found regstart.
 * Returns zero for no match, 1 for a match.
 */
static long find_match_text(colnr_T startcol, int regstart, char_u *match_text)
{
#define PTR2LEN(x) enc_utf8 ? utf_ptr2len(x) : MB_PTR2LEN(x)

  colnr_T col = startcol;
  int regstart_len = PTR2LEN(regline + startcol);

  for (;;) {
    bool match = true;
    char_u *s1 = match_text;
    char_u *s2 = regline + col + regstart_len;  // skip regstart
    while (*s1) {
      int c1_len = PTR2LEN(s1);
      int c1 = PTR2CHAR(s1);
      int c2_len = PTR2LEN(s2);
      int c2 = PTR2CHAR(s2);

      if ((c1 != c2 && (!rex.reg_ic || mb_tolower(c1) != mb_tolower(c2)))
          || c1_len != c2_len) {
        match = false;
        break;
      }
      s1 += c1_len;
      s2 += c2_len;
    }
    if (match
        // check that no composing char follows
        && !(enc_utf8 && utf_iscomposing(PTR2CHAR(s2)))) {
      cleanup_subexpr();
      if (REG_MULTI) {
        rex.reg_startpos[0].lnum = reglnum;
        rex.reg_startpos[0].col = col;
        rex.reg_endpos[0].lnum = reglnum;
        rex.reg_endpos[0].col = s2 - regline;
      } else {
        rex.reg_startp[0] = regline + col;
        rex.reg_endp[0] = s2;
      }
      return 1L;
    }

    // Try finding regstart after the current match.
    col += regstart_len;  // skip regstart
    if (skip_to_start(regstart, &col) == FAIL) {
      break;
    }
  }
  return 0L;

#undef PTR2LEN
}

/// Main matching routine.
///
/// Run NFA to determine whether it matches reginput.
///
/// When "nfa_endp" is not NULL it is a required end-of-match position.
///
/// Return TRUE if there is a match, FALSE otherwise.
/// When there is a match "submatch" contains the positions.
/// Note: Caller must ensure that: start != NULL.
static int nfa_regmatch(nfa_regprog_T *prog, nfa_state_T *start,
                        regsubs_T *submatch, regsubs_T *m)
{
  int result;
  int flag = 0;
  bool go_to_nextline = false;
  nfa_thread_T *t;
  nfa_list_T list[2];
  int listidx;
  nfa_list_T  *thislist;
  nfa_list_T  *nextlist;
  int         *listids = NULL;
  nfa_state_T *add_state;
  bool add_here;
  int add_count;
  int add_off = 0;
  int toplevel = start->c == NFA_MOPEN;
#ifdef NFA_REGEXP_DEBUG_LOG
  FILE        *debug = fopen(NFA_REGEXP_DEBUG_LOG, "a");

  if (debug == NULL) {
    EMSG2(_("(NFA) COULD NOT OPEN %s !"), NFA_REGEXP_DEBUG_LOG);
    return false;
  }
#endif
  // Some patterns may take a long time to match, especially when using
  // recursive_regmatch(). Allow interrupting them with CTRL-C.
  fast_breakcheck();
  if (got_int) {
#ifdef NFA_REGEXP_DEBUG_LOG
    fclose(debug);
#endif
    return false;
  }
  if (nfa_time_limit != NULL && profile_passed_limit(*nfa_time_limit)) {
#ifdef NFA_REGEXP_DEBUG_LOG
    fclose(debug);
#endif
    return false;
  }

  nfa_match = false;

  // Allocate memory for the lists of nodes.
  size_t size = (nstate + 1) * sizeof(nfa_thread_T);
  list[0].t = xmalloc(size);
  list[0].len = nstate + 1;
  list[1].t = xmalloc(size);
  list[1].len = nstate + 1;

#ifdef REGEXP_DEBUG
  log_fd = fopen(NFA_REGEXP_RUN_LOG, "a");
  if (log_fd != NULL) {
    fprintf(log_fd, "**********************************\n");
    nfa_set_code(start->c);
    fprintf(log_fd, " RUNNING nfa_regmatch() starting with state %d, code %s\n",
        abs(start->id), code);
    fprintf(log_fd, "**********************************\n");
  } else {
    EMSG(_(
            "Could not open temporary log file for writing, displaying on stderr ... "));
    log_fd = stderr;
  }
#endif

  thislist = &list[0];
  thislist->n = 0;
  thislist->has_pim = FALSE;
  nextlist = &list[1];
  nextlist->n = 0;
  nextlist->has_pim = FALSE;
#ifdef REGEXP_DEBUG
  fprintf(log_fd, "(---) STARTSTATE first\n");
#endif
  thislist->id = nfa_listid + 1;

  /* Inline optimized code for addstate(thislist, start, m, 0) if we know
   * it's the first MOPEN. */
  if (toplevel) {
    if (REG_MULTI) {
      m->norm.list.multi[0].start_lnum = reglnum;
      m->norm.list.multi[0].start_col = (colnr_T)(reginput - regline);
    } else
      m->norm.list.line[0].start = reginput;
    m->norm.in_use = 1;
    addstate(thislist, start->out, m, NULL, 0);
  } else
    addstate(thislist, start, m, NULL, 0);

#define ADD_STATE_IF_MATCH(state) \
  if (result) { \
    add_state = state->out; \
    add_off = clen; \
  }

  /*
   * Run for each character.
   */
  for (;; ) {
    int curc;
    int clen;

    if (has_mbyte) {
      curc = (*mb_ptr2char)(reginput);
      clen = (*mb_ptr2len)(reginput);
    } else {
      curc = *reginput;
      clen = 1;
    }
    if (curc == NUL) {
      clen = 0;
      go_to_nextline = false;
    }

    /* swap lists */
    thislist = &list[flag];
    nextlist = &list[flag ^= 1];
    nextlist->n = 0;                /* clear nextlist */
    nextlist->has_pim = FALSE;
    ++nfa_listid;
    if (prog->re_engine == AUTOMATIC_ENGINE && nfa_listid >= NFA_MAX_STATES) {
      // Too many states, retry with old engine.
      nfa_match = NFA_TOO_EXPENSIVE;
      goto theend;
    }

    thislist->id = nfa_listid;
    nextlist->id = nfa_listid + 1;

#ifdef REGEXP_DEBUG
    fprintf(log_fd, "------------------------------------------\n");
    fprintf(log_fd, ">>> Reginput is \"%s\"\n", reginput);
    fprintf(log_fd,
        ">>> Advanced one character ... Current char is %c (code %d) \n", curc,
        (int)curc);
    fprintf(log_fd, ">>> Thislist has %d states available: ", thislist->n);
    {
      int i;

      for (i = 0; i < thislist->n; i++)
        fprintf(log_fd, "%d  ", abs(thislist->t[i].state->id));
    }
    fprintf(log_fd, "\n");
#endif

#ifdef NFA_REGEXP_DEBUG_LOG
    fprintf(debug, "\n-------------------\n");
#endif
    /*
     * If the state lists are empty we can stop.
     */
    if (thislist->n == 0)
      break;

    /* compute nextlist */
    for (listidx = 0; listidx < thislist->n; ++listidx) {
      t = &thislist->t[listidx];

#ifdef NFA_REGEXP_DEBUG_LOG
      nfa_set_code(t->state->c);
      fprintf(debug, "%s, ", code);
#endif
#ifdef REGEXP_DEBUG
      {
        int col;

        if (t->subs.norm.in_use <= 0)
          col = -1;
        else if (REG_MULTI)
          col = t->subs.norm.list.multi[0].start_col;
        else
          col = (int)(t->subs.norm.list.line[0].start - regline);
        nfa_set_code(t->state->c);
        fprintf(log_fd, "(%d) char %d %s (start col %d)%s ... \n",
            abs(t->state->id), (int)t->state->c, code, col,
            pim_info(&t->pim));
      }
#endif

      /*
       * Handle the possible codes of the current state.
       * The most important is NFA_MATCH.
       */
      add_state = NULL;
      add_here = false;
      add_count = 0;
      switch (t->state->c) {
      case NFA_MATCH:
      {
        // If the match ends before a composing characters and
        // rex.reg_icombine is not set, that is not really a match.
        if (enc_utf8 && !rex.reg_icombine && utf_iscomposing(curc)) {
          break;
        }
        nfa_match = true;
        copy_sub(&submatch->norm, &t->subs.norm);
        if (nfa_has_zsubexpr)
          copy_sub(&submatch->synt, &t->subs.synt);
#ifdef REGEXP_DEBUG
        log_subsexpr(&t->subs);
#endif
        /* Found the left-most longest match, do not look at any other
         * states at this position.  When the list of states is going
         * to be empty quit without advancing, so that "reginput" is
         * correct. */
        if (nextlist->n == 0)
          clen = 0;
        goto nextchar;
      }

      case NFA_END_INVISIBLE:
      case NFA_END_INVISIBLE_NEG:
      case NFA_END_PATTERN:
        /*
         * This is only encountered after a NFA_START_INVISIBLE or
         * NFA_START_INVISIBLE_BEFORE node.
         * They surround a zero-width group, used with "\@=", "\&",
         * "\@!", "\@<=" and "\@<!".
         * If we got here, it means that the current "invisible" group
         * finished successfully, so return control to the parent
         * nfa_regmatch().  For a look-behind match only when it ends
         * in the position in "nfa_endp".
         * Submatches are stored in *m, and used in the parent call.
         */
#ifdef REGEXP_DEBUG
        if (nfa_endp != NULL) {
          if (REG_MULTI)
            fprintf(
                log_fd,
                "Current lnum: %d, endp lnum: %d; current col: %d, endp col: %d\n",
                (int)reglnum,
                (int)nfa_endp->se_u.pos.lnum,
                (int)(reginput - regline),
                nfa_endp->se_u.pos.col);
          else
            fprintf(log_fd, "Current col: %d, endp col: %d\n",
                (int)(reginput - regline),
                (int)(nfa_endp->se_u.ptr - reginput));
        }
#endif
        /* If "nfa_endp" is set it's only a match if it ends at
         * "nfa_endp" */
        if (nfa_endp != NULL && (REG_MULTI
                                 ? (reglnum != nfa_endp->se_u.pos.lnum
                                    || (int)(reginput - regline)
                                    != nfa_endp->se_u.pos.col)
                                 : reginput != nfa_endp->se_u.ptr))
          break;

        /* do not set submatches for \@! */
        if (t->state->c != NFA_END_INVISIBLE_NEG) {
          copy_sub(&m->norm, &t->subs.norm);
          if (nfa_has_zsubexpr)
            copy_sub(&m->synt, &t->subs.synt);
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
      {
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
          if (nfa_has_zsubexpr)
            copy_sub_off(&m->synt, &t->subs.synt);

          // First try matching the invisible match, then what
          // follows.
          result = recursive_regmatch(t->state, NULL, prog, submatch, m,
                                      &listids);
          if (result == NFA_TOO_EXPENSIVE) {
            nfa_match = result;
            goto theend;
          }

          // for \@! and \@<! it is a match when the result is
          // FALSE
          if (result != (t->state->c == NFA_START_INVISIBLE_NEG
                         || t->state->c == NFA_START_INVISIBLE_NEG_FIRST
                         || t->state->c
                         == NFA_START_INVISIBLE_BEFORE_NEG
                         || t->state->c
                         == NFA_START_INVISIBLE_BEFORE_NEG_FIRST)) {
            // Copy submatch info from the recursive call
            copy_sub_off(&t->subs.norm, &m->norm);
            if (nfa_has_zsubexpr)
              copy_sub_off(&t->subs.synt, &m->synt);
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
            pim.end.pos.col = (int)(reginput - regline);
            pim.end.pos.lnum = reglnum;
          } else
            pim.end.ptr = reginput;

          // t->state->out1 is the corresponding END_INVISIBLE
          // node; Add its out to the current list (zero-width
          // match).
          addstate_here(thislist, t->state->out1->out, &t->subs,
              &pim, &listidx);
        }
      }
      break;

      case NFA_START_PATTERN:
      {
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
          fprintf(
              log_fd,
              "> Not trying to match pattern, output state %d is already in list %d. char %d: %s\n",
              abs(skip->id), skip_lid, skip->c, code);
#endif
          break;
        }
        // Copy submatch info to the recursive call, opposite of what
        // happens afterwards.
        copy_sub_off(&m->norm, &t->subs.norm);
        if (nfa_has_zsubexpr) {
          copy_sub_off(&m->synt, &t->subs.synt);
        }

        // First try matching the pattern.
        result = recursive_regmatch(t->state, NULL, prog, submatch, m,
                                    &listids);
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
          if (nfa_has_zsubexpr) {
            copy_sub_off(&t->subs.synt, &m->synt);
          }
          // Now we need to skip over the matched text and then
          // continue with what follows.
          if (REG_MULTI) {
            // TODO(RE): multi-line match
            bytelen = m->norm.list.multi[0].end_col
                      - (int)(reginput - regline);
          } else {
            bytelen = (int)(m->norm.list.line[0].end - reginput);
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
        if (reginput == regline) {
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
        } else if (has_mbyte) {
          int this_class;

          // Get class of current and previous char (if it exists).
          this_class = mb_get_class_tab(reginput, rex.reg_buf->b_chartab);
          if (this_class <= 1) {
            result = false;
          } else if (reg_prev_class() == this_class) {
            result = false;
          }
        } else if (!vim_iswordc_buf(curc, rex.reg_buf)
                   || (reginput > regline
                       && vim_iswordc_buf(reginput[-1], rex.reg_buf))) {
          result = false;
        }
        if (result) {
          add_here = true;
          add_state = t->state->out;
        }
        break;

      case NFA_EOW:
        result = true;
        if (reginput == regline) {
          result = false;
        } else if (has_mbyte) {
          int this_class, prev_class;

          // Get class of current and previous char (if it exists).
          this_class = mb_get_class_tab(reginput, rex.reg_buf->b_chartab);
          prev_class = reg_prev_class();
          if (this_class == prev_class
              || prev_class == 0 || prev_class == 1) {
            result = false;
          }
        } else if (!vim_iswordc_buf(reginput[-1], rex.reg_buf)
                   || (reginput[0] != NUL
                       && vim_iswordc_buf(curc, rex.reg_buf))) {
          result = false;
        }
        if (result) {
          add_here = true;
          add_state = t->state->out;
        }
        break;

      case NFA_BOF:
        if (reglnum == 0 && reginput == regline
            && (!REG_MULTI || rex.reg_firstlnum == 1)) {
          add_here = true;
          add_state = t->state->out;
        }
        break;

      case NFA_EOF:
        if (reglnum == rex.reg_maxline && curc == NUL) {
          add_here = true;
          add_state = t->state->out;
        }
        break;

      case NFA_COMPOSING:
      {
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
          len += mb_char2len(mc);
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
            len += mb_char2len(mc);
            sta = sta->out;
          }

          // We don't care about the order of composing characters.
          // Get them into cchars[] first.
          while (len < clen) {
            mc = mb_ptr2char(reginput + len);
            cchars[ccount++] = mc;
            len += mb_char2len(mc);
            if (ccount == MAX_MCO)
              break;
          }

          // Check that each composing char in the pattern matches a
          // composing char in the text.  We do not check if all
          // composing chars are matched.
          result = OK;
          while (sta->c != NFA_END_COMPOSING) {
            for (j = 0; j < ccount; ++j)
              if (cchars[j] == sta->c)
                break;
            if (j == ccount) {
              result = FAIL;
              break;
            }
            sta = sta->out;
          }
        } else
          result = FAIL;

        end = t->state->out1;               // NFA_END_COMPOSING
        ADD_STATE_IF_MATCH(end);
        break;
      }

      case NFA_NEWL:
        if (curc == NUL && !rex.reg_line_lbr && REG_MULTI
            && reglnum <= rex.reg_maxline) {
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
      case NFA_START_NEG_COLL:
      {
        // What follows is a list of characters, until NFA_END_COLL.
        // One of them must match or none of them must match.
        nfa_state_T     *state;
        int result_if_matched;
        int c1, c2;

        // Never match EOL. If it's part of the collection it is added
        // as a separate state with an OR.
        if (curc == NUL) {
          break;
        }

        state = t->state->out;
        result_if_matched = (t->state->c == NFA_START_COLL);
        for (;; ) {
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
              int curc_low = mb_tolower(curc);
              int done = false;

              for (; c1 <= c2; c1++) {
                if (mb_tolower(c1) == curc_low) {
                  result = result_if_matched;
                  done = TRUE;
                  break;
                }
              }
              if (done) {
                break;
              }
            }
          } else if (state->c < 0 ? check_char_class(state->c, curc)
                     : (curc == state->c
                        || (rex.reg_ic && mb_tolower(curc)
                            == mb_tolower(state->c)))) {
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
        if (enc_utf8 && utf_iscomposing(curc)) {
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
        result = vim_iswordp_buf(reginput, rex.reg_buf);
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_SKWORD:          //  \K
        result = !ascii_isdigit(curc)
                 && vim_iswordp_buf(reginput, rex.reg_buf);
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
        result = vim_isprintc(PTR2CHAR(reginput));
        ADD_STATE_IF_MATCH(t->state);
        break;

      case NFA_SPRINT:          //  \P
        result = !ascii_isdigit(curc) && vim_isprintc(PTR2CHAR(reginput));
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
                     && reglnum > LONG_MAX - rex.reg_firstlnum)
                    || (rex.reg_firstlnum < 0
                        && reglnum < LONG_MIN + rex.reg_firstlnum))
               && reglnum + rex.reg_firstlnum >= 0);
        result = (REG_MULTI
                  && nfa_re_num_cmp((uintmax_t)t->state->val,
                                    t->state->c - NFA_LNUM,
                                    (uintmax_t)(reglnum + rex.reg_firstlnum)));
        if (result) {
          add_here = true;
          add_state = t->state->out;
        }
        break;

      case NFA_COL:
      case NFA_COL_GT:
      case NFA_COL_LT:
        assert(t->state->val >= 0
               && reginput >= regline
               && (uintmax_t)(reginput - regline) <= UINTMAX_MAX - 1);
        result = nfa_re_num_cmp((uintmax_t)t->state->val,
                                t->state->c - NFA_COL,
                                (uintmax_t)(reginput - regline + 1));
        if (result) {
          add_here = true;
          add_state = t->state->out;
        }
        break;

      case NFA_VCOL:
      case NFA_VCOL_GT:
      case NFA_VCOL_LT:
        {
          int op = t->state->c - NFA_VCOL;
          colnr_T col = (colnr_T)(reginput - regline);

          // Bail out quickly when there can't be a match, avoid the overhead of
          // win_linetabsize() on long lines.
          if (op != 1 && col > t->state->val * (has_mbyte ? MB_MAXBYTES : 1)) {
            break;
          }

          result = false;
          win_T *wp = rex.reg_win == NULL ? curwin : rex.reg_win;
          if (op == 1 && col - 1 > t->state->val && col > 100) {
            long ts = wp->w_buffer->b_p_ts;

            // Guess that a character won't use more columns than 'tabstop',
            // with a minimum of 4.
            if (ts < 4) {
              ts = 4;
            }
            result = col > t->state->val * ts;
          }
          if (!result) {
            uintmax_t lts = win_linetabsize(wp, regline, col);
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
      case NFA_MARK_LT:
      {
        pos_T *pos = getmark_buf(rex.reg_buf, t->state->val, false);

        // Compare the mark position to the match position.
        result = (pos != NULL                        // mark doesn't exist
                  && pos->lnum > 0          // mark isn't set in reg_buf
                  && (pos->lnum == reglnum + rex.reg_firstlnum
                      ? (pos->col == (colnr_T)(reginput - regline)
                         ? t->state->c == NFA_MARK
                         : (pos->col < (colnr_T)(reginput - regline)
                            ? t->state->c == NFA_MARK_GT
                            : t->state->c == NFA_MARK_LT))
                      : (pos->lnum < reglnum + rex.reg_firstlnum
                         ? t->state->c == NFA_MARK_GT
                         : t->state->c == NFA_MARK_LT)));
        if (result) {
          add_here = true;
          add_state = t->state->out;
        }
        break;
      }

      case NFA_CURSOR:
        result = (rex.reg_win != NULL
                  && (reglnum + rex.reg_firstlnum == rex.reg_win->w_cursor.lnum)
                  && ((colnr_T)(reginput - regline)
                      == rex.reg_win->w_cursor.col));
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
          IEMSGN("INTERNAL: Negative state char: %" PRId64, c);
        }
#endif
        result = (c == curc);

        if (!result && rex.reg_ic) {
          result = mb_tolower(c) == mb_tolower(curc);
        }

        // If rex.reg_icombine is not set only skip over the character
        // itself.  When it is set skip over composing characters.
        if (result && enc_utf8 && !rex.reg_icombine) {
          clen = utf_ptr2len(reginput);
        }

        ADD_STATE_IF_MATCH(t->state);
        break;
      }
      }       // switch (t->state->c)

      if (add_state != NULL) {
        nfa_pim_T *pim;
        nfa_pim_T pim_copy;

        if (t->pim.result == NFA_PIM_UNUSED)
          pim = NULL;
        else
          pim = &t->pim;

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
            result = recursive_regmatch(pim->state, pim,
                prog, submatch, m, &listids);
            pim->result = result ? NFA_PIM_MATCH : NFA_PIM_NOMATCH;
            // for \@! and \@<! it is a match when the result is
            // FALSE
            if (result != (pim->state->c == NFA_START_INVISIBLE_NEG
                           || pim->state->c == NFA_START_INVISIBLE_NEG_FIRST
                           || pim->state->c
                           == NFA_START_INVISIBLE_BEFORE_NEG
                           || pim->state->c
                           == NFA_START_INVISIBLE_BEFORE_NEG_FIRST)) {
              // Copy submatch info from the recursive call
              copy_sub_off(&pim->subs.norm, &m->norm);
              if (nfa_has_zsubexpr)
                copy_sub_off(&pim->subs.synt, &m->synt);
            }
          } else {
            result = (pim->result == NFA_PIM_MATCH);
#ifdef REGEXP_DEBUG
            fprintf(log_fd, "\n");
            fprintf(
                log_fd,
                "Using previous recursive nfa_regmatch() result, result == %d\n",
                pim->result);
            fprintf(log_fd, "MATCH = %s\n", result ? "OK" : "FALSE");
            fprintf(log_fd, "\n");
#endif
          }

          // for \@! and \@<! it is a match when result is FALSE
          if (result != (pim->state->c == NFA_START_INVISIBLE_NEG
                         || pim->state->c == NFA_START_INVISIBLE_NEG_FIRST
                         || pim->state->c
                         == NFA_START_INVISIBLE_BEFORE_NEG
                         || pim->state->c
                         == NFA_START_INVISIBLE_BEFORE_NEG_FIRST)) {
            // Copy submatch info from the recursive call
            copy_sub_off(&t->subs.norm, &pim->subs.norm);
            if (nfa_has_zsubexpr)
              copy_sub_off(&t->subs.synt, &pim->subs.synt);
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

        if (add_here)
          addstate_here(thislist, add_state, &t->subs, pim, &listidx);
        else {
          addstate(nextlist, add_state, &t->subs, pim, add_off);
          if (add_count > 0)
            nextlist->t[nextlist->n - 1].count = add_count;
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
             && reglnum == 0
             && clen != 0
             && (rex.reg_maxcol == 0
                 || (colnr_T)(reginput - regline) < rex.reg_maxcol))
            || (nfa_endp != NULL
                && (REG_MULTI
                    ? (reglnum < nfa_endp->se_u.pos.lnum
                       || (reglnum == nfa_endp->se_u.pos.lnum
                           && (int)(reginput - regline)
                           < nfa_endp->se_u.pos.col))
                    : reginput < nfa_endp->se_u.ptr)))) {
#ifdef REGEXP_DEBUG
      fprintf(log_fd, "(---) STARTSTATE\n");
#endif
      // Inline optimized code for addstate() if we know the state is
      // the first MOPEN.
      if (toplevel) {
        int add = TRUE;
        int c;

        if (prog->regstart != NUL && clen != 0) {
          if (nextlist->n == 0) {
            colnr_T col = (colnr_T)(reginput - regline) + clen;

            // Nextlist is empty, we can skip ahead to the
            // character that must appear at the start.
            if (skip_to_start(prog->regstart, &col) == FAIL) {
              break;
            }
#ifdef REGEXP_DEBUG
            fprintf(log_fd, "  Skipping ahead %d bytes to regstart\n",
                col - ((colnr_T)(reginput - regline) + clen));
#endif
            reginput = regline + col - clen;
          } else {
            // Checking if the required start character matches is
            // cheaper than adding a state that won't match.
            c = PTR2CHAR(reginput + clen);
            if (c != prog->regstart && (!rex.reg_ic || mb_tolower(c)
                                        != mb_tolower(prog->regstart))) {
#ifdef REGEXP_DEBUG
              fprintf(log_fd,
                  "  Skipping start state, regstart does not match\n");
#endif
              add = FALSE;
            }
          }
        }

        if (add) {
          if (REG_MULTI)
            m->norm.list.multi[0].start_col =
              (colnr_T)(reginput - regline) + clen;
          else
            m->norm.list.line[0].start = reginput + clen;
          addstate(nextlist, start->out, m, NULL, clen);
        }
      } else
        addstate(nextlist, start, m, NULL, clen);
    }

#ifdef REGEXP_DEBUG
    fprintf(log_fd, ">>> Thislist had %d states available: ", thislist->n);
    {
      int i;

      for (i = 0; i < thislist->n; i++)
        fprintf(log_fd, "%d  ", abs(thislist->t[i].state->id));
    }
    fprintf(log_fd, "\n");
#endif

nextchar:
    // Advance to the next character, or advance to the next line, or
    // finish.
    if (clen != 0) {
      reginput += clen;
    } else if (go_to_nextline || (nfa_endp != NULL && REG_MULTI
                                  && reglnum < nfa_endp->se_u.pos.lnum)) {
      reg_nextline();
    } else {
      break;
    }

    // Allow interrupting with CTRL-C.
    line_breakcheck();
    if (got_int) {
      break;
    }
    // Check for timeout once every twenty times to avoid overhead.
    if (nfa_time_limit != NULL && ++nfa_time_count == 20) {
      nfa_time_count = 0;
      if (profile_passed_limit(*nfa_time_limit)) {
        break;
      }
    }
  }

#ifdef REGEXP_DEBUG
  if (log_fd != stderr)
    fclose(log_fd);
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

// Try match of "prog" with at regline["col"].
// Returns <= 0 for failure, number of lines contained in the match otherwise.
static long nfa_regtry(nfa_regprog_T *prog, colnr_T col, proftime_T *tm)
{
  int i;
  regsubs_T subs, m;
  nfa_state_T *start = prog->start;
#ifdef REGEXP_DEBUG
  FILE        *f;
#endif

  reginput = regline + col;
  nfa_time_limit = tm;
  nfa_time_count = 0;

#ifdef REGEXP_DEBUG
  f = fopen(NFA_REGEXP_RUN_LOG, "a");
  if (f != NULL) {
    fprintf(f,
        "\n\n\t=======================================================\n");
#ifdef REGEXP_DEBUG
    fprintf(f, "\tRegexp is \"%s\"\n", nfa_regengine.expr);
#endif
    fprintf(f, "\tInput text is \"%s\" \n", reginput);
    fprintf(f, "\t=======================================================\n\n");
    nfa_print_state(f, start);
    fprintf(f, "\n\n");
    fclose(f);
  } else
    EMSG(_("Could not open temporary log file for writing "));
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

    if (rex.reg_startpos[0].lnum < 0) {
      rex.reg_startpos[0].lnum = 0;
      rex.reg_startpos[0].col = col;
    }
    if (rex.reg_endpos[0].lnum < 0) {
      // pattern has a \ze but it didn't match, use current end
      rex.reg_endpos[0].lnum = reglnum;
      rex.reg_endpos[0].col = (int)(reginput - regline);
    } else {
      // Use line number of "\ze".
      reglnum = rex.reg_endpos[0].lnum;
    }
  } else {
    for (i = 0; i < subs.norm.in_use; i++) {
      rex.reg_startp[i] = subs.norm.list.line[i].start;
      rex.reg_endp[i] = subs.norm.list.line[i].end;
    }

    if (rex.reg_startp[0] == NULL) {
      rex.reg_startp[0] = regline + col;
    }
    if (rex.reg_endp[0] == NULL) {
      rex.reg_endp[0] = reginput;
    }
  }

  /* Package any found \z(...\) matches for export. Default is none. */
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
            vim_strnsave(reg_getline(mpos->start_lnum) + mpos->start_col,
                         mpos->end_col - mpos->start_col);
        }
      } else {
        struct linepos *lpos = &subs.synt.list.line[i];

        if (lpos->start != NULL && lpos->end != NULL)
          re_extmatch_out->matches[i] =
            vim_strnsave(lpos->start,
                (int)(lpos->end - lpos->start));
      }
    }
  }

  return 1 + reglnum;
}

/// Match a regexp against a string ("line" points to the string) or multiple
/// lines ("line" is NULL, use reg_getline()).
///
/// @param line String in which to search or NULL
/// @param startcol Column to start looking for match
/// @param tm Timeout limit or NULL
///
/// @return <= 0 if there is no match and number of lines contained in the
/// match otherwise.
static long nfa_regexec_both(char_u *line, colnr_T startcol, proftime_T *tm)
{
  nfa_regprog_T   *prog;
  long retval = 0L;
  int i;
  colnr_T col = startcol;

  if (REG_MULTI) {
    prog = (nfa_regprog_T *)rex.reg_mmatch->regprog;
    line = reg_getline((linenr_T)0);  // relative to the cursor
    rex.reg_startpos = rex.reg_mmatch->startpos;
    rex.reg_endpos = rex.reg_mmatch->endpos;
  } else {
    prog = (nfa_regprog_T *)rex.reg_match->regprog;
    rex.reg_startp = rex.reg_match->startp;
    rex.reg_endp = rex.reg_match->endp;
  }

  /* Be paranoid... */
  if (prog == NULL || line == NULL) {
    EMSG(_(e_null));
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

  regline = line;
  reglnum = 0;      /* relative to line */

  nfa_has_zend = prog->has_zend;
  nfa_has_backref = prog->has_backref;
  nfa_nsubexpr = prog->nsubexp;
  nfa_listid = 1;
  nfa_alt_listid = 2;
  nfa_regengine.expr = prog->pattern;

  if (prog->reganch && col > 0)
    return 0L;

  need_clear_subexpr = TRUE;
  /* Clear the external match subpointers if necessary. */
  if (prog->reghasz == REX_SET) {
    nfa_has_zsubexpr = TRUE;
    need_clear_zsubexpr = TRUE;
  } else
    nfa_has_zsubexpr = FALSE;

  if (prog->regstart != NUL) {
    /* Skip ahead until a character we know the match must start with.
     * When there is none there is no match. */
    if (skip_to_start(prog->regstart, &col) == FAIL)
      return 0L;

    // If match_text is set it contains the full text that must match.
    // Nothing else to try. Doesn't handle combining chars well.
    if (prog->match_text != NULL && !rex.reg_icombine) {
      return find_match_text(col, prog->regstart, prog->match_text);
    }
  }

  // If the start column is past the maximum column: no need to try.
  if (rex.reg_maxcol > 0 && col >= rex.reg_maxcol) {
    goto theend;
  }

  nstate = prog->nstate;
  for (i = 0; i < nstate; ++i) {
    prog->state[i].id = i;
    prog->state[i].lastlist[0] = 0;
    prog->state[i].lastlist[1] = 0;
  }

  retval = nfa_regtry(prog, col, tm);

  nfa_regengine.expr = NULL;

theend:
  return retval;
}

/*
 * Compile a regular expression into internal code for the NFA matcher.
 * Returns the program in allocated space.  Returns NULL for an error.
 */
static regprog_T *nfa_regcomp(char_u *expr, int re_flags)
{
  nfa_regprog_T       *prog = NULL;
  int                 *postfix;

  if (expr == NULL)
    return NULL;

  nfa_regengine.expr = expr;
  nfa_re_flags = re_flags;

  init_class_tab();

  nfa_regcomp_start(expr, re_flags);

  /* Build postfix form of the regexp. Needed to build the NFA
   * (and count its size). */
  postfix = re2post();
  if (postfix == NULL) {
    // TODO(vim): only give this error for debugging?
    if (post_ptr >= post_end) {
      IEMSGN("Internal error: estimated max number "
             "of states insufficient: %" PRId64,
             post_end - post_start);
    }
    goto fail;              // Cascaded (syntax?) error
  }

  /*
   * In order to build the NFA, we parse the input regexp twice:
   * 1. first pass to count size (so we can allocate space)
   * 2. second to emit code
   */
#ifdef REGEXP_DEBUG
  {
    FILE *f = fopen(NFA_REGEXP_RUN_LOG, "a");

    if (f != NULL) {
      fprintf(
          f,
          "\n*****************************\n\n\n\n\tCompiling regexp \"%s\" ... hold on !\n",
          expr);
      fclose(f);
    }
  }
#endif

  /*
   * PASS 1
   * Count number of NFA states in "nstate". Do not build the NFA.
   */
  post2nfa(postfix, post_ptr, TRUE);

  /* allocate the regprog with space for the compiled regexp */
  size_t prog_size = sizeof(nfa_regprog_T) + sizeof(nfa_state_T) * (nstate - 1);
  prog = xmalloc(prog_size);
  state_ptr = prog->state;

  /*
   * PASS 2
   * Build the NFA
   */
  prog->start = post2nfa(postfix, post_ptr, FALSE);
  if (prog->start == NULL)
    goto fail;

  prog->regflags = regflags;
  prog->engine = &nfa_regengine;
  prog->nstate = nstate;
  prog->has_zend = nfa_has_zend;
  prog->has_backref = nfa_has_backref;
  prog->nsubexp = regnpar;

  nfa_postprocess(prog);

  prog->reganch = nfa_get_reganch(prog->start, 0);
  prog->regstart = nfa_get_regstart(prog->start, 0);
  prog->match_text = nfa_get_match_text(prog->start);

#ifdef REGEXP_DEBUG
  nfa_postfix_dump(expr, OK);
  nfa_dump(prog);
#endif
  /* Remember whether this pattern has any \z specials in it. */
  prog->reghasz = re_has_z;
  prog->pattern = vim_strsave(expr);
  nfa_regengine.expr = NULL;

out:
  xfree(post_start);
  post_start = post_ptr = post_end = NULL;
  state_ptr = NULL;
  return (regprog_T *)prog;

fail:
  xfree(prog);
  prog = NULL;
#ifdef REGEXP_DEBUG
  nfa_postfix_dump(expr, FAIL);
#endif
  nfa_regengine.expr = NULL;
  goto out;
}

/*
 * Free a compiled regexp program, returned by nfa_regcomp().
 */
static void nfa_regfree(regprog_T *prog)
{
  if (prog != NULL) {
    xfree(((nfa_regprog_T *)prog)->match_text);
    xfree(((nfa_regprog_T *)prog)->pattern);
    xfree(prog);
  }
}

/*
 * Match a regexp against a string.
 * "rmp->regprog" is a compiled regexp as returned by nfa_regcomp().
 * Uses curbuf for line count and 'iskeyword'.
 * If "line_lbr" is true, consider a "\n" in "line" to be a line break.
 *
 * Returns <= 0 for failure, number of lines contained in the match otherwise.
 */
static int 
nfa_regexec_nl (
    regmatch_T *rmp,
    char_u *line,      /* string to match against */
    colnr_T col,       /* column to start looking for match */
    bool line_lbr
)
{
  rex.reg_match = rmp;
  rex.reg_mmatch = NULL;
  rex.reg_maxline = 0;
  rex.reg_line_lbr = line_lbr;
  rex.reg_buf = curbuf;
  rex.reg_win = NULL;
  rex.reg_ic = rmp->rm_ic;
  rex.reg_icombine = false;
  rex.reg_maxcol = 0;
  return nfa_regexec_both(line, col, NULL);
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
static long nfa_regexec_multi(regmmatch_T *rmp, win_T *win, buf_T *buf,
                              linenr_T lnum, colnr_T col, proftime_T *tm)
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
  rex.reg_maxcol = rmp->rmm_maxcol;

  return nfa_regexec_both(NULL, col, tm);
}
