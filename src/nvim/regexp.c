// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/*
 * Handling of regular expressions: vim_regcomp(), vim_regexec(), vim_regsub()
 */

// By default: do not create debugging logs or files related to regular
// expressions, even when compiling with -DDEBUG.
// Uncomment the second line to get the regexp debugging.
// #undef REGEXP_DEBUG
// #define REGEXP_DEBUG

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>

#include "nvim/ascii.h"
#include "nvim/charset.h"
#include "nvim/eval.h"
#include "nvim/eval/userfunc.h"
#include "nvim/ex_cmds2.h"
#include "nvim/garray.h"
#include "nvim/mark.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/os/input.h"
#include "nvim/plines.h"
#include "nvim/regexp.h"
#include "nvim/strings.h"
#include "nvim/vim.h"

#ifdef REGEXP_DEBUG
// show/save debugging data when BT engine is used
# define BT_REGEXP_DUMP
// save the debugging data to a file instead of displaying it
# define BT_REGEXP_LOG
# define BT_REGEXP_DEBUG_LOG
# define BT_REGEXP_DEBUG_LOG_NAME       "bt_regexp_debug.log"
#endif

/*
 * Magic characters have a special meaning, they don't match literally.
 * Magic characters are negative.  This separates them from literal characters
 * (possibly multi-byte).  Only ASCII characters can be Magic.
 */
#define Magic(x)        ((int)(x) - 256)
#define un_Magic(x)     ((x) + 256)
#define is_Magic(x)     ((x) < 0)

/*
 * We should define ftpr as a pointer to a function returning a pointer to
 * a function returning a pointer to a function ...
 * This is impossible, so we declare a pointer to a function returning a
 * pointer to a function returning void. This should work for all compilers.
 */
typedef void (*(*fptr_T)(int *, int))(void);

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
#define UCHARAT(p)      ((int)(*(char_u *)(p)))

// Used for an error (down from) vim_regcomp(): give the error message, set
// rc_did_emsg and return NULL
#define EMSG_RET_NULL(m) return (emsg(m), rc_did_emsg = true, (void *)NULL)
#define IEMSG_RET_NULL(m) return (iemsg(m), rc_did_emsg = true, (void *)NULL)
#define EMSG_RET_FAIL(m) return (emsg(m), rc_did_emsg = true, FAIL)
#define EMSG2_RET_NULL(m, c) \
  return (semsg((m), (c) ? "" : "\\"), rc_did_emsg = true, (void *)NULL)
#define EMSG3_RET_NULL(m, c, a) \
  return (semsg((const char *)(m), (c) ? "" : "\\", (a)), rc_did_emsg = true, (void *)NULL)
#define EMSG2_RET_FAIL(m, c) \
  return (semsg((m), (c) ? "" : "\\"), rc_did_emsg = true, FAIL)
#define EMSG_ONE_RET_NULL EMSG2_RET_NULL(_("E369: invalid item in %s%%[]"), reg_magic == MAGIC_ALL)

#define MAX_LIMIT       (32767L << 16L)

static char_u e_missingbracket[] = N_("E769: Missing ] after %s[");
static char_u e_reverse_range[] = N_("E944: Reverse range in character class");
static char_u e_large_class[] = N_("E945: Range too large in character class");
static char_u e_unmatchedpp[] = N_("E53: Unmatched %s%%(");
static char_u e_unmatchedp[] = N_("E54: Unmatched %s(");
static char_u e_unmatchedpar[] = N_("E55: Unmatched %s)");
static char_u e_z_not_allowed[] = N_("E66: \\z( not allowed here");
static char_u e_z1_not_allowed[] = N_("E67: \\z1 - \\z9 not allowed here");
static char_u e_missing_sb[] = N_("E69: Missing ] after %s%%[");
static char_u e_empty_sb[] = N_("E70: Empty %s%%[]");
static char_u e_recursive[] = N_("E956: Cannot use pattern recursively");
static char_u e_regexp_number_after_dot_pos_search[]
  = N_("E1204: No Number allowed after .: '\\%%%c'");

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

static char_u *reg_prev_sub = NULL;

/*
 * REGEXP_INRANGE contains all characters which are always special in a []
 * range after '\'.
 * REGEXP_ABBR contains all characters which act as abbreviations after '\'.
 * These are:
 *  \n  - New line (NL).
 *  \r  - Carriage Return (CR).
 *  \t  - Tab (TAB).
 *  \e  - Escape (ESC).
 *  \b  - Backspace (Ctrl_H).
 *  \d  - Character code in decimal, eg \d123
 *  \o  - Character code in octal, eg \o80
 *  \x  - Character code in hex, eg \x4a
 *  \u  - Multibyte character code, eg \u20ac
 *  \U  - Long multibyte character code, eg \U12345678
 */
static char REGEXP_INRANGE[] = "]^-n\\";
static char REGEXP_ABBR[] = "nrtebdoxuU";

/*
 * Translate '\x' to its control character, except "\n", which is Magic.
 */
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

/*
 * Check for a character class name "[:name:]".  "pp" points to the '['.
 * Returns one of the CLASS_ items. CLASS_NONE means that no item was
 * recognized.  Otherwise "pp" is advanced to after the item.
 */
