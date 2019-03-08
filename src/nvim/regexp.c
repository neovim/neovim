// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/*
 * Handling of regular expressions: vim_regcomp(), vim_regexec(), vim_regsub()
 *
 * NOTICE:
 *
 * This is NOT the original regular expression code as written by Henry
 * Spencer.  This code has been modified specifically for use with the VIM
 * editor, and should not be used separately from Vim.  If you want a good
 * regular expression library, get the original code.  The copyright notice
 * that follows is from the original.
 *
 * END NOTICE
 *
 *	Copyright (c) 1986 by University of Toronto.
 *	Written by Henry Spencer.  Not derived from licensed software.
 *
 *	Permission is granted to anyone to use this software for any
 *	purpose on any computer system, and to redistribute it freely,
 *	subject to the following restrictions:
 *
 *	1. The author is not responsible for the consequences of use of
 *		this software, no matter how awful, even if they arise
 *		from defects in it.
 *
 *	2. The origin of this software must not be misrepresented, either
 *		by explicit claim or by omission.
 *
 *	3. Altered versions must be plainly marked as such, and must not
 *		be misrepresented as being the original software.
 *
 * Beware that some of this code is subtly aware of the way operator
 * precedence is structured in regular expressions.  Serious changes in
 * regular-expression syntax might require a total rethink.
 *
 * Changes have been made by Tony Andrews, Olaf 'Rhialto' Seibert, Robert
 * Webb, Ciaran McCreesh and Bram Moolenaar.
 * Named character class support added by Walter Briscoe (1998 Jul 01)
 */

/* Uncomment the first if you do not want to see debugging logs or files
 * related to regular expressions, even when compiling with -DDEBUG.
 * Uncomment the second to get the regexp debugging. */
/* #undef REGEXP_DEBUG */
/* #define REGEXP_DEBUG */

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/regexp.h"
#include "nvim/charset.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds2.h"
#include "nvim/mark.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/garray.h"
#include "nvim/strings.h"

#ifdef REGEXP_DEBUG
/* show/save debugging data when BT engine is used */
# define BT_REGEXP_DUMP
/* save the debugging data to a file instead of displaying it */
# define BT_REGEXP_LOG
# define BT_REGEXP_DEBUG_LOG
# define BT_REGEXP_DEBUG_LOG_NAME       "bt_regexp_debug.log"
#endif

/*
 * The "internal use only" fields in regexp_defs.h are present to pass info from
 * compile to execute that permits the execute phase to run lots faster on
 * simple cases.  They are:
 *
 * regstart	char that must begin a match; NUL if none obvious; Can be a
 *		multi-byte character.
 * reganch	is the match anchored (at beginning-of-line only)?
 * regmust	string (pointer into program) that match must include, or NULL
 * regmlen	length of regmust string
 * regflags	RF_ values or'ed together
 *
 * Regstart and reganch permit very fast decisions on suitable starting points
 * for a match, cutting down the work a lot.  Regmust permits fast rejection
 * of lines that cannot possibly match.  The regmust tests are costly enough
 * that vim_regcomp() supplies a regmust only if the r.e. contains something
 * potentially expensive (at present, the only such thing detected is * or +
 * at the start of the r.e., which can involve a lot of backup).  Regmlen is
 * supplied because the test in vim_regexec() needs it and vim_regcomp() is
 * computing it anyway.
 */

/*
 * Structure for regexp "program".  This is essentially a linear encoding
 * of a nondeterministic finite-state machine (aka syntax charts or
 * "railroad normal form" in parsing technology).  Each node is an opcode
 * plus a "next" pointer, possibly plus an operand.  "Next" pointers of
 * all nodes except BRANCH and BRACES_COMPLEX implement concatenation; a "next"
 * pointer with a BRANCH on both ends of it is connecting two alternatives.
 * (Here we have one of the subtle syntax dependencies:	an individual BRANCH
 * (as opposed to a collection of them) is never concatenated with anything
 * because of operator precedence).  The "next" pointer of a BRACES_COMPLEX
 * node points to the node after the stuff to be repeated.
 * The operand of some types of node is a literal string; for others, it is a
 * node leading into a sub-FSM.  In particular, the operand of a BRANCH node
 * is the first node of the branch.
 * (NB this is *not* a tree structure: the tail of the branch connects to the
 * thing following the set of BRANCHes.)
 *
 * pattern	is coded like:
 *
 *			  +-----------------+
 *			  |		    V
 * <aa>\|<bb>	BRANCH <aa> BRANCH <bb> --> END
 *		     |	    ^	 |	    ^
 *		     +------+	 +----------+
 *
 *
 *		       +------------------+
 *		       V		  |
 * <aa>*	BRANCH BRANCH <aa> --> BACK BRANCH --> NOTHING --> END
 *		     |	    |		    ^			   ^
 *		     |	    +---------------+			   |
 *		     +---------------------------------------------+
 *
 *
 *		       +----------------------+
 *		       V		      |
 * <aa>\+	BRANCH <aa> --> BRANCH --> BACK  BRANCH --> NOTHING --> END
 *		     |		     |		 ^			^
 *		     |		     +-----------+			|
 *		     +--------------------------------------------------+
 *
 *
 *					+-------------------------+
 *					V			  |
 * <aa>\{}	BRANCH BRACE_LIMITS --> BRACE_COMPLEX <aa> --> BACK  END
 *		     |				    |		     ^
 *		     |				    +----------------+
 *		     +-----------------------------------------------+
 *
 *
 * <aa>\@!<bb>	BRANCH NOMATCH <aa> --> END  <bb> --> END
 *		     |	     |		      ^       ^
 *		     |	     +----------------+       |
 *		     +--------------------------------+
 *
 *						      +---------+
 *						      |		V
 * \z[abc]	BRANCH BRANCH  a  BRANCH  b  BRANCH  c	BRANCH	NOTHING --> END
 *		     |	    |	       |	  |	^		    ^
 *		     |	    |	       |	  +-----+		    |
 *		     |	    |	       +----------------+		    |
 *		     |	    +---------------------------+		    |
 *		     +------------------------------------------------------+
 *
 * They all start with a BRANCH for "\|" alternatives, even when there is only
 * one alternative.
 */

/*
 * The opcodes are:
 */

/* definition	number		   opnd?    meaning */
#define END             0       /*	End of program or NOMATCH operand. */
#define BOL             1       /*	Match "" at beginning of line. */
#define EOL             2       /*	Match "" at end of line. */
#define BRANCH          3       /* node Match this alternative, or the
                                 *	next... */
#define BACK            4       /*	Match "", "next" ptr points backward. */
#define EXACTLY         5       /* str	Match this string. */
#define NOTHING         6       /*	Match empty string. */
#define STAR            7       /* node Match this (simple) thing 0 or more
                                 *	times. */
#define PLUS            8       /* node Match this (simple) thing 1 or more
                                 *	times. */
#define MATCH           9       /* node match the operand zero-width */
#define NOMATCH         10      /* node check for no match with operand */
#define BEHIND          11      /* node look behind for a match with operand */
#define NOBEHIND        12      /* node look behind for no match with operand */
#define SUBPAT          13      /* node match the operand here */
#define BRACE_SIMPLE    14      /* node Match this (simple) thing between m and
                                 *	n times (\{m,n\}). */
#define BOW             15      /*	Match "" after [^a-zA-Z0-9_] */
#define EOW             16      /*	Match "" at    [^a-zA-Z0-9_] */
#define BRACE_LIMITS    17      /* nr nr  define the min & max for BRACE_SIMPLE
                                 *	and BRACE_COMPLEX. */
#define NEWL            18      /*	Match line-break */
#define BHPOS           19      /*	End position for BEHIND or NOBEHIND */


/* character classes: 20-48 normal, 50-78 include a line-break */
#define ADD_NL          30
#define FIRST_NL        ANY + ADD_NL
#define ANY             20      /*	Match any one character. */
#define ANYOF           21      /* str	Match any character in this string. */
#define ANYBUT          22      /* str	Match any character not in this
                                 *	string. */
#define IDENT           23      /*	Match identifier char */
#define SIDENT          24      /*	Match identifier char but no digit */
#define KWORD           25      /*	Match keyword char */
#define SKWORD          26      /*	Match word char but no digit */
#define FNAME           27      /*	Match file name char */
#define SFNAME          28      /*	Match file name char but no digit */
#define PRINT           29      /*	Match printable char */
#define SPRINT          30      /*	Match printable char but no digit */
#define WHITE           31      /*	Match whitespace char */
#define NWHITE          32      /*	Match non-whitespace char */
#define DIGIT           33      /*	Match digit char */
#define NDIGIT          34      /*	Match non-digit char */
#define HEX             35      /*	Match hex char */
#define NHEX            36      /*	Match non-hex char */
#define OCTAL           37      /*	Match octal char */
#define NOCTAL          38      /*	Match non-octal char */
#define WORD            39      /*	Match word char */
#define NWORD           40      /*	Match non-word char */
#define HEAD            41      /*	Match head char */
#define NHEAD           42      /*	Match non-head char */
#define ALPHA           43      /*	Match alpha char */
#define NALPHA          44      /*	Match non-alpha char */
#define LOWER           45      /*	Match lowercase char */
#define NLOWER          46      /*	Match non-lowercase char */
#define UPPER           47      /*	Match uppercase char */
#define NUPPER          48      /*	Match non-uppercase char */
#define LAST_NL         NUPPER + ADD_NL
// -V:WITH_NL:560
#define WITH_NL(op)     ((op) >= FIRST_NL && (op) <= LAST_NL)

#define MOPEN           80   // -89 Mark this point in input as start of
                             //     \( … \) subexpr.  MOPEN + 0 marks start of
                             //     match.
#define MCLOSE          90   // -99 Analogous to MOPEN.  MCLOSE + 0 marks
                             //     end of match.
#define BACKREF         100  // -109 node Match same string again \1-\9.

# define ZOPEN          110  // -119 Mark this point in input as start of
                             //  \z( … \) subexpr.
# define ZCLOSE         120  // -129 Analogous to ZOPEN.
# define ZREF           130  // -139 node Match external submatch \z1-\z9

#define BRACE_COMPLEX   140 /* -149 node Match nodes between m & n times */

#define NOPEN           150     /*	Mark this point in input as start of
                                 \%( subexpr. */
#define NCLOSE          151     /*	Analogous to NOPEN. */

#define MULTIBYTECODE   200     /* mbc	Match one multi-byte character */
#define RE_BOF          201     /*	Match "" at beginning of file. */
#define RE_EOF          202     /*	Match "" at end of file. */
#define CURSOR          203     /*	Match location of cursor. */

#define RE_LNUM         204     /* nr cmp  Match line number */
#define RE_COL          205     /* nr cmp  Match column number */
#define RE_VCOL         206     /* nr cmp  Match virtual column number */

#define RE_MARK         207     /* mark cmp  Match mark position */
#define RE_VISUAL       208     /*	Match Visual area */
#define RE_COMPOSING    209     // any composing characters

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

typedef struct {
  char_u     *regparse;
  int prevchr_len;
  int curchr;
  int prevchr;
  int prevprevchr;
  int nextchr;
  int at_start;
  int prev_at_start;
  int regnpar;
} parse_state_T;

/*
 * Structure used to save the current input state, when it needs to be
 * restored after trying a match.  Used by reg_save() and reg_restore().
 * Also stores the length of "backpos".
 */
typedef struct {
  union {
    char_u  *ptr;       /* reginput pointer, for single-line regexp */
    lpos_T pos;         /* reginput pos, for multi-line regexp */
  } rs_u;
  int rs_len;
} regsave_T;

/* struct to save start/end pointer/position in for \(\) */
typedef struct {
  union {
    char_u  *ptr;
    lpos_T pos;
  } se_u;
} save_se_T;

/* used for BEHIND and NOBEHIND matching */
typedef struct regbehind_S {
  regsave_T save_after;
  regsave_T save_behind;
  int save_need_clear_subexpr;
  save_se_T save_start[NSUBEXP];
  save_se_T save_end[NSUBEXP];
} regbehind_T;

/* Values for rs_state in regitem_T. */
typedef enum regstate_E {
  RS_NOPEN = 0          /* NOPEN and NCLOSE */
  , RS_MOPEN            /* MOPEN + [0-9] */
  , RS_MCLOSE           /* MCLOSE + [0-9] */
  , RS_ZOPEN            /* ZOPEN + [0-9] */
  , RS_ZCLOSE           /* ZCLOSE + [0-9] */
  , RS_BRANCH           /* BRANCH */
  , RS_BRCPLX_MORE      /* BRACE_COMPLEX and trying one more match */
  , RS_BRCPLX_LONG      /* BRACE_COMPLEX and trying longest match */
  , RS_BRCPLX_SHORT     /* BRACE_COMPLEX and trying shortest match */
  , RS_NOMATCH          /* NOMATCH */
  , RS_BEHIND1          /* BEHIND / NOBEHIND matching rest */
  , RS_BEHIND2          /* BEHIND / NOBEHIND matching behind part */
  , RS_STAR_LONG        /* STAR/PLUS/BRACE_SIMPLE longest match */
  , RS_STAR_SHORT       /* STAR/PLUS/BRACE_SIMPLE shortest match */
} regstate_T;

/*
 * When there are alternatives a regstate_T is put on the regstack to remember
 * what we are doing.
 * Before it may be another type of item, depending on rs_state, to remember
 * more things.
 */
typedef struct regitem_S {
  regstate_T rs_state;          /* what we are doing, one of RS_ above */
  char_u      *rs_scan;         /* current node in program */
  union {
    save_se_T sesave;
    regsave_T regsave;
  } rs_un;                      /* room for saving reginput */
  short rs_no;                  /* submatch nr or BEHIND/NOBEHIND */
} regitem_T;


/* used for STAR, PLUS and BRACE_SIMPLE matching */
typedef struct regstar_S {
  int nextb;                    /* next byte */
  int nextb_ic;                 /* next byte reverse case */
  long count;
  long minval;
  long maxval;
} regstar_T;

/* used to store input position when a BACK was encountered, so that we now if
 * we made any progress since the last time. */
typedef struct backpos_S {
  char_u      *bp_scan;         /* "scan" where BACK was encountered */
  regsave_T bp_pos;             /* last input position */
} backpos_T;

typedef struct {
  int a, b, c;
} decomp_T;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "regexp.c.generated.h"
#endif
static int no_Magic(int x)
{
  if (is_Magic(x))
    return un_Magic(x);
  return x;
}

static int toggle_Magic(int x)
{
  if (is_Magic(x))
    return un_Magic(x);
  return Magic(x);
}

/*
 * The first byte of the regexp internal "program" is actually this magic
 * number; the start node begins in the second byte.  It's used to catch the
 * most severe mutilation of the program by the caller.
 */

#define REGMAGIC        0234

/*
 * Opcode notes:
 *
 * BRANCH	The set of branches constituting a single choice are hooked
 *		together with their "next" pointers, since precedence prevents
 *		anything being concatenated to any individual branch.  The
 *		"next" pointer of the last BRANCH in a choice points to the
 *		thing following the whole choice.  This is also where the
 *		final "next" pointer of each individual branch points; each
 *		branch starts with the operand node of a BRANCH node.
 *
 * BACK		Normal "next" pointers all implicitly point forward; BACK
 *		exists to make loop structures possible.
 *
 * STAR,PLUS	'=', and complex '*' and '+', are implemented as circular
 *		BRANCH structures using BACK.  Simple cases (one character
 *		per match) are implemented with STAR and PLUS for speed
 *		and to minimize recursive plunges.
 *
 * BRACE_LIMITS	This is always followed by a BRACE_SIMPLE or BRACE_COMPLEX
 *		node, and defines the min and max limits to be used for that
 *		node.
 *
 * MOPEN,MCLOSE	...are numbered at compile time.
 * ZOPEN,ZCLOSE	...ditto
 */

/*
 * A node is one char of opcode followed by two chars of "next" pointer.
 * "Next" pointers are stored as two 8-bit bytes, high order first.  The
 * value is a positive offset from the opcode of the node containing it.
 * An operand, if any, simply follows the node.  (Note that much of the
 * code generation knows about this implicit relationship.)
 *
 * Using two bytes for the "next" pointer is vast overkill for most things,
 * but allows patterns to get big without disasters.
 */
#define OP(p)           ((int)*(p))
#define NEXT(p)         (((*((p) + 1) & 0377) << 8) + (*((p) + 2) & 0377))
#define OPERAND(p)      ((p) + 3)
/* Obtain an operand that was stored as four bytes, MSB first. */
#define OPERAND_MIN(p)  (((long)(p)[3] << 24) + ((long)(p)[4] << 16) \
                         + ((long)(p)[5] << 8) + (long)(p)[6])
/* Obtain a second operand stored as four bytes. */
#define OPERAND_MAX(p)  OPERAND_MIN((p) + 4)
/* Obtain a second single-byte operand stored after a four bytes operand. */
#define OPERAND_CMP(p)  (p)[7]

/*
 * Utility definitions.
 */
#define UCHARAT(p)      ((int)*(char_u *)(p))

/* Used for an error (down from) vim_regcomp(): give the error message, set
 * rc_did_emsg and return NULL */
#define EMSG_RET_NULL(m) return (EMSG(m), rc_did_emsg = true, (void *)NULL)
#define IEMSG_RET_NULL(m) return (IEMSG(m), rc_did_emsg = true, (void *)NULL)
#define EMSG_RET_FAIL(m) return (EMSG(m), rc_did_emsg = true, FAIL)
#define EMSG2_RET_NULL(m, c) \
    return (EMSG2((m), (c) ? "" : "\\"), rc_did_emsg = true, (void *)NULL)
#define EMSG2_RET_FAIL(m, c) \
    return (EMSG2((m), (c) ? "" : "\\"), rc_did_emsg = true, FAIL)
#define EMSG_ONE_RET_NULL EMSG2_RET_NULL(_( \
    "E369: invalid item in %s%%[]"), reg_magic == MAGIC_ALL)

#define MAX_LIMIT       (32767L << 16L)


#ifdef BT_REGEXP_DUMP
static void regdump(char_u *, bt_regprog_T *);
#endif
#ifdef REGEXP_DEBUG
static char_u   *regprop(char_u *);
#endif

static char_u e_missingbracket[] = N_("E769: Missing ] after %s[");
static char_u e_reverse_range[] = N_("E944: Reverse range in character class");
static char_u e_large_class[] = N_("E945: Range too large in character class");
static char_u e_unmatchedpp[] = N_("E53: Unmatched %s%%(");
static char_u e_unmatchedp[] = N_("E54: Unmatched %s(");
static char_u e_unmatchedpar[] = N_("E55: Unmatched %s)");
static char_u e_z_not_allowed[] = N_("E66: \\z( not allowed here");
static char_u e_z1_not_allowed[] = N_("E67: \\z1 - \\z9 not allowed here");
static char_u e_missing_sb[] = N_("E69: Missing ] after %s%%[");
static char_u e_empty_sb[]  = N_("E70: Empty %s%%[]");
#define NOT_MULTI       0
#define MULTI_ONE       1
#define MULTI_MULT      2
/*
 * Return NOT_MULTI if c is not a "multi" operator.
 * Return MULTI_ONE if c is a single "multi" operator.
 * Return MULTI_MULT if c is a multi "multi" operator.
 */
static int re_multi_type(int c)
{
  if (c == Magic('@') || c == Magic('=') || c == Magic('?'))
    return MULTI_ONE;
  if (c == Magic('*') || c == Magic('+') || c == Magic('{'))
    return MULTI_MULT;
  return NOT_MULTI;
}

/*
 * Flags to be passed up and down.
 */
#define HASWIDTH        0x1     /* Known never to match null string. */
#define SIMPLE          0x2     /* Simple enough to be STAR/PLUS operand. */
#define SPSTART         0x4     /* Starts with * or +. */
#define HASNL           0x8     /* Contains some \n. */
#define HASLOOKBH       0x10    /* Contains "\@<=" or "\@<!". */
#define WORST           0       /* Worst case. */

/*
 * When regcode is set to this value, code is not emitted and size is computed
 * instead.
 */
#define JUST_CALC_SIZE  ((char_u *) -1)

static char_u           *reg_prev_sub = NULL;

/*
 * REGEXP_INRANGE contains all characters which are always special in a []
 * range after '\'.
 * REGEXP_ABBR contains all characters which act as abbreviations after '\'.
 * These are:
 *  \n	- New line (NL).
 *  \r	- Carriage Return (CR).
 *  \t	- Tab (TAB).
 *  \e	- Escape (ESC).
 *  \b	- Backspace (Ctrl_H).
 *  \d  - Character code in decimal, eg \d123
 *  \o	- Character code in octal, eg \o80
 *  \x	- Character code in hex, eg \x4a
 *  \u	- Multibyte character code, eg \u20ac
 *  \U	- Long multibyte character code, eg \U12345678
 */
static char_u REGEXP_INRANGE[] = "]^-n\\";
static char_u REGEXP_ABBR[] = "nrtebdoxuU";


/*
 * Translate '\x' to its control character, except "\n", which is Magic.
 */