static int get_char_class(char_u **pp)
{
  static const char *(class_names[]) =
  {
    "alnum:]",
#define CLASS_ALNUM 0
    "alpha:]",
#define CLASS_ALPHA 1
    "blank:]",
#define CLASS_BLANK 2
    "cntrl:]",
#define CLASS_CNTRL 3
    "digit:]",
#define CLASS_DIGIT 4
    "graph:]",
#define CLASS_GRAPH 5
    "lower:]",
#define CLASS_LOWER 6
    "print:]",
#define CLASS_PRINT 7
    "punct:]",
#define CLASS_PUNCT 8
    "space:]",
#define CLASS_SPACE 9
    "upper:]",
#define CLASS_UPPER 10
    "xdigit:]",
#define CLASS_XDIGIT 11
    "tab:]",
#define CLASS_TAB 12
    "return:]",
#define CLASS_RETURN 13
    "backspace:]",
#define CLASS_BACKSPACE 14
    "escape:]",
#define CLASS_ESCAPE 15
    "ident:]",
#define CLASS_IDENT 16
    "keyword:]",
#define CLASS_KEYWORD 17
    "fname:]",
#define CLASS_FNAME 18
  };
#define CLASS_NONE 99
  int i;

  if ((*pp)[1] == ':') {
    for (i = 0; i < (int)ARRAY_SIZE(class_names); i++) {
      if (STRNCMP(*pp + 2, class_names[i], STRLEN(class_names[i])) == 0) {
        *pp += STRLEN(class_names[i]) + 2;
        return i;
      }
    }
  }
  return CLASS_NONE;
}

/*
 * Specific version of character class functions.
 * Using a table to keep this fast.
 */
static short class_tab[256];

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

static char_u *regparse;        ///< Input-scan pointer.
static int regnpar;             ///< () count.
static bool wants_nfa;          ///< regex should use NFA engine
static int regnzpar;            ///< \z() count.
static int re_has_z;            ///< \z item detected
static unsigned regflags;       ///< RF_ flags for prog
static int had_eol;             ///< true when EOL found by vim_regcomp()

static int reg_magic;           // magicness of the pattern:
#define MAGIC_NONE      1       // "\V" very unmagic
#define MAGIC_OFF       2       // "\M" or 'magic' off
#define MAGIC_ON        3       // "\m" or 'magic'
#define MAGIC_ALL       4       // "\v" very magic

static int reg_string;          // matching with a string instead of a buffer
                                // line
static int reg_strict;          // "[abc" is illegal

/*
 * META contains all characters that may be magic, except '^' and '$'.
 */

// uncrustify:off

// META[] is used often enough to justify turning it into a table.
static char_u META_flags[] = {
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
  char_u *regparse;
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

/*
 * Check for an equivalence class name "[=a=]".  "pp" points to the '['.
 * Returns a character representing the class. Zero means that no item was
 * recognized.  Otherwise "pp" is advanced to after the item.
 */
static int get_equi_class(char_u **pp)
{
  int c;
  int l = 1;
  char_u *p = *pp;

  if (p[1] == '=' && p[2] != NUL) {
    l = utfc_ptr2len((char *)p + 2);
    if (p[l + 2] == '=' && p[l + 3] == ']') {
      c = utf_ptr2char((char *)p + 2);
      *pp += l + 4;
      return c;
    }
  }
  return 0;
}

/*
 * Check for a collating element "[.a.]".  "pp" points to the '['.
 * Returns a character. Zero means that no item was recognized.  Otherwise
 * "pp" is advanced to after the item.
 * Currently only single characters are recognized!
 */
static int get_coll_element(char_u **pp)
{
  int c;
  int l = 1;
  char_u *p = *pp;

  if (p[0] != NUL && p[1] == '.' && p[2] != NUL) {
    l = utfc_ptr2len((char *)p + 2);
    if (p[l + 2] == '.' && p[l + 3] == ']') {
      c = utf_ptr2char((char *)p + 2);
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

/*
 * Skip over a "[]" range.
 * "p" must point to the character after the '['.
 * The returned pointer is on the matching ']', or the terminating NUL.
 */
static char_u *skip_anyof(char_u *p)
{
  int l;

  if (*p == '^') {  // Complement of range.
    p++;
  }
  if (*p == ']' || *p == '-') {
    p++;
  }
  while (*p != NUL && *p != ']') {
    if ((l = utfc_ptr2len((char *)p)) > 1) {
      p += l;
    } else if (*p == '-') {
      p++;
      if (*p != ']' && *p != NUL) {
        MB_PTR_ADV(p);
      }
    } else if (*p == '\\'
               && (vim_strchr(REGEXP_INRANGE, p[1]) != NULL
                   || (!reg_cpo_lit
                       && vim_strchr(REGEXP_ABBR, p[1]) != NULL))) {
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

/*
 * Skip past regular expression.
 * Stop at end of "startp" or where "dirc" is found ('/', '?', etc).
 * Take care of characters with a backslash in front of it.
 * Skip strings inside [ and ].
 * When "newp" is not NULL and "dirc" is '?', make an allocated copy of the
 * expression and change "\?" to "?".  If "*newp" is not NULL the expression
 * is changed in-place.
 */
char_u *skip_regexp(char_u *startp, int dirc, int magic, char_u **newp)
{
  int mymagic;
  char_u *p = startp;

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
        if (*newp == NULL) {
          *newp = vim_strsave(startp);
          p = *newp + (p - startp);
        }
        STRMOVE(p, p + 1);
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
  return p;
}

// variables used for parsing
static int prevchr_len;    // byte length of previous char
static int at_start;       // True when on the first character
static int prev_at_start;  // True when on the second character

/*
 * Start parsing at "str".
 */
static void initchr(char_u *str)
{
  regparse = str;
  prevchr_len = 0;
  curchr = prevprevchr = prevchr = nextchr = -1;
  at_start = true;
  prev_at_start = false;
}

/*
 * Save the current parse state, so that it can be restored and parsing
 * starts in the same state again.
 */
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

/*
 * Restore a previously saved parse state.
 */
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

/*
 * Get the next character without advancing.
 */
static int peekchr(void)
{
  static int after_slash = false;

  if (curchr != -1) {
    return curchr;
  }

  switch (curchr = regparse[0]) {
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
      char_u *p = regparse + 1;
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
    int c = regparse[1];

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
      /*
       * Handle abbreviations, like "\t" for TAB -- webb
       */
      curchr = backslash_trans(c);
    } else if (reg_magic == MAGIC_NONE && (c == '$' || c == '^')) {
      curchr = toggle_Magic(c);
    } else {
      // Next character can never be (made) magic?
      // Then backslashing it won't do anything.
      curchr = utf_ptr2char((char *)regparse + 1);
    }
    break;
  }

  default:
    curchr = utf_ptr2char((char *)regparse);
  }

  return curchr;
}

/*
 * Eat one lexed character.  Do this in a way that we can undo it.
 */
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
    prevchr_len += utf_ptr2len((char *)regparse + prevchr_len);
  }
  regparse += prevchr_len;
  prev_at_start = at_start;
  at_start = false;
  prevprevchr = prevchr;
  prevchr = curchr;
  curchr = nextchr;         // use previously unget char, or -1
  nextchr = -1;
}

/*
 * Skip a character while keeping the value of prev_at_start for at_start.
 * prevchr and prevprevchr are also kept.
 */
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

/*
 * Get the next character from the pattern. We know about magic and such, so
 * therefore we need a lexical analyzer.
 */
static int getchr(void)
{
  int chr = peekchr();

  skipchr();
  return chr;
}

/*
 * put character back.  Works only once!
 */
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

/*
 * Get and return the value of the hex string at the current position.
 * Return -1 if there is no valid hex number.
 * The position is updated:
 *     blahblah\%x20asdf
 *         before-^ ^-after
 * The parameter controls the maximum number of input characters. This will be
 * 2 when reading a \%x20 sequence and 4 when reading a \%u20AC sequence.
 */
static int64_t gethexchrs(int maxinputlen)
{
  int64_t nr = 0;
  int c;
  int i;

  for (i = 0; i < maxinputlen; ++i) {
    c = regparse[0];
    if (!ascii_isxdigit(c)) {
      break;
    }
    nr <<= 4;
    nr |= hex2nr(c);
    ++regparse;
  }

  if (i == 0) {
    return -1;
  }
  return nr;
}

/*
 * Get and return the value of the decimal string immediately after the
 * current position. Return -1 for invalid.  Consumes all digits.
 */
static int64_t getdecchrs(void)
{
  int64_t nr = 0;
  int c;
  int i;

  for (i = 0;; ++i) {
    c = regparse[0];
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

/*
 * get and return the value of the octal string immediately after the current
 * position. Return -1 for invalid, or 0-255 for valid. Smart enough to handle
 * numbers > 377 correctly (for example, 400 is treated as 40) and doesn't
 * treat 8 or 9 as recognised characters. Position is updated:
 *     blahblah\%o210asdf
 *         before-^  ^-after
 */
static int64_t getoctchrs(void)
{
  int64_t nr = 0;
  int c;
  int i;

  for (i = 0; i < 3 && nr < 040; i++) {  // -V536
    c = regparse[0];
    if (c < '0' || c > '7') {
      break;
    }
    nr <<= 3;
    nr |= hex2nr(c);
    ++regparse;
  }

  if (i == 0) {
    return -1;
  }
  return nr;
}

/*
 * read_limits - Read two integers to be taken as a minimum and maximum.
 * If the first character is '-', then the range is reversed.
 * Should end with 'end'.  If minval is missing, zero is default, if maxval is
 * missing, a very big number is the default.
 */
static int read_limits(long *minval, long *maxval)
{
  int reverse = false;
  char_u *first_char;
  long tmp;

  if (*regparse == '-') {
    // Starts with '-', so reverse the range later.
    regparse++;
    reverse = true;
  }
  first_char = regparse;
  *minval = getdigits_long(&regparse, false, 0);
  if (*regparse == ',') {           // There is a comma.
    if (ascii_isdigit(*++regparse)) {
      *maxval = getdigits_long(&regparse, false, MAX_LIMIT);
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

  /*
   * Reverse the range if there was a '-', or make sure it is in the right
   * order otherwise.
   */
  if ((!reverse && *minval > *maxval) || (reverse && *minval < *maxval)) {
    tmp = *minval;
    *minval = *maxval;
    *maxval = tmp;
  }
  skipchr();            // let's be friends with the lexer again
  return OK;
}

/*
 * vim_regexec and friends
 */

/*
 * Global work variables for vim_regexec().
 */

// Sometimes need to save a copy of a line.  Since alloc()/free() is very
// slow, we keep one allocated piece of memory and only re-allocate it when
// it's too small.  It's freed in bt_regexec_both() when finished.
static char_u *reg_tofree = NULL;
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
  char_u **reg_startp;
  char_u **reg_endp;
  lpos_T *reg_startpos;
  lpos_T *reg_endpos;
  win_T *reg_win;
  buf_T *reg_buf;
  linenr_T reg_firstlnum;
  linenr_T reg_maxline;
  bool reg_line_lbr;  // "\n" in string is line break

  // The current match-position is remembered with these variables:
  linenr_T lnum;  ///< line number, relative to first line
  char_u *line;   ///< start of current line
  char_u *input;  ///< current input, points into "line"

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

// Return true if character 'c' is included in 'iskeyword' option for
// "reg_buf" buffer.
static bool reg_iswordc(int c)
{
  return vim_iswordc_buf(c, rex.reg_buf);
}

/*
 * Get pointer to the line "lnum", which is relative to "reg_firstlnum".
 */
static char_u *reg_getline(linenr_T lnum)
{
  // when looking behind for a match/no-match lnum is negative.  But we
  // can't go before line 1
  if (rex.reg_firstlnum + lnum < 1) {
    return NULL;
  }
  if (lnum > rex.reg_maxline) {
    // Must have matched the "\n" in the last line.
    return (char_u *)"";
  }
  return ml_get_buf(rex.reg_buf, rex.reg_firstlnum + lnum, false);
}

static char_u *reg_startzp[NSUBEXP];  // Workspace to mark beginning
static char_u *reg_endzp[NSUBEXP];    //   and end of \z(...\) matches
static lpos_T reg_startzpos[NSUBEXP];   // idem, beginning pos
static lpos_T reg_endzpos[NSUBEXP];     // idem, end pos

// true if using multi-line regexp.
#define REG_MULTI       (rex.reg_match == NULL)

/*
 * Create a new extmatch and mark it as referenced once.
 */
static reg_extmatch_T *make_extmatch(void)
  FUNC_ATTR_NONNULL_RET
{
  reg_extmatch_T *em = xcalloc(1, sizeof(reg_extmatch_T));
  em->refcnt = 1;
  return em;
}

/*
 * Add a reference to an extmatch.
 */
reg_extmatch_T *ref_extmatch(reg_extmatch_T *em)
{
  if (em != NULL) {
    em->refcnt++;
  }
  return em;
}

/*
 * Remove a reference to an extmatch.  If there are no references left, free
 * the info.
 */
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
    return mb_get_class_tab(rex.input - 1 - utf_head_off(rex.line, rex.input - 1),
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

  // Check if the buffer is the current buffer.
  if (rex.reg_buf != curbuf || VIsual.lnum == 0) {
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
    rex.line = reg_getline(rex.lnum);
    rex.input = rex.line + col;

    unsigned int cols_u = win_linetabsize(wp, rex.line, col);
    assert(cols_u <= MAXCOL);
    colnr_T cols = (colnr_T)cols_u;
    if (cols < start || cols > end - (*p_sel == 'e')) {
      return false;
    }
  }
  return true;
}

/*
 * Check the regexp program for its magic number.
 * Return true if it's wrong.
 */
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

/*
 * Cleanup the subexpressions, if this wasn't done yet.
 * This construction is used to clear the subexpressions only when they are
 * used (to increase speed).
 */
static void cleanup_subexpr(void)
{
  if (rex.need_clear_subexpr) {
    if (REG_MULTI) {
      // Use 0xff to set lnum to -1
      memset(rex.reg_startpos, 0xff, sizeof(lpos_T) * NSUBEXP);
      memset(rex.reg_endpos, 0xff, sizeof(lpos_T) * NSUBEXP);
    } else {
      memset(rex.reg_startp, 0, sizeof(char_u *) * NSUBEXP);
      memset(rex.reg_endp, 0, sizeof(char_u *) * NSUBEXP);
    }
    rex.need_clear_subexpr = false;
  }
}

static void cleanup_zsubexpr(void)
{
  if (rex.need_clear_zsubexpr) {
    if (REG_MULTI) {
      // Use 0xff to set lnum to -1
      memset(reg_startzpos, 0xff, sizeof(lpos_T) * NSUBEXP);
      memset(reg_endzpos, 0xff, sizeof(lpos_T) * NSUBEXP);
    } else {
      memset(reg_startzp, 0, sizeof(char_u *) * NSUBEXP);
      memset(reg_endzp, 0, sizeof(char_u *) * NSUBEXP);
    }
    rex.need_clear_zsubexpr = false;
  }
}

// Advance rex.lnum, rex.line and rex.input to the next line.
static void reg_nextline(void)
{
  rex.line = reg_getline(++rex.lnum);
  rex.input = rex.line;
  fast_breakcheck();
}

/*
 * Check whether a backreference matches.
 * Returns RA_FAIL, RA_NOMATCH or RA_MATCH.
 * If "bytelen" is not NULL, it is set to the byte length of the match in the
 * last line.
 */
static int match_with_backref(linenr_T start_lnum, colnr_T start_col, linenr_T end_lnum,
                              colnr_T end_col, int *bytelen)
{
  linenr_T clnum = start_lnum;
  colnr_T ccol = start_col;
  int len;
  char_u *p;

  if (bytelen != NULL) {
    *bytelen = 0;
  }
  for (;;) {
    // Since getting one line may invalidate the other, need to make copy.
    // Slow!
    if (rex.line != reg_tofree) {
      len = (int)STRLEN(rex.line);
      if (reg_tofree == NULL || len >= (int)reg_tofreelen) {
        len += 50;              // get some extra
        xfree(reg_tofree);
        reg_tofree = xmalloc(len);
        reg_tofreelen = len;
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
      len = (int)STRLEN(p + ccol);
    }

    if (cstrncmp(p + ccol, rex.input, &len) != 0) {
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
static decomp_T decomp_table[0xfb4f - 0xfb20 + 1] =
{
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

// Compare two strings, ignore case if rex.reg_ic set.
// Return 0 if strings match, non-zero otherwise.
// Correct the length "*n" when composing characters are ignored.
static int cstrncmp(char_u *s1, char_u *s2, int *n)
{
  int result;

  if (!rex.reg_ic) {
    result = STRNCMP(s1, s2, *n);
  } else {
    assert(*n >= 0);
    result = mb_strnicmp(s1, s2, (size_t)*n);
  }

  // if it failed and it's utf8 and we want to combineignore:
  if (result != 0 && rex.reg_icombine) {
    char_u *str1, *str2;
    int c1, c2, c11, c12;
    int junk;

    // we have to handle the strcmp ourselves, since it is necessary to
    // deal with the composing characters by ignoring them:
    str1 = s1;
    str2 = s2;
    c1 = c2 = 0;
    while ((int)(str1 - s1) < *n) {
      c1 = mb_ptr2char_adv((const char_u **)&str1);
      c2 = mb_ptr2char_adv((const char_u **)&str2);

      /* decompose the character if necessary, into 'base' characters
       * because I don't care about Arabic, I will hard-code the Hebrew
       * which I *do* care about!  So sue me... */
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
static inline char_u *cstrchr(const char_u *const s, const int c)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
  FUNC_ATTR_ALWAYS_INLINE
{
  if (!rex.reg_ic) {
    return (char_u *)vim_strchr((char *)s, c);
  }

  // Use folded case for UTF-8, slow! For ASCII use libc strpbrk which is
  // expected to be highly optimized.
  if (c > 0x80) {
    const int folded_c = utf_fold(c);
    for (const char_u *p = s; *p != NUL; p += utfc_ptr2len((char *)p)) {
      if (utf_fold(utf_ptr2char((char *)p)) == folded_c) {
        return (char_u *)p;
      }
    }
    return NULL;
  }

  int cc;
  if (ASCII_ISUPPER(c)) {
    cc = TOLOWER_ASC(c);
  } else if (ASCII_ISLOWER(c)) {
    cc = TOUPPER_ASC(c);
  } else {
    return (char_u *)vim_strchr((char *)s, c);
  }

  char tofind[] = { (char)c, (char)cc, NUL };
  return (char_u *)strpbrk((const char *)s, tofind);
}

////////////////////////////////////////////////////////////////
//                    regsub stuff                            //
////////////////////////////////////////////////////////////////

// This stuff below really confuses cc on an SGI -- webb

static fptr_T do_upper(int *d, int c)
{
  *d = mb_toupper(c);

  return (fptr_T)NULL;
}

static fptr_T do_Upper(int *d, int c)
{
  *d = mb_toupper(c);

  return (fptr_T)do_Upper;
}

static fptr_T do_lower(int *d, int c)
{
  *d = mb_tolower(c);

  return (fptr_T)NULL;
}

static fptr_T do_Lower(int *d, int c)
{
  *d = mb_tolower(c);

  return (fptr_T)do_Lower;
}

/*
 * regtilde(): Replace tildes in the pattern by the old pattern.
 *
 * Short explanation of the tilde: It stands for the previous replacement
 * pattern.  If that previous pattern also contains a ~ we should go back a
 * step further...  But we insert the previous pattern into the current one
 * and remember that.
 * This still does not handle the case where "magic" changes.  So require the
 * user to keep his hands off of "magic".
 *
 * The tildes are parsed once before the first call to vim_regsub().
 */
char_u *regtilde(char_u *source, int magic, bool preview)
{
  char_u *newsub = source;
  char_u *tmpsub;
  char_u *p;
  int len;
  int prevlen;

  for (p = newsub; *p; ++p) {
    if ((*p == '~' && magic) || (*p == '\\' && *(p + 1) == '~' && !magic)) {
      if (reg_prev_sub != NULL) {
        // length = len(newsub) - 1 + len(prev_sub) + 1
        prevlen = (int)STRLEN(reg_prev_sub);
        tmpsub = xmalloc(STRLEN(newsub) + prevlen);
        // copy prefix
        len = (int)(p - newsub);              // not including ~
        memmove(tmpsub, newsub, (size_t)len);
        // interpret tilde
        memmove(tmpsub + len, reg_prev_sub, (size_t)prevlen);
        // copy postfix
        if (!magic) {
          p++;                                // back off backslash
        }
        STRCPY(tmpsub + len + prevlen, p + 1);

        if (newsub != source) {               // already allocated newsub
          xfree(newsub);
        }
        newsub = tmpsub;
        p = newsub + len + prevlen;
      } else if (magic) {
        STRMOVE(p, p + 1);              // remove '~'
      } else {
        STRMOVE(p, p + 2);              // remove '\~'
      }
      p--;
    } else {
      if (*p == '\\' && p[1]) {         // skip escaped characters
        p++;
      }
      p += utfc_ptr2len((char *)p) - 1;
    }
  }

  // Only change reg_prev_sub when not previewing.
  if (!preview) {
    xfree(reg_prev_sub);
    if (newsub != source) {             // newsub was allocated, just keep it
      reg_prev_sub = newsub;
    } else {                            // no ~ found, need to save newsub
      reg_prev_sub = vim_strsave(newsub);
    }
  }

  return newsub;
}

static bool can_f_submatch = false;  // true when submatch() can be used

// These pointers are used for reg_submatch().  Needed for when the
// substitution string is an expression that contains a call to substitute()
// and submatch().
typedef struct {
  regmatch_T *sm_match;
  regmmatch_T *sm_mmatch;
  linenr_T sm_firstlnum;
  linenr_T sm_maxline;
  int sm_line_lbr;
} regsubmatch_T;

static regsubmatch_T rsm;  // can only be used when can_f_submatch is true

/// Put the submatches in "argv[argskip]" which is a list passed into
/// call_func() by vim_regsub_both().
static int fill_submatch_list(int argc FUNC_ATTR_UNUSED, typval_T *argv, int argskip, int argcount)
  FUNC_ATTR_NONNULL_ALL
{
  typval_T *listarg = argv + argskip;

  if (argcount == argskip) {
    // called function doesn't take a submatches argument
    return argskip;
  }

  // Relies on sl_list to be the first item in staticList10_T.
  tv_list_init_static10((staticList10_T *)listarg->vval.v_list);

  // There are always 10 list items in staticList10_T.
  listitem_T *li = tv_list_first(listarg->vval.v_list);
  for (int i = 0; i < 10; i++) {
    char_u *s = rsm.sm_match->startp[i];
    if (s == NULL || rsm.sm_match->endp[i] == NULL) {
      s = NULL;
    } else {
      s = vim_strnsave(s, rsm.sm_match->endp[i] - s);
    }
    TV_LIST_ITEM_TV(li)->v_type = VAR_STRING;
    TV_LIST_ITEM_TV(li)->vval.v_string = (char *)s;
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
/// If "copy" is true really copy into "dest".
/// If "copy" is false nothing is copied, this is just to find out the length
/// of the result.
///
/// If "backslash" is true, a backslash will be removed later, need to double
/// them to keep them, and insert a backslash before a CR to avoid it being
/// replaced with a line break later.
///
/// Note: The matched text must not change between the call of
/// vim_regexec()/vim_regexec_multi() and vim_regsub()!  It would make the back
/// references invalid!
///
/// Returns the size of the replacement, including terminating NUL.
int vim_regsub(regmatch_T *rmp, char_u *source, typval_T *expr, char_u *dest, int copy, int magic,
               int backslash)
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
  int result = vim_regsub_both(source, expr, dest, copy, magic, backslash);

  rex_in_use = rex_in_use_save;
  if (rex_in_use) {
    rex = rex_save;
  }

  return result;
}

int vim_regsub_multi(regmmatch_T *rmp, linenr_T lnum, char_u *source, char_u *dest, int copy,
                     int magic, int backslash)
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
  int result = vim_regsub_both(source, NULL, dest, copy, magic, backslash);

  rex_in_use = rex_in_use_save;
  if (rex_in_use) {
    rex = rex_save;
  }

  return result;
}

static int vim_regsub_both(char_u *source, typval_T *expr, char_u *dest, int copy, int magic,
                           int backslash)
{
  char_u *src;
  char_u *dst;
  char_u *s;
  int c;
  int cc;
  int no = -1;
  fptr_T func_all = (fptr_T)NULL;
  fptr_T func_one = (fptr_T)NULL;
  linenr_T clnum = 0;           // init for GCC
  int len = 0;                  // init for GCC
  static char_u *eval_result = NULL;

  // We need to keep track of how many backslashes we escape, so that the byte
  // counts for `extmark_splice` are correct.
  int num_escaped = 0;

  // Be paranoid...
  if ((source == NULL && expr == NULL) || dest == NULL) {
    emsg(_(e_null));
    return 0;
  }
  if (prog_magic_wrong()) {
    return 0;
  }
  src = source;
  dst = dest;

  // When the substitute part starts with "\=" evaluate it as an expression.
  if (expr != NULL || (source[0] == '\\' && source[1] == '=')) {
    // To make sure that the length doesn't change between checking the
    // length and copying the string, and to speed up things, the
    // resulting string is saved from the call with "copy" == false to the
    // call with "copy" == true.
    if (copy) {
      if (eval_result != NULL) {
        STRCPY(dest, eval_result);
        dst += STRLEN(eval_result);
        XFREE_CLEAR(eval_result);
      }
    } else {
      const bool prev_can_f_submatch = can_f_submatch;
      regsubmatch_T rsm_save;

      xfree(eval_result);

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

      if (expr != NULL) {
        typval_T argv[2];
        typval_T rettv;
        staticList10_T matchList = TV_LIST_STATIC10_INIT;
        rettv.v_type = VAR_STRING;
        rettv.vval.v_string = NULL;
        argv[0].v_type = VAR_LIST;
        argv[0].vval.v_list = &matchList.sl_list;
        funcexe_T funcexe = FUNCEXE_INIT;
        funcexe.argv_func = fill_submatch_list;
        funcexe.evaluate = true;
        if (expr->v_type == VAR_FUNC) {
          s = (char_u *)expr->vval.v_string;
          call_func((char *)s, -1, &rettv, 1, argv, &funcexe);
        } else if (expr->v_type == VAR_PARTIAL) {
          partial_T *partial = expr->vval.v_partial;

          s = (char_u *)partial_name(partial);
          funcexe.partial = partial;
          call_func((char *)s, -1, &rettv, 1, argv, &funcexe);
        }
        if (tv_list_len(&matchList.sl_list) > 0) {
          // fill_submatch_list() was called.
          clear_submatch_list(&matchList);
        }
        if (rettv.v_type == VAR_UNKNOWN) {
          // something failed, no need to report another error
          eval_result = NULL;
        } else {
          char buf[NUMBUFLEN];
          eval_result = (char_u *)tv_get_string_buf_chk(&rettv, buf);
          if (eval_result != NULL) {
            eval_result = vim_strsave(eval_result);
          }
        }
        tv_clear(&rettv);
      } else {
        eval_result = (char_u *)eval_to_string((char *)source + 2, NULL, true);
      }

      if (eval_result != NULL) {
        int had_backslash = false;

        for (s = eval_result; *s != NUL; MB_PTR_ADV(s)) {
          // Change NL to CR, so that it becomes a line break,
          // unless called from vim_regexec_nl().
          // Skip over a backslashed character.
          if (*s == NL && !rsm.sm_line_lbr) {
            *s = CAR;
          } else if (*s == '\\' && s[1] != NUL) {
            s++;
            /* Change NL to CR here too, so that this works:
             * :s/abc\\\ndef/\="aaa\\\nbbb"/  on text:
             *   abc\
             *   def
             * Not when called from vim_regexec_nl().
             */
            if (*s == NL && !rsm.sm_line_lbr) {
              *s = CAR;
            }
            had_backslash = true;
          }
        }
        if (had_backslash && backslash) {
          // Backslashes will be consumed, need to double them.
          s = vim_strsave_escaped(eval_result, (char_u *)"\\");
          xfree(eval_result);
          eval_result = s;
        }

        dst += STRLEN(eval_result);
      }

      can_f_submatch = prev_can_f_submatch;
      if (can_f_submatch) {
        rsm = rsm_save;
      }
    }
  } else {
    while ((c = *src++) != NUL) {
      if (c == '&' && magic) {
        no = 0;
      } else if (c == '\\' && *src != NUL) {
        if (*src == '&' && !magic) {
          ++src;
          no = 0;
        } else if ('0' <= *src && *src <= '9') {
          no = *src++ - '0';
        } else if (vim_strchr("uUlLeE", *src)) {
          switch (*src++) {
          case 'u':
            func_one = (fptr_T)do_upper;
            continue;
          case 'U':
            func_all = (fptr_T)do_Upper;
            continue;
          case 'l':
            func_one = (fptr_T)do_lower;
            continue;
          case 'L':
            func_all = (fptr_T)do_Lower;
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
            *dst++ = c;
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
            if (backslash) {
              num_escaped += 1;
              if (copy) {
                *dst = '\\';
              }
              dst++;
            }
            c = *src++;
          }
        } else {
          c = utf_ptr2char((char *)src - 1);
        }
        // Write to buffer, if copy is set.
        if (func_one != NULL) {
          func_one = (fptr_T)(func_one(&cc, c));
        } else if (func_all != NULL) {
          func_all = (fptr_T)(func_all(&cc, c));
        } else {
          // just copy
          cc = c;
        }

        int totlen = utfc_ptr2len((char *)src - 1);

        if (copy) {
          utf_char2bytes(cc, (char *)dst);
        }
        dst += utf_char2len(cc) - 1;
        int clen = utf_ptr2len((char *)src - 1);

        // If the character length is shorter than "totlen", there
        // are composing characters; copy them as-is.
        if (clen < totlen) {
          if (copy) {
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
              len = (int)STRLEN(s);
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
          for (;;) {
            if (len == 0) {
              if (REG_MULTI) {
                if (rex.reg_mmatch->endpos[no].lnum == clnum) {
                  break;
                }
                if (copy) {
                  *dst = CAR;
                }
                dst++;
                s = reg_getline(++clnum);
                if (rex.reg_mmatch->endpos[no].lnum == clnum) {
                  len = rex.reg_mmatch->endpos[no].col;
                } else {
                  len = (int)STRLEN(s);
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
              if (backslash && (*s == CAR || *s == '\\')) {
                /*
                 * Insert a backslash in front of a CR, otherwise
                 * it will be replaced by a line break.
                 * Number of backslashes will be halved later,
                 * double them here.
                 */
                if (copy) {
                  dst[0] = '\\';
                  dst[1] = *s;
                }
                dst += 2;
              } else {
                c = utf_ptr2char((char *)s);

                if (func_one != (fptr_T)NULL) {
                  // Turbo C complains without the typecast
                  func_one = (fptr_T)(func_one(&cc, c));
                } else if (func_all != (fptr_T)NULL) {
                  // Turbo C complains without the typecast
                  func_all = (fptr_T)(func_all(&cc, c));
                } else {  // just copy
                  cc = c;
                }

                {
                  int l;

                  // Copy composing characters separately, one
                  // at a time.
                  l = utf_ptr2len((char *)s) - 1;

                  s += l;
                  len -= l;
                  if (copy) {
                    utf_char2bytes(cc, (char *)dst);
                  }
                  dst += utf_char2len(cc) - 1;
                }
                dst++;
              }

              ++s;
              --len;
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
  return (int)((dst - dest) + 1 - num_escaped);
}

/*
 * Call reg_getline() with the line numbers from the submatch.  If a
 * substitute() was used the reg_maxline and other values have been
 * overwritten.
 */
static char_u *reg_getline_submatch(linenr_T lnum)
{
  char_u *s;
  linenr_T save_first = rex.reg_firstlnum;
  linenr_T save_max = rex.reg_maxline;

  rex.reg_firstlnum = rsm.sm_firstlnum;
  rex.reg_maxline = rsm.sm_maxline;

  s = reg_getline(lnum);

  rex.reg_firstlnum = save_first;
  rex.reg_maxline = save_max;
  return s;
}

/*
 * Used for the submatch() function: get the string from the n'th submatch in
 * allocated memory.
 * Returns NULL when not in a ":s" command and for a non-existing submatch.
 */
char_u *reg_submatch(int no)
{
  char_u *retval = NULL;
  char_u *s;
  int round;
  linenr_T lnum;

  if (!can_f_submatch || no < 0) {
    return NULL;
  }

  if (rsm.sm_match == NULL) {
    ssize_t len;

    /*
     * First round: compute the length and allocate memory.
     * Second round: copy the text.
     */
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
          STRLCPY(retval, s, len + 1);
        }
        len++;
      } else {
        // Multiple lines: take start line from start col, middle
        // lines completely and end line up to end col.
        len = (ssize_t)STRLEN(s);
        if (round == 2) {
          STRCPY(retval, s);
          retval[len] = '\n';
        }
        len++;
        lnum++;
        while (lnum < rsm.sm_mmatch->endpos[no].lnum) {
          s = reg_getline_submatch(lnum++);
          if (round == 2) {
            STRCPY(retval + len, s);
          }
          len += STRLEN(s);
          if (round == 2) {
            retval[len] = '\n';
          }
          len++;
        }
        if (round == 2) {
          STRNCPY(retval + len, reg_getline_submatch(lnum),
                  rsm.sm_mmatch->endpos[no].col);
        }
        len += rsm.sm_mmatch->endpos[no].col;
        if (round == 2) {
          retval[len] = NUL;  // -V595
        }
        len++;
      }

      if (retval == NULL) {
        retval = xmalloc(len);
      }
    }
  } else {
    s = rsm.sm_match->startp[no];
    if (s == NULL || rsm.sm_match->endp[no] == NULL) {
      retval = NULL;
    } else {
      retval = vim_strnsave(s, rsm.sm_match->endp[no] - s);
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

    s = (const char *)reg_getline_submatch(slnum) + scol;
    if (slnum == elnum) {
      tv_list_append_string(list, s, ecol - scol);
    } else {
      tv_list_append_string(list, s, -1);
      for (int i = 1; i < elnum - slnum; i++) {
        s = (const char *)reg_getline_submatch(slnum + i);
        tv_list_append_string(list, s, -1);
      }
      s = (const char *)reg_getline_submatch(elnum);
      tv_list_append_string(list, s, ecol);
    }
  } else {
    s = (const char *)rsm.sm_match->startp[no];
    if (s == NULL || rsm.sm_match->endp[no] == NULL) {
      return NULL;
    }
    list = tv_list_alloc(1);
    tv_list_append_string(list, s, (const char *)rsm.sm_match->endp[no] - s);
  }

  tv_list_ref(list);
  return list;
}

// XXX Do not allow headers generator to catch definitions from regexp_nfa.c
#ifndef DO_NOT_DEFINE_EMPTY_ATTRIBUTES
# include "nvim/regexp_bt.c"
# include "nvim/regexp_nfa.c"
#endif

static regengine_T bt_regengine =
{
  bt_regcomp,
  bt_regfree,
  bt_regexec_nl,
  bt_regexec_multi,
};

static regengine_T nfa_regengine =
{
  nfa_regcomp,
  nfa_regfree,
  nfa_regexec_nl,
  nfa_regexec_multi,
};

// Which regexp engine to use? Needed for vim_regcomp().
// Must match with 'regexpengine'.
static int regexp_engine = 0;

#ifdef REGEXP_DEBUG
static char_u regname[][30] = {
  "AUTOMATIC Regexp Engine",
  "BACKTRACKING Regexp Engine",
  "NFA Regexp Engine"
};
#endif

/*
 * Compile a regular expression into internal code.
 * Returns the program in allocated memory.
 * Use vim_regfree() to free the memory.
 * Returns NULL for an error.
 */
regprog_T *vim_regcomp(char *expr_arg, int re_flags)
{
  regprog_T *prog = NULL;
  char_u *expr = (char_u *)expr_arg;
  int save_called_emsg;

  regexp_engine = p_re;

  // Check for prefix "\%#=", that sets the regexp engine
  if (STRNCMP(expr, "\\%#=", 4) == 0) {
    int newengine = expr[4] - '0';

    if (newengine == AUTOMATIC_ENGINE
        || newengine == BACKTRACKING_ENGINE
        || newengine == NFA_ENGINE) {
      regexp_engine = expr[4] - '0';
      expr += 5;
#ifdef REGEXP_DEBUG
      smsg("New regexp mode selected (%d): %s",
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
  save_called_emsg = called_emsg;
  called_emsg = false;
  if (regexp_engine != BACKTRACKING_ENGINE) {
    prog = nfa_regengine.regcomp(expr,
                                 re_flags + (regexp_engine == AUTOMATIC_ENGINE ? RE_AUTO : 0));
  } else {
    prog = bt_regengine.regcomp(expr, re_flags);
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
    if (regexp_engine == AUTOMATIC_ENGINE && !called_emsg) {
      regexp_engine = BACKTRACKING_ENGINE;
      report_re_switch(expr);
      prog = bt_regengine.regcomp(expr, re_flags);
    }
  }
  called_emsg |= save_called_emsg;

  if (prog != NULL) {
    // Store the info needed to call regcomp() again when the engine turns out
    // to be very slow when executing it.
    prog->re_engine = regexp_engine;
    prog->re_flags = re_flags;
  }

  return prog;
}

/*
 * Free a compiled regexp program, returned by vim_regcomp().
 */
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

static void report_re_switch(char_u *pat)
{
  if (p_verbose > 0) {
    verbose_enter();
    msg_puts(_("Switching to backtracking RE engine for pattern: "));
    msg_puts((char *)pat);
    verbose_leave();
  }
}

/// Matches a regexp against a string.
/// "rmp->regprog" is a compiled regexp as returned by vim_regcomp().
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
static bool vim_regexec_string(regmatch_T *rmp, char_u *line, colnr_T col, bool nl)
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

  int result = rmp->regprog->engine->regexec_nl(rmp, line, col, nl);
  rmp->regprog->re_in_use = false;

  // NFA engine aborted because it's very slow, use backtracking engine instead.
  if (rmp->regprog->re_engine == AUTOMATIC_ENGINE
      && result == NFA_TOO_EXPENSIVE) {
    int save_p_re = p_re;
    int re_flags = rmp->regprog->re_flags;
    char_u *pat = vim_strsave(((nfa_regprog_T *)rmp->regprog)->pattern);

    p_re = BACKTRACKING_ENGINE;
    vim_regfree(rmp->regprog);
    report_re_switch(pat);
    rmp->regprog = vim_regcomp((char *)pat, re_flags);
    if (rmp->regprog != NULL) {
      rmp->regprog->re_in_use = true;
      result = rmp->regprog->engine->regexec_nl(rmp, line, col, nl);
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
bool vim_regexec_prog(regprog_T **prog, bool ignore_case, char_u *line, colnr_T col)
{
  regmatch_T regmatch = { .regprog = *prog, .rm_ic = ignore_case };
  bool r = vim_regexec_string(&regmatch, line, col, false);
  *prog = regmatch.regprog;
  return r;
}

// Note: "rmp->regprog" may be freed and changed.
// Return true if there is a match, false if not.
bool vim_regexec(regmatch_T *rmp, char_u *line, colnr_T col)
{
  return vim_regexec_string(rmp, line, col, false);
}

// Like vim_regexec(), but consider a "\n" in "line" to be a line break.
// Note: "rmp->regprog" may be freed and changed.
// Return true if there is a match, false if not.
bool vim_regexec_nl(regmatch_T *rmp, char_u *line, colnr_T col)
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
long vim_regexec_multi(regmmatch_T *rmp, win_T *win, buf_T *buf, linenr_T lnum, colnr_T col,
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

  int result = rmp->regprog->engine->regexec_multi(rmp, win, buf, lnum, col,
                                                   tm, timed_out);
  rmp->regprog->re_in_use = false;

  // NFA engine aborted because it's very slow, use backtracking engine instead.
  if (rmp->regprog->re_engine == AUTOMATIC_ENGINE
      && result == NFA_TOO_EXPENSIVE) {
    int save_p_re = p_re;
    int re_flags = rmp->regprog->re_flags;
    char_u *pat = vim_strsave(((nfa_regprog_T *)rmp->regprog)->pattern);

    p_re = BACKTRACKING_ENGINE;
    regprog_T *prev_prog = rmp->regprog;

    report_re_switch(pat);
    // checking for \z misuse was already done when compiling for NFA,
    // allow all here
    reg_do_extmatch = REX_ALL;
    rmp->regprog = vim_regcomp((char *)pat, re_flags);
    reg_do_extmatch = 0;

    if (rmp->regprog == NULL) {
      // Somehow compiling the pattern failed now, put back the
      // previous one to avoid "regprog" becoming NULL.
      rmp->regprog = prev_prog;
    } else {
      vim_regfree(prev_prog);

      rmp->regprog->re_in_use = true;
      result = rmp->regprog->engine->regexec_multi(rmp, win, buf, lnum, col,
                                                   tm, timed_out);
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