static int backslash_trans(int c)
{
  switch (c) {
  case 'r':   return CAR;
  case 't':   return TAB;
  case 'e':   return ESC;
  case 'b':   return BS;
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
  };
#define CLASS_NONE 99
  int i;

  if ((*pp)[1] == ':') {
    for (i = 0; i < (int)ARRAY_SIZE(class_names); ++i)
      if (STRNCMP(*pp + 2, class_names[i], STRLEN(class_names[i])) == 0) {
        *pp += STRLEN(class_names[i]) + 2;
        return i;
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
  static int done = FALSE;

  if (done)
    return;

  for (i = 0; i < 256; ++i) {
    if (i >= '0' && i <= '7')
      class_tab[i] = RI_DIGIT + RI_HEX + RI_OCTAL + RI_WORD;
    else if (i >= '8' && i <= '9')
      class_tab[i] = RI_DIGIT + RI_HEX + RI_WORD;
    else if (i >= 'a' && i <= 'f')
      class_tab[i] = RI_HEX + RI_WORD + RI_HEAD + RI_ALPHA + RI_LOWER;
    else if (i >= 'g' && i <= 'z')
      class_tab[i] = RI_WORD + RI_HEAD + RI_ALPHA + RI_LOWER;
    else if (i >= 'A' && i <= 'F')
      class_tab[i] = RI_HEX + RI_WORD + RI_HEAD + RI_ALPHA + RI_UPPER;
    else if (i >= 'G' && i <= 'Z')
      class_tab[i] = RI_WORD + RI_HEAD + RI_ALPHA + RI_UPPER;
    else if (i == '_')
      class_tab[i] = RI_WORD + RI_HEAD;
    else
      class_tab[i] = 0;
  }
  class_tab[' '] |= RI_WHITE;
  class_tab['\t'] |= RI_WHITE;
  done = TRUE;
}

# define ri_digit(c)    (c < 0x100 && (class_tab[c] & RI_DIGIT))
# define ri_hex(c)      (c < 0x100 && (class_tab[c] & RI_HEX))
# define ri_octal(c)    (c < 0x100 && (class_tab[c] & RI_OCTAL))
# define ri_word(c)     (c < 0x100 && (class_tab[c] & RI_WORD))
# define ri_head(c)     (c < 0x100 && (class_tab[c] & RI_HEAD))
# define ri_alpha(c)    (c < 0x100 && (class_tab[c] & RI_ALPHA))
# define ri_lower(c)    (c < 0x100 && (class_tab[c] & RI_LOWER))
# define ri_upper(c)    (c < 0x100 && (class_tab[c] & RI_UPPER))
# define ri_white(c)    (c < 0x100 && (class_tab[c] & RI_WHITE))

/* flags for regflags */
#define RF_ICASE    1   /* ignore case */
#define RF_NOICASE  2   /* don't ignore case */
#define RF_HASNL    4   /* can match a NL */
#define RF_ICOMBINE 8   /* ignore combining characters */
#define RF_LOOKBH   16  /* uses "\@<=" or "\@<!" */

/*
 * Global work variables for vim_regcomp().
 */

static char_u   *regparse;      /* Input-scan pointer. */
static int prevchr_len;         /* byte length of previous char */
static int num_complex_braces;      /* Complex \{...} count */
static int regnpar;             /* () count. */
static int regnzpar;            /* \z() count. */
static int re_has_z;            /* \z item detected */
static char_u   *regcode;       /* Code-emit pointer, or JUST_CALC_SIZE */
static long regsize;            /* Code size. */
static int reg_toolong;         /* TRUE when offset out of range */
static char_u had_endbrace[NSUBEXP];    /* flags, TRUE if end of () found */
static unsigned regflags;       /* RF_ flags for prog */
static long brace_min[10];      /* Minimums for complex brace repeats */
static long brace_max[10];      /* Maximums for complex brace repeats */
static int brace_count[10];      /* Current counts for complex brace repeats */
static int had_eol;             /* TRUE when EOL found by vim_regcomp() */
static int one_exactly = FALSE;         /* only do one char for EXACTLY */

static int reg_magic;           /* magicness of the pattern: */
#define MAGIC_NONE      1       /* "\V" very unmagic */
#define MAGIC_OFF       2       /* "\M" or 'magic' off */
#define MAGIC_ON        3       /* "\m" or 'magic' */
#define MAGIC_ALL       4       /* "\v" very magic */

static int reg_string;          /* matching with a string instead of a buffer
                                   line */
static int reg_strict;          /* "[abc" is illegal */

/*
 * META contains all characters that may be magic, except '^' and '$'.
 */

/* META[] is used often enough to justify turning it into a table. */
static char_u META_flags[] = {
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  /*		   %  &     (  )  *  +	      .    */
  0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 1, 0,
  /*     1  2  3	4  5  6  7  8  9	<  =  >  ? */
  0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1,
  /*  @  A     C	D     F     H  I     K	L  M	 O */
  1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 0, 1,
  /*  P	     S	   U  V  W  X	  Z  [		 _ */
  1, 0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 1, 0, 0, 0, 1,
  /*     a     c	d     f     h  i     k	l  m  n  o */
  0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1,
  /*  p	     s	   u  v  w  x	  z  {	|     ~    */
  1, 0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1
};

static int curchr;              /* currently parsed character */
/* Previous character.  Note: prevchr is sometimes -1 when we are not at the
 * start, eg in /[ ^I]^ the pattern was never found even if it existed,
 * because ^ was taken to be magic -- webb */
static int prevchr;
static int prevprevchr;         /* previous-previous character */
static int nextchr;             /* used for ungetchr() */

/* arguments for reg() */
#define REG_NOPAREN     0       /* toplevel reg() */
#define REG_PAREN       1       /* \(\) */
#define REG_ZPAREN      2       /* \z(\) */
#define REG_NPAREN      3       /* \%(\) */

/*
 * Forward declarations for vim_regcomp()'s friends.
 */
# define REGMBC(x) regmbc(x);
# define CASEMBC(x) case x:

static regengine_T bt_regengine;
static regengine_T nfa_regengine;

/*
 * Return TRUE if compiled regular expression "prog" can match a line break.
 */
int re_multiline(regprog_T *prog)
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
  char_u      *p = *pp;

  if (p[1] == '=' && p[2] != NUL) {
    l = (*mb_ptr2len)(p + 2);
    if (p[l + 2] == '=' && p[l + 3] == ']') {
      c = utf_ptr2char(p + 2);
      *pp += l + 4;
      return c;
    }
  }
  return 0;
}


/*
 * Produce the bytes for equivalence class "c".
 * Currently only handles latin1, latin9 and utf-8.
 * NOTE: When changing this function, also change nfa_emit_equi_class()
 */
static void reg_equi_class(int c)
{
  if (enc_utf8 || STRCMP(p_enc, "latin1") == 0
      || STRCMP(p_enc, "iso-8859-15") == 0) {
    switch (c) {
      // Do not use '\300' style, it results in a negative number.
    case 'A': case 0xc0: case 0xc1: case 0xc2:
    case 0xc3: case 0xc4: case 0xc5:
      CASEMBC(0x100) CASEMBC(0x102) CASEMBC(0x104) CASEMBC(0x1cd)
      CASEMBC(0x1de) CASEMBC(0x1e0) CASEMBC(0x1ea2)
      regmbc('A'); regmbc(0xc0); regmbc(0xc1);
      regmbc(0xc2); regmbc(0xc3); regmbc(0xc4);
      regmbc(0xc5);
      REGMBC(0x100) REGMBC(0x102) REGMBC(0x104)
      REGMBC(0x1cd) REGMBC(0x1de) REGMBC(0x1e0)
      REGMBC(0x1ea2)
      return;
    case 'B': CASEMBC(0x1e02) CASEMBC(0x1e06)
      regmbc('B'); REGMBC(0x1e02) REGMBC(0x1e06)
      return;
    case 'C': case 0xc7:
      CASEMBC(0x106) CASEMBC(0x108) CASEMBC(0x10a) CASEMBC(0x10c)
      regmbc('C'); regmbc(0xc7);
      REGMBC(0x106) REGMBC(0x108) REGMBC(0x10a)
      REGMBC(0x10c)
      return;
    case 'D': CASEMBC(0x10e) CASEMBC(0x110) CASEMBC(0x1e0a)
      CASEMBC(0x1e0e) CASEMBC(0x1e10)
      regmbc('D'); REGMBC(0x10e) REGMBC(0x110)
      REGMBC(0x1e0a) REGMBC(0x1e0e) REGMBC(0x1e10)
      return;
    case 'E': case 0xc8: case 0xc9: case 0xca: case 0xcb:
      CASEMBC(0x112) CASEMBC(0x114) CASEMBC(0x116) CASEMBC(0x118)
      CASEMBC(0x11a) CASEMBC(0x1eba) CASEMBC(0x1ebc)
      regmbc('E'); regmbc(0xc8); regmbc(0xc9);
      regmbc(0xca); regmbc(0xcb);
      REGMBC(0x112) REGMBC(0x114) REGMBC(0x116)
      REGMBC(0x118) REGMBC(0x11a) REGMBC(0x1eba)
      REGMBC(0x1ebc)
      return;
    case 'F': CASEMBC(0x1e1e)
      regmbc('F'); REGMBC(0x1e1e)
      return;
    case 'G': CASEMBC(0x11c) CASEMBC(0x11e) CASEMBC(0x120)
      CASEMBC(0x122) CASEMBC(0x1e4) CASEMBC(0x1e6) CASEMBC(0x1f4)
      CASEMBC(0x1e20)
      regmbc('G'); REGMBC(0x11c) REGMBC(0x11e)
      REGMBC(0x120) REGMBC(0x122) REGMBC(0x1e4)
      REGMBC(0x1e6) REGMBC(0x1f4) REGMBC(0x1e20)
      return;
    case 'H': CASEMBC(0x124) CASEMBC(0x126) CASEMBC(0x1e22)
      CASEMBC(0x1e26) CASEMBC(0x1e28)
      regmbc('H'); REGMBC(0x124) REGMBC(0x126)
      REGMBC(0x1e22) REGMBC(0x1e26) REGMBC(0x1e28)
      return;
    case 'I': case 0xcc: case 0xcd: case 0xce: case 0xcf:
      CASEMBC(0x128) CASEMBC(0x12a) CASEMBC(0x12c) CASEMBC(0x12e)
      CASEMBC(0x130) CASEMBC(0x1cf) CASEMBC(0x1ec8)
      regmbc('I'); regmbc(0xcc); regmbc(0xcd);
      regmbc(0xce); regmbc(0xcf);
      REGMBC(0x128) REGMBC(0x12a) REGMBC(0x12c)
      REGMBC(0x12e) REGMBC(0x130) REGMBC(0x1cf)
      REGMBC(0x1ec8)
      return;
    case 'J': CASEMBC(0x134)
      regmbc('J'); REGMBC(0x134)
      return;
    case 'K': CASEMBC(0x136) CASEMBC(0x1e8) CASEMBC(0x1e30)
      CASEMBC(0x1e34)
      regmbc('K'); REGMBC(0x136) REGMBC(0x1e8)
      REGMBC(0x1e30) REGMBC(0x1e34)
      return;
    case 'L': CASEMBC(0x139) CASEMBC(0x13b) CASEMBC(0x13d)
      CASEMBC(0x13f) CASEMBC(0x141) CASEMBC(0x1e3a)
      regmbc('L'); REGMBC(0x139) REGMBC(0x13b)
      REGMBC(0x13d) REGMBC(0x13f) REGMBC(0x141)
      REGMBC(0x1e3a)
      return;
    case 'M': CASEMBC(0x1e3e) CASEMBC(0x1e40)
      regmbc('M'); REGMBC(0x1e3e) REGMBC(0x1e40)
      return;
    case 'N': case 0xd1:
      CASEMBC(0x143) CASEMBC(0x145) CASEMBC(0x147) CASEMBC(0x1e44)
      CASEMBC(0x1e48)
      regmbc('N'); regmbc(0xd1);
      REGMBC(0x143) REGMBC(0x145) REGMBC(0x147)
      REGMBC(0x1e44) REGMBC(0x1e48)
      return;
    case 'O': case 0xd2: case 0xd3: case 0xd4: case 0xd5:
    case 0xd6: case 0xd8:
      CASEMBC(0x14c) CASEMBC(0x14e) CASEMBC(0x150) CASEMBC(0x1a0)
      CASEMBC(0x1d1) CASEMBC(0x1ea) CASEMBC(0x1ec) CASEMBC(0x1ece)
      regmbc('O'); regmbc(0xd2); regmbc(0xd3);
      regmbc(0xd4); regmbc(0xd5); regmbc(0xd6);
      regmbc(0xd8);
      REGMBC(0x14c) REGMBC(0x14e) REGMBC(0x150)
      REGMBC(0x1a0) REGMBC(0x1d1) REGMBC(0x1ea)
      REGMBC(0x1ec) REGMBC(0x1ece)
      return;
    case 'P': case 0x1e54: case 0x1e56:
      regmbc('P'); REGMBC(0x1e54) REGMBC(0x1e56)
      return;
    case 'R': CASEMBC(0x154) CASEMBC(0x156) CASEMBC(0x158)
      CASEMBC(0x1e58) CASEMBC(0x1e5e)
      regmbc('R'); REGMBC(0x154) REGMBC(0x156) REGMBC(0x158)
      REGMBC(0x1e58) REGMBC(0x1e5e)
      return;
    case 'S': CASEMBC(0x15a) CASEMBC(0x15c) CASEMBC(0x15e)
      CASEMBC(0x160) CASEMBC(0x1e60)
      regmbc('S'); REGMBC(0x15a) REGMBC(0x15c)
      REGMBC(0x15e) REGMBC(0x160) REGMBC(0x1e60)
      return;
    case 'T': CASEMBC(0x162) CASEMBC(0x164) CASEMBC(0x166)
      CASEMBC(0x1e6a) CASEMBC(0x1e6e)
      regmbc('T'); REGMBC(0x162) REGMBC(0x164)
      REGMBC(0x166) REGMBC(0x1e6a) REGMBC(0x1e6e)
      return;
    case 'U': case 0xd9: case 0xda: case 0xdb: case 0xdc:
      CASEMBC(0x168) CASEMBC(0x16a) CASEMBC(0x16c) CASEMBC(0x16e)
      CASEMBC(0x170) CASEMBC(0x172) CASEMBC(0x1af) CASEMBC(0x1d3)
      CASEMBC(0x1ee6)
      regmbc('U'); regmbc(0xd9); regmbc(0xda);
      regmbc(0xdb); regmbc(0xdc);
      REGMBC(0x168) REGMBC(0x16a) REGMBC(0x16c)
      REGMBC(0x16e) REGMBC(0x170) REGMBC(0x172)
      REGMBC(0x1af) REGMBC(0x1d3) REGMBC(0x1ee6)
      return;
    case 'V': CASEMBC(0x1e7c)
      regmbc('V'); REGMBC(0x1e7c)
      return;
    case 'W': CASEMBC(0x174) CASEMBC(0x1e80) CASEMBC(0x1e82)
      CASEMBC(0x1e84) CASEMBC(0x1e86)
      regmbc('W'); REGMBC(0x174) REGMBC(0x1e80)
      REGMBC(0x1e82) REGMBC(0x1e84) REGMBC(0x1e86)
      return;
    case 'X': CASEMBC(0x1e8a) CASEMBC(0x1e8c)
      regmbc('X'); REGMBC(0x1e8a) REGMBC(0x1e8c)
      return;
    case 'Y': case 0xdd:
      CASEMBC(0x176) CASEMBC(0x178) CASEMBC(0x1e8e) CASEMBC(0x1ef2)
      CASEMBC(0x1ef6) CASEMBC(0x1ef8)
      regmbc('Y'); regmbc(0xdd);
      REGMBC(0x176) REGMBC(0x178) REGMBC(0x1e8e)
      REGMBC(0x1ef2) REGMBC(0x1ef6) REGMBC(0x1ef8)
      return;
    case 'Z': CASEMBC(0x179) CASEMBC(0x17b) CASEMBC(0x17d)
      CASEMBC(0x1b5) CASEMBC(0x1e90) CASEMBC(0x1e94)
      regmbc('Z'); REGMBC(0x179) REGMBC(0x17b)
      REGMBC(0x17d) REGMBC(0x1b5) REGMBC(0x1e90)
      REGMBC(0x1e94)
      return;
    case 'a': case 0xe0: case 0xe1: case 0xe2:
    case 0xe3: case 0xe4: case 0xe5:
      CASEMBC(0x101) CASEMBC(0x103) CASEMBC(0x105) CASEMBC(0x1ce)
      CASEMBC(0x1df) CASEMBC(0x1e1) CASEMBC(0x1ea3)
      regmbc('a'); regmbc(0xe0); regmbc(0xe1);
      regmbc(0xe2); regmbc(0xe3); regmbc(0xe4);
      regmbc(0xe5);
      REGMBC(0x101) REGMBC(0x103) REGMBC(0x105)
      REGMBC(0x1ce) REGMBC(0x1df) REGMBC(0x1e1)
      REGMBC(0x1ea3)
      return;
    case 'b': CASEMBC(0x1e03) CASEMBC(0x1e07)
      regmbc('b'); REGMBC(0x1e03) REGMBC(0x1e07)
      return;
    case 'c': case 0xe7:
      CASEMBC(0x107) CASEMBC(0x109) CASEMBC(0x10b) CASEMBC(0x10d)
      regmbc('c'); regmbc(0xe7);
      REGMBC(0x107) REGMBC(0x109) REGMBC(0x10b)
      REGMBC(0x10d)
      return;
    case 'd': CASEMBC(0x10f) CASEMBC(0x111) CASEMBC(0x1e0b)
      CASEMBC(0x1e0f) CASEMBC(0x1e11)
      regmbc('d'); REGMBC(0x10f) REGMBC(0x111)
      REGMBC(0x1e0b) REGMBC(0x1e0f) REGMBC(0x1e11)
      return;
    case 'e': case 0xe8: case 0xe9: case 0xea: case 0xeb:
      CASEMBC(0x113) CASEMBC(0x115) CASEMBC(0x117) CASEMBC(0x119)
      CASEMBC(0x11b) CASEMBC(0x1ebb) CASEMBC(0x1ebd)
      regmbc('e'); regmbc(0xe8); regmbc(0xe9);
      regmbc(0xea); regmbc(0xeb);
      REGMBC(0x113) REGMBC(0x115) REGMBC(0x117)
      REGMBC(0x119) REGMBC(0x11b) REGMBC(0x1ebb)
      REGMBC(0x1ebd)
      return;
    case 'f': CASEMBC(0x1e1f)
      regmbc('f'); REGMBC(0x1e1f)
      return;
    case 'g': CASEMBC(0x11d) CASEMBC(0x11f) CASEMBC(0x121)
      CASEMBC(0x123) CASEMBC(0x1e5) CASEMBC(0x1e7) CASEMBC(0x1f5)
      CASEMBC(0x1e21)
      regmbc('g'); REGMBC(0x11d) REGMBC(0x11f)
      REGMBC(0x121) REGMBC(0x123) REGMBC(0x1e5)
      REGMBC(0x1e7) REGMBC(0x1f5) REGMBC(0x1e21)
      return;
    case 'h': CASEMBC(0x125) CASEMBC(0x127) CASEMBC(0x1e23)
      CASEMBC(0x1e27) CASEMBC(0x1e29) CASEMBC(0x1e96)
      regmbc('h'); REGMBC(0x125) REGMBC(0x127)
      REGMBC(0x1e23) REGMBC(0x1e27) REGMBC(0x1e29)
      REGMBC(0x1e96)
      return;
    case 'i': case 0xec: case 0xed: case 0xee: case 0xef:
      CASEMBC(0x129) CASEMBC(0x12b) CASEMBC(0x12d) CASEMBC(0x12f)
      CASEMBC(0x1d0) CASEMBC(0x1ec9)
      regmbc('i'); regmbc(0xec); regmbc(0xed);
      regmbc(0xee); regmbc(0xef);
      REGMBC(0x129) REGMBC(0x12b) REGMBC(0x12d)
      REGMBC(0x12f) REGMBC(0x1d0) REGMBC(0x1ec9)
      return;
    case 'j': CASEMBC(0x135) CASEMBC(0x1f0)
      regmbc('j'); REGMBC(0x135) REGMBC(0x1f0)
      return;
    case 'k': CASEMBC(0x137) CASEMBC(0x1e9) CASEMBC(0x1e31)
      CASEMBC(0x1e35)
      regmbc('k'); REGMBC(0x137) REGMBC(0x1e9)
      REGMBC(0x1e31) REGMBC(0x1e35)
      return;
    case 'l': CASEMBC(0x13a) CASEMBC(0x13c) CASEMBC(0x13e)
      CASEMBC(0x140) CASEMBC(0x142) CASEMBC(0x1e3b)
      regmbc('l'); REGMBC(0x13a) REGMBC(0x13c)
      REGMBC(0x13e) REGMBC(0x140) REGMBC(0x142)
      REGMBC(0x1e3b)
      return;
    case 'm': CASEMBC(0x1e3f) CASEMBC(0x1e41)
      regmbc('m'); REGMBC(0x1e3f) REGMBC(0x1e41)
      return;
    case 'n': case 0xf1:
      CASEMBC(0x144) CASEMBC(0x146) CASEMBC(0x148) CASEMBC(0x149)
      CASEMBC(0x1e45) CASEMBC(0x1e49)
      regmbc('n'); regmbc(0xf1);
      REGMBC(0x144) REGMBC(0x146) REGMBC(0x148)
      REGMBC(0x149) REGMBC(0x1e45) REGMBC(0x1e49)
      return;
    case 'o': case 0xf2: case 0xf3: case 0xf4: case 0xf5:
    case 0xf6: case 0xf8:
      CASEMBC(0x14d) CASEMBC(0x14f) CASEMBC(0x151) CASEMBC(0x1a1)
      CASEMBC(0x1d2) CASEMBC(0x1eb) CASEMBC(0x1ed) CASEMBC(0x1ecf)
      regmbc('o'); regmbc(0xf2); regmbc(0xf3);
      regmbc(0xf4); regmbc(0xf5); regmbc(0xf6);
      regmbc(0xf8);
      REGMBC(0x14d) REGMBC(0x14f) REGMBC(0x151)
      REGMBC(0x1a1) REGMBC(0x1d2) REGMBC(0x1eb)
      REGMBC(0x1ed) REGMBC(0x1ecf)
      return;
    case 'p': CASEMBC(0x1e55) CASEMBC(0x1e57)
      regmbc('p'); REGMBC(0x1e55) REGMBC(0x1e57)
      return;
    case 'r': CASEMBC(0x155) CASEMBC(0x157) CASEMBC(0x159)
      CASEMBC(0x1e59) CASEMBC(0x1e5f)
      regmbc('r'); REGMBC(0x155) REGMBC(0x157) REGMBC(0x159)
      REGMBC(0x1e59) REGMBC(0x1e5f)
      return;
    case 's': CASEMBC(0x15b) CASEMBC(0x15d) CASEMBC(0x15f)
      CASEMBC(0x161) CASEMBC(0x1e61)
      regmbc('s'); REGMBC(0x15b) REGMBC(0x15d)
      REGMBC(0x15f) REGMBC(0x161) REGMBC(0x1e61)
      return;
    case 't': CASEMBC(0x163) CASEMBC(0x165) CASEMBC(0x167)
      CASEMBC(0x1e6b) CASEMBC(0x1e6f) CASEMBC(0x1e97)
      regmbc('t'); REGMBC(0x163) REGMBC(0x165) REGMBC(0x167)
      REGMBC(0x1e6b) REGMBC(0x1e6f) REGMBC(0x1e97)
      return;
    case 'u': case 0xf9: case 0xfa: case 0xfb: case 0xfc:
      CASEMBC(0x169) CASEMBC(0x16b) CASEMBC(0x16d) CASEMBC(0x16f)
      CASEMBC(0x171) CASEMBC(0x173) CASEMBC(0x1b0) CASEMBC(0x1d4)
      CASEMBC(0x1ee7)
      regmbc('u'); regmbc(0xf9); regmbc(0xfa);
      regmbc(0xfb); regmbc(0xfc);
      REGMBC(0x169) REGMBC(0x16b) REGMBC(0x16d)
      REGMBC(0x16f) REGMBC(0x171) REGMBC(0x173)
      REGMBC(0x1b0) REGMBC(0x1d4) REGMBC(0x1ee7)
      return;
    case 'v': CASEMBC(0x1e7d)
      regmbc('v'); REGMBC(0x1e7d)
      return;
    case 'w': CASEMBC(0x175) CASEMBC(0x1e81) CASEMBC(0x1e83)
      CASEMBC(0x1e85) CASEMBC(0x1e87) CASEMBC(0x1e98)
      regmbc('w'); REGMBC(0x175) REGMBC(0x1e81)
      REGMBC(0x1e83) REGMBC(0x1e85) REGMBC(0x1e87)
      REGMBC(0x1e98)
      return;
    case 'x': CASEMBC(0x1e8b) CASEMBC(0x1e8d)
      regmbc('x'); REGMBC(0x1e8b) REGMBC(0x1e8d)
      return;
    case 'y': case 0xfd: case 0xff:
      CASEMBC(0x177) CASEMBC(0x1e8f) CASEMBC(0x1e99)
      CASEMBC(0x1ef3) CASEMBC(0x1ef7) CASEMBC(0x1ef9)
      regmbc('y'); regmbc(0xfd); regmbc(0xff);
      REGMBC(0x177) REGMBC(0x1e8f) REGMBC(0x1e99)
      REGMBC(0x1ef3) REGMBC(0x1ef7) REGMBC(0x1ef9)
      return;
    case 'z': CASEMBC(0x17a) CASEMBC(0x17c) CASEMBC(0x17e)
      CASEMBC(0x1b6) CASEMBC(0x1e91) CASEMBC(0x1e95)
      regmbc('z'); REGMBC(0x17a) REGMBC(0x17c)
      REGMBC(0x17e) REGMBC(0x1b6) REGMBC(0x1e91)
      REGMBC(0x1e95)
      return;
    }
  }
  regmbc(c);
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
  char_u      *p = *pp;

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

static int reg_cpo_lit; /* 'cpoptions' contains 'l' flag */

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

  if (*p == '^')        /* Complement of range. */
    ++p;
  if (*p == ']' || *p == '-')
    ++p;
  while (*p != NUL && *p != ']') {
    if (has_mbyte && (l = (*mb_ptr2len)(p)) > 1) {
      p += l;
    } else if (*p == '-')  {
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
  char_u      *p = startp;

  if (magic)
    mymagic = MAGIC_ON;
  else
    mymagic = MAGIC_OFF;
  get_cpo_flags();

  for (; p[0] != NUL; MB_PTR_ADV(p)) {
    if (p[0] == dirc) {         // found end of regexp
      break;
    }
    if ((p[0] == '[' && mymagic >= MAGIC_ON)
        || (p[0] == '\\' && p[1] == '[' && mymagic <= MAGIC_OFF)) {
      p = skip_anyof(p + 1);
      if (p[0] == NUL)
        break;
    } else if (p[0] == '\\' && p[1] != NUL)   {
      if (dirc == '?' && newp != NULL && p[1] == '?') {
        /* change "\?" to "?", make a copy first. */
        if (*newp == NULL) {
          *newp = vim_strsave(startp);
          p = *newp + (p - startp);
        }
        STRMOVE(p, p + 1);
      } else
        ++p;            /* skip next character */
      if (*p == 'v')
        mymagic = MAGIC_ALL;
      else if (*p == 'V')
        mymagic = MAGIC_NONE;
    }
  }
  return p;
}

/// Return TRUE if the back reference is legal. We must have seen the close
/// brace.
/// TODO(vim): Should also check that we don't refer to something repeated
/// (+*=): what instance of the repetition should we match?
static int seen_endbrace(int refnum)
{
  if (!had_endbrace[refnum]) {
      char_u *p;

      // Trick: check if "@<=" or "@<!" follows, in which case
      // the \1 can appear before the referenced match.
      for (p = regparse; *p != NUL; p++) {
        if (p[0] == '@' && p[1] == '<' && (p[2] == '!' || p[2] == '=')) {
          break;
        }
      }

    if (*p == NUL) {
      EMSG(_("E65: Illegal back reference"));
      rc_did_emsg = true;
      return false;
    }
  }
  return TRUE;
}

/*
 * bt_regcomp() - compile a regular expression into internal code for the
 * traditional back track matcher.
 * Returns the program in allocated space.  Returns NULL for an error.
 *
 * We can't allocate space until we know how big the compiled form will be,
 * but we can't compile it (and thus know how big it is) until we've got a
 * place to put the code.  So we cheat:  we compile it twice, once with code
 * generation turned off and size counting turned on, and once "for real".
 * This also means that we don't allocate space until we are sure that the
 * thing really will compile successfully, and we never have to move the
 * code and thus invalidate pointers into it.  (Note that it has to be in
 * one piece because free() must be able to free it all.)
 *
 * Whether upper/lower case is to be ignored is decided when executing the
 * program, it does not matter here.
 *
 * Beware that the optimization-preparation code in here knows about some
 * of the structure of the compiled regexp.
 * "re_flags": RE_MAGIC and/or RE_STRING.
 */
static regprog_T *bt_regcomp(char_u *expr, int re_flags)
{
  char_u      *scan;
  char_u      *longest;
  int len;
  int flags;

  if (expr == NULL)
    EMSG_RET_NULL(_(e_null));

  init_class_tab();

  /*
   * First pass: determine size, legality.
   */
  regcomp_start(expr, re_flags);
  regcode = JUST_CALC_SIZE;
  regc(REGMAGIC);
  if (reg(REG_NOPAREN, &flags) == NULL)
    return NULL;

  /* Allocate space. */
  bt_regprog_T *r = xmalloc(sizeof(bt_regprog_T) + regsize);

  /*
   * Second pass: emit code.
   */
  regcomp_start(expr, re_flags);
  regcode = r->program;
  regc(REGMAGIC);
  if (reg(REG_NOPAREN, &flags) == NULL || reg_toolong) {
    xfree(r);
    if (reg_toolong)
      EMSG_RET_NULL(_("E339: Pattern too long"));
    return NULL;
  }

  /* Dig out information for optimizations. */
  r->regstart = NUL;            /* Worst-case defaults. */
  r->reganch = 0;
  r->regmust = NULL;
  r->regmlen = 0;
  r->regflags = regflags;
  if (flags & HASNL)
    r->regflags |= RF_HASNL;
  if (flags & HASLOOKBH)
    r->regflags |= RF_LOOKBH;
  /* Remember whether this pattern has any \z specials in it. */
  r->reghasz = re_has_z;
  scan = r->program + 1;        /* First BRANCH. */
  if (OP(regnext(scan)) == END) {   /* Only one top-level choice. */
    scan = OPERAND(scan);

    /* Starting-point info. */
    if (OP(scan) == BOL || OP(scan) == RE_BOF) {
      r->reganch++;
      scan = regnext(scan);
    }

    if (OP(scan) == EXACTLY) {
      r->regstart = utf_ptr2char(OPERAND(scan));
    } else if (OP(scan) == BOW
               || OP(scan) == EOW
               || OP(scan) == NOTHING
               || OP(scan) == MOPEN  + 0 || OP(scan) == NOPEN
               || OP(scan) == MCLOSE + 0 || OP(scan) == NCLOSE) {
      char_u *regnext_scan = regnext(scan);
      if (OP(regnext_scan) == EXACTLY) {
        r->regstart = utf_ptr2char(OPERAND(regnext_scan));
      }
    }

    /*
     * If there's something expensive in the r.e., find the longest
     * literal string that must appear and make it the regmust.  Resolve
     * ties in favor of later strings, since the regstart check works
     * with the beginning of the r.e. and avoiding duplication
     * strengthens checking.  Not a strong reason, but sufficient in the
     * absence of others.
     */
    /*
     * When the r.e. starts with BOW, it is faster to look for a regmust
     * first. Used a lot for "#" and "*" commands. (Added by mool).
     */
    if ((flags & SPSTART || OP(scan) == BOW || OP(scan) == EOW)
        && !(flags & HASNL)) {
      longest = NULL;
      len = 0;
      for (; scan != NULL; scan = regnext(scan))
        if (OP(scan) == EXACTLY && STRLEN(OPERAND(scan)) >= (size_t)len) {
          longest = OPERAND(scan);
          len = (int)STRLEN(OPERAND(scan));
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

/*
 * Free a compiled regexp program, returned by bt_regcomp().
 */
static void bt_regfree(regprog_T *prog)
{
  xfree(prog);
}

/*
 * Setup to parse the regexp.  Used once to get the length and once to do it.
 */
static void 
regcomp_start (
    char_u *expr,
    int re_flags                       /* see vim_regcomp() */
)
{
  initchr(expr);
  if (re_flags & RE_MAGIC)
    reg_magic = MAGIC_ON;
  else
    reg_magic = MAGIC_OFF;
  reg_string = (re_flags & RE_STRING);
  reg_strict = (re_flags & RE_STRICT);
  get_cpo_flags();

  num_complex_braces = 0;
  regnpar = 1;
  memset(had_endbrace, 0, sizeof(had_endbrace));
  regnzpar = 1;
  re_has_z = 0;
  regsize = 0L;
  reg_toolong = FALSE;
  regflags = 0;
  had_eol = FALSE;
}

/*
 * Check if during the previous call to vim_regcomp the EOL item "$" has been
 * found.  This is messy, but it works fine.
 */
int vim_regcomp_had_eol(void)
{
  return had_eol;
}

// variables for parsing reginput
static int at_start;       // True when on the first character
static int prev_at_start;  // True when on the second character

/*
 * Parse regular expression, i.e. main body or parenthesized thing.
 *
 * Caller must absorb opening parenthesis.
 *
 * Combining parenthesis handling with the base level of regular expression
 * is a trifle forced, but the need to tie the tails of the branches to what
 * follows makes it hard to avoid.
 */
static char_u *
reg (
    int paren,              /* REG_NOPAREN, REG_PAREN, REG_NPAREN or REG_ZPAREN */
    int *flagp
)
{
  char_u      *ret;
  char_u      *br;
  char_u      *ender;
  int parno = 0;
  int flags;

  *flagp = HASWIDTH;            /* Tentatively. */

  if (paren == REG_ZPAREN) {
    /* Make a ZOPEN node. */
    if (regnzpar >= NSUBEXP)
      EMSG_RET_NULL(_("E50: Too many \\z("));
    parno = regnzpar;
    regnzpar++;
    ret = regnode(ZOPEN + parno);
  } else if (paren == REG_PAREN)    {
    /* Make a MOPEN node. */
    if (regnpar >= NSUBEXP)
      EMSG2_RET_NULL(_("E51: Too many %s("), reg_magic == MAGIC_ALL);
    parno = regnpar;
    ++regnpar;
    ret = regnode(MOPEN + parno);
  } else if (paren == REG_NPAREN)   {
    /* Make a NOPEN node. */
    ret = regnode(NOPEN);
  } else
    ret = NULL;

  /* Pick up the branches, linking them together. */
  br = regbranch(&flags);
  if (br == NULL)
    return NULL;
  if (ret != NULL)
    regtail(ret, br);           /* [MZ]OPEN -> first. */
  else
    ret = br;
  /* If one of the branches can be zero-width, the whole thing can.
   * If one of the branches has * at start or matches a line-break, the
   * whole thing can. */
  if (!(flags & HASWIDTH))
    *flagp &= ~HASWIDTH;
  *flagp |= flags & (SPSTART | HASNL | HASLOOKBH);
  while (peekchr() == Magic('|')) {
    skipchr();
    br = regbranch(&flags);
    if (br == NULL || reg_toolong)
      return NULL;
    regtail(ret, br);           /* BRANCH -> BRANCH. */
    if (!(flags & HASWIDTH))
      *flagp &= ~HASWIDTH;
    *flagp |= flags & (SPSTART | HASNL | HASLOOKBH);
  }

  /* Make a closing node, and hook it on the end. */
  ender = regnode(
      paren == REG_ZPAREN ? ZCLOSE + parno :
      paren == REG_PAREN ? MCLOSE + parno :
      paren == REG_NPAREN ? NCLOSE : END);
  regtail(ret, ender);

  /* Hook the tails of the branches to the closing node. */
  for (br = ret; br != NULL; br = regnext(br))
    regoptail(br, ender);

  /* Check for proper termination. */
  if (paren != REG_NOPAREN && getchr() != Magic(')')) {
    if (paren == REG_ZPAREN)
      EMSG_RET_NULL(_("E52: Unmatched \\z("));
    else if (paren == REG_NPAREN)
      EMSG2_RET_NULL(_(e_unmatchedpp), reg_magic == MAGIC_ALL);
    else
      EMSG2_RET_NULL(_(e_unmatchedp), reg_magic == MAGIC_ALL);
  } else if (paren == REG_NOPAREN && peekchr() != NUL) {
    if (curchr == Magic(')'))
      EMSG2_RET_NULL(_(e_unmatchedpar), reg_magic == MAGIC_ALL);
    else
      EMSG_RET_NULL(_(e_trailing));             /* "Can't happen". */
    /* NOTREACHED */
  }
  /*
   * Here we set the flag allowing back references to this set of
   * parentheses.
   */
  if (paren == REG_PAREN)
    had_endbrace[parno] = TRUE;         /* have seen the close paren */
  return ret;
}

/*
 * Parse one alternative of an | operator.
 * Implements the & operator.
 */
static char_u *regbranch(int *flagp)
{
  char_u      *ret;
  char_u      *chain = NULL;
  char_u      *latest;
  int flags;

  *flagp = WORST | HASNL;               /* Tentatively. */

  ret = regnode(BRANCH);
  for (;; ) {
    latest = regconcat(&flags);
    if (latest == NULL)
      return NULL;
    /* If one of the branches has width, the whole thing has.  If one of
     * the branches anchors at start-of-line, the whole thing does.
     * If one of the branches uses look-behind, the whole thing does. */
    *flagp |= flags & (HASWIDTH | SPSTART | HASLOOKBH);
    /* If one of the branches doesn't match a line-break, the whole thing
     * doesn't. */
    *flagp &= ~HASNL | (flags & HASNL);
    if (chain != NULL)
      regtail(chain, latest);
    if (peekchr() != Magic('&'))
      break;
    skipchr();
    regtail(latest, regnode(END));     /* operand ends */
    if (reg_toolong)
      break;
    reginsert(MATCH, latest);
    chain = latest;
  }

  return ret;
}

/*
 * Parse one alternative of an | or & operator.
 * Implements the concatenation operator.
 */
static char_u *regconcat(int *flagp)
{
  char_u      *first = NULL;
  char_u      *chain = NULL;
  char_u      *latest;
  int flags;
  int cont = TRUE;

  *flagp = WORST;               /* Tentatively. */

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
      latest = regpiece(&flags);
      if (latest == NULL || reg_toolong)
        return NULL;
      *flagp |= flags & (HASWIDTH | HASNL | HASLOOKBH);
      if (chain == NULL)                        /* First piece. */
        *flagp |= flags & SPSTART;
      else
        regtail(chain, latest);
      chain = latest;
      if (first == NULL)
        first = latest;
      break;
    }
  }
  if (first == NULL)            /* Loop ran zero times. */
    first = regnode(NOTHING);
  return first;
}

/*
 * Parse something followed by possible [*+=].
 *
 * Note that the branching code sequences used for = and the general cases
 * of * and + are somewhat optimized:  they use the same NOTHING node as
 * both the endmarker for their branch list and the body of the last branch.
 * It might seem that this node could be dispensed with entirely, but the
 * endmarker role is not redundant.
 */
static char_u *regpiece(int *flagp)
{
  char_u          *ret;
  int op;
  char_u          *next;
  int flags;
  long minval;
  long maxval;

  ret = regatom(&flags);
  if (ret == NULL)
    return NULL;

  op = peekchr();
  if (re_multi_type(op) == NOT_MULTI) {
    *flagp = flags;
    return ret;
  }
  /* default flags */
  *flagp = (WORST | SPSTART | (flags & (HASNL | HASLOOKBH)));

  skipchr();
  switch (op) {
  case Magic('*'):
    if (flags & SIMPLE)
      reginsert(STAR, ret);
    else {
      /* Emit x* as (x&|), where & means "self". */
      reginsert(BRANCH, ret);           /* Either x */
      regoptail(ret, regnode(BACK));            /* and loop */
      regoptail(ret, ret);              /* back */
      regtail(ret, regnode(BRANCH));            /* or */
      regtail(ret, regnode(NOTHING));           /* null. */
    }
    break;

  case Magic('+'):
    if (flags & SIMPLE)
      reginsert(PLUS, ret);
    else {
      /* Emit x+ as x(&|), where & means "self". */
      next = regnode(BRANCH);           /* Either */
      regtail(ret, next);
      regtail(regnode(BACK), ret);              /* loop back */
      regtail(next, regnode(BRANCH));           /* or */
      regtail(ret, regnode(NOTHING));           /* null. */
    }
    *flagp = (WORST | HASWIDTH | (flags & (HASNL | HASLOOKBH)));
    break;

  case Magic('@'):
  {
    int lop = END;
    int64_t nr = getdecchrs();

    switch (no_Magic(getchr())) {
    case '=': lop = MATCH; break;                                 /* \@= */
    case '!': lop = NOMATCH; break;                               /* \@! */
    case '>': lop = SUBPAT; break;                                /* \@> */
    case '<': switch (no_Magic(getchr())) {
      case '=': lop = BEHIND; break;                               /* \@<= */
      case '!': lop = NOBEHIND; break;                             /* \@<! */
    }
    }
    if (lop == END)
      EMSG2_RET_NULL(_("E59: invalid character after %s@"),
          reg_magic == MAGIC_ALL);
    /* Look behind must match with behind_pos. */
    if (lop == BEHIND || lop == NOBEHIND) {
      regtail(ret, regnode(BHPOS));
      *flagp |= HASLOOKBH;
    }
    regtail(ret, regnode(END));             /* operand ends */
    if (lop == BEHIND || lop == NOBEHIND) {
      if (nr < 0)
        nr = 0;                 /* no limit is same as zero limit */
      reginsert_nr(lop, (uint32_t)nr, ret);
    } else
      reginsert(lop, ret);
    break;
  }

  case Magic('?'):
  case Magic('='):
    /* Emit x= as (x|) */
    reginsert(BRANCH, ret);                     /* Either x */
    regtail(ret, regnode(BRANCH));              /* or */
    next = regnode(NOTHING);                    /* null. */
    regtail(ret, next);
    regoptail(ret, next);
    break;

  case Magic('{'):
    if (!read_limits(&minval, &maxval))
      return NULL;
    if (flags & SIMPLE) {
      reginsert(BRACE_SIMPLE, ret);
      reginsert_limits(BRACE_LIMITS, minval, maxval, ret);
    } else {
      if (num_complex_braces >= 10)
        EMSG2_RET_NULL(_("E60: Too many complex %s{...}s"),
            reg_magic == MAGIC_ALL);
      reginsert(BRACE_COMPLEX + num_complex_braces, ret);
      regoptail(ret, regnode(BACK));
      regoptail(ret, ret);
      reginsert_limits(BRACE_LIMITS, minval, maxval, ret);
      ++num_complex_braces;
    }
    if (minval > 0 && maxval > 0)
      *flagp = (HASWIDTH | (flags & (HASNL | HASLOOKBH)));
    break;
  }
  if (re_multi_type(peekchr()) != NOT_MULTI) {
    /* Can't have a multi follow a multi. */
    if (peekchr() == Magic('*'))
      sprintf((char *)IObuff, _("E61: Nested %s*"),
          reg_magic >= MAGIC_ON ? "" : "\\");
    else
      sprintf((char *)IObuff, _("E62: Nested %s%c"),
          reg_magic == MAGIC_ALL ? "" : "\\", no_Magic(peekchr()));
    EMSG_RET_NULL(IObuff);
  }

  return ret;
}

/* When making changes to classchars also change nfa_classcodes. */
static char_u   *classchars = (char_u *)".iIkKfFpPsSdDxXoOwWhHaAlLuU";
static int classcodes[] = {
  ANY, IDENT, SIDENT, KWORD, SKWORD,
  FNAME, SFNAME, PRINT, SPRINT,
  WHITE, NWHITE, DIGIT, NDIGIT,
  HEX, NHEX, OCTAL, NOCTAL,
  WORD, NWORD, HEAD, NHEAD,
  ALPHA, NALPHA, LOWER, NLOWER,
  UPPER, NUPPER
};

/*
 * Parse the lowest level.
 *
 * Optimization:  gobbles an entire sequence of ordinary characters so that
 * it can turn them into a single node, which is smaller to store and
 * faster to run.  Don't do this when one_exactly is set.
 */
static char_u *regatom(int *flagp)
{
  char_u          *ret;
  int flags;
  int c;
  char_u          *p;
  int extra = 0;
  int save_prev_at_start = prev_at_start;

  *flagp = WORST;               /* Tentatively. */

  c = getchr();
  switch (c) {
  case Magic('^'):
    ret = regnode(BOL);
    break;

  case Magic('$'):
    ret = regnode(EOL);
    had_eol = TRUE;
    break;

  case Magic('<'):
    ret = regnode(BOW);
    break;

  case Magic('>'):
    ret = regnode(EOW);
    break;

  case Magic('_'):
    c = no_Magic(getchr());
    if (c == '^') {             /* "\_^" is start-of-line */
      ret = regnode(BOL);
      break;
    }
    if (c == '$') {             /* "\_$" is end-of-line */
      ret = regnode(EOL);
      had_eol = TRUE;
      break;
    }

    extra = ADD_NL;
    *flagp |= HASNL;

    /* "\_[" is character range plus newline */
    if (c == '[')
      goto collection;

  // "\_x" is character class plus newline
  FALLTHROUGH;

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
    if (p == NULL)
      EMSG_RET_NULL(_("E63: invalid use of \\_"));
    /* When '.' is followed by a composing char ignore the dot, so that
     * the composing char is matched here. */
    if (enc_utf8 && c == Magic('.') && utf_iscomposing(peekchr())) {
      c = getchr();
      goto do_multibyte;
    }
    ret = regnode(classcodes[p - classchars] + extra);
    *flagp |= HASWIDTH | SIMPLE;
    break;

  case Magic('n'):
    if (reg_string) {
      /* In a string "\n" matches a newline character. */
      ret = regnode(EXACTLY);
      regc(NL);
      regc(NUL);
      *flagp |= HASWIDTH | SIMPLE;
    } else {
      /* In buffer text "\n" matches the end of a line. */
      ret = regnode(NEWL);
      *flagp |= HASWIDTH | HASNL;
    }
    break;

  case Magic('('):
    if (one_exactly)
      EMSG_ONE_RET_NULL;
    ret = reg(REG_PAREN, &flags);
    if (ret == NULL)
      return NULL;
    *flagp |= flags & (HASWIDTH | SPSTART | HASNL | HASLOOKBH);
    break;

  case NUL:
  case Magic('|'):
  case Magic('&'):
  case Magic(')'):
    if (one_exactly)
      EMSG_ONE_RET_NULL;
    IEMSG_RET_NULL(_(e_internal));       // Supposed to be caught earlier.
  // NOTREACHED

  case Magic('='):
  case Magic('?'):
  case Magic('+'):
  case Magic('@'):
  case Magic('{'):
  case Magic('*'):
    c = no_Magic(c);
    sprintf((char *)IObuff, _("E64: %s%c follows nothing"),
        (c == '*' ? reg_magic >= MAGIC_ON : reg_magic == MAGIC_ALL)
        ? "" : "\\", c);
    EMSG_RET_NULL(IObuff);
  /* NOTREACHED */

  case Magic('~'):              /* previous substitute pattern */
    if (reg_prev_sub != NULL) {
      char_u      *lp;

      ret = regnode(EXACTLY);
      lp = reg_prev_sub;
      while (*lp != NUL)
        regc(*lp++);
      regc(NUL);
      if (*reg_prev_sub != NUL) {
        *flagp |= HASWIDTH;
        if ((lp - reg_prev_sub) == 1)
          *flagp |= SIMPLE;
      }
    } else
      EMSG_RET_NULL(_(e_nopresub));
    break;

  case Magic('1'):
  case Magic('2'):
  case Magic('3'):
  case Magic('4'):
  case Magic('5'):
  case Magic('6'):
  case Magic('7'):
  case Magic('8'):
  case Magic('9'):
  {
    int refnum;

    refnum = c - Magic('0');
    if (!seen_endbrace(refnum)) {
      return NULL;
    }
    ret = regnode(BACKREF + refnum);
  }
  break;

  case Magic('z'):
  {
    c = no_Magic(getchr());
    switch (c) {
    case '(': if ((reg_do_extmatch & REX_SET) == 0)
        EMSG_RET_NULL(_(e_z_not_allowed));
      if (one_exactly)
        EMSG_ONE_RET_NULL;
      ret = reg(REG_ZPAREN, &flags);
      if (ret == NULL)
        return NULL;
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
    case '9': if ((reg_do_extmatch & REX_USE) == 0)
        EMSG_RET_NULL(_(e_z1_not_allowed));
      ret = regnode(ZREF + c - '0');
      re_has_z = REX_USE;
      break;

    case 's': ret = regnode(MOPEN + 0);
      if (!re_mult_next("\\zs")) {
        return NULL;
      }
      break;

    case 'e': ret = regnode(MCLOSE + 0);
      if (!re_mult_next("\\ze")) {
        return NULL;
      }
      break;

    default:  EMSG_RET_NULL(_("E68: Invalid character after \\z"));
    }
  }
  break;

  case Magic('%'):
  {
    c = no_Magic(getchr());
    switch (c) {
    /* () without a back reference */
    case '(':
      if (one_exactly)
        EMSG_ONE_RET_NULL;
      ret = reg(REG_NPAREN, &flags);
      if (ret == NULL)
        return NULL;
      *flagp |= flags & (HASWIDTH | SPSTART | HASNL | HASLOOKBH);
      break;

    /* Catch \%^ and \%$ regardless of where they appear in the
     * pattern -- regardless of whether or not it makes sense. */
    case '^':
      ret = regnode(RE_BOF);
      break;

    case '$':
      ret = regnode(RE_EOF);
      break;

    case '#':
      ret = regnode(CURSOR);
      break;

    case 'V':
      ret = regnode(RE_VISUAL);
      break;

    case 'C':
      ret = regnode(RE_COMPOSING);
      break;

    /* \%[abc]: Emit as a list of branches, all ending at the last
     * branch which matches nothing. */
    case '[':
      if (one_exactly)                          /* doesn't nest */
        EMSG_ONE_RET_NULL;
      {
        char_u    *lastbranch;
        char_u    *lastnode = NULL;
        char_u    *br;

        ret = NULL;
        while ((c = getchr()) != ']') {
          if (c == NUL)
            EMSG2_RET_NULL(_(e_missing_sb),
                reg_magic == MAGIC_ALL);
          br = regnode(BRANCH);
          if (ret == NULL)
            ret = br;
          else
            regtail(lastnode, br);

          ungetchr();
          one_exactly = TRUE;
          lastnode = regatom(flagp);
          one_exactly = FALSE;
          if (lastnode == NULL)
            return NULL;
        }
        if (ret == NULL)
          EMSG2_RET_NULL(_(e_empty_sb),
              reg_magic == MAGIC_ALL);
        lastbranch = regnode(BRANCH);
        br = regnode(NOTHING);
        if (ret != JUST_CALC_SIZE) {
          regtail(lastnode, br);
          regtail(lastbranch, br);
          /* connect all branches to the NOTHING
           * branch at the end */
          for (br = ret; br != lastnode; ) {
            if (OP(br) == BRANCH) {
              regtail(br, lastbranch);
              br = OPERAND(br);
            } else
              br = regnext(br);
          }
        }
        *flagp &= ~(HASWIDTH | SIMPLE);
        break;
      }

    case 'd':               /* %d123 decimal */
    case 'o':               /* %o123 octal */
    case 'x':               /* %xab hex 2 */
    case 'u':               /* %uabcd hex 4 */
    case 'U':               /* %U1234abcd hex 8 */
    {
      int64_t i;

      switch (c) {
      case 'd': i = getdecchrs(); break;
      case 'o': i = getoctchrs(); break;
      case 'x': i = gethexchrs(2); break;
      case 'u': i = gethexchrs(4); break;
      case 'U': i = gethexchrs(8); break;
      default:  i = -1; break;
      }

      if (i < 0 || i > INT_MAX) {
        EMSG2_RET_NULL(_("E678: Invalid character after %s%%[dxouU]"),
                       reg_magic == MAGIC_ALL);
      }
      if (use_multibytecode(i)) {
        ret = regnode(MULTIBYTECODE);
      } else {
        ret = regnode(EXACTLY);
      }
      if (i == 0) {
        regc(0x0a);
      } else {
        regmbc(i);
      }
      regc(NUL);
      *flagp |= HASWIDTH;
      break;
    }

    default:
      if (ascii_isdigit(c) || c == '<' || c == '>'
          || c == '\'') {
        uint32_t n = 0;
        int cmp;

        cmp = c;
        if (cmp == '<' || cmp == '>')
          c = getchr();
        while (ascii_isdigit(c)) {
          n = n * 10 + (uint32_t)(c - '0');
          c = getchr();
        }
        if (c == '\'' && n == 0) {
          /* "\%'m", "\%<'m" and "\%>'m": Mark */
          c = getchr();
          ret = regnode(RE_MARK);
          if (ret == JUST_CALC_SIZE)
            regsize += 2;
          else {
            *regcode++ = c;
            *regcode++ = cmp;
          }
          break;
        } else if (c == 'l' || c == 'c' || c == 'v') {
          if (c == 'l') {
            ret = regnode(RE_LNUM);
            if (save_prev_at_start) {
              at_start = true;
            }
          } else if (c == 'c') {
            ret = regnode(RE_COL);
          } else {
            ret = regnode(RE_VCOL);
          }
          if (ret == JUST_CALC_SIZE) {
            regsize += 5;
          } else {
            // put the number and the optional
            // comparator after the opcode
            regcode = re_put_uint32(regcode, n);
            *regcode++ = cmp;
          }
          break;
        }
      }

      EMSG2_RET_NULL(_("E71: Invalid character after %s%%"),
          reg_magic == MAGIC_ALL);
    }
  }
  break;

  case Magic('['):
collection:
    {
      char_u      *lp;

      /*
       * If there is no matching ']', we assume the '[' is a normal
       * character.  This makes 'incsearch' and ":help [" work.
       */
      lp = skip_anyof(regparse);
      if (*lp == ']') {         /* there is a matching ']' */
        int startc = -1;                /* > 0 when next '-' is a range */
        int endc;

        /*
         * In a character class, different parsing rules apply.
         * Not even \ is special anymore, nothing is.
         */
        if (*regparse == '^') {             /* Complement of range. */
          ret = regnode(ANYBUT + extra);
          regparse++;
        } else
          ret = regnode(ANYOF + extra);

        /* At the start ']' and '-' mean the literal character. */
        if (*regparse == ']' || *regparse == '-') {
          startc = *regparse;
          regc(*regparse++);
        }

        while (*regparse != NUL && *regparse != ']') {
          if (*regparse == '-') {
            ++regparse;
            /* The '-' is not used for a range at the end and
             * after or before a '\n'. */
            if (*regparse == ']' || *regparse == NUL
                || startc == -1
                || (regparse[0] == '\\' && regparse[1] == 'n')) {
              regc('-');
              startc = '-';                     /* [--x] is a range */
            } else {
              /* Also accept "a-[.z.]" */
              endc = 0;
              if (*regparse == '[')
                endc = get_coll_element(&regparse);
              if (endc == 0) {
                if (has_mbyte) {
                  endc = mb_ptr2char_adv((const char_u **)&regparse);
                } else {
                  endc = *regparse++;
                }
              }

              /* Handle \o40, \x20 and \u20AC style sequences */
              if (endc == '\\' && !reg_cpo_lit)
                endc = coll_get_char();

              if (startc > endc) {
                EMSG_RET_NULL(_(e_reverse_range));
              }
              if (has_mbyte && ((*mb_char2len)(startc) > 1
                                || (*mb_char2len)(endc) > 1)) {
                // Limit to a range of 256 chars
                if (endc > startc + 256) {
                  EMSG_RET_NULL(_(e_large_class));
                }
                while (++startc <= endc) {
                  regmbc(startc);
                }
              } else {
                while (++startc <= endc)
                  regc(startc);
              }
              startc = -1;
            }
          }
          /*
           * Only "\]", "\^", "\]" and "\\" are special in Vi.  Vim
           * accepts "\t", "\e", etc., but only when the 'l' flag in
           * 'cpoptions' is not included.
           */
          else if (*regparse == '\\'
                   && (vim_strchr(REGEXP_INRANGE, regparse[1]) != NULL
                       || (!reg_cpo_lit
                           && vim_strchr(REGEXP_ABBR,
                               regparse[1]) != NULL))) {
            regparse++;
            if (*regparse == 'n') {
              /* '\n' in range: also match NL */
              if (ret != JUST_CALC_SIZE) {
                /* Using \n inside [^] does not change what
                 * matches. "[^\n]" is the same as ".". */
                if (*ret == ANYOF) {
                  *ret = ANYOF + ADD_NL;
                  *flagp |= HASNL;
                }
                /* else: must have had a \n already */
              }
              regparse++;
              startc = -1;
            } else if (*regparse == 'd'
                       || *regparse == 'o'
                       || *regparse == 'x'
                       || *regparse == 'u'
                       || *regparse == 'U') {
              startc = coll_get_char();
              if (startc == 0)
                regc(0x0a);
              else
                regmbc(startc);
            } else {
              startc = backslash_trans(*regparse++);
              regc(startc);
            }
          } else if (*regparse == '[') {
            int c_class;
            int cu;

            c_class = get_char_class(&regparse);
            startc = -1;
            /* Characters assumed to be 8 bits! */
            switch (c_class) {
            case CLASS_NONE:
              c_class = get_equi_class(&regparse);
              if (c_class != 0) {
                /* produce equivalence class */
                reg_equi_class(c_class);
              } else if ((c_class =
                            get_coll_element(&regparse)) != 0) {
                /* produce a collating element */
                regmbc(c_class);
              } else {
                /* literal '[', allow [[-x] as a range */
                startc = *regparse++;
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
              for (cu = 9; cu <= 13; cu++)
                regc(cu);
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
        prevchr_len = 1;                /* last char was the ']' */
        if (*regparse != ']')
          EMSG_RET_NULL(_(e_toomsbra));                 /* Cannot happen? */
        skipchr();                  /* let's be friends with the lexer again */
        *flagp |= HASWIDTH | SIMPLE;
        break;
      } else if (reg_strict)
        EMSG2_RET_NULL(_(e_missingbracket), reg_magic > MAGIC_OFF);
    }
    FALLTHROUGH;

  default:
  {
    int len;

    /* A multi-byte character is handled as a separate atom if it's
     * before a multi and when it's a composing char. */
    if (use_multibytecode(c)) {
do_multibyte:
      ret = regnode(MULTIBYTECODE);
      regmbc(c);
      *flagp |= HASWIDTH | SIMPLE;
      break;
    }

    ret = regnode(EXACTLY);

    /*
     * Append characters as long as:
     * - there is no following multi, we then need the character in
     *   front of it as a single character operand
     * - not running into a Magic character
     * - "one_exactly" is not set
     * But always emit at least one character.  Might be a Multi,
     * e.g., a "[" without matching "]".
     */
    for (len = 0; c != NUL && (len == 0
                               || (re_multi_type(peekchr()) == NOT_MULTI
                                   && !one_exactly
                                   && !is_Magic(c))); ++len) {
      c = no_Magic(c);
      if (has_mbyte) {
        regmbc(c);
        if (enc_utf8) {
          int l;

          /* Need to get composing character too. */
          for (;; ) {
            l = utf_ptr2len(regparse);
            if (!UTF_COMPOSINGLIKE(regparse, regparse + l))
              break;
            regmbc(utf_ptr2char(regparse));
            skipchr();
          }
        }
      } else
        regc(c);
      c = getchr();
    }
    ungetchr();

    regc(NUL);
    *flagp |= HASWIDTH;
    if (len == 1)
      *flagp |= SIMPLE;
  }
  break;
  }

  return ret;
}

/// Used in a place where no * or \+ can follow.
static bool re_mult_next(char *what)
{
  if (re_multi_type(peekchr()) == MULTI_MULT) {
    EMSG2_RET_FAIL(_("E888: (NFA regexp) cannot repeat %s"), what);
  }
  return true;
}

/*
 * Return TRUE if MULTIBYTECODE should be used instead of EXACTLY for
 * character "c".
 */
static int use_multibytecode(int c)
{
  return has_mbyte && (*mb_char2len)(c) > 1
         && (re_multi_type(peekchr()) != NOT_MULTI
             || (enc_utf8 && utf_iscomposing(c)));
}

/*
 * Emit a node.
 * Return pointer to generated code.
 */
static char_u *regnode(int op)
{
  char_u  *ret;

  ret = regcode;
  if (ret == JUST_CALC_SIZE)
    regsize += 3;
  else {
    *regcode++ = op;
    *regcode++ = NUL;                   /* Null "next" pointer. */
    *regcode++ = NUL;
  }
  return ret;
}

/*
 * Emit (if appropriate) a byte of code
 */
static void regc(int b)
{
  if (regcode == JUST_CALC_SIZE)
    regsize++;
  else
    *regcode++ = b;
}

/*
 * Emit (if appropriate) a multi-byte character of code
 */
static void regmbc(int c)
{
  if (regcode == JUST_CALC_SIZE) {
    regsize += utf_char2len(c);
  } else {
    regcode += utf_char2bytes(c, regcode);
  }
}

/*
 * Insert an operator in front of already-emitted operand
 *
 * Means relocating the operand.
 */
static void reginsert(int op, char_u *opnd)
{
  char_u      *src;
  char_u      *dst;
  char_u      *place;

  if (regcode == JUST_CALC_SIZE) {
    regsize += 3;
    return;
  }
  src = regcode;
  regcode += 3;
  dst = regcode;
  while (src > opnd)
    *--dst = *--src;

  place = opnd;                 /* Op node, where operand used to be. */
  *place++ = op;
  *place++ = NUL;
  *place = NUL;
}

/*
 * Insert an operator in front of already-emitted operand.
 * Add a number to the operator.
 */
static void reginsert_nr(int op, long val, char_u *opnd)
{
  char_u      *src;
  char_u      *dst;
  char_u      *place;

  if (regcode == JUST_CALC_SIZE) {
    regsize += 7;
    return;
  }
  src = regcode;
  regcode += 7;
  dst = regcode;
  while (src > opnd)
    *--dst = *--src;

  place = opnd;                 /* Op node, where operand used to be. */
  *place++ = op;
  *place++ = NUL;
  *place++ = NUL;
  assert(val >= 0 && (uintmax_t)val <= UINT32_MAX);
  re_put_uint32(place, (uint32_t)val);
}

/*
 * Insert an operator in front of already-emitted operand.
 * The operator has the given limit values as operands.  Also set next pointer.
 *
 * Means relocating the operand.
 */
static void reginsert_limits(int op, long minval, long maxval, char_u *opnd)
{
  char_u      *src;
  char_u      *dst;
  char_u      *place;

  if (regcode == JUST_CALC_SIZE) {
    regsize += 11;
    return;
  }
  src = regcode;
  regcode += 11;
  dst = regcode;
  while (src > opnd)
    *--dst = *--src;

  place = opnd;                 /* Op node, where operand used to be. */
  *place++ = op;
  *place++ = NUL;
  *place++ = NUL;
  assert(minval >= 0 && (uintmax_t)minval <= UINT32_MAX);
  place = re_put_uint32(place, (uint32_t)minval);
  assert(maxval >= 0 && (uintmax_t)maxval <= UINT32_MAX);
  place = re_put_uint32(place, (uint32_t)maxval);
  regtail(opnd, place);
}

/*
 * Write a four bytes number at "p" and return pointer to the next char.
 */
static char_u *re_put_uint32(char_u *p, uint32_t val)
{
  *p++ = (char_u) ((val >> 24) & 0377);
  *p++ = (char_u) ((val >> 16) & 0377);
  *p++ = (char_u) ((val >> 8) & 0377);
  *p++ = (char_u) (val & 0377);
  return p;
}

/*
 * Set the next-pointer at the end of a node chain.
 */
static void regtail(char_u *p, char_u *val)
{
  char_u      *scan;
  char_u      *temp;
  int offset;

  if (p == JUST_CALC_SIZE)
    return;

  /* Find last node. */
  scan = p;
  for (;; ) {
    temp = regnext(scan);
    if (temp == NULL)
      break;
    scan = temp;
  }

  if (OP(scan) == BACK)
    offset = (int)(scan - val);
  else
    offset = (int)(val - scan);
  /* When the offset uses more than 16 bits it can no longer fit in the two
   * bytes available.  Use a global flag to avoid having to check return
   * values in too many places. */
  if (offset > 0xffff)
    reg_toolong = TRUE;
  else {
    *(scan + 1) = (char_u) (((unsigned)offset >> 8) & 0377);
    *(scan + 2) = (char_u) (offset & 0377);
  }
}

/*
 * Like regtail, on item after a BRANCH; nop if none.
 */
static void regoptail(char_u *p, char_u *val)
{
  /* When op is neither BRANCH nor BRACE_COMPLEX0-9, it is "operandless" */
  if (p == NULL || p == JUST_CALC_SIZE
      || (OP(p) != BRANCH
          && (OP(p) < BRACE_COMPLEX || OP(p) > BRACE_COMPLEX + 9)))
    return;
  regtail(OPERAND(p), val);
}

/*
 * Functions for getting characters from the regexp input.
 */

/*
 * Start parsing at "str".
 */
static void initchr(char_u *str)
{
  regparse = str;
  prevchr_len = 0;
  curchr = prevprevchr = prevchr = nextchr = -1;
  at_start = TRUE;
  prev_at_start = FALSE;
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
  static int after_slash = FALSE;

  if (curchr != -1) {
    return curchr;
  }

  switch (curchr = regparse[0]) {
  case '.':
  case '[':
  case '~':
    /* magic when 'magic' is on */
    if (reg_magic >= MAGIC_ON)
      curchr = Magic(curchr);
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
  case '#':           /* future ext. */
  case '"':           /* future ext. */
  case '\'':          /* future ext. */
  case ',':           /* future ext. */
  case '-':           /* future ext. */
  case ':':           /* future ext. */
  case ';':           /* future ext. */
  case '`':           /* future ext. */
  case '/':           /* Can't be used in / command */
    /* magic only after "\v" */
    if (reg_magic == MAGIC_ALL)
      curchr = Magic(curchr);
    break;
  case '*':
    /* * is not magic as the very first character, eg "?*ptr", when
     * after '^', eg "/^*ptr" and when after "\(", "\|", "\&".  But
     * "\(\*" is not magic, thus must be magic if "after_slash" */
    if (reg_magic >= MAGIC_ON
        && !at_start
        && !(prev_at_start && prevchr == Magic('^'))
        && (after_slash
            || (prevchr != Magic('(')
                && prevchr != Magic('&')
                && prevchr != Magic('|'))))
      curchr = Magic('*');
    break;
  case '^':
    /* '^' is only magic as the very first character and if it's after
     * "\(", "\|", "\&' or "\n" */
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
      at_start = TRUE;
      prev_at_start = FALSE;
    }
    break;
  case '$':
    /* '$' is only magic as the very last char and if it's in front of
     * either "\|", "\)", "\&", or "\n" */
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
  case '\\':
  {
    int c = regparse[1];

    if (c == NUL)
      curchr = '\\';                  /* trailing '\' */
    else if (
      c <= '~' && META_flags[c]
      ) {
      /*
       * META contains everything that may be magic sometimes,
       * except ^ and $ ("\^" and "\$" are only magic after
       * "\V").  We now fetch the next character and toggle its
       * magicness.  Therefore, \ is so meta-magic that it is
       * not in META.
       */
      curchr = -1;
      prev_at_start = at_start;
      at_start = FALSE;               /* be able to say "/\*ptr" */
      ++regparse;
      ++after_slash;
      peekchr();
      --regparse;
      --after_slash;
      curchr = toggle_Magic(curchr);
    } else if (vim_strchr(REGEXP_ABBR, c)) {
      /*
       * Handle abbreviations, like "\t" for TAB -- webb
       */
      curchr = backslash_trans(c);
    } else if (reg_magic == MAGIC_NONE && (c == '$' || c == '^'))
      curchr = toggle_Magic(c);
    else {
      /*
       * Next character can never be (made) magic?
       * Then backslashing it won't do anything.
       */
      curchr = utf_ptr2char(regparse + 1);
    }
    break;
  }

  default:
    curchr = utf_ptr2char(regparse);
  }

  return curchr;
}

/*
 * Eat one lexed character.  Do this in a way that we can undo it.
 */
static void skipchr(void)
{
  /* peekchr() eats a backslash, do the same here */
  if (*regparse == '\\')
    prevchr_len = 1;
  else
    prevchr_len = 0;
  if (regparse[prevchr_len] != NUL) {
    // Exclude composing chars that utfc_ptr2len does include.
    prevchr_len += utf_ptr2len(regparse + prevchr_len);
  }
  regparse += prevchr_len;
  prev_at_start = at_start;
  at_start = FALSE;
  prevprevchr = prevchr;
  prevchr = curchr;
  curchr = nextchr;         /* use previously unget char, or -1 */
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
  prev_at_start = FALSE;

  /* Backup regparse, so that it's at the same position as before the
   * getchr(). */
  regparse -= prevchr_len;
}

/*
 * Get and return the value of the hex string at the current position.
 * Return -1 if there is no valid hex number.
 * The position is updated:
 *     blahblah\%x20asdf
 *	   before-^ ^-after
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
    if (!ascii_isxdigit(c))
      break;
    nr <<= 4;
    nr |= hex2nr(c);
    ++regparse;
  }

  if (i == 0)
    return -1;
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
    if (c < '0' || c > '9')
      break;
    nr *= 10;
    nr += c - '0';
    ++regparse;
    curchr = -1;     /* no longer valid */
  }

  if (i == 0)
    return -1;
  return nr;
}

/*
 * get and return the value of the octal string immediately after the current
 * position. Return -1 for invalid, or 0-255 for valid. Smart enough to handle
 * numbers > 377 correctly (for example, 400 is treated as 40) and doesn't
 * treat 8 or 9 as recognised characters. Position is updated:
 *     blahblah\%o210asdf
 *	   before-^  ^-after
 */
static int64_t getoctchrs(void)
{
  int64_t nr = 0;
  int c;
  int i;

  for (i = 0; i < 3 && nr < 040; i++) {  // -V536
    c = regparse[0];
    if (c < '0' || c > '7')
      break;
    nr <<= 3;
    nr |= hex2nr(c);
    ++regparse;
  }

  if (i == 0)
    return -1;
  return nr;
}

/*
 * Get a number after a backslash that is inside [].
 * When nothing is recognized return a backslash.
 */
static int coll_get_char(void)
{
  int64_t nr = -1;

  switch (*regparse++) {
  case 'd': nr = getdecchrs(); break;
  case 'o': nr = getoctchrs(); break;
  case 'x': nr = gethexchrs(2); break;
  case 'u': nr = gethexchrs(4); break;
  case 'U': nr = gethexchrs(8); break;
  }
  if (nr < 0 || nr > INT_MAX) {
    // If getting the number fails be backwards compatible: the character
    // is a backslash.
    regparse--;
    nr = '\\';
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
  int reverse = FALSE;
  char_u      *first_char;
  long tmp;

  if (*regparse == '-') {
    /* Starts with '-', so reverse the range later */
    regparse++;
    reverse = TRUE;
  }
  first_char = regparse;
  *minval = getdigits_long(&regparse);
  if (*regparse == ',') {           /* There is a comma */
    if (ascii_isdigit(*++regparse))
      *maxval = getdigits_long(&regparse);
    else
      *maxval = MAX_LIMIT;
  } else if (ascii_isdigit(*first_char))
    *maxval = *minval;              /* It was \{n} or \{-n} */
  else
    *maxval = MAX_LIMIT;            /* It was \{} or \{-} */
  if (*regparse == '\\')
    regparse++;         /* Allow either \{...} or \{...\} */
  if (*regparse != '}') {
    sprintf((char *)IObuff, _("E554: Syntax error in %s{...}"),
        reg_magic == MAGIC_ALL ? "" : "\\");
    EMSG_RET_FAIL(IObuff);
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
  skipchr();            /* let's be friends with the lexer again */
  return OK;
}

/*
 * vim_regexec and friends
 */

/*
 * Global work variables for vim_regexec().
 */

/* The current match-position is remembered with these variables: */
static linenr_T reglnum;        /* line number, relative to first line */
static char_u   *regline;       /* start of current line */
static char_u   *reginput;      /* current input, points into "regline" */

static int need_clear_subexpr;          /* subexpressions still need to be
                                         * cleared */
static int need_clear_zsubexpr = FALSE;         /* extmatch subexpressions
                                                 * still need to be cleared */


/* Save the sub-expressions before attempting a match. */
#define save_se(savep, posp, pp) \
  REG_MULTI ? save_se_multi((savep), (posp)) : save_se_one((savep), (pp))

/* After a failed match restore the sub-expressions. */
#define restore_se(savep, posp, pp) { \
    if (REG_MULTI) \
      *(posp) = (savep)->se_u.pos; \
    else \
      *(pp) = (savep)->se_u.ptr; }


#ifdef REGEXP_DEBUG
int regnarrate = 0;
#endif

// Sometimes need to save a copy of a line.  Since alloc()/free() is very
// slow, we keep one allocated piece of memory and only re-allocate it when
// it's too small.  It's freed in bt_regexec_both() when finished.
static char_u   *reg_tofree = NULL;
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

  // Internal copy of 'ignorecase'.  It is set at each call to vim_regexec().
  // Normally it gets the value of "rm_ic" or "rmm_ic", but when the pattern
  // contains '\c' or '\C' the value is overruled.
  bool reg_ic;

  // Similar to rex.reg_ic, but only for 'combining' characters.  Set with \Z
  // flag in the regexp.  Defaults to false, always.
  bool reg_icombine;

  // Copy of "rmm_maxcol": maximum column to search for a match.  Zero when
  // there is no maximum.
  colnr_T reg_maxcol;
} regexec_T;

static regexec_T rex;
static bool rex_in_use = false;

/*
 * "regstack" and "backpos" are used by regmatch().  They are kept over calls
 * to avoid invoking malloc() and free() often.
 * "regstack" is a stack with regitem_T items, sometimes preceded by regstar_T
 * or regbehind_T.
 * "backpos_T" is a table with backpos_T for BACK
 */
static garray_T regstack = GA_EMPTY_INIT_VALUE;
static garray_T backpos = GA_EMPTY_INIT_VALUE;

/*
 * Both for regstack and backpos tables we use the following strategy of
 * allocation (to reduce malloc/free calls):
 * - Initial size is fairly small.
 * - When needed, the tables are grown bigger (8 times at first, double after
 *   that).
 * - After executing the match we free the memory only if the array has grown.
 *   Thus the memory is kept allocated when it's at the initial size.
 * This makes it fast while not keeping a lot of memory allocated.
 * A three times speed increase was observed when using many simple patterns.
 */
#define REGSTACK_INITIAL        2048
#define BACKPOS_INITIAL         64

#if defined(EXITFREE)
void free_regexp_stuff(void)
{
  ga_clear(&regstack);
  ga_clear(&backpos);
  xfree(reg_tofree);
  xfree(reg_prev_sub);
}

#endif

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

static regsave_T behind_pos;

static char_u   *reg_startzp[NSUBEXP];  /* Workspace to mark beginning */
static char_u   *reg_endzp[NSUBEXP];    /*   and end of \z(...\) matches */
static lpos_T reg_startzpos[NSUBEXP];   /* idem, beginning pos */
static lpos_T reg_endzpos[NSUBEXP];     /* idem, end pos */

// TRUE if using multi-line regexp.
#define REG_MULTI       (rex.reg_match == NULL)

/*
 * Match a regexp against a string.
 * "rmp->regprog" is a compiled regexp as returned by vim_regcomp().
 * Uses curbuf for line count and 'iskeyword'.
 * If "line_lbr" is true, consider a "\n" in "line" to be a line break.
 *
 * Returns 0 for failure, number of lines contained in the match otherwise.
 */
static int 
bt_regexec_nl (
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

  long r = bt_regexec_both(line, col, NULL, NULL);
  assert(r <= INT_MAX);
  return (int)r;
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
    return vim_strchr(s, c);
  }

  // Use folded case for UTF-8, slow! For ASCII use libc strpbrk which is
  // expected to be highly optimized.
  if (c > 0x80) {
    const int folded_c = utf_fold(c);
    for (const char_u *p = s; *p != NUL; p += utfc_ptr2len(p)) {
      if (utf_fold(utf_ptr2char(p)) == folded_c) {
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
    return vim_strchr(s, c);
  }

  char tofind[] = { (char)c, (char)cc, NUL };
  return (char_u *)strpbrk((const char *)s, tofind);
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
static long bt_regexec_multi(regmmatch_T *rmp, win_T *win, buf_T *buf,
                             linenr_T lnum, colnr_T col,
                             proftime_T *tm, int *timed_out)
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

  return bt_regexec_both(NULL, col, tm, timed_out);
}

/// Match a regexp against a string ("line" points to the string) or multiple
/// lines ("line" is NULL, use reg_getline()).
/// @return 0 for failure, or number of lines contained in the match.
static long bt_regexec_both(char_u *line,
                            colnr_T col,      // column to start search
                            proftime_T *tm,   // timeout limit or NULL
                            int *timed_out)   // flag set on timeout or NULL
{
  bt_regprog_T        *prog;
  char_u      *s;
  long retval = 0L;

  /* Create "regstack" and "backpos" if they are not allocated yet.
   * We allocate *_INITIAL amount of bytes first and then set the grow size
   * to much bigger value to avoid many malloc calls in case of deep regular
   * expressions.  */
  if (regstack.ga_data == NULL) {
    /* Use an item size of 1 byte, since we push different things
     * onto the regstack. */
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
    line = reg_getline((linenr_T)0);
    rex.reg_startpos = rex.reg_mmatch->startpos;
    rex.reg_endpos = rex.reg_mmatch->endpos;
  } else {
    prog = (bt_regprog_T *)rex.reg_match->regprog;
    rex.reg_startp = rex.reg_match->startp;
    rex.reg_endp = rex.reg_match->endp;
  }

  /* Be paranoid... */
  if (prog == NULL || line == NULL) {
    EMSG(_(e_null));
    goto theend;
  }

  /* Check validity of program. */
  if (prog_magic_wrong())
    goto theend;

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

  /* If there is a "must appear" string, look for it. */
  if (prog->regmust != NULL) {
    int c = utf_ptr2char(prog->regmust);
    s = line + col;

    // This is used very often, esp. for ":global".  Use two versions of
    // the loop to avoid overhead of conditions.
    if (!rex.reg_ic) {
      while ((s = vim_strchr(s, c)) != NULL) {
        if (cstrncmp(s, prog->regmust, &prog->regmlen) == 0) {
          break;  // Found it.
        }
        MB_PTR_ADV(s);
      }
    } else {
      while ((s = cstrchr(s, c)) != NULL) {
        if (cstrncmp(s, prog->regmust, &prog->regmlen) == 0) {
          break;  // Found it.
        }
        MB_PTR_ADV(s);
      }
    }
    if (s == NULL) {  // Not present.
      goto theend;
    }
  }

  regline = line;
  reglnum = 0;
  reg_toolong = FALSE;

  /* Simplest case: Anchored match need be tried only once. */
  if (prog->reganch) {
    int c = utf_ptr2char(regline + col);
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
    /* Messy cases:  unanchored match. */
    while (!got_int) {
      if (prog->regstart != NUL) {
        // Skip until the char we know it must start with.
        s = cstrchr(regline + col, prog->regstart);
        if (s == NULL) {
          retval = 0;
          break;
        }
        col = (int)(s - regline);
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

      /* if not currently on the first line, get it again */
      if (reglnum != 0) {
        reglnum = 0;
        regline = reg_getline((linenr_T)0);
      }
      if (regline[col] == NUL)
        break;
      if (has_mbyte)
        col += (*mb_ptr2len)(regline + col);
      else
        ++col;
      /* Check for timeout once in a twenty times to avoid overhead. */
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
  /* Free "reg_tofree" when it's a bit big.
   * Free regstack and backpos if they are bigger than their initial size. */
  if (reg_tofreelen > 400) {
    xfree(reg_tofree);
    reg_tofree = NULL;
  }
  if (regstack.ga_maxlen > REGSTACK_INITIAL)
    ga_clear(&regstack);
  if (backpos.ga_maxlen > BACKPOS_INITIAL)
    ga_clear(&backpos);

  return retval;
}


/*
 * Create a new extmatch and mark it as referenced once.
 */
static reg_extmatch_T *make_extmatch(void)
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
  if (em != NULL)
    em->refcnt++;
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
    for (i = 0; i < NSUBEXP; ++i)
      xfree(em->matches[i]);
    xfree(em);
  }
}

/// Try match of "prog" with at regline["col"].
/// @returns 0 for failure, or number of lines contained in the match.
static long regtry(bt_regprog_T *prog,
                   colnr_T col,
                   proftime_T *tm,    // timeout limit or NULL
                   int *timed_out)    // flag set on timeout or NULL
{
  reginput = regline + col;
  need_clear_subexpr = TRUE;
  /* Clear the external match subpointers if necessary. */
  if (prog->reghasz == REX_SET)
    need_clear_zsubexpr = TRUE;

  if (regmatch(prog->program + 1, tm, timed_out) == 0) {
    return 0;
  }

  cleanup_subexpr();
  if (REG_MULTI) {
    if (rex.reg_startpos[0].lnum < 0) {
      rex.reg_startpos[0].lnum = 0;
      rex.reg_startpos[0].col = col;
    }
    if (rex.reg_endpos[0].lnum < 0) {
      rex.reg_endpos[0].lnum = reglnum;
      rex.reg_endpos[0].col = (int)(reginput - regline);
    } else {
      // Use line number of "\ze".
      reglnum = rex.reg_endpos[0].lnum;
    }
  } else {
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
    int i;

    cleanup_zsubexpr();
    re_extmatch_out = make_extmatch();
    for (i = 0; i < NSUBEXP; i++) {
      if (REG_MULTI) {
        /* Only accept single line matches. */
        if (reg_startzpos[i].lnum >= 0
            && reg_endzpos[i].lnum == reg_startzpos[i].lnum
            && reg_endzpos[i].col >= reg_startzpos[i].col) {
          re_extmatch_out->matches[i] =
            vim_strnsave(reg_getline(reg_startzpos[i].lnum)
                         + reg_startzpos[i].col,
                         reg_endzpos[i].col
                         - reg_startzpos[i].col);
        }
      } else {
        if (reg_startzp[i] != NULL && reg_endzp[i] != NULL)
          re_extmatch_out->matches[i] =
            vim_strnsave(reg_startzp[i],
                (int)(reg_endzp[i] - reg_startzp[i]));
      }
    }
  }
  return 1 + reglnum;
}


// Get class of previous character.
static int reg_prev_class(void)
{
  if (reginput > regline) {
    return mb_get_class_tab(reginput - 1 - utf_head_off(regline, reginput - 1),
                            rex.reg_buf->b_chartab);
  }
  return -1;
}


// Return TRUE if the current reginput position matches the Visual area.
static int reg_match_visual(void)
{
  pos_T top, bot;
  linenr_T lnum;
  colnr_T col;
  win_T *wp = rex.reg_win == NULL ? curwin : rex.reg_win;
  int mode;
  colnr_T start, end;
  colnr_T start2, end2;

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
  } else {
    if (lt(curbuf->b_visual.vi_start, curbuf->b_visual.vi_end)) {
      top = curbuf->b_visual.vi_start;
      bot = curbuf->b_visual.vi_end;
    } else {
      top = curbuf->b_visual.vi_end;
      bot = curbuf->b_visual.vi_start;
    }
    mode = curbuf->b_visual.vi_mode;
  }
  lnum = reglnum + rex.reg_firstlnum;
  if (lnum < top.lnum || lnum > bot.lnum) {
    return false;
  }

  if (mode == 'v') {
    col = (colnr_T)(reginput - regline);
    if ((lnum == top.lnum && col < top.col)
        || (lnum == bot.lnum && col >= bot.col + (*p_sel != 'e')))
      return FALSE;
  } else if (mode == Ctrl_V) {
    getvvcol(wp, &top, &start, NULL, &end);
    getvvcol(wp, &bot, &start2, NULL, &end2);
    if (start2 < start)
      start = start2;
    if (end2 > end)
      end = end2;
    if (top.col == MAXCOL || bot.col == MAXCOL)
      end = MAXCOL;
    unsigned int cols_u = win_linetabsize(wp, regline,
                                          (colnr_T)(reginput - regline));
    assert(cols_u <= MAXCOL);
    colnr_T cols = (colnr_T)cols_u;
    if (cols < start || cols > end - (*p_sel == 'e'))
      return FALSE;
  }
  return TRUE;
}

#define ADVANCE_REGINPUT() MB_PTR_ADV(reginput)

/*
 * The arguments from BRACE_LIMITS are stored here.  They are actually local
 * to regmatch(), but they are here to reduce the amount of stack space used
 * (it can be called recursively many times).
 */
static long bl_minval;
static long bl_maxval;

/// Main matching routine
///
/// Conceptually the strategy is simple: Check to see whether the current node
/// matches, push an item onto the regstack and loop to see whether the rest
/// matches, and then act accordingly.  In practice we make some effort to
/// avoid using the regstack, in particular by going through "ordinary" nodes
/// (that don't need to know whether the rest of the match failed) by a nested
/// loop.
///
/// Returns TRUE when there is a match.  Leaves reginput and reglnum just after
/// the last matched character.
/// Returns FALSE when there is no match.  Leaves reginput and reglnum in an
/// undefined state!
static int regmatch(
    char_u *scan,               // Current node.
    proftime_T *tm,             // timeout limit or NULL
    int *timed_out              // flag set on timeout or NULL
)
{
  char_u        *next;          /* Next node. */
  int op;
  int c;
  regitem_T     *rp;
  int no;
  int status;                   // one of the RA_ values:
  int tm_count = 0;
#define RA_FAIL         1       // something failed, abort
#define RA_CONT         2       // continue in inner loop
#define RA_BREAK        3       // break inner loop
#define RA_MATCH        4       // successful match
#define RA_NOMATCH      5       // didn't match

  // Make "regstack" and "backpos" empty.  They are allocated and freed in
  // bt_regexec_both() to reduce malloc()/free() calls.
  regstack.ga_len = 0;
  backpos.ga_len = 0;

  /*
   * Repeat until "regstack" is empty.
   */
  for (;; ) {
    /* Some patterns may take a long time to match, e.g., "\([a-z]\+\)\+Q".
     * Allow interrupting them with CTRL-C. */
    fast_breakcheck();

#ifdef REGEXP_DEBUG
    if (scan != NULL && regnarrate) {
      mch_errmsg((char *)regprop(scan));
      mch_errmsg("(\n");
    }
#endif

    /*
     * Repeat for items that can be matched sequentially, without using the
     * regstack.
     */
    for (;; ) {
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
        mch_errmsg((char *)regprop(scan));
        mch_errmsg("...\n");
        if (re_extmatch_in != NULL) {
          int i;

          mch_errmsg(_("External submatches:\n"));
          for (i = 0; i < NSUBEXP; i++) {
            mch_errmsg("    \"");
            if (re_extmatch_in->matches[i] != NULL)
              mch_errmsg((char *)re_extmatch_in->matches[i]);
            mch_errmsg("\"\n");
          }
        }
      }
#endif
      next = regnext(scan);

      op = OP(scan);
      // Check for character class with NL added.
      if (!rex.reg_line_lbr && WITH_NL(op) && REG_MULTI
          && *reginput == NUL && reglnum <= rex.reg_maxline) {
        reg_nextline();
      } else if (rex.reg_line_lbr && WITH_NL(op) && *reginput == '\n') {
        ADVANCE_REGINPUT();
      } else {
        if (WITH_NL(op)) {
          op -= ADD_NL;
        }
        c = utf_ptr2char(reginput);
        switch (op) {
        case BOL:
          if (reginput != regline)
            status = RA_NOMATCH;
          break;

        case EOL:
          if (c != NUL)
            status = RA_NOMATCH;
          break;

        case RE_BOF:
          // We're not at the beginning of the file when below the first
          // line where we started, not at the start of the line or we
          // didn't start at the first line of the buffer.
          if (reglnum != 0 || reginput != regline
              || (REG_MULTI && rex.reg_firstlnum > 1)) {
            status = RA_NOMATCH;
          }
          break;

        case RE_EOF:
          if (reglnum != rex.reg_maxline || c != NUL) {
            status = RA_NOMATCH;
          }
          break;

        case CURSOR:
          // Check if the buffer is in a window and compare the
          // rex.reg_win->w_cursor position to the match position.
          if (rex.reg_win == NULL
              || (reglnum + rex.reg_firstlnum != rex.reg_win->w_cursor.lnum)
              || ((colnr_T)(reginput - regline) != rex.reg_win->w_cursor.col)) {
            status = RA_NOMATCH;
          }
          break;

        case RE_MARK:
          /* Compare the mark position to the match position. */
        {
          int mark = OPERAND(scan)[0];
          int cmp = OPERAND(scan)[1];
          pos_T   *pos;

          pos = getmark_buf(rex.reg_buf, mark, false);
          if (pos == NULL                    // mark doesn't exist
              || pos->lnum <= 0              // mark isn't set in reg_buf
              || (pos->lnum == reglnum + rex.reg_firstlnum
                  ? (pos->col == (colnr_T)(reginput - regline)
                     ? (cmp == '<' || cmp == '>')
                     : (pos->col < (colnr_T)(reginput - regline)
                        ? cmp != '>'
                        : cmp != '<'))
                  : (pos->lnum < reglnum + rex.reg_firstlnum
                     ? cmp != '>'
                     : cmp != '<'))) {
            status = RA_NOMATCH;
          }
        }
        break;

        case RE_VISUAL:
          if (!reg_match_visual())
            status = RA_NOMATCH;
          break;

        case RE_LNUM:
          assert(reglnum + rex.reg_firstlnum >= 0
                 && (uintmax_t)(reglnum + rex.reg_firstlnum) <= UINT32_MAX);
          if (!REG_MULTI
              || !re_num_cmp((uint32_t)(reglnum + rex.reg_firstlnum), scan)) {
            status = RA_NOMATCH;
          }
          break;

        case RE_COL:
          assert(reginput - regline + 1 >= 0
                 && (uintmax_t)(reginput - regline + 1) <= UINT32_MAX);
          if (!re_num_cmp((uint32_t)(reginput - regline + 1), scan))
            status = RA_NOMATCH;
          break;

        case RE_VCOL:
          if (!re_num_cmp(win_linetabsize(rex.reg_win == NULL
                                          ? curwin : rex.reg_win,
                                          regline,
                                          (colnr_T)(reginput - regline)) + 1,
                          scan)) {
            status = RA_NOMATCH;
          }
          break;

        case BOW:       /* \<word; reginput points to w */
          if (c == NUL)         /* Can't match at end of line */
            status = RA_NOMATCH;
          else if (has_mbyte) {
            int this_class;

            // Get class of current and previous char (if it exists).
            this_class = mb_get_class_tab(reginput, rex.reg_buf->b_chartab);
            if (this_class <= 1) {
              status = RA_NOMATCH;  // Not on a word at all.
            } else if (reg_prev_class() == this_class) {
              status = RA_NOMATCH;  // Previous char is in same word.
            }
          } else {
            if (!vim_iswordc_buf(c, rex.reg_buf)
                || (reginput > regline
                    && vim_iswordc_buf(reginput[-1], rex.reg_buf))) {
              status = RA_NOMATCH;
            }
          }
          break;

        case EOW:       /* word\>; reginput points after d */
          if (reginput == regline)      /* Can't match at start of line */
            status = RA_NOMATCH;
          else if (has_mbyte) {
            int this_class, prev_class;

            // Get class of current and previous char (if it exists).
            this_class = mb_get_class_tab(reginput, rex.reg_buf->b_chartab);
            prev_class = reg_prev_class();
            if (this_class == prev_class
                || prev_class == 0 || prev_class == 1)
              status = RA_NOMATCH;
          } else {
            if (!vim_iswordc_buf(reginput[-1], rex.reg_buf)
                || (reginput[0] != NUL && vim_iswordc_buf(c, rex.reg_buf))) {
              status = RA_NOMATCH;
            }
          }
          break;   /* Matched with EOW */

        case ANY:
          /* ANY does not match new lines. */
          if (c == NUL)
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case IDENT:
          if (!vim_isIDc(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case SIDENT:
          if (ascii_isdigit(*reginput) || !vim_isIDc(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case KWORD:
          if (!vim_iswordp_buf(reginput, rex.reg_buf)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case SKWORD:
          if (ascii_isdigit(*reginput)
              || !vim_iswordp_buf(reginput, rex.reg_buf)) {
            status = RA_NOMATCH;
          } else {
            ADVANCE_REGINPUT();
          }
          break;

        case FNAME:
          if (!vim_isfilec(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case SFNAME:
          if (ascii_isdigit(*reginput) || !vim_isfilec(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case PRINT:
          if (!vim_isprintc(PTR2CHAR(reginput)))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case SPRINT:
          if (ascii_isdigit(*reginput) || !vim_isprintc(PTR2CHAR(reginput)))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case WHITE:
          if (!ascii_iswhite(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case NWHITE:
          if (c == NUL || ascii_iswhite(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case DIGIT:
          if (!ri_digit(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case NDIGIT:
          if (c == NUL || ri_digit(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case HEX:
          if (!ri_hex(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case NHEX:
          if (c == NUL || ri_hex(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case OCTAL:
          if (!ri_octal(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case NOCTAL:
          if (c == NUL || ri_octal(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case WORD:
          if (!ri_word(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case NWORD:
          if (c == NUL || ri_word(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case HEAD:
          if (!ri_head(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case NHEAD:
          if (c == NUL || ri_head(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case ALPHA:
          if (!ri_alpha(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case NALPHA:
          if (c == NUL || ri_alpha(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case LOWER:
          if (!ri_lower(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case NLOWER:
          if (c == NUL || ri_lower(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case UPPER:
          if (!ri_upper(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case NUPPER:
          if (c == NUL || ri_upper(c))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case EXACTLY:
        {
          int len;
          char_u  *opnd;

          opnd = OPERAND(scan);
          // Inline the first byte, for speed.
          if (*opnd != *reginput
              && (!rex.reg_ic
                  || (!enc_utf8
                      && mb_tolower(*opnd) != mb_tolower(*reginput)))) {
            status = RA_NOMATCH;
          } else if (*opnd == NUL) {
            // match empty string always works; happens when "~" is
            // empty.
          } else {
            if (opnd[1] == NUL && !(enc_utf8 && rex.reg_ic)) {
              len = 1;  // matched a single byte above
            } else {
              // Need to match first byte again for multi-byte.
              len = (int)STRLEN(opnd);
              if (cstrncmp(opnd, reginput, &len) != 0) {
                status = RA_NOMATCH;
              }
            }
            // Check for following composing character, unless %C
            // follows (skips over all composing chars).
            if (status != RA_NOMATCH && enc_utf8
                && UTF_COMPOSINGLIKE(reginput, reginput + len)
                && !rex.reg_icombine
                && OP(next) != RE_COMPOSING) {
              // raaron: This code makes a composing character get
              // ignored, which is the correct behavior (sometimes)
              // for voweled Hebrew texts.
              status = RA_NOMATCH;
            }
            if (status != RA_NOMATCH) {
              reginput += len;
            }
          }
        }
        break;

        case ANYOF:
        case ANYBUT:
          if (c == NUL)
            status = RA_NOMATCH;
          else if ((cstrchr(OPERAND(scan), c) == NULL) == (op == ANYOF))
            status = RA_NOMATCH;
          else
            ADVANCE_REGINPUT();
          break;

        case MULTIBYTECODE:
          if (has_mbyte) {
            int i, len;
            char_u  *opnd;
            int opndc = 0, inpc;

            opnd = OPERAND(scan);
            // Safety check (just in case 'encoding' was changed since
            // compiling the program).
            if ((len = (*mb_ptr2len)(opnd)) < 2) {
              status = RA_NOMATCH;
              break;
            }
            if (enc_utf8) {
              opndc = utf_ptr2char(opnd);
            }
            if (enc_utf8 && utf_iscomposing(opndc)) {
              /* When only a composing char is given match at any
               * position where that composing char appears. */
              status = RA_NOMATCH;
              for (i = 0; reginput[i] != NUL; i += utf_ptr2len(reginput + i)) {
                inpc = utf_ptr2char(reginput + i);
                if (!utf_iscomposing(inpc)) {
                  if (i > 0) {
                    break;
                  }
                } else if (opndc == inpc) {
                  // Include all following composing chars.
                  len = i + utfc_ptr2len(reginput + i);
                  status = RA_MATCH;
                  break;
                }
              }
            } else
              for (i = 0; i < len; ++i)
                if (opnd[i] != reginput[i]) {
                  status = RA_NOMATCH;
                  break;
                }
            reginput += len;
          } else
            status = RA_NOMATCH;
          break;

        case RE_COMPOSING:
          if (enc_utf8) {
            // Skip composing characters.
            while (utf_iscomposing(utf_ptr2char(reginput))) {
              MB_CPTR_ADV(reginput);
            }
          }
          break;

        case NOTHING:
          break;

        case BACK:
        {
          int i;

          /*
           * When we run into BACK we need to check if we don't keep
           * looping without matching any input.  The second and later
           * times a BACK is encountered it fails if the input is still
           * at the same position as the previous time.
           * The positions are stored in "backpos" and found by the
           * current value of "scan", the position in the RE program.
           */
          backpos_T *bp = (backpos_T *)backpos.ga_data;
          for (i = 0; i < backpos.ga_len; ++i)
            if (bp[i].bp_scan == scan)
              break;
          if (i == backpos.ga_len) {
            backpos_T *p = GA_APPEND_VIA_PTR(backpos_T, &backpos);
            p->bp_scan = scan;
          } else if (reg_save_equal(&bp[i].bp_pos))
            /* Still at same position as last time, fail. */
            status = RA_NOMATCH;

          if (status != RA_FAIL && status != RA_NOMATCH)
            reg_save(&bp[i].bp_pos, &backpos);
        }
        break;

        case MOPEN + 0:     /* Match start: \zs */
        case MOPEN + 1:     /* \( */
        case MOPEN + 2:
        case MOPEN + 3:
        case MOPEN + 4:
        case MOPEN + 5:
        case MOPEN + 6:
        case MOPEN + 7:
        case MOPEN + 8:
        case MOPEN + 9:
        {
          no = op - MOPEN;
          cleanup_subexpr();
          rp = regstack_push(RS_MOPEN, scan);
          if (rp == NULL)
            status = RA_FAIL;
          else {
            rp->rs_no = no;
            save_se(&rp->rs_un.sesave, &rex.reg_startpos[no],
                    &rex.reg_startp[no]);
            // We simply continue and handle the result when done.
          }
        }
        break;

        case NOPEN:         /* \%( */
        case NCLOSE:        /* \) after \%( */
          if (regstack_push(RS_NOPEN, scan) == NULL)
            status = RA_FAIL;
          /* We simply continue and handle the result when done. */
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
        {
          no = op - ZOPEN;
          cleanup_zsubexpr();
          rp = regstack_push(RS_ZOPEN, scan);
          if (rp == NULL)
            status = RA_FAIL;
          else {
            rp->rs_no = no;
            save_se(&rp->rs_un.sesave, &reg_startzpos[no],
                &reg_startzp[no]);
            /* We simply continue and handle the result when done. */
          }
        }
        break;

        case MCLOSE + 0:    /* Match end: \ze */
        case MCLOSE + 1:    /* \) */
        case MCLOSE + 2:
        case MCLOSE + 3:
        case MCLOSE + 4:
        case MCLOSE + 5:
        case MCLOSE + 6:
        case MCLOSE + 7:
        case MCLOSE + 8:
        case MCLOSE + 9:
        {
          no = op - MCLOSE;
          cleanup_subexpr();
          rp = regstack_push(RS_MCLOSE, scan);
          if (rp == NULL) {
            status = RA_FAIL;
          } else {
            rp->rs_no = no;
            save_se(&rp->rs_un.sesave, &rex.reg_endpos[no], &rex.reg_endp[no]);
            // We simply continue and handle the result when done.
          }
        }
        break;

        case ZCLOSE + 1:    /* \) after \z( */
        case ZCLOSE + 2:
        case ZCLOSE + 3:
        case ZCLOSE + 4:
        case ZCLOSE + 5:
        case ZCLOSE + 6:
        case ZCLOSE + 7:
        case ZCLOSE + 8:
        case ZCLOSE + 9:
        {
          no = op - ZCLOSE;
          cleanup_zsubexpr();
          rp = regstack_push(RS_ZCLOSE, scan);
          if (rp == NULL)
            status = RA_FAIL;
          else {
            rp->rs_no = no;
            save_se(&rp->rs_un.sesave, &reg_endzpos[no],
                &reg_endzp[no]);
            /* We simply continue and handle the result when done. */
          }
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
        case BACKREF + 9:
        {
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
              if (cstrncmp(rex.reg_startp[no], reginput, &len) != 0) {
                status = RA_NOMATCH;
              }
            }
          } else {  // Multi-line regexp
            if (rex.reg_startpos[no].lnum < 0 || rex.reg_endpos[no].lnum < 0) {
              // Backref was not set: Match an empty string.
              len = 0;
            } else {
              if (rex.reg_startpos[no].lnum == reglnum
                  && rex.reg_endpos[no].lnum == reglnum) {
                // Compare back-ref within the current line.
                len = rex.reg_endpos[no].col - rex.reg_startpos[no].col;
                if (cstrncmp(regline + rex.reg_startpos[no].col,
                             reginput, &len) != 0) {
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

          /* Matched the backref, skip over it. */
          reginput += len;
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
        {
          int len;

          cleanup_zsubexpr();
          no = op - ZREF;
          if (re_extmatch_in != NULL
              && re_extmatch_in->matches[no] != NULL) {
            len = (int)STRLEN(re_extmatch_in->matches[no]);
            if (cstrncmp(re_extmatch_in->matches[no],
                    reginput, &len) != 0)
              status = RA_NOMATCH;
            else
              reginput += len;
          } else {
            /* Backref was not set: Match an empty string. */
          }
        }
        break;

        case BRANCH:
        {
          if (OP(next) != BRANCH)       /* No choice. */
            next = OPERAND(scan);               /* Avoid recursion. */
          else {
            rp = regstack_push(RS_BRANCH, scan);
            if (rp == NULL)
              status = RA_FAIL;
            else
              status = RA_BREAK;                /* rest is below */
          }
        }
        break;

        case BRACE_LIMITS:
        {
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
        {
          no = op - BRACE_COMPLEX;
          ++brace_count[no];

          /* If not matched enough times yet, try one more */
          if (brace_count[no] <= (brace_min[no] <= brace_max[no]
                                  ? brace_min[no] : brace_max[no])) {
            rp = regstack_push(RS_BRCPLX_MORE, scan);
            if (rp == NULL)
              status = RA_FAIL;
            else {
              rp->rs_no = no;
              reg_save(&rp->rs_un.regsave, &backpos);
              next = OPERAND(scan);
              /* We continue and handle the result when done. */
            }
            break;
          }

          /* If matched enough times, may try matching some more */
          if (brace_min[no] <= brace_max[no]) {
            /* Range is the normal way around, use longest match */
            if (brace_count[no] <= brace_max[no]) {
              rp = regstack_push(RS_BRCPLX_LONG, scan);
              if (rp == NULL)
                status = RA_FAIL;
              else {
                rp->rs_no = no;
                reg_save(&rp->rs_un.regsave, &backpos);
                next = OPERAND(scan);
                /* We continue and handle the result when done. */
              }
            }
          } else {
            /* Range is backwards, use shortest match first */
            if (brace_count[no] <= brace_min[no]) {
              rp = regstack_push(RS_BRCPLX_SHORT, scan);
              if (rp == NULL)
                status = RA_FAIL;
              else {
                reg_save(&rp->rs_un.regsave, &backpos);
                /* We continue and handle the result when done. */
              }
            }
          }
        }
        break;

        case BRACE_SIMPLE:
        case STAR:
        case PLUS:
        {
          regstar_T rst;

          /*
           * Lookahead to avoid useless match attempts when we know
           * what character comes next.
           */
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

          /*
           * When maxval > minval, try matching as much as possible, up
           * to maxval.  When maxval < minval, try matching at least the
           * minimal number (since the range is backwards, that's also
           * maxval!).
           */
          rst.count = regrepeat(OPERAND(scan), rst.maxval);
          if (got_int) {
            status = RA_FAIL;
            break;
          }
          if (rst.minval <= rst.maxval
              ? rst.count >= rst.minval : rst.count >= rst.maxval) {
            /* It could match.  Prepare for trying to match what
             * follows.  The code is below.  Parameters are stored in
             * a regstar_T on the regstack. */
            if ((long)((unsigned)regstack.ga_len >> 10) >= p_mmp) {
              EMSG(_(e_maxmempat));
              status = RA_FAIL;
            } else {
              ga_grow(&regstack, sizeof(regstar_T));
              regstack.ga_len += sizeof(regstar_T);
              rp = regstack_push(rst.minval <= rst.maxval
                  ? RS_STAR_LONG : RS_STAR_SHORT, scan);
              if (rp == NULL)
                status = RA_FAIL;
              else {
                *(((regstar_T *)rp) - 1) = rst;
                status = RA_BREAK;                  /* skip the restore bits */
              }
            }
          } else
            status = RA_NOMATCH;

        }
        break;

        case NOMATCH:
        case MATCH:
        case SUBPAT:
          rp = regstack_push(RS_NOMATCH, scan);
          if (rp == NULL)
            status = RA_FAIL;
          else {
            rp->rs_no = op;
            reg_save(&rp->rs_un.regsave, &backpos);
            next = OPERAND(scan);
            /* We continue and handle the result when done. */
          }
          break;

        case BEHIND:
        case NOBEHIND:
          /* Need a bit of room to store extra positions. */
          if ((long)((unsigned)regstack.ga_len >> 10) >= p_mmp) {
            EMSG(_(e_maxmempat));
            status = RA_FAIL;
          } else {
            ga_grow(&regstack, sizeof(regbehind_T));
            regstack.ga_len += sizeof(regbehind_T);
            rp = regstack_push(RS_BEHIND1, scan);
            if (rp == NULL)
              status = RA_FAIL;
            else {
              /* Need to save the subexpr to be able to restore them
               * when there is a match but we don't use it. */
              save_subexpr(((regbehind_T *)rp) - 1);

              rp->rs_no = op;
              reg_save(&rp->rs_un.regsave, &backpos);
              /* First try if what follows matches.  If it does then we
               * check the behind match by looping. */
            }
          }
          break;

        case BHPOS:
          if (REG_MULTI) {
            if (behind_pos.rs_u.pos.col != (colnr_T)(reginput - regline)
                || behind_pos.rs_u.pos.lnum != reglnum)
              status = RA_NOMATCH;
          } else if (behind_pos.rs_u.ptr != reginput)
            status = RA_NOMATCH;
          break;

        case NEWL:
          if ((c != NUL || !REG_MULTI || reglnum > rex.reg_maxline
               || rex.reg_line_lbr) && (c != '\n' || !rex.reg_line_lbr)) {
            status = RA_NOMATCH;
          } else if (rex.reg_line_lbr) {
            ADVANCE_REGINPUT();
          } else {
            reg_nextline();
          }
          break;

        case END:
          status = RA_MATCH;    /* Success! */
          break;

        default:
          EMSG(_(e_re_corr));
#ifdef REGEXP_DEBUG
          printf("Illegal op code %d\n", op);
#endif
          status = RA_FAIL;
          break;
        }
      }

      /* If we can't continue sequentially, break the inner loop. */
      if (status != RA_CONT)
        break;

      /* Continue in inner loop, advance to next item. */
      scan = next;

    } /* end of inner loop */

    /*
     * If there is something on the regstack execute the code for the state.
     * If the state is popped then loop and use the older state.
     */
    while (!GA_EMPTY(&regstack) && status != RA_FAIL) {
      rp = (regitem_T *)((char *)regstack.ga_data + regstack.ga_len) - 1;
      switch (rp->rs_state) {
      case RS_NOPEN:
        /* Result is passed on as-is, simply pop the state. */
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
        /* Pop the state.  Restore pointers when there is no match. */
        if (status == RA_NOMATCH)
          restore_se(&rp->rs_un.sesave, &reg_startzpos[rp->rs_no],
              &reg_startzp[rp->rs_no]);
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
        /* Pop the state.  Restore pointers when there is no match. */
        if (status == RA_NOMATCH)
          restore_se(&rp->rs_un.sesave, &reg_endzpos[rp->rs_no],
              &reg_endzp[rp->rs_no]);
        regstack_pop(&scan);
        break;

      case RS_BRANCH:
        if (status == RA_MATCH)
          /* this branch matched, use it */
          regstack_pop(&scan);
        else {
          if (status != RA_BREAK) {
            /* After a non-matching branch: try next one. */
            reg_restore(&rp->rs_un.regsave, &backpos);
            scan = rp->rs_scan;
          }
          if (scan == NULL || OP(scan) != BRANCH) {
            /* no more branches, didn't find a match */
            status = RA_NOMATCH;
            regstack_pop(&scan);
          } else {
            /* Prepare to try a branch. */
            rp->rs_scan = regnext(scan);
            reg_save(&rp->rs_un.regsave, &backpos);
            scan = OPERAND(scan);
          }
        }
        break;

      case RS_BRCPLX_MORE:
        /* Pop the state.  Restore pointers when there is no match. */
        if (status == RA_NOMATCH) {
          reg_restore(&rp->rs_un.regsave, &backpos);
          --brace_count[rp->rs_no];             /* decrement match count */
        }
        regstack_pop(&scan);
        break;

      case RS_BRCPLX_LONG:
        /* Pop the state.  Restore pointers when there is no match. */
        if (status == RA_NOMATCH) {
          /* There was no match, but we did find enough matches. */
          reg_restore(&rp->rs_un.regsave, &backpos);
          --brace_count[rp->rs_no];
          /* continue with the items after "\{}" */
          status = RA_CONT;
        }
        regstack_pop(&scan);
        if (status == RA_CONT)
          scan = regnext(scan);
        break;

      case RS_BRCPLX_SHORT:
        /* Pop the state.  Restore pointers when there is no match. */
        if (status == RA_NOMATCH)
          /* There was no match, try to match one more item. */
          reg_restore(&rp->rs_un.regsave, &backpos);
        regstack_pop(&scan);
        if (status == RA_NOMATCH) {
          scan = OPERAND(scan);
          status = RA_CONT;
        }
        break;

      case RS_NOMATCH:
        /* Pop the state.  If the operand matches for NOMATCH or
        * doesn't match for MATCH/SUBPAT, we fail.  Otherwise backup,
        * except for SUBPAT, and continue with the next item. */
        if (status == (rp->rs_no == NOMATCH ? RA_MATCH : RA_NOMATCH))
          status = RA_NOMATCH;
        else {
          status = RA_CONT;
          if (rp->rs_no != SUBPAT)              /* zero-width */
            reg_restore(&rp->rs_un.regsave, &backpos);
        }
        regstack_pop(&scan);
        if (status == RA_CONT)
          scan = regnext(scan);
        break;

      case RS_BEHIND1:
        if (status == RA_NOMATCH) {
          regstack_pop(&scan);
          regstack.ga_len -= sizeof(regbehind_T);
        } else {
          /* The stuff after BEHIND/NOBEHIND matches.  Now try if
           * the behind part does (not) match before the current
           * position in the input.  This must be done at every
           * position in the input and checking if the match ends at
           * the current position. */

          /* save the position after the found match for next */
          reg_save(&(((regbehind_T *)rp) - 1)->save_after, &backpos);

          /* Start looking for a match with operand at the current
           * position.  Go back one character until we find the
           * result, hitting the start of the line or the previous
           * line (for multi-line matching).
           * Set behind_pos to where the match should end, BHPOS
           * will match it.  Save the current value. */
          (((regbehind_T *)rp) - 1)->save_behind = behind_pos;
          behind_pos = rp->rs_un.regsave;

          rp->rs_state = RS_BEHIND2;

          reg_restore(&rp->rs_un.regsave, &backpos);
          scan = OPERAND(rp->rs_scan) + 4;
        }
        break;

      case RS_BEHIND2:
        /*
         * Looping for BEHIND / NOBEHIND match.
         */
        if (status == RA_MATCH && reg_save_equal(&behind_pos)) {
          /* found a match that ends where "next" started */
          behind_pos = (((regbehind_T *)rp) - 1)->save_behind;
          if (rp->rs_no == BEHIND)
            reg_restore(&(((regbehind_T *)rp) - 1)->save_after,
                &backpos);
          else {
            /* But we didn't want a match.  Need to restore the
             * subexpr, because what follows matched, so they have
             * been set. */
            status = RA_NOMATCH;
            restore_subexpr(((regbehind_T *)rp) - 1);
          }
          regstack_pop(&scan);
          regstack.ga_len -= sizeof(regbehind_T);
        } else {
          long limit;

          /* No match or a match that doesn't end where we want it: Go
           * back one character.  May go to previous line once. */
          no = OK;
          limit = OPERAND_MIN(rp->rs_scan);
          if (REG_MULTI) {
            if (limit > 0
                && ((rp->rs_un.regsave.rs_u.pos.lnum
                     < behind_pos.rs_u.pos.lnum
                     ? (colnr_T)STRLEN(regline)
                     : behind_pos.rs_u.pos.col)
                    - rp->rs_un.regsave.rs_u.pos.col >= limit))
              no = FAIL;
            else if (rp->rs_un.regsave.rs_u.pos.col == 0) {
              if (rp->rs_un.regsave.rs_u.pos.lnum
                  < behind_pos.rs_u.pos.lnum
                  || reg_getline(
                      --rp->rs_un.regsave.rs_u.pos.lnum)
                  == NULL)
                no = FAIL;
              else {
                reg_restore(&rp->rs_un.regsave, &backpos);
                rp->rs_un.regsave.rs_u.pos.col =
                  (colnr_T)STRLEN(regline);
              }
            } else {
              const char_u *const line =
                  reg_getline(rp->rs_un.regsave.rs_u.pos.lnum);

              rp->rs_un.regsave.rs_u.pos.col -=
                  utf_head_off(line,
                               line + rp->rs_un.regsave.rs_u.pos.col - 1)
                  + 1;
            }
          } else {
            if (rp->rs_un.regsave.rs_u.ptr == regline) {
              no = FAIL;
            } else {
              MB_PTR_BACK(regline, rp->rs_un.regsave.rs_u.ptr);
              if (limit > 0
                  && (long)(behind_pos.rs_u.ptr
                            - rp->rs_un.regsave.rs_u.ptr) > limit) {
                no = FAIL;
              }
            }
          }
          if (no == OK) {
            /* Advanced, prepare for finding match again. */
            reg_restore(&rp->rs_un.regsave, &backpos);
            scan = OPERAND(rp->rs_scan) + 4;
            if (status == RA_MATCH) {
              /* We did match, so subexpr may have been changed,
               * need to restore them for the next try. */
              status = RA_NOMATCH;
              restore_subexpr(((regbehind_T *)rp) - 1);
            }
          } else {
            /* Can't advance.  For NOBEHIND that's a match. */
            behind_pos = (((regbehind_T *)rp) - 1)->save_behind;
            if (rp->rs_no == NOBEHIND) {
              reg_restore(&(((regbehind_T *)rp) - 1)->save_after,
                  &backpos);
              status = RA_MATCH;
            } else {
              /* We do want a proper match.  Need to restore the
               * subexpr if we had a match, because they may have
               * been set. */
              if (status == RA_MATCH) {
                status = RA_NOMATCH;
                restore_subexpr(((regbehind_T *)rp) - 1);
              }
            }
            regstack_pop(&scan);
            regstack.ga_len -= sizeof(regbehind_T);
          }
        }
        break;

      case RS_STAR_LONG:
      case RS_STAR_SHORT:
      {
        regstar_T           *rst = ((regstar_T *)rp) - 1;

        if (status == RA_MATCH) {
          regstack_pop(&scan);
          regstack.ga_len -= sizeof(regstar_T);
          break;
        }

        /* Tried once already, restore input pointers. */
        if (status != RA_BREAK)
          reg_restore(&rp->rs_un.regsave, &backpos);

        /* Repeat until we found a position where it could match. */
        for (;; ) {
          if (status != RA_BREAK) {
            /* Tried first position already, advance. */
            if (rp->rs_state == RS_STAR_LONG) {
              /* Trying for longest match, but couldn't or
               * didn't match -- back up one char. */
              if (--rst->count < rst->minval)
                break;
              if (reginput == regline) {
                // backup to last char of previous line
                reglnum--;
                regline = reg_getline(reglnum);
                // Just in case regrepeat() didn't count right.
                if (regline == NULL) {
                  break;
                }
                reginput = regline + STRLEN(regline);
                fast_breakcheck();
              } else {
                MB_PTR_BACK(regline, reginput);
              }
            } else {
              /* Range is backwards, use shortest match first.
               * Careful: maxval and minval are exchanged!
               * Couldn't or didn't match: try advancing one
               * char. */
              if (rst->count == rst->minval
                  || regrepeat(OPERAND(rp->rs_scan), 1L) == 0)
                break;
              ++rst->count;
            }
            if (got_int)
              break;
          } else
            status = RA_NOMATCH;

          /* If it could match, try it. */
          if (rst->nextb == NUL || *reginput == rst->nextb
              || *reginput == rst->nextb_ic) {
            reg_save(&rp->rs_un.regsave, &backpos);
            scan = regnext(rp->rs_scan);
            status = RA_CONT;
            break;
          }
        }
        if (status != RA_CONT) {
          /* Failed. */
          regstack_pop(&scan);
          regstack.ga_len -= sizeof(regstar_T);
          status = RA_NOMATCH;
        }
      }
      break;
      }

      /* If we want to continue the inner loop or didn't pop a state
       * continue matching loop */
      if (status == RA_CONT || rp == (regitem_T *)
          ((char *)regstack.ga_data + regstack.ga_len) - 1)
        break;
    }

    /* May need to continue with the inner loop, starting at "scan". */
    if (status == RA_CONT)
      continue;

    /*
     * If the regstack is empty or something failed we are done.
     */
    if (GA_EMPTY(&regstack) || status == RA_FAIL) {
      if (scan == NULL) {
        /*
         * We get here only if there's trouble -- normally "case END" is
         * the terminating point.
         */
        EMSG(_(e_re_corr));
#ifdef REGEXP_DEBUG
        printf("Premature EOL\n");
#endif
      }
      if (status == RA_FAIL)
        got_int = TRUE;
      return status == RA_MATCH;
    }

  } /* End of loop until the regstack is empty. */

  /* NOTREACHED */
}

/*
 * Push an item onto the regstack.
 * Returns pointer to new item.  Returns NULL when out of memory.
 */
static regitem_T *regstack_push(regstate_T state, char_u *scan)
{
  regitem_T   *rp;

  if ((long)((unsigned)regstack.ga_len >> 10) >= p_mmp) {
    EMSG(_(e_maxmempat));
    return NULL;
  }
  ga_grow(&regstack, sizeof(regitem_T));

  rp = (regitem_T *)((char *)regstack.ga_data + regstack.ga_len);
  rp->rs_state = state;
  rp->rs_scan = scan;

  regstack.ga_len += sizeof(regitem_T);
  return rp;
}

/*
 * Pop an item from the regstack.
 */
static void regstack_pop(char_u **scan)
{
  regitem_T   *rp;

  rp = (regitem_T *)((char *)regstack.ga_data + regstack.ga_len) - 1;
  *scan = rp->rs_scan;

  regstack.ga_len -= sizeof(regitem_T);
}

/*
 * regrepeat - repeatedly match something simple, return how many.
 * Advances reginput (and reglnum) to just after the matched chars.
 */
static int 
regrepeat (
    char_u *p,
    long maxcount              /* maximum number of matches allowed */
)
{
  long count = 0;
  char_u      *scan;
  char_u      *opnd;
  int mask;
  int testval = 0;

  scan = reginput;          /* Make local copy of reginput for speed. */
  opnd = OPERAND(p);
  switch (OP(p)) {
  case ANY:
  case ANY + ADD_NL:
    while (count < maxcount) {
      /* Matching anything means we continue until end-of-line (or
       * end-of-file for ANY + ADD_NL), only limited by maxcount. */
      while (*scan != NUL && count < maxcount) {
        count++;
        MB_PTR_ADV(scan);
      }
      if (!REG_MULTI || !WITH_NL(OP(p)) || reglnum > rex.reg_maxline
          || rex.reg_line_lbr || count == maxcount) {
        break;
      }
      count++;  // count the line-break
      reg_nextline();
      scan = reginput;
      if (got_int)
        break;
    }
    break;

  case IDENT:
  case IDENT + ADD_NL:
    testval = 1;
    FALLTHROUGH;
  case SIDENT:
  case SIDENT + ADD_NL:
    while (count < maxcount) {
      if (vim_isIDc(PTR2CHAR(scan)) && (testval || !ascii_isdigit(*scan))) {
        MB_PTR_ADV(scan);
      } else if (*scan == NUL) {
        if (!REG_MULTI || !WITH_NL(OP(p)) || reglnum > rex.reg_maxline
            || rex.reg_line_lbr) {
          break;
        }
        reg_nextline();
        scan = reginput;
        if (got_int)
          break;
      } else if (rex.reg_line_lbr && *scan == '\n' && WITH_NL(OP(p))) {
        scan++;
      } else {
        break;
      }
      ++count;
    }
    break;

  case KWORD:
  case KWORD + ADD_NL:
    testval = 1;
    FALLTHROUGH;
  case SKWORD:
  case SKWORD + ADD_NL:
    while (count < maxcount) {
      if (vim_iswordp_buf(scan, rex.reg_buf)
          && (testval || !ascii_isdigit(*scan))) {
        MB_PTR_ADV(scan);
      } else if (*scan == NUL) {
        if (!REG_MULTI || !WITH_NL(OP(p)) || reglnum > rex.reg_maxline
            || rex.reg_line_lbr) {
          break;
        }
        reg_nextline();
        scan = reginput;
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
      if (vim_isfilec(PTR2CHAR(scan)) && (testval || !ascii_isdigit(*scan))) {
        MB_PTR_ADV(scan);
      } else if (*scan == NUL) {
        if (!REG_MULTI || !WITH_NL(OP(p)) || reglnum > rex.reg_maxline
            || rex.reg_line_lbr) {
          break;
        }
        reg_nextline();
        scan = reginput;
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
        if (!REG_MULTI || !WITH_NL(OP(p)) || reglnum > rex.reg_maxline
            || rex.reg_line_lbr) {
          break;
        }
        reg_nextline();
        scan = reginput;
        if (got_int) {
          break;
        }
      } else if (vim_isprintc(PTR2CHAR(scan)) == 1
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
        if (!REG_MULTI || !WITH_NL(OP(p)) || reglnum > rex.reg_maxline
            || rex.reg_line_lbr) {
          break;
        }
        reg_nextline();
        scan = reginput;
        if (got_int)
          break;
      } else if (has_mbyte && (l = (*mb_ptr2len)(scan)) > 1) {
        if (testval != 0)
          break;
        scan += l;
      } else if ((class_tab[*scan] & mask) == testval) {
        scan++;
      } else if (rex.reg_line_lbr && *scan == '\n' && WITH_NL(OP(p))) {
        scan++;
      } else {
        break;
      }
      ++count;
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

  case EXACTLY:
  {
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

  case MULTIBYTECODE:
  {
    int i, len, cf = 0;

    /* Safety check (just in case 'encoding' was changed since
     * compiling the program). */
    if ((len = (*mb_ptr2len)(opnd)) > 1) {
      if (rex.reg_ic && enc_utf8) {
        cf = utf_fold(utf_ptr2char(opnd));
      }
      while (count < maxcount && (*mb_ptr2len)(scan) >= len) {
        for (i = 0; i < len; ++i) {
          if (opnd[i] != scan[i]) {
            break;
          }
        }
        if (i < len && (!rex.reg_ic || !enc_utf8
                        || utf_fold(utf_ptr2char(scan)) != cf)) {
          break;
        }
        scan += len;
        ++count;
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
        if (!REG_MULTI || !WITH_NL(OP(p)) || reglnum > rex.reg_maxline
            || rex.reg_line_lbr) {
          break;
        }
        reg_nextline();
        scan = reginput;
        if (got_int) {
          break;
        }
      } else if (rex.reg_line_lbr && *scan == '\n' && WITH_NL(OP(p))) {
        scan++;
      } else if ((len = utfc_ptr2len(scan)) > 1) {
        if ((cstrchr(opnd, utf_ptr2char(scan)) == NULL) == testval) {
          break;
        }
        scan += len;
      } else {
        if ((cstrchr(opnd, *scan) == NULL) == testval)
          break;
        ++scan;
      }
      ++count;
    }
    break;

  case NEWL:
    while (count < maxcount
           && ((*scan == NUL && reglnum <= rex.reg_maxline && !rex.reg_line_lbr
                && REG_MULTI) || (*scan == '\n' && rex.reg_line_lbr))) {
      count++;
      if (rex.reg_line_lbr) {
        ADVANCE_REGINPUT();
      } else {
        reg_nextline();
      }
      scan = reginput;
      if (got_int)
        break;
    }
    break;

  default:                      /* Oh dear.  Called inappropriately. */
    EMSG(_(e_re_corr));
#ifdef REGEXP_DEBUG
    printf("Called regrepeat with op code %d\n", OP(p));
#endif
    break;
  }

  reginput = scan;

  return (int)count;
}

/*
 * regnext - dig the "next" pointer out of a node
 * Returns NULL when calculating size, when there is no next item and when
 * there is an error.
 */
static char_u *regnext(char_u *p)
{
  int offset;

  if (p == JUST_CALC_SIZE || reg_toolong)
    return NULL;

  offset = NEXT(p);
  if (offset == 0)
    return NULL;

  if (OP(p) == BACK)
    return p - offset;
  else
    return p + offset;
}

/*
 * Check the regexp program for its magic number.
 * Return TRUE if it's wrong.
 */
static int prog_magic_wrong(void)
{
  regprog_T   *prog;

  prog = REG_MULTI ? rex.reg_mmatch->regprog : rex.reg_match->regprog;
  if (prog->engine == &nfa_regengine) {
    // For NFA matcher we don't check the magic
    return false;
  }

  if (UCHARAT(((bt_regprog_T *)prog)->program) != REGMAGIC) {
    EMSG(_(e_re_corr));
    return TRUE;
  }
  return FALSE;
}

/*
 * Cleanup the subexpressions, if this wasn't done yet.
 * This construction is used to clear the subexpressions only when they are
 * used (to increase speed).
 */
static void cleanup_subexpr(void)
{
  if (need_clear_subexpr) {
    if (REG_MULTI) {
      // Use 0xff to set lnum to -1
      memset(rex.reg_startpos, 0xff, sizeof(lpos_T) * NSUBEXP);
      memset(rex.reg_endpos, 0xff, sizeof(lpos_T) * NSUBEXP);
    } else {
      memset(rex.reg_startp, 0, sizeof(char_u *) * NSUBEXP);
      memset(rex.reg_endp, 0, sizeof(char_u *) * NSUBEXP);
    }
    need_clear_subexpr = FALSE;
  }
}

static void cleanup_zsubexpr(void)
{
  if (need_clear_zsubexpr) {
    if (REG_MULTI) {
      /* Use 0xff to set lnum to -1 */
      memset(reg_startzpos, 0xff, sizeof(lpos_T) * NSUBEXP);
      memset(reg_endzpos, 0xff, sizeof(lpos_T) * NSUBEXP);
    } else {
      memset(reg_startzp, 0, sizeof(char_u *) * NSUBEXP);
      memset(reg_endzp, 0, sizeof(char_u *) * NSUBEXP);
    }
    need_clear_zsubexpr = FALSE;
  }
}

/*
 * Save the current subexpr to "bp", so that they can be restored
 * later by restore_subexpr().
 */
static void save_subexpr(regbehind_T *bp)
{
  int i;

  // When "need_clear_subexpr" is set we don't need to save the values, only
  // remember that this flag needs to be set again when restoring.
  bp->save_need_clear_subexpr = need_clear_subexpr;
  if (!need_clear_subexpr) {
    for (i = 0; i < NSUBEXP; ++i) {
      if (REG_MULTI) {
        bp->save_start[i].se_u.pos = rex.reg_startpos[i];
        bp->save_end[i].se_u.pos = rex.reg_endpos[i];
      } else {
        bp->save_start[i].se_u.ptr = rex.reg_startp[i];
        bp->save_end[i].se_u.ptr = rex.reg_endp[i];
      }
    }
  }
}

/*
 * Restore the subexpr from "bp".
 */
static void restore_subexpr(regbehind_T *bp)
{
  int i;

  /* Only need to restore saved values when they are not to be cleared. */
  need_clear_subexpr = bp->save_need_clear_subexpr;
  if (!need_clear_subexpr) {
    for (i = 0; i < NSUBEXP; ++i) {
      if (REG_MULTI) {
        rex.reg_startpos[i] = bp->save_start[i].se_u.pos;
        rex.reg_endpos[i] = bp->save_end[i].se_u.pos;
      } else {
        rex.reg_startp[i] = bp->save_start[i].se_u.ptr;
        rex.reg_endp[i] = bp->save_end[i].se_u.ptr;
      }
    }
  }
}

/*
 * Advance reglnum, regline and reginput to the next line.
 */
static void reg_nextline(void)
{
  regline = reg_getline(++reglnum);
  reginput = regline;
  fast_breakcheck();
}

/*
 * Save the input line and position in a regsave_T.
 */
static void reg_save(regsave_T *save, garray_T *gap)
{
  if (REG_MULTI) {
    save->rs_u.pos.col = (colnr_T)(reginput - regline);
    save->rs_u.pos.lnum = reglnum;
  } else
    save->rs_u.ptr = reginput;
  save->rs_len = gap->ga_len;
}

/*
 * Restore the input line and position from a regsave_T.
 */
static void reg_restore(regsave_T *save, garray_T *gap)
{
  if (REG_MULTI) {
    if (reglnum != save->rs_u.pos.lnum) {
      /* only call reg_getline() when the line number changed to save
       * a bit of time */
      reglnum = save->rs_u.pos.lnum;
      regline = reg_getline(reglnum);
    }
    reginput = regline + save->rs_u.pos.col;
  } else
    reginput = save->rs_u.ptr;
  gap->ga_len = save->rs_len;
}

/*
 * Return TRUE if current position is equal to saved position.
 */
static int reg_save_equal(regsave_T *save)
{
  if (REG_MULTI)
    return reglnum == save->rs_u.pos.lnum
           && reginput == regline + save->rs_u.pos.col;
  return reginput == save->rs_u.ptr;
}

/*
 * Tentatively set the sub-expression start to the current position (after
 * calling regmatch() they will have changed).  Need to save the existing
 * values for when there is no match.
 * Use se_save() to use pointer (save_se_multi()) or position (save_se_one()),
 * depending on REG_MULTI.
 */
static void save_se_multi(save_se_T *savep, lpos_T *posp)
{
  savep->se_u.pos = *posp;
  posp->lnum = reglnum;
  posp->col = (colnr_T)(reginput - regline);
}

static void save_se_one(save_se_T *savep, char_u **pp)
{
  savep->se_u.ptr = *pp;
  *pp = reginput;
}

/*
 * Compare a number with the operand of RE_LNUM, RE_COL or RE_VCOL.
 */
static int re_num_cmp(uint32_t val, char_u *scan)
{
  uint32_t n = (uint32_t)OPERAND_MIN(scan);

  if (OPERAND_CMP(scan) == '>')
    return val > n;
  if (OPERAND_CMP(scan) == '<')
    return val < n;
  return val == n;
}

/*
 * Check whether a backreference matches.
 * Returns RA_FAIL, RA_NOMATCH or RA_MATCH.
 * If "bytelen" is not NULL, it is set to the byte length of the match in the
 * last line.
 */
static int match_with_backref(linenr_T start_lnum, colnr_T start_col, linenr_T end_lnum, colnr_T end_col, int *bytelen)
{
  linenr_T clnum = start_lnum;
  colnr_T ccol = start_col;
  int len;
  char_u      *p;

  if (bytelen != NULL)
    *bytelen = 0;
  for (;; ) {
    /* Since getting one line may invalidate the other, need to make copy.
     * Slow! */
    if (regline != reg_tofree) {
      len = (int)STRLEN(regline);
      if (reg_tofree == NULL || len >= (int)reg_tofreelen) {
        len += 50;              /* get some extra */
        xfree(reg_tofree);
        reg_tofree = xmalloc(len);
        reg_tofreelen = len;
      }
      STRCPY(reg_tofree, regline);
      reginput = reg_tofree + (reginput - regline);
      regline = reg_tofree;
    }

    /* Get the line to compare with. */
    p = reg_getline(clnum);
    assert(p);

    if (clnum == end_lnum)
      len = end_col - ccol;
    else
      len = (int)STRLEN(p + ccol);

    if (cstrncmp(p + ccol, reginput, &len) != 0)
      return RA_NOMATCH;        /* doesn't match */
    if (bytelen != NULL)
      *bytelen += len;
    if (clnum == end_lnum) {
      break;  // match and at end!
    }
    if (reglnum >= rex.reg_maxline) {
      return RA_NOMATCH;  // text too short
    }

    /* Advance to next line. */
    reg_nextline();
    if (bytelen != NULL)
      *bytelen = 0;
    ++clnum;
    ccol = 0;
    if (got_int)
      return RA_FAIL;
  }

  /* found a match!  Note that regline may now point to a copy of the line,
   * that should not matter. */
  return RA_MATCH;
}

#ifdef BT_REGEXP_DUMP

/*
 * regdump - dump a regexp onto stdout in vaguely comprehensible form
 */
static void regdump(char_u *pattern, bt_regprog_T *r)
{
  char_u  *s;
  int op = EXACTLY;             /* Arbitrary non-END op. */
  char_u  *next;
  char_u  *end = NULL;
  FILE    *f;

#ifdef BT_REGEXP_LOG
  f = fopen("bt_regexp_log.log", "a");
#else
  f = stdout;
#endif
  if (f == NULL)
    return;
  fprintf(f, "-------------------------------------\n\r\nregcomp(%s):\r\n",
      pattern);

  s = r->program + 1;
  /*
   * Loop until we find the END that isn't before a referred next (an END
   * can also appear in a NOMATCH operand).
   */
  while (op != END || s <= end) {
    op = OP(s);
    fprintf(f, "%2d%s", (int)(s - r->program), regprop(s));     /* Where, what. */
    next = regnext(s);
    if (next == NULL)           /* Next ptr. */
      fprintf(f, "(0)");
    else
      fprintf(f, "(%d)", (int)((s - r->program) + (next - s)));
    if (end < next)
      end = next;
    if (op == BRACE_LIMITS) {
      /* Two ints */
      fprintf(f, " minval %" PRId64 ", maxval %" PRId64,
              (int64_t)OPERAND_MIN(s), (int64_t)OPERAND_MAX(s));
      s += 8;
    } else if (op == BEHIND || op == NOBEHIND) {
      /* one int */
      fprintf(f, " count %" PRId64, (int64_t)OPERAND_MIN(s));
      s += 4;
    } else if (op == RE_LNUM || op == RE_COL || op == RE_VCOL) {
      /* one int plus comperator */
      fprintf(f, " count %" PRId64, (int64_t)OPERAND_MIN(s));
      s += 5;
    }
    s += 3;
    if (op == ANYOF || op == ANYOF + ADD_NL
        || op == ANYBUT || op == ANYBUT + ADD_NL
        || op == EXACTLY) {
      /* Literal string, where present. */
      fprintf(f, "\nxxxxxxxxx\n");
      while (*s != NUL)
        fprintf(f, "%c", *s++);
      fprintf(f, "\nxxxxxxxxx\n");
      s++;
    }
    fprintf(f, "\r\n");
  }

  /* Header fields of interest. */
  if (r->regstart != NUL)
    fprintf(f, "start `%s' 0x%x; ", r->regstart < 256
        ? (char *)transchar(r->regstart)
        : "multibyte", r->regstart);
  if (r->reganch)
    fprintf(f, "anchored; ");
  if (r->regmust != NULL)
    fprintf(f, "must have \"%s\"", r->regmust);
  fprintf(f, "\r\n");

#ifdef BT_REGEXP_LOG
  fclose(f);
#endif
}
#endif      /* BT_REGEXP_DUMP */

#ifdef REGEXP_DEBUG
/*
 * regprop - printable representation of opcode
 */
static char_u *regprop(char_u *op)
{
  char            *p;
  static char buf[50];

  STRCPY(buf, ":");

  switch ((int) OP(op)) {
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
    sprintf(buf + STRLEN(buf), "MOPEN%d", OP(op) - MOPEN);
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
    sprintf(buf + STRLEN(buf), "MCLOSE%d", OP(op) - MCLOSE);
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
    sprintf(buf + STRLEN(buf), "BACKREF%d", OP(op) - BACKREF);
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
    sprintf(buf + STRLEN(buf), "ZOPEN%d", OP(op) - ZOPEN);
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
    sprintf(buf + STRLEN(buf), "ZCLOSE%d", OP(op) - ZCLOSE);
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
    sprintf(buf + STRLEN(buf), "ZREF%d", OP(op) - ZREF);
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
    sprintf(buf + STRLEN(buf), "BRACE_COMPLEX%d", OP(op) - BRACE_COMPLEX);
    p = NULL;
    break;
  case MULTIBYTECODE:
    p = "MULTIBYTECODE";
    break;
  case NEWL:
    p = "NEWL";
    break;
  default:
    sprintf(buf + STRLEN(buf), "corrupt %d", OP(op));
    p = NULL;
    break;
  }
  if (p != NULL)
    STRCAT(buf, p);
  return (char_u *)buf;
}
#endif      /* REGEXP_DEBUG */



/* 0xfb20 - 0xfb4f */
static decomp_T decomp_table[0xfb4f-0xfb20+1] =
{
  {0x5e2,0,0},                  /* 0xfb20	alt ayin */
  {0x5d0,0,0},                  /* 0xfb21	alt alef */
  {0x5d3,0,0},                  /* 0xfb22	alt dalet */
  {0x5d4,0,0},                  /* 0xfb23	alt he */
  {0x5db,0,0},                  /* 0xfb24	alt kaf */
  {0x5dc,0,0},                  /* 0xfb25	alt lamed */
  {0x5dd,0,0},                  /* 0xfb26	alt mem-sofit */
  {0x5e8,0,0},                  /* 0xfb27	alt resh */
  {0x5ea,0,0},                  /* 0xfb28	alt tav */
  {'+', 0, 0},                  /* 0xfb29	alt plus */
  {0x5e9, 0x5c1, 0},            /* 0xfb2a	shin+shin-dot */
  {0x5e9, 0x5c2, 0},            /* 0xfb2b	shin+sin-dot */
  {0x5e9, 0x5c1, 0x5bc},        /* 0xfb2c	shin+shin-dot+dagesh */
  {0x5e9, 0x5c2, 0x5bc},        /* 0xfb2d	shin+sin-dot+dagesh */
  {0x5d0, 0x5b7, 0},            /* 0xfb2e	alef+patah */
  {0x5d0, 0x5b8, 0},            /* 0xfb2f	alef+qamats */
  {0x5d0, 0x5b4, 0},            /* 0xfb30	alef+hiriq */
  {0x5d1, 0x5bc, 0},            /* 0xfb31	bet+dagesh */
  {0x5d2, 0x5bc, 0},            /* 0xfb32	gimel+dagesh */
  {0x5d3, 0x5bc, 0},            /* 0xfb33	dalet+dagesh */
  {0x5d4, 0x5bc, 0},            /* 0xfb34	he+dagesh */
  {0x5d5, 0x5bc, 0},            /* 0xfb35	vav+dagesh */
  {0x5d6, 0x5bc, 0},            /* 0xfb36	zayin+dagesh */
  {0xfb37, 0, 0},               /* 0xfb37 -- */
  {0x5d8, 0x5bc, 0},            /* 0xfb38	tet+dagesh */
  {0x5d9, 0x5bc, 0},            /* 0xfb39	yud+dagesh */
  {0x5da, 0x5bc, 0},            /* 0xfb3a	kaf sofit+dagesh */
  {0x5db, 0x5bc, 0},            /* 0xfb3b	kaf+dagesh */
  {0x5dc, 0x5bc, 0},            /* 0xfb3c	lamed+dagesh */
  {0xfb3d, 0, 0},               /* 0xfb3d -- */
  {0x5de, 0x5bc, 0},            /* 0xfb3e	mem+dagesh */
  {0xfb3f, 0, 0},               /* 0xfb3f -- */
  {0x5e0, 0x5bc, 0},            /* 0xfb40	nun+dagesh */
  {0x5e1, 0x5bc, 0},            /* 0xfb41	samech+dagesh */
  {0xfb42, 0, 0},               /* 0xfb42 -- */
  {0x5e3, 0x5bc, 0},            /* 0xfb43	pe sofit+dagesh */
  {0x5e4, 0x5bc,0},             /* 0xfb44	pe+dagesh */
  {0xfb45, 0, 0},               /* 0xfb45 -- */
  {0x5e6, 0x5bc, 0},            /* 0xfb46	tsadi+dagesh */
  {0x5e7, 0x5bc, 0},            /* 0xfb47	qof+dagesh */
  {0x5e8, 0x5bc, 0},            /* 0xfb48	resh+dagesh */
  {0x5e9, 0x5bc, 0},            /* 0xfb49	shin+dagesh */
  {0x5ea, 0x5bc, 0},            /* 0xfb4a	tav+dagesh */
  {0x5d5, 0x5b9, 0},            /* 0xfb4b	vav+holam */
  {0x5d1, 0x5bf, 0},            /* 0xfb4c	bet+rafe */
  {0x5db, 0x5bf, 0},            /* 0xfb4d	kaf+rafe */
  {0x5e4, 0x5bf, 0},            /* 0xfb4e	pe+rafe */
  {0x5d0, 0x5dc, 0}             /* 0xfb4f	alef-lamed */
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
  if (result != 0 && enc_utf8 && rex.reg_icombine) {
    char_u  *str1, *str2;
    int c1, c2, c11, c12;
    int junk;

    /* we have to handle the strcmp ourselves, since it is necessary to
     * deal with the composing characters by ignoring them: */
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
    if (result == 0)
      *n = (int)(str2 - s2);
  }

  return result;
}

/***************************************************************
*		      regsub stuff			       *
***************************************************************/

/* This stuff below really confuses cc on an SGI -- webb */



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
char_u *regtilde(char_u *source, int magic)
{
  char_u      *newsub = source;
  char_u      *tmpsub;
  char_u      *p;
  int len;
  int prevlen;

  for (p = newsub; *p; ++p) {
    if ((*p == '~' && magic) || (*p == '\\' && *(p + 1) == '~' && !magic)) {
      if (reg_prev_sub != NULL) {
        /* length = len(newsub) - 1 + len(prev_sub) + 1 */
        prevlen = (int)STRLEN(reg_prev_sub);
        tmpsub = xmalloc(STRLEN(newsub) + prevlen);
        /* copy prefix */
        len = (int)(p - newsub);              /* not including ~ */
        memmove(tmpsub, newsub, (size_t)len);
        /* interpret tilde */
        memmove(tmpsub + len, reg_prev_sub, (size_t)prevlen);
        /* copy postfix */
        if (!magic)
          ++p;                                /* back off \ */
        STRCPY(tmpsub + len + prevlen, p + 1);

        if (newsub != source)                 /* already allocated newsub */
          xfree(newsub);
        newsub = tmpsub;
        p = newsub + len + prevlen;
      } else if (magic)
        STRMOVE(p, p + 1);              /* remove '~' */
      else
        STRMOVE(p, p + 2);              /* remove '\~' */
      --p;
    } else {
      if (*p == '\\' && p[1])                   /* skip escaped characters */
        ++p;
      if (has_mbyte)
        p += (*mb_ptr2len)(p) - 1;
    }
  }

  xfree(reg_prev_sub);
  if (newsub != source)         /* newsub was allocated, just keep it */
    reg_prev_sub = newsub;
  else                          /* no ~ found, need to save newsub  */
    reg_prev_sub = vim_strsave(newsub);
  return newsub;
}

static int can_f_submatch = FALSE;      /* TRUE when submatch() can be used */

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

/// Put the submatches in "argv[0]" which is a list passed into call_func() by
/// vim_regsub_both().
static int fill_submatch_list(int argc, typval_T *argv, int argcount)
{
  if (argcount == 0) {
    // called function doesn't take an argument
    return 0;
  }

  // Relies on sl_list to be the first item in staticList10_T.
  tv_list_init_static10((staticList10_T *)argv->vval.v_list);

  // There are always 10 list items in staticList10_T.
  listitem_T *li = tv_list_first(argv->vval.v_list);
  for (int i = 0; i < 10; i++) {
    char_u *s = rsm.sm_match->startp[i];
    if (s == NULL || rsm.sm_match->endp[i] == NULL) {
      s = NULL;
    } else {
      s = vim_strnsave(s, (int)(rsm.sm_match->endp[i] - s));
    }
    TV_LIST_ITEM_TV(li)->v_type = VAR_STRING;
    TV_LIST_ITEM_TV(li)->vval.v_string = s;
    li = TV_LIST_ITEM_NEXT(argv->vval.v_list, li);
  }
  return 1;
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
/// If "copy" is TRUE really copy into "dest".
/// If "copy" is FALSE nothing is copied, this is just to find out the length
/// of the result.
///
/// If "backslash" is TRUE, a backslash will be removed later, need to double
/// them to keep them, and insert a backslash before a CR to avoid it being
/// replaced with a line break later.
///
/// Note: The matched text must not change between the call of
/// vim_regexec()/vim_regexec_multi() and vim_regsub()!  It would make the back
/// references invalid!
///
/// Returns the size of the replacement, including terminating NUL.
int vim_regsub(regmatch_T *rmp, char_u *source, typval_T *expr, char_u *dest,
               int copy, int magic, int backslash)
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

int vim_regsub_multi(regmmatch_T *rmp, linenr_T lnum, char_u *source, char_u *dest, int copy, int magic, int backslash)
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

static int vim_regsub_both(char_u *source, typval_T *expr, char_u *dest,
                           int copy, int magic, int backslash)
{
  char_u      *src;
  char_u      *dst;
  char_u      *s;
  int c;
  int cc;
  int no = -1;
  fptr_T func_all = (fptr_T)NULL;
  fptr_T func_one = (fptr_T)NULL;
  linenr_T clnum = 0;           /* init for GCC */
  int len = 0;                  /* init for GCC */
  static char_u *eval_result = NULL;

  // Be paranoid...
  if ((source == NULL && expr == NULL) || dest == NULL) {
    EMSG(_(e_null));
    return 0;
  }
  if (prog_magic_wrong())
    return 0;
  src = source;
  dst = dest;

  // When the substitute part starts with "\=" evaluate it as an expression.
  if (expr != NULL || (source[0] == '\\' && source[1] == '=')) {
    // To make sure that the length doesn't change between checking the
    // length and copying the string, and to speed up things, the
    // resulting string is saved from the call with "copy" == FALSE to the
    // call with "copy" == TRUE.
    if (copy) {
      if (eval_result != NULL) {
        STRCPY(dest, eval_result);
        dst += STRLEN(eval_result);
        xfree(eval_result);
        eval_result = NULL;
      }
    } else {
      int prev_can_f_submatch = can_f_submatch;
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
        int dummy;
        typval_T rettv;
        staticList10_T matchList = TV_LIST_STATIC10_INIT;

        rettv.v_type = VAR_STRING;
        rettv.vval.v_string = NULL;
        argv[0].v_type = VAR_LIST;
        argv[0].vval.v_list = &matchList.sl_list;
        if (expr->v_type == VAR_FUNC) {
          s = expr->vval.v_string;
          call_func(s, (int)STRLEN(s), &rettv, 1, argv,
                    fill_submatch_list, 0L, 0L, &dummy,
                    true, NULL, NULL);
        } else if (expr->v_type == VAR_PARTIAL) {
          partial_T *partial = expr->vval.v_partial;

          s = partial_name(partial);
          call_func(s, (int)STRLEN(s), &rettv, 1, argv,
                    fill_submatch_list, 0L, 0L, &dummy,
                    true, partial, NULL);
        }
        if (tv_list_len(&matchList.sl_list) > 0) {
          // fill_submatch_list() was called.
          clear_submatch_list(&matchList);
        }
        char buf[NUMBUFLEN];
        eval_result = (char_u *)tv_get_string_buf_chk(&rettv, buf);
        if (eval_result != NULL) {
          eval_result = vim_strsave(eval_result);
        }
        tv_clear(&rettv);
      } else {
        eval_result = eval_to_string(source + 2, NULL, true);
      }

      if (eval_result != NULL) {
        int had_backslash = FALSE;

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
          /* Backslashes will be consumed, need to double them. */
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
  } else
    while ((c = *src++) != NUL) {
      if (c == '&' && magic)
        no = 0;
      else if (c == '\\' && *src != NUL) {
        if (*src == '&' && !magic) {
          ++src;
          no = 0;
        } else if ('0' <= *src && *src <= '9') {
          no = *src++ - '0';
        } else if (vim_strchr((char_u *)"uUlLeE", *src)) {
          switch (*src++) {
          case 'u':   func_one = (fptr_T)do_upper;
            continue;
          case 'U':   func_all = (fptr_T)do_Upper;
            continue;
          case 'l':   func_one = (fptr_T)do_lower;
            continue;
          case 'L':   func_all = (fptr_T)do_Lower;
            continue;
          case 'e':
          case 'E':   func_one = func_all = (fptr_T)NULL;
            continue;
          }
        }
      }
      if (no < 0) {           /* Ordinary character. */
        if (c == K_SPECIAL && src[0] != NUL && src[1] != NUL) {
          /* Copy a special key as-is. */
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
          /* Check for abbreviations -- webb */
          switch (*src) {
          case 'r':   c = CAR;        ++src;  break;
          case 'n':   c = NL;         ++src;  break;
          case 't':   c = TAB;        ++src;  break;
          /* Oh no!  \e already has meaning in subst pat :-( */
          /* case 'e':   c = ESC;	++src;	break; */
          case 'b':   c = Ctrl_H;     ++src;  break;

          /* If "backslash" is TRUE the backslash will be removed
           * later.  Used to insert a literal CR. */
          default:    if (backslash) {
              if (copy)
                *dst = '\\';
              ++dst;
          }
            c = *src++;
          }
        } else {
          c = utf_ptr2char(src - 1);
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

        int totlen = utfc_ptr2len(src - 1);

        if (copy) {
          utf_char2bytes(cc, dst);
        }
        dst += utf_char2len(cc) - 1;
        int clen = utf_ptr2len(src - 1);

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
          for (;; ) {
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
                EMSG(_(e_re_damg));
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
                c = utf_ptr2char(s);

                if (func_one != (fptr_T)NULL)
                  /* Turbo C complains without the typecast */
                  func_one = (fptr_T)(func_one(&cc, c));
                else if (func_all != (fptr_T)NULL)
                  /* Turbo C complains without the typecast */
                  func_all = (fptr_T)(func_all(&cc, c));
                else             /* just copy */
                  cc = c;

                if (has_mbyte) {
                  int l;

                  // Copy composing characters separately, one
                  // at a time.
                  l = utf_ptr2len(s) - 1;

                  s += l;
                  len -= l;
                  if (copy) {
                    utf_char2bytes(cc, dst);
                  }
                  dst += utf_char2len(cc) - 1;
                } else if (copy) {
                  *dst = cc;
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
  if (copy)
    *dst = NUL;

exit:
  return (int)((dst - dest) + 1);
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
  char_u      *retval = NULL;
  char_u      *s;
  int round;
  linenr_T lnum;

  if (!can_f_submatch || no < 0)
    return NULL;

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

      s = reg_getline_submatch(lnum) + rsm.sm_mmatch->startpos[no].col;
      if (s == NULL) {  // anti-crash check, cannot happen?
        break;
      }
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
          if (round == 2)
            STRCPY(retval + len, s);
          len += STRLEN(s);
          if (round == 2)
            retval[len] = '\n';
          ++len;
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
      retval = vim_strnsave(s, (int)(rsm.sm_match->endp[no] - s));
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

  return list;
}

static regengine_T bt_regengine =
{
  bt_regcomp,
  bt_regfree,
  bt_regexec_nl,
  bt_regexec_multi,
  (char_u *)""
};


// XXX Do not allow headers generator to catch definitions from regexp_nfa.c
#ifndef DO_NOT_DEFINE_EMPTY_ATTRIBUTES
# include "nvim/regexp_nfa.c"
#endif

static regengine_T nfa_regengine =
{
  nfa_regcomp,
  nfa_regfree,
  nfa_regexec_nl,
  nfa_regexec_multi,
  (char_u *)""
};

/* Which regexp engine to use? Needed for vim_regcomp().
 * Must match with 'regexpengine'. */
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
regprog_T *vim_regcomp(char_u *expr_arg, int re_flags)
{
  regprog_T   *prog = NULL;
  char_u      *expr = expr_arg;
  int          save_called_emsg;

  regexp_engine = p_re;

  /* Check for prefix "\%#=", that sets the regexp engine */
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
      EMSG(_(
              "E864: \\%#= can only be followed by 0, 1, or 2. The automatic engine will be used "));
      regexp_engine = AUTOMATIC_ENGINE;
    }
  }
  bt_regengine.expr = expr;
  nfa_regengine.expr = expr;
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
    // Debugging log for NFA.
    if (regexp_engine != BACKTRACKING_ENGINE) {
      FILE *f = fopen(BT_REGEXP_DEBUG_LOG_NAME, "a");
      if (f) {
        fprintf(f, "Syntax error in \"%s\"\n", expr);
        fclose(f);
      } else
        EMSG2("(NFA) Could not open \"%s\" to write !!!",
            BT_REGEXP_DEBUG_LOG_NAME);
    }
#endif
    // If the NFA engine failed, try the backtracking engine. The NFA engine
    // also fails for patterns that it can't handle well but are still valid
    // patterns, thus a retry should work.
    // But don't try if an error message was given.
    if (regexp_engine == AUTOMATIC_ENGINE && !called_emsg) {
      regexp_engine = BACKTRACKING_ENGINE;
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
  if (prog != NULL)
    prog->engine->regfree(prog);
}

static void report_re_switch(char_u *pat)
{
  if (p_verbose > 0) {
    verbose_enter();
    MSG_PUTS(_("Switching to backtracking RE engine for pattern: "));
    MSG_PUTS(pat);
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
/// @return TRUE if there is a match, FALSE if not.
static int vim_regexec_both(regmatch_T *rmp, char_u *line, colnr_T col, bool nl)
{
  regexec_T rex_save;
  bool rex_in_use_save = rex_in_use;

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

  // NFA engine aborted because it's very slow, use backtracking engine instead.
  if (rmp->regprog->re_engine == AUTOMATIC_ENGINE
      && result == NFA_TOO_EXPENSIVE) {
    int save_p_re = p_re;
    int re_flags = rmp->regprog->re_flags;
    char_u *pat = vim_strsave(((nfa_regprog_T *)rmp->regprog)->pattern);

    p_re = BACKTRACKING_ENGINE;
    vim_regfree(rmp->regprog);
    report_re_switch(pat);
    rmp->regprog = vim_regcomp(pat, re_flags);
    if (rmp->regprog != NULL) {
      result = rmp->regprog->engine->regexec_nl(rmp, line, col, nl);
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
// Return TRUE if there is a match, FALSE if not.
int vim_regexec_prog(regprog_T **prog, bool ignore_case, char_u *line,
                      colnr_T col)
{
  regmatch_T regmatch = {.regprog = *prog, .rm_ic = ignore_case};
  int r = vim_regexec_both(&regmatch, line, col, false);
  *prog = regmatch.regprog;
  return r;
}

// Note: "rmp->regprog" may be freed and changed.
// Return TRUE if there is a match, FALSE if not.
int vim_regexec(regmatch_T *rmp, char_u *line, colnr_T col)
{
  return vim_regexec_both(rmp, line, col, false);
}

// Like vim_regexec(), but consider a "\n" in "line" to be a line break.
// Note: "rmp->regprog" may be freed and changed.
// Return TRUE if there is a match, FALSE if not.
int vim_regexec_nl(regmatch_T *rmp, char_u *line, colnr_T col)
{
  return vim_regexec_both(rmp, line, col, true);
}

/// Match a regexp against multiple lines.
/// "rmp->regprog" must be a compiled regexp as returned by vim_regcomp().
/// Note: "rmp->regprog" may be freed and changed, even set to NULL.
/// Uses curbuf for line count and 'iskeyword'.
///
/// Return zero if there is no match.  Return number of lines contained in the
/// match otherwise.
long vim_regexec_multi(
    regmmatch_T *rmp,
    win_T       *win,               // window in which to search or NULL
    buf_T       *buf,               // buffer in which to search
    linenr_T lnum,                  // nr of line to start looking for match
    colnr_T col,                    // column to start looking for match
    proftime_T  *tm,                // timeout limit or NULL
    int         *timed_out          // flag is set when timeout limit reached
)
{
  regexec_T rex_save;
  bool rex_in_use_save = rex_in_use;

  if (rex_in_use) {
    // Being called recursively, save the state.
    rex_save = rex;
  }
  rex_in_use = true;

  int result = rmp->regprog->engine->regexec_multi(rmp, win, buf, lnum, col,
                                                   tm, timed_out);

  // NFA engine aborted because it's very slow, use backtracking engine instead.
  if (rmp->regprog->re_engine == AUTOMATIC_ENGINE
      && result == NFA_TOO_EXPENSIVE) {
    int save_p_re = p_re;
    int re_flags = rmp->regprog->re_flags;
    char_u *pat = vim_strsave(((nfa_regprog_T *)rmp->regprog)->pattern);

    p_re = BACKTRACKING_ENGINE;
    vim_regfree(rmp->regprog);
    report_re_switch(pat);
    // checking for \z misuse was already done when compiling for NFA,
    // allow all here
    reg_do_extmatch = REX_ALL;
    rmp->regprog = vim_regcomp(pat, re_flags);
    reg_do_extmatch = 0;

    if (rmp->regprog != NULL) {
      result = rmp->regprog->engine->regexec_multi(rmp, win, buf, lnum, col,
                                                   tm, timed_out);
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
