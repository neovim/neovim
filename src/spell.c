/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * spell.c: code for spell checking
 *
 * The spell checking mechanism uses a tree (aka trie).  Each node in the tree
 * has a list of bytes that can appear (siblings).  For each byte there is a
 * pointer to the node with the byte that follows in the word (child).
 *
 * A NUL byte is used where the word may end.  The bytes are sorted, so that
 * binary searching can be used and the NUL bytes are at the start.  The
 * number of possible bytes is stored before the list of bytes.
 *
 * The tree uses two arrays: "byts" stores the characters, "idxs" stores
 * either the next index or flags.  The tree starts at index 0.  For example,
 * to lookup "vi" this sequence is followed:
 *	i = 0
 *	len = byts[i]
 *	n = where "v" appears in byts[i + 1] to byts[i + len]
 *	i = idxs[n]
 *	len = byts[i]
 *	n = where "i" appears in byts[i + 1] to byts[i + len]
 *	i = idxs[n]
 *	len = byts[i]
 *	find that byts[i + 1] is 0, idxs[i + 1] has flags for "vi".
 *
 * There are two word trees: one with case-folded words and one with words in
 * original case.  The second one is only used for keep-case words and is
 * usually small.
 *
 * There is one additional tree for when not all prefixes are applied when
 * generating the .spl file.  This tree stores all the possible prefixes, as
 * if they were words.  At each word (prefix) end the prefix nr is stored, the
 * following word must support this prefix nr.  And the condition nr is
 * stored, used to lookup the condition that the word must match with.
 *
 * Thanks to Olaf Seibert for providing an example implementation of this tree
 * and the compression mechanism.
 * LZ trie ideas:
 *	http://www.irb.hr/hr/home/ristov/papers/RistovLZtrieRevision1.pdf
 * More papers: http://www-igm.univ-mlv.fr/~laporte/publi_en.html
 *
 * Matching involves checking the caps type: Onecap ALLCAP KeepCap.
 *
 * Why doesn't Vim use aspell/ispell/myspell/etc.?
 * See ":help develop-spell".
 */

/* Use SPELL_PRINTTREE for debugging: dump the word tree after adding a word.
 * Only use it for small word lists! */

/* Use DEBUG_TRIEWALK to print the changes made in suggest_trie_walk() for a
 * specific word. */

/*
 * Use this to adjust the score after finding suggestions, based on the
 * suggested word sounding like the bad word.  This is much faster than doing
 * it for every possible suggestion.
 * Disadvantage: When "the" is typed as "hte" it sounds quite different ("@"
 * vs "ht") and goes down in the list.
 * Used when 'spellsuggest' is set to "best".
 */
#define RESCORE(word_score, sound_score) ((3 * word_score + sound_score) / 4)

/*
 * Do the opposite: based on a maximum end score and a known sound score,
 * compute the maximum word score that can be used.
 */
#define MAXSCORE(word_score, sound_score) ((4 * word_score - sound_score) / 3)

/*
 * Vim spell file format: <HEADER>
 *			  <SECTIONS>
 *			  <LWORDTREE>
 *			  <KWORDTREE>
 *			  <PREFIXTREE>
 *
 * <HEADER>: <fileID> <versionnr>
 *
 * <fileID>     8 bytes    "VIMspell"
 * <versionnr>  1 byte	    VIMSPELLVERSION
 *
 *
 * Sections make it possible to add information to the .spl file without
 * making it incompatible with previous versions.  There are two kinds of
 * sections:
 * 1. Not essential for correct spell checking.  E.g. for making suggestions.
 *    These are skipped when not supported.
 * 2. Optional information, but essential for spell checking when present.
 *    E.g. conditions for affixes.  When this section is present but not
 *    supported an error message is given.
 *
 * <SECTIONS>: <section> ... <sectionend>
 *
 * <section>: <sectionID> <sectionflags> <sectionlen> (section contents)
 *
 * <sectionID>	  1 byte    number from 0 to 254 identifying the section
 *
 * <sectionflags> 1 byte    SNF_REQUIRED: this section is required for correct
 *					    spell checking
 *
 * <sectionlen>   4 bytes   length of section contents, MSB first
 *
 * <sectionend>	  1 byte    SN_END
 *
 *
 * sectionID == SN_INFO: <infotext>
 * <infotext>	 N bytes    free format text with spell file info (version,
 *			    website, etc)
 *
 * sectionID == SN_REGION: <regionname> ...
 * <regionname>	 2 bytes    Up to 8 region names: ca, au, etc.  Lower case.
 *			    First <regionname> is region 1.
 *
 * sectionID == SN_CHARFLAGS: <charflagslen> <charflags>
 *				<folcharslen> <folchars>
 * <charflagslen> 1 byte    Number of bytes in <charflags> (should be 128).
 * <charflags>  N bytes     List of flags (first one is for character 128):
 *			    0x01  word character	CF_WORD
 *			    0x02  upper-case character	CF_UPPER
 * <folcharslen>  2 bytes   Number of bytes in <folchars>.
 * <folchars>     N bytes   Folded characters, first one is for character 128.
 *
 * sectionID == SN_MIDWORD: <midword>
 * <midword>     N bytes    Characters that are word characters only when used
 *			    in the middle of a word.
 *
 * sectionID == SN_PREFCOND: <prefcondcnt> <prefcond> ...
 * <prefcondcnt> 2 bytes    Number of <prefcond> items following.
 * <prefcond> : <condlen> <condstr>
 * <condlen>	1 byte	    Length of <condstr>.
 * <condstr>	N bytes	    Condition for the prefix.
 *
 * sectionID == SN_REP: <repcount> <rep> ...
 * <repcount>	 2 bytes    number of <rep> items, MSB first.
 * <rep> : <repfromlen> <repfrom> <reptolen> <repto>
 * <repfromlen>	 1 byte	    length of <repfrom>
 * <repfrom>	 N bytes    "from" part of replacement
 * <reptolen>	 1 byte	    length of <repto>
 * <repto>	 N bytes    "to" part of replacement
 *
 * sectionID == SN_REPSAL: <repcount> <rep> ...
 *   just like SN_REP but for soundfolded words
 *
 * sectionID == SN_SAL: <salflags> <salcount> <sal> ...
 * <salflags>	 1 byte	    flags for soundsalike conversion:
 *			    SAL_F0LLOWUP
 *			    SAL_COLLAPSE
 *			    SAL_REM_ACCENTS
 * <salcount>    2 bytes    number of <sal> items following
 * <sal> : <salfromlen> <salfrom> <saltolen> <salto>
 * <salfromlen>	 1 byte	    length of <salfrom>
 * <salfrom>	 N bytes    "from" part of soundsalike
 * <saltolen>	 1 byte	    length of <salto>
 * <salto>	 N bytes    "to" part of soundsalike
 *
 * sectionID == SN_SOFO: <sofofromlen> <sofofrom> <sofotolen> <sofoto>
 * <sofofromlen> 2 bytes    length of <sofofrom>
 * <sofofrom>	 N bytes    "from" part of soundfold
 * <sofotolen>	 2 bytes    length of <sofoto>
 * <sofoto>	 N bytes    "to" part of soundfold
 *
 * sectionID == SN_SUGFILE: <timestamp>
 * <timestamp>   8 bytes    time in seconds that must match with .sug file
 *
 * sectionID == SN_NOSPLITSUGS: nothing
 *
 * sectionID == SN_WORDS: <word> ...
 * <word>	 N bytes    NUL terminated common word
 *
 * sectionID == SN_MAP: <mapstr>
 * <mapstr>	 N bytes    String with sequences of similar characters,
 *			    separated by slashes.
 *
 * sectionID == SN_COMPOUND: <compmax> <compminlen> <compsylmax> <compoptions>
 *				<comppatcount> <comppattern> ... <compflags>
 * <compmax>     1 byte	    Maximum nr of words in compound word.
 * <compminlen>  1 byte	    Minimal word length for compounding.
 * <compsylmax>  1 byte	    Maximum nr of syllables in compound word.
 * <compoptions> 2 bytes    COMP_ flags.
 * <comppatcount> 2 bytes   number of <comppattern> following
 * <compflags>   N bytes    Flags from COMPOUNDRULE items, separated by
 *			    slashes.
 *
 * <comppattern>: <comppatlen> <comppattext>
 * <comppatlen>	 1 byte	    length of <comppattext>
 * <comppattext> N bytes    end or begin chars from CHECKCOMPOUNDPATTERN
 *
 * sectionID == SN_NOBREAK: (empty, its presence is what matters)
 *
 * sectionID == SN_SYLLABLE: <syllable>
 * <syllable>    N bytes    String from SYLLABLE item.
 *
 * <LWORDTREE>: <wordtree>
 *
 * <KWORDTREE>: <wordtree>
 *
 * <PREFIXTREE>: <wordtree>
 *
 *
 * <wordtree>: <nodecount> <nodedata> ...
 *
 * <nodecount>	4 bytes	    Number of nodes following.  MSB first.
 *
 * <nodedata>: <siblingcount> <sibling> ...
 *
 * <siblingcount> 1 byte    Number of siblings in this node.  The siblings
 *			    follow in sorted order.
 *
 * <sibling>: <byte> [ <nodeidx> <xbyte>
 *		      | <flags> [<flags2>] [<region>] [<affixID>]
 *		      | [<pflags>] <affixID> <prefcondnr> ]
 *
 * <byte>	1 byte	    Byte value of the sibling.  Special cases:
 *			    BY_NOFLAGS: End of word without flags and for all
 *					regions.
 *					For PREFIXTREE <affixID> and
 *					<prefcondnr> follow.
 *			    BY_FLAGS:   End of word, <flags> follow.
 *					For PREFIXTREE <pflags>, <affixID>
 *					and <prefcondnr> follow.
 *			    BY_FLAGS2:  End of word, <flags> and <flags2>
 *					follow.  Not used in PREFIXTREE.
 *			    BY_INDEX:   Child of sibling is shared, <nodeidx>
 *					and <xbyte> follow.
 *
 * <nodeidx>	3 bytes	    Index of child for this sibling, MSB first.
 *
 * <xbyte>	1 byte	    byte value of the sibling.
 *
 * <flags>	1 byte	    bitmask of:
 *			    WF_ALLCAP	word must have only capitals
 *			    WF_ONECAP   first char of word must be capital
 *			    WF_KEEPCAP	keep-case word
 *			    WF_FIXCAP   keep-case word, all caps not allowed
 *			    WF_RARE	rare word
 *			    WF_BANNED	bad word
 *			    WF_REGION	<region> follows
 *			    WF_AFX	<affixID> follows
 *
 * <flags2>	1 byte	    Bitmask of:
 *			    WF_HAS_AFF >> 8   word includes affix
 *			    WF_NEEDCOMP >> 8  word only valid in compound
 *			    WF_NOSUGGEST >> 8  word not used for suggestions
 *			    WF_COMPROOT >> 8  word already a compound
 *			    WF_NOCOMPBEF >> 8 no compounding before this word
 *			    WF_NOCOMPAFT >> 8 no compounding after this word
 *
 * <pflags>	1 byte	    bitmask of:
 *			    WFP_RARE	rare prefix
 *			    WFP_NC	non-combining prefix
 *			    WFP_UP	letter after prefix made upper case
 *
 * <region>	1 byte	    Bitmask for regions in which word is valid.  When
 *			    omitted it's valid in all regions.
 *			    Lowest bit is for region 1.
 *
 * <affixID>	1 byte	    ID of affix that can be used with this word.  In
 *			    PREFIXTREE used for the required prefix ID.
 *
 * <prefcondnr>	2 bytes	    Prefix condition number, index in <prefcond> list
 *			    from HEADER.
 *
 * All text characters are in 'encoding', but stored as single bytes.
 */

/*
 * Vim .sug file format:  <SUGHEADER>
 *			  <SUGWORDTREE>
 *			  <SUGTABLE>
 *
 * <SUGHEADER>: <fileID> <versionnr> <timestamp>
 *
 * <fileID>     6 bytes     "VIMsug"
 * <versionnr>  1 byte      VIMSUGVERSION
 * <timestamp>  8 bytes     timestamp that must match with .spl file
 *
 *
 * <SUGWORDTREE>: <wordtree>  (see above, no flags or region used)
 *
 *
 * <SUGTABLE>: <sugwcount> <sugline> ...
 *
 * <sugwcount>	4 bytes	    number of <sugline> following
 *
 * <sugline>: <sugnr> ... NUL
 *
 * <sugnr>:     X bytes     word number that results in this soundfolded word,
 *			    stored as an offset to the previous number in as
 *			    few bytes as possible, see offset2bytes())
 */

#include "vim.h"
#include "spell.h"
#include "buffer.h"
#include "charset.h"
#include "edit.h"
#include "eval.h"
#include "ex_cmds.h"
#include "ex_cmds2.h"
#include "ex_docmd.h"
#include "fileio.h"
#include "getchar.h"
#include "hashtab.h"
#include "mbyte.h"
#include "memline.h"
#include "message.h"
#include "misc1.h"
#include "misc2.h"
#include "garray.h"
#include "normal.h"
#include "option.h"
#include "os_unix.h"
#include "regexp.h"
#include "screen.h"
#include "search.h"
#include "syntax.h"
#include "term.h"
#include "ui.h"
#include "undo.h"
#include "os/os.h"

#ifndef UNIX            /* it's in os_unix_defs.h for Unix */
# include <time.h>      /* for time_t */
#endif

#define MAXWLEN 250             /* Assume max. word len is this many bytes.
                                   Some places assume a word length fits in a
                                   byte, thus it can't be above 255. */

/* Type used for indexes in the word tree need to be at least 4 bytes.  If int
 * is 8 bytes we could use something smaller, but what? */
#if SIZEOF_INT > 3
typedef int idx_T;
#else
typedef long idx_T;
#endif

# define SPL_FNAME_TMPL  "%s.%s.spl"
# define SPL_FNAME_ADD   ".add."
# define SPL_FNAME_ASCII ".ascii."

/* Flags used for a word.  Only the lowest byte can be used, the region byte
 * comes above it. */
#define WF_REGION   0x01        /* region byte follows */
#define WF_ONECAP   0x02        /* word with one capital (or all capitals) */
#define WF_ALLCAP   0x04        /* word must be all capitals */
#define WF_RARE     0x08        /* rare word */
#define WF_BANNED   0x10        /* bad word */
#define WF_AFX      0x20        /* affix ID follows */
#define WF_FIXCAP   0x40        /* keep-case word, allcap not allowed */
#define WF_KEEPCAP  0x80        /* keep-case word */

/* for <flags2>, shifted up one byte to be used in wn_flags */
#define WF_HAS_AFF  0x0100      /* word includes affix */
#define WF_NEEDCOMP 0x0200      /* word only valid in compound */
#define WF_NOSUGGEST 0x0400     /* word not to be suggested */
#define WF_COMPROOT 0x0800      /* already compounded word, COMPOUNDROOT */
#define WF_NOCOMPBEF 0x1000     /* no compounding before this word */
#define WF_NOCOMPAFT 0x2000     /* no compounding after this word */

/* only used for su_badflags */
#define WF_MIXCAP   0x20        /* mix of upper and lower case: macaRONI */

#define WF_CAPMASK (WF_ONECAP | WF_ALLCAP | WF_KEEPCAP | WF_FIXCAP)

/* flags for <pflags> */
#define WFP_RARE            0x01        /* rare prefix */
#define WFP_NC              0x02        /* prefix is not combining */
#define WFP_UP              0x04        /* to-upper prefix */
#define WFP_COMPPERMIT      0x08        /* prefix with COMPOUNDPERMITFLAG */
#define WFP_COMPFORBID      0x10        /* prefix with COMPOUNDFORBIDFLAG */

/* Flags for postponed prefixes in "sl_pidxs".  Must be above affixID (one
 * byte) and prefcondnr (two bytes). */
#define WF_RAREPFX  (WFP_RARE << 24)    /* rare postponed prefix */
#define WF_PFX_NC   (WFP_NC << 24)      /* non-combining postponed prefix */
#define WF_PFX_UP   (WFP_UP << 24)      /* to-upper postponed prefix */
#define WF_PFX_COMPPERMIT (WFP_COMPPERMIT << 24) /* postponed prefix with
                                                  * COMPOUNDPERMITFLAG */
#define WF_PFX_COMPFORBID (WFP_COMPFORBID << 24) /* postponed prefix with
                                                  * COMPOUNDFORBIDFLAG */


/* flags for <compoptions> */
#define COMP_CHECKDUP           1       /* CHECKCOMPOUNDDUP */
#define COMP_CHECKREP           2       /* CHECKCOMPOUNDREP */
#define COMP_CHECKCASE          4       /* CHECKCOMPOUNDCASE */
#define COMP_CHECKTRIPLE        8       /* CHECKCOMPOUNDTRIPLE */

/* Special byte values for <byte>.  Some are only used in the tree for
 * postponed prefixes, some only in the other trees.  This is a bit messy... */
#define BY_NOFLAGS      0       /* end of word without flags or region; for
                                 * postponed prefix: no <pflags> */
#define BY_INDEX        1       /* child is shared, index follows */
#define BY_FLAGS        2       /* end of word, <flags> byte follows; for
                                 * postponed prefix: <pflags> follows */
#define BY_FLAGS2       3       /* end of word, <flags> and <flags2> bytes
                                 * follow; never used in prefix tree */
#define BY_SPECIAL  BY_FLAGS2   /* highest special byte value */

/* Info from "REP", "REPSAL" and "SAL" entries in ".aff" file used in si_rep,
 * si_repsal, sl_rep, and si_sal.  Not for sl_sal!
 * One replacement: from "ft_from" to "ft_to". */
typedef struct fromto_S {
  char_u      *ft_from;
  char_u      *ft_to;
} fromto_T;

/* Info from "SAL" entries in ".aff" file used in sl_sal.
 * The info is split for quick processing by spell_soundfold().
 * Note that "sm_oneof" and "sm_rules" point into sm_lead. */
typedef struct salitem_S {
  char_u      *sm_lead;         /* leading letters */
  int sm_leadlen;               /* length of "sm_lead" */
  char_u      *sm_oneof;        /* letters from () or NULL */
  char_u      *sm_rules;        /* rules like ^, $, priority */
  char_u      *sm_to;           /* replacement. */
  int         *sm_lead_w;       /* wide character copy of "sm_lead" */
  int         *sm_oneof_w;      /* wide character copy of "sm_oneof" */
  int         *sm_to_w;         /* wide character copy of "sm_to" */
} salitem_T;

typedef int salfirst_T;

/* Values for SP_*ERROR are negative, positive values are used by
 * read_cnt_string(). */
#define SP_TRUNCERROR   -1      /* spell file truncated error */
#define SP_FORMERROR    -2      /* format error in spell file */
#define SP_OTHERERROR   -3      /* other error while reading spell file */

/*
 * Structure used to store words and other info for one language, loaded from
 * a .spl file.
 * The main access is through the tree in "sl_fbyts/sl_fidxs", storing the
 * case-folded words.  "sl_kbyts/sl_kidxs" is for keep-case words.
 *
 * The "byts" array stores the possible bytes in each tree node, preceded by
 * the number of possible bytes, sorted on byte value:
 *	<len> <byte1> <byte2> ...
 * The "idxs" array stores the index of the child node corresponding to the
 * byte in "byts".
 * Exception: when the byte is zero, the word may end here and "idxs" holds
 * the flags, region mask and affixID for the word.  There may be several
 * zeros in sequence for alternative flag/region/affixID combinations.
 */
typedef struct slang_S slang_T;
struct slang_S {
  slang_T     *sl_next;         /* next language */
  char_u      *sl_name;         /* language name "en", "en.rare", "nl", etc. */
  char_u      *sl_fname;        /* name of .spl file */
  int sl_add;                   /* TRUE if it's a .add file. */

  char_u      *sl_fbyts;        /* case-folded word bytes */
  idx_T       *sl_fidxs;        /* case-folded word indexes */
  char_u      *sl_kbyts;        /* keep-case word bytes */
  idx_T       *sl_kidxs;        /* keep-case word indexes */
  char_u      *sl_pbyts;        /* prefix tree word bytes */
  idx_T       *sl_pidxs;        /* prefix tree word indexes */

  char_u      *sl_info;         /* infotext string or NULL */

  char_u sl_regions[17];        /* table with up to 8 region names plus NUL */

  char_u      *sl_midword;      /* MIDWORD string or NULL */

  hashtab_T sl_wordcount;       /* hashtable with word count, wordcount_T */

  int sl_compmax;               /* COMPOUNDWORDMAX (default: MAXWLEN) */
  int sl_compminlen;            /* COMPOUNDMIN (default: 0) */
  int sl_compsylmax;            /* COMPOUNDSYLMAX (default: MAXWLEN) */
  int sl_compoptions;           /* COMP_* flags */
  garray_T sl_comppat;          /* CHECKCOMPOUNDPATTERN items */
  regprog_T   *sl_compprog;     /* COMPOUNDRULE turned into a regexp progrm
                                 * (NULL when no compounding) */
  char_u      *sl_comprules;    /* all COMPOUNDRULE concatenated (or NULL) */
  char_u      *sl_compstartflags;   /* flags for first compound word */
  char_u      *sl_compallflags;   /* all flags for compound words */
  char_u sl_nobreak;            /* When TRUE: no spaces between words */
  char_u      *sl_syllable;     /* SYLLABLE repeatable chars or NULL */
  garray_T sl_syl_items;        /* syllable items */

  int sl_prefixcnt;             /* number of items in "sl_prefprog" */
  regprog_T   **sl_prefprog;    /* table with regprogs for prefixes */

  garray_T sl_rep;              /* list of fromto_T entries from REP lines */
  short sl_rep_first[256];          /* indexes where byte first appears, -1 if
                                       there is none */
  garray_T sl_sal;              /* list of salitem_T entries from SAL lines */
  salfirst_T sl_sal_first[256];     /* indexes where byte first appears, -1 if
                                       there is none */
  int sl_followup;              /* SAL followup */
  int sl_collapse;              /* SAL collapse_result */
  int sl_rem_accents;           /* SAL remove_accents */
  int sl_sofo;                  /* SOFOFROM and SOFOTO instead of SAL items:
                                 * "sl_sal_first" maps chars, when has_mbyte
                                 * "sl_sal" is a list of wide char lists. */
  garray_T sl_repsal;           /* list of fromto_T entries from REPSAL lines */
  short sl_repsal_first[256];          /* sl_rep_first for REPSAL lines */
  int sl_nosplitsugs;           /* don't suggest splitting a word */

  /* Info from the .sug file.  Loaded on demand. */
  time_t sl_sugtime;            /* timestamp for .sug file */
  char_u      *sl_sbyts;        /* soundfolded word bytes */
  idx_T       *sl_sidxs;        /* soundfolded word indexes */
  buf_T       *sl_sugbuf;       /* buffer with word number table */
  int sl_sugloaded;             /* TRUE when .sug file was loaded or failed to
                                   load */

  int sl_has_map;               /* TRUE if there is a MAP line */
  hashtab_T sl_map_hash;        /* MAP for multi-byte chars */
  int sl_map_array[256];           /* MAP for first 256 chars */
  hashtab_T sl_sounddone;       /* table with soundfolded words that have
                                   handled, see add_sound_suggest() */
};

/* First language that is loaded, start of the linked list of loaded
 * languages. */
static slang_T *first_lang = NULL;

/* Flags used in .spl file for soundsalike flags. */
#define SAL_F0LLOWUP            1
#define SAL_COLLAPSE            2
#define SAL_REM_ACCENTS         4

/*
 * Structure used in "b_langp", filled from 'spelllang'.
 */
typedef struct langp_S {
  slang_T     *lp_slang;        /* info for this language */
  slang_T     *lp_sallang;      /* language used for sound folding or NULL */
  slang_T     *lp_replang;      /* language used for REP items or NULL */
  int lp_region;                /* bitmask for region or REGION_ALL */
} langp_T;

#define LANGP_ENTRY(ga, i)      (((langp_T *)(ga).ga_data) + (i))

#define REGION_ALL 0xff         /* word valid in all regions */

#define VIMSPELLMAGIC "VIMspell"  /* string at start of Vim spell file */
#define VIMSPELLMAGICL 8
#define VIMSPELLVERSION 50

#define VIMSUGMAGIC "VIMsug"    /* string at start of Vim .sug file */
#define VIMSUGMAGICL 6
#define VIMSUGVERSION 1

/* Section IDs.  Only renumber them when VIMSPELLVERSION changes! */
#define SN_REGION       0       /* <regionname> section */
#define SN_CHARFLAGS    1       /* charflags section */
#define SN_MIDWORD      2       /* <midword> section */
#define SN_PREFCOND     3       /* <prefcond> section */
#define SN_REP          4       /* REP items section */
#define SN_SAL          5       /* SAL items section */
#define SN_SOFO         6       /* soundfolding section */
#define SN_MAP          7       /* MAP items section */
#define SN_COMPOUND     8       /* compound words section */
#define SN_SYLLABLE     9       /* syllable section */
#define SN_NOBREAK      10      /* NOBREAK section */
#define SN_SUGFILE      11      /* timestamp for .sug file */
#define SN_REPSAL       12      /* REPSAL items section */
#define SN_WORDS        13      /* common words */
#define SN_NOSPLITSUGS  14      /* don't split word for suggestions */
#define SN_INFO         15      /* info section */
#define SN_END          255     /* end of sections */

#define SNF_REQUIRED    1       /* <sectionflags>: required section */

/* Result values.  Lower number is accepted over higher one. */
#define SP_BANNED       -1
#define SP_OK           0
#define SP_RARE         1
#define SP_LOCAL        2
#define SP_BAD          3

/* file used for "zG" and "zW" */
static char_u   *int_wordlist = NULL;

typedef struct wordcount_S {
  short_u wc_count;                 /* nr of times word was seen */
  char_u wc_word[1];                /* word, actually longer */
} wordcount_T;

static wordcount_T dumwc;
#define WC_KEY_OFF  (unsigned)(dumwc.wc_word - (char_u *)&dumwc)
#define HI2WC(hi)     ((wordcount_T *)((hi)->hi_key - WC_KEY_OFF))
#define MAXWORDCOUNT 0xffff

/*
 * Information used when looking for suggestions.
 */
typedef struct suginfo_S {
  garray_T su_ga;                   /* suggestions, contains "suggest_T" */
  int su_maxcount;                  /* max. number of suggestions displayed */
  int su_maxscore;                  /* maximum score for adding to su_ga */
  int su_sfmaxscore;                /* idem, for when doing soundfold words */
  garray_T su_sga;                  /* like su_ga, sound-folded scoring */
  char_u      *su_badptr;           /* start of bad word in line */
  int su_badlen;                    /* length of detected bad word in line */
  int su_badflags;                  /* caps flags for bad word */
  char_u su_badword[MAXWLEN];        /* bad word truncated at su_badlen */
  char_u su_fbadword[MAXWLEN];        /* su_badword case-folded */
  char_u su_sal_badword[MAXWLEN];        /* su_badword soundfolded */
  hashtab_T su_banned;              /* table with banned words */
  slang_T     *su_sallang;          /* default language for sound folding */
} suginfo_T;

/* One word suggestion.  Used in "si_ga". */
typedef struct suggest_S {
  char_u      *st_word;         /* suggested word, allocated string */
  int st_wordlen;               /* STRLEN(st_word) */
  int st_orglen;                /* length of replaced text */
  int st_score;                 /* lower is better */
  int st_altscore;              /* used when st_score compares equal */
  int st_salscore;              /* st_score is for soundalike */
  int st_had_bonus;             /* bonus already included in score */
  slang_T     *st_slang;        /* language used for sound folding */
} suggest_T;

#define SUG(ga, i) (((suggest_T *)(ga).ga_data)[i])

/* TRUE if a word appears in the list of banned words.  */
#define WAS_BANNED(su, word) (!HASHITEM_EMPTY(hash_find(&su->su_banned, word)))

/* Number of suggestions kept when cleaning up.  We need to keep more than
 * what is displayed, because when rescore_suggestions() is called the score
 * may change and wrong suggestions may be removed later. */
#define SUG_CLEAN_COUNT(su)    ((su)->su_maxcount < \
                                130 ? 150 : (su)->su_maxcount + 20)

/* Threshold for sorting and cleaning up suggestions.  Don't want to keep lots
 * of suggestions that are not going to be displayed. */
#define SUG_MAX_COUNT(su)       (SUG_CLEAN_COUNT(su) + 50)

/* score for various changes */
#define SCORE_SPLIT     149     /* split bad word */
#define SCORE_SPLIT_NO  249     /* split bad word with NOSPLITSUGS */
#define SCORE_ICASE     52      /* slightly different case */
#define SCORE_REGION    200     /* word is for different region */
#define SCORE_RARE      180     /* rare word */
#define SCORE_SWAP      75      /* swap two characters */
#define SCORE_SWAP3     110     /* swap two characters in three */
#define SCORE_REP       65      /* REP replacement */
#define SCORE_SUBST     93      /* substitute a character */
#define SCORE_SIMILAR   33      /* substitute a similar character */
#define SCORE_SUBCOMP   33      /* substitute a composing character */
#define SCORE_DEL       94      /* delete a character */
#define SCORE_DELDUP    66      /* delete a duplicated character */
#define SCORE_DELCOMP   28      /* delete a composing character */
#define SCORE_INS       96      /* insert a character */
#define SCORE_INSDUP    67      /* insert a duplicate character */
#define SCORE_INSCOMP   30      /* insert a composing character */
#define SCORE_NONWORD   103     /* change non-word to word char */

#define SCORE_FILE      30      /* suggestion from a file */
#define SCORE_MAXINIT   350     /* Initial maximum score: higher == slower.
                                 * 350 allows for about three changes. */

#define SCORE_COMMON1   30      /* subtracted for words seen before */
#define SCORE_COMMON2   40      /* subtracted for words often seen */
#define SCORE_COMMON3   50      /* subtracted for words very often seen */
#define SCORE_THRES2    10      /* word count threshold for COMMON2 */
#define SCORE_THRES3    100     /* word count threshold for COMMON3 */

/* When trying changed soundfold words it becomes slow when trying more than
 * two changes.  With less then two changes it's slightly faster but we miss a
 * few good suggestions.  In rare cases we need to try three of four changes.
 */
#define SCORE_SFMAX1    200     /* maximum score for first try */
#define SCORE_SFMAX2    300     /* maximum score for second try */
#define SCORE_SFMAX3    400     /* maximum score for third try */

#define SCORE_BIG       SCORE_INS * 3   /* big difference */
#define SCORE_MAXMAX    999999          /* accept any score */
#define SCORE_LIMITMAX  350             /* for spell_edit_score_limit() */

/* for spell_edit_score_limit() we need to know the minimum value of
* SCORE_ICASE, SCORE_SWAP, SCORE_DEL, SCORE_SIMILAR and SCORE_INS */
#define SCORE_EDIT_MIN  SCORE_SIMILAR

/*
 * Structure to store info for word matching.
 */
typedef struct matchinf_S {
  langp_T     *mi_lp;                   /* info for language and region */

  /* pointers to original text to be checked */
  char_u      *mi_word;                 /* start of word being checked */
  char_u      *mi_end;                  /* end of matching word so far */
  char_u      *mi_fend;                 /* next char to be added to mi_fword */
  char_u      *mi_cend;                 /* char after what was used for
                                           mi_capflags */

  /* case-folded text */
  char_u mi_fword[MAXWLEN + 1];         /* mi_word case-folded */
  int mi_fwordlen;                      /* nr of valid bytes in mi_fword */

  /* for when checking word after a prefix */
  int mi_prefarridx;                    /* index in sl_pidxs with list of
                                           affixID/condition */
  int mi_prefcnt;                       /* number of entries at mi_prefarridx */
  int mi_prefixlen;                     /* byte length of prefix */
  int mi_cprefixlen;                    /* byte length of prefix in original
                                           case */

  /* for when checking a compound word */
  int mi_compoff;                       /* start of following word offset */
  char_u mi_compflags[MAXWLEN];         /* flags for compound words used */
  int mi_complen;                       /* nr of compound words used */
  int mi_compextra;                     /* nr of COMPOUNDROOT words */

  /* others */
  int mi_result;                        /* result so far: SP_BAD, SP_OK, etc. */
  int mi_capflags;                      /* WF_ONECAP WF_ALLCAP WF_KEEPCAP */
  win_T       *mi_win;                  /* buffer being checked */

  /* for NOBREAK */
  int mi_result2;                       /* "mi_resul" without following word */
  char_u      *mi_end2;                 /* "mi_end" without following word */
} matchinf_T;

/*
 * The tables used for recognizing word characters according to spelling.
 * These are only used for the first 256 characters of 'encoding'.
 */
typedef struct spelltab_S {
  char_u st_isw[256];           /* flags: is word char */
  char_u st_isu[256];           /* flags: is uppercase char */
  char_u st_fold[256];          /* chars: folded case */
  char_u st_upper[256];         /* chars: upper case */
} spelltab_T;

static spelltab_T spelltab;
static int did_set_spelltab;

#define CF_WORD         0x01
#define CF_UPPER        0x02

static void clear_spell_chartab(spelltab_T *sp);
static int set_spell_finish(spelltab_T  *new_st);
static int spell_iswordp(char_u *p, win_T *wp);
static int spell_iswordp_nmw(char_u *p, win_T *wp);
static int spell_mb_isword_class(int cl, win_T *wp);
static int spell_iswordp_w(int *p, win_T *wp);
static int write_spell_prefcond(FILE *fd, garray_T *gap);

/*
 * For finding suggestions: At each node in the tree these states are tried:
 */
typedef enum {
  STATE_START = 0,      /* At start of node check for NUL bytes (goodword
                         * ends); if badword ends there is a match, otherwise
                         * try splitting word. */
  STATE_NOPREFIX,       /* try without prefix */
  STATE_SPLITUNDO,      /* Undo splitting. */
  STATE_ENDNUL,         /* Past NUL bytes at start of the node. */
  STATE_PLAIN,          /* Use each byte of the node. */
  STATE_DEL,            /* Delete a byte from the bad word. */
  STATE_INS_PREP,       /* Prepare for inserting bytes. */
  STATE_INS,            /* Insert a byte in the bad word. */
  STATE_SWAP,           /* Swap two bytes. */
  STATE_UNSWAP,         /* Undo swap two characters. */
  STATE_SWAP3,          /* Swap two characters over three. */
  STATE_UNSWAP3,        /* Undo Swap two characters over three. */
  STATE_UNROT3L,        /* Undo rotate three characters left */
  STATE_UNROT3R,        /* Undo rotate three characters right */
  STATE_REP_INI,        /* Prepare for using REP items. */
  STATE_REP,            /* Use matching REP items from the .aff file. */
  STATE_REP_UNDO,       /* Undo a REP item replacement. */
  STATE_FINAL           /* End of this node. */
} state_T;

/*
 * Struct to keep the state at each level in suggest_try_change().
 */
typedef struct trystate_S {
  state_T ts_state;             /* state at this level, STATE_ */
  int ts_score;                 /* score */
  idx_T ts_arridx;              /* index in tree array, start of node */
  short ts_curi;                /* index in list of child nodes */
  char_u ts_fidx;               /* index in fword[], case-folded bad word */
  char_u ts_fidxtry;            /* ts_fidx at which bytes may be changed */
  char_u ts_twordlen;           /* valid length of tword[] */
  char_u ts_prefixdepth;        /* stack depth for end of prefix or
                                * PFD_PREFIXTREE or PFD_NOPREFIX */
  char_u ts_flags;              /* TSF_ flags */
  char_u ts_tcharlen;           /* number of bytes in tword character */
  char_u ts_tcharidx;           /* current byte index in tword character */
  char_u ts_isdiff;             /* DIFF_ values */
  char_u ts_fcharstart;         /* index in fword where badword char started */
  char_u ts_prewordlen;         /* length of word in "preword[]" */
  char_u ts_splitoff;           /* index in "tword" after last split */
  char_u ts_splitfidx;          /* "ts_fidx" at word split */
  char_u ts_complen;            /* nr of compound words used */
  char_u ts_compsplit;          /* index for "compflags" where word was spit */
  char_u ts_save_badflags;          /* su_badflags saved here */
  char_u ts_delidx;             /* index in fword for char that was deleted,
                                   valid when "ts_flags" has TSF_DIDDEL */
} trystate_T;

/* values for ts_isdiff */
#define DIFF_NONE       0       /* no different byte (yet) */
#define DIFF_YES        1       /* different byte found */
#define DIFF_INSERT     2       /* inserting character */

/* values for ts_flags */
#define TSF_PREFIXOK    1       /* already checked that prefix is OK */
#define TSF_DIDSPLIT    2       /* tried split at this point */
#define TSF_DIDDEL      4       /* did a delete, "ts_delidx" has index */

/* special values ts_prefixdepth */
#define PFD_NOPREFIX    0xff    /* not using prefixes */
#define PFD_PREFIXTREE  0xfe    /* walking through the prefix tree */
#define PFD_NOTSPECIAL  0xfd    /* highest value that's not special */

/* mode values for find_word */
#define FIND_FOLDWORD       0   /* find word case-folded */
#define FIND_KEEPWORD       1   /* find keep-case word */
#define FIND_PREFIX         2   /* find word after prefix */
#define FIND_COMPOUND       3   /* find case-folded compound word */
#define FIND_KEEPCOMPOUND   4   /* find keep-case compound word */

static slang_T *slang_alloc(char_u *lang);
static void slang_free(slang_T *lp);
static void slang_clear(slang_T *lp);
static void slang_clear_sug(slang_T *lp);
static void find_word(matchinf_T *mip, int mode);
static int match_checkcompoundpattern(char_u *ptr, int wlen,
                                      garray_T *gap);
static int can_compound(slang_T *slang, char_u *word, char_u *flags);
static int can_be_compound(trystate_T *sp, slang_T *slang, char_u *compflags,
                           int flag);
static int match_compoundrule(slang_T *slang, char_u *compflags);
static int valid_word_prefix(int totprefcnt, int arridx, int flags,
                             char_u *word, slang_T *slang,
                             int cond_req);
static void find_prefix(matchinf_T *mip, int mode);
static int fold_more(matchinf_T *mip);
static int spell_valid_case(int wordflags, int treeflags);
static int no_spell_checking(win_T *wp);
static void spell_load_lang(char_u *lang);
static char_u *spell_enc(void);
static void int_wordlist_spl(char_u *fname);
static void spell_load_cb(char_u *fname, void *cookie);
static slang_T *spell_load_file(char_u *fname, char_u *lang, slang_T *old_lp,
                                int silent);
static char_u *read_cnt_string(FILE *fd, int cnt_bytes, int *lenp);
static int read_region_section(FILE *fd, slang_T *slang, int len);
static int read_charflags_section(FILE *fd);
static int read_prefcond_section(FILE *fd, slang_T *lp);
static int read_rep_section(FILE *fd, garray_T *gap, short *first);
static int read_sal_section(FILE *fd, slang_T *slang);
static int read_words_section(FILE *fd, slang_T *lp, int len);
static void count_common_word(slang_T *lp, char_u *word, int len,
                              int count);
static int score_wordcount_adj(slang_T *slang, int score, char_u *word,
                               int split);
static int read_sofo_section(FILE *fd, slang_T *slang);
static int read_compound(FILE *fd, slang_T *slang, int len);
static int byte_in_str(char_u *str, int byte);
static int init_syl_tab(slang_T *slang);
static int count_syllables(slang_T *slang, char_u *word);
static int set_sofo(slang_T *lp, char_u *from, char_u *to);
static void set_sal_first(slang_T *lp);
static int *mb_str2wide(char_u *s);
static int spell_read_tree(FILE *fd, char_u **bytsp, idx_T **idxsp,
                           int prefixtree,
                           int prefixcnt);
static idx_T read_tree_node(FILE *fd, char_u *byts, idx_T *idxs,
                            int maxidx, idx_T startidx, int prefixtree,
                            int maxprefcondnr);
static void clear_midword(win_T *buf);
static void use_midword(slang_T *lp, win_T *buf);
static int find_region(char_u *rp, char_u *region);
static int captype(char_u *word, char_u *end);
static int badword_captype(char_u *word, char_u *end);
static void spell_reload_one(char_u *fname, int added_word);
static void set_spell_charflags(char_u *flags, int cnt, char_u *upp);
static int set_spell_chartab(char_u *fol, char_u *low, char_u *upp);
static int spell_casefold(char_u *p, int len, char_u *buf, int buflen);
static int check_need_cap(linenr_T lnum, colnr_T col);
static void spell_find_suggest(char_u *badptr, int badlen, suginfo_T *su,
                               int maxcount, int banbadword,
                               int need_cap,
                               int interactive);
static void spell_suggest_expr(suginfo_T *su, char_u *expr);
static void spell_suggest_file(suginfo_T *su, char_u *fname);
static void spell_suggest_intern(suginfo_T *su, int interactive);
static void suggest_load_files(void);
static void tree_count_words(char_u *byts, idx_T *idxs);
static void spell_find_cleanup(suginfo_T *su);
static void onecap_copy(char_u *word, char_u *wcopy, int upper);
static void allcap_copy(char_u *word, char_u *wcopy);
static void suggest_try_special(suginfo_T *su);
static void suggest_try_change(suginfo_T *su);
static void suggest_trie_walk(suginfo_T *su, langp_T *lp, char_u *fword,
                              int soundfold);
static void go_deeper(trystate_T *stack, int depth, int score_add);
static int nofold_len(char_u *fword, int flen, char_u *word);
static void find_keepcap_word(slang_T *slang, char_u *fword,
                              char_u *kword);
static void score_comp_sal(suginfo_T *su);
static void score_combine(suginfo_T *su);
static int stp_sal_score(suggest_T *stp, suginfo_T *su, slang_T *slang,
                         char_u *badsound);
static void suggest_try_soundalike_prep(void);
static void suggest_try_soundalike(suginfo_T *su);
static void suggest_try_soundalike_finish(void);
static void add_sound_suggest(suginfo_T *su, char_u *goodword,
                              int score,
                              langp_T *lp);
static int soundfold_find(slang_T *slang, char_u *word);
static void make_case_word(char_u *fword, char_u *cword, int flags);
static void set_map_str(slang_T *lp, char_u *map);
static int similar_chars(slang_T *slang, int c1, int c2);
static void add_suggestion(suginfo_T *su, garray_T *gap, char_u *goodword,
                           int badlen, int score,
                           int altscore, int had_bonus, slang_T *slang,
                           int maxsf);
static void check_suggestions(suginfo_T *su, garray_T *gap);
static void add_banned(suginfo_T *su, char_u *word);
static void rescore_suggestions(suginfo_T *su);
static void rescore_one(suginfo_T *su, suggest_T *stp);
static int cleanup_suggestions(garray_T *gap, int maxscore, int keep);
static void spell_soundfold(slang_T *slang, char_u *inword, int folded,
                            char_u *res);
static void spell_soundfold_sofo(slang_T *slang, char_u *inword,
                                 char_u *res);
static void spell_soundfold_sal(slang_T *slang, char_u *inword,
                                char_u *res);
static void spell_soundfold_wsal(slang_T *slang, char_u *inword,
                                 char_u *res);
static int soundalike_score(char_u *goodsound, char_u *badsound);
static int spell_edit_score(slang_T *slang, char_u *badword,
                            char_u *goodword);
static int spell_edit_score_limit(slang_T *slang, char_u *badword,
                                  char_u *goodword,
                                  int limit);
static int spell_edit_score_limit_w(slang_T *slang, char_u *badword,
                                    char_u *goodword,
                                    int limit);
static void dump_word(slang_T *slang, char_u *word, char_u *pat,
                      int *dir, int round, int flags,
                      linenr_T lnum);
static linenr_T dump_prefixes(slang_T *slang, char_u *word, char_u *pat,
                              int *dir, int round, int flags,
                              linenr_T startlnum);
static buf_T *open_spellbuf(void);
static void close_spellbuf(buf_T *buf);

/*
 * Use our own character-case definitions, because the current locale may
 * differ from what the .spl file uses.
 * These must not be called with negative number!
 */
# if defined(HAVE_WCHAR_H)
#  include <wchar.h>        /* for towupper() and towlower() */
# endif
/* Multi-byte implementation.  For Unicode we can call utf_*(), but don't do
 * that for ASCII, because we don't want to use 'casemap' here.  Otherwise use
 * the "w" library function for characters above 255 if available. */
# ifdef HAVE_TOWLOWER
#  define SPELL_TOFOLD(c) (enc_utf8 && (c) >= 128 ? utf_fold(c) \
                           : (c) < \
                           256 ? (int)spelltab.st_fold[c] : (int)towlower(c))
# else
#  define SPELL_TOFOLD(c) (enc_utf8 && (c) >= 128 ? utf_fold(c) \
                           : (c) < 256 ? (int)spelltab.st_fold[c] : (c))
# endif

# ifdef HAVE_TOWUPPER
#  define SPELL_TOUPPER(c) (enc_utf8 && (c) >= 128 ? utf_toupper(c) \
                            : (c) < \
                            256 ? (int)spelltab.st_upper[c] : (int)towupper(c))
# else
#  define SPELL_TOUPPER(c) (enc_utf8 && (c) >= 128 ? utf_toupper(c) \
                            : (c) < 256 ? (int)spelltab.st_upper[c] : (c))
# endif

# ifdef HAVE_ISWUPPER
#  define SPELL_ISUPPER(c) (enc_utf8 && (c) >= 128 ? utf_isupper(c) \
                            : (c) < 256 ? spelltab.st_isu[c] : iswupper(c))
# else
#  define SPELL_ISUPPER(c) (enc_utf8 && (c) >= 128 ? utf_isupper(c) \
                            : (c) < 256 ? spelltab.st_isu[c] : (FALSE))
# endif


static char *e_format = N_("E759: Format error in spell file");
static char *e_spell_trunc = N_("E758: Truncated spell file");
static char *e_afftrailing = N_("Trailing text in %s line %d: %s");
static char *e_affname = N_("Affix name too long in %s line %d: %s");
static char *e_affform = N_("E761: Format error in affix file FOL, LOW or UPP");
static char *e_affrange = N_(
    "E762: Character in FOL, LOW or UPP is out of range");
static char *msg_compressing = N_("Compressing word tree...");

/* Remember what "z?" replaced. */
static char_u   *repl_from = NULL;
static char_u   *repl_to = NULL;

/*
 * Main spell-checking function.
 * "ptr" points to a character that could be the start of a word.
 * "*attrp" is set to the highlight index for a badly spelled word.  For a
 * non-word or when it's OK it remains unchanged.
 * This must only be called when 'spelllang' is not empty.
 *
 * "capcol" is used to check for a Capitalised word after the end of a
 * sentence.  If it's zero then perform the check.  Return the column where to
 * check next, or -1 when no sentence end was found.  If it's NULL then don't
 * worry.
 *
 * Returns the length of the word in bytes, also when it's OK, so that the
 * caller can skip over the word.
 */
int 
spell_check (
    win_T *wp,                /* current window */
    char_u *ptr,
    hlf_T *attrp,
    int *capcol,            /* column to check for Capital */
    int docount                    /* count good words */
)
{
  matchinf_T mi;                /* Most things are put in "mi" so that it can
                                   be passed to functions quickly. */
  int nrlen = 0;                /* found a number first */
  int c;
  int wrongcaplen = 0;
  int lpi;
  int count_word = docount;

  /* A word never starts at a space or a control character.  Return quickly
   * then, skipping over the character. */
  if (*ptr <= ' ')
    return 1;

  /* Return here when loading language files failed. */
  if (wp->w_s->b_langp.ga_len == 0)
    return 1;

  vim_memset(&mi, 0, sizeof(matchinf_T));

  /* A number is always OK.  Also skip hexadecimal numbers 0xFF99 and
   * 0X99FF.  But always do check spelling to find "3GPP" and "11
   * julifeest". */
  if (*ptr >= '0' && *ptr <= '9') {
    if (*ptr == '0' && (ptr[1] == 'x' || ptr[1] == 'X'))
      mi.mi_end = skiphex(ptr + 2);
    else
      mi.mi_end = skipdigits(ptr);
    nrlen = (int)(mi.mi_end - ptr);
  }

  /* Find the normal end of the word (until the next non-word character). */
  mi.mi_word = ptr;
  mi.mi_fend = ptr;
  if (spell_iswordp(mi.mi_fend, wp)) {
    do {
      mb_ptr_adv(mi.mi_fend);
    } while (*mi.mi_fend != NUL && spell_iswordp(mi.mi_fend, wp));

    if (capcol != NULL && *capcol == 0 && wp->w_s->b_cap_prog != NULL) {
      /* Check word starting with capital letter. */
      c = PTR2CHAR(ptr);
      if (!SPELL_ISUPPER(c))
        wrongcaplen = (int)(mi.mi_fend - ptr);
    }
  }
  if (capcol != NULL)
    *capcol = -1;

  /* We always use the characters up to the next non-word character,
   * also for bad words. */
  mi.mi_end = mi.mi_fend;

  /* Check caps type later. */
  mi.mi_capflags = 0;
  mi.mi_cend = NULL;
  mi.mi_win = wp;

  /* case-fold the word with one non-word character, so that we can check
   * for the word end. */
  if (*mi.mi_fend != NUL)
    mb_ptr_adv(mi.mi_fend);

  (void)spell_casefold(ptr, (int)(mi.mi_fend - ptr), mi.mi_fword,
      MAXWLEN + 1);
  mi.mi_fwordlen = (int)STRLEN(mi.mi_fword);

  /* The word is bad unless we recognize it. */
  mi.mi_result = SP_BAD;
  mi.mi_result2 = SP_BAD;

  /*
   * Loop over the languages specified in 'spelllang'.
   * We check them all, because a word may be matched longer in another
   * language.
   */
  for (lpi = 0; lpi < wp->w_s->b_langp.ga_len; ++lpi) {
    mi.mi_lp = LANGP_ENTRY(wp->w_s->b_langp, lpi);

    /* If reloading fails the language is still in the list but everything
     * has been cleared. */
    if (mi.mi_lp->lp_slang->sl_fidxs == NULL)
      continue;

    /* Check for a matching word in case-folded words. */
    find_word(&mi, FIND_FOLDWORD);

    /* Check for a matching word in keep-case words. */
    find_word(&mi, FIND_KEEPWORD);

    /* Check for matching prefixes. */
    find_prefix(&mi, FIND_FOLDWORD);

    /* For a NOBREAK language, may want to use a word without a following
     * word as a backup. */
    if (mi.mi_lp->lp_slang->sl_nobreak && mi.mi_result == SP_BAD
        && mi.mi_result2 != SP_BAD) {
      mi.mi_result = mi.mi_result2;
      mi.mi_end = mi.mi_end2;
    }

    /* Count the word in the first language where it's found to be OK. */
    if (count_word && mi.mi_result == SP_OK) {
      count_common_word(mi.mi_lp->lp_slang, ptr,
          (int)(mi.mi_end - ptr), 1);
      count_word = FALSE;
    }
  }

  if (mi.mi_result != SP_OK) {
    /* If we found a number skip over it.  Allows for "42nd".  Do flag
     * rare and local words, e.g., "3GPP". */
    if (nrlen > 0) {
      if (mi.mi_result == SP_BAD || mi.mi_result == SP_BANNED)
        return nrlen;
    }
    /* When we are at a non-word character there is no error, just
     * skip over the character (try looking for a word after it). */
    else if (!spell_iswordp_nmw(ptr, wp)) {
      if (capcol != NULL && wp->w_s->b_cap_prog != NULL) {
        regmatch_T regmatch;

        /* Check for end of sentence. */
        regmatch.regprog = wp->w_s->b_cap_prog;
        regmatch.rm_ic = FALSE;
        if (vim_regexec(&regmatch, ptr, 0))
          *capcol = (int)(regmatch.endp[0] - ptr);
      }

      if (has_mbyte)
        return (*mb_ptr2len)(ptr);
      return 1;
    } else if (mi.mi_end == ptr)
      /* Always include at least one character.  Required for when there
       * is a mixup in "midword". */
      mb_ptr_adv(mi.mi_end);
    else if (mi.mi_result == SP_BAD
             && LANGP_ENTRY(wp->w_s->b_langp, 0)->lp_slang->sl_nobreak) {
      char_u      *p, *fp;
      int save_result = mi.mi_result;

      /* First language in 'spelllang' is NOBREAK.  Find first position
       * at which any word would be valid. */
      mi.mi_lp = LANGP_ENTRY(wp->w_s->b_langp, 0);
      if (mi.mi_lp->lp_slang->sl_fidxs != NULL) {
        p = mi.mi_word;
        fp = mi.mi_fword;
        for (;; ) {
          mb_ptr_adv(p);
          mb_ptr_adv(fp);
          if (p >= mi.mi_end)
            break;
          mi.mi_compoff = (int)(fp - mi.mi_fword);
          find_word(&mi, FIND_COMPOUND);
          if (mi.mi_result != SP_BAD) {
            mi.mi_end = p;
            break;
          }
        }
        mi.mi_result = save_result;
      }
    }

    if (mi.mi_result == SP_BAD || mi.mi_result == SP_BANNED)
      *attrp = HLF_SPB;
    else if (mi.mi_result == SP_RARE)
      *attrp = HLF_SPR;
    else
      *attrp = HLF_SPL;
  }

  if (wrongcaplen > 0 && (mi.mi_result == SP_OK || mi.mi_result == SP_RARE)) {
    /* Report SpellCap only when the word isn't badly spelled. */
    *attrp = HLF_SPC;
    return wrongcaplen;
  }

  return (int)(mi.mi_end - ptr);
}

/*
 * Check if the word at "mip->mi_word" is in the tree.
 * When "mode" is FIND_FOLDWORD check in fold-case word tree.
 * When "mode" is FIND_KEEPWORD check in keep-case word tree.
 * When "mode" is FIND_PREFIX check for word after prefix in fold-case word
 * tree.
 *
 * For a match mip->mi_result is updated.
 */
static void find_word(matchinf_T *mip, int mode)
{
  idx_T arridx = 0;
  int endlen[MAXWLEN];              /* length at possible word endings */
  idx_T endidx[MAXWLEN];            /* possible word endings */
  int endidxcnt = 0;
  int len;
  int wlen = 0;
  int flen;
  int c;
  char_u      *ptr;
  idx_T lo, hi, m;
  char_u      *s;
  char_u      *p;
  int res = SP_BAD;
  slang_T     *slang = mip->mi_lp->lp_slang;
  unsigned flags;
  char_u      *byts;
  idx_T       *idxs;
  int word_ends;
  int prefix_found;
  int nobreak_result;

  if (mode == FIND_KEEPWORD || mode == FIND_KEEPCOMPOUND) {
    /* Check for word with matching case in keep-case tree. */
    ptr = mip->mi_word;
    flen = 9999;                    /* no case folding, always enough bytes */
    byts = slang->sl_kbyts;
    idxs = slang->sl_kidxs;

    if (mode == FIND_KEEPCOMPOUND)
      /* Skip over the previously found word(s). */
      wlen += mip->mi_compoff;
  } else   {
    /* Check for case-folded in case-folded tree. */
    ptr = mip->mi_fword;
    flen = mip->mi_fwordlen;        /* available case-folded bytes */
    byts = slang->sl_fbyts;
    idxs = slang->sl_fidxs;

    if (mode == FIND_PREFIX) {
      /* Skip over the prefix. */
      wlen = mip->mi_prefixlen;
      flen -= mip->mi_prefixlen;
    } else if (mode == FIND_COMPOUND)   {
      /* Skip over the previously found word(s). */
      wlen = mip->mi_compoff;
      flen -= mip->mi_compoff;
    }

  }

  if (byts == NULL)
    return;                     /* array is empty */

  /*
   * Repeat advancing in the tree until:
   * - there is a byte that doesn't match,
   * - we reach the end of the tree,
   * - or we reach the end of the line.
   */
  for (;; ) {
    if (flen <= 0 && *mip->mi_fend != NUL)
      flen = fold_more(mip);

    len = byts[arridx++];

    /* If the first possible byte is a zero the word could end here.
     * Remember this index, we first check for the longest word. */
    if (byts[arridx] == 0) {
      if (endidxcnt == MAXWLEN) {
        /* Must be a corrupted spell file. */
        EMSG(_(e_format));
        return;
      }
      endlen[endidxcnt] = wlen;
      endidx[endidxcnt++] = arridx++;
      --len;

      /* Skip over the zeros, there can be several flag/region
       * combinations. */
      while (len > 0 && byts[arridx] == 0) {
        ++arridx;
        --len;
      }
      if (len == 0)
        break;              /* no children, word must end here */
    }

    /* Stop looking at end of the line. */
    if (ptr[wlen] == NUL)
      break;

    /* Perform a binary search in the list of accepted bytes. */
    c = ptr[wlen];
    if (c == TAB)           /* <Tab> is handled like <Space> */
      c = ' ';
    lo = arridx;
    hi = arridx + len - 1;
    while (lo < hi) {
      m = (lo + hi) / 2;
      if (byts[m] > c)
        hi = m - 1;
      else if (byts[m] < c)
        lo = m + 1;
      else {
        lo = hi = m;
        break;
      }
    }

    /* Stop if there is no matching byte. */
    if (hi < lo || byts[lo] != c)
      break;

    /* Continue at the child (if there is one). */
    arridx = idxs[lo];
    ++wlen;
    --flen;

    /* One space in the good word may stand for several spaces in the
     * checked word. */
    if (c == ' ') {
      for (;; ) {
        if (flen <= 0 && *mip->mi_fend != NUL)
          flen = fold_more(mip);
        if (ptr[wlen] != ' ' && ptr[wlen] != TAB)
          break;
        ++wlen;
        --flen;
      }
    }
  }

  /*
   * Verify that one of the possible endings is valid.  Try the longest
   * first.
   */
  while (endidxcnt > 0) {
    --endidxcnt;
    arridx = endidx[endidxcnt];
    wlen = endlen[endidxcnt];

    if ((*mb_head_off)(ptr, ptr + wlen) > 0)
      continue;             /* not at first byte of character */
    if (spell_iswordp(ptr + wlen, mip->mi_win)) {
      if (slang->sl_compprog == NULL && !slang->sl_nobreak)
        continue;                   /* next char is a word character */
      word_ends = FALSE;
    } else
      word_ends = TRUE;
    /* The prefix flag is before compound flags.  Once a valid prefix flag
     * has been found we try compound flags. */
    prefix_found = FALSE;

    if (mode != FIND_KEEPWORD && has_mbyte) {
      /* Compute byte length in original word, length may change
       * when folding case.  This can be slow, take a shortcut when the
       * case-folded word is equal to the keep-case word. */
      p = mip->mi_word;
      if (STRNCMP(ptr, p, wlen) != 0) {
        for (s = ptr; s < ptr + wlen; mb_ptr_adv(s))
          mb_ptr_adv(p);
        wlen = (int)(p - mip->mi_word);
      }
    }

    /* Check flags and region.  For FIND_PREFIX check the condition and
     * prefix ID.
     * Repeat this if there are more flags/region alternatives until there
     * is a match. */
    res = SP_BAD;
    for (len = byts[arridx - 1]; len > 0 && byts[arridx] == 0;
         --len, ++arridx) {
      flags = idxs[arridx];

      /* For the fold-case tree check that the case of the checked word
       * matches with what the word in the tree requires.
       * For keep-case tree the case is always right.  For prefixes we
       * don't bother to check. */
      if (mode == FIND_FOLDWORD) {
        if (mip->mi_cend != mip->mi_word + wlen) {
          /* mi_capflags was set for a different word length, need
           * to do it again. */
          mip->mi_cend = mip->mi_word + wlen;
          mip->mi_capflags = captype(mip->mi_word, mip->mi_cend);
        }

        if (mip->mi_capflags == WF_KEEPCAP
            || !spell_valid_case(mip->mi_capflags, flags))
          continue;
      }
      /* When mode is FIND_PREFIX the word must support the prefix:
       * check the prefix ID and the condition.  Do that for the list at
       * mip->mi_prefarridx that find_prefix() filled. */
      else if (mode == FIND_PREFIX && !prefix_found) {
        c = valid_word_prefix(mip->mi_prefcnt, mip->mi_prefarridx,
            flags,
            mip->mi_word + mip->mi_cprefixlen, slang,
            FALSE);
        if (c == 0)
          continue;

        /* Use the WF_RARE flag for a rare prefix. */
        if (c & WF_RAREPFX)
          flags |= WF_RARE;
        prefix_found = TRUE;
      }

      if (slang->sl_nobreak) {
        if ((mode == FIND_COMPOUND || mode == FIND_KEEPCOMPOUND)
            && (flags & WF_BANNED) == 0) {
          /* NOBREAK: found a valid following word.  That's all we
           * need to know, so return. */
          mip->mi_result = SP_OK;
          break;
        }
      } else if ((mode == FIND_COMPOUND || mode == FIND_KEEPCOMPOUND
                  || !word_ends)) {
        /* If there is no compound flag or the word is shorter than
         * COMPOUNDMIN reject it quickly.
         * Makes you wonder why someone puts a compound flag on a word
         * that's too short...  Myspell compatibility requires this
         * anyway. */
        if (((unsigned)flags >> 24) == 0
            || wlen - mip->mi_compoff < slang->sl_compminlen)
          continue;
        /* For multi-byte chars check character length against
         * COMPOUNDMIN. */
        if (has_mbyte
            && slang->sl_compminlen > 0
            && mb_charlen_len(mip->mi_word + mip->mi_compoff,
                wlen - mip->mi_compoff) < slang->sl_compminlen)
          continue;

        /* Limit the number of compound words to COMPOUNDWORDMAX if no
         * maximum for syllables is specified. */
        if (!word_ends && mip->mi_complen + mip->mi_compextra + 2
            > slang->sl_compmax
            && slang->sl_compsylmax == MAXWLEN)
          continue;

        /* Don't allow compounding on a side where an affix was added,
         * unless COMPOUNDPERMITFLAG was used. */
        if (mip->mi_complen > 0 && (flags & WF_NOCOMPBEF))
          continue;
        if (!word_ends && (flags & WF_NOCOMPAFT))
          continue;

        /* Quickly check if compounding is possible with this flag. */
        if (!byte_in_str(mip->mi_complen == 0
                ? slang->sl_compstartflags
                : slang->sl_compallflags,
                ((unsigned)flags >> 24)))
          continue;

        /* If there is a match with a CHECKCOMPOUNDPATTERN rule
         * discard the compound word. */
        if (match_checkcompoundpattern(ptr, wlen, &slang->sl_comppat))
          continue;

        if (mode == FIND_COMPOUND) {
          int capflags;

          /* Need to check the caps type of the appended compound
           * word. */
          if (has_mbyte && STRNCMP(ptr, mip->mi_word,
                  mip->mi_compoff) != 0) {
            /* case folding may have changed the length */
            p = mip->mi_word;
            for (s = ptr; s < ptr + mip->mi_compoff; mb_ptr_adv(s))
              mb_ptr_adv(p);
          } else
            p = mip->mi_word + mip->mi_compoff;
          capflags = captype(p, mip->mi_word + wlen);
          if (capflags == WF_KEEPCAP || (capflags == WF_ALLCAP
                                         && (flags & WF_FIXCAP) != 0))
            continue;

          if (capflags != WF_ALLCAP) {
            /* When the character before the word is a word
             * character we do not accept a Onecap word.  We do
             * accept a no-caps word, even when the dictionary
             * word specifies ONECAP. */
            mb_ptr_back(mip->mi_word, p);
            if (spell_iswordp_nmw(p, mip->mi_win)
                ? capflags == WF_ONECAP
                : (flags & WF_ONECAP) != 0
                && capflags != WF_ONECAP)
              continue;
          }
        }

        /* If the word ends the sequence of compound flags of the
         * words must match with one of the COMPOUNDRULE items and
         * the number of syllables must not be too large. */
        mip->mi_compflags[mip->mi_complen] = ((unsigned)flags >> 24);
        mip->mi_compflags[mip->mi_complen + 1] = NUL;
        if (word_ends) {
          char_u fword[MAXWLEN];

          if (slang->sl_compsylmax < MAXWLEN) {
            /* "fword" is only needed for checking syllables. */
            if (ptr == mip->mi_word)
              (void)spell_casefold(ptr, wlen, fword, MAXWLEN);
            else
              vim_strncpy(fword, ptr, endlen[endidxcnt]);
          }
          if (!can_compound(slang, fword, mip->mi_compflags))
            continue;
        } else if (slang->sl_comprules != NULL
                   && !match_compoundrule(slang, mip->mi_compflags))
          /* The compound flags collected so far do not match any
           * COMPOUNDRULE, discard the compounded word. */
          continue;
      }
      /* Check NEEDCOMPOUND: can't use word without compounding. */
      else if (flags & WF_NEEDCOMP)
        continue;

      nobreak_result = SP_OK;

      if (!word_ends) {
        int save_result = mip->mi_result;
        char_u  *save_end = mip->mi_end;
        langp_T *save_lp = mip->mi_lp;
        int lpi;

        /* Check that a valid word follows.  If there is one and we
         * are compounding, it will set "mi_result", thus we are
         * always finished here.  For NOBREAK we only check that a
         * valid word follows.
         * Recursive! */
        if (slang->sl_nobreak)
          mip->mi_result = SP_BAD;

        /* Find following word in case-folded tree. */
        mip->mi_compoff = endlen[endidxcnt];
        if (has_mbyte && mode == FIND_KEEPWORD) {
          /* Compute byte length in case-folded word from "wlen":
           * byte length in keep-case word.  Length may change when
           * folding case.  This can be slow, take a shortcut when
           * the case-folded word is equal to the keep-case word. */
          p = mip->mi_fword;
          if (STRNCMP(ptr, p, wlen) != 0) {
            for (s = ptr; s < ptr + wlen; mb_ptr_adv(s))
              mb_ptr_adv(p);
            mip->mi_compoff = (int)(p - mip->mi_fword);
          }
        }
        c = mip->mi_compoff;
        ++mip->mi_complen;
        if (flags & WF_COMPROOT)
          ++mip->mi_compextra;

        /* For NOBREAK we need to try all NOBREAK languages, at least
         * to find the ".add" file(s). */
        for (lpi = 0; lpi < mip->mi_win->w_s->b_langp.ga_len; ++lpi) {
          if (slang->sl_nobreak) {
            mip->mi_lp = LANGP_ENTRY(mip->mi_win->w_s->b_langp, lpi);
            if (mip->mi_lp->lp_slang->sl_fidxs == NULL
                || !mip->mi_lp->lp_slang->sl_nobreak)
              continue;
          }

          find_word(mip, FIND_COMPOUND);

          /* When NOBREAK any word that matches is OK.  Otherwise we
           * need to find the longest match, thus try with keep-case
           * and prefix too. */
          if (!slang->sl_nobreak || mip->mi_result == SP_BAD) {
            /* Find following word in keep-case tree. */
            mip->mi_compoff = wlen;
            find_word(mip, FIND_KEEPCOMPOUND);

#if 0       /* Disabled, a prefix must not appear halfway a compound word,
               unless the COMPOUNDPERMITFLAG is used and then it can't be a
               postponed prefix. */
            if (!slang->sl_nobreak || mip->mi_result == SP_BAD) {
              /* Check for following word with prefix. */
              mip->mi_compoff = c;
              find_prefix(mip, FIND_COMPOUND);
            }
#endif
          }

          if (!slang->sl_nobreak)
            break;
        }
        --mip->mi_complen;
        if (flags & WF_COMPROOT)
          --mip->mi_compextra;
        mip->mi_lp = save_lp;

        if (slang->sl_nobreak) {
          nobreak_result = mip->mi_result;
          mip->mi_result = save_result;
          mip->mi_end = save_end;
        } else   {
          if (mip->mi_result == SP_OK)
            break;
          continue;
        }
      }

      if (flags & WF_BANNED)
        res = SP_BANNED;
      else if (flags & WF_REGION) {
        /* Check region. */
        if ((mip->mi_lp->lp_region & (flags >> 16)) != 0)
          res = SP_OK;
        else
          res = SP_LOCAL;
      } else if (flags & WF_RARE)
        res = SP_RARE;
      else
        res = SP_OK;

      /* Always use the longest match and the best result.  For NOBREAK
       * we separately keep the longest match without a following good
       * word as a fall-back. */
      if (nobreak_result == SP_BAD) {
        if (mip->mi_result2 > res) {
          mip->mi_result2 = res;
          mip->mi_end2 = mip->mi_word + wlen;
        } else if (mip->mi_result2 == res
                   && mip->mi_end2 < mip->mi_word + wlen)
          mip->mi_end2 = mip->mi_word + wlen;
      } else if (mip->mi_result > res)   {
        mip->mi_result = res;
        mip->mi_end = mip->mi_word + wlen;
      } else if (mip->mi_result == res && mip->mi_end < mip->mi_word + wlen)
        mip->mi_end = mip->mi_word + wlen;

      if (mip->mi_result == SP_OK)
        break;
    }

    if (mip->mi_result == SP_OK)
      break;
  }
}

/*
 * Return TRUE if there is a match between the word ptr[wlen] and
 * CHECKCOMPOUNDPATTERN rules, assuming that we will concatenate with another
 * word.
 * A match means that the first part of CHECKCOMPOUNDPATTERN matches at the
 * end of ptr[wlen] and the second part matches after it.
 */
static int 
match_checkcompoundpattern (
    char_u *ptr,
    int wlen,
    garray_T *gap      /* &sl_comppat */
)
{
  int i;
  char_u      *p;
  int len;

  for (i = 0; i + 1 < gap->ga_len; i += 2) {
    p = ((char_u **)gap->ga_data)[i + 1];
    if (STRNCMP(ptr + wlen, p, STRLEN(p)) == 0) {
      /* Second part matches at start of following compound word, now
       * check if first part matches at end of previous word. */
      p = ((char_u **)gap->ga_data)[i];
      len = (int)STRLEN(p);
      if (len <= wlen && STRNCMP(ptr + wlen - len, p, len) == 0)
        return TRUE;
    }
  }
  return FALSE;
}

/*
 * Return TRUE if "flags" is a valid sequence of compound flags and "word"
 * does not have too many syllables.
 */
static int can_compound(slang_T *slang, char_u *word, char_u *flags)
{
  regmatch_T regmatch;
  char_u uflags[MAXWLEN * 2];
  int i;
  char_u      *p;

  if (slang->sl_compprog == NULL)
    return FALSE;
  if (enc_utf8) {
    /* Need to convert the single byte flags to utf8 characters. */
    p = uflags;
    for (i = 0; flags[i] != NUL; ++i)
      p += mb_char2bytes(flags[i], p);
    *p = NUL;
    p = uflags;
  } else
    p = flags;
  regmatch.regprog = slang->sl_compprog;
  regmatch.rm_ic = FALSE;
  if (!vim_regexec(&regmatch, p, 0))
    return FALSE;

  /* Count the number of syllables.  This may be slow, do it last.  If there
   * are too many syllables AND the number of compound words is above
   * COMPOUNDWORDMAX then compounding is not allowed. */
  if (slang->sl_compsylmax < MAXWLEN
      && count_syllables(slang, word) > slang->sl_compsylmax)
    return (int)STRLEN(flags) < slang->sl_compmax;
  return TRUE;
}

/*
 * Return TRUE when the sequence of flags in "compflags" plus "flag" can
 * possibly form a valid compounded word.  This also checks the COMPOUNDRULE
 * lines if they don't contain wildcards.
 */
static int can_be_compound(trystate_T *sp, slang_T *slang, char_u *compflags, int flag)
{
  /* If the flag doesn't appear in sl_compstartflags or sl_compallflags
   * then it can't possibly compound. */
  if (!byte_in_str(sp->ts_complen == sp->ts_compsplit
          ? slang->sl_compstartflags : slang->sl_compallflags, flag))
    return FALSE;

  /* If there are no wildcards, we can check if the flags collected so far
   * possibly can form a match with COMPOUNDRULE patterns.  This only
   * makes sense when we have two or more words. */
  if (slang->sl_comprules != NULL && sp->ts_complen > sp->ts_compsplit) {
    int v;

    compflags[sp->ts_complen] = flag;
    compflags[sp->ts_complen + 1] = NUL;
    v = match_compoundrule(slang, compflags + sp->ts_compsplit);
    compflags[sp->ts_complen] = NUL;
    return v;
  }

  return TRUE;
}


/*
 * Return TRUE if the compound flags in compflags[] match the start of any
 * compound rule.  This is used to stop trying a compound if the flags
 * collected so far can't possibly match any compound rule.
 * Caller must check that slang->sl_comprules is not NULL.
 */
static int match_compoundrule(slang_T *slang, char_u *compflags)
{
  char_u      *p;
  int i;
  int c;

  /* loop over all the COMPOUNDRULE entries */
  for (p = slang->sl_comprules; *p != NUL; ++p) {
    /* loop over the flags in the compound word we have made, match
     * them against the current rule entry */
    for (i = 0;; ++i) {
      c = compflags[i];
      if (c == NUL)
        /* found a rule that matches for the flags we have so far */
        return TRUE;
      if (*p == '/' || *p == NUL)
        break;          /* end of rule, it's too short */
      if (*p == '[') {
        int match = FALSE;

        /* compare against all the flags in [] */
        ++p;
        while (*p != ']' && *p != NUL)
          if (*p++ == c)
            match = TRUE;
        if (!match)
          break;            /* none matches */
      } else if (*p != c)
        break;          /* flag of word doesn't match flag in pattern */
      ++p;
    }

    /* Skip to the next "/", where the next pattern starts. */
    p = vim_strchr(p, '/');
    if (p == NULL)
      break;
  }

  /* Checked all the rules and none of them match the flags, so there
   * can't possibly be a compound starting with these flags. */
  return FALSE;
}

/*
 * Return non-zero if the prefix indicated by "arridx" matches with the prefix
 * ID in "flags" for the word "word".
 * The WF_RAREPFX flag is included in the return value for a rare prefix.
 */
static int 
valid_word_prefix (
    int totprefcnt,                 /* nr of prefix IDs */
    int arridx,                     /* idx in sl_pidxs[] */
    int flags,
    char_u *word,
    slang_T *slang,
    int cond_req                   /* only use prefixes with a condition */
)
{
  int prefcnt;
  int pidx;
  regprog_T   *rp;
  regmatch_T regmatch;
  int prefid;

  prefid = (unsigned)flags >> 24;
  for (prefcnt = totprefcnt - 1; prefcnt >= 0; --prefcnt) {
    pidx = slang->sl_pidxs[arridx + prefcnt];

    /* Check the prefix ID. */
    if (prefid != (pidx & 0xff))
      continue;

    /* Check if the prefix doesn't combine and the word already has a
     * suffix. */
    if ((flags & WF_HAS_AFF) && (pidx & WF_PFX_NC))
      continue;

    /* Check the condition, if there is one.  The condition index is
     * stored in the two bytes above the prefix ID byte.  */
    rp = slang->sl_prefprog[((unsigned)pidx >> 8) & 0xffff];
    if (rp != NULL) {
      regmatch.regprog = rp;
      regmatch.rm_ic = FALSE;
      if (!vim_regexec(&regmatch, word, 0))
        continue;
    } else if (cond_req)
      continue;

    /* It's a match!  Return the WF_ flags. */
    return pidx;
  }
  return 0;
}

/*
 * Check if the word at "mip->mi_word" has a matching prefix.
 * If it does, then check the following word.
 *
 * If "mode" is "FIND_COMPOUND" then do the same after another word, find a
 * prefix in a compound word.
 *
 * For a match mip->mi_result is updated.
 */
static void find_prefix(matchinf_T *mip, int mode)
{
  idx_T arridx = 0;
  int len;
  int wlen = 0;
  int flen;
  int c;
  char_u      *ptr;
  idx_T lo, hi, m;
  slang_T     *slang = mip->mi_lp->lp_slang;
  char_u      *byts;
  idx_T       *idxs;

  byts = slang->sl_pbyts;
  if (byts == NULL)
    return;                     /* array is empty */

  /* We use the case-folded word here, since prefixes are always
   * case-folded. */
  ptr = mip->mi_fword;
  flen = mip->mi_fwordlen;      /* available case-folded bytes */
  if (mode == FIND_COMPOUND) {
    /* Skip over the previously found word(s). */
    ptr += mip->mi_compoff;
    flen -= mip->mi_compoff;
  }
  idxs = slang->sl_pidxs;

  /*
   * Repeat advancing in the tree until:
   * - there is a byte that doesn't match,
   * - we reach the end of the tree,
   * - or we reach the end of the line.
   */
  for (;; ) {
    if (flen == 0 && *mip->mi_fend != NUL)
      flen = fold_more(mip);

    len = byts[arridx++];

    /* If the first possible byte is a zero the prefix could end here.
     * Check if the following word matches and supports the prefix. */
    if (byts[arridx] == 0) {
      /* There can be several prefixes with different conditions.  We
       * try them all, since we don't know which one will give the
       * longest match.  The word is the same each time, pass the list
       * of possible prefixes to find_word(). */
      mip->mi_prefarridx = arridx;
      mip->mi_prefcnt = len;
      while (len > 0 && byts[arridx] == 0) {
        ++arridx;
        --len;
      }
      mip->mi_prefcnt -= len;

      /* Find the word that comes after the prefix. */
      mip->mi_prefixlen = wlen;
      if (mode == FIND_COMPOUND)
        /* Skip over the previously found word(s). */
        mip->mi_prefixlen += mip->mi_compoff;

      if (has_mbyte) {
        /* Case-folded length may differ from original length. */
        mip->mi_cprefixlen = nofold_len(mip->mi_fword,
            mip->mi_prefixlen, mip->mi_word);
      } else
        mip->mi_cprefixlen = mip->mi_prefixlen;
      find_word(mip, FIND_PREFIX);


      if (len == 0)
        break;              /* no children, word must end here */
    }

    /* Stop looking at end of the line. */
    if (ptr[wlen] == NUL)
      break;

    /* Perform a binary search in the list of accepted bytes. */
    c = ptr[wlen];
    lo = arridx;
    hi = arridx + len - 1;
    while (lo < hi) {
      m = (lo + hi) / 2;
      if (byts[m] > c)
        hi = m - 1;
      else if (byts[m] < c)
        lo = m + 1;
      else {
        lo = hi = m;
        break;
      }
    }

    /* Stop if there is no matching byte. */
    if (hi < lo || byts[lo] != c)
      break;

    /* Continue at the child (if there is one). */
    arridx = idxs[lo];
    ++wlen;
    --flen;
  }
}

/*
 * Need to fold at least one more character.  Do until next non-word character
 * for efficiency.  Include the non-word character too.
 * Return the length of the folded chars in bytes.
 */
static int fold_more(matchinf_T *mip)
{
  int flen;
  char_u      *p;

  p = mip->mi_fend;
  do {
    mb_ptr_adv(mip->mi_fend);
  } while (*mip->mi_fend != NUL && spell_iswordp(mip->mi_fend, mip->mi_win));

  /* Include the non-word character so that we can check for the word end. */
  if (*mip->mi_fend != NUL)
    mb_ptr_adv(mip->mi_fend);

  (void)spell_casefold(p, (int)(mip->mi_fend - p),
      mip->mi_fword + mip->mi_fwordlen,
      MAXWLEN - mip->mi_fwordlen);
  flen = (int)STRLEN(mip->mi_fword + mip->mi_fwordlen);
  mip->mi_fwordlen += flen;
  return flen;
}

/*
 * Check case flags for a word.  Return TRUE if the word has the requested
 * case.
 */
static int 
spell_valid_case (
    int wordflags,              /* flags for the checked word. */
    int treeflags              /* flags for the word in the spell tree */
)
{
  return (wordflags == WF_ALLCAP && (treeflags & WF_FIXCAP) == 0)
         || ((treeflags & (WF_ALLCAP | WF_KEEPCAP)) == 0
             && ((treeflags & WF_ONECAP) == 0
                 || (wordflags & WF_ONECAP) != 0));
}

/*
 * Return TRUE if spell checking is not enabled.
 */
static int no_spell_checking(win_T *wp)
{
  if (!wp->w_p_spell || *wp->w_s->b_p_spl == NUL
      || wp->w_s->b_langp.ga_len == 0) {
    EMSG(_("E756: Spell checking is not enabled"));
    return TRUE;
  }
  return FALSE;
}

/*
 * Move to next spell error.
 * "curline" is FALSE for "[s", "]s", "[S" and "]S".
 * "curline" is TRUE to find word under/after cursor in the same line.
 * For Insert mode completion "dir" is BACKWARD and "curline" is TRUE: move
 * to after badly spelled word before the cursor.
 * Return 0 if not found, length of the badly spelled word otherwise.
 */
int 
spell_move_to (
    win_T *wp,
    int dir,                        /* FORWARD or BACKWARD */
    int allwords,                   /* TRUE for "[s"/"]s", FALSE for "[S"/"]S" */
    int curline,
    hlf_T *attrp             /* return: attributes of bad word or NULL
                                   (only when "dir" is FORWARD) */
)
{
  linenr_T lnum;
  pos_T found_pos;
  int found_len = 0;
  char_u      *line;
  char_u      *p;
  char_u      *endp;
  hlf_T attr;
  int len;
  int has_syntax = syntax_present(wp);
  int col;
  int can_spell;
  char_u      *buf = NULL;
  int buflen = 0;
  int skip = 0;
  int capcol = -1;
  int found_one = FALSE;
  int wrapped = FALSE;

  if (no_spell_checking(wp))
    return 0;

  /*
   * Start looking for bad word at the start of the line, because we can't
   * start halfway a word, we don't know where it starts or ends.
   *
   * When searching backwards, we continue in the line to find the last
   * bad word (in the cursor line: before the cursor).
   *
   * We concatenate the start of the next line, so that wrapped words work
   * (e.g. "et<line-break>cetera").  Doesn't work when searching backwards
   * though...
   */
  lnum = wp->w_cursor.lnum;
  clearpos(&found_pos);

  while (!got_int) {
    line = ml_get_buf(wp->w_buffer, lnum, FALSE);

    len = (int)STRLEN(line);
    if (buflen < len + MAXWLEN + 2) {
      vim_free(buf);
      buflen = len + MAXWLEN + 2;
      buf = alloc(buflen);
      if (buf == NULL)
        break;
    }

    /* In first line check first word for Capital. */
    if (lnum == 1)
      capcol = 0;

    /* For checking first word with a capital skip white space. */
    if (capcol == 0)
      capcol = (int)(skipwhite(line) - line);
    else if (curline && wp == curwin) {
      /* For spellbadword(): check if first word needs a capital. */
      col = (int)(skipwhite(line) - line);
      if (check_need_cap(lnum, col))
        capcol = col;

      /* Need to get the line again, may have looked at the previous
       * one. */
      line = ml_get_buf(wp->w_buffer, lnum, FALSE);
    }

    /* Copy the line into "buf" and append the start of the next line if
     * possible. */
    STRCPY(buf, line);
    if (lnum < wp->w_buffer->b_ml.ml_line_count)
      spell_cat_line(buf + STRLEN(buf),
          ml_get_buf(wp->w_buffer, lnum + 1, FALSE), MAXWLEN);

    p = buf + skip;
    endp = buf + len;
    while (p < endp) {
      /* When searching backward don't search after the cursor.  Unless
       * we wrapped around the end of the buffer. */
      if (dir == BACKWARD
          && lnum == wp->w_cursor.lnum
          && !wrapped
          && (colnr_T)(p - buf) >= wp->w_cursor.col)
        break;

      /* start of word */
      attr = HLF_COUNT;
      len = spell_check(wp, p, &attr, &capcol, FALSE);

      if (attr != HLF_COUNT) {
        /* We found a bad word.  Check the attribute. */
        if (allwords || attr == HLF_SPB) {
          /* When searching forward only accept a bad word after
           * the cursor. */
          if (dir == BACKWARD
              || lnum != wp->w_cursor.lnum
              || (lnum == wp->w_cursor.lnum
                  && (wrapped
                      || (colnr_T)(curline ? p - buf + len
                                   : p - buf)
                      > wp->w_cursor.col))) {
            if (has_syntax) {
              col = (int)(p - buf);
              (void)syn_get_id(wp, lnum, (colnr_T)col,
                  FALSE, &can_spell, FALSE);
              if (!can_spell)
                attr = HLF_COUNT;
            } else
              can_spell = TRUE;

            if (can_spell) {
              found_one = TRUE;
              found_pos.lnum = lnum;
              found_pos.col = (int)(p - buf);
              found_pos.coladd = 0;
              if (dir == FORWARD) {
                /* No need to search further. */
                wp->w_cursor = found_pos;
                vim_free(buf);
                if (attrp != NULL)
                  *attrp = attr;
                return len;
              } else if (curline)
                /* Insert mode completion: put cursor after
                 * the bad word. */
                found_pos.col += len;
              found_len = len;
            }
          } else
            found_one = TRUE;
        }
      }

      /* advance to character after the word */
      p += len;
      capcol -= len;
    }

    if (dir == BACKWARD && found_pos.lnum != 0) {
      /* Use the last match in the line (before the cursor). */
      wp->w_cursor = found_pos;
      vim_free(buf);
      return found_len;
    }

    if (curline)
      break;            /* only check cursor line */

    /* Advance to next line. */
    if (dir == BACKWARD) {
      /* If we are back at the starting line and searched it again there
       * is no match, give up. */
      if (lnum == wp->w_cursor.lnum && wrapped)
        break;

      if (lnum > 1)
        --lnum;
      else if (!p_ws)
        break;              /* at first line and 'nowrapscan' */
      else {
        /* Wrap around to the end of the buffer.  May search the
         * starting line again and accept the last match. */
        lnum = wp->w_buffer->b_ml.ml_line_count;
        wrapped = TRUE;
        if (!shortmess(SHM_SEARCH))
          give_warning((char_u *)_(top_bot_msg), TRUE);
      }
      capcol = -1;
    } else   {
      if (lnum < wp->w_buffer->b_ml.ml_line_count)
        ++lnum;
      else if (!p_ws)
        break;              /* at first line and 'nowrapscan' */
      else {
        /* Wrap around to the start of the buffer.  May search the
         * starting line again and accept the first match. */
        lnum = 1;
        wrapped = TRUE;
        if (!shortmess(SHM_SEARCH))
          give_warning((char_u *)_(bot_top_msg), TRUE);
      }

      /* If we are back at the starting line and there is no match then
       * give up. */
      if (lnum == wp->w_cursor.lnum && (!found_one || wrapped))
        break;

      /* Skip the characters at the start of the next line that were
       * included in a match crossing line boundaries. */
      if (attr == HLF_COUNT)
        skip = (int)(p - endp);
      else
        skip = 0;

      /* Capcol skips over the inserted space. */
      --capcol;

      /* But after empty line check first word in next line */
      if (*skipwhite(line) == NUL)
        capcol = 0;
    }

    line_breakcheck();
  }

  vim_free(buf);
  return 0;
}

/*
 * For spell checking: concatenate the start of the following line "line" into
 * "buf", blanking-out special characters.  Copy less then "maxlen" bytes.
 * Keep the blanks at the start of the next line, this is used in win_line()
 * to skip those bytes if the word was OK.
 */
void spell_cat_line(char_u *buf, char_u *line, int maxlen)
{
  char_u      *p;
  int n;

  p = skipwhite(line);
  while (vim_strchr((char_u *)"*#/\"\t", *p) != NULL)
    p = skipwhite(p + 1);

  if (*p != NUL) {
    /* Only worth concatenating if there is something else than spaces to
     * concatenate. */
    n = (int)(p - line) + 1;
    if (n < maxlen - 1) {
      vim_memset(buf, ' ', n);
      vim_strncpy(buf +  n, p, maxlen - 1 - n);
    }
  }
}

/*
 * Structure used for the cookie argument of do_in_runtimepath().
 */
typedef struct spelload_S {
  char_u sl_lang[MAXWLEN + 1];          /* language name */
  slang_T *sl_slang;                    /* resulting slang_T struct */
  int sl_nobreak;                       /* NOBREAK language found */
} spelload_T;

/*
 * Load word list(s) for "lang" from Vim spell file(s).
 * "lang" must be the language without the region: e.g., "en".
 */
static void spell_load_lang(char_u *lang)
{
  char_u fname_enc[85];
  int r;
  spelload_T sl;
  int round;

  /* Copy the language name to pass it to spell_load_cb() as a cookie.
   * It's truncated when an error is detected. */
  STRCPY(sl.sl_lang, lang);
  sl.sl_slang = NULL;
  sl.sl_nobreak = FALSE;

  /* We may retry when no spell file is found for the language, an
   * autocommand may load it then. */
  for (round = 1; round <= 2; ++round) {
    /*
     * Find the first spell file for "lang" in 'runtimepath' and load it.
     */
    vim_snprintf((char *)fname_enc, sizeof(fname_enc) - 5,
        "spell/%s.%s.spl",
        lang, spell_enc());
    r = do_in_runtimepath(fname_enc, FALSE, spell_load_cb, &sl);

    if (r == FAIL && *sl.sl_lang != NUL) {
      /* Try loading the ASCII version. */
      vim_snprintf((char *)fname_enc, sizeof(fname_enc) - 5,
          "spell/%s.ascii.spl",
          lang);
      r = do_in_runtimepath(fname_enc, FALSE, spell_load_cb, &sl);

      if (r == FAIL && *sl.sl_lang != NUL && round == 1
          && apply_autocmds(EVENT_SPELLFILEMISSING, lang,
              curbuf->b_fname, FALSE, curbuf))
        continue;
      break;
    }
    break;
  }

  if (r == FAIL) {
    smsg((char_u *)
        _("Warning: Cannot find word list \"%s.%s.spl\" or \"%s.ascii.spl\""),
        lang, spell_enc(), lang);
  } else if (sl.sl_slang != NULL)   {
    /* At least one file was loaded, now load ALL the additions. */
    STRCPY(fname_enc + STRLEN(fname_enc) - 3, "add.spl");
    do_in_runtimepath(fname_enc, TRUE, spell_load_cb, &sl);
  }
}

/*
 * Return the encoding used for spell checking: Use 'encoding', except that we
 * use "latin1" for "latin9".  And limit to 60 characters (just in case).
 */
static char_u *spell_enc(void)                     {

  if (STRLEN(p_enc) < 60 && STRCMP(p_enc, "iso-8859-15") != 0)
    return p_enc;
  return (char_u *)"latin1";
}

/*
 * Get the name of the .spl file for the internal wordlist into
 * "fname[MAXPATHL]".
 */
static void int_wordlist_spl(char_u *fname)
{
  vim_snprintf((char *)fname, MAXPATHL, SPL_FNAME_TMPL,
      int_wordlist, spell_enc());
}

/*
 * Allocate a new slang_T for language "lang".  "lang" can be NULL.
 * Caller must fill "sl_next".
 */
static slang_T *slang_alloc(char_u *lang)
{
  slang_T *lp;

  lp = (slang_T *)alloc_clear(sizeof(slang_T));
  if (lp != NULL) {
    if (lang != NULL)
      lp->sl_name = vim_strsave(lang);
    ga_init2(&lp->sl_rep, sizeof(fromto_T), 10);
    ga_init2(&lp->sl_repsal, sizeof(fromto_T), 10);
    lp->sl_compmax = MAXWLEN;
    lp->sl_compsylmax = MAXWLEN;
    hash_init(&lp->sl_wordcount);
  }

  return lp;
}

/*
 * Free the contents of an slang_T and the structure itself.
 */
static void slang_free(slang_T *lp)
{
  vim_free(lp->sl_name);
  vim_free(lp->sl_fname);
  slang_clear(lp);
  vim_free(lp);
}

/*
 * Clear an slang_T so that the file can be reloaded.
 */
static void slang_clear(slang_T *lp)
{
  garray_T    *gap;
  fromto_T    *ftp;
  salitem_T   *smp;
  int i;
  int round;

  vim_free(lp->sl_fbyts);
  lp->sl_fbyts = NULL;
  vim_free(lp->sl_kbyts);
  lp->sl_kbyts = NULL;
  vim_free(lp->sl_pbyts);
  lp->sl_pbyts = NULL;

  vim_free(lp->sl_fidxs);
  lp->sl_fidxs = NULL;
  vim_free(lp->sl_kidxs);
  lp->sl_kidxs = NULL;
  vim_free(lp->sl_pidxs);
  lp->sl_pidxs = NULL;

  for (round = 1; round <= 2; ++round) {
    gap = round == 1 ? &lp->sl_rep : &lp->sl_repsal;
    while (gap->ga_len > 0) {
      ftp = &((fromto_T *)gap->ga_data)[--gap->ga_len];
      vim_free(ftp->ft_from);
      vim_free(ftp->ft_to);
    }
    ga_clear(gap);
  }

  gap = &lp->sl_sal;
  if (lp->sl_sofo) {
    /* "ga_len" is set to 1 without adding an item for latin1 */
    if (gap->ga_data != NULL)
      /* SOFOFROM and SOFOTO items: free lists of wide characters. */
      for (i = 0; i < gap->ga_len; ++i)
        vim_free(((int **)gap->ga_data)[i]);
  } else
    /* SAL items: free salitem_T items */
    while (gap->ga_len > 0) {
      smp = &((salitem_T *)gap->ga_data)[--gap->ga_len];
      vim_free(smp->sm_lead);
      /* Don't free sm_oneof and sm_rules, they point into sm_lead. */
      vim_free(smp->sm_to);
      vim_free(smp->sm_lead_w);
      vim_free(smp->sm_oneof_w);
      vim_free(smp->sm_to_w);
    }
  ga_clear(gap);

  for (i = 0; i < lp->sl_prefixcnt; ++i)
    vim_regfree(lp->sl_prefprog[i]);
  lp->sl_prefixcnt = 0;
  vim_free(lp->sl_prefprog);
  lp->sl_prefprog = NULL;

  vim_free(lp->sl_info);
  lp->sl_info = NULL;

  vim_free(lp->sl_midword);
  lp->sl_midword = NULL;

  vim_regfree(lp->sl_compprog);
  vim_free(lp->sl_comprules);
  vim_free(lp->sl_compstartflags);
  vim_free(lp->sl_compallflags);
  lp->sl_compprog = NULL;
  lp->sl_comprules = NULL;
  lp->sl_compstartflags = NULL;
  lp->sl_compallflags = NULL;

  vim_free(lp->sl_syllable);
  lp->sl_syllable = NULL;
  ga_clear(&lp->sl_syl_items);

  ga_clear_strings(&lp->sl_comppat);

  hash_clear_all(&lp->sl_wordcount, WC_KEY_OFF);
  hash_init(&lp->sl_wordcount);

  hash_clear_all(&lp->sl_map_hash, 0);

  /* Clear info from .sug file. */
  slang_clear_sug(lp);

  lp->sl_compmax = MAXWLEN;
  lp->sl_compminlen = 0;
  lp->sl_compsylmax = MAXWLEN;
  lp->sl_regions[0] = NUL;
}

/*
 * Clear the info from the .sug file in "lp".
 */
static void slang_clear_sug(slang_T *lp)
{
  vim_free(lp->sl_sbyts);
  lp->sl_sbyts = NULL;
  vim_free(lp->sl_sidxs);
  lp->sl_sidxs = NULL;
  close_spellbuf(lp->sl_sugbuf);
  lp->sl_sugbuf = NULL;
  lp->sl_sugloaded = FALSE;
  lp->sl_sugtime = 0;
}

/*
 * Load one spell file and store the info into a slang_T.
 * Invoked through do_in_runtimepath().
 */
static void spell_load_cb(char_u *fname, void *cookie)
{
  spelload_T  *slp = (spelload_T *)cookie;
  slang_T     *slang;

  slang = spell_load_file(fname, slp->sl_lang, NULL, FALSE);
  if (slang != NULL) {
    /* When a previously loaded file has NOBREAK also use it for the
     * ".add" files. */
    if (slp->sl_nobreak && slang->sl_add)
      slang->sl_nobreak = TRUE;
    else if (slang->sl_nobreak)
      slp->sl_nobreak = TRUE;

    slp->sl_slang = slang;
  }
}

/*
 * Load one spell file and store the info into a slang_T.
 *
 * This is invoked in three ways:
 * - From spell_load_cb() to load a spell file for the first time.  "lang" is
 *   the language name, "old_lp" is NULL.  Will allocate an slang_T.
 * - To reload a spell file that was changed.  "lang" is NULL and "old_lp"
 *   points to the existing slang_T.
 * - Just after writing a .spl file; it's read back to produce the .sug file.
 *   "old_lp" is NULL and "lang" is NULL.  Will allocate an slang_T.
 *
 * Returns the slang_T the spell file was loaded into.  NULL for error.
 */
static slang_T *
spell_load_file (
    char_u *fname,
    char_u *lang,
    slang_T *old_lp,
    int silent                     /* no error if file doesn't exist */
)
{
  FILE        *fd;
  char_u buf[VIMSPELLMAGICL];
  char_u      *p;
  int i;
  int n;
  int len;
  char_u      *save_sourcing_name = sourcing_name;
  linenr_T save_sourcing_lnum = sourcing_lnum;
  slang_T     *lp = NULL;
  int c = 0;
  int res;

  fd = mch_fopen((char *)fname, "r");
  if (fd == NULL) {
    if (!silent)
      EMSG2(_(e_notopen), fname);
    else if (p_verbose > 2) {
      verbose_enter();
      smsg((char_u *)e_notopen, fname);
      verbose_leave();
    }
    goto endFAIL;
  }
  if (p_verbose > 2) {
    verbose_enter();
    smsg((char_u *)_("Reading spell file \"%s\""), fname);
    verbose_leave();
  }

  if (old_lp == NULL) {
    lp = slang_alloc(lang);
    if (lp == NULL)
      goto endFAIL;

    /* Remember the file name, used to reload the file when it's updated. */
    lp->sl_fname = vim_strsave(fname);
    if (lp->sl_fname == NULL)
      goto endFAIL;

    /* Check for .add.spl (_add.spl for VMS). */
    lp->sl_add = strstr((char *)gettail(fname), SPL_FNAME_ADD) != NULL;
  } else
    lp = old_lp;

  /* Set sourcing_name, so that error messages mention the file name. */
  sourcing_name = fname;
  sourcing_lnum = 0;

  /*
   * <HEADER>: <fileID>
   */
  for (i = 0; i < VIMSPELLMAGICL; ++i)
    buf[i] = getc(fd);                                  /* <fileID> */
  if (STRNCMP(buf, VIMSPELLMAGIC, VIMSPELLMAGICL) != 0) {
    EMSG(_("E757: This does not look like a spell file"));
    goto endFAIL;
  }
  c = getc(fd);                                         /* <versionnr> */
  if (c < VIMSPELLVERSION) {
    EMSG(_("E771: Old spell file, needs to be updated"));
    goto endFAIL;
  } else if (c > VIMSPELLVERSION)   {
    EMSG(_("E772: Spell file is for newer version of Vim"));
    goto endFAIL;
  }


  /*
   * <SECTIONS>: <section> ... <sectionend>
   * <section>: <sectionID> <sectionflags> <sectionlen> (section contents)
   */
  for (;; ) {
    n = getc(fd);                           /* <sectionID> or <sectionend> */
    if (n == SN_END)
      break;
    c = getc(fd);                                       /* <sectionflags> */
    len = get4c(fd);                                    /* <sectionlen> */
    if (len < 0)
      goto truncerr;

    res = 0;
    switch (n) {
    case SN_INFO:
      lp->sl_info = read_string(fd, len);               /* <infotext> */
      if (lp->sl_info == NULL)
        goto endFAIL;
      break;

    case SN_REGION:
      res = read_region_section(fd, lp, len);
      break;

    case SN_CHARFLAGS:
      res = read_charflags_section(fd);
      break;

    case SN_MIDWORD:
      lp->sl_midword = read_string(fd, len);            /* <midword> */
      if (lp->sl_midword == NULL)
        goto endFAIL;
      break;

    case SN_PREFCOND:
      res = read_prefcond_section(fd, lp);
      break;

    case SN_REP:
      res = read_rep_section(fd, &lp->sl_rep, lp->sl_rep_first);
      break;

    case SN_REPSAL:
      res = read_rep_section(fd, &lp->sl_repsal, lp->sl_repsal_first);
      break;

    case SN_SAL:
      res = read_sal_section(fd, lp);
      break;

    case SN_SOFO:
      res = read_sofo_section(fd, lp);
      break;

    case SN_MAP:
      p = read_string(fd, len);                         /* <mapstr> */
      if (p == NULL)
        goto endFAIL;
      set_map_str(lp, p);
      vim_free(p);
      break;

    case SN_WORDS:
      res = read_words_section(fd, lp, len);
      break;

    case SN_SUGFILE:
      lp->sl_sugtime = get8ctime(fd);                   /* <timestamp> */
      break;

    case SN_NOSPLITSUGS:
      lp->sl_nosplitsugs = TRUE;                        /* <timestamp> */
      break;

    case SN_COMPOUND:
      res = read_compound(fd, lp, len);
      break;

    case SN_NOBREAK:
      lp->sl_nobreak = TRUE;
      break;

    case SN_SYLLABLE:
      lp->sl_syllable = read_string(fd, len);           /* <syllable> */
      if (lp->sl_syllable == NULL)
        goto endFAIL;
      if (init_syl_tab(lp) == FAIL)
        goto endFAIL;
      break;

    default:
      /* Unsupported section.  When it's required give an error
       * message.  When it's not required skip the contents. */
      if (c & SNF_REQUIRED) {
        EMSG(_("E770: Unsupported section in spell file"));
        goto endFAIL;
      }
      while (--len >= 0)
        if (getc(fd) < 0)
          goto truncerr;
      break;
    }
someerror:
    if (res == SP_FORMERROR) {
      EMSG(_(e_format));
      goto endFAIL;
    }
    if (res == SP_TRUNCERROR) {
truncerr:
      EMSG(_(e_spell_trunc));
      goto endFAIL;
    }
    if (res == SP_OTHERERROR)
      goto endFAIL;
  }

  /* <LWORDTREE> */
  res = spell_read_tree(fd, &lp->sl_fbyts, &lp->sl_fidxs, FALSE, 0);
  if (res != 0)
    goto someerror;

  /* <KWORDTREE> */
  res = spell_read_tree(fd, &lp->sl_kbyts, &lp->sl_kidxs, FALSE, 0);
  if (res != 0)
    goto someerror;

  /* <PREFIXTREE> */
  res = spell_read_tree(fd, &lp->sl_pbyts, &lp->sl_pidxs, TRUE,
      lp->sl_prefixcnt);
  if (res != 0)
    goto someerror;

  /* For a new file link it in the list of spell files. */
  if (old_lp == NULL && lang != NULL) {
    lp->sl_next = first_lang;
    first_lang = lp;
  }

  goto endOK;

endFAIL:
  if (lang != NULL)
    /* truncating the name signals the error to spell_load_lang() */
    *lang = NUL;
  if (lp != NULL && old_lp == NULL)
    slang_free(lp);
  lp = NULL;

endOK:
  if (fd != NULL)
    fclose(fd);
  sourcing_name = save_sourcing_name;
  sourcing_lnum = save_sourcing_lnum;

  return lp;
}

/*
 * Read a length field from "fd" in "cnt_bytes" bytes.
 * Allocate memory, read the string into it and add a NUL at the end.
 * Returns NULL when the count is zero.
 * Sets "*cntp" to SP_*ERROR when there is an error, length of the result
 * otherwise.
 */
static char_u *read_cnt_string(FILE *fd, int cnt_bytes, int *cntp)
{
  int cnt = 0;
  int i;
  char_u      *str;

  /* read the length bytes, MSB first */
  for (i = 0; i < cnt_bytes; ++i)
    cnt = (cnt << 8) + getc(fd);
  if (cnt < 0) {
    *cntp = SP_TRUNCERROR;
    return NULL;
  }
  *cntp = cnt;
  if (cnt == 0)
    return NULL;            /* nothing to read, return NULL */

  str = read_string(fd, cnt);
  if (str == NULL)
    *cntp = SP_OTHERERROR;
  return str;
}

/*
 * Read SN_REGION: <regionname> ...
 * Return SP_*ERROR flags.
 */
static int read_region_section(FILE *fd, slang_T *lp, int len)
{
  int i;

  if (len > 16)
    return SP_FORMERROR;
  for (i = 0; i < len; ++i)
    lp->sl_regions[i] = getc(fd);                       /* <regionname> */
  lp->sl_regions[len] = NUL;
  return 0;
}

/*
 * Read SN_CHARFLAGS section: <charflagslen> <charflags>
 *				<folcharslen> <folchars>
 * Return SP_*ERROR flags.
 */
static int read_charflags_section(FILE *fd)
{
  char_u      *flags;
  char_u      *fol;
  int flagslen, follen;

  /* <charflagslen> <charflags> */
  flags = read_cnt_string(fd, 1, &flagslen);
  if (flagslen < 0)
    return flagslen;

  /* <folcharslen> <folchars> */
  fol = read_cnt_string(fd, 2, &follen);
  if (follen < 0) {
    vim_free(flags);
    return follen;
  }

  /* Set the word-char flags and fill SPELL_ISUPPER() table. */
  if (flags != NULL && fol != NULL)
    set_spell_charflags(flags, flagslen, fol);

  vim_free(flags);
  vim_free(fol);

  /* When <charflagslen> is zero then <fcharlen> must also be zero. */
  if ((flags == NULL) != (fol == NULL))
    return SP_FORMERROR;
  return 0;
}

/*
 * Read SN_PREFCOND section.
 * Return SP_*ERROR flags.
 */
static int read_prefcond_section(FILE *fd, slang_T *lp)
{
  int cnt;
  int i;
  int n;
  char_u      *p;
  char_u buf[MAXWLEN + 1];

  /* <prefcondcnt> <prefcond> ... */
  cnt = get2c(fd);                                      /* <prefcondcnt> */
  if (cnt <= 0)
    return SP_FORMERROR;

  lp->sl_prefprog = (regprog_T **)alloc_clear(
      (unsigned)sizeof(regprog_T *) * cnt);
  if (lp->sl_prefprog == NULL)
    return SP_OTHERERROR;
  lp->sl_prefixcnt = cnt;

  for (i = 0; i < cnt; ++i) {
    /* <prefcond> : <condlen> <condstr> */
    n = getc(fd);                                       /* <condlen> */
    if (n < 0 || n >= MAXWLEN)
      return SP_FORMERROR;

    /* When <condlen> is zero we have an empty condition.  Otherwise
    * compile the regexp program used to check for the condition. */
    if (n > 0) {
      buf[0] = '^';                 /* always match at one position only */
      p = buf + 1;
      while (n-- > 0)
        *p++ = getc(fd);                                /* <condstr> */
      *p = NUL;
      lp->sl_prefprog[i] = vim_regcomp(buf, RE_MAGIC + RE_STRING);
    }
  }
  return 0;
}

/*
 * Read REP or REPSAL items section from "fd": <repcount> <rep> ...
 * Return SP_*ERROR flags.
 */
static int read_rep_section(FILE *fd, garray_T *gap, short *first)
{
  int cnt;
  fromto_T    *ftp;
  int i;

  cnt = get2c(fd);                                      /* <repcount> */
  if (cnt < 0)
    return SP_TRUNCERROR;

  if (ga_grow(gap, cnt) == FAIL)
    return SP_OTHERERROR;

  /* <rep> : <repfromlen> <repfrom> <reptolen> <repto> */
  for (; gap->ga_len < cnt; ++gap->ga_len) {
    ftp = &((fromto_T *)gap->ga_data)[gap->ga_len];
    ftp->ft_from = read_cnt_string(fd, 1, &i);
    if (i < 0)
      return i;
    if (i == 0)
      return SP_FORMERROR;
    ftp->ft_to = read_cnt_string(fd, 1, &i);
    if (i <= 0) {
      vim_free(ftp->ft_from);
      if (i < 0)
        return i;
      return SP_FORMERROR;
    }
  }

  /* Fill the first-index table. */
  for (i = 0; i < 256; ++i)
    first[i] = -1;
  for (i = 0; i < gap->ga_len; ++i) {
    ftp = &((fromto_T *)gap->ga_data)[i];
    if (first[*ftp->ft_from] == -1)
      first[*ftp->ft_from] = i;
  }
  return 0;
}

/*
 * Read SN_SAL section: <salflags> <salcount> <sal> ...
 * Return SP_*ERROR flags.
 */
static int read_sal_section(FILE *fd, slang_T *slang)
{
  int i;
  int cnt;
  garray_T    *gap;
  salitem_T   *smp;
  int ccnt;
  char_u      *p;
  int c = NUL;

  slang->sl_sofo = FALSE;

  i = getc(fd);                                 /* <salflags> */
  if (i & SAL_F0LLOWUP)
    slang->sl_followup = TRUE;
  if (i & SAL_COLLAPSE)
    slang->sl_collapse = TRUE;
  if (i & SAL_REM_ACCENTS)
    slang->sl_rem_accents = TRUE;

  cnt = get2c(fd);                              /* <salcount> */
  if (cnt < 0)
    return SP_TRUNCERROR;

  gap = &slang->sl_sal;
  ga_init2(gap, sizeof(salitem_T), 10);
  if (ga_grow(gap, cnt + 1) == FAIL)
    return SP_OTHERERROR;

  /* <sal> : <salfromlen> <salfrom> <saltolen> <salto> */
  for (; gap->ga_len < cnt; ++gap->ga_len) {
    smp = &((salitem_T *)gap->ga_data)[gap->ga_len];
    ccnt = getc(fd);                            /* <salfromlen> */
    if (ccnt < 0)
      return SP_TRUNCERROR;
    if ((p = alloc(ccnt + 2)) == NULL)
      return SP_OTHERERROR;
    smp->sm_lead = p;

    /* Read up to the first special char into sm_lead. */
    for (i = 0; i < ccnt; ++i) {
      c = getc(fd);                             /* <salfrom> */
      if (vim_strchr((char_u *)"0123456789(-<^$", c) != NULL)
        break;
      *p++ = c;
    }
    smp->sm_leadlen = (int)(p - smp->sm_lead);
    *p++ = NUL;

    /* Put (abc) chars in sm_oneof, if any. */
    if (c == '(') {
      smp->sm_oneof = p;
      for (++i; i < ccnt; ++i) {
        c = getc(fd);                           /* <salfrom> */
        if (c == ')')
          break;
        *p++ = c;
      }
      *p++ = NUL;
      if (++i < ccnt)
        c = getc(fd);
    } else
      smp->sm_oneof = NULL;

    /* Any following chars go in sm_rules. */
    smp->sm_rules = p;
    if (i < ccnt)
      /* store the char we got while checking for end of sm_lead */
      *p++ = c;
    for (++i; i < ccnt; ++i)
      *p++ = getc(fd);                          /* <salfrom> */
    *p++ = NUL;

    /* <saltolen> <salto> */
    smp->sm_to = read_cnt_string(fd, 1, &ccnt);
    if (ccnt < 0) {
      vim_free(smp->sm_lead);
      return ccnt;
    }

    if (has_mbyte) {
      /* convert the multi-byte strings to wide char strings */
      smp->sm_lead_w = mb_str2wide(smp->sm_lead);
      smp->sm_leadlen = mb_charlen(smp->sm_lead);
      if (smp->sm_oneof == NULL)
        smp->sm_oneof_w = NULL;
      else
        smp->sm_oneof_w = mb_str2wide(smp->sm_oneof);
      if (smp->sm_to == NULL)
        smp->sm_to_w = NULL;
      else
        smp->sm_to_w = mb_str2wide(smp->sm_to);
      if (smp->sm_lead_w == NULL
          || (smp->sm_oneof_w == NULL && smp->sm_oneof != NULL)
          || (smp->sm_to_w == NULL && smp->sm_to != NULL)) {
        vim_free(smp->sm_lead);
        vim_free(smp->sm_to);
        vim_free(smp->sm_lead_w);
        vim_free(smp->sm_oneof_w);
        vim_free(smp->sm_to_w);
        return SP_OTHERERROR;
      }
    }
  }

  if (gap->ga_len > 0) {
    /* Add one extra entry to mark the end with an empty sm_lead.  Avoids
     * that we need to check the index every time. */
    smp = &((salitem_T *)gap->ga_data)[gap->ga_len];
    if ((p = alloc(1)) == NULL)
      return SP_OTHERERROR;
    p[0] = NUL;
    smp->sm_lead = p;
    smp->sm_leadlen = 0;
    smp->sm_oneof = NULL;
    smp->sm_rules = p;
    smp->sm_to = NULL;
    if (has_mbyte) {
      smp->sm_lead_w = mb_str2wide(smp->sm_lead);
      smp->sm_leadlen = 0;
      smp->sm_oneof_w = NULL;
      smp->sm_to_w = NULL;
    }
    ++gap->ga_len;
  }

  /* Fill the first-index table. */
  set_sal_first(slang);

  return 0;
}

/*
 * Read SN_WORDS: <word> ...
 * Return SP_*ERROR flags.
 */
static int read_words_section(FILE *fd, slang_T *lp, int len)
{
  int done = 0;
  int i;
  int c;
  char_u word[MAXWLEN];

  while (done < len) {
    /* Read one word at a time. */
    for (i = 0;; ++i) {
      c = getc(fd);
      if (c == EOF)
        return SP_TRUNCERROR;
      word[i] = c;
      if (word[i] == NUL)
        break;
      if (i == MAXWLEN - 1)
        return SP_FORMERROR;
    }

    /* Init the count to 10. */
    count_common_word(lp, word, -1, 10);
    done += i + 1;
  }
  return 0;
}

/*
 * Add a word to the hashtable of common words.
 * If it's already there then the counter is increased.
 */
static void 
count_common_word (
    slang_T *lp,
    char_u *word,
    int len,                    /* word length, -1 for upto NUL */
    int count                  /* 1 to count once, 10 to init */
)
{
  hash_T hash;
  hashitem_T  *hi;
  wordcount_T *wc;
  char_u buf[MAXWLEN];
  char_u      *p;

  if (len == -1)
    p = word;
  else {
    vim_strncpy(buf, word, len);
    p = buf;
  }

  hash = hash_hash(p);
  hi = hash_lookup(&lp->sl_wordcount, p, hash);
  if (HASHITEM_EMPTY(hi)) {
    wc = (wordcount_T *)alloc((unsigned)(sizeof(wordcount_T) + STRLEN(p)));
    if (wc == NULL)
      return;
    STRCPY(wc->wc_word, p);
    wc->wc_count = count;
    hash_add_item(&lp->sl_wordcount, hi, wc->wc_word, hash);
  } else   {
    wc = HI2WC(hi);
    if ((wc->wc_count += count) < (unsigned)count)      /* check for overflow */
      wc->wc_count = MAXWORDCOUNT;
  }
}

/*
 * Adjust the score of common words.
 */
static int 
score_wordcount_adj (
    slang_T *slang,
    int score,
    char_u *word,
    int split                  /* word was split, less bonus */
)
{
  hashitem_T  *hi;
  wordcount_T *wc;
  int bonus;
  int newscore;

  hi = hash_find(&slang->sl_wordcount, word);
  if (!HASHITEM_EMPTY(hi)) {
    wc = HI2WC(hi);
    if (wc->wc_count < SCORE_THRES2)
      bonus = SCORE_COMMON1;
    else if (wc->wc_count < SCORE_THRES3)
      bonus = SCORE_COMMON2;
    else
      bonus = SCORE_COMMON3;
    if (split)
      newscore = score - bonus / 2;
    else
      newscore = score - bonus;
    if (newscore < 0)
      return 0;
    return newscore;
  }
  return score;
}

/*
 * SN_SOFO: <sofofromlen> <sofofrom> <sofotolen> <sofoto>
 * Return SP_*ERROR flags.
 */
static int read_sofo_section(FILE *fd, slang_T *slang)
{
  int cnt;
  char_u      *from, *to;
  int res;

  slang->sl_sofo = TRUE;

  /* <sofofromlen> <sofofrom> */
  from = read_cnt_string(fd, 2, &cnt);
  if (cnt < 0)
    return cnt;

  /* <sofotolen> <sofoto> */
  to = read_cnt_string(fd, 2, &cnt);
  if (cnt < 0) {
    vim_free(from);
    return cnt;
  }

  /* Store the info in slang->sl_sal and/or slang->sl_sal_first. */
  if (from != NULL && to != NULL)
    res = set_sofo(slang, from, to);
  else if (from != NULL || to != NULL)
    res = SP_FORMERROR;        /* only one of two strings is an error */
  else
    res = 0;

  vim_free(from);
  vim_free(to);
  return res;
}

/*
 * Read the compound section from the .spl file:
 *	<compmax> <compminlen> <compsylmax> <compoptions> <compflags>
 * Returns SP_*ERROR flags.
 */
static int read_compound(FILE *fd, slang_T *slang, int len)
{
  int todo = len;
  int c;
  int atstart;
  char_u      *pat;
  char_u      *pp;
  char_u      *cp;
  char_u      *ap;
  char_u      *crp;
  int cnt;
  garray_T    *gap;

  if (todo < 2)
    return SP_FORMERROR;        /* need at least two bytes */

  --todo;
  c = getc(fd);                                         /* <compmax> */
  if (c < 2)
    c = MAXWLEN;
  slang->sl_compmax = c;

  --todo;
  c = getc(fd);                                         /* <compminlen> */
  if (c < 1)
    c = 0;
  slang->sl_compminlen = c;

  --todo;
  c = getc(fd);                                         /* <compsylmax> */
  if (c < 1)
    c = MAXWLEN;
  slang->sl_compsylmax = c;

  c = getc(fd);                                         /* <compoptions> */
  if (c != 0)
    ungetc(c, fd);          /* be backwards compatible with Vim 7.0b */
  else {
    --todo;
    c = getc(fd);           /* only use the lower byte for now */
    --todo;
    slang->sl_compoptions = c;

    gap = &slang->sl_comppat;
    c = get2c(fd);                                      /* <comppatcount> */
    todo -= 2;
    ga_init2(gap, sizeof(char_u *), c);
    if (ga_grow(gap, c) == OK)
      while (--c >= 0) {
        ((char_u **)(gap->ga_data))[gap->ga_len++] =
          read_cnt_string(fd, 1, &cnt);
        /* <comppatlen> <comppattext> */
        if (cnt < 0)
          return cnt;
        todo -= cnt + 1;
      }
  }
  if (todo < 0)
    return SP_FORMERROR;

  /* Turn the COMPOUNDRULE items into a regexp pattern:
   * "a[bc]/a*b+" -> "^\(a[bc]\|a*b\+\)$".
   * Inserting backslashes may double the length, "^\(\)$<Nul>" is 7 bytes.
   * Conversion to utf-8 may double the size. */
  c = todo * 2 + 7;
  if (enc_utf8)
    c += todo * 2;
  pat = alloc((unsigned)c);
  if (pat == NULL)
    return SP_OTHERERROR;

  /* We also need a list of all flags that can appear at the start and one
   * for all flags. */
  cp = alloc(todo + 1);
  if (cp == NULL) {
    vim_free(pat);
    return SP_OTHERERROR;
  }
  slang->sl_compstartflags = cp;
  *cp = NUL;

  ap = alloc(todo + 1);
  if (ap == NULL) {
    vim_free(pat);
    return SP_OTHERERROR;
  }
  slang->sl_compallflags = ap;
  *ap = NUL;

  /* And a list of all patterns in their original form, for checking whether
   * compounding may work in match_compoundrule().  This is freed when we
   * encounter a wildcard, the check doesn't work then. */
  crp = alloc(todo + 1);
  slang->sl_comprules = crp;

  pp = pat;
  *pp++ = '^';
  *pp++ = '\\';
  *pp++ = '(';

  atstart = 1;
  while (todo-- > 0) {
    c = getc(fd);                                       /* <compflags> */
    if (c == EOF) {
      vim_free(pat);
      return SP_TRUNCERROR;
    }

    /* Add all flags to "sl_compallflags". */
    if (vim_strchr((char_u *)"?*+[]/", c) == NULL
        && !byte_in_str(slang->sl_compallflags, c)) {
      *ap++ = c;
      *ap = NUL;
    }

    if (atstart != 0) {
      /* At start of item: copy flags to "sl_compstartflags".  For a
       * [abc] item set "atstart" to 2 and copy up to the ']'. */
      if (c == '[')
        atstart = 2;
      else if (c == ']')
        atstart = 0;
      else {
        if (!byte_in_str(slang->sl_compstartflags, c)) {
          *cp++ = c;
          *cp = NUL;
        }
        if (atstart == 1)
          atstart = 0;
      }
    }

    /* Copy flag to "sl_comprules", unless we run into a wildcard. */
    if (crp != NULL) {
      if (c == '?' || c == '+' || c == '*') {
        vim_free(slang->sl_comprules);
        slang->sl_comprules = NULL;
        crp = NULL;
      } else
        *crp++ = c;
    }

    if (c == '/') {         /* slash separates two items */
      *pp++ = '\\';
      *pp++ = '|';
      atstart = 1;
    } else   {              /* normal char, "[abc]" and '*' are copied as-is */
      if (c == '?' || c == '+' || c == '~')
        *pp++ = '\\';               /* "a?" becomes "a\?", "a+" becomes "a\+" */
      if (enc_utf8)
        pp += mb_char2bytes(c, pp);
      else
        *pp++ = c;
    }
  }

  *pp++ = '\\';
  *pp++ = ')';
  *pp++ = '$';
  *pp = NUL;

  if (crp != NULL)
    *crp = NUL;

  slang->sl_compprog = vim_regcomp(pat, RE_MAGIC + RE_STRING + RE_STRICT);
  vim_free(pat);
  if (slang->sl_compprog == NULL)
    return SP_FORMERROR;

  return 0;
}

/*
 * Return TRUE if byte "n" appears in "str".
 * Like strchr() but independent of locale.
 */
static int byte_in_str(char_u *str, int n)
{
  char_u      *p;

  for (p = str; *p != NUL; ++p)
    if (*p == n)
      return TRUE;
  return FALSE;
}

#define SY_MAXLEN   30
typedef struct syl_item_S {
  char_u sy_chars[SY_MAXLEN];               /* the sequence of chars */
  int sy_len;
} syl_item_T;

/*
 * Truncate "slang->sl_syllable" at the first slash and put the following items
 * in "slang->sl_syl_items".
 */
static int init_syl_tab(slang_T *slang)
{
  char_u      *p;
  char_u      *s;
  int l;
  syl_item_T  *syl;

  ga_init2(&slang->sl_syl_items, sizeof(syl_item_T), 4);
  p = vim_strchr(slang->sl_syllable, '/');
  while (p != NULL) {
    *p++ = NUL;
    if (*p == NUL)          /* trailing slash */
      break;
    s = p;
    p = vim_strchr(p, '/');
    if (p == NULL)
      l = (int)STRLEN(s);
    else
      l = (int)(p - s);
    if (l >= SY_MAXLEN)
      return SP_FORMERROR;
    if (ga_grow(&slang->sl_syl_items, 1) == FAIL)
      return SP_OTHERERROR;
    syl = ((syl_item_T *)slang->sl_syl_items.ga_data)
          + slang->sl_syl_items.ga_len++;
    vim_strncpy(syl->sy_chars, s, l);
    syl->sy_len = l;
  }
  return OK;
}

/*
 * Count the number of syllables in "word".
 * When "word" contains spaces the syllables after the last space are counted.
 * Returns zero if syllables are not defines.
 */
static int count_syllables(slang_T *slang, char_u *word)
{
  int cnt = 0;
  int skip = FALSE;
  char_u      *p;
  int len;
  int i;
  syl_item_T  *syl;
  int c;

  if (slang->sl_syllable == NULL)
    return 0;

  for (p = word; *p != NUL; p += len) {
    /* When running into a space reset counter. */
    if (*p == ' ') {
      len = 1;
      cnt = 0;
      continue;
    }

    /* Find longest match of syllable items. */
    len = 0;
    for (i = 0; i < slang->sl_syl_items.ga_len; ++i) {
      syl = ((syl_item_T *)slang->sl_syl_items.ga_data) + i;
      if (syl->sy_len > len
          && STRNCMP(p, syl->sy_chars, syl->sy_len) == 0)
        len = syl->sy_len;
    }
    if (len != 0) {     /* found a match, count syllable  */
      ++cnt;
      skip = FALSE;
    } else   {
      /* No recognized syllable item, at least a syllable char then? */
      c = mb_ptr2char(p);
      len = (*mb_ptr2len)(p);
      if (vim_strchr(slang->sl_syllable, c) == NULL)
        skip = FALSE;               /* No, search for next syllable */
      else if (!skip) {
        ++cnt;                      /* Yes, count it */
        skip = TRUE;                /* don't count following syllable chars */
      }
    }
  }
  return cnt;
}

/*
 * Set the SOFOFROM and SOFOTO items in language "lp".
 * Returns SP_*ERROR flags when there is something wrong.
 */
static int set_sofo(slang_T *lp, char_u *from, char_u *to)
{
  int i;

  garray_T    *gap;
  char_u      *s;
  char_u      *p;
  int c;
  int         *inp;

  if (has_mbyte) {
    /* Use "sl_sal" as an array with 256 pointers to a list of wide
     * characters.  The index is the low byte of the character.
     * The list contains from-to pairs with a terminating NUL.
     * sl_sal_first[] is used for latin1 "from" characters. */
    gap = &lp->sl_sal;
    ga_init2(gap, sizeof(int *), 1);
    if (ga_grow(gap, 256) == FAIL)
      return SP_OTHERERROR;
    vim_memset(gap->ga_data, 0, sizeof(int *) * 256);
    gap->ga_len = 256;

    /* First count the number of items for each list.  Temporarily use
     * sl_sal_first[] for this. */
    for (p = from, s = to; *p != NUL && *s != NUL; ) {
      c = mb_cptr2char_adv(&p);
      mb_cptr_adv(s);
      if (c >= 256)
        ++lp->sl_sal_first[c & 0xff];
    }
    if (*p != NUL || *s != NUL)             /* lengths differ */
      return SP_FORMERROR;

    /* Allocate the lists. */
    for (i = 0; i < 256; ++i)
      if (lp->sl_sal_first[i] > 0) {
        p = alloc(sizeof(int) * (lp->sl_sal_first[i] * 2 + 1));
        if (p == NULL)
          return SP_OTHERERROR;
        ((int **)gap->ga_data)[i] = (int *)p;
        *(int *)p = 0;
      }

    /* Put the characters up to 255 in sl_sal_first[] the rest in a sl_sal
     * list. */
    vim_memset(lp->sl_sal_first, 0, sizeof(salfirst_T) * 256);
    for (p = from, s = to; *p != NUL && *s != NUL; ) {
      c = mb_cptr2char_adv(&p);
      i = mb_cptr2char_adv(&s);
      if (c >= 256) {
        /* Append the from-to chars at the end of the list with
         * the low byte. */
        inp = ((int **)gap->ga_data)[c & 0xff];
        while (*inp != 0)
          ++inp;
        *inp++ = c;                     /* from char */
        *inp++ = i;                     /* to char */
        *inp++ = NUL;                   /* NUL at the end */
      } else
        /* mapping byte to char is done in sl_sal_first[] */
        lp->sl_sal_first[c] = i;
    }
  } else   {
    /* mapping bytes to bytes is done in sl_sal_first[] */
    if (STRLEN(from) != STRLEN(to))
      return SP_FORMERROR;

    for (i = 0; to[i] != NUL; ++i)
      lp->sl_sal_first[from[i]] = to[i];
    lp->sl_sal.ga_len = 1;              /* indicates we have soundfolding */
  }

  return 0;
}

/*
 * Fill the first-index table for "lp".
 */
static void set_sal_first(slang_T *lp)
{
  salfirst_T  *sfirst;
  int i;
  salitem_T   *smp;
  int c;
  garray_T    *gap = &lp->sl_sal;

  sfirst = lp->sl_sal_first;
  for (i = 0; i < 256; ++i)
    sfirst[i] = -1;
  smp = (salitem_T *)gap->ga_data;
  for (i = 0; i < gap->ga_len; ++i) {
    if (has_mbyte)
      /* Use the lowest byte of the first character.  For latin1 it's
       * the character, for other encodings it should differ for most
       * characters. */
      c = *smp[i].sm_lead_w & 0xff;
    else
      c = *smp[i].sm_lead;
    if (sfirst[c] == -1) {
      sfirst[c] = i;
      if (has_mbyte) {
        int n;

        /* Make sure all entries with this byte are following each
         * other.  Move the ones that are in the wrong position.  Do
         * keep the same ordering! */
        while (i + 1 < gap->ga_len
               && (*smp[i + 1].sm_lead_w & 0xff) == c)
          /* Skip over entry with same index byte. */
          ++i;

        for (n = 1; i + n < gap->ga_len; ++n)
          if ((*smp[i + n].sm_lead_w & 0xff) == c) {
            salitem_T tsal;

            /* Move entry with same index byte after the entries
             * we already found. */
            ++i;
            --n;
            tsal = smp[i + n];
            mch_memmove(smp + i + 1, smp + i,
                sizeof(salitem_T) * n);
            smp[i] = tsal;
          }
      }
    }
  }
}

/*
 * Turn a multi-byte string into a wide character string.
 * Return it in allocated memory (NULL for out-of-memory)
 */
static int *mb_str2wide(char_u *s)
{
  int         *res;
  char_u      *p;
  int i = 0;

  res = (int *)alloc(sizeof(int) * (mb_charlen(s) + 1));
  if (res != NULL) {
    for (p = s; *p != NUL; )
      res[i++] = mb_ptr2char_adv(&p);
    res[i] = NUL;
  }
  return res;
}

/*
 * Read a tree from the .spl or .sug file.
 * Allocates the memory and stores pointers in "bytsp" and "idxsp".
 * This is skipped when the tree has zero length.
 * Returns zero when OK, SP_ value for an error.
 */
static int 
spell_read_tree (
    FILE *fd,
    char_u **bytsp,
    idx_T **idxsp,
    int prefixtree,                 /* TRUE for the prefix tree */
    int prefixcnt                  /* when "prefixtree" is TRUE: prefix count */
)
{
  int len;
  int idx;
  char_u      *bp;
  idx_T       *ip;

  /* The tree size was computed when writing the file, so that we can
   * allocate it as one long block. <nodecount> */
  len = get4c(fd);
  if (len < 0)
    return SP_TRUNCERROR;
  if (len > 0) {
    /* Allocate the byte array. */
    bp = lalloc((long_u)len, TRUE);
    if (bp == NULL)
      return SP_OTHERERROR;
    *bytsp = bp;

    /* Allocate the index array. */
    ip = (idx_T *)lalloc_clear((long_u)(len * sizeof(int)), TRUE);
    if (ip == NULL)
      return SP_OTHERERROR;
    *idxsp = ip;

    /* Recursively read the tree and store it in the array. */
    idx = read_tree_node(fd, bp, ip, len, 0, prefixtree, prefixcnt);
    if (idx < 0)
      return idx;
  }
  return 0;
}

/*
 * Read one row of siblings from the spell file and store it in the byte array
 * "byts" and index array "idxs".  Recursively read the children.
 *
 * NOTE: The code here must match put_node()!
 *
 * Returns the index (>= 0) following the siblings.
 * Returns SP_TRUNCERROR if the file is shorter than expected.
 * Returns SP_FORMERROR if there is a format error.
 */
static idx_T 
read_tree_node (
    FILE *fd,
    char_u *byts,
    idx_T *idxs,
    int maxidx,                         /* size of arrays */
    idx_T startidx,                     /* current index in "byts" and "idxs" */
    int prefixtree,                     /* TRUE for reading PREFIXTREE */
    int maxprefcondnr                  /* maximum for <prefcondnr> */
)
{
  int len;
  int i;
  int n;
  idx_T idx = startidx;
  int c;
  int c2;
#define SHARED_MASK     0x8000000

  len = getc(fd);                                       /* <siblingcount> */
  if (len <= 0)
    return SP_TRUNCERROR;

  if (startidx + len >= maxidx)
    return SP_FORMERROR;
  byts[idx++] = len;

  /* Read the byte values, flag/region bytes and shared indexes. */
  for (i = 1; i <= len; ++i) {
    c = getc(fd);                                       /* <byte> */
    if (c < 0)
      return SP_TRUNCERROR;
    if (c <= BY_SPECIAL) {
      if (c == BY_NOFLAGS && !prefixtree) {
        /* No flags, all regions. */
        idxs[idx] = 0;
        c = 0;
      } else if (c != BY_INDEX)   {
        if (prefixtree) {
          /* Read the optional pflags byte, the prefix ID and the
           * condition nr.  In idxs[] store the prefix ID in the low
           * byte, the condition index shifted up 8 bits, the flags
           * shifted up 24 bits. */
          if (c == BY_FLAGS)
            c = getc(fd) << 24;                         /* <pflags> */
          else
            c = 0;

          c |= getc(fd);                                /* <affixID> */

          n = get2c(fd);                                /* <prefcondnr> */
          if (n >= maxprefcondnr)
            return SP_FORMERROR;
          c |= (n << 8);
        } else   {   /* c must be BY_FLAGS or BY_FLAGS2 */
                     /* Read flags and optional region and prefix ID.  In
                      * idxs[] the flags go in the low two bytes, region above
                      * that and prefix ID above the region. */
          c2 = c;
          c = getc(fd);                                 /* <flags> */
          if (c2 == BY_FLAGS2)
            c = (getc(fd) << 8) + c;                    /* <flags2> */
          if (c & WF_REGION)
            c = (getc(fd) << 16) + c;                   /* <region> */
          if (c & WF_AFX)
            c = (getc(fd) << 24) + c;                   /* <affixID> */
        }

        idxs[idx] = c;
        c = 0;
      } else   { /* c == BY_INDEX */
        /* <nodeidx> */
        n = get3c(fd);
        if (n < 0 || n >= maxidx)
          return SP_FORMERROR;
        idxs[idx] = n + SHARED_MASK;
        c = getc(fd);                                   /* <xbyte> */
      }
    }
    byts[idx++] = c;
  }

  /* Recursively read the children for non-shared siblings.
   * Skip the end-of-word ones (zero byte value) and the shared ones (and
   * remove SHARED_MASK) */
  for (i = 1; i <= len; ++i)
    if (byts[startidx + i] != 0) {
      if (idxs[startidx + i] & SHARED_MASK)
        idxs[startidx + i] &= ~SHARED_MASK;
      else {
        idxs[startidx + i] = idx;
        idx = read_tree_node(fd, byts, idxs, maxidx, idx,
            prefixtree, maxprefcondnr);
        if (idx < 0)
          break;
      }
    }

  return idx;
}

/*
 * Parse 'spelllang' and set w_s->b_langp accordingly.
 * Returns NULL if it's OK, an error message otherwise.
 */
char_u *did_set_spelllang(win_T *wp)
{
  garray_T ga;
  char_u      *splp;
  char_u      *region;
  char_u region_cp[3];
  int filename;
  int region_mask;
  slang_T     *slang;
  int c;
  char_u lang[MAXWLEN + 1];
  char_u spf_name[MAXPATHL];
  int len;
  char_u      *p;
  int round;
  char_u      *spf;
  char_u      *use_region = NULL;
  int dont_use_region = FALSE;
  int nobreak = FALSE;
  int i, j;
  langp_T     *lp, *lp2;
  static int recursive = FALSE;
  char_u      *ret_msg = NULL;
  char_u      *spl_copy;

  /* We don't want to do this recursively.  May happen when a language is
   * not available and the SpellFileMissing autocommand opens a new buffer
   * in which 'spell' is set. */
  if (recursive)
    return NULL;
  recursive = TRUE;

  ga_init2(&ga, sizeof(langp_T), 2);
  clear_midword(wp);

  /* Make a copy of 'spelllang', the SpellFileMissing autocommands may change
   * it under our fingers. */
  spl_copy = vim_strsave(wp->w_s->b_p_spl);
  if (spl_copy == NULL)
    goto theend;

  wp->w_s->b_cjk = 0;

  /* Loop over comma separated language names. */
  for (splp = spl_copy; *splp != NUL; ) {
    /* Get one language name. */
    copy_option_part(&splp, lang, MAXWLEN, ",");
    region = NULL;
    len = (int)STRLEN(lang);

    if (STRCMP(lang, "cjk") == 0) {
      wp->w_s->b_cjk = 1;
      continue;
    }

    /* If the name ends in ".spl" use it as the name of the spell file.
     * If there is a region name let "region" point to it and remove it
     * from the name. */
    if (len > 4 && fnamecmp(lang + len - 4, ".spl") == 0) {
      filename = TRUE;

      /* Locate a region and remove it from the file name. */
      p = vim_strchr(gettail(lang), '_');
      if (p != NULL && ASCII_ISALPHA(p[1]) && ASCII_ISALPHA(p[2])
          && !ASCII_ISALPHA(p[3])) {
        vim_strncpy(region_cp, p + 1, 2);
        mch_memmove(p, p + 3, len - (p - lang) - 2);
        len -= 3;
        region = region_cp;
      } else
        dont_use_region = TRUE;

      /* Check if we loaded this language before. */
      for (slang = first_lang; slang != NULL; slang = slang->sl_next)
        if (fullpathcmp(lang, slang->sl_fname, FALSE) == FPC_SAME)
          break;
    } else   {
      filename = FALSE;
      if (len > 3 && lang[len - 3] == '_') {
        region = lang + len - 2;
        len -= 3;
        lang[len] = NUL;
      } else
        dont_use_region = TRUE;

      /* Check if we loaded this language before. */
      for (slang = first_lang; slang != NULL; slang = slang->sl_next)
        if (STRICMP(lang, slang->sl_name) == 0)
          break;
    }

    if (region != NULL) {
      /* If the region differs from what was used before then don't
       * use it for 'spellfile'. */
      if (use_region != NULL && STRCMP(region, use_region) != 0)
        dont_use_region = TRUE;
      use_region = region;
    }

    /* If not found try loading the language now. */
    if (slang == NULL) {
      if (filename)
        (void)spell_load_file(lang, lang, NULL, FALSE);
      else {
        spell_load_lang(lang);
        /* SpellFileMissing autocommands may do anything, including
         * destroying the buffer we are using... */
        if (!buf_valid(wp->w_buffer)) {
          ret_msg =
            (char_u *)"E797: SpellFileMissing autocommand deleted buffer";
          goto theend;
        }
      }
    }

    /*
     * Loop over the languages, there can be several files for "lang".
     */
    for (slang = first_lang; slang != NULL; slang = slang->sl_next)
      if (filename ? fullpathcmp(lang, slang->sl_fname, FALSE) == FPC_SAME
          : STRICMP(lang, slang->sl_name) == 0) {
        region_mask = REGION_ALL;
        if (!filename && region != NULL) {
          /* find region in sl_regions */
          c = find_region(slang->sl_regions, region);
          if (c == REGION_ALL) {
            if (slang->sl_add) {
              if (*slang->sl_regions != NUL)
                /* This addition file is for other regions. */
                region_mask = 0;
            } else
              /* This is probably an error.  Give a warning and
               * accept the words anyway. */
              smsg((char_u *)
                  _("Warning: region %s not supported"),
                  region);
          } else
            region_mask = 1 << c;
        }

        if (region_mask != 0) {
          if (ga_grow(&ga, 1) == FAIL) {
            ga_clear(&ga);
            ret_msg = e_outofmem;
            goto theend;
          }
          LANGP_ENTRY(ga, ga.ga_len)->lp_slang = slang;
          LANGP_ENTRY(ga, ga.ga_len)->lp_region = region_mask;
          ++ga.ga_len;
          use_midword(slang, wp);
          if (slang->sl_nobreak)
            nobreak = TRUE;
        }
      }
  }

  /* round 0: load int_wordlist, if possible.
   * round 1: load first name in 'spellfile'.
   * round 2: load second name in 'spellfile.
   * etc. */
  spf = curwin->w_s->b_p_spf;
  for (round = 0; round == 0 || *spf != NUL; ++round) {
    if (round == 0) {
      /* Internal wordlist, if there is one. */
      if (int_wordlist == NULL)
        continue;
      int_wordlist_spl(spf_name);
    } else   {
      /* One entry in 'spellfile'. */
      copy_option_part(&spf, spf_name, MAXPATHL - 5, ",");
      STRCAT(spf_name, ".spl");

      /* If it was already found above then skip it. */
      for (c = 0; c < ga.ga_len; ++c) {
        p = LANGP_ENTRY(ga, c)->lp_slang->sl_fname;
        if (p != NULL && fullpathcmp(spf_name, p, FALSE) == FPC_SAME)
          break;
      }
      if (c < ga.ga_len)
        continue;
    }

    /* Check if it was loaded already. */
    for (slang = first_lang; slang != NULL; slang = slang->sl_next)
      if (fullpathcmp(spf_name, slang->sl_fname, FALSE) == FPC_SAME)
        break;
    if (slang == NULL) {
      /* Not loaded, try loading it now.  The language name includes the
       * region name, the region is ignored otherwise.  for int_wordlist
       * use an arbitrary name. */
      if (round == 0)
        STRCPY(lang, "internal wordlist");
      else {
        vim_strncpy(lang, gettail(spf_name), MAXWLEN);
        p = vim_strchr(lang, '.');
        if (p != NULL)
          *p = NUL;             /* truncate at ".encoding.add" */
      }
      slang = spell_load_file(spf_name, lang, NULL, TRUE);

      /* If one of the languages has NOBREAK we assume the addition
       * files also have this. */
      if (slang != NULL && nobreak)
        slang->sl_nobreak = TRUE;
    }
    if (slang != NULL && ga_grow(&ga, 1) == OK) {
      region_mask = REGION_ALL;
      if (use_region != NULL && !dont_use_region) {
        /* find region in sl_regions */
        c = find_region(slang->sl_regions, use_region);
        if (c != REGION_ALL)
          region_mask = 1 << c;
        else if (*slang->sl_regions != NUL)
          /* This spell file is for other regions. */
          region_mask = 0;
      }

      if (region_mask != 0) {
        LANGP_ENTRY(ga, ga.ga_len)->lp_slang = slang;
        LANGP_ENTRY(ga, ga.ga_len)->lp_sallang = NULL;
        LANGP_ENTRY(ga, ga.ga_len)->lp_replang = NULL;
        LANGP_ENTRY(ga, ga.ga_len)->lp_region = region_mask;
        ++ga.ga_len;
        use_midword(slang, wp);
      }
    }
  }

  /* Everything is fine, store the new b_langp value. */
  ga_clear(&wp->w_s->b_langp);
  wp->w_s->b_langp = ga;

  /* For each language figure out what language to use for sound folding and
   * REP items.  If the language doesn't support it itself use another one
   * with the same name.  E.g. for "en-math" use "en". */
  for (i = 0; i < ga.ga_len; ++i) {
    lp = LANGP_ENTRY(ga, i);

    /* sound folding */
    if (lp->lp_slang->sl_sal.ga_len > 0)
      /* language does sound folding itself */
      lp->lp_sallang = lp->lp_slang;
    else
      /* find first similar language that does sound folding */
      for (j = 0; j < ga.ga_len; ++j) {
        lp2 = LANGP_ENTRY(ga, j);
        if (lp2->lp_slang->sl_sal.ga_len > 0
            && STRNCMP(lp->lp_slang->sl_name,
                lp2->lp_slang->sl_name, 2) == 0) {
          lp->lp_sallang = lp2->lp_slang;
          break;
        }
      }

    /* REP items */
    if (lp->lp_slang->sl_rep.ga_len > 0)
      /* language has REP items itself */
      lp->lp_replang = lp->lp_slang;
    else
      /* find first similar language that has REP items */
      for (j = 0; j < ga.ga_len; ++j) {
        lp2 = LANGP_ENTRY(ga, j);
        if (lp2->lp_slang->sl_rep.ga_len > 0
            && STRNCMP(lp->lp_slang->sl_name,
                lp2->lp_slang->sl_name, 2) == 0) {
          lp->lp_replang = lp2->lp_slang;
          break;
        }
      }
  }

theend:
  vim_free(spl_copy);
  recursive = FALSE;
  return ret_msg;
}

/*
 * Clear the midword characters for buffer "buf".
 */
static void clear_midword(win_T *wp)
{
  vim_memset(wp->w_s->b_spell_ismw, 0, 256);
  vim_free(wp->w_s->b_spell_ismw_mb);
  wp->w_s->b_spell_ismw_mb = NULL;
}

/*
 * Use the "sl_midword" field of language "lp" for buffer "buf".
 * They add up to any currently used midword characters.
 */
static void use_midword(slang_T *lp, win_T *wp)
{
  char_u      *p;

  if (lp->sl_midword == NULL)       /* there aren't any */
    return;

  for (p = lp->sl_midword; *p != NUL; )
    if (has_mbyte) {
      int c, l, n;
      char_u  *bp;

      c = mb_ptr2char(p);
      l = (*mb_ptr2len)(p);
      if (c < 256 && l <= 2)
        wp->w_s->b_spell_ismw[c] = TRUE;
      else if (wp->w_s->b_spell_ismw_mb == NULL)
        /* First multi-byte char in "b_spell_ismw_mb". */
        wp->w_s->b_spell_ismw_mb = vim_strnsave(p, l);
      else {
        /* Append multi-byte chars to "b_spell_ismw_mb". */
        n = (int)STRLEN(wp->w_s->b_spell_ismw_mb);
        bp = vim_strnsave(wp->w_s->b_spell_ismw_mb, n + l);
        if (bp != NULL) {
          vim_free(wp->w_s->b_spell_ismw_mb);
          wp->w_s->b_spell_ismw_mb = bp;
          vim_strncpy(bp + n, p, l);
        }
      }
      p += l;
    } else
      wp->w_s->b_spell_ismw[*p++] = TRUE;
}

/*
 * Find the region "region[2]" in "rp" (points to "sl_regions").
 * Each region is simply stored as the two characters of it's name.
 * Returns the index if found (first is 0), REGION_ALL if not found.
 */
static int find_region(char_u *rp, char_u *region)
{
  int i;

  for (i = 0;; i += 2) {
    if (rp[i] == NUL)
      return REGION_ALL;
    if (rp[i] == region[0] && rp[i + 1] == region[1])
      break;
  }
  return i / 2;
}

/*
 * Return case type of word:
 * w word	0
 * Word		WF_ONECAP
 * W WORD	WF_ALLCAP
 * WoRd	wOrd	WF_KEEPCAP
 */
static int 
captype (
    char_u *word,
    char_u *end           /* When NULL use up to NUL byte. */
)
{
  char_u      *p;
  int c;
  int firstcap;
  int allcap;
  int past_second = FALSE;              /* past second word char */

  /* find first letter */
  for (p = word; !spell_iswordp_nmw(p, curwin); mb_ptr_adv(p))
    if (end == NULL ? *p == NUL : p >= end)
      return 0;             /* only non-word characters, illegal word */
  if (has_mbyte)
    c = mb_ptr2char_adv(&p);
  else
    c = *p++;
  firstcap = allcap = SPELL_ISUPPER(c);

  /*
   * Need to check all letters to find a word with mixed upper/lower.
   * But a word with an upper char only at start is a ONECAP.
   */
  for (; end == NULL ? *p != NUL : p < end; mb_ptr_adv(p))
    if (spell_iswordp_nmw(p, curwin)) {
      c = PTR2CHAR(p);
      if (!SPELL_ISUPPER(c)) {
        /* UUl -> KEEPCAP */
        if (past_second && allcap)
          return WF_KEEPCAP;
        allcap = FALSE;
      } else if (!allcap)
        /* UlU -> KEEPCAP */
        return WF_KEEPCAP;
      past_second = TRUE;
    }

  if (allcap)
    return WF_ALLCAP;
  if (firstcap)
    return WF_ONECAP;
  return 0;
}

/*
 * Like captype() but for a KEEPCAP word add ONECAP if the word starts with a
 * capital.  So that make_case_word() can turn WOrd into Word.
 * Add ALLCAP for "WOrD".
 */
static int badword_captype(char_u *word, char_u *end)
{
  int flags = captype(word, end);
  int c;
  int l, u;
  int first;
  char_u      *p;

  if (flags & WF_KEEPCAP) {
    /* Count the number of UPPER and lower case letters. */
    l = u = 0;
    first = FALSE;
    for (p = word; p < end; mb_ptr_adv(p)) {
      c = PTR2CHAR(p);
      if (SPELL_ISUPPER(c)) {
        ++u;
        if (p == word)
          first = TRUE;
      } else
        ++l;
    }

    /* If there are more UPPER than lower case letters suggest an
     * ALLCAP word.  Otherwise, if the first letter is UPPER then
     * suggest ONECAP.  Exception: "ALl" most likely should be "All",
     * require three upper case letters. */
    if (u > l && u > 2)
      flags |= WF_ALLCAP;
    else if (first)
      flags |= WF_ONECAP;

    if (u >= 2 && l >= 2)       /* maCARONI maCAroni */
      flags |= WF_MIXCAP;
  }
  return flags;
}

/*
 * Delete the internal wordlist and its .spl file.
 */
void spell_delete_wordlist(void)          {
  char_u fname[MAXPATHL];

  if (int_wordlist != NULL) {
    mch_remove(int_wordlist);
    int_wordlist_spl(fname);
    mch_remove(fname);
    vim_free(int_wordlist);
    int_wordlist = NULL;
  }
}

/*
 * Free all languages.
 */
void spell_free_all(void)          {
  slang_T     *slang;
  buf_T       *buf;

  /* Go through all buffers and handle 'spelllang'. <VN> */
  for (buf = firstbuf; buf != NULL; buf = buf->b_next)
    ga_clear(&buf->b_s.b_langp);

  while (first_lang != NULL) {
    slang = first_lang;
    first_lang = slang->sl_next;
    slang_free(slang);
  }

  spell_delete_wordlist();

  vim_free(repl_to);
  repl_to = NULL;
  vim_free(repl_from);
  repl_from = NULL;
}

/*
 * Clear all spelling tables and reload them.
 * Used after 'encoding' is set and when ":mkspell" was used.
 */
void spell_reload(void)          {
  win_T       *wp;

  /* Initialize the table for spell_iswordp(). */
  init_spell_chartab();

  /* Unload all allocated memory. */
  spell_free_all();

  /* Go through all buffers and handle 'spelllang'. */
  for (wp = firstwin; wp != NULL; wp = wp->w_next) {
    /* Only load the wordlists when 'spelllang' is set and there is a
     * window for this buffer in which 'spell' is set. */
    if (*wp->w_s->b_p_spl != NUL) {
      if (wp->w_p_spell) {
        (void)did_set_spelllang(wp);
        break;
      }
    }
  }
}

/*
 * Reload the spell file "fname" if it's loaded.
 */
static void 
spell_reload_one (
    char_u *fname,
    int added_word                 /* invoked through "zg" */
)
{
  slang_T     *slang;
  int didit = FALSE;

  for (slang = first_lang; slang != NULL; slang = slang->sl_next) {
    if (fullpathcmp(fname, slang->sl_fname, FALSE) == FPC_SAME) {
      slang_clear(slang);
      if (spell_load_file(fname, NULL, slang, FALSE) == NULL)
        /* reloading failed, clear the language */
        slang_clear(slang);
      redraw_all_later(SOME_VALID);
      didit = TRUE;
    }
  }

  /* When "zg" was used and the file wasn't loaded yet, should redo
   * 'spelllang' to load it now. */
  if (added_word && !didit)
    did_set_spelllang(curwin);
}


/*
 * Functions for ":mkspell".
 */

#define MAXLINELEN  500         /* Maximum length in bytes of a line in a .aff
                                   and .dic file. */
/*
 * Main structure to store the contents of a ".aff" file.
 */
typedef struct afffile_S {
  char_u      *af_enc;          /* "SET", normalized, alloc'ed string or NULL */
  int af_flagtype;              /* AFT_CHAR, AFT_LONG, AFT_NUM or AFT_CAPLONG */
  unsigned af_rare;             /* RARE ID for rare word */
  unsigned af_keepcase;         /* KEEPCASE ID for keep-case word */
  unsigned af_bad;              /* BAD ID for banned word */
  unsigned af_needaffix;        /* NEEDAFFIX ID */
  unsigned af_circumfix;        /* CIRCUMFIX ID */
  unsigned af_needcomp;         /* NEEDCOMPOUND ID */
  unsigned af_comproot;         /* COMPOUNDROOT ID */
  unsigned af_compforbid;       /* COMPOUNDFORBIDFLAG ID */
  unsigned af_comppermit;       /* COMPOUNDPERMITFLAG ID */
  unsigned af_nosuggest;        /* NOSUGGEST ID */
  int af_pfxpostpone;           /* postpone prefixes without chop string and
                                   without flags */
  hashtab_T af_pref;            /* hashtable for prefixes, affheader_T */
  hashtab_T af_suff;            /* hashtable for suffixes, affheader_T */
  hashtab_T af_comp;            /* hashtable for compound flags, compitem_T */
} afffile_T;

#define AFT_CHAR        0       /* flags are one character */
#define AFT_LONG        1       /* flags are two characters */
#define AFT_CAPLONG     2       /* flags are one or two characters */
#define AFT_NUM         3       /* flags are numbers, comma separated */

typedef struct affentry_S affentry_T;
/* Affix entry from ".aff" file.  Used for prefixes and suffixes. */
struct affentry_S {
  affentry_T  *ae_next;         /* next affix with same name/number */
  char_u      *ae_chop;         /* text to chop off basic word (can be NULL) */
  char_u      *ae_add;          /* text to add to basic word (can be NULL) */
  char_u      *ae_flags;        /* flags on the affix (can be NULL) */
  char_u      *ae_cond;         /* condition (NULL for ".") */
  regprog_T   *ae_prog;         /* regexp program for ae_cond or NULL */
  char ae_compforbid;           /* COMPOUNDFORBIDFLAG found */
  char ae_comppermit;           /* COMPOUNDPERMITFLAG found */
};

# define AH_KEY_LEN 17          /* 2 x 8 bytes + NUL */

/* Affix header from ".aff" file.  Used for af_pref and af_suff. */
typedef struct affheader_S {
  char_u ah_key[AH_KEY_LEN];        /* key for hashtab == name of affix */
  unsigned ah_flag;             /* affix name as number, uses "af_flagtype" */
  int ah_newID;                 /* prefix ID after renumbering; 0 if not used */
  int ah_combine;               /* suffix may combine with prefix */
  int ah_follows;               /* another affix block should be following */
  affentry_T  *ah_first;        /* first affix entry */
} affheader_T;

#define HI2AH(hi)   ((affheader_T *)(hi)->hi_key)

/* Flag used in compound items. */
typedef struct compitem_S {
  char_u ci_key[AH_KEY_LEN];        /* key for hashtab == name of compound */
  unsigned ci_flag;             /* affix name as number, uses "af_flagtype" */
  int ci_newID;                 /* affix ID after renumbering. */
} compitem_T;

#define HI2CI(hi)   ((compitem_T *)(hi)->hi_key)

/*
 * Structure that is used to store the items in the word tree.  This avoids
 * the need to keep track of each allocated thing, everything is freed all at
 * once after ":mkspell" is done.
 * Note: "sb_next" must be just before "sb_data" to make sure the alignment of
 * "sb_data" is correct for systems where pointers must be aligned on
 * pointer-size boundaries and sizeof(pointer) > sizeof(int) (e.g., Sparc).
 */
#define  SBLOCKSIZE 16000       /* size of sb_data */
typedef struct sblock_S sblock_T;
struct sblock_S {
  int sb_used;                  /* nr of bytes already in use */
  sblock_T    *sb_next;         /* next block in list */
  char_u sb_data[1];            /* data, actually longer */
};

/*
 * A node in the tree.
 */
typedef struct wordnode_S wordnode_T;
struct wordnode_S {
  union     /* shared to save space */
  {
    char_u hashkey[6];          /* the hash key, only used while compressing */
    int index;                  /* index in written nodes (valid after first
                                   round) */
  } wn_u1;
  union     /* shared to save space */
  {
    wordnode_T *next;           /* next node with same hash key */
    wordnode_T *wnode;          /* parent node that will write this node */
  } wn_u2;
  wordnode_T  *wn_child;        /* child (next byte in word) */
  wordnode_T  *wn_sibling;      /* next sibling (alternate byte in word,
                                   always sorted) */
  int wn_refs;                  /* Nr. of references to this node.  Only
                                   relevant for first node in a list of
                                   siblings, in following siblings it is
                                   always one. */
  char_u wn_byte;               /* Byte for this node. NUL for word end */

  /* Info for when "wn_byte" is NUL.
   * In PREFIXTREE "wn_region" is used for the prefcondnr.
   * In the soundfolded word tree "wn_flags" has the MSW of the wordnr and
   * "wn_region" the LSW of the wordnr. */
  char_u wn_affixID;            /* supported/required prefix ID or 0 */
  short_u wn_flags;             /* WF_ flags */
  short wn_region;              /* region mask */

#ifdef SPELL_PRINTTREE
  int wn_nr;                    /* sequence nr for printing */
#endif
};

#define WN_MASK  0xffff         /* mask relevant bits of "wn_flags" */

#define HI2WN(hi)    (wordnode_T *)((hi)->hi_key)

/*
 * Info used while reading the spell files.
 */
typedef struct spellinfo_S {
  wordnode_T  *si_foldroot;     /* tree with case-folded words */
  long si_foldwcount;           /* nr of words in si_foldroot */

  wordnode_T  *si_keeproot;     /* tree with keep-case words */
  long si_keepwcount;           /* nr of words in si_keeproot */

  wordnode_T  *si_prefroot;     /* tree with postponed prefixes */

  long si_sugtree;              /* creating the soundfolding trie */

  sblock_T    *si_blocks;       /* memory blocks used */
  long si_blocks_cnt;           /* memory blocks allocated */
  int si_did_emsg;              /* TRUE when ran out of memory */

  long si_compress_cnt;             /* words to add before lowering
                                       compression limit */
  wordnode_T  *si_first_free;   /* List of nodes that have been freed during
                                   compression, linked by "wn_child" field. */
  long si_free_count;           /* number of nodes in si_first_free */
#ifdef SPELL_PRINTTREE
  int si_wordnode_nr;           /* sequence nr for nodes */
#endif
  buf_T       *si_spellbuf;     /* buffer used to store soundfold word table */

  int si_ascii;                 /* handling only ASCII words */
  int si_add;                   /* addition file */
  int si_clear_chartab;             /* when TRUE clear char tables */
  int si_region;                /* region mask */
  vimconv_T si_conv;            /* for conversion to 'encoding' */
  int si_memtot;                /* runtime memory used */
  int si_verbose;               /* verbose messages */
  int si_msg_count;             /* number of words added since last message */
  char_u      *si_info;         /* info text chars or NULL  */
  int si_region_count;           /* number of regions supported (1 when there
                                    are no regions) */
  char_u si_region_name[17];        /* region names; used only if
                                     * si_region_count > 1) */

  garray_T si_rep;              /* list of fromto_T entries from REP lines */
  garray_T si_repsal;           /* list of fromto_T entries from REPSAL lines */
  garray_T si_sal;              /* list of fromto_T entries from SAL lines */
  char_u      *si_sofofr;       /* SOFOFROM text */
  char_u      *si_sofoto;       /* SOFOTO text */
  int si_nosugfile;             /* NOSUGFILE item found */
  int si_nosplitsugs;           /* NOSPLITSUGS item found */
  int si_followup;              /* soundsalike: ? */
  int si_collapse;              /* soundsalike: ? */
  hashtab_T si_commonwords;     /* hashtable for common words */
  time_t si_sugtime;            /* timestamp for .sug file */
  int si_rem_accents;           /* soundsalike: remove accents */
  garray_T si_map;              /* MAP info concatenated */
  char_u      *si_midword;      /* MIDWORD chars or NULL  */
  int si_compmax;               /* max nr of words for compounding */
  int si_compminlen;            /* minimal length for compounding */
  int si_compsylmax;            /* max nr of syllables for compounding */
  int si_compoptions;           /* COMP_ flags */
  garray_T si_comppat;          /* CHECKCOMPOUNDPATTERN items, each stored as
                                   a string */
  char_u      *si_compflags;    /* flags used for compounding */
  char_u si_nobreak;            /* NOBREAK */
  char_u      *si_syllable;     /* syllable string */
  garray_T si_prefcond;         /* table with conditions for postponed
                                * prefixes, each stored as a string */
  int si_newprefID;             /* current value for ah_newID */
  int si_newcompID;             /* current value for compound ID */
} spellinfo_T;

static afffile_T *spell_read_aff(spellinfo_T *spin, char_u *fname);
static int is_aff_rule(char_u **items, int itemcnt, char *rulename,
                       int mincount);
static void aff_process_flags(afffile_T *affile, affentry_T *entry);
static int spell_info_item(char_u *s);
static unsigned affitem2flag(int flagtype, char_u *item, char_u *fname,
                             int lnum);
static unsigned get_affitem(int flagtype, char_u **pp);
static void process_compflags(spellinfo_T *spin, afffile_T *aff,
                              char_u *compflags);
static void check_renumber(spellinfo_T *spin);
static int flag_in_afflist(int flagtype, char_u *afflist, unsigned flag);
static void aff_check_number(int spinval, int affval, char *name);
static void aff_check_string(char_u *spinval, char_u *affval,
                             char *name);
static int str_equal(char_u *s1, char_u *s2);
static void add_fromto(spellinfo_T *spin, garray_T *gap, char_u *from,
                       char_u *to);
static int sal_to_bool(char_u *s);
static void spell_free_aff(afffile_T *aff);
static int spell_read_dic(spellinfo_T *spin, char_u *fname,
                          afffile_T *affile);
static int get_affix_flags(afffile_T *affile, char_u *afflist);
static int get_pfxlist(afffile_T *affile, char_u *afflist,
                       char_u *store_afflist);
static void get_compflags(afffile_T *affile, char_u *afflist,
                          char_u *store_afflist);
static int store_aff_word(spellinfo_T *spin, char_u *word, char_u *afflist,
                          afffile_T *affile, hashtab_T *ht,
                          hashtab_T *xht, int condit, int flags,
                          char_u *pfxlist,
                          int pfxlen);
static int spell_read_wordfile(spellinfo_T *spin, char_u *fname);
static void *getroom(spellinfo_T *spin, size_t len, int align);
static char_u *getroom_save(spellinfo_T *spin, char_u *s);
static void free_blocks(sblock_T *bl);
static wordnode_T *wordtree_alloc(spellinfo_T *spin);
static int store_word(spellinfo_T *spin, char_u *word, int flags,
                      int region, char_u *pfxlist,
                      int need_affix);
static int tree_add_word(spellinfo_T *spin, char_u *word,
                         wordnode_T *tree, int flags, int region,
                         int affixID);
static wordnode_T *get_wordnode(spellinfo_T *spin);
static int deref_wordnode(spellinfo_T *spin, wordnode_T *node);
static void free_wordnode(spellinfo_T *spin, wordnode_T *n);
static void wordtree_compress(spellinfo_T *spin, wordnode_T *root);
static int node_compress(spellinfo_T *spin, wordnode_T *node,
                         hashtab_T *ht,
                         int *tot);
static int node_equal(wordnode_T *n1, wordnode_T *n2);
static int write_vim_spell(spellinfo_T *spin, char_u *fname);
static void clear_node(wordnode_T *node);
static int put_node(FILE *fd, wordnode_T *node, int idx, int regionmask,
                    int prefixtree);
static void spell_make_sugfile(spellinfo_T *spin, char_u *wfname);
static int sug_filltree(spellinfo_T *spin, slang_T *slang);
static int sug_maketable(spellinfo_T *spin);
static int sug_filltable(spellinfo_T *spin, wordnode_T *node,
                         int startwordnr,
                         garray_T *gap);
static int offset2bytes(int nr, char_u *buf);
static int bytes2offset(char_u **pp);
static void sug_write(spellinfo_T *spin, char_u *fname);
static void mkspell(int fcount, char_u **fnames, int ascii,
                    int over_write,
                    int added_word);
static void spell_message(spellinfo_T *spin, char_u *str);
static void init_spellfile(void);

/* In the postponed prefixes tree wn_flags is used to store the WFP_ flags,
 * but it must be negative to indicate the prefix tree to tree_add_word().
 * Use a negative number with the lower 8 bits zero. */
#define PFX_FLAGS       -256

/* flags for "condit" argument of store_aff_word() */
#define CONDIT_COMB     1       /* affix must combine */
#define CONDIT_CFIX     2       /* affix must have CIRCUMFIX flag */
#define CONDIT_SUF      4       /* add a suffix for matching flags */
#define CONDIT_AFF      8       /* word already has an affix */

/*
 * Tunable parameters for when the tree is compressed.  See 'mkspellmem'.
 */
static long compress_start = 30000;     /* memory / SBLOCKSIZE */
static long compress_inc = 100;         /* memory / SBLOCKSIZE */
static long compress_added = 500000;    /* word count */

#ifdef SPELL_PRINTTREE
/*
 * For debugging the tree code: print the current tree in a (more or less)
 * readable format, so that we can see what happens when adding a word and/or
 * compressing the tree.
 * Based on code from Olaf Seibert.
 */
#define PRINTLINESIZE   1000
#define PRINTWIDTH      6

#define PRINTSOME(l, depth, fmt, a1, a2) vim_snprintf(l + depth * PRINTWIDTH, \
    PRINTLINESIZE - PRINTWIDTH * depth, fmt, a1, a2)

static char line1[PRINTLINESIZE];
static char line2[PRINTLINESIZE];
static char line3[PRINTLINESIZE];

static void spell_clear_flags(wordnode_T *node)                 {
  wordnode_T  *np;

  for (np = node; np != NULL; np = np->wn_sibling) {
    np->wn_u1.index = FALSE;
    spell_clear_flags(np->wn_child);
  }
}

static void spell_print_node(wordnode_T *node, int depth)                 {
  if (node->wn_u1.index) {
    /* Done this node before, print the reference. */
    PRINTSOME(line1, depth, "(%d)", node->wn_nr, 0);
    PRINTSOME(line2, depth, "    ", 0, 0);
    PRINTSOME(line3, depth, "    ", 0, 0);
    msg(line1);
    msg(line2);
    msg(line3);
  } else   {
    node->wn_u1.index = TRUE;

    if (node->wn_byte != NUL) {
      if (node->wn_child != NULL)
        PRINTSOME(line1, depth, " %c -> ", node->wn_byte, 0);
      else
        /* Cannot happen? */
        PRINTSOME(line1, depth, " %c ???", node->wn_byte, 0);
    } else
      PRINTSOME(line1, depth, " $    ", 0, 0);

    PRINTSOME(line2, depth, "%d/%d    ", node->wn_nr, node->wn_refs);

    if (node->wn_sibling != NULL)
      PRINTSOME(line3, depth, " |    ", 0, 0);
    else
      PRINTSOME(line3, depth, "      ", 0, 0);

    if (node->wn_byte == NUL) {
      msg(line1);
      msg(line2);
      msg(line3);
    }

    /* do the children */
    if (node->wn_byte != NUL && node->wn_child != NULL)
      spell_print_node(node->wn_child, depth + 1);

    /* do the siblings */
    if (node->wn_sibling != NULL) {
      /* get rid of all parent details except | */
      STRCPY(line1, line3);
      STRCPY(line2, line3);
      spell_print_node(node->wn_sibling, depth);
    }
  }
}

static void spell_print_tree(wordnode_T *root)                 {
  if (root != NULL) {
    /* Clear the "wn_u1.index" fields, used to remember what has been
     * done. */
    spell_clear_flags(root);

    /* Recursively print the tree. */
    spell_print_node(root, 0);
  }
}

#endif /* SPELL_PRINTTREE */

/*
 * Read the affix file "fname".
 * Returns an afffile_T, NULL for complete failure.
 */
static afffile_T *spell_read_aff(spellinfo_T *spin, char_u *fname)
{
  FILE        *fd;
  afffile_T   *aff;
  char_u rline[MAXLINELEN];
  char_u      *line;
  char_u      *pc = NULL;
#define MAXITEMCNT  30
  char_u      *(items[MAXITEMCNT]);
  int itemcnt;
  char_u      *p;
  int lnum = 0;
  affheader_T *cur_aff = NULL;
  int did_postpone_prefix = FALSE;
  int aff_todo = 0;
  hashtab_T   *tp;
  char_u      *low = NULL;
  char_u      *fol = NULL;
  char_u      *upp = NULL;
  int do_rep;
  int do_repsal;
  int do_sal;
  int do_mapline;
  int found_map = FALSE;
  hashitem_T  *hi;
  int l;
  int compminlen = 0;                   /* COMPOUNDMIN value */
  int compsylmax = 0;                   /* COMPOUNDSYLMAX value */
  int compoptions = 0;                  /* COMP_ flags */
  int compmax = 0;                      /* COMPOUNDWORDMAX value */
  char_u      *compflags = NULL;        /* COMPOUNDFLAG and COMPOUNDRULE
                                           concatenated */
  char_u      *midword = NULL;          /* MIDWORD value */
  char_u      *syllable = NULL;         /* SYLLABLE value */
  char_u      *sofofrom = NULL;         /* SOFOFROM value */
  char_u      *sofoto = NULL;           /* SOFOTO value */

  /*
   * Open the file.
   */
  fd = mch_fopen((char *)fname, "r");
  if (fd == NULL) {
    EMSG2(_(e_notopen), fname);
    return NULL;
  }

  vim_snprintf((char *)IObuff, IOSIZE, _("Reading affix file %s ..."), fname);
  spell_message(spin, IObuff);

  /* Only do REP lines when not done in another .aff file already. */
  do_rep = spin->si_rep.ga_len == 0;

  /* Only do REPSAL lines when not done in another .aff file already. */
  do_repsal = spin->si_repsal.ga_len == 0;

  /* Only do SAL lines when not done in another .aff file already. */
  do_sal = spin->si_sal.ga_len == 0;

  /* Only do MAP lines when not done in another .aff file already. */
  do_mapline = spin->si_map.ga_len == 0;

  /*
   * Allocate and init the afffile_T structure.
   */
  aff = (afffile_T *)getroom(spin, sizeof(afffile_T), TRUE);
  if (aff == NULL) {
    fclose(fd);
    return NULL;
  }
  hash_init(&aff->af_pref);
  hash_init(&aff->af_suff);
  hash_init(&aff->af_comp);

  /*
   * Read all the lines in the file one by one.
   */
  while (!vim_fgets(rline, MAXLINELEN, fd) && !got_int) {
    line_breakcheck();
    ++lnum;

    /* Skip comment lines. */
    if (*rline == '#')
      continue;

    /* Convert from "SET" to 'encoding' when needed. */
    vim_free(pc);
    if (spin->si_conv.vc_type != CONV_NONE) {
      pc = string_convert(&spin->si_conv, rline, NULL);
      if (pc == NULL) {
        smsg((char_u *)_("Conversion failure for word in %s line %d: %s"),
            fname, lnum, rline);
        continue;
      }
      line = pc;
    } else   {
      pc = NULL;
      line = rline;
    }

    /* Split the line up in white separated items.  Put a NUL after each
     * item. */
    itemcnt = 0;
    for (p = line;; ) {
      while (*p != NUL && *p <= ' ')        /* skip white space and CR/NL */
        ++p;
      if (*p == NUL)
        break;
      if (itemcnt == MAXITEMCNT)            /* too many items */
        break;
      items[itemcnt++] = p;
      /* A few items have arbitrary text argument, don't split them. */
      if (itemcnt == 2 && spell_info_item(items[0]))
        while (*p >= ' ' || *p == TAB)            /* skip until CR/NL */
          ++p;
      else
        while (*p > ' ')            /* skip until white space or CR/NL */
          ++p;
      if (*p == NUL)
        break;
      *p++ = NUL;
    }

    /* Handle non-empty lines. */
    if (itemcnt > 0) {
      if (is_aff_rule(items, itemcnt, "SET", 2) && aff->af_enc == NULL) {
        /* Setup for conversion from "ENC" to 'encoding'. */
        aff->af_enc = enc_canonize(items[1]);
        if (aff->af_enc != NULL && !spin->si_ascii
            && convert_setup(&spin->si_conv, aff->af_enc,
                p_enc) == FAIL)
          smsg((char_u *)_("Conversion in %s not supported: from %s to %s"),
              fname, aff->af_enc, p_enc);
        spin->si_conv.vc_fail = TRUE;
      } else if (is_aff_rule(items, itemcnt, "FLAG", 2)
                 && aff->af_flagtype == AFT_CHAR) {
        if (STRCMP(items[1], "long") == 0)
          aff->af_flagtype = AFT_LONG;
        else if (STRCMP(items[1], "num") == 0)
          aff->af_flagtype = AFT_NUM;
        else if (STRCMP(items[1], "caplong") == 0)
          aff->af_flagtype = AFT_CAPLONG;
        else
          smsg((char_u *)_("Invalid value for FLAG in %s line %d: %s"),
              fname, lnum, items[1]);
        if (aff->af_rare != 0
            || aff->af_keepcase != 0
            || aff->af_bad != 0
            || aff->af_needaffix != 0
            || aff->af_circumfix != 0
            || aff->af_needcomp != 0
            || aff->af_comproot != 0
            || aff->af_nosuggest != 0
            || compflags != NULL
            || aff->af_suff.ht_used > 0
            || aff->af_pref.ht_used > 0)
          smsg((char_u *)_("FLAG after using flags in %s line %d: %s"),
              fname, lnum, items[1]);
      } else if (spell_info_item(items[0]))   {
        p = (char_u *)getroom(spin,
            (spin->si_info == NULL ? 0 : STRLEN(spin->si_info))
            + STRLEN(items[0])
            + STRLEN(items[1]) + 3, FALSE);
        if (p != NULL) {
          if (spin->si_info != NULL) {
            STRCPY(p, spin->si_info);
            STRCAT(p, "\n");
          }
          STRCAT(p, items[0]);
          STRCAT(p, " ");
          STRCAT(p, items[1]);
          spin->si_info = p;
        }
      } else if (is_aff_rule(items, itemcnt, "MIDWORD", 2)
                 && midword == NULL) {
        midword = getroom_save(spin, items[1]);
      } else if (is_aff_rule(items, itemcnt, "TRY", 2))   {
        /* ignored, we look in the tree for what chars may appear */
      }
      /* TODO: remove "RAR" later */
      else if ((is_aff_rule(items, itemcnt, "RAR", 2)
                || is_aff_rule(items, itemcnt, "RARE", 2))
               && aff->af_rare == 0) {
        aff->af_rare = affitem2flag(aff->af_flagtype, items[1],
            fname, lnum);
      }
      /* TODO: remove "KEP" later */
      else if ((is_aff_rule(items, itemcnt, "KEP", 2)
                || is_aff_rule(items, itemcnt, "KEEPCASE", 2))
               && aff->af_keepcase == 0) {
        aff->af_keepcase = affitem2flag(aff->af_flagtype, items[1],
            fname, lnum);
      } else if ((is_aff_rule(items, itemcnt, "BAD", 2)
                  || is_aff_rule(items, itemcnt, "FORBIDDENWORD", 2))
                 && aff->af_bad == 0) {
        aff->af_bad = affitem2flag(aff->af_flagtype, items[1],
            fname, lnum);
      } else if (is_aff_rule(items, itemcnt, "NEEDAFFIX", 2)
                 && aff->af_needaffix == 0) {
        aff->af_needaffix = affitem2flag(aff->af_flagtype, items[1],
            fname, lnum);
      } else if (is_aff_rule(items, itemcnt, "CIRCUMFIX", 2)
                 && aff->af_circumfix == 0) {
        aff->af_circumfix = affitem2flag(aff->af_flagtype, items[1],
            fname, lnum);
      } else if (is_aff_rule(items, itemcnt, "NOSUGGEST", 2)
                 && aff->af_nosuggest == 0) {
        aff->af_nosuggest = affitem2flag(aff->af_flagtype, items[1],
            fname, lnum);
      } else if ((is_aff_rule(items, itemcnt, "NEEDCOMPOUND", 2)
                  || is_aff_rule(items, itemcnt, "ONLYINCOMPOUND", 2))
                 && aff->af_needcomp == 0) {
        aff->af_needcomp = affitem2flag(aff->af_flagtype, items[1],
            fname, lnum);
      } else if (is_aff_rule(items, itemcnt, "COMPOUNDROOT", 2)
                 && aff->af_comproot == 0) {
        aff->af_comproot = affitem2flag(aff->af_flagtype, items[1],
            fname, lnum);
      } else if (is_aff_rule(items, itemcnt, "COMPOUNDFORBIDFLAG", 2)
                 && aff->af_compforbid == 0) {
        aff->af_compforbid = affitem2flag(aff->af_flagtype, items[1],
            fname, lnum);
        if (aff->af_pref.ht_used > 0)
          smsg((char_u *)_(
                  "Defining COMPOUNDFORBIDFLAG after PFX item may give wrong results in %s line %d"),
              fname, lnum);
      } else if (is_aff_rule(items, itemcnt, "COMPOUNDPERMITFLAG", 2)
                 && aff->af_comppermit == 0) {
        aff->af_comppermit = affitem2flag(aff->af_flagtype, items[1],
            fname, lnum);
        if (aff->af_pref.ht_used > 0)
          smsg((char_u *)_(
                  "Defining COMPOUNDPERMITFLAG after PFX item may give wrong results in %s line %d"),
              fname, lnum);
      } else if (is_aff_rule(items, itemcnt, "COMPOUNDFLAG", 2)
                 && compflags == NULL) {
        /* Turn flag "c" into COMPOUNDRULE compatible string "c+",
         * "Na" into "Na+", "1234" into "1234+". */
        p = getroom(spin, STRLEN(items[1]) + 2, FALSE);
        if (p != NULL) {
          STRCPY(p, items[1]);
          STRCAT(p, "+");
          compflags = p;
        }
      } else if (is_aff_rule(items, itemcnt, "COMPOUNDRULES", 2))   {
        /* We don't use the count, but do check that it's a number and
         * not COMPOUNDRULE mistyped. */
        if (atoi((char *)items[1]) == 0)
          smsg((char_u *)_("Wrong COMPOUNDRULES value in %s line %d: %s"),
              fname, lnum, items[1]);
      } else if (is_aff_rule(items, itemcnt, "COMPOUNDRULE", 2))   {
        /* Don't use the first rule if it is a number. */
        if (compflags != NULL || *skipdigits(items[1]) != NUL) {
          /* Concatenate this string to previously defined ones,
           * using a slash to separate them. */
          l = (int)STRLEN(items[1]) + 1;
          if (compflags != NULL)
            l += (int)STRLEN(compflags) + 1;
          p = getroom(spin, l, FALSE);
          if (p != NULL) {
            if (compflags != NULL) {
              STRCPY(p, compflags);
              STRCAT(p, "/");
            }
            STRCAT(p, items[1]);
            compflags = p;
          }
        }
      } else if (is_aff_rule(items, itemcnt, "COMPOUNDWORDMAX", 2)
                 && compmax == 0) {
        compmax = atoi((char *)items[1]);
        if (compmax == 0)
          smsg((char_u *)_("Wrong COMPOUNDWORDMAX value in %s line %d: %s"),
              fname, lnum, items[1]);
      } else if (is_aff_rule(items, itemcnt, "COMPOUNDMIN", 2)
                 && compminlen == 0) {
        compminlen = atoi((char *)items[1]);
        if (compminlen == 0)
          smsg((char_u *)_("Wrong COMPOUNDMIN value in %s line %d: %s"),
              fname, lnum, items[1]);
      } else if (is_aff_rule(items, itemcnt, "COMPOUNDSYLMAX", 2)
                 && compsylmax == 0) {
        compsylmax = atoi((char *)items[1]);
        if (compsylmax == 0)
          smsg((char_u *)_("Wrong COMPOUNDSYLMAX value in %s line %d: %s"),
              fname, lnum, items[1]);
      } else if (is_aff_rule(items, itemcnt, "CHECKCOMPOUNDDUP", 1))   {
        compoptions |= COMP_CHECKDUP;
      } else if (is_aff_rule(items, itemcnt, "CHECKCOMPOUNDREP", 1))   {
        compoptions |= COMP_CHECKREP;
      } else if (is_aff_rule(items, itemcnt, "CHECKCOMPOUNDCASE", 1))   {
        compoptions |= COMP_CHECKCASE;
      } else if (is_aff_rule(items, itemcnt, "CHECKCOMPOUNDTRIPLE", 1))   {
        compoptions |= COMP_CHECKTRIPLE;
      } else if (is_aff_rule(items, itemcnt, "CHECKCOMPOUNDPATTERN", 2))   {
        if (atoi((char *)items[1]) == 0)
          smsg((char_u *)_("Wrong CHECKCOMPOUNDPATTERN value in %s line %d: %s"),
              fname, lnum, items[1]);
      } else if (is_aff_rule(items, itemcnt, "CHECKCOMPOUNDPATTERN", 3))   {
        garray_T    *gap = &spin->si_comppat;
        int i;

        /* Only add the couple if it isn't already there. */
        for (i = 0; i < gap->ga_len - 1; i += 2)
          if (STRCMP(((char_u **)(gap->ga_data))[i], items[1]) == 0
              && STRCMP(((char_u **)(gap->ga_data))[i + 1],
                  items[2]) == 0)
            break;
        if (i >= gap->ga_len && ga_grow(gap, 2) == OK) {
          ((char_u **)(gap->ga_data))[gap->ga_len++]
            = getroom_save(spin, items[1]);
          ((char_u **)(gap->ga_data))[gap->ga_len++]
            = getroom_save(spin, items[2]);
        }
      } else if (is_aff_rule(items, itemcnt, "SYLLABLE", 2)
                 && syllable == NULL) {
        syllable = getroom_save(spin, items[1]);
      } else if (is_aff_rule(items, itemcnt, "NOBREAK", 1))   {
        spin->si_nobreak = TRUE;
      } else if (is_aff_rule(items, itemcnt, "NOSPLITSUGS", 1))   {
        spin->si_nosplitsugs = TRUE;
      } else if (is_aff_rule(items, itemcnt, "NOSUGFILE", 1))   {
        spin->si_nosugfile = TRUE;
      } else if (is_aff_rule(items, itemcnt, "PFXPOSTPONE", 1))   {
        aff->af_pfxpostpone = TRUE;
      } else if ((STRCMP(items[0], "PFX") == 0
                  || STRCMP(items[0], "SFX") == 0)
                 && aff_todo == 0
                 && itemcnt >= 4) {
        int lasti = 4;
        char_u key[AH_KEY_LEN];

        if (*items[0] == 'P')
          tp = &aff->af_pref;
        else
          tp = &aff->af_suff;

        /* Myspell allows the same affix name to be used multiple
         * times.  The affix files that do this have an undocumented
         * "S" flag on all but the last block, thus we check for that
         * and store it in ah_follows. */
        vim_strncpy(key, items[1], AH_KEY_LEN - 1);
        hi = hash_find(tp, key);
        if (!HASHITEM_EMPTY(hi)) {
          cur_aff = HI2AH(hi);
          if (cur_aff->ah_combine != (*items[2] == 'Y'))
            smsg((char_u *)_(
                    "Different combining flag in continued affix block in %s line %d: %s"),
                fname, lnum, items[1]);
          if (!cur_aff->ah_follows)
            smsg((char_u *)_("Duplicate affix in %s line %d: %s"),
                fname, lnum, items[1]);
        } else   {
          /* New affix letter. */
          cur_aff = (affheader_T *)getroom(spin,
              sizeof(affheader_T), TRUE);
          if (cur_aff == NULL)
            break;
          cur_aff->ah_flag = affitem2flag(aff->af_flagtype, items[1],
              fname, lnum);
          if (cur_aff->ah_flag == 0 || STRLEN(items[1]) >= AH_KEY_LEN)
            break;
          if (cur_aff->ah_flag == aff->af_bad
              || cur_aff->ah_flag == aff->af_rare
              || cur_aff->ah_flag == aff->af_keepcase
              || cur_aff->ah_flag == aff->af_needaffix
              || cur_aff->ah_flag == aff->af_circumfix
              || cur_aff->ah_flag == aff->af_nosuggest
              || cur_aff->ah_flag == aff->af_needcomp
              || cur_aff->ah_flag == aff->af_comproot)
            smsg((char_u *)_(
                    "Affix also used for BAD/RARE/KEEPCASE/NEEDAFFIX/NEEDCOMPOUND/NOSUGGEST in %s line %d: %s"),
                fname, lnum, items[1]);
          STRCPY(cur_aff->ah_key, items[1]);
          hash_add(tp, cur_aff->ah_key);

          cur_aff->ah_combine = (*items[2] == 'Y');
        }

        /* Check for the "S" flag, which apparently means that another
         * block with the same affix name is following. */
        if (itemcnt > lasti && STRCMP(items[lasti], "S") == 0) {
          ++lasti;
          cur_aff->ah_follows = TRUE;
        } else
          cur_aff->ah_follows = FALSE;

        /* Myspell allows extra text after the item, but that might
         * mean mistakes go unnoticed.  Require a comment-starter. */
        if (itemcnt > lasti && *items[lasti] != '#')
          smsg((char_u *)_(e_afftrailing), fname, lnum, items[lasti]);

        if (STRCMP(items[2], "Y") != 0 && STRCMP(items[2], "N") != 0)
          smsg((char_u *)_("Expected Y or N in %s line %d: %s"),
              fname, lnum, items[2]);

        if (*items[0] == 'P' && aff->af_pfxpostpone) {
          if (cur_aff->ah_newID == 0) {
            /* Use a new number in the .spl file later, to be able
             * to handle multiple .aff files. */
            check_renumber(spin);
            cur_aff->ah_newID = ++spin->si_newprefID;

            /* We only really use ah_newID if the prefix is
             * postponed.  We know that only after handling all
             * the items. */
            did_postpone_prefix = FALSE;
          } else
            /* Did use the ID in a previous block. */
            did_postpone_prefix = TRUE;
        }

        aff_todo = atoi((char *)items[3]);
      } else if ((STRCMP(items[0], "PFX") == 0
                  || STRCMP(items[0], "SFX") == 0)
                 && aff_todo > 0
                 && STRCMP(cur_aff->ah_key, items[1]) == 0
                 && itemcnt >= 5) {
        affentry_T      *aff_entry;
        int upper = FALSE;
        int lasti = 5;

        /* Myspell allows extra text after the item, but that might
         * mean mistakes go unnoticed.  Require a comment-starter.
         * Hunspell uses a "-" item. */
        if (itemcnt > lasti && *items[lasti] != '#'
            && (STRCMP(items[lasti], "-") != 0
                || itemcnt != lasti + 1))
          smsg((char_u *)_(e_afftrailing), fname, lnum, items[lasti]);

        /* New item for an affix letter. */
        --aff_todo;
        aff_entry = (affentry_T *)getroom(spin,
            sizeof(affentry_T), TRUE);
        if (aff_entry == NULL)
          break;

        if (STRCMP(items[2], "0") != 0)
          aff_entry->ae_chop = getroom_save(spin, items[2]);
        if (STRCMP(items[3], "0") != 0) {
          aff_entry->ae_add = getroom_save(spin, items[3]);

          /* Recognize flags on the affix: abcd/XYZ */
          aff_entry->ae_flags = vim_strchr(aff_entry->ae_add, '/');
          if (aff_entry->ae_flags != NULL) {
            *aff_entry->ae_flags++ = NUL;
            aff_process_flags(aff, aff_entry);
          }
        }

        /* Don't use an affix entry with non-ASCII characters when
         * "spin->si_ascii" is TRUE. */
        if (!spin->si_ascii || !(has_non_ascii(aff_entry->ae_chop)
                                 || has_non_ascii(aff_entry->ae_add))) {
          aff_entry->ae_next = cur_aff->ah_first;
          cur_aff->ah_first = aff_entry;

          if (STRCMP(items[4], ".") != 0) {
            char_u buf[MAXLINELEN];

            aff_entry->ae_cond = getroom_save(spin, items[4]);
            if (*items[0] == 'P')
              sprintf((char *)buf, "^%s", items[4]);
            else
              sprintf((char *)buf, "%s$", items[4]);
            aff_entry->ae_prog = vim_regcomp(buf,
                RE_MAGIC + RE_STRING + RE_STRICT);
            if (aff_entry->ae_prog == NULL)
              smsg((char_u *)_("Broken condition in %s line %d: %s"),
                  fname, lnum, items[4]);
          }

          /* For postponed prefixes we need an entry in si_prefcond
           * for the condition.  Use an existing one if possible.
           * Can't be done for an affix with flags, ignoring
           * COMPOUNDFORBIDFLAG and COMPOUNDPERMITFLAG. */
          if (*items[0] == 'P' && aff->af_pfxpostpone
              && aff_entry->ae_flags == NULL) {
            /* When the chop string is one lower-case letter and
             * the add string ends in the upper-case letter we set
             * the "upper" flag, clear "ae_chop" and remove the
             * letters from "ae_add".  The condition must either
             * be empty or start with the same letter. */
            if (aff_entry->ae_chop != NULL
                && aff_entry->ae_add != NULL
                && aff_entry->ae_chop[(*mb_ptr2len)(
                                        aff_entry->ae_chop)] == NUL
                ) {
              int c, c_up;

              c = PTR2CHAR(aff_entry->ae_chop);
              c_up = SPELL_TOUPPER(c);
              if (c_up != c
                  && (aff_entry->ae_cond == NULL
                      || PTR2CHAR(aff_entry->ae_cond) == c)) {
                p = aff_entry->ae_add
                    + STRLEN(aff_entry->ae_add);
                mb_ptr_back(aff_entry->ae_add, p);
                if (PTR2CHAR(p) == c_up) {
                  upper = TRUE;
                  aff_entry->ae_chop = NULL;
                  *p = NUL;

                  /* The condition is matched with the
                   * actual word, thus must check for the
                   * upper-case letter. */
                  if (aff_entry->ae_cond != NULL) {
                    char_u buf[MAXLINELEN];
                    if (has_mbyte) {
                      onecap_copy(items[4], buf, TRUE);
                      aff_entry->ae_cond = getroom_save(
                          spin, buf);
                    } else
                      *aff_entry->ae_cond = c_up;
                    if (aff_entry->ae_cond != NULL) {
                      sprintf((char *)buf, "^%s",
                          aff_entry->ae_cond);
                      vim_regfree(aff_entry->ae_prog);
                      aff_entry->ae_prog = vim_regcomp(
                          buf, RE_MAGIC + RE_STRING);
                    }
                  }
                }
              }
            }

            if (aff_entry->ae_chop == NULL
                && aff_entry->ae_flags == NULL) {
              int idx;
              char_u      **pp;
              int n;

              /* Find a previously used condition. */
              for (idx = spin->si_prefcond.ga_len - 1; idx >= 0;
                   --idx) {
                p = ((char_u **)spin->si_prefcond.ga_data)[idx];
                if (str_equal(p, aff_entry->ae_cond))
                  break;
              }
              if (idx < 0 && ga_grow(&spin->si_prefcond, 1) == OK) {
                /* Not found, add a new condition. */
                idx = spin->si_prefcond.ga_len++;
                pp = ((char_u **)spin->si_prefcond.ga_data)
                     + idx;
                if (aff_entry->ae_cond == NULL)
                  *pp = NULL;
                else
                  *pp = getroom_save(spin,
                      aff_entry->ae_cond);
              }

              /* Add the prefix to the prefix tree. */
              if (aff_entry->ae_add == NULL)
                p = (char_u *)"";
              else
                p = aff_entry->ae_add;

              /* PFX_FLAGS is a negative number, so that
               * tree_add_word() knows this is the prefix tree. */
              n = PFX_FLAGS;
              if (!cur_aff->ah_combine)
                n |= WFP_NC;
              if (upper)
                n |= WFP_UP;
              if (aff_entry->ae_comppermit)
                n |= WFP_COMPPERMIT;
              if (aff_entry->ae_compforbid)
                n |= WFP_COMPFORBID;
              tree_add_word(spin, p, spin->si_prefroot, n,
                  idx, cur_aff->ah_newID);
              did_postpone_prefix = TRUE;
            }

            /* Didn't actually use ah_newID, backup si_newprefID. */
            if (aff_todo == 0 && !did_postpone_prefix) {
              --spin->si_newprefID;
              cur_aff->ah_newID = 0;
            }
          }
        }
      } else if (is_aff_rule(items, itemcnt, "FOL", 2) && fol == NULL)   {
        fol = vim_strsave(items[1]);
      } else if (is_aff_rule(items, itemcnt, "LOW", 2) && low == NULL)   {
        low = vim_strsave(items[1]);
      } else if (is_aff_rule(items, itemcnt, "UPP", 2) && upp == NULL)   {
        upp = vim_strsave(items[1]);
      } else if (is_aff_rule(items, itemcnt, "REP", 2)
                 || is_aff_rule(items, itemcnt, "REPSAL", 2)) {
        /* Ignore REP/REPSAL count */;
        if (!isdigit(*items[1]))
          smsg((char_u *)_("Expected REP(SAL) count in %s line %d"),
              fname, lnum);
      } else if ((STRCMP(items[0], "REP") == 0
                  || STRCMP(items[0], "REPSAL") == 0)
                 && itemcnt >= 3) {
        /* REP/REPSAL item */
        /* Myspell ignores extra arguments, we require it starts with
         * # to detect mistakes. */
        if (itemcnt > 3 && items[3][0] != '#')
          smsg((char_u *)_(e_afftrailing), fname, lnum, items[3]);
        if (items[0][3] == 'S' ? do_repsal : do_rep) {
          /* Replace underscore with space (can't include a space
           * directly). */
          for (p = items[1]; *p != NUL; mb_ptr_adv(p))
            if (*p == '_')
              *p = ' ';
          for (p = items[2]; *p != NUL; mb_ptr_adv(p))
            if (*p == '_')
              *p = ' ';
          add_fromto(spin, items[0][3] == 'S'
              ? &spin->si_repsal
              : &spin->si_rep, items[1], items[2]);
        }
      } else if (is_aff_rule(items, itemcnt, "MAP", 2))   {
        /* MAP item or count */
        if (!found_map) {
          /* First line contains the count. */
          found_map = TRUE;
          if (!isdigit(*items[1]))
            smsg((char_u *)_("Expected MAP count in %s line %d"),
                fname, lnum);
        } else if (do_mapline)   {
          int c;

          /* Check that every character appears only once. */
          for (p = items[1]; *p != NUL; ) {
            c = mb_ptr2char_adv(&p);
            if ((spin->si_map.ga_len > 0
                 && vim_strchr(spin->si_map.ga_data, c)
                 != NULL)
                || vim_strchr(p, c) != NULL)
              smsg((char_u *)_("Duplicate character in MAP in %s line %d"),
                  fname, lnum);
          }

          /* We simply concatenate all the MAP strings, separated by
           * slashes. */
          ga_concat(&spin->si_map, items[1]);
          ga_append(&spin->si_map, '/');
        }
      }
      /* Accept "SAL from to" and "SAL from to  #comment". */
      else if (is_aff_rule(items, itemcnt, "SAL", 3)) {
        if (do_sal) {
          /* SAL item (sounds-a-like)
           * Either one of the known keys or a from-to pair. */
          if (STRCMP(items[1], "followup") == 0)
            spin->si_followup = sal_to_bool(items[2]);
          else if (STRCMP(items[1], "collapse_result") == 0)
            spin->si_collapse = sal_to_bool(items[2]);
          else if (STRCMP(items[1], "remove_accents") == 0)
            spin->si_rem_accents = sal_to_bool(items[2]);
          else
            /* when "to" is "_" it means empty */
            add_fromto(spin, &spin->si_sal, items[1],
                STRCMP(items[2], "_") == 0 ? (char_u *)""
                : items[2]);
        }
      } else if (is_aff_rule(items, itemcnt, "SOFOFROM", 2)
                 && sofofrom == NULL) {
        sofofrom = getroom_save(spin, items[1]);
      } else if (is_aff_rule(items, itemcnt, "SOFOTO", 2)
                 && sofoto == NULL) {
        sofoto = getroom_save(spin, items[1]);
      } else if (STRCMP(items[0], "COMMON") == 0)   {
        int i;

        for (i = 1; i < itemcnt; ++i) {
          if (HASHITEM_EMPTY(hash_find(&spin->si_commonwords,
                      items[i]))) {
            p = vim_strsave(items[i]);
            if (p == NULL)
              break;
            hash_add(&spin->si_commonwords, p);
          }
        }
      } else
        smsg((char_u *)_("Unrecognized or duplicate item in %s line %d: %s"),
            fname, lnum, items[0]);
    }
  }

  if (fol != NULL || low != NULL || upp != NULL) {
    if (spin->si_clear_chartab) {
      /* Clear the char type tables, don't want to use any of the
       * currently used spell properties. */
      init_spell_chartab();
      spin->si_clear_chartab = FALSE;
    }

    /*
     * Don't write a word table for an ASCII file, so that we don't check
     * for conflicts with a word table that matches 'encoding'.
     * Don't write one for utf-8 either, we use utf_*() and
     * mb_get_class(), the list of chars in the file will be incomplete.
     */
    if (!spin->si_ascii
        && !enc_utf8
        ) {
      if (fol == NULL || low == NULL || upp == NULL)
        smsg((char_u *)_("Missing FOL/LOW/UPP line in %s"), fname);
      else
        (void)set_spell_chartab(fol, low, upp);
    }

    vim_free(fol);
    vim_free(low);
    vim_free(upp);
  }

  /* Use compound specifications of the .aff file for the spell info. */
  if (compmax != 0) {
    aff_check_number(spin->si_compmax, compmax, "COMPOUNDWORDMAX");
    spin->si_compmax = compmax;
  }

  if (compminlen != 0) {
    aff_check_number(spin->si_compminlen, compminlen, "COMPOUNDMIN");
    spin->si_compminlen = compminlen;
  }

  if (compsylmax != 0) {
    if (syllable == NULL)
      smsg((char_u *)_("COMPOUNDSYLMAX used without SYLLABLE"));
    aff_check_number(spin->si_compsylmax, compsylmax, "COMPOUNDSYLMAX");
    spin->si_compsylmax = compsylmax;
  }

  if (compoptions != 0) {
    aff_check_number(spin->si_compoptions, compoptions, "COMPOUND options");
    spin->si_compoptions |= compoptions;
  }

  if (compflags != NULL)
    process_compflags(spin, aff, compflags);

  /* Check that we didn't use too many renumbered flags. */
  if (spin->si_newcompID < spin->si_newprefID) {
    if (spin->si_newcompID == 127 || spin->si_newcompID == 255)
      MSG(_("Too many postponed prefixes"));
    else if (spin->si_newprefID == 0 || spin->si_newprefID == 127)
      MSG(_("Too many compound flags"));
    else
      MSG(_("Too many postponed prefixes and/or compound flags"));
  }

  if (syllable != NULL) {
    aff_check_string(spin->si_syllable, syllable, "SYLLABLE");
    spin->si_syllable = syllable;
  }

  if (sofofrom != NULL || sofoto != NULL) {
    if (sofofrom == NULL || sofoto == NULL)
      smsg((char_u *)_("Missing SOFO%s line in %s"),
          sofofrom == NULL ? "FROM" : "TO", fname);
    else if (spin->si_sal.ga_len > 0)
      smsg((char_u *)_("Both SAL and SOFO lines in %s"), fname);
    else {
      aff_check_string(spin->si_sofofr, sofofrom, "SOFOFROM");
      aff_check_string(spin->si_sofoto, sofoto, "SOFOTO");
      spin->si_sofofr = sofofrom;
      spin->si_sofoto = sofoto;
    }
  }

  if (midword != NULL) {
    aff_check_string(spin->si_midword, midword, "MIDWORD");
    spin->si_midword = midword;
  }

  vim_free(pc);
  fclose(fd);
  return aff;
}

/*
 * Return TRUE when items[0] equals "rulename", there are "mincount" items or
 * a comment is following after item "mincount".
 */
static int is_aff_rule(char_u **items, int itemcnt, char *rulename, int mincount)
{
  return STRCMP(items[0], rulename) == 0
         && (itemcnt == mincount
             || (itemcnt > mincount && items[mincount][0] == '#'));
}

/*
 * For affix "entry" move COMPOUNDFORBIDFLAG and COMPOUNDPERMITFLAG from
 * ae_flags to ae_comppermit and ae_compforbid.
 */
static void aff_process_flags(afffile_T *affile, affentry_T *entry)
{
  char_u      *p;
  char_u      *prevp;
  unsigned flag;

  if (entry->ae_flags != NULL
      && (affile->af_compforbid != 0 || affile->af_comppermit != 0)) {
    for (p = entry->ae_flags; *p != NUL; ) {
      prevp = p;
      flag = get_affitem(affile->af_flagtype, &p);
      if (flag == affile->af_comppermit || flag == affile->af_compforbid) {
        STRMOVE(prevp, p);
        p = prevp;
        if (flag == affile->af_comppermit)
          entry->ae_comppermit = TRUE;
        else
          entry->ae_compforbid = TRUE;
      }
      if (affile->af_flagtype == AFT_NUM && *p == ',')
        ++p;
    }
    if (*entry->ae_flags == NUL)
      entry->ae_flags = NULL;           /* nothing left */
  }
}

/*
 * Return TRUE if "s" is the name of an info item in the affix file.
 */
static int spell_info_item(char_u *s)
{
  return STRCMP(s, "NAME") == 0
         || STRCMP(s, "HOME") == 0
         || STRCMP(s, "VERSION") == 0
         || STRCMP(s, "AUTHOR") == 0
         || STRCMP(s, "EMAIL") == 0
         || STRCMP(s, "COPYRIGHT") == 0;
}

/*
 * Turn an affix flag name into a number, according to the FLAG type.
 * returns zero for failure.
 */
static unsigned affitem2flag(int flagtype, char_u *item, char_u *fname, int lnum)
{
  unsigned res;
  char_u      *p = item;

  res = get_affitem(flagtype, &p);
  if (res == 0) {
    if (flagtype == AFT_NUM)
      smsg((char_u *)_("Flag is not a number in %s line %d: %s"),
          fname, lnum, item);
    else
      smsg((char_u *)_("Illegal flag in %s line %d: %s"),
          fname, lnum, item);
  }
  if (*p != NUL) {
    smsg((char_u *)_(e_affname), fname, lnum, item);
    return 0;
  }

  return res;
}

/*
 * Get one affix name from "*pp" and advance the pointer.
 * Returns zero for an error, still advances the pointer then.
 */
static unsigned get_affitem(int flagtype, char_u **pp)
{
  int res;

  if (flagtype == AFT_NUM) {
    if (!VIM_ISDIGIT(**pp)) {
      ++*pp;            /* always advance, avoid getting stuck */
      return 0;
    }
    res = getdigits(pp);
  } else   {
    res = mb_ptr2char_adv(pp);
    if (flagtype == AFT_LONG || (flagtype == AFT_CAPLONG
                                 && res >= 'A' && res <= 'Z')) {
      if (**pp == NUL)
        return 0;
      res = mb_ptr2char_adv(pp) + (res << 16);
    }
  }
  return res;
}

/*
 * Process the "compflags" string used in an affix file and append it to
 * spin->si_compflags.
 * The processing involves changing the affix names to ID numbers, so that
 * they fit in one byte.
 */
static void process_compflags(spellinfo_T *spin, afffile_T *aff, char_u *compflags)
{
  char_u      *p;
  char_u      *prevp;
  unsigned flag;
  compitem_T  *ci;
  int id;
  int len;
  char_u      *tp;
  char_u key[AH_KEY_LEN];
  hashitem_T  *hi;

  /* Make room for the old and the new compflags, concatenated with a / in
   * between.  Processing it makes it shorter, but we don't know by how
   * much, thus allocate the maximum. */
  len = (int)STRLEN(compflags) + 1;
  if (spin->si_compflags != NULL)
    len += (int)STRLEN(spin->si_compflags) + 1;
  p = getroom(spin, len, FALSE);
  if (p == NULL)
    return;
  if (spin->si_compflags != NULL) {
    STRCPY(p, spin->si_compflags);
    STRCAT(p, "/");
  }
  spin->si_compflags = p;
  tp = p + STRLEN(p);

  for (p = compflags; *p != NUL; ) {
    if (vim_strchr((char_u *)"/?*+[]", *p) != NULL)
      /* Copy non-flag characters directly. */
      *tp++ = *p++;
    else {
      /* First get the flag number, also checks validity. */
      prevp = p;
      flag = get_affitem(aff->af_flagtype, &p);
      if (flag != 0) {
        /* Find the flag in the hashtable.  If it was used before, use
         * the existing ID.  Otherwise add a new entry. */
        vim_strncpy(key, prevp, p - prevp);
        hi = hash_find(&aff->af_comp, key);
        if (!HASHITEM_EMPTY(hi))
          id = HI2CI(hi)->ci_newID;
        else {
          ci = (compitem_T *)getroom(spin, sizeof(compitem_T), TRUE);
          if (ci == NULL)
            break;
          STRCPY(ci->ci_key, key);
          ci->ci_flag = flag;
          /* Avoid using a flag ID that has a special meaning in a
           * regexp (also inside []). */
          do {
            check_renumber(spin);
            id = spin->si_newcompID--;
          } while (vim_strchr((char_u *)"/?*+[]\\-^", id) != NULL);
          ci->ci_newID = id;
          hash_add(&aff->af_comp, ci->ci_key);
        }
        *tp++ = id;
      }
      if (aff->af_flagtype == AFT_NUM && *p == ',')
        ++p;
    }
  }

  *tp = NUL;
}

/*
 * Check that the new IDs for postponed affixes and compounding don't overrun
 * each other.  We have almost 255 available, but start at 0-127 to avoid
 * using two bytes for utf-8.  When the 0-127 range is used up go to 128-255.
 * When that is used up an error message is given.
 */
static void check_renumber(spellinfo_T *spin)
{
  if (spin->si_newprefID == spin->si_newcompID && spin->si_newcompID < 128) {
    spin->si_newprefID = 127;
    spin->si_newcompID = 255;
  }
}

/*
 * Return TRUE if flag "flag" appears in affix list "afflist".
 */
static int flag_in_afflist(int flagtype, char_u *afflist, unsigned flag)
{
  char_u      *p;
  unsigned n;

  switch (flagtype) {
  case AFT_CHAR:
    return vim_strchr(afflist, flag) != NULL;

  case AFT_CAPLONG:
  case AFT_LONG:
    for (p = afflist; *p != NUL; ) {
      n = mb_ptr2char_adv(&p);
      if ((flagtype == AFT_LONG || (n >= 'A' && n <= 'Z'))
          && *p != NUL)
        n = mb_ptr2char_adv(&p) + (n << 16);
      if (n == flag)
        return TRUE;
    }
    break;

  case AFT_NUM:
    for (p = afflist; *p != NUL; ) {
      n = getdigits(&p);
      if (n == flag)
        return TRUE;
      if (*p != NUL)            /* skip over comma */
        ++p;
    }
    break;
  }
  return FALSE;
}

/*
 * Give a warning when "spinval" and "affval" numbers are set and not the same.
 */
static void aff_check_number(int spinval, int affval, char *name)
{
  if (spinval != 0 && spinval != affval)
    smsg((char_u *)_(
            "%s value differs from what is used in another .aff file"), name);
}

/*
 * Give a warning when "spinval" and "affval" strings are set and not the same.
 */
static void aff_check_string(char_u *spinval, char_u *affval, char *name)
{
  if (spinval != NULL && STRCMP(spinval, affval) != 0)
    smsg((char_u *)_(
            "%s value differs from what is used in another .aff file"), name);
}

/*
 * Return TRUE if strings "s1" and "s2" are equal.  Also consider both being
 * NULL as equal.
 */
static int str_equal(char_u *s1, char_u *s2)
{
  if (s1 == NULL || s2 == NULL)
    return s1 == s2;
  return STRCMP(s1, s2) == 0;
}

/*
 * Add a from-to item to "gap".  Used for REP and SAL items.
 * They are stored case-folded.
 */
static void add_fromto(spellinfo_T *spin, garray_T *gap, char_u *from, char_u *to)
{
  fromto_T    *ftp;
  char_u word[MAXWLEN];

  if (ga_grow(gap, 1) == OK) {
    ftp = ((fromto_T *)gap->ga_data) + gap->ga_len;
    (void)spell_casefold(from, (int)STRLEN(from), word, MAXWLEN);
    ftp->ft_from = getroom_save(spin, word);
    (void)spell_casefold(to, (int)STRLEN(to), word, MAXWLEN);
    ftp->ft_to = getroom_save(spin, word);
    ++gap->ga_len;
  }
}

/*
 * Convert a boolean argument in a SAL line to TRUE or FALSE;
 */
static int sal_to_bool(char_u *s)
{
  return STRCMP(s, "1") == 0 || STRCMP(s, "true") == 0;
}

/*
 * Free the structure filled by spell_read_aff().
 */
static void spell_free_aff(afffile_T *aff)
{
  hashtab_T   *ht;
  hashitem_T  *hi;
  int todo;
  affheader_T *ah;
  affentry_T  *ae;

  vim_free(aff->af_enc);

  /* All this trouble to free the "ae_prog" items... */
  for (ht = &aff->af_pref;; ht = &aff->af_suff) {
    todo = (int)ht->ht_used;
    for (hi = ht->ht_array; todo > 0; ++hi) {
      if (!HASHITEM_EMPTY(hi)) {
        --todo;
        ah = HI2AH(hi);
        for (ae = ah->ah_first; ae != NULL; ae = ae->ae_next)
          vim_regfree(ae->ae_prog);
      }
    }
    if (ht == &aff->af_suff)
      break;
  }

  hash_clear(&aff->af_pref);
  hash_clear(&aff->af_suff);
  hash_clear(&aff->af_comp);
}

/*
 * Read dictionary file "fname".
 * Returns OK or FAIL;
 */
static int spell_read_dic(spellinfo_T *spin, char_u *fname, afffile_T *affile)
{
  hashtab_T ht;
  char_u line[MAXLINELEN];
  char_u      *p;
  char_u      *afflist;
  char_u store_afflist[MAXWLEN];
  int pfxlen;
  int need_affix;
  char_u      *dw;
  char_u      *pc;
  char_u      *w;
  int l;
  hash_T hash;
  hashitem_T  *hi;
  FILE        *fd;
  int lnum = 1;
  int non_ascii = 0;
  int retval = OK;
  char_u message[MAXLINELEN + MAXWLEN];
  int flags;
  int duplicate = 0;

  /*
   * Open the file.
   */
  fd = mch_fopen((char *)fname, "r");
  if (fd == NULL) {
    EMSG2(_(e_notopen), fname);
    return FAIL;
  }

  /* The hashtable is only used to detect duplicated words. */
  hash_init(&ht);

  vim_snprintf((char *)IObuff, IOSIZE,
      _("Reading dictionary file %s ..."), fname);
  spell_message(spin, IObuff);

  /* start with a message for the first line */
  spin->si_msg_count = 999999;

  /* Read and ignore the first line: word count. */
  (void)vim_fgets(line, MAXLINELEN, fd);
  if (!vim_isdigit(*skipwhite(line)))
    EMSG2(_("E760: No word count in %s"), fname);

  /*
   * Read all the lines in the file one by one.
   * The words are converted to 'encoding' here, before being added to
   * the hashtable.
   */
  while (!vim_fgets(line, MAXLINELEN, fd) && !got_int) {
    line_breakcheck();
    ++lnum;
    if (line[0] == '#' || line[0] == '/')
      continue;         /* comment line */

    /* Remove CR, LF and white space from the end.  White space halfway
     * the word is kept to allow e.g., "et al.". */
    l = (int)STRLEN(line);
    while (l > 0 && line[l - 1] <= ' ')
      --l;
    if (l == 0)
      continue;         /* empty line */
    line[l] = NUL;

    /* Convert from "SET" to 'encoding' when needed. */
    if (spin->si_conv.vc_type != CONV_NONE) {
      pc = string_convert(&spin->si_conv, line, NULL);
      if (pc == NULL) {
        smsg((char_u *)_("Conversion failure for word in %s line %d: %s"),
            fname, lnum, line);
        continue;
      }
      w = pc;
    } else   {
      pc = NULL;
      w = line;
    }

    /* Truncate the word at the "/", set "afflist" to what follows.
     * Replace "\/" by "/" and "\\" by "\". */
    afflist = NULL;
    for (p = w; *p != NUL; mb_ptr_adv(p)) {
      if (*p == '\\' && (p[1] == '\\' || p[1] == '/'))
        STRMOVE(p, p + 1);
      else if (*p == '/') {
        *p = NUL;
        afflist = p + 1;
        break;
      }
    }

    /* Skip non-ASCII words when "spin->si_ascii" is TRUE. */
    if (spin->si_ascii && has_non_ascii(w)) {
      ++non_ascii;
      vim_free(pc);
      continue;
    }

    /* This takes time, print a message every 10000 words. */
    if (spin->si_verbose && spin->si_msg_count > 10000) {
      spin->si_msg_count = 0;
      vim_snprintf((char *)message, sizeof(message),
          _("line %6d, word %6d - %s"),
          lnum, spin->si_foldwcount + spin->si_keepwcount, w);
      msg_start();
      msg_puts_long_attr(message, 0);
      msg_clr_eos();
      msg_didout = FALSE;
      msg_col = 0;
      out_flush();
    }

    /* Store the word in the hashtable to be able to find duplicates. */
    dw = (char_u *)getroom_save(spin, w);
    if (dw == NULL) {
      retval = FAIL;
      vim_free(pc);
      break;
    }

    hash = hash_hash(dw);
    hi = hash_lookup(&ht, dw, hash);
    if (!HASHITEM_EMPTY(hi)) {
      if (p_verbose > 0)
        smsg((char_u *)_("Duplicate word in %s line %d: %s"),
            fname, lnum, dw);
      else if (duplicate == 0)
        smsg((char_u *)_("First duplicate word in %s line %d: %s"),
            fname, lnum, dw);
      ++duplicate;
    } else
      hash_add_item(&ht, hi, dw, hash);

    flags = 0;
    store_afflist[0] = NUL;
    pfxlen = 0;
    need_affix = FALSE;
    if (afflist != NULL) {
      /* Extract flags from the affix list. */
      flags |= get_affix_flags(affile, afflist);

      if (affile->af_needaffix != 0 && flag_in_afflist(
              affile->af_flagtype, afflist, affile->af_needaffix))
        need_affix = TRUE;

      if (affile->af_pfxpostpone)
        /* Need to store the list of prefix IDs with the word. */
        pfxlen = get_pfxlist(affile, afflist, store_afflist);

      if (spin->si_compflags != NULL)
        /* Need to store the list of compound flags with the word.
         * Concatenate them to the list of prefix IDs. */
        get_compflags(affile, afflist, store_afflist + pfxlen);
    }

    /* Add the word to the word tree(s). */
    if (store_word(spin, dw, flags, spin->si_region,
            store_afflist, need_affix) == FAIL)
      retval = FAIL;

    if (afflist != NULL) {
      /* Find all matching suffixes and add the resulting words.
       * Additionally do matching prefixes that combine. */
      if (store_aff_word(spin, dw, afflist, affile,
              &affile->af_suff, &affile->af_pref,
              CONDIT_SUF, flags, store_afflist, pfxlen) == FAIL)
        retval = FAIL;

      /* Find all matching prefixes and add the resulting words. */
      if (store_aff_word(spin, dw, afflist, affile,
              &affile->af_pref, NULL,
              CONDIT_SUF, flags, store_afflist, pfxlen) == FAIL)
        retval = FAIL;
    }

    vim_free(pc);
  }

  if (duplicate > 0)
    smsg((char_u *)_("%d duplicate word(s) in %s"), duplicate, fname);
  if (spin->si_ascii && non_ascii > 0)
    smsg((char_u *)_("Ignored %d word(s) with non-ASCII characters in %s"),
        non_ascii, fname);
  hash_clear(&ht);

  fclose(fd);
  return retval;
}

/*
 * Check for affix flags in "afflist" that are turned into word flags.
 * Return WF_ flags.
 */
static int get_affix_flags(afffile_T *affile, char_u *afflist)
{
  int flags = 0;

  if (affile->af_keepcase != 0 && flag_in_afflist(
          affile->af_flagtype, afflist, affile->af_keepcase))
    flags |= WF_KEEPCAP | WF_FIXCAP;
  if (affile->af_rare != 0 && flag_in_afflist(
          affile->af_flagtype, afflist, affile->af_rare))
    flags |= WF_RARE;
  if (affile->af_bad != 0 && flag_in_afflist(
          affile->af_flagtype, afflist, affile->af_bad))
    flags |= WF_BANNED;
  if (affile->af_needcomp != 0 && flag_in_afflist(
          affile->af_flagtype, afflist, affile->af_needcomp))
    flags |= WF_NEEDCOMP;
  if (affile->af_comproot != 0 && flag_in_afflist(
          affile->af_flagtype, afflist, affile->af_comproot))
    flags |= WF_COMPROOT;
  if (affile->af_nosuggest != 0 && flag_in_afflist(
          affile->af_flagtype, afflist, affile->af_nosuggest))
    flags |= WF_NOSUGGEST;
  return flags;
}

/*
 * Get the list of prefix IDs from the affix list "afflist".
 * Used for PFXPOSTPONE.
 * Put the resulting flags in "store_afflist[MAXWLEN]" with a terminating NUL
 * and return the number of affixes.
 */
static int get_pfxlist(afffile_T *affile, char_u *afflist, char_u *store_afflist)
{
  char_u      *p;
  char_u      *prevp;
  int cnt = 0;
  int id;
  char_u key[AH_KEY_LEN];
  hashitem_T  *hi;

  for (p = afflist; *p != NUL; ) {
    prevp = p;
    if (get_affitem(affile->af_flagtype, &p) != 0) {
      /* A flag is a postponed prefix flag if it appears in "af_pref"
       * and it's ID is not zero. */
      vim_strncpy(key, prevp, p - prevp);
      hi = hash_find(&affile->af_pref, key);
      if (!HASHITEM_EMPTY(hi)) {
        id = HI2AH(hi)->ah_newID;
        if (id != 0)
          store_afflist[cnt++] = id;
      }
    }
    if (affile->af_flagtype == AFT_NUM && *p == ',')
      ++p;
  }

  store_afflist[cnt] = NUL;
  return cnt;
}

/*
 * Get the list of compound IDs from the affix list "afflist" that are used
 * for compound words.
 * Puts the flags in "store_afflist[]".
 */
static void get_compflags(afffile_T *affile, char_u *afflist, char_u *store_afflist)
{
  char_u      *p;
  char_u      *prevp;
  int cnt = 0;
  char_u key[AH_KEY_LEN];
  hashitem_T  *hi;

  for (p = afflist; *p != NUL; ) {
    prevp = p;
    if (get_affitem(affile->af_flagtype, &p) != 0) {
      /* A flag is a compound flag if it appears in "af_comp". */
      vim_strncpy(key, prevp, p - prevp);
      hi = hash_find(&affile->af_comp, key);
      if (!HASHITEM_EMPTY(hi))
        store_afflist[cnt++] = HI2CI(hi)->ci_newID;
    }
    if (affile->af_flagtype == AFT_NUM && *p == ',')
      ++p;
  }

  store_afflist[cnt] = NUL;
}

/*
 * Apply affixes to a word and store the resulting words.
 * "ht" is the hashtable with affentry_T that need to be applied, either
 * prefixes or suffixes.
 * "xht", when not NULL, is the prefix hashtable, to be used additionally on
 * the resulting words for combining affixes.
 *
 * Returns FAIL when out of memory.
 */
static int 
store_aff_word (
    spellinfo_T *spin,              /* spell info */
    char_u *word,              /* basic word start */
    char_u *afflist,           /* list of names of supported affixes */
    afffile_T *affile,
    hashtab_T *ht,
    hashtab_T *xht,
    int condit,                     /* CONDIT_SUF et al. */
    int flags,                      /* flags for the word */
    char_u *pfxlist,           /* list of prefix IDs */
    int pfxlen                     /* nr of flags in "pfxlist" for prefixes, rest
                                 * is compound flags */
)
{
  int todo;
  hashitem_T  *hi;
  affheader_T *ah;
  affentry_T  *ae;
  regmatch_T regmatch;
  char_u newword[MAXWLEN];
  int retval = OK;
  int i, j;
  char_u      *p;
  int use_flags;
  char_u      *use_pfxlist;
  int use_pfxlen;
  int need_affix;
  char_u store_afflist[MAXWLEN];
  char_u pfx_pfxlist[MAXWLEN];
  size_t wordlen = STRLEN(word);
  int use_condit;

  todo = (int)ht->ht_used;
  for (hi = ht->ht_array; todo > 0 && retval == OK; ++hi) {
    if (!HASHITEM_EMPTY(hi)) {
      --todo;
      ah = HI2AH(hi);

      /* Check that the affix combines, if required, and that the word
       * supports this affix. */
      if (((condit & CONDIT_COMB) == 0 || ah->ah_combine)
          && flag_in_afflist(affile->af_flagtype, afflist,
              ah->ah_flag)) {
        /* Loop over all affix entries with this name. */
        for (ae = ah->ah_first; ae != NULL; ae = ae->ae_next) {
          /* Check the condition.  It's not logical to match case
           * here, but it is required for compatibility with
           * Myspell.
           * Another requirement from Myspell is that the chop
           * string is shorter than the word itself.
           * For prefixes, when "PFXPOSTPONE" was used, only do
           * prefixes with a chop string and/or flags.
           * When a previously added affix had CIRCUMFIX this one
           * must have it too, if it had not then this one must not
           * have one either. */
          regmatch.regprog = ae->ae_prog;
          regmatch.rm_ic = FALSE;
          if ((xht != NULL || !affile->af_pfxpostpone
               || ae->ae_chop != NULL
               || ae->ae_flags != NULL)
              && (ae->ae_chop == NULL
                  || STRLEN(ae->ae_chop) < wordlen)
              && (ae->ae_prog == NULL
                  || vim_regexec(&regmatch, word, (colnr_T)0))
              && (((condit & CONDIT_CFIX) == 0)
                  == ((condit & CONDIT_AFF) == 0
                      || ae->ae_flags == NULL
                      || !flag_in_afflist(affile->af_flagtype,
                          ae->ae_flags, affile->af_circumfix)))) {
            /* Match.  Remove the chop and add the affix. */
            if (xht == NULL) {
              /* prefix: chop/add at the start of the word */
              if (ae->ae_add == NULL)
                *newword = NUL;
              else
                vim_strncpy(newword, ae->ae_add, MAXWLEN - 1);
              p = word;
              if (ae->ae_chop != NULL) {
                /* Skip chop string. */
                if (has_mbyte) {
                  i = mb_charlen(ae->ae_chop);
                  for (; i > 0; --i)
                    mb_ptr_adv(p);
                } else
                  p += STRLEN(ae->ae_chop);
              }
              STRCAT(newword, p);
            } else   {
              /* suffix: chop/add at the end of the word */
              vim_strncpy(newword, word, MAXWLEN - 1);
              if (ae->ae_chop != NULL) {
                /* Remove chop string. */
                p = newword + STRLEN(newword);
                i = (int)MB_CHARLEN(ae->ae_chop);
                for (; i > 0; --i)
                  mb_ptr_back(newword, p);
                *p = NUL;
              }
              if (ae->ae_add != NULL)
                STRCAT(newword, ae->ae_add);
            }

            use_flags = flags;
            use_pfxlist = pfxlist;
            use_pfxlen = pfxlen;
            need_affix = FALSE;
            use_condit = condit | CONDIT_COMB | CONDIT_AFF;
            if (ae->ae_flags != NULL) {
              /* Extract flags from the affix list. */
              use_flags |= get_affix_flags(affile, ae->ae_flags);

              if (affile->af_needaffix != 0 && flag_in_afflist(
                      affile->af_flagtype, ae->ae_flags,
                      affile->af_needaffix))
                need_affix = TRUE;

              /* When there is a CIRCUMFIX flag the other affix
               * must also have it and we don't add the word
               * with one affix. */
              if (affile->af_circumfix != 0 && flag_in_afflist(
                      affile->af_flagtype, ae->ae_flags,
                      affile->af_circumfix)) {
                use_condit |= CONDIT_CFIX;
                if ((condit & CONDIT_CFIX) == 0)
                  need_affix = TRUE;
              }

              if (affile->af_pfxpostpone
                  || spin->si_compflags != NULL) {
                if (affile->af_pfxpostpone)
                  /* Get prefix IDS from the affix list. */
                  use_pfxlen = get_pfxlist(affile,
                      ae->ae_flags, store_afflist);
                else
                  use_pfxlen = 0;
                use_pfxlist = store_afflist;

                /* Combine the prefix IDs. Avoid adding the
                 * same ID twice. */
                for (i = 0; i < pfxlen; ++i) {
                  for (j = 0; j < use_pfxlen; ++j)
                    if (pfxlist[i] == use_pfxlist[j])
                      break;
                  if (j == use_pfxlen)
                    use_pfxlist[use_pfxlen++] = pfxlist[i];
                }

                if (spin->si_compflags != NULL)
                  /* Get compound IDS from the affix list. */
                  get_compflags(affile, ae->ae_flags,
                      use_pfxlist + use_pfxlen);

                /* Combine the list of compound flags.
                 * Concatenate them to the prefix IDs list.
                 * Avoid adding the same ID twice. */
                for (i = pfxlen; pfxlist[i] != NUL; ++i) {
                  for (j = use_pfxlen;
                       use_pfxlist[j] != NUL; ++j)
                    if (pfxlist[i] == use_pfxlist[j])
                      break;
                  if (use_pfxlist[j] == NUL) {
                    use_pfxlist[j++] = pfxlist[i];
                    use_pfxlist[j] = NUL;
                  }
                }
              }
            }

            /* Obey a "COMPOUNDFORBIDFLAG" of the affix: don't
             * use the compound flags. */
            if (use_pfxlist != NULL && ae->ae_compforbid) {
              vim_strncpy(pfx_pfxlist, use_pfxlist, use_pfxlen);
              use_pfxlist = pfx_pfxlist;
            }

            /* When there are postponed prefixes... */
            if (spin->si_prefroot != NULL
                && spin->si_prefroot->wn_sibling != NULL) {
              /* ... add a flag to indicate an affix was used. */
              use_flags |= WF_HAS_AFF;

              /* ... don't use a prefix list if combining
               * affixes is not allowed.  But do use the
               * compound flags after them. */
              if (!ah->ah_combine && use_pfxlist != NULL)
                use_pfxlist += use_pfxlen;
            }

            /* When compounding is supported and there is no
             * "COMPOUNDPERMITFLAG" then forbid compounding on the
             * side where the affix is applied. */
            if (spin->si_compflags != NULL && !ae->ae_comppermit) {
              if (xht != NULL)
                use_flags |= WF_NOCOMPAFT;
              else
                use_flags |= WF_NOCOMPBEF;
            }

            /* Store the modified word. */
            if (store_word(spin, newword, use_flags,
                    spin->si_region, use_pfxlist,
                    need_affix) == FAIL)
              retval = FAIL;

            /* When added a prefix or a first suffix and the affix
             * has flags may add a(nother) suffix.  RECURSIVE! */
            if ((condit & CONDIT_SUF) && ae->ae_flags != NULL)
              if (store_aff_word(spin, newword, ae->ae_flags,
                      affile, &affile->af_suff, xht,
                      use_condit & (xht == NULL
                                    ? ~0 :  ~CONDIT_SUF),
                      use_flags, use_pfxlist, pfxlen) == FAIL)
                retval = FAIL;

            /* When added a suffix and combining is allowed also
            * try adding a prefix additionally.  Both for the
            * word flags and for the affix flags.  RECURSIVE! */
            if (xht != NULL && ah->ah_combine) {
              if (store_aff_word(spin, newword,
                      afflist, affile,
                      xht, NULL, use_condit,
                      use_flags, use_pfxlist,
                      pfxlen) == FAIL
                  || (ae->ae_flags != NULL
                      && store_aff_word(spin, newword,
                          ae->ae_flags, affile,
                          xht, NULL, use_condit,
                          use_flags, use_pfxlist,
                          pfxlen) == FAIL))
                retval = FAIL;
            }
          }
        }
      }
    }
  }

  return retval;
}

/*
 * Read a file with a list of words.
 */
static int spell_read_wordfile(spellinfo_T *spin, char_u *fname)
{
  FILE        *fd;
  long lnum = 0;
  char_u rline[MAXLINELEN];
  char_u      *line;
  char_u      *pc = NULL;
  char_u      *p;
  int l;
  int retval = OK;
  int did_word = FALSE;
  int non_ascii = 0;
  int flags;
  int regionmask;

  /*
   * Open the file.
   */
  fd = mch_fopen((char *)fname, "r");
  if (fd == NULL) {
    EMSG2(_(e_notopen), fname);
    return FAIL;
  }

  vim_snprintf((char *)IObuff, IOSIZE, _("Reading word file %s ..."), fname);
  spell_message(spin, IObuff);

  /*
   * Read all the lines in the file one by one.
   */
  while (!vim_fgets(rline, MAXLINELEN, fd) && !got_int) {
    line_breakcheck();
    ++lnum;

    /* Skip comment lines. */
    if (*rline == '#')
      continue;

    /* Remove CR, LF and white space from the end. */
    l = (int)STRLEN(rline);
    while (l > 0 && rline[l - 1] <= ' ')
      --l;
    if (l == 0)
      continue;         /* empty or blank line */
    rline[l] = NUL;

    /* Convert from "/encoding={encoding}" to 'encoding' when needed. */
    vim_free(pc);
    if (spin->si_conv.vc_type != CONV_NONE) {
      pc = string_convert(&spin->si_conv, rline, NULL);
      if (pc == NULL) {
        smsg((char_u *)_("Conversion failure for word in %s line %d: %s"),
            fname, lnum, rline);
        continue;
      }
      line = pc;
    } else   {
      pc = NULL;
      line = rline;
    }

    if (*line == '/') {
      ++line;
      if (STRNCMP(line, "encoding=", 9) == 0) {
        if (spin->si_conv.vc_type != CONV_NONE)
          smsg((char_u *)_(
                  "Duplicate /encoding= line ignored in %s line %d: %s"),
              fname, lnum, line - 1);
        else if (did_word)
          smsg((char_u *)_(
                  "/encoding= line after word ignored in %s line %d: %s"),
              fname, lnum, line - 1);
        else {
          char_u      *enc;

          /* Setup for conversion to 'encoding'. */
          line += 9;
          enc = enc_canonize(line);
          if (enc != NULL && !spin->si_ascii
              && convert_setup(&spin->si_conv, enc,
                  p_enc) == FAIL)
            smsg((char_u *)_("Conversion in %s not supported: from %s to %s"),
                fname, line, p_enc);
          vim_free(enc);
          spin->si_conv.vc_fail = TRUE;
        }
        continue;
      }

      if (STRNCMP(line, "regions=", 8) == 0) {
        if (spin->si_region_count > 1)
          smsg((char_u *)_("Duplicate /regions= line ignored in %s line %d: %s"),
              fname, lnum, line);
        else {
          line += 8;
          if (STRLEN(line) > 16)
            smsg((char_u *)_("Too many regions in %s line %d: %s"),
                fname, lnum, line);
          else {
            spin->si_region_count = (int)STRLEN(line) / 2;
            STRCPY(spin->si_region_name, line);

            /* Adjust the mask for a word valid in all regions. */
            spin->si_region = (1 << spin->si_region_count) - 1;
          }
        }
        continue;
      }

      smsg((char_u *)_("/ line ignored in %s line %d: %s"),
          fname, lnum, line - 1);
      continue;
    }

    flags = 0;
    regionmask = spin->si_region;

    /* Check for flags and region after a slash. */
    p = vim_strchr(line, '/');
    if (p != NULL) {
      *p++ = NUL;
      while (*p != NUL) {
        if (*p == '=')                  /* keep-case word */
          flags |= WF_KEEPCAP | WF_FIXCAP;
        else if (*p == '!')             /* Bad, bad, wicked word. */
          flags |= WF_BANNED;
        else if (*p == '?')             /* Rare word. */
          flags |= WF_RARE;
        else if (VIM_ISDIGIT(*p)) {       /* region number(s) */
          if ((flags & WF_REGION) == 0)             /* first one */
            regionmask = 0;
          flags |= WF_REGION;

          l = *p - '0';
          if (l > spin->si_region_count) {
            smsg((char_u *)_("Invalid region nr in %s line %d: %s"),
                fname, lnum, p);
            break;
          }
          regionmask |= 1 << (l - 1);
        } else   {
          smsg((char_u *)_("Unrecognized flags in %s line %d: %s"),
              fname, lnum, p);
          break;
        }
        ++p;
      }
    }

    /* Skip non-ASCII words when "spin->si_ascii" is TRUE. */
    if (spin->si_ascii && has_non_ascii(line)) {
      ++non_ascii;
      continue;
    }

    /* Normal word: store it. */
    if (store_word(spin, line, flags, regionmask, NULL, FALSE) == FAIL) {
      retval = FAIL;
      break;
    }
    did_word = TRUE;
  }

  vim_free(pc);
  fclose(fd);

  if (spin->si_ascii && non_ascii > 0) {
    vim_snprintf((char *)IObuff, IOSIZE,
        _("Ignored %d words with non-ASCII characters"), non_ascii);
    spell_message(spin, IObuff);
  }

  return retval;
}

/*
 * Get part of an sblock_T, "len" bytes long.
 * This avoids calling free() for every little struct we use (and keeping
 * track of them).
 * The memory is cleared to all zeros.
 * Returns NULL when out of memory.
 */
static void *
getroom (
    spellinfo_T *spin,
    size_t len,                     /* length needed */
    int align                      /* align for pointer */
)
{
  char_u      *p;
  sblock_T    *bl = spin->si_blocks;

  if (align && bl != NULL)
    /* Round size up for alignment.  On some systems structures need to be
     * aligned to the size of a pointer (e.g., SPARC). */
    bl->sb_used = (bl->sb_used + sizeof(char *) - 1)
                  & ~(sizeof(char *) - 1);

  if (bl == NULL || bl->sb_used + len > SBLOCKSIZE) {
    if (len >= SBLOCKSIZE)
      bl = NULL;
    else
      /* Allocate a block of memory. It is not freed until much later. */
      bl = (sblock_T *)alloc_clear(
          (unsigned)(sizeof(sblock_T) + SBLOCKSIZE));
    if (bl == NULL) {
      if (!spin->si_did_emsg) {
        EMSG(_("E845: Insufficient memory, word list will be incomplete"));
        spin->si_did_emsg = TRUE;
      }
      return NULL;
    }
    bl->sb_next = spin->si_blocks;
    spin->si_blocks = bl;
    bl->sb_used = 0;
    ++spin->si_blocks_cnt;
  }

  p = bl->sb_data + bl->sb_used;
  bl->sb_used += (int)len;

  return p;
}

/*
 * Make a copy of a string into memory allocated with getroom().
 * Returns NULL when out of memory.
 */
static char_u *getroom_save(spellinfo_T *spin, char_u *s)
{
  char_u      *sc;

  sc = (char_u *)getroom(spin, STRLEN(s) + 1, FALSE);
  if (sc != NULL)
    STRCPY(sc, s);
  return sc;
}


/*
 * Free the list of allocated sblock_T.
 */
static void free_blocks(sblock_T *bl)
{
  sblock_T    *next;

  while (bl != NULL) {
    next = bl->sb_next;
    vim_free(bl);
    bl = next;
  }
}

/*
 * Allocate the root of a word tree.
 * Returns NULL when out of memory.
 */
static wordnode_T *wordtree_alloc(spellinfo_T *spin)
{
  return (wordnode_T *)getroom(spin, sizeof(wordnode_T), TRUE);
}

/*
 * Store a word in the tree(s).
 * Always store it in the case-folded tree.  For a keep-case word this is
 * useful when the word can also be used with all caps (no WF_FIXCAP flag) and
 * used to find suggestions.
 * For a keep-case word also store it in the keep-case tree.
 * When "pfxlist" is not NULL store the word for each postponed prefix ID and
 * compound flag.
 */
static int 
store_word (
    spellinfo_T *spin,
    char_u *word,
    int flags,                      /* extra flags, WF_BANNED */
    int region,                     /* supported region(s) */
    char_u *pfxlist,           /* list of prefix IDs or NULL */
    int need_affix                 /* only store word with affix ID */
)
{
  int len = (int)STRLEN(word);
  int ct = captype(word, word + len);
  char_u foldword[MAXWLEN];
  int res = OK;
  char_u      *p;

  (void)spell_casefold(word, len, foldword, MAXWLEN);
  for (p = pfxlist; res == OK; ++p) {
    if (!need_affix || (p != NULL && *p != NUL))
      res = tree_add_word(spin, foldword, spin->si_foldroot, ct | flags,
          region, p == NULL ? 0 : *p);
    if (p == NULL || *p == NUL)
      break;
  }
  ++spin->si_foldwcount;

  if (res == OK && (ct == WF_KEEPCAP || (flags & WF_KEEPCAP))) {
    for (p = pfxlist; res == OK; ++p) {
      if (!need_affix || (p != NULL && *p != NUL))
        res = tree_add_word(spin, word, spin->si_keeproot, flags,
            region, p == NULL ? 0 : *p);
      if (p == NULL || *p == NUL)
        break;
    }
    ++spin->si_keepwcount;
  }
  return res;
}

/*
 * Add word "word" to a word tree at "root".
 * When "flags" < 0 we are adding to the prefix tree where "flags" is used for
 * "rare" and "region" is the condition nr.
 * Returns FAIL when out of memory.
 */
static int tree_add_word(spellinfo_T *spin, char_u *word, wordnode_T *root, int flags, int region, int affixID)
{
  wordnode_T  *node = root;
  wordnode_T  *np;
  wordnode_T  *copyp, **copyprev;
  wordnode_T  **prev = NULL;
  int i;

  /* Add each byte of the word to the tree, including the NUL at the end. */
  for (i = 0;; ++i) {
    /* When there is more than one reference to this node we need to make
     * a copy, so that we can modify it.  Copy the whole list of siblings
     * (we don't optimize for a partly shared list of siblings). */
    if (node != NULL && node->wn_refs > 1) {
      --node->wn_refs;
      copyprev = prev;
      for (copyp = node; copyp != NULL; copyp = copyp->wn_sibling) {
        /* Allocate a new node and copy the info. */
        np = get_wordnode(spin);
        if (np == NULL)
          return FAIL;
        np->wn_child = copyp->wn_child;
        if (np->wn_child != NULL)
          ++np->wn_child->wn_refs;              /* child gets extra ref */
        np->wn_byte = copyp->wn_byte;
        if (np->wn_byte == NUL) {
          np->wn_flags = copyp->wn_flags;
          np->wn_region = copyp->wn_region;
          np->wn_affixID = copyp->wn_affixID;
        }

        /* Link the new node in the list, there will be one ref. */
        np->wn_refs = 1;
        if (copyprev != NULL)
          *copyprev = np;
        copyprev = &np->wn_sibling;

        /* Let "node" point to the head of the copied list. */
        if (copyp == node)
          node = np;
      }
    }

    /* Look for the sibling that has the same character.  They are sorted
     * on byte value, thus stop searching when a sibling is found with a
     * higher byte value.  For zero bytes (end of word) the sorting is
     * done on flags and then on affixID. */
    while (node != NULL
           && (node->wn_byte < word[i]
               || (node->wn_byte == NUL
                   && (flags < 0
                       ? node->wn_affixID < (unsigned)affixID
                       : (node->wn_flags < (unsigned)(flags & WN_MASK)
                          || (node->wn_flags == (flags & WN_MASK)
                              && (spin->si_sugtree
                                  ? (node->wn_region & 0xffff) < region
                                  : node->wn_affixID
                                  < (unsigned)affixID))))))) {
      prev = &node->wn_sibling;
      node = *prev;
    }
    if (node == NULL
        || node->wn_byte != word[i]
        || (word[i] == NUL
            && (flags < 0
                || spin->si_sugtree
                || node->wn_flags != (flags & WN_MASK)
                || node->wn_affixID != affixID))) {
      /* Allocate a new node. */
      np = get_wordnode(spin);
      if (np == NULL)
        return FAIL;
      np->wn_byte = word[i];

      /* If "node" is NULL this is a new child or the end of the sibling
       * list: ref count is one.  Otherwise use ref count of sibling and
       * make ref count of sibling one (matters when inserting in front
       * of the list of siblings). */
      if (node == NULL)
        np->wn_refs = 1;
      else {
        np->wn_refs = node->wn_refs;
        node->wn_refs = 1;
      }
      if (prev != NULL)
        *prev = np;
      np->wn_sibling = node;
      node = np;
    }

    if (word[i] == NUL) {
      node->wn_flags = flags;
      node->wn_region |= region;
      node->wn_affixID = affixID;
      break;
    }
    prev = &node->wn_child;
    node = *prev;
  }
#ifdef SPELL_PRINTTREE
  smsg("Added \"%s\"", word);
  spell_print_tree(root->wn_sibling);
#endif

  /* count nr of words added since last message */
  ++spin->si_msg_count;

  if (spin->si_compress_cnt > 1) {
    if (--spin->si_compress_cnt == 1)
      /* Did enough words to lower the block count limit. */
      spin->si_blocks_cnt += compress_inc;
  }

  /*
   * When we have allocated lots of memory we need to compress the word tree
   * to free up some room.  But compression is slow, and we might actually
   * need that room, thus only compress in the following situations:
   * 1. When not compressed before (si_compress_cnt == 0): when using
   *    "compress_start" blocks.
   * 2. When compressed before and used "compress_inc" blocks before
   *    adding "compress_added" words (si_compress_cnt > 1).
   * 3. When compressed before, added "compress_added" words
   *    (si_compress_cnt == 1) and the number of free nodes drops below the
   *    maximum word length.
   */
#ifndef SPELL_PRINTTREE
  if (spin->si_compress_cnt == 1
      ? spin->si_free_count < MAXWLEN
                              : spin->si_blocks_cnt >= compress_start)
#endif
  {
    /* Decrement the block counter.  The effect is that we compress again
     * when the freed up room has been used and another "compress_inc"
     * blocks have been allocated.  Unless "compress_added" words have
     * been added, then the limit is put back again. */
    spin->si_blocks_cnt -= compress_inc;
    spin->si_compress_cnt = compress_added;

    if (spin->si_verbose) {
      msg_start();
      msg_puts((char_u *)_(msg_compressing));
      msg_clr_eos();
      msg_didout = FALSE;
      msg_col = 0;
      out_flush();
    }

    /* Compress both trees.  Either they both have many nodes, which makes
     * compression useful, or one of them is small, which means
     * compression goes fast.  But when filling the soundfold word tree
     * there is no keep-case tree. */
    wordtree_compress(spin, spin->si_foldroot);
    if (affixID >= 0)
      wordtree_compress(spin, spin->si_keeproot);
  }

  return OK;
}

/*
 * Check the 'mkspellmem' option.  Return FAIL if it's wrong.
 * Sets "sps_flags".
 */
int spell_check_msm(void)         {
  char_u      *p = p_msm;
  long start = 0;
  long incr = 0;
  long added = 0;

  if (!VIM_ISDIGIT(*p))
    return FAIL;
  /* block count = (value * 1024) / SBLOCKSIZE (but avoid overflow)*/
  start = (getdigits(&p) * 10) / (SBLOCKSIZE / 102);
  if (*p != ',')
    return FAIL;
  ++p;
  if (!VIM_ISDIGIT(*p))
    return FAIL;
  incr = (getdigits(&p) * 102) / (SBLOCKSIZE / 10);
  if (*p != ',')
    return FAIL;
  ++p;
  if (!VIM_ISDIGIT(*p))
    return FAIL;
  added = getdigits(&p) * 1024;
  if (*p != NUL)
    return FAIL;

  if (start == 0 || incr == 0 || added == 0 || incr > start)
    return FAIL;

  compress_start = start;
  compress_inc = incr;
  compress_added = added;
  return OK;
}

/*
 * Get a wordnode_T, either from the list of previously freed nodes or
 * allocate a new one.
 * Returns NULL when out of memory.
 */
static wordnode_T *get_wordnode(spellinfo_T *spin)
{
  wordnode_T *n;

  if (spin->si_first_free == NULL)
    n = (wordnode_T *)getroom(spin, sizeof(wordnode_T), TRUE);
  else {
    n = spin->si_first_free;
    spin->si_first_free = n->wn_child;
    vim_memset(n, 0, sizeof(wordnode_T));
    --spin->si_free_count;
  }
#ifdef SPELL_PRINTTREE
  if (n != NULL)
    n->wn_nr = ++spin->si_wordnode_nr;
#endif
  return n;
}

/*
 * Decrement the reference count on a node (which is the head of a list of
 * siblings).  If the reference count becomes zero free the node and its
 * siblings.
 * Returns the number of nodes actually freed.
 */
static int deref_wordnode(spellinfo_T *spin, wordnode_T *node)
{
  wordnode_T  *np;
  int cnt = 0;

  if (--node->wn_refs == 0) {
    for (np = node; np != NULL; np = np->wn_sibling) {
      if (np->wn_child != NULL)
        cnt += deref_wordnode(spin, np->wn_child);
      free_wordnode(spin, np);
      ++cnt;
    }
    ++cnt;          /* length field */
  }
  return cnt;
}

/*
 * Free a wordnode_T for re-use later.
 * Only the "wn_child" field becomes invalid.
 */
static void free_wordnode(spellinfo_T *spin, wordnode_T *n)
{
  n->wn_child = spin->si_first_free;
  spin->si_first_free = n;
  ++spin->si_free_count;
}

/*
 * Compress a tree: find tails that are identical and can be shared.
 */
static void wordtree_compress(spellinfo_T *spin, wordnode_T *root)
{
  hashtab_T ht;
  int n;
  int tot = 0;
  int perc;

  /* Skip the root itself, it's not actually used.  The first sibling is the
   * start of the tree. */
  if (root->wn_sibling != NULL) {
    hash_init(&ht);
    n = node_compress(spin, root->wn_sibling, &ht, &tot);

#ifndef SPELL_PRINTTREE
    if (spin->si_verbose || p_verbose > 2)
#endif
    {
      if (tot > 1000000)
        perc = (tot - n) / (tot / 100);
      else if (tot == 0)
        perc = 0;
      else
        perc = (tot - n) * 100 / tot;
      vim_snprintf((char *)IObuff, IOSIZE,
          _("Compressed %d of %d nodes; %d (%d%%) remaining"),
          n, tot, tot - n, perc);
      spell_message(spin, IObuff);
    }
#ifdef SPELL_PRINTTREE
    spell_print_tree(root->wn_sibling);
#endif
    hash_clear(&ht);
  }
}

/*
 * Compress a node, its siblings and its children, depth first.
 * Returns the number of compressed nodes.
 */
static int 
node_compress (
    spellinfo_T *spin,
    wordnode_T *node,
    hashtab_T *ht,
    int *tot           /* total count of nodes before compressing,
                               incremented while going through the tree */
)
{
  wordnode_T  *np;
  wordnode_T  *tp;
  wordnode_T  *child;
  hash_T hash;
  hashitem_T  *hi;
  int len = 0;
  unsigned nr, n;
  int compressed = 0;

  /*
   * Go through the list of siblings.  Compress each child and then try
   * finding an identical child to replace it.
   * Note that with "child" we mean not just the node that is pointed to,
   * but the whole list of siblings of which the child node is the first.
   */
  for (np = node; np != NULL && !got_int; np = np->wn_sibling) {
    ++len;
    if ((child = np->wn_child) != NULL) {
      /* Compress the child first.  This fills hashkey. */
      compressed += node_compress(spin, child, ht, tot);

      /* Try to find an identical child. */
      hash = hash_hash(child->wn_u1.hashkey);
      hi = hash_lookup(ht, child->wn_u1.hashkey, hash);
      if (!HASHITEM_EMPTY(hi)) {
        /* There are children we encountered before with a hash value
         * identical to the current child.  Now check if there is one
         * that is really identical. */
        for (tp = HI2WN(hi); tp != NULL; tp = tp->wn_u2.next)
          if (node_equal(child, tp)) {
            /* Found one!  Now use that child in place of the
             * current one.  This means the current child and all
             * its siblings is unlinked from the tree. */
            ++tp->wn_refs;
            compressed += deref_wordnode(spin, child);
            np->wn_child = tp;
            break;
          }
        if (tp == NULL) {
          /* No other child with this hash value equals the child of
           * the node, add it to the linked list after the first
           * item. */
          tp = HI2WN(hi);
          child->wn_u2.next = tp->wn_u2.next;
          tp->wn_u2.next = child;
        }
      } else
        /* No other child has this hash value, add it to the
         * hashtable. */
        hash_add_item(ht, hi, child->wn_u1.hashkey, hash);
    }
  }
  *tot += len + 1;      /* add one for the node that stores the length */

  /*
   * Make a hash key for the node and its siblings, so that we can quickly
   * find a lookalike node.  This must be done after compressing the sibling
   * list, otherwise the hash key would become invalid by the compression.
   */
  node->wn_u1.hashkey[0] = len;
  nr = 0;
  for (np = node; np != NULL; np = np->wn_sibling) {
    if (np->wn_byte == NUL)
      /* end node: use wn_flags, wn_region and wn_affixID */
      n = np->wn_flags + (np->wn_region << 8) + (np->wn_affixID << 16);
    else
      /* byte node: use the byte value and the child pointer */
      n = (unsigned)(np->wn_byte + ((long_u)np->wn_child << 8));
    nr = nr * 101 + n;
  }

  /* Avoid NUL bytes, it terminates the hash key. */
  n = nr & 0xff;
  node->wn_u1.hashkey[1] = n == 0 ? 1 : n;
  n = (nr >> 8) & 0xff;
  node->wn_u1.hashkey[2] = n == 0 ? 1 : n;
  n = (nr >> 16) & 0xff;
  node->wn_u1.hashkey[3] = n == 0 ? 1 : n;
  n = (nr >> 24) & 0xff;
  node->wn_u1.hashkey[4] = n == 0 ? 1 : n;
  node->wn_u1.hashkey[5] = NUL;

  /* Check for CTRL-C pressed now and then. */
  fast_breakcheck();

  return compressed;
}

/*
 * Return TRUE when two nodes have identical siblings and children.
 */
static int node_equal(wordnode_T *n1, wordnode_T *n2)
{
  wordnode_T  *p1;
  wordnode_T  *p2;

  for (p1 = n1, p2 = n2; p1 != NULL && p2 != NULL;
       p1 = p1->wn_sibling, p2 = p2->wn_sibling)
    if (p1->wn_byte != p2->wn_byte
        || (p1->wn_byte == NUL
            ? (p1->wn_flags != p2->wn_flags
               || p1->wn_region != p2->wn_region
               || p1->wn_affixID != p2->wn_affixID)
            : (p1->wn_child != p2->wn_child)))
      break;

  return p1 == NULL && p2 == NULL;
}

static int
rep_compare(const void *s1, const void *s2);

/*
 * Function given to qsort() to sort the REP items on "from" string.
 */
static int rep_compare(const void *s1, const void *s2)
{
  fromto_T    *p1 = (fromto_T *)s1;
  fromto_T    *p2 = (fromto_T *)s2;

  return STRCMP(p1->ft_from, p2->ft_from);
}

/*
 * Write the Vim .spl file "fname".
 * Return FAIL or OK;
 */
static int write_vim_spell(spellinfo_T *spin, char_u *fname)
{
  FILE        *fd;
  int regionmask;
  int round;
  wordnode_T  *tree;
  int nodecount;
  int i;
  int l;
  garray_T    *gap;
  fromto_T    *ftp;
  char_u      *p;
  int rr;
  int retval = OK;
  size_t fwv = 1;         /* collect return value of fwrite() to avoid
                             warnings from picky compiler */

  fd = mch_fopen((char *)fname, "w");
  if (fd == NULL) {
    EMSG2(_(e_notopen), fname);
    return FAIL;
  }

  /* <HEADER>: <fileID> <versionnr> */
  /* <fileID> */
  fwv &= fwrite(VIMSPELLMAGIC, VIMSPELLMAGICL, (size_t)1, fd);
  if (fwv != (size_t)1)
    /* Catch first write error, don't try writing more. */
    goto theend;

  putc(VIMSPELLVERSION, fd);                                /* <versionnr> */

  /*
   * <SECTIONS>: <section> ... <sectionend>
   */

  /* SN_INFO: <infotext> */
  if (spin->si_info != NULL) {
    putc(SN_INFO, fd);                                  /* <sectionID> */
    putc(0, fd);                                        /* <sectionflags> */

    i = (int)STRLEN(spin->si_info);
    put_bytes(fd, (long_u)i, 4);                        /* <sectionlen> */
    fwv &= fwrite(spin->si_info, (size_t)i, (size_t)1, fd);     /* <infotext> */
  }

  /* SN_REGION: <regionname> ...
   * Write the region names only if there is more than one. */
  if (spin->si_region_count > 1) {
    putc(SN_REGION, fd);                                /* <sectionID> */
    putc(SNF_REQUIRED, fd);                             /* <sectionflags> */
    l = spin->si_region_count * 2;
    put_bytes(fd, (long_u)l, 4);                        /* <sectionlen> */
    fwv &= fwrite(spin->si_region_name, (size_t)l, (size_t)1, fd);
    /* <regionname> ... */
    regionmask = (1 << spin->si_region_count) - 1;
  } else
    regionmask = 0;

  /* SN_CHARFLAGS: <charflagslen> <charflags> <folcharslen> <folchars>
   *
   * The table with character flags and the table for case folding.
   * This makes sure the same characters are recognized as word characters
   * when generating an when using a spell file.
   * Skip this for ASCII, the table may conflict with the one used for
   * 'encoding'.
   * Also skip this for an .add.spl file, the main spell file must contain
   * the table (avoids that it conflicts).  File is shorter too.
   */
  if (!spin->si_ascii && !spin->si_add) {
    char_u folchars[128 * 8];
    int flags;

    putc(SN_CHARFLAGS, fd);                             /* <sectionID> */
    putc(SNF_REQUIRED, fd);                             /* <sectionflags> */

    /* Form the <folchars> string first, we need to know its length. */
    l = 0;
    for (i = 128; i < 256; ++i) {
      if (has_mbyte)
        l += mb_char2bytes(spelltab.st_fold[i], folchars + l);
      else
        folchars[l++] = spelltab.st_fold[i];
    }
    put_bytes(fd, (long_u)(1 + 128 + 2 + l), 4);        /* <sectionlen> */

    fputc(128, fd);                                     /* <charflagslen> */
    for (i = 128; i < 256; ++i) {
      flags = 0;
      if (spelltab.st_isw[i])
        flags |= CF_WORD;
      if (spelltab.st_isu[i])
        flags |= CF_UPPER;
      fputc(flags, fd);                                 /* <charflags> */
    }

    put_bytes(fd, (long_u)l, 2);                        /* <folcharslen> */
    fwv &= fwrite(folchars, (size_t)l, (size_t)1, fd);     /* <folchars> */
  }

  /* SN_MIDWORD: <midword> */
  if (spin->si_midword != NULL) {
    putc(SN_MIDWORD, fd);                               /* <sectionID> */
    putc(SNF_REQUIRED, fd);                             /* <sectionflags> */

    i = (int)STRLEN(spin->si_midword);
    put_bytes(fd, (long_u)i, 4);                        /* <sectionlen> */
    fwv &= fwrite(spin->si_midword, (size_t)i, (size_t)1, fd);
    /* <midword> */
  }

  /* SN_PREFCOND: <prefcondcnt> <prefcond> ... */
  if (spin->si_prefcond.ga_len > 0) {
    putc(SN_PREFCOND, fd);                              /* <sectionID> */
    putc(SNF_REQUIRED, fd);                             /* <sectionflags> */

    l = write_spell_prefcond(NULL, &spin->si_prefcond);
    put_bytes(fd, (long_u)l, 4);                        /* <sectionlen> */

    write_spell_prefcond(fd, &spin->si_prefcond);
  }

  /* SN_REP: <repcount> <rep> ...
   * SN_SAL: <salflags> <salcount> <sal> ...
   * SN_REPSAL: <repcount> <rep> ... */

  /* round 1: SN_REP section
   * round 2: SN_SAL section (unless SN_SOFO is used)
   * round 3: SN_REPSAL section */
  for (round = 1; round <= 3; ++round) {
    if (round == 1)
      gap = &spin->si_rep;
    else if (round == 2) {
      /* Don't write SN_SAL when using a SN_SOFO section */
      if (spin->si_sofofr != NULL && spin->si_sofoto != NULL)
        continue;
      gap = &spin->si_sal;
    } else
      gap = &spin->si_repsal;

    /* Don't write the section if there are no items. */
    if (gap->ga_len == 0)
      continue;

    /* Sort the REP/REPSAL items. */
    if (round != 2)
      qsort(gap->ga_data, (size_t)gap->ga_len,
          sizeof(fromto_T), rep_compare);

    i = round == 1 ? SN_REP : (round == 2 ? SN_SAL : SN_REPSAL);
    putc(i, fd);                                        /* <sectionID> */

    /* This is for making suggestions, section is not required. */
    putc(0, fd);                                        /* <sectionflags> */

    /* Compute the length of what follows. */
    l = 2;          /* count <repcount> or <salcount> */
    for (i = 0; i < gap->ga_len; ++i) {
      ftp = &((fromto_T *)gap->ga_data)[i];
      l += 1 + (int)STRLEN(ftp->ft_from);        /* count <*fromlen> and <*from> */
      l += 1 + (int)STRLEN(ftp->ft_to);          /* count <*tolen> and <*to> */
    }
    if (round == 2)
      ++l;              /* count <salflags> */
    put_bytes(fd, (long_u)l, 4);                        /* <sectionlen> */

    if (round == 2) {
      i = 0;
      if (spin->si_followup)
        i |= SAL_F0LLOWUP;
      if (spin->si_collapse)
        i |= SAL_COLLAPSE;
      if (spin->si_rem_accents)
        i |= SAL_REM_ACCENTS;
      putc(i, fd);                              /* <salflags> */
    }

    put_bytes(fd, (long_u)gap->ga_len, 2);      /* <repcount> or <salcount> */
    for (i = 0; i < gap->ga_len; ++i) {
      /* <rep> : <repfromlen> <repfrom> <reptolen> <repto> */
      /* <sal> : <salfromlen> <salfrom> <saltolen> <salto> */
      ftp = &((fromto_T *)gap->ga_data)[i];
      for (rr = 1; rr <= 2; ++rr) {
        p = rr == 1 ? ftp->ft_from : ftp->ft_to;
        l = (int)STRLEN(p);
        putc(l, fd);
        if (l > 0)
          fwv &= fwrite(p, l, (size_t)1, fd);
      }
    }

  }

  /* SN_SOFO: <sofofromlen> <sofofrom> <sofotolen> <sofoto>
   * This is for making suggestions, section is not required. */
  if (spin->si_sofofr != NULL && spin->si_sofoto != NULL) {
    putc(SN_SOFO, fd);                                  /* <sectionID> */
    putc(0, fd);                                        /* <sectionflags> */

    l = (int)STRLEN(spin->si_sofofr);
    put_bytes(fd, (long_u)(l + STRLEN(spin->si_sofoto) + 4), 4);
    /* <sectionlen> */

    put_bytes(fd, (long_u)l, 2);                        /* <sofofromlen> */
    fwv &= fwrite(spin->si_sofofr, l, (size_t)1, fd);     /* <sofofrom> */

    l = (int)STRLEN(spin->si_sofoto);
    put_bytes(fd, (long_u)l, 2);                        /* <sofotolen> */
    fwv &= fwrite(spin->si_sofoto, l, (size_t)1, fd);     /* <sofoto> */
  }

  /* SN_WORDS: <word> ...
   * This is for making suggestions, section is not required. */
  if (spin->si_commonwords.ht_used > 0) {
    putc(SN_WORDS, fd);                                 /* <sectionID> */
    putc(0, fd);                                        /* <sectionflags> */

    /* round 1: count the bytes
     * round 2: write the bytes */
    for (round = 1; round <= 2; ++round) {
      int todo;
      int len = 0;
      hashitem_T  *hi;

      todo = (int)spin->si_commonwords.ht_used;
      for (hi = spin->si_commonwords.ht_array; todo > 0; ++hi)
        if (!HASHITEM_EMPTY(hi)) {
          l = (int)STRLEN(hi->hi_key) + 1;
          len += l;
          if (round == 2)                               /* <word> */
            fwv &= fwrite(hi->hi_key, (size_t)l, (size_t)1, fd);
          --todo;
        }
      if (round == 1)
        put_bytes(fd, (long_u)len, 4);                  /* <sectionlen> */
    }
  }

  /* SN_MAP: <mapstr>
   * This is for making suggestions, section is not required. */
  if (spin->si_map.ga_len > 0) {
    putc(SN_MAP, fd);                                   /* <sectionID> */
    putc(0, fd);                                        /* <sectionflags> */
    l = spin->si_map.ga_len;
    put_bytes(fd, (long_u)l, 4);                        /* <sectionlen> */
    fwv &= fwrite(spin->si_map.ga_data, (size_t)l, (size_t)1, fd);
    /* <mapstr> */
  }

  /* SN_SUGFILE: <timestamp>
   * This is used to notify that a .sug file may be available and at the
   * same time allows for checking that a .sug file that is found matches
   * with this .spl file.  That's because the word numbers must be exactly
   * right. */
  if (!spin->si_nosugfile
      && (spin->si_sal.ga_len > 0
          || (spin->si_sofofr != NULL && spin->si_sofoto != NULL))) {
    putc(SN_SUGFILE, fd);                               /* <sectionID> */
    putc(0, fd);                                        /* <sectionflags> */
    put_bytes(fd, (long_u)8, 4);                        /* <sectionlen> */

    /* Set si_sugtime and write it to the file. */
    spin->si_sugtime = time(NULL);
    put_time(fd, spin->si_sugtime);                     /* <timestamp> */
  }

  /* SN_NOSPLITSUGS: nothing
   * This is used to notify that no suggestions with word splits are to be
   * made. */
  if (spin->si_nosplitsugs) {
    putc(SN_NOSPLITSUGS, fd);                           /* <sectionID> */
    putc(0, fd);                                        /* <sectionflags> */
    put_bytes(fd, (long_u)0, 4);                        /* <sectionlen> */
  }

  /* SN_COMPOUND: compound info.
   * We don't mark it required, when not supported all compound words will
   * be bad words. */
  if (spin->si_compflags != NULL) {
    putc(SN_COMPOUND, fd);                              /* <sectionID> */
    putc(0, fd);                                        /* <sectionflags> */

    l = (int)STRLEN(spin->si_compflags);
    for (i = 0; i < spin->si_comppat.ga_len; ++i)
      l += (int)STRLEN(((char_u **)(spin->si_comppat.ga_data))[i]) + 1;
    put_bytes(fd, (long_u)(l + 7), 4);                  /* <sectionlen> */

    putc(spin->si_compmax, fd);                         /* <compmax> */
    putc(spin->si_compminlen, fd);                      /* <compminlen> */
    putc(spin->si_compsylmax, fd);                      /* <compsylmax> */
    putc(0, fd);                /* for Vim 7.0b compatibility */
    putc(spin->si_compoptions, fd);                     /* <compoptions> */
    put_bytes(fd, (long_u)spin->si_comppat.ga_len, 2);
    /* <comppatcount> */
    for (i = 0; i < spin->si_comppat.ga_len; ++i) {
      p = ((char_u **)(spin->si_comppat.ga_data))[i];
      putc((int)STRLEN(p), fd);                         /* <comppatlen> */
      fwv &= fwrite(p, (size_t)STRLEN(p), (size_t)1, fd);
      /* <comppattext> */
    }
    /* <compflags> */
    fwv &= fwrite(spin->si_compflags, (size_t)STRLEN(spin->si_compflags),
        (size_t)1, fd);
  }

  /* SN_NOBREAK: NOBREAK flag */
  if (spin->si_nobreak) {
    putc(SN_NOBREAK, fd);                               /* <sectionID> */
    putc(0, fd);                                        /* <sectionflags> */

    /* It's empty, the presence of the section flags the feature. */
    put_bytes(fd, (long_u)0, 4);                        /* <sectionlen> */
  }

  /* SN_SYLLABLE: syllable info.
   * We don't mark it required, when not supported syllables will not be
   * counted. */
  if (spin->si_syllable != NULL) {
    putc(SN_SYLLABLE, fd);                              /* <sectionID> */
    putc(0, fd);                                        /* <sectionflags> */

    l = (int)STRLEN(spin->si_syllable);
    put_bytes(fd, (long_u)l, 4);                        /* <sectionlen> */
    fwv &= fwrite(spin->si_syllable, (size_t)l, (size_t)1, fd);
    /* <syllable> */
  }

  /* end of <SECTIONS> */
  putc(SN_END, fd);                                     /* <sectionend> */


  /*
   * <LWORDTREE>  <KWORDTREE>  <PREFIXTREE>
   */
  spin->si_memtot = 0;
  for (round = 1; round <= 3; ++round) {
    if (round == 1)
      tree = spin->si_foldroot->wn_sibling;
    else if (round == 2)
      tree = spin->si_keeproot->wn_sibling;
    else
      tree = spin->si_prefroot->wn_sibling;

    /* Clear the index and wnode fields in the tree. */
    clear_node(tree);

    /* Count the number of nodes.  Needed to be able to allocate the
     * memory when reading the nodes.  Also fills in index for shared
     * nodes. */
    nodecount = put_node(NULL, tree, 0, regionmask, round == 3);

    /* number of nodes in 4 bytes */
    put_bytes(fd, (long_u)nodecount, 4);        /* <nodecount> */
    spin->si_memtot += nodecount + nodecount * sizeof(int);

    /* Write the nodes. */
    (void)put_node(fd, tree, 0, regionmask, round == 3);
  }

  /* Write another byte to check for errors (file system full). */
  if (putc(0, fd) == EOF)
    retval = FAIL;
theend:
  if (fclose(fd) == EOF)
    retval = FAIL;

  if (fwv != (size_t)1)
    retval = FAIL;
  if (retval == FAIL)
    EMSG(_(e_write));

  return retval;
}

/*
 * Clear the index and wnode fields of "node", it siblings and its
 * children.  This is needed because they are a union with other items to save
 * space.
 */
static void clear_node(wordnode_T *node)
{
  wordnode_T  *np;

  if (node != NULL)
    for (np = node; np != NULL; np = np->wn_sibling) {
      np->wn_u1.index = 0;
      np->wn_u2.wnode = NULL;

      if (np->wn_byte != NUL)
        clear_node(np->wn_child);
    }
}


/*
 * Dump a word tree at node "node".
 *
 * This first writes the list of possible bytes (siblings).  Then for each
 * byte recursively write the children.
 *
 * NOTE: The code here must match the code in read_tree_node(), since
 * assumptions are made about the indexes (so that we don't have to write them
 * in the file).
 *
 * Returns the number of nodes used.
 */
static int 
put_node (
    FILE *fd,                /* NULL when only counting */
    wordnode_T *node,
    int idx,
    int regionmask,
    int prefixtree                 /* TRUE for PREFIXTREE */
)
{
  int newindex = idx;
  int siblingcount = 0;
  wordnode_T  *np;
  int flags;

  /* If "node" is zero the tree is empty. */
  if (node == NULL)
    return 0;

  /* Store the index where this node is written. */
  node->wn_u1.index = idx;

  /* Count the number of siblings. */
  for (np = node; np != NULL; np = np->wn_sibling)
    ++siblingcount;

  /* Write the sibling count. */
  if (fd != NULL)
    putc(siblingcount, fd);                             /* <siblingcount> */

  /* Write each sibling byte and optionally extra info. */
  for (np = node; np != NULL; np = np->wn_sibling) {
    if (np->wn_byte == 0) {
      if (fd != NULL) {
        /* For a NUL byte (end of word) write the flags etc. */
        if (prefixtree) {
          /* In PREFIXTREE write the required affixID and the
           * associated condition nr (stored in wn_region).  The
           * byte value is misused to store the "rare" and "not
           * combining" flags */
          if (np->wn_flags == (short_u)PFX_FLAGS)
            putc(BY_NOFLAGS, fd);                       /* <byte> */
          else {
            putc(BY_FLAGS, fd);                         /* <byte> */
            putc(np->wn_flags, fd);                     /* <pflags> */
          }
          putc(np->wn_affixID, fd);                     /* <affixID> */
          put_bytes(fd, (long_u)np->wn_region, 2);           /* <prefcondnr> */
        } else   {
          /* For word trees we write the flag/region items. */
          flags = np->wn_flags;
          if (regionmask != 0 && np->wn_region != regionmask)
            flags |= WF_REGION;
          if (np->wn_affixID != 0)
            flags |= WF_AFX;
          if (flags == 0) {
            /* word without flags or region */
            putc(BY_NOFLAGS, fd);                               /* <byte> */
          } else   {
            if (np->wn_flags >= 0x100) {
              putc(BY_FLAGS2, fd);                              /* <byte> */
              putc(flags, fd);                                  /* <flags> */
              putc((unsigned)flags >> 8, fd);                   /* <flags2> */
            } else   {
              putc(BY_FLAGS, fd);                               /* <byte> */
              putc(flags, fd);                                  /* <flags> */
            }
            if (flags & WF_REGION)
              putc(np->wn_region, fd);                          /* <region> */
            if (flags & WF_AFX)
              putc(np->wn_affixID, fd);                         /* <affixID> */
          }
        }
      }
    } else   {
      if (np->wn_child->wn_u1.index != 0
          && np->wn_child->wn_u2.wnode != node) {
        /* The child is written elsewhere, write the reference. */
        if (fd != NULL) {
          putc(BY_INDEX, fd);                           /* <byte> */
                                                        /* <nodeidx> */
          put_bytes(fd, (long_u)np->wn_child->wn_u1.index, 3);
        }
      } else if (np->wn_child->wn_u2.wnode == NULL)
        /* We will write the child below and give it an index. */
        np->wn_child->wn_u2.wnode = node;

      if (fd != NULL)
        if (putc(np->wn_byte, fd) == EOF) {       /* <byte> or <xbyte> */
          EMSG(_(e_write));
          return 0;
        }
    }
  }

  /* Space used in the array when reading: one for each sibling and one for
   * the count. */
  newindex += siblingcount + 1;

  /* Recursively dump the children of each sibling. */
  for (np = node; np != NULL; np = np->wn_sibling)
    if (np->wn_byte != 0 && np->wn_child->wn_u2.wnode == node)
      newindex = put_node(fd, np->wn_child, newindex, regionmask,
          prefixtree);

  return newindex;
}


/*
 * ":mkspell [-ascii] outfile  infile ..."
 * ":mkspell [-ascii] addfile"
 */
void ex_mkspell(exarg_T *eap)
{
  int fcount;
  char_u      **fnames;
  char_u      *arg = eap->arg;
  int ascii = FALSE;

  if (STRNCMP(arg, "-ascii", 6) == 0) {
    ascii = TRUE;
    arg = skipwhite(arg + 6);
  }

  /* Expand all the remaining arguments (e.g., $VIMRUNTIME). */
  if (get_arglist_exp(arg, &fcount, &fnames, FALSE) == OK) {
    mkspell(fcount, fnames, ascii, eap->forceit, FALSE);
    FreeWild(fcount, fnames);
  }
}

/*
 * Create the .sug file.
 * Uses the soundfold info in "spin".
 * Writes the file with the name "wfname", with ".spl" changed to ".sug".
 */
static void spell_make_sugfile(spellinfo_T *spin, char_u *wfname)
{
  char_u      *fname = NULL;
  int len;
  slang_T     *slang;
  int free_slang = FALSE;

  /*
   * Read back the .spl file that was written.  This fills the required
   * info for soundfolding.  This also uses less memory than the
   * pointer-linked version of the trie.  And it avoids having two versions
   * of the code for the soundfolding stuff.
   * It might have been done already by spell_reload_one().
   */
  for (slang = first_lang; slang != NULL; slang = slang->sl_next)
    if (fullpathcmp(wfname, slang->sl_fname, FALSE) == FPC_SAME)
      break;
  if (slang == NULL) {
    spell_message(spin, (char_u *)_("Reading back spell file..."));
    slang = spell_load_file(wfname, NULL, NULL, FALSE);
    if (slang == NULL)
      return;
    free_slang = TRUE;
  }

  /*
   * Clear the info in "spin" that is used.
   */
  spin->si_blocks = NULL;
  spin->si_blocks_cnt = 0;
  spin->si_compress_cnt = 0;        /* will stay at 0 all the time*/
  spin->si_free_count = 0;
  spin->si_first_free = NULL;
  spin->si_foldwcount = 0;

  /*
   * Go through the trie of good words, soundfold each word and add it to
   * the soundfold trie.
   */
  spell_message(spin, (char_u *)_("Performing soundfolding..."));
  if (sug_filltree(spin, slang) == FAIL)
    goto theend;

  /*
   * Create the table which links each soundfold word with a list of the
   * good words it may come from.  Creates buffer "spin->si_spellbuf".
   * This also removes the wordnr from the NUL byte entries to make
   * compression possible.
   */
  if (sug_maketable(spin) == FAIL)
    goto theend;

  smsg((char_u *)_("Number of words after soundfolding: %ld"),
      (long)spin->si_spellbuf->b_ml.ml_line_count);

  /*
   * Compress the soundfold trie.
   */
  spell_message(spin, (char_u *)_(msg_compressing));
  wordtree_compress(spin, spin->si_foldroot);

  /*
   * Write the .sug file.
   * Make the file name by changing ".spl" to ".sug".
   */
  fname = alloc(MAXPATHL);
  if (fname == NULL)
    goto theend;
  vim_strncpy(fname, wfname, MAXPATHL - 1);
  len = (int)STRLEN(fname);
  fname[len - 2] = 'u';
  fname[len - 1] = 'g';
  sug_write(spin, fname);

theend:
  vim_free(fname);
  if (free_slang)
    slang_free(slang);
  free_blocks(spin->si_blocks);
  close_spellbuf(spin->si_spellbuf);
}

/*
 * Build the soundfold trie for language "slang".
 */
static int sug_filltree(spellinfo_T *spin, slang_T *slang)
{
  char_u      *byts;
  idx_T       *idxs;
  int depth;
  idx_T arridx[MAXWLEN];
  int curi[MAXWLEN];
  char_u tword[MAXWLEN];
  char_u tsalword[MAXWLEN];
  int c;
  idx_T n;
  unsigned words_done = 0;
  int wordcount[MAXWLEN];

  /* We use si_foldroot for the soundfolded trie. */
  spin->si_foldroot = wordtree_alloc(spin);
  if (spin->si_foldroot == NULL)
    return FAIL;

  /* let tree_add_word() know we're adding to the soundfolded tree */
  spin->si_sugtree = TRUE;

  /*
   * Go through the whole case-folded tree, soundfold each word and put it
   * in the trie.
   */
  byts = slang->sl_fbyts;
  idxs = slang->sl_fidxs;

  arridx[0] = 0;
  curi[0] = 1;
  wordcount[0] = 0;

  depth = 0;
  while (depth >= 0 && !got_int) {
    if (curi[depth] > byts[arridx[depth]]) {
      /* Done all bytes at this node, go up one level. */
      idxs[arridx[depth]] = wordcount[depth];
      if (depth > 0)
        wordcount[depth - 1] += wordcount[depth];

      --depth;
      line_breakcheck();
    } else   {

      /* Do one more byte at this node. */
      n = arridx[depth] + curi[depth];
      ++curi[depth];

      c = byts[n];
      if (c == 0) {
        /* Sound-fold the word. */
        tword[depth] = NUL;
        spell_soundfold(slang, tword, TRUE, tsalword);

        /* We use the "flags" field for the MSB of the wordnr,
         * "region" for the LSB of the wordnr.  */
        if (tree_add_word(spin, tsalword, spin->si_foldroot,
                words_done >> 16, words_done & 0xffff,
                0) == FAIL)
          return FAIL;

        ++words_done;
        ++wordcount[depth];

        /* Reset the block count each time to avoid compression
         * kicking in. */
        spin->si_blocks_cnt = 0;

        /* Skip over any other NUL bytes (same word with different
         * flags). */
        while (byts[n + 1] == 0) {
          ++n;
          ++curi[depth];
        }
      } else   {
        /* Normal char, go one level deeper. */
        tword[depth++] = c;
        arridx[depth] = idxs[n];
        curi[depth] = 1;
        wordcount[depth] = 0;
      }
    }
  }

  smsg((char_u *)_("Total number of words: %d"), words_done);

  return OK;
}

/*
 * Make the table that links each word in the soundfold trie to the words it
 * can be produced from.
 * This is not unlike lines in a file, thus use a memfile to be able to access
 * the table efficiently.
 * Returns FAIL when out of memory.
 */
static int sug_maketable(spellinfo_T *spin)
{
  garray_T ga;
  int res = OK;

  /* Allocate a buffer, open a memline for it and create the swap file
   * (uses a temp file, not a .swp file). */
  spin->si_spellbuf = open_spellbuf();
  if (spin->si_spellbuf == NULL)
    return FAIL;

  /* Use a buffer to store the line info, avoids allocating many small
   * pieces of memory. */
  ga_init2(&ga, 1, 100);

  /* recursively go through the tree */
  if (sug_filltable(spin, spin->si_foldroot->wn_sibling, 0, &ga) == -1)
    res = FAIL;

  ga_clear(&ga);
  return res;
}

/*
 * Fill the table for one node and its children.
 * Returns the wordnr at the start of the node.
 * Returns -1 when out of memory.
 */
static int 
sug_filltable (
    spellinfo_T *spin,
    wordnode_T *node,
    int startwordnr,
    garray_T *gap           /* place to store line of numbers */
)
{
  wordnode_T  *p, *np;
  int wordnr = startwordnr;
  int nr;
  int prev_nr;

  for (p = node; p != NULL; p = p->wn_sibling) {
    if (p->wn_byte == NUL) {
      gap->ga_len = 0;
      prev_nr = 0;
      for (np = p; np != NULL && np->wn_byte == NUL; np = np->wn_sibling) {
        if (ga_grow(gap, 10) == FAIL)
          return -1;

        nr = (np->wn_flags << 16) + (np->wn_region & 0xffff);
        /* Compute the offset from the previous nr and store the
         * offset in a way that it takes a minimum number of bytes.
         * It's a bit like utf-8, but without the need to mark
         * following bytes. */
        nr -= prev_nr;
        prev_nr += nr;
        gap->ga_len += offset2bytes(nr,
            (char_u *)gap->ga_data + gap->ga_len);
      }

      /* add the NUL byte */
      ((char_u *)gap->ga_data)[gap->ga_len++] = NUL;

      if (ml_append_buf(spin->si_spellbuf, (linenr_T)wordnr,
              gap->ga_data, gap->ga_len, TRUE) == FAIL)
        return -1;
      ++wordnr;

      /* Remove extra NUL entries, we no longer need them. We don't
       * bother freeing the nodes, the won't be reused anyway. */
      while (p->wn_sibling != NULL && p->wn_sibling->wn_byte == NUL)
        p->wn_sibling = p->wn_sibling->wn_sibling;

      /* Clear the flags on the remaining NUL node, so that compression
       * works a lot better. */
      p->wn_flags = 0;
      p->wn_region = 0;
    } else   {
      wordnr = sug_filltable(spin, p->wn_child, wordnr, gap);
      if (wordnr == -1)
        return -1;
    }
  }
  return wordnr;
}

/*
 * Convert an offset into a minimal number of bytes.
 * Similar to utf_char2byters, but use 8 bits in followup bytes and avoid NUL
 * bytes.
 */
static int offset2bytes(int nr, char_u *buf)
{
  int rem;
  int b1, b2, b3, b4;

  /* Split the number in parts of base 255.  We need to avoid NUL bytes. */
  b1 = nr % 255 + 1;
  rem = nr / 255;
  b2 = rem % 255 + 1;
  rem = rem / 255;
  b3 = rem % 255 + 1;
  b4 = rem / 255 + 1;

  if (b4 > 1 || b3 > 0x1f) {    /* 4 bytes */
    buf[0] = 0xe0 + b4;
    buf[1] = b3;
    buf[2] = b2;
    buf[3] = b1;
    return 4;
  }
  if (b3 > 1 || b2 > 0x3f ) {   /* 3 bytes */
    buf[0] = 0xc0 + b3;
    buf[1] = b2;
    buf[2] = b1;
    return 3;
  }
  if (b2 > 1 || b1 > 0x7f ) {   /* 2 bytes */
    buf[0] = 0x80 + b2;
    buf[1] = b1;
    return 2;
  }
  /* 1 byte */
  buf[0] = b1;
  return 1;
}

/*
 * Opposite of offset2bytes().
 * "pp" points to the bytes and is advanced over it.
 * Returns the offset.
 */
static int bytes2offset(char_u **pp)
{
  char_u      *p = *pp;
  int nr;
  int c;

  c = *p++;
  if ((c & 0x80) == 0x00) {             /* 1 byte */
    nr = c - 1;
  } else if ((c & 0xc0) == 0x80)   {    /* 2 bytes */
    nr = (c & 0x3f) - 1;
    nr = nr * 255 + (*p++ - 1);
  } else if ((c & 0xe0) == 0xc0)   {    /* 3 bytes */
    nr = (c & 0x1f) - 1;
    nr = nr * 255 + (*p++ - 1);
    nr = nr * 255 + (*p++ - 1);
  } else   {                            /* 4 bytes */
    nr = (c & 0x0f) - 1;
    nr = nr * 255 + (*p++ - 1);
    nr = nr * 255 + (*p++ - 1);
    nr = nr * 255 + (*p++ - 1);
  }

  *pp = p;
  return nr;
}

/*
 * Write the .sug file in "fname".
 */
static void sug_write(spellinfo_T *spin, char_u *fname)
{
  FILE        *fd;
  wordnode_T  *tree;
  int nodecount;
  int wcount;
  char_u      *line;
  linenr_T lnum;
  int len;

  /* Create the file.  Note that an existing file is silently overwritten! */
  fd = mch_fopen((char *)fname, "w");
  if (fd == NULL) {
    EMSG2(_(e_notopen), fname);
    return;
  }

  vim_snprintf((char *)IObuff, IOSIZE,
      _("Writing suggestion file %s ..."), fname);
  spell_message(spin, IObuff);

  /*
   * <SUGHEADER>: <fileID> <versionnr> <timestamp>
   */
  if (fwrite(VIMSUGMAGIC, VIMSUGMAGICL, (size_t)1, fd) != 1) { /* <fileID> */
    EMSG(_(e_write));
    goto theend;
  }
  putc(VIMSUGVERSION, fd);                              /* <versionnr> */

  /* Write si_sugtime to the file. */
  put_time(fd, spin->si_sugtime);                       /* <timestamp> */

  /*
   * <SUGWORDTREE>
   */
  spin->si_memtot = 0;
  tree = spin->si_foldroot->wn_sibling;

  /* Clear the index and wnode fields in the tree. */
  clear_node(tree);

  /* Count the number of nodes.  Needed to be able to allocate the
   * memory when reading the nodes.  Also fills in index for shared
   * nodes. */
  nodecount = put_node(NULL, tree, 0, 0, FALSE);

  /* number of nodes in 4 bytes */
  put_bytes(fd, (long_u)nodecount, 4);          /* <nodecount> */
  spin->si_memtot += nodecount + nodecount * sizeof(int);

  /* Write the nodes. */
  (void)put_node(fd, tree, 0, 0, FALSE);

  /*
   * <SUGTABLE>: <sugwcount> <sugline> ...
   */
  wcount = spin->si_spellbuf->b_ml.ml_line_count;
  put_bytes(fd, (long_u)wcount, 4);     /* <sugwcount> */

  for (lnum = 1; lnum <= (linenr_T)wcount; ++lnum) {
    /* <sugline>: <sugnr> ... NUL */
    line = ml_get_buf(spin->si_spellbuf, lnum, FALSE);
    len = (int)STRLEN(line) + 1;
    if (fwrite(line, (size_t)len, (size_t)1, fd) == 0) {
      EMSG(_(e_write));
      goto theend;
    }
    spin->si_memtot += len;
  }

  /* Write another byte to check for errors. */
  if (putc(0, fd) == EOF)
    EMSG(_(e_write));

  vim_snprintf((char *)IObuff, IOSIZE,
      _("Estimated runtime memory use: %d bytes"), spin->si_memtot);
  spell_message(spin, IObuff);

theend:
  /* close the file */
  fclose(fd);
}

/*
 * Open a spell buffer.  This is a nameless buffer that is not in the buffer
 * list and only contains text lines.  Can use a swapfile to reduce memory
 * use.
 * Most other fields are invalid!  Esp. watch out for string options being
 * NULL and there is no undo info.
 * Returns NULL when out of memory.
 */
static buf_T *open_spellbuf(void)                    {
  buf_T       *buf;

  buf = (buf_T *)alloc_clear(sizeof(buf_T));
  if (buf != NULL) {
    buf->b_spell = TRUE;
    buf->b_p_swf = TRUE;        /* may create a swap file */
    buf->b_p_key = empty_option;
    ml_open(buf);
    ml_open_file(buf);          /* create swap file now */
  }
  return buf;
}

/*
 * Close the buffer used for spell info.
 */
static void close_spellbuf(buf_T *buf)
{
  if (buf != NULL) {
    ml_close(buf, TRUE);
    vim_free(buf);
  }
}


/*
 * Create a Vim spell file from one or more word lists.
 * "fnames[0]" is the output file name.
 * "fnames[fcount - 1]" is the last input file name.
 * Exception: when "fnames[0]" ends in ".add" it's used as the input file name
 * and ".spl" is appended to make the output file name.
 */
static void 
mkspell (
    int fcount,
    char_u **fnames,
    int ascii,                          /* -ascii argument given */
    int over_write,                     /* overwrite existing output file */
    int added_word                     /* invoked through "zg" */
)
{
  char_u      *fname = NULL;
  char_u      *wfname;
  char_u      **innames;
  int incount;
  afffile_T   *(afile[8]);
  int i;
  int len;
  struct stat st;
  int error = FALSE;
  spellinfo_T spin;

  vim_memset(&spin, 0, sizeof(spin));
  spin.si_verbose = !added_word;
  spin.si_ascii = ascii;
  spin.si_followup = TRUE;
  spin.si_rem_accents = TRUE;
  ga_init2(&spin.si_rep, (int)sizeof(fromto_T), 20);
  ga_init2(&spin.si_repsal, (int)sizeof(fromto_T), 20);
  ga_init2(&spin.si_sal, (int)sizeof(fromto_T), 20);
  ga_init2(&spin.si_map, (int)sizeof(char_u), 100);
  ga_init2(&spin.si_comppat, (int)sizeof(char_u *), 20);
  ga_init2(&spin.si_prefcond, (int)sizeof(char_u *), 50);
  hash_init(&spin.si_commonwords);
  spin.si_newcompID = 127;      /* start compound ID at first maximum */

  /* default: fnames[0] is output file, following are input files */
  innames = &fnames[1];
  incount = fcount - 1;

  wfname = alloc(MAXPATHL);
  if (wfname == NULL)
    return;

  if (fcount >= 1) {
    len = (int)STRLEN(fnames[0]);
    if (fcount == 1 && len > 4 && STRCMP(fnames[0] + len - 4, ".add") == 0) {
      /* For ":mkspell path/en.latin1.add" output file is
       * "path/en.latin1.add.spl". */
      innames = &fnames[0];
      incount = 1;
      vim_snprintf((char *)wfname, MAXPATHL, "%s.spl", fnames[0]);
    } else if (fcount == 1)   {
      /* For ":mkspell path/vim" output file is "path/vim.latin1.spl". */
      innames = &fnames[0];
      incount = 1;
      vim_snprintf((char *)wfname, MAXPATHL, SPL_FNAME_TMPL,
          fnames[0], spin.si_ascii ? (char_u *)"ascii" : spell_enc());
    } else if (len > 4 && STRCMP(fnames[0] + len - 4, ".spl") == 0)   {
      /* Name ends in ".spl", use as the file name. */
      vim_strncpy(wfname, fnames[0], MAXPATHL - 1);
    } else
      /* Name should be language, make the file name from it. */
      vim_snprintf((char *)wfname, MAXPATHL, SPL_FNAME_TMPL,
          fnames[0], spin.si_ascii ? (char_u *)"ascii" : spell_enc());

    /* Check for .ascii.spl. */
    if (strstr((char *)gettail(wfname), SPL_FNAME_ASCII) != NULL)
      spin.si_ascii = TRUE;

    /* Check for .add.spl. */
    if (strstr((char *)gettail(wfname), SPL_FNAME_ADD) != NULL)
      spin.si_add = TRUE;
  }

  if (incount <= 0)
    EMSG(_(e_invarg));          /* need at least output and input names */
  else if (vim_strchr(gettail(wfname), '_') != NULL)
    EMSG(_("E751: Output file name must not have region name"));
  else if (incount > 8)
    EMSG(_("E754: Only up to 8 regions supported"));
  else {
    /* Check for overwriting before doing things that may take a lot of
     * time. */
    if (!over_write && mch_stat((char *)wfname, &st) >= 0) {
      EMSG(_(e_exists));
      goto theend;
    }
    if (mch_isdir(wfname)) {
      EMSG2(_(e_isadir2), wfname);
      goto theend;
    }

    fname = alloc(MAXPATHL);
    if (fname == NULL)
      goto theend;

    /*
     * Init the aff and dic pointers.
     * Get the region names if there are more than 2 arguments.
     */
    for (i = 0; i < incount; ++i) {
      afile[i] = NULL;

      if (incount > 1) {
        len = (int)STRLEN(innames[i]);
        if (STRLEN(gettail(innames[i])) < 5
            || innames[i][len - 3] != '_') {
          EMSG2(_("E755: Invalid region in %s"), innames[i]);
          goto theend;
        }
        spin.si_region_name[i * 2] = TOLOWER_ASC(innames[i][len - 2]);
        spin.si_region_name[i * 2 + 1] =
          TOLOWER_ASC(innames[i][len - 1]);
      }
    }
    spin.si_region_count = incount;

    spin.si_foldroot = wordtree_alloc(&spin);
    spin.si_keeproot = wordtree_alloc(&spin);
    spin.si_prefroot = wordtree_alloc(&spin);
    if (spin.si_foldroot == NULL
        || spin.si_keeproot == NULL
        || spin.si_prefroot == NULL) {
      free_blocks(spin.si_blocks);
      goto theend;
    }

    /* When not producing a .add.spl file clear the character table when
     * we encounter one in the .aff file.  This means we dump the current
     * one in the .spl file if the .aff file doesn't define one.  That's
     * better than guessing the contents, the table will match a
     * previously loaded spell file. */
    if (!spin.si_add)
      spin.si_clear_chartab = TRUE;

    /*
     * Read all the .aff and .dic files.
     * Text is converted to 'encoding'.
     * Words are stored in the case-folded and keep-case trees.
     */
    for (i = 0; i < incount && !error; ++i) {
      spin.si_conv.vc_type = CONV_NONE;
      spin.si_region = 1 << i;

      vim_snprintf((char *)fname, MAXPATHL, "%s.aff", innames[i]);
      if (mch_stat((char *)fname, &st) >= 0) {
        /* Read the .aff file.  Will init "spin->si_conv" based on the
         * "SET" line. */
        afile[i] = spell_read_aff(&spin, fname);
        if (afile[i] == NULL)
          error = TRUE;
        else {
          /* Read the .dic file and store the words in the trees. */
          vim_snprintf((char *)fname, MAXPATHL, "%s.dic",
              innames[i]);
          if (spell_read_dic(&spin, fname, afile[i]) == FAIL)
            error = TRUE;
        }
      } else   {
        /* No .aff file, try reading the file as a word list.  Store
         * the words in the trees. */
        if (spell_read_wordfile(&spin, innames[i]) == FAIL)
          error = TRUE;
      }

      /* Free any conversion stuff. */
      convert_setup(&spin.si_conv, NULL, NULL);
    }

    if (spin.si_compflags != NULL && spin.si_nobreak)
      MSG(_("Warning: both compounding and NOBREAK specified"));

    if (!error && !got_int) {
      /*
       * Combine tails in the tree.
       */
      spell_message(&spin, (char_u *)_(msg_compressing));
      wordtree_compress(&spin, spin.si_foldroot);
      wordtree_compress(&spin, spin.si_keeproot);
      wordtree_compress(&spin, spin.si_prefroot);
    }

    if (!error && !got_int) {
      /*
       * Write the info in the spell file.
       */
      vim_snprintf((char *)IObuff, IOSIZE,
          _("Writing spell file %s ..."), wfname);
      spell_message(&spin, IObuff);

      error = write_vim_spell(&spin, wfname) == FAIL;

      spell_message(&spin, (char_u *)_("Done!"));
      vim_snprintf((char *)IObuff, IOSIZE,
          _("Estimated runtime memory use: %d bytes"), spin.si_memtot);
      spell_message(&spin, IObuff);

      /*
       * If the file is loaded need to reload it.
       */
      if (!error)
        spell_reload_one(wfname, added_word);
    }

    /* Free the allocated memory. */
    ga_clear(&spin.si_rep);
    ga_clear(&spin.si_repsal);
    ga_clear(&spin.si_sal);
    ga_clear(&spin.si_map);
    ga_clear(&spin.si_comppat);
    ga_clear(&spin.si_prefcond);
    hash_clear_all(&spin.si_commonwords, 0);

    /* Free the .aff file structures. */
    for (i = 0; i < incount; ++i)
      if (afile[i] != NULL)
        spell_free_aff(afile[i]);

    /* Free all the bits and pieces at once. */
    free_blocks(spin.si_blocks);

    /*
     * If there is soundfolding info and no NOSUGFILE item create the
     * .sug file with the soundfolded word trie.
     */
    if (spin.si_sugtime != 0 && !error && !got_int)
      spell_make_sugfile(&spin, wfname);

  }

theend:
  vim_free(fname);
  vim_free(wfname);
}

/*
 * Display a message for spell file processing when 'verbose' is set or using
 * ":mkspell".  "str" can be IObuff.
 */
static void spell_message(spellinfo_T *spin, char_u *str)
{
  if (spin->si_verbose || p_verbose > 2) {
    if (!spin->si_verbose)
      verbose_enter();
    MSG(str);
    out_flush();
    if (!spin->si_verbose)
      verbose_leave();
  }
}

/*
 * ":[count]spellgood  {word}"
 * ":[count]spellwrong  {word}"
 * ":[count]spellundo  {word}"
 */
void ex_spell(exarg_T *eap)
{
  spell_add_word(eap->arg, (int)STRLEN(eap->arg), eap->cmdidx == CMD_spellwrong,
      eap->forceit ? 0 : (int)eap->line2,
      eap->cmdidx == CMD_spellundo);
}

/*
 * Add "word[len]" to 'spellfile' as a good or bad word.
 */
void 
spell_add_word (
    char_u *word,
    int len,
    int bad,
    int idx,                    /* "zG" and "zW": zero, otherwise index in
                               'spellfile' */
    int undo                   /* TRUE for "zug", "zuG", "zuw" and "zuW" */
)
{
  FILE        *fd = NULL;
  buf_T       *buf = NULL;
  int new_spf = FALSE;
  char_u      *fname;
  char_u      *fnamebuf = NULL;
  char_u line[MAXWLEN * 2];
  long fpos, fpos_next = 0;
  int i;
  char_u      *spf;

  if (idx == 0) {           /* use internal wordlist */
    if (int_wordlist == NULL) {
      int_wordlist = vim_tempname('s');
      if (int_wordlist == NULL)
        return;
    }
    fname = int_wordlist;
  } else   {
    /* If 'spellfile' isn't set figure out a good default value. */
    if (*curwin->w_s->b_p_spf == NUL) {
      init_spellfile();
      new_spf = TRUE;
    }

    if (*curwin->w_s->b_p_spf == NUL) {
      EMSG2(_(e_notset), "spellfile");
      return;
    }
    fnamebuf = alloc(MAXPATHL);
    if (fnamebuf == NULL)
      return;

    for (spf = curwin->w_s->b_p_spf, i = 1; *spf != NUL; ++i) {
      copy_option_part(&spf, fnamebuf, MAXPATHL, ",");
      if (i == idx)
        break;
      if (*spf == NUL) {
        EMSGN(_("E765: 'spellfile' does not have %ld entries"), idx);
        vim_free(fnamebuf);
        return;
      }
    }

    /* Check that the user isn't editing the .add file somewhere. */
    buf = buflist_findname_exp(fnamebuf);
    if (buf != NULL && buf->b_ml.ml_mfp == NULL)
      buf = NULL;
    if (buf != NULL && bufIsChanged(buf)) {
      EMSG(_(e_bufloaded));
      vim_free(fnamebuf);
      return;
    }

    fname = fnamebuf;
  }

  if (bad || undo) {
    /* When the word appears as good word we need to remove that one,
     * since its flags sort before the one with WF_BANNED. */
    fd = mch_fopen((char *)fname, "r");
    if (fd != NULL) {
      while (!vim_fgets(line, MAXWLEN * 2, fd)) {
        fpos = fpos_next;
        fpos_next = ftell(fd);
        if (STRNCMP(word, line, len) == 0
            && (line[len] == '/' || line[len] < ' ')) {
          /* Found duplicate word.  Remove it by writing a '#' at
           * the start of the line.  Mixing reading and writing
           * doesn't work for all systems, close the file first. */
          fclose(fd);
          fd = mch_fopen((char *)fname, "r+");
          if (fd == NULL)
            break;
          if (fseek(fd, fpos, SEEK_SET) == 0) {
            fputc('#', fd);
            if (undo) {
              home_replace(NULL, fname, NameBuff, MAXPATHL, TRUE);
              smsg((char_u *)_("Word '%.*s' removed from %s"),
                  len, word, NameBuff);
            }
          }
          fseek(fd, fpos_next, SEEK_SET);
        }
      }
      if (fd != NULL)
        fclose(fd);
    }
  }

  if (!undo) {
    fd = mch_fopen((char *)fname, "a");
    if (fd == NULL && new_spf) {
      char_u *p;

      /* We just initialized the 'spellfile' option and can't open the
       * file.  We may need to create the "spell" directory first.  We
       * already checked the runtime directory is writable in
       * init_spellfile(). */
      if (!dir_of_file_exists(fname) && (p = gettail_sep(fname)) != fname) {
        int c = *p;

        /* The directory doesn't exist.  Try creating it and opening
         * the file again. */
        *p = NUL;
        vim_mkdir(fname, 0755);
        *p = c;
        fd = mch_fopen((char *)fname, "a");
      }
    }

    if (fd == NULL)
      EMSG2(_(e_notopen), fname);
    else {
      if (bad)
        fprintf(fd, "%.*s/!\n", len, word);
      else
        fprintf(fd, "%.*s\n", len, word);
      fclose(fd);

      home_replace(NULL, fname, NameBuff, MAXPATHL, TRUE);
      smsg((char_u *)_("Word '%.*s' added to %s"), len, word, NameBuff);
    }
  }

  if (fd != NULL) {
    /* Update the .add.spl file. */
    mkspell(1, &fname, FALSE, TRUE, TRUE);

    /* If the .add file is edited somewhere, reload it. */
    if (buf != NULL)
      buf_reload(buf, buf->b_orig_mode);

    redraw_all_later(SOME_VALID);
  }
  vim_free(fnamebuf);
}

/*
 * Initialize 'spellfile' for the current buffer.
 */
static void init_spellfile(void)                 {
  char_u      *buf;
  int l;
  char_u      *fname;
  char_u      *rtp;
  char_u      *lend;
  int aspath = FALSE;
  char_u      *lstart = curbuf->b_s.b_p_spl;

  if (*curwin->w_s->b_p_spl != NUL && curwin->w_s->b_langp.ga_len > 0) {
    buf = alloc(MAXPATHL);
    if (buf == NULL)
      return;

    /* Find the end of the language name.  Exclude the region.  If there
     * is a path separator remember the start of the tail. */
    for (lend = curwin->w_s->b_p_spl; *lend != NUL
         && vim_strchr((char_u *)",._", *lend) == NULL; ++lend)
      if (vim_ispathsep(*lend)) {
        aspath = TRUE;
        lstart = lend + 1;
      }

    /* Loop over all entries in 'runtimepath'.  Use the first one where we
     * are allowed to write. */
    rtp = p_rtp;
    while (*rtp != NUL) {
      if (aspath)
        /* Use directory of an entry with path, e.g., for
         * "/dir/lg.utf-8.spl" use "/dir". */
        vim_strncpy(buf, curbuf->b_s.b_p_spl,
            lstart - curbuf->b_s.b_p_spl - 1);
      else
        /* Copy the path from 'runtimepath' to buf[]. */
        copy_option_part(&rtp, buf, MAXPATHL, ",");
      if (filewritable(buf) == 2) {
        /* Use the first language name from 'spelllang' and the
         * encoding used in the first loaded .spl file. */
        if (aspath)
          vim_strncpy(buf, curbuf->b_s.b_p_spl,
              lend - curbuf->b_s.b_p_spl);
        else {
          /* Create the "spell" directory if it doesn't exist yet. */
          l = (int)STRLEN(buf);
          vim_snprintf((char *)buf + l, MAXPATHL - l, "/spell");
          if (filewritable(buf) != 2)
            vim_mkdir(buf, 0755);

          l = (int)STRLEN(buf);
          vim_snprintf((char *)buf + l, MAXPATHL - l,
              "/%.*s", (int)(lend - lstart), lstart);
        }
        l = (int)STRLEN(buf);
        fname = LANGP_ENTRY(curwin->w_s->b_langp, 0)
                ->lp_slang->sl_fname;
        vim_snprintf((char *)buf + l, MAXPATHL - l, ".%s.add",
            fname != NULL
            && strstr((char *)gettail(fname), ".ascii.") != NULL
            ? (char_u *)"ascii" : spell_enc());
        set_option_value((char_u *)"spellfile", 0L, buf, OPT_LOCAL);
        break;
      }
      aspath = FALSE;
    }

    vim_free(buf);
  }
}

/*
 * Init the chartab used for spelling for ASCII.
 * EBCDIC is not supported!
 */
static void clear_spell_chartab(spelltab_T *sp)
{
  int i;

  /* Init everything to FALSE. */
  vim_memset(sp->st_isw, FALSE, sizeof(sp->st_isw));
  vim_memset(sp->st_isu, FALSE, sizeof(sp->st_isu));
  for (i = 0; i < 256; ++i) {
    sp->st_fold[i] = i;
    sp->st_upper[i] = i;
  }

  /* We include digits.  A word shouldn't start with a digit, but handling
   * that is done separately. */
  for (i = '0'; i <= '9'; ++i)
    sp->st_isw[i] = TRUE;
  for (i = 'A'; i <= 'Z'; ++i) {
    sp->st_isw[i] = TRUE;
    sp->st_isu[i] = TRUE;
    sp->st_fold[i] = i + 0x20;
  }
  for (i = 'a'; i <= 'z'; ++i) {
    sp->st_isw[i] = TRUE;
    sp->st_upper[i] = i - 0x20;
  }
}

/*
 * Init the chartab used for spelling.  Only depends on 'encoding'.
 * Called once while starting up and when 'encoding' changes.
 * The default is to use isalpha(), but the spell file should define the word
 * characters to make it possible that 'encoding' differs from the current
 * locale.  For utf-8 we don't use isalpha() but our own functions.
 */
void init_spell_chartab(void)          {
  int i;

  did_set_spelltab = FALSE;
  clear_spell_chartab(&spelltab);
  if (enc_dbcs) {
    /* DBCS: assume double-wide characters are word characters. */
    for (i = 128; i <= 255; ++i)
      if (MB_BYTE2LEN(i) == 2)
        spelltab.st_isw[i] = TRUE;
  } else if (enc_utf8)   {
    for (i = 128; i < 256; ++i) {
      int f = utf_fold(i);
      int u = utf_toupper(i);

      spelltab.st_isu[i] = utf_isupper(i);
      spelltab.st_isw[i] = spelltab.st_isu[i] || utf_islower(i);
      /* The folded/upper-cased value is different between latin1 and
       * utf8 for 0xb5, causing E763 for no good reason.  Use the latin1
       * value for utf-8 to avoid this. */
      spelltab.st_fold[i] = (f < 256) ? f : i;
      spelltab.st_upper[i] = (u < 256) ? u : i;
    }
  } else   {
    /* Rough guess: use locale-dependent library functions. */
    for (i = 128; i < 256; ++i) {
      if (MB_ISUPPER(i)) {
        spelltab.st_isw[i] = TRUE;
        spelltab.st_isu[i] = TRUE;
        spelltab.st_fold[i] = MB_TOLOWER(i);
      } else if (MB_ISLOWER(i))   {
        spelltab.st_isw[i] = TRUE;
        spelltab.st_upper[i] = MB_TOUPPER(i);
      }
    }
  }
}

/*
 * Set the spell character tables from strings in the affix file.
 */
static int set_spell_chartab(char_u *fol, char_u *low, char_u *upp)
{
  /* We build the new tables here first, so that we can compare with the
   * previous one. */
  spelltab_T new_st;
  char_u      *pf = fol, *pl = low, *pu = upp;
  int f, l, u;

  clear_spell_chartab(&new_st);

  while (*pf != NUL) {
    if (*pl == NUL || *pu == NUL) {
      EMSG(_(e_affform));
      return FAIL;
    }
    f = mb_ptr2char_adv(&pf);
    l = mb_ptr2char_adv(&pl);
    u = mb_ptr2char_adv(&pu);
    /* Every character that appears is a word character. */
    if (f < 256)
      new_st.st_isw[f] = TRUE;
    if (l < 256)
      new_st.st_isw[l] = TRUE;
    if (u < 256)
      new_st.st_isw[u] = TRUE;

    /* if "LOW" and "FOL" are not the same the "LOW" char needs
     * case-folding */
    if (l < 256 && l != f) {
      if (f >= 256) {
        EMSG(_(e_affrange));
        return FAIL;
      }
      new_st.st_fold[l] = f;
    }

    /* if "UPP" and "FOL" are not the same the "UPP" char needs
     * case-folding, it's upper case and the "UPP" is the upper case of
     * "FOL" . */
    if (u < 256 && u != f) {
      if (f >= 256) {
        EMSG(_(e_affrange));
        return FAIL;
      }
      new_st.st_fold[u] = f;
      new_st.st_isu[u] = TRUE;
      new_st.st_upper[f] = u;
    }
  }

  if (*pl != NUL || *pu != NUL) {
    EMSG(_(e_affform));
    return FAIL;
  }

  return set_spell_finish(&new_st);
}

/*
 * Set the spell character tables from strings in the .spl file.
 */
static void 
set_spell_charflags (
    char_u *flags,
    int cnt,                    /* length of "flags" */
    char_u *fol
)
{
  /* We build the new tables here first, so that we can compare with the
   * previous one. */
  spelltab_T new_st;
  int i;
  char_u      *p = fol;
  int c;

  clear_spell_chartab(&new_st);

  for (i = 0; i < 128; ++i) {
    if (i < cnt) {
      new_st.st_isw[i + 128] = (flags[i] & CF_WORD) != 0;
      new_st.st_isu[i + 128] = (flags[i] & CF_UPPER) != 0;
    }

    if (*p != NUL) {
      c = mb_ptr2char_adv(&p);
      new_st.st_fold[i + 128] = c;
      if (i + 128 != c && new_st.st_isu[i + 128] && c < 256)
        new_st.st_upper[c] = i + 128;
    }
  }

  (void)set_spell_finish(&new_st);
}

static int set_spell_finish(spelltab_T *new_st)
{
  int i;

  if (did_set_spelltab) {
    /* check that it's the same table */
    for (i = 0; i < 256; ++i) {
      if (spelltab.st_isw[i] != new_st->st_isw[i]
          || spelltab.st_isu[i] != new_st->st_isu[i]
          || spelltab.st_fold[i] != new_st->st_fold[i]
          || spelltab.st_upper[i] != new_st->st_upper[i]) {
        EMSG(_("E763: Word characters differ between spell files"));
        return FAIL;
      }
    }
  } else   {
    /* copy the new spelltab into the one being used */
    spelltab = *new_st;
    did_set_spelltab = TRUE;
  }

  return OK;
}

/*
 * Return TRUE if "p" points to a word character.
 * As a special case we see "midword" characters as word character when it is
 * followed by a word character.  This finds they'there but not 'they there'.
 * Thus this only works properly when past the first character of the word.
 */
static int 
spell_iswordp (
    char_u *p,
    win_T *wp            /* buffer used */
)
{
  char_u      *s;
  int l;
  int c;

  if (has_mbyte) {
    l = MB_BYTE2LEN(*p);
    s = p;
    if (l == 1) {
      /* be quick for ASCII */
      if (wp->w_s->b_spell_ismw[*p])
        s = p + 1;                      /* skip a mid-word character */
    } else   {
      c = mb_ptr2char(p);
      if (c < 256 ? wp->w_s->b_spell_ismw[c]
          : (wp->w_s->b_spell_ismw_mb != NULL
             && vim_strchr(wp->w_s->b_spell_ismw_mb, c) != NULL))
        s = p + l;
    }

    c = mb_ptr2char(s);
    if (c > 255)
      return spell_mb_isword_class(mb_get_class(s), wp);
    return spelltab.st_isw[c];
  }

  return spelltab.st_isw[wp->w_s->b_spell_ismw[*p] ? p[1] : p[0]];
}

/*
 * Return TRUE if "p" points to a word character.
 * Unlike spell_iswordp() this doesn't check for "midword" characters.
 */
static int spell_iswordp_nmw(char_u *p, win_T *wp)
{
  int c;

  if (has_mbyte) {
    c = mb_ptr2char(p);
    if (c > 255)
      return spell_mb_isword_class(mb_get_class(p), wp);
    return spelltab.st_isw[c];
  }
  return spelltab.st_isw[*p];
}

/*
 * Return TRUE if word class indicates a word character.
 * Only for characters above 255.
 * Unicode subscript and superscript are not considered word characters.
 * See also dbcs_class() and utf_class() in mbyte.c.
 */
static int spell_mb_isword_class(int cl, win_T *wp)
{
  if (wp->w_s->b_cjk)
    /* East Asian characters are not considered word characters. */
    return cl == 2 || cl == 0x2800;
  return cl >= 2 && cl != 0x2070 && cl != 0x2080;
}

/*
 * Return TRUE if "p" points to a word character.
 * Wide version of spell_iswordp().
 */
static int spell_iswordp_w(int *p, win_T *wp)
{
  int         *s;

  if (*p < 256 ? wp->w_s->b_spell_ismw[*p]
      : (wp->w_s->b_spell_ismw_mb != NULL
         && vim_strchr(wp->w_s->b_spell_ismw_mb, *p) != NULL))
    s = p + 1;
  else
    s = p;

  if (*s > 255) {
    if (enc_utf8)
      return spell_mb_isword_class(utf_class(*s), wp);
    if (enc_dbcs)
      return spell_mb_isword_class(
          dbcs_class((unsigned)*s >> 8, *s & 0xff), wp);
    return 0;
  }
  return spelltab.st_isw[*s];
}

/*
 * Write the table with prefix conditions to the .spl file.
 * When "fd" is NULL only count the length of what is written.
 */
static int write_spell_prefcond(FILE *fd, garray_T *gap)
{
  int i;
  char_u      *p;
  int len;
  int totlen;
  size_t x = 1;         /* collect return value of fwrite() */

  if (fd != NULL)
    put_bytes(fd, (long_u)gap->ga_len, 2);          /* <prefcondcnt> */

  totlen = 2 + gap->ga_len;   /* length of <prefcondcnt> and <condlen> bytes */

  for (i = 0; i < gap->ga_len; ++i) {
    /* <prefcond> : <condlen> <condstr> */
    p = ((char_u **)gap->ga_data)[i];
    if (p != NULL) {
      len = (int)STRLEN(p);
      if (fd != NULL) {
        fputc(len, fd);
        x &= fwrite(p, (size_t)len, (size_t)1, fd);
      }
      totlen += len;
    } else if (fd != NULL)
      fputc(0, fd);
  }

  return totlen;
}

/*
 * Case-fold "str[len]" into "buf[buflen]".  The result is NUL terminated.
 * Uses the character definitions from the .spl file.
 * When using a multi-byte 'encoding' the length may change!
 * Returns FAIL when something wrong.
 */
static int spell_casefold(char_u *str, int len, char_u *buf, int buflen)
{
  int i;

  if (len >= buflen) {
    buf[0] = NUL;
    return FAIL;                /* result will not fit */
  }

  if (has_mbyte) {
    int outi = 0;
    char_u  *p;
    int c;

    /* Fold one character at a time. */
    for (p = str; p < str + len; ) {
      if (outi + MB_MAXBYTES > buflen) {
        buf[outi] = NUL;
        return FAIL;
      }
      c = mb_cptr2char_adv(&p);
      outi += mb_char2bytes(SPELL_TOFOLD(c), buf + outi);
    }
    buf[outi] = NUL;
  } else   {
    /* Be quick for non-multibyte encodings. */
    for (i = 0; i < len; ++i)
      buf[i] = spelltab.st_fold[str[i]];
    buf[i] = NUL;
  }

  return OK;
}

/* values for sps_flags */
#define SPS_BEST    1
#define SPS_FAST    2
#define SPS_DOUBLE  4

static int sps_flags = SPS_BEST;        /* flags from 'spellsuggest' */
static int sps_limit = 9999;            /* max nr of suggestions given */

/*
 * Check the 'spellsuggest' option.  Return FAIL if it's wrong.
 * Sets "sps_flags" and "sps_limit".
 */
int spell_check_sps(void)         {
  char_u      *p;
  char_u      *s;
  char_u buf[MAXPATHL];
  int f;

  sps_flags = 0;
  sps_limit = 9999;

  for (p = p_sps; *p != NUL; ) {
    copy_option_part(&p, buf, MAXPATHL, ",");

    f = 0;
    if (VIM_ISDIGIT(*buf)) {
      s = buf;
      sps_limit = getdigits(&s);
      if (*s != NUL && !VIM_ISDIGIT(*s))
        f = -1;
    } else if (STRCMP(buf, "best") == 0)
      f = SPS_BEST;
    else if (STRCMP(buf, "fast") == 0)
      f = SPS_FAST;
    else if (STRCMP(buf, "double") == 0)
      f = SPS_DOUBLE;
    else if (STRNCMP(buf, "expr:", 5) != 0
             && STRNCMP(buf, "file:", 5) != 0)
      f = -1;

    if (f == -1 || (sps_flags != 0 && f != 0)) {
      sps_flags = SPS_BEST;
      sps_limit = 9999;
      return FAIL;
    }
    if (f != 0)
      sps_flags = f;
  }

  if (sps_flags == 0)
    sps_flags = SPS_BEST;

  return OK;
}

/*
 * "z=": Find badly spelled word under or after the cursor.
 * Give suggestions for the properly spelled word.
 * In Visual mode use the highlighted word as the bad word.
 * When "count" is non-zero use that suggestion.
 */
void spell_suggest(int count)
{
  char_u      *line;
  pos_T prev_cursor = curwin->w_cursor;
  char_u wcopy[MAXWLEN + 2];
  char_u      *p;
  int i;
  int c;
  suginfo_T sug;
  suggest_T   *stp;
  int mouse_used;
  int need_cap;
  int limit;
  int selected = count;
  int badlen = 0;
  int msg_scroll_save = msg_scroll;

  if (no_spell_checking(curwin))
    return;

  if (VIsual_active) {
    /* Use the Visually selected text as the bad word.  But reject
     * a multi-line selection. */
    if (curwin->w_cursor.lnum != VIsual.lnum) {
      vim_beep();
      return;
    }
    badlen = (int)curwin->w_cursor.col - (int)VIsual.col;
    if (badlen < 0)
      badlen = -badlen;
    else
      curwin->w_cursor.col = VIsual.col;
    ++badlen;
    end_visual_mode();
  } else
  /* Find the start of the badly spelled word. */
  if (spell_move_to(curwin, FORWARD, TRUE, TRUE, NULL) == 0
      || curwin->w_cursor.col > prev_cursor.col) {
    /* No bad word or it starts after the cursor: use the word under the
     * cursor. */
    curwin->w_cursor = prev_cursor;
    line = ml_get_curline();
    p = line + curwin->w_cursor.col;
    /* Backup to before start of word. */
    while (p > line && spell_iswordp_nmw(p, curwin))
      mb_ptr_back(line, p);
    /* Forward to start of word. */
    while (*p != NUL && !spell_iswordp_nmw(p, curwin))
      mb_ptr_adv(p);

    if (!spell_iswordp_nmw(p, curwin)) {                /* No word found. */
      beep_flush();
      return;
    }
    curwin->w_cursor.col = (colnr_T)(p - line);
  }

  /* Get the word and its length. */

  /* Figure out if the word should be capitalised. */
  need_cap = check_need_cap(curwin->w_cursor.lnum, curwin->w_cursor.col);

  /* Make a copy of current line since autocommands may free the line. */
  line = vim_strsave(ml_get_curline());
  if (line == NULL)
    goto skip;

  /* Get the list of suggestions.  Limit to 'lines' - 2 or the number in
   * 'spellsuggest', whatever is smaller. */
  if (sps_limit > (int)Rows - 2)
    limit = (int)Rows - 2;
  else
    limit = sps_limit;
  spell_find_suggest(line + curwin->w_cursor.col, badlen, &sug, limit,
      TRUE, need_cap, TRUE);

  if (sug.su_ga.ga_len == 0)
    MSG(_("Sorry, no suggestions"));
  else if (count > 0) {
    if (count > sug.su_ga.ga_len)
      smsg((char_u *)_("Sorry, only %ld suggestions"),
          (long)sug.su_ga.ga_len);
  } else   {
    vim_free(repl_from);
    repl_from = NULL;
    vim_free(repl_to);
    repl_to = NULL;

    /* When 'rightleft' is set the list is drawn right-left. */
    cmdmsg_rl = curwin->w_p_rl;
    if (cmdmsg_rl)
      msg_col = Columns - 1;

    /* List the suggestions. */
    msg_start();
    msg_row = Rows - 1;         /* for when 'cmdheight' > 1 */
    lines_left = Rows;          /* avoid more prompt */
    vim_snprintf((char *)IObuff, IOSIZE, _("Change \"%.*s\" to:"),
        sug.su_badlen, sug.su_badptr);
    if (cmdmsg_rl && STRNCMP(IObuff, "Change", 6) == 0) {
      /* And now the rabbit from the high hat: Avoid showing the
       * untranslated message rightleft. */
      vim_snprintf((char *)IObuff, IOSIZE, ":ot \"%.*s\" egnahC",
          sug.su_badlen, sug.su_badptr);
    }
    msg_puts(IObuff);
    msg_clr_eos();
    msg_putchar('\n');

    msg_scroll = TRUE;
    for (i = 0; i < sug.su_ga.ga_len; ++i) {
      stp = &SUG(sug.su_ga, i);

      /* The suggested word may replace only part of the bad word, add
       * the not replaced part. */
      vim_strncpy(wcopy, stp->st_word, MAXWLEN);
      if (sug.su_badlen > stp->st_orglen)
        vim_strncpy(wcopy + stp->st_wordlen,
            sug.su_badptr + stp->st_orglen,
            sug.su_badlen - stp->st_orglen);
      vim_snprintf((char *)IObuff, IOSIZE, "%2d", i + 1);
      if (cmdmsg_rl)
        rl_mirror(IObuff);
      msg_puts(IObuff);

      vim_snprintf((char *)IObuff, IOSIZE, " \"%s\"", wcopy);
      msg_puts(IObuff);

      /* The word may replace more than "su_badlen". */
      if (sug.su_badlen < stp->st_orglen) {
        vim_snprintf((char *)IObuff, IOSIZE, _(" < \"%.*s\""),
            stp->st_orglen, sug.su_badptr);
        msg_puts(IObuff);
      }

      if (p_verbose > 0) {
        /* Add the score. */
        if (sps_flags & (SPS_DOUBLE | SPS_BEST))
          vim_snprintf((char *)IObuff, IOSIZE, " (%s%d - %d)",
              stp->st_salscore ? "s " : "",
              stp->st_score, stp->st_altscore);
        else
          vim_snprintf((char *)IObuff, IOSIZE, " (%d)",
              stp->st_score);
        if (cmdmsg_rl)
          /* Mirror the numbers, but keep the leading space. */
          rl_mirror(IObuff + 1);
        msg_advance(30);
        msg_puts(IObuff);
      }
      msg_putchar('\n');
    }

    cmdmsg_rl = FALSE;
    msg_col = 0;
    /* Ask for choice. */
    selected = prompt_for_number(&mouse_used);
    if (mouse_used)
      selected -= lines_left;
    lines_left = Rows;                  /* avoid more prompt */
    /* don't delay for 'smd' in normal_cmd() */
    msg_scroll = msg_scroll_save;
  }

  if (selected > 0 && selected <= sug.su_ga.ga_len && u_save_cursor() == OK) {
    /* Save the from and to text for :spellrepall. */
    stp = &SUG(sug.su_ga, selected - 1);
    if (sug.su_badlen > stp->st_orglen) {
      /* Replacing less than "su_badlen", append the remainder to
       * repl_to. */
      repl_from = vim_strnsave(sug.su_badptr, sug.su_badlen);
      vim_snprintf((char *)IObuff, IOSIZE, "%s%.*s", stp->st_word,
          sug.su_badlen - stp->st_orglen,
          sug.su_badptr + stp->st_orglen);
      repl_to = vim_strsave(IObuff);
    } else   {
      /* Replacing su_badlen or more, use the whole word. */
      repl_from = vim_strnsave(sug.su_badptr, stp->st_orglen);
      repl_to = vim_strsave(stp->st_word);
    }

    /* Replace the word. */
    p = alloc((unsigned)STRLEN(line) - stp->st_orglen
        + stp->st_wordlen + 1);
    if (p != NULL) {
      c = (int)(sug.su_badptr - line);
      mch_memmove(p, line, c);
      STRCPY(p + c, stp->st_word);
      STRCAT(p, sug.su_badptr + stp->st_orglen);
      ml_replace(curwin->w_cursor.lnum, p, FALSE);
      curwin->w_cursor.col = c;

      /* For redo we use a change-word command. */
      ResetRedobuff();
      AppendToRedobuff((char_u *)"ciw");
      AppendToRedobuffLit(p + c,
          stp->st_wordlen + sug.su_badlen - stp->st_orglen);
      AppendCharToRedobuff(ESC);

      /* After this "p" may be invalid. */
      changed_bytes(curwin->w_cursor.lnum, c);
    }
  } else
    curwin->w_cursor = prev_cursor;

  spell_find_cleanup(&sug);
skip:
  vim_free(line);
}

/*
 * Check if the word at line "lnum" column "col" is required to start with a
 * capital.  This uses 'spellcapcheck' of the current buffer.
 */
static int check_need_cap(linenr_T lnum, colnr_T col)
{
  int need_cap = FALSE;
  char_u      *line;
  char_u      *line_copy = NULL;
  char_u      *p;
  colnr_T endcol;
  regmatch_T regmatch;

  if (curwin->w_s->b_cap_prog == NULL)
    return FALSE;

  line = ml_get_curline();
  endcol = 0;
  if ((int)(skipwhite(line) - line) >= (int)col) {
    /* At start of line, check if previous line is empty or sentence
     * ends there. */
    if (lnum == 1)
      need_cap = TRUE;
    else {
      line = ml_get(lnum - 1);
      if (*skipwhite(line) == NUL)
        need_cap = TRUE;
      else {
        /* Append a space in place of the line break. */
        line_copy = concat_str(line, (char_u *)" ");
        line = line_copy;
        endcol = (colnr_T)STRLEN(line);
      }
    }
  } else
    endcol = col;

  if (endcol > 0) {
    /* Check if sentence ends before the bad word. */
    regmatch.regprog = curwin->w_s->b_cap_prog;
    regmatch.rm_ic = FALSE;
    p = line + endcol;
    for (;; ) {
      mb_ptr_back(line, p);
      if (p == line || spell_iswordp_nmw(p, curwin))
        break;
      if (vim_regexec(&regmatch, p, 0)
          && regmatch.endp[0] == line + endcol) {
        need_cap = TRUE;
        break;
      }
    }
  }

  vim_free(line_copy);

  return need_cap;
}


/*
 * ":spellrepall"
 */
void ex_spellrepall(exarg_T *eap)
{
  pos_T pos = curwin->w_cursor;
  char_u      *frompat;
  int addlen;
  char_u      *line;
  char_u      *p;
  int save_ws = p_ws;
  linenr_T prev_lnum = 0;

  if (repl_from == NULL || repl_to == NULL) {
    EMSG(_("E752: No previous spell replacement"));
    return;
  }
  addlen = (int)(STRLEN(repl_to) - STRLEN(repl_from));

  frompat = alloc((unsigned)STRLEN(repl_from) + 7);
  if (frompat == NULL)
    return;
  sprintf((char *)frompat, "\\V\\<%s\\>", repl_from);
  p_ws = FALSE;

  sub_nsubs = 0;
  sub_nlines = 0;
  curwin->w_cursor.lnum = 0;
  while (!got_int) {
    if (do_search(NULL, '/', frompat, 1L, SEARCH_KEEP, NULL) == 0
        || u_save_cursor() == FAIL)
      break;

    /* Only replace when the right word isn't there yet.  This happens
     * when changing "etc" to "etc.". */
    line = ml_get_curline();
    if (addlen <= 0 || STRNCMP(line + curwin->w_cursor.col,
            repl_to, STRLEN(repl_to)) != 0) {
      p = alloc((unsigned)STRLEN(line) + addlen + 1);
      if (p == NULL)
        break;
      mch_memmove(p, line, curwin->w_cursor.col);
      STRCPY(p + curwin->w_cursor.col, repl_to);
      STRCAT(p, line + curwin->w_cursor.col + STRLEN(repl_from));
      ml_replace(curwin->w_cursor.lnum, p, FALSE);
      changed_bytes(curwin->w_cursor.lnum, curwin->w_cursor.col);

      if (curwin->w_cursor.lnum != prev_lnum) {
        ++sub_nlines;
        prev_lnum = curwin->w_cursor.lnum;
      }
      ++sub_nsubs;
    }
    curwin->w_cursor.col += (colnr_T)STRLEN(repl_to);
  }

  p_ws = save_ws;
  curwin->w_cursor = pos;
  vim_free(frompat);

  if (sub_nsubs == 0)
    EMSG2(_("E753: Not found: %s"), repl_from);
  else
    do_sub_msg(FALSE);
}

/*
 * Find spell suggestions for "word".  Return them in the growarray "*gap" as
 * a list of allocated strings.
 */
void 
spell_suggest_list (
    garray_T *gap,
    char_u *word,
    int maxcount,                   /* maximum nr of suggestions */
    int need_cap,                   /* 'spellcapcheck' matched */
    int interactive
)
{
  suginfo_T sug;
  int i;
  suggest_T   *stp;
  char_u      *wcopy;

  spell_find_suggest(word, 0, &sug, maxcount, FALSE, need_cap, interactive);

  /* Make room in "gap". */
  ga_init2(gap, sizeof(char_u *), sug.su_ga.ga_len + 1);
  if (ga_grow(gap, sug.su_ga.ga_len) == OK) {
    for (i = 0; i < sug.su_ga.ga_len; ++i) {
      stp = &SUG(sug.su_ga, i);

      /* The suggested word may replace only part of "word", add the not
       * replaced part. */
      wcopy = alloc(stp->st_wordlen
          + (unsigned)STRLEN(sug.su_badptr + stp->st_orglen) + 1);
      if (wcopy == NULL)
        break;
      STRCPY(wcopy, stp->st_word);
      STRCPY(wcopy + stp->st_wordlen, sug.su_badptr + stp->st_orglen);
      ((char_u **)gap->ga_data)[gap->ga_len++] = wcopy;
    }
  }

  spell_find_cleanup(&sug);
}

/*
 * Find spell suggestions for the word at the start of "badptr".
 * Return the suggestions in "su->su_ga".
 * The maximum number of suggestions is "maxcount".
 * Note: does use info for the current window.
 * This is based on the mechanisms of Aspell, but completely reimplemented.
 */
static void 
spell_find_suggest (
    char_u *badptr,
    int badlen,                     /* length of bad word or 0 if unknown */
    suginfo_T *su,
    int maxcount,
    int banbadword,                 /* don't include badword in suggestions */
    int need_cap,                   /* word should start with capital */
    int interactive
)
{
  hlf_T attr = HLF_COUNT;
  char_u buf[MAXPATHL];
  char_u      *p;
  int do_combine = FALSE;
  char_u      *sps_copy;
  static int expr_busy = FALSE;
  int c;
  int i;
  langp_T     *lp;

  /*
   * Set the info in "*su".
   */
  vim_memset(su, 0, sizeof(suginfo_T));
  ga_init2(&su->su_ga, (int)sizeof(suggest_T), 10);
  ga_init2(&su->su_sga, (int)sizeof(suggest_T), 10);
  if (*badptr == NUL)
    return;
  hash_init(&su->su_banned);

  su->su_badptr = badptr;
  if (badlen != 0)
    su->su_badlen = badlen;
  else
    su->su_badlen = spell_check(curwin, su->su_badptr, &attr, NULL, FALSE);
  su->su_maxcount = maxcount;
  su->su_maxscore = SCORE_MAXINIT;

  if (su->su_badlen >= MAXWLEN)
    su->su_badlen = MAXWLEN - 1;        /* just in case */
  vim_strncpy(su->su_badword, su->su_badptr, su->su_badlen);
  (void)spell_casefold(su->su_badptr, su->su_badlen,
      su->su_fbadword, MAXWLEN);
  /* get caps flags for bad word */
  su->su_badflags = badword_captype(su->su_badptr,
      su->su_badptr + su->su_badlen);
  if (need_cap)
    su->su_badflags |= WF_ONECAP;

  /* Find the default language for sound folding.  We simply use the first
   * one in 'spelllang' that supports sound folding.  That's good for when
   * using multiple files for one language, it's not that bad when mixing
   * languages (e.g., "pl,en"). */
  for (i = 0; i < curbuf->b_s.b_langp.ga_len; ++i) {
    lp = LANGP_ENTRY(curbuf->b_s.b_langp, i);
    if (lp->lp_sallang != NULL) {
      su->su_sallang = lp->lp_sallang;
      break;
    }
  }

  /* Soundfold the bad word with the default sound folding, so that we don't
   * have to do this many times. */
  if (su->su_sallang != NULL)
    spell_soundfold(su->su_sallang, su->su_fbadword, TRUE,
        su->su_sal_badword);

  /* If the word is not capitalised and spell_check() doesn't consider the
   * word to be bad then it might need to be capitalised.  Add a suggestion
   * for that. */
  c = PTR2CHAR(su->su_badptr);
  if (!SPELL_ISUPPER(c) && attr == HLF_COUNT) {
    make_case_word(su->su_badword, buf, WF_ONECAP);
    add_suggestion(su, &su->su_ga, buf, su->su_badlen, SCORE_ICASE,
        0, TRUE, su->su_sallang, FALSE);
  }

  /* Ban the bad word itself.  It may appear in another region. */
  if (banbadword)
    add_banned(su, su->su_badword);

  /* Make a copy of 'spellsuggest', because the expression may change it. */
  sps_copy = vim_strsave(p_sps);
  if (sps_copy == NULL)
    return;

  /* Loop over the items in 'spellsuggest'. */
  for (p = sps_copy; *p != NUL; ) {
    copy_option_part(&p, buf, MAXPATHL, ",");

    if (STRNCMP(buf, "expr:", 5) == 0) {
      /* Evaluate an expression.  Skip this when called recursively,
       * when using spellsuggest() in the expression. */
      if (!expr_busy) {
        expr_busy = TRUE;
        spell_suggest_expr(su, buf + 5);
        expr_busy = FALSE;
      }
    } else if (STRNCMP(buf, "file:", 5) == 0)
      /* Use list of suggestions in a file. */
      spell_suggest_file(su, buf + 5);
    else {
      /* Use internal method. */
      spell_suggest_intern(su, interactive);
      if (sps_flags & SPS_DOUBLE)
        do_combine = TRUE;
    }
  }

  vim_free(sps_copy);

  if (do_combine)
    /* Combine the two list of suggestions.  This must be done last,
     * because sorting changes the order again. */
    score_combine(su);
}

/*
 * Find suggestions by evaluating expression "expr".
 */
static void spell_suggest_expr(suginfo_T *su, char_u *expr)
{
  list_T      *list;
  listitem_T  *li;
  int score;
  char_u      *p;

  /* The work is split up in a few parts to avoid having to export
   * suginfo_T.
   * First evaluate the expression and get the resulting list. */
  list = eval_spell_expr(su->su_badword, expr);
  if (list != NULL) {
    /* Loop over the items in the list. */
    for (li = list->lv_first; li != NULL; li = li->li_next)
      if (li->li_tv.v_type == VAR_LIST) {
        /* Get the word and the score from the items. */
        score = get_spellword(li->li_tv.vval.v_list, &p);
        if (score >= 0 && score <= su->su_maxscore)
          add_suggestion(su, &su->su_ga, p, su->su_badlen,
              score, 0, TRUE, su->su_sallang, FALSE);
      }
    list_unref(list);
  }

  /* Remove bogus suggestions, sort and truncate at "maxcount". */
  check_suggestions(su, &su->su_ga);
  (void)cleanup_suggestions(&su->su_ga, su->su_maxscore, su->su_maxcount);
}

/*
 * Find suggestions in file "fname".  Used for "file:" in 'spellsuggest'.
 */
static void spell_suggest_file(suginfo_T *su, char_u *fname)
{
  FILE        *fd;
  char_u line[MAXWLEN * 2];
  char_u      *p;
  int len;
  char_u cword[MAXWLEN];

  /* Open the file. */
  fd = mch_fopen((char *)fname, "r");
  if (fd == NULL) {
    EMSG2(_(e_notopen), fname);
    return;
  }

  /* Read it line by line. */
  while (!vim_fgets(line, MAXWLEN * 2, fd) && !got_int) {
    line_breakcheck();

    p = vim_strchr(line, '/');
    if (p == NULL)
      continue;             /* No Tab found, just skip the line. */
    *p++ = NUL;
    if (STRICMP(su->su_badword, line) == 0) {
      /* Match!  Isolate the good word, until CR or NL. */
      for (len = 0; p[len] >= ' '; ++len)
        ;
      p[len] = NUL;

      /* If the suggestion doesn't have specific case duplicate the case
       * of the bad word. */
      if (captype(p, NULL) == 0) {
        make_case_word(p, cword, su->su_badflags);
        p = cword;
      }

      add_suggestion(su, &su->su_ga, p, su->su_badlen,
          SCORE_FILE, 0, TRUE, su->su_sallang, FALSE);
    }
  }

  fclose(fd);

  /* Remove bogus suggestions, sort and truncate at "maxcount". */
  check_suggestions(su, &su->su_ga);
  (void)cleanup_suggestions(&su->su_ga, su->su_maxscore, su->su_maxcount);
}

/*
 * Find suggestions for the internal method indicated by "sps_flags".
 */
static void spell_suggest_intern(suginfo_T *su, int interactive)
{
  /*
   * Load the .sug file(s) that are available and not done yet.
   */
  suggest_load_files();

  /*
   * 1. Try special cases, such as repeating a word: "the the" -> "the".
   *
   * Set a maximum score to limit the combination of operations that is
   * tried.
   */
  suggest_try_special(su);

  /*
   * 2. Try inserting/deleting/swapping/changing a letter, use REP entries
   *    from the .aff file and inserting a space (split the word).
   */
  suggest_try_change(su);

  /* For the resulting top-scorers compute the sound-a-like score. */
  if (sps_flags & SPS_DOUBLE)
    score_comp_sal(su);

  /*
   * 3. Try finding sound-a-like words.
   */
  if ((sps_flags & SPS_FAST) == 0) {
    if (sps_flags & SPS_BEST)
      /* Adjust the word score for the suggestions found so far for how
       * they sounds like. */
      rescore_suggestions(su);

    /*
     * While going through the soundfold tree "su_maxscore" is the score
     * for the soundfold word, limits the changes that are being tried,
     * and "su_sfmaxscore" the rescored score, which is set by
     * cleanup_suggestions().
     * First find words with a small edit distance, because this is much
     * faster and often already finds the top-N suggestions.  If we didn't
     * find many suggestions try again with a higher edit distance.
     * "sl_sounddone" is used to avoid doing the same word twice.
     */
    suggest_try_soundalike_prep();
    su->su_maxscore = SCORE_SFMAX1;
    su->su_sfmaxscore = SCORE_MAXINIT * 3;
    suggest_try_soundalike(su);
    if (su->su_ga.ga_len < SUG_CLEAN_COUNT(su)) {
      /* We didn't find enough matches, try again, allowing more
       * changes to the soundfold word. */
      su->su_maxscore = SCORE_SFMAX2;
      suggest_try_soundalike(su);
      if (su->su_ga.ga_len < SUG_CLEAN_COUNT(su)) {
        /* Still didn't find enough matches, try again, allowing even
         * more changes to the soundfold word. */
        su->su_maxscore = SCORE_SFMAX3;
        suggest_try_soundalike(su);
      }
    }
    su->su_maxscore = su->su_sfmaxscore;
    suggest_try_soundalike_finish();
  }

  /* When CTRL-C was hit while searching do show the results.  Only clear
   * got_int when using a command, not for spellsuggest(). */
  ui_breakcheck();
  if (interactive && got_int) {
    (void)vgetc();
    got_int = FALSE;
  }

  if ((sps_flags & SPS_DOUBLE) == 0 && su->su_ga.ga_len != 0) {
    if (sps_flags & SPS_BEST)
      /* Adjust the word score for how it sounds like. */
      rescore_suggestions(su);

    /* Remove bogus suggestions, sort and truncate at "maxcount". */
    check_suggestions(su, &su->su_ga);
    (void)cleanup_suggestions(&su->su_ga, su->su_maxscore, su->su_maxcount);
  }
}

/*
 * Load the .sug files for languages that have one and weren't loaded yet.
 */
static void suggest_load_files(void)                 {
  langp_T     *lp;
  int lpi;
  slang_T     *slang;
  char_u      *dotp;
  FILE        *fd;
  char_u buf[MAXWLEN];
  int i;
  time_t timestamp;
  int wcount;
  int wordnr;
  garray_T ga;
  int c;

  /* Do this for all languages that support sound folding. */
  for (lpi = 0; lpi < curwin->w_s->b_langp.ga_len; ++lpi) {
    lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    slang = lp->lp_slang;
    if (slang->sl_sugtime != 0 && !slang->sl_sugloaded) {
      /* Change ".spl" to ".sug" and open the file.  When the file isn't
       * found silently skip it.  Do set "sl_sugloaded" so that we
       * don't try again and again. */
      slang->sl_sugloaded = TRUE;

      dotp = vim_strrchr(slang->sl_fname, '.');
      if (dotp == NULL || fnamecmp(dotp, ".spl") != 0)
        continue;
      STRCPY(dotp, ".sug");
      fd = mch_fopen((char *)slang->sl_fname, "r");
      if (fd == NULL)
        goto nextone;

      /*
       * <SUGHEADER>: <fileID> <versionnr> <timestamp>
       */
      for (i = 0; i < VIMSUGMAGICL; ++i)
        buf[i] = getc(fd);                              /* <fileID> */
      if (STRNCMP(buf, VIMSUGMAGIC, VIMSUGMAGICL) != 0) {
        EMSG2(_("E778: This does not look like a .sug file: %s"),
            slang->sl_fname);
        goto nextone;
      }
      c = getc(fd);                                     /* <versionnr> */
      if (c < VIMSUGVERSION) {
        EMSG2(_("E779: Old .sug file, needs to be updated: %s"),
            slang->sl_fname);
        goto nextone;
      } else if (c > VIMSUGVERSION)   {
        EMSG2(_("E780: .sug file is for newer version of Vim: %s"),
            slang->sl_fname);
        goto nextone;
      }

      /* Check the timestamp, it must be exactly the same as the one in
       * the .spl file.  Otherwise the word numbers won't match. */
      timestamp = get8ctime(fd);                        /* <timestamp> */
      if (timestamp != slang->sl_sugtime) {
        EMSG2(_("E781: .sug file doesn't match .spl file: %s"),
            slang->sl_fname);
        goto nextone;
      }

      /*
       * <SUGWORDTREE>: <wordtree>
       * Read the trie with the soundfolded words.
       */
      if (spell_read_tree(fd, &slang->sl_sbyts, &slang->sl_sidxs,
              FALSE, 0) != 0) {
someerror:
        EMSG2(_("E782: error while reading .sug file: %s"),
            slang->sl_fname);
        slang_clear_sug(slang);
        goto nextone;
      }

      /*
       * <SUGTABLE>: <sugwcount> <sugline> ...
       *
       * Read the table with word numbers.  We use a file buffer for
       * this, because it's so much like a file with lines.  Makes it
       * possible to swap the info and save on memory use.
       */
      slang->sl_sugbuf = open_spellbuf();
      if (slang->sl_sugbuf == NULL)
        goto someerror;
      /* <sugwcount> */
      wcount = get4c(fd);
      if (wcount < 0)
        goto someerror;

      /* Read all the wordnr lists into the buffer, one NUL terminated
       * list per line. */
      ga_init2(&ga, 1, 100);
      for (wordnr = 0; wordnr < wcount; ++wordnr) {
        ga.ga_len = 0;
        for (;; ) {
          c = getc(fd);                                     /* <sugline> */
          if (c < 0 || ga_grow(&ga, 1) == FAIL)
            goto someerror;
          ((char_u *)ga.ga_data)[ga.ga_len++] = c;
          if (c == NUL)
            break;
        }
        if (ml_append_buf(slang->sl_sugbuf, (linenr_T)wordnr,
                ga.ga_data, ga.ga_len, TRUE) == FAIL)
          goto someerror;
      }
      ga_clear(&ga);

      /*
       * Need to put word counts in the word tries, so that we can find
       * a word by its number.
       */
      tree_count_words(slang->sl_fbyts, slang->sl_fidxs);
      tree_count_words(slang->sl_sbyts, slang->sl_sidxs);

nextone:
      if (fd != NULL)
        fclose(fd);
      STRCPY(dotp, ".spl");
    }
  }
}

/*
 * Fill in the wordcount fields for a trie.
 * Returns the total number of words.
 */
static void tree_count_words(char_u *byts, idx_T *idxs)
{
  int depth;
  idx_T arridx[MAXWLEN];
  int curi[MAXWLEN];
  int c;
  idx_T n;
  int wordcount[MAXWLEN];

  arridx[0] = 0;
  curi[0] = 1;
  wordcount[0] = 0;
  depth = 0;
  while (depth >= 0 && !got_int) {
    if (curi[depth] > byts[arridx[depth]]) {
      /* Done all bytes at this node, go up one level. */
      idxs[arridx[depth]] = wordcount[depth];
      if (depth > 0)
        wordcount[depth - 1] += wordcount[depth];

      --depth;
      fast_breakcheck();
    } else   {
      /* Do one more byte at this node. */
      n = arridx[depth] + curi[depth];
      ++curi[depth];

      c = byts[n];
      if (c == 0) {
        /* End of word, count it. */
        ++wordcount[depth];

        /* Skip over any other NUL bytes (same word with different
         * flags). */
        while (byts[n + 1] == 0) {
          ++n;
          ++curi[depth];
        }
      } else   {
        /* Normal char, go one level deeper to count the words. */
        ++depth;
        arridx[depth] = idxs[n];
        curi[depth] = 1;
        wordcount[depth] = 0;
      }
    }
  }
}

/*
 * Free the info put in "*su" by spell_find_suggest().
 */
static void spell_find_cleanup(suginfo_T *su)
{
  int i;

  /* Free the suggestions. */
  for (i = 0; i < su->su_ga.ga_len; ++i)
    vim_free(SUG(su->su_ga, i).st_word);
  ga_clear(&su->su_ga);
  for (i = 0; i < su->su_sga.ga_len; ++i)
    vim_free(SUG(su->su_sga, i).st_word);
  ga_clear(&su->su_sga);

  /* Free the banned words. */
  hash_clear_all(&su->su_banned, 0);
}

/*
 * Make a copy of "word", with the first letter upper or lower cased, to
 * "wcopy[MAXWLEN]".  "word" must not be empty.
 * The result is NUL terminated.
 */
static void 
onecap_copy (
    char_u *word,
    char_u *wcopy,
    int upper                  /* TRUE: first letter made upper case */
)
{
  char_u      *p;
  int c;
  int l;

  p = word;
  if (has_mbyte)
    c = mb_cptr2char_adv(&p);
  else
    c = *p++;
  if (upper)
    c = SPELL_TOUPPER(c);
  else
    c = SPELL_TOFOLD(c);
  if (has_mbyte)
    l = mb_char2bytes(c, wcopy);
  else {
    l = 1;
    wcopy[0] = c;
  }
  vim_strncpy(wcopy + l, p, MAXWLEN - l - 1);
}

/*
 * Make a copy of "word" with all the letters upper cased into
 * "wcopy[MAXWLEN]".  The result is NUL terminated.
 */
static void allcap_copy(char_u *word, char_u *wcopy)
{
  char_u      *s;
  char_u      *d;
  int c;

  d = wcopy;
  for (s = word; *s != NUL; ) {
    if (has_mbyte)
      c = mb_cptr2char_adv(&s);
    else
      c = *s++;

    /* We only change 0xdf to SS when we are certain latin1 is used.  It
     * would cause weird errors in other 8-bit encodings. */
    if (enc_latin1like && c == 0xdf) {
      c = 'S';
      if (d - wcopy >= MAXWLEN - 1)
        break;
      *d++ = c;
    } else
      c = SPELL_TOUPPER(c);

    if (has_mbyte) {
      if (d - wcopy >= MAXWLEN - MB_MAXBYTES)
        break;
      d += mb_char2bytes(c, d);
    } else   {
      if (d - wcopy >= MAXWLEN - 1)
        break;
      *d++ = c;
    }
  }
  *d = NUL;
}

/*
 * Try finding suggestions by recognizing specific situations.
 */
static void suggest_try_special(suginfo_T *su)
{
  char_u      *p;
  size_t len;
  int c;
  char_u word[MAXWLEN];

  /*
   * Recognize a word that is repeated: "the the".
   */
  p = skiptowhite(su->su_fbadword);
  len = p - su->su_fbadword;
  p = skipwhite(p);
  if (STRLEN(p) == len && STRNCMP(su->su_fbadword, p, len) == 0) {
    /* Include badflags: if the badword is onecap or allcap
    * use that for the goodword too: "The the" -> "The". */
    c = su->su_fbadword[len];
    su->su_fbadword[len] = NUL;
    make_case_word(su->su_fbadword, word, su->su_badflags);
    su->su_fbadword[len] = c;

    /* Give a soundalike score of 0, compute the score as if deleting one
     * character. */
    add_suggestion(su, &su->su_ga, word, su->su_badlen,
        RESCORE(SCORE_REP, 0), 0, TRUE, su->su_sallang, FALSE);
  }
}

/*
 * Try finding suggestions by adding/removing/swapping letters.
 */
static void suggest_try_change(suginfo_T *su)
{
  char_u fword[MAXWLEN];            /* copy of the bad word, case-folded */
  int n;
  char_u      *p;
  int lpi;
  langp_T     *lp;

  /* We make a copy of the case-folded bad word, so that we can modify it
   * to find matches (esp. REP items).  Append some more text, changing
   * chars after the bad word may help. */
  STRCPY(fword, su->su_fbadword);
  n = (int)STRLEN(fword);
  p = su->su_badptr + su->su_badlen;
  (void)spell_casefold(p, (int)STRLEN(p), fword + n, MAXWLEN - n);

  for (lpi = 0; lpi < curwin->w_s->b_langp.ga_len; ++lpi) {
    lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);

    /* If reloading a spell file fails it's still in the list but
     * everything has been cleared. */
    if (lp->lp_slang->sl_fbyts == NULL)
      continue;

    /* Try it for this language.  Will add possible suggestions. */
    suggest_trie_walk(su, lp, fword, FALSE);
  }
}

/* Check the maximum score, if we go over it we won't try this change. */
#define TRY_DEEPER(su, stack, depth, add) \
  (stack[depth].ts_score + (add) < su->su_maxscore)

/*
 * Try finding suggestions by adding/removing/swapping letters.
 *
 * This uses a state machine.  At each node in the tree we try various
 * operations.  When trying if an operation works "depth" is increased and the
 * stack[] is used to store info.  This allows combinations, thus insert one
 * character, replace one and delete another.  The number of changes is
 * limited by su->su_maxscore.
 *
 * After implementing this I noticed an article by Kemal Oflazer that
 * describes something similar: "Error-tolerant Finite State Recognition with
 * Applications to Morphological Analysis and Spelling Correction" (1996).
 * The implementation in the article is simplified and requires a stack of
 * unknown depth.  The implementation here only needs a stack depth equal to
 * the length of the word.
 *
 * This is also used for the sound-folded word, "soundfold" is TRUE then.
 * The mechanism is the same, but we find a match with a sound-folded word
 * that comes from one or more original words.  Each of these words may be
 * added, this is done by add_sound_suggest().
 * Don't use:
 *	the prefix tree or the keep-case tree
 *	"su->su_badlen"
 *	anything to do with upper and lower case
 *	anything to do with word or non-word characters ("spell_iswordp()")
 *	banned words
 *	word flags (rare, region, compounding)
 *	word splitting for now
 *	"similar_chars()"
 *	use "slang->sl_repsal" instead of "lp->lp_replang->sl_rep"
 */
static void suggest_trie_walk(suginfo_T *su, langp_T *lp, char_u *fword, int soundfold)
{
  char_u tword[MAXWLEN];            /* good word collected so far */
  trystate_T stack[MAXWLEN];
  char_u preword[MAXWLEN * 3];        /* word found with proper case;
                                       * concatenation of prefix compound
                                       * words and split word.  NUL terminated
                                       * when going deeper but not when coming
                                       * back. */
  char_u compflags[MAXWLEN];            /* compound flags, one for each word */
  trystate_T  *sp;
  int newscore;
  int score;
  char_u      *byts, *fbyts, *pbyts;
  idx_T       *idxs, *fidxs, *pidxs;
  int depth;
  int c, c2, c3;
  int n = 0;
  int flags;
  garray_T    *gap;
  idx_T arridx;
  int len;
  char_u      *p;
  fromto_T    *ftp;
  int fl = 0, tl;
  int repextra = 0;                 /* extra bytes in fword[] from REP item */
  slang_T     *slang = lp->lp_slang;
  int fword_ends;
  int goodword_ends;
#ifdef DEBUG_TRIEWALK
  /* Stores the name of the change made at each level. */
  char_u changename[MAXWLEN][80];
#endif
  int breakcheckcount = 1000;
  int compound_ok;

  /*
   * Go through the whole case-fold tree, try changes at each node.
   * "tword[]" contains the word collected from nodes in the tree.
   * "fword[]" the word we are trying to match with (initially the bad
   * word).
   */
  depth = 0;
  sp = &stack[0];
  vim_memset(sp, 0, sizeof(trystate_T));
  sp->ts_curi = 1;

  if (soundfold) {
    /* Going through the soundfold tree. */
    byts = fbyts = slang->sl_sbyts;
    idxs = fidxs = slang->sl_sidxs;
    pbyts = NULL;
    pidxs = NULL;
    sp->ts_prefixdepth = PFD_NOPREFIX;
    sp->ts_state = STATE_START;
  } else   {
    /*
     * When there are postponed prefixes we need to use these first.  At
     * the end of the prefix we continue in the case-fold tree.
     */
    fbyts = slang->sl_fbyts;
    fidxs = slang->sl_fidxs;
    pbyts = slang->sl_pbyts;
    pidxs = slang->sl_pidxs;
    if (pbyts != NULL) {
      byts = pbyts;
      idxs = pidxs;
      sp->ts_prefixdepth = PFD_PREFIXTREE;
      sp->ts_state = STATE_NOPREFIX;            /* try without prefix first */
    } else   {
      byts = fbyts;
      idxs = fidxs;
      sp->ts_prefixdepth = PFD_NOPREFIX;
      sp->ts_state = STATE_START;
    }
  }

  /*
   * Loop to find all suggestions.  At each round we either:
   * - For the current state try one operation, advance "ts_curi",
   *   increase "depth".
   * - When a state is done go to the next, set "ts_state".
   * - When all states are tried decrease "depth".
   */
  while (depth >= 0 && !got_int) {
    sp = &stack[depth];
    switch (sp->ts_state) {
    case STATE_START:
    case STATE_NOPREFIX:
      /*
       * Start of node: Deal with NUL bytes, which means
       * tword[] may end here.
       */
      arridx = sp->ts_arridx;               /* current node in the tree */
      len = byts[arridx];                   /* bytes in this node */
      arridx += sp->ts_curi;                /* index of current byte */

      if (sp->ts_prefixdepth == PFD_PREFIXTREE) {
        /* Skip over the NUL bytes, we use them later. */
        for (n = 0; n < len && byts[arridx + n] == 0; ++n)
          ;
        sp->ts_curi += n;

        /* Always past NUL bytes now. */
        n = (int)sp->ts_state;
        sp->ts_state = STATE_ENDNUL;
        sp->ts_save_badflags = su->su_badflags;

        /* At end of a prefix or at start of prefixtree: check for
         * following word. */
        if (byts[arridx] == 0 || n == (int)STATE_NOPREFIX) {
          /* Set su->su_badflags to the caps type at this position.
           * Use the caps type until here for the prefix itself. */
          if (has_mbyte)
            n = nofold_len(fword, sp->ts_fidx, su->su_badptr);
          else
            n = sp->ts_fidx;
          flags = badword_captype(su->su_badptr, su->su_badptr + n);
          su->su_badflags = badword_captype(su->su_badptr + n,
              su->su_badptr + su->su_badlen);
#ifdef DEBUG_TRIEWALK
          sprintf(changename[depth], "prefix");
#endif
          go_deeper(stack, depth, 0);
          ++depth;
          sp = &stack[depth];
          sp->ts_prefixdepth = depth - 1;
          byts = fbyts;
          idxs = fidxs;
          sp->ts_arridx = 0;

          /* Move the prefix to preword[] with the right case
           * and make find_keepcap_word() works. */
          tword[sp->ts_twordlen] = NUL;
          make_case_word(tword + sp->ts_splitoff,
              preword + sp->ts_prewordlen, flags);
          sp->ts_prewordlen = (char_u)STRLEN(preword);
          sp->ts_splitoff = sp->ts_twordlen;
        }
        break;
      }

      if (sp->ts_curi > len || byts[arridx] != 0) {
        /* Past bytes in node and/or past NUL bytes. */
        sp->ts_state = STATE_ENDNUL;
        sp->ts_save_badflags = su->su_badflags;
        break;
      }

      /*
       * End of word in tree.
       */
      ++sp->ts_curi;                    /* eat one NUL byte */

      flags = (int)idxs[arridx];

      /* Skip words with the NOSUGGEST flag. */
      if (flags & WF_NOSUGGEST)
        break;

      fword_ends = (fword[sp->ts_fidx] == NUL
                    || (soundfold
                        ? vim_iswhite(fword[sp->ts_fidx])
                        : !spell_iswordp(fword + sp->ts_fidx, curwin)));
      tword[sp->ts_twordlen] = NUL;

      if (sp->ts_prefixdepth <= PFD_NOTSPECIAL
          && (sp->ts_flags & TSF_PREFIXOK) == 0) {
        /* There was a prefix before the word.  Check that the prefix
         * can be used with this word. */
        /* Count the length of the NULs in the prefix.  If there are
         * none this must be the first try without a prefix.  */
        n = stack[sp->ts_prefixdepth].ts_arridx;
        len = pbyts[n++];
        for (c = 0; c < len && pbyts[n + c] == 0; ++c)
          ;
        if (c > 0) {
          c = valid_word_prefix(c, n, flags,
              tword + sp->ts_splitoff, slang, FALSE);
          if (c == 0)
            break;

          /* Use the WF_RARE flag for a rare prefix. */
          if (c & WF_RAREPFX)
            flags |= WF_RARE;

          /* Tricky: when checking for both prefix and compounding
           * we run into the prefix flag first.
           * Remember that it's OK, so that we accept the prefix
           * when arriving at a compound flag. */
          sp->ts_flags |= TSF_PREFIXOK;
        }
      }

      /* Check NEEDCOMPOUND: can't use word without compounding.  Do try
       * appending another compound word below. */
      if (sp->ts_complen == sp->ts_compsplit && fword_ends
          && (flags & WF_NEEDCOMP))
        goodword_ends = FALSE;
      else
        goodword_ends = TRUE;

      p = NULL;
      compound_ok = TRUE;
      if (sp->ts_complen > sp->ts_compsplit) {
        if (slang->sl_nobreak) {
          /* There was a word before this word.  When there was no
           * change in this word (it was correct) add the first word
           * as a suggestion.  If this word was corrected too, we
           * need to check if a correct word follows. */
          if (sp->ts_fidx - sp->ts_splitfidx
              == sp->ts_twordlen - sp->ts_splitoff
              && STRNCMP(fword + sp->ts_splitfidx,
                  tword + sp->ts_splitoff,
                  sp->ts_fidx - sp->ts_splitfidx) == 0) {
            preword[sp->ts_prewordlen] = NUL;
            newscore = score_wordcount_adj(slang, sp->ts_score,
                preword + sp->ts_prewordlen,
                sp->ts_prewordlen > 0);
            /* Add the suggestion if the score isn't too bad. */
            if (newscore <= su->su_maxscore)
              add_suggestion(su, &su->su_ga, preword,
                  sp->ts_splitfidx - repextra,
                  newscore, 0, FALSE,
                  lp->lp_sallang, FALSE);
            break;
          }
        } else   {
          /* There was a compound word before this word.  If this
           * word does not support compounding then give up
           * (splitting is tried for the word without compound
           * flag). */
          if (((unsigned)flags >> 24) == 0
              || sp->ts_twordlen - sp->ts_splitoff
              < slang->sl_compminlen)
            break;
          /* For multi-byte chars check character length against
           * COMPOUNDMIN. */
          if (has_mbyte
              && slang->sl_compminlen > 0
              && mb_charlen(tword + sp->ts_splitoff)
              < slang->sl_compminlen)
            break;

          compflags[sp->ts_complen] = ((unsigned)flags >> 24);
          compflags[sp->ts_complen + 1] = NUL;
          vim_strncpy(preword + sp->ts_prewordlen,
              tword + sp->ts_splitoff,
              sp->ts_twordlen - sp->ts_splitoff);

          /* Verify CHECKCOMPOUNDPATTERN  rules. */
          if (match_checkcompoundpattern(preword,  sp->ts_prewordlen,
                  &slang->sl_comppat))
            compound_ok = FALSE;

          if (compound_ok) {
            p = preword;
            while (*skiptowhite(p) != NUL)
              p = skipwhite(skiptowhite(p));
            if (fword_ends && !can_compound(slang, p,
                    compflags + sp->ts_compsplit))
              /* Compound is not allowed.  But it may still be
               * possible if we add another (short) word. */
              compound_ok = FALSE;
          }

          /* Get pointer to last char of previous word. */
          p = preword + sp->ts_prewordlen;
          mb_ptr_back(preword, p);
        }
      }

      /*
       * Form the word with proper case in preword.
       * If there is a word from a previous split, append.
       * For the soundfold tree don't change the case, simply append.
       */
      if (soundfold)
        STRCPY(preword + sp->ts_prewordlen, tword + sp->ts_splitoff);
      else if (flags & WF_KEEPCAP)
        /* Must find the word in the keep-case tree. */
        find_keepcap_word(slang, tword + sp->ts_splitoff,
            preword + sp->ts_prewordlen);
      else {
        /* Include badflags: If the badword is onecap or allcap
         * use that for the goodword too.  But if the badword is
         * allcap and it's only one char long use onecap. */
        c = su->su_badflags;
        if ((c & WF_ALLCAP)
            && su->su_badlen == (*mb_ptr2len)(su->su_badptr)
            )
          c = WF_ONECAP;
        c |= flags;

        /* When appending a compound word after a word character don't
         * use Onecap. */
        if (p != NULL && spell_iswordp_nmw(p, curwin))
          c &= ~WF_ONECAP;
        make_case_word(tword + sp->ts_splitoff,
            preword + sp->ts_prewordlen, c);
      }

      if (!soundfold) {
        /* Don't use a banned word.  It may appear again as a good
         * word, thus remember it. */
        if (flags & WF_BANNED) {
          add_banned(su, preword + sp->ts_prewordlen);
          break;
        }
        if ((sp->ts_complen == sp->ts_compsplit
             && WAS_BANNED(su, preword + sp->ts_prewordlen))
            || WAS_BANNED(su, preword)) {
          if (slang->sl_compprog == NULL)
            break;
          /* the word so far was banned but we may try compounding */
          goodword_ends = FALSE;
        }
      }

      newscore = 0;
      if (!soundfold) {         /* soundfold words don't have flags */
        if ((flags & WF_REGION)
            && (((unsigned)flags >> 16) & lp->lp_region) == 0)
          newscore += SCORE_REGION;
        if (flags & WF_RARE)
          newscore += SCORE_RARE;

        if (!spell_valid_case(su->su_badflags,
                captype(preword + sp->ts_prewordlen, NULL)))
          newscore += SCORE_ICASE;
      }

      /* TODO: how about splitting in the soundfold tree? */
      if (fword_ends
          && goodword_ends
          && sp->ts_fidx >= sp->ts_fidxtry
          && compound_ok) {
        /* The badword also ends: add suggestions. */
#ifdef DEBUG_TRIEWALK
        if (soundfold && STRCMP(preword, "smwrd") == 0) {
          int j;

          /* print the stack of changes that brought us here */
          smsg("------ %s -------", fword);
          for (j = 0; j < depth; ++j)
            smsg("%s", changename[j]);
        }
#endif
        if (soundfold) {
          /* For soundfolded words we need to find the original
           * words, the edit distance and then add them. */
          add_sound_suggest(su, preword, sp->ts_score, lp);
        } else if (sp->ts_fidx > 0)   {
          /* Give a penalty when changing non-word char to word
           * char, e.g., "thes," -> "these". */
          p = fword + sp->ts_fidx;
          mb_ptr_back(fword, p);
          if (!spell_iswordp(p, curwin)) {
            p = preword + STRLEN(preword);
            mb_ptr_back(preword, p);
            if (spell_iswordp(p, curwin))
              newscore += SCORE_NONWORD;
          }

          /* Give a bonus to words seen before. */
          score = score_wordcount_adj(slang,
              sp->ts_score + newscore,
              preword + sp->ts_prewordlen,
              sp->ts_prewordlen > 0);

          /* Add the suggestion if the score isn't too bad. */
          if (score <= su->su_maxscore) {
            add_suggestion(su, &su->su_ga, preword,
                sp->ts_fidx - repextra,
                score, 0, FALSE, lp->lp_sallang, FALSE);

            if (su->su_badflags & WF_MIXCAP) {
              /* We really don't know if the word should be
               * upper or lower case, add both. */
              c = captype(preword, NULL);
              if (c == 0 || c == WF_ALLCAP) {
                make_case_word(tword + sp->ts_splitoff,
                    preword + sp->ts_prewordlen,
                    c == 0 ? WF_ALLCAP : 0);

                add_suggestion(su, &su->su_ga, preword,
                    sp->ts_fidx - repextra,
                    score + SCORE_ICASE, 0, FALSE,
                    lp->lp_sallang, FALSE);
              }
            }
          }
        }
      }

      /*
       * Try word split and/or compounding.
       */
      if ((sp->ts_fidx >= sp->ts_fidxtry || fword_ends)
          /* Don't split halfway a character. */
          && (!has_mbyte || sp->ts_tcharlen == 0)
          ) {
        int try_compound;
        int try_split;

        /* If past the end of the bad word don't try a split.
         * Otherwise try changing the next word.  E.g., find
         * suggestions for "the the" where the second "the" is
         * different.  It's done like a split.
         * TODO: word split for soundfold words */
        try_split = (sp->ts_fidx - repextra < su->su_badlen)
                    && !soundfold;

        /* Get here in several situations:
         * 1. The word in the tree ends:
         *    If the word allows compounding try that.  Otherwise try
         *    a split by inserting a space.  For both check that a
         *    valid words starts at fword[sp->ts_fidx].
         *    For NOBREAK do like compounding to be able to check if
         *    the next word is valid.
         * 2. The badword does end, but it was due to a change (e.g.,
         *    a swap).  No need to split, but do check that the
         *    following word is valid.
         * 3. The badword and the word in the tree end.  It may still
         *    be possible to compound another (short) word.
         */
        try_compound = FALSE;
        if (!soundfold
            && slang->sl_compprog != NULL
            && ((unsigned)flags >> 24) != 0
            && sp->ts_twordlen - sp->ts_splitoff
            >= slang->sl_compminlen
            && (!has_mbyte
                || slang->sl_compminlen == 0
                || mb_charlen(tword + sp->ts_splitoff)
                >= slang->sl_compminlen)
            && (slang->sl_compsylmax < MAXWLEN
                || sp->ts_complen + 1 - sp->ts_compsplit
                < slang->sl_compmax)
            && (can_be_compound(sp, slang,
                    compflags, ((unsigned)flags >> 24)))) {
          try_compound = TRUE;
          compflags[sp->ts_complen] = ((unsigned)flags >> 24);
          compflags[sp->ts_complen + 1] = NUL;
        }

        /* For NOBREAK we never try splitting, it won't make any word
         * valid. */
        if (slang->sl_nobreak)
          try_compound = TRUE;

        /* If we could add a compound word, and it's also possible to
         * split at this point, do the split first and set
         * TSF_DIDSPLIT to avoid doing it again. */
        else if (!fword_ends
                 && try_compound
                 && (sp->ts_flags & TSF_DIDSPLIT) == 0) {
          try_compound = FALSE;
          sp->ts_flags |= TSF_DIDSPLIT;
          --sp->ts_curi;                    /* do the same NUL again */
          compflags[sp->ts_complen] = NUL;
        } else
          sp->ts_flags &= ~TSF_DIDSPLIT;

        if (try_split || try_compound) {
          if (!try_compound && (!fword_ends || !goodword_ends)) {
            /* If we're going to split need to check that the
             * words so far are valid for compounding.  If there
             * is only one word it must not have the NEEDCOMPOUND
             * flag. */
            if (sp->ts_complen == sp->ts_compsplit
                && (flags & WF_NEEDCOMP))
              break;
            p = preword;
            while (*skiptowhite(p) != NUL)
              p = skipwhite(skiptowhite(p));
            if (sp->ts_complen > sp->ts_compsplit
                && !can_compound(slang, p,
                    compflags + sp->ts_compsplit))
              break;

            if (slang->sl_nosplitsugs)
              newscore += SCORE_SPLIT_NO;
            else
              newscore += SCORE_SPLIT;

            /* Give a bonus to words seen before. */
            newscore = score_wordcount_adj(slang, newscore,
                preword + sp->ts_prewordlen, TRUE);
          }

          if (TRY_DEEPER(su, stack, depth, newscore)) {
            go_deeper(stack, depth, newscore);
#ifdef DEBUG_TRIEWALK
            if (!try_compound && !fword_ends)
              sprintf(changename[depth], "%.*s-%s: split",
                  sp->ts_twordlen, tword, fword + sp->ts_fidx);
            else
              sprintf(changename[depth], "%.*s-%s: compound",
                  sp->ts_twordlen, tword, fword + sp->ts_fidx);
#endif
            /* Save things to be restored at STATE_SPLITUNDO. */
            sp->ts_save_badflags = su->su_badflags;
            sp->ts_state = STATE_SPLITUNDO;

            ++depth;
            sp = &stack[depth];

            /* Append a space to preword when splitting. */
            if (!try_compound && !fword_ends)
              STRCAT(preword, " ");
            sp->ts_prewordlen = (char_u)STRLEN(preword);
            sp->ts_splitoff = sp->ts_twordlen;
            sp->ts_splitfidx = sp->ts_fidx;

            /* If the badword has a non-word character at this
             * position skip it.  That means replacing the
             * non-word character with a space.  Always skip a
             * character when the word ends.  But only when the
             * good word can end. */
            if (((!try_compound && !spell_iswordp_nmw(fword
                      + sp->ts_fidx,
                      curwin))
                 || fword_ends)
                && fword[sp->ts_fidx] != NUL
                && goodword_ends) {
              int l;

              if (has_mbyte)
                l = MB_BYTE2LEN(fword[sp->ts_fidx]);
              else
                l = 1;
              if (fword_ends) {
                /* Copy the skipped character to preword. */
                mch_memmove(preword + sp->ts_prewordlen,
                    fword + sp->ts_fidx, l);
                sp->ts_prewordlen += l;
                preword[sp->ts_prewordlen] = NUL;
              } else
                sp->ts_score -= SCORE_SPLIT - SCORE_SUBST;
              sp->ts_fidx += l;
            }

            /* When compounding include compound flag in
             * compflags[] (already set above).  When splitting we
             * may start compounding over again.  */
            if (try_compound)
              ++sp->ts_complen;
            else
              sp->ts_compsplit = sp->ts_complen;
            sp->ts_prefixdepth = PFD_NOPREFIX;

            /* set su->su_badflags to the caps type at this
             * position */
            if (has_mbyte)
              n = nofold_len(fword, sp->ts_fidx, su->su_badptr);
            else
              n = sp->ts_fidx;
            su->su_badflags = badword_captype(su->su_badptr + n,
                su->su_badptr + su->su_badlen);

            /* Restart at top of the tree. */
            sp->ts_arridx = 0;

            /* If there are postponed prefixes, try these too. */
            if (pbyts != NULL) {
              byts = pbyts;
              idxs = pidxs;
              sp->ts_prefixdepth = PFD_PREFIXTREE;
              sp->ts_state = STATE_NOPREFIX;
            }
          }
        }
      }
      break;

    case STATE_SPLITUNDO:
      /* Undo the changes done for word split or compound word. */
      su->su_badflags = sp->ts_save_badflags;

      /* Continue looking for NUL bytes. */
      sp->ts_state = STATE_START;

      /* In case we went into the prefix tree. */
      byts = fbyts;
      idxs = fidxs;
      break;

    case STATE_ENDNUL:
      /* Past the NUL bytes in the node. */
      su->su_badflags = sp->ts_save_badflags;
      if (fword[sp->ts_fidx] == NUL
          && sp->ts_tcharlen == 0
          ) {
        /* The badword ends, can't use STATE_PLAIN. */
        sp->ts_state = STATE_DEL;
        break;
      }
      sp->ts_state = STATE_PLAIN;
    /*FALLTHROUGH*/

    case STATE_PLAIN:
      /*
       * Go over all possible bytes at this node, add each to tword[]
       * and use child node.  "ts_curi" is the index.
       */
      arridx = sp->ts_arridx;
      if (sp->ts_curi > byts[arridx]) {
        /* Done all bytes at this node, do next state.  When still at
         * already changed bytes skip the other tricks. */
        if (sp->ts_fidx >= sp->ts_fidxtry)
          sp->ts_state = STATE_DEL;
        else
          sp->ts_state = STATE_FINAL;
      } else   {
        arridx += sp->ts_curi++;
        c = byts[arridx];

        /* Normal byte, go one level deeper.  If it's not equal to the
         * byte in the bad word adjust the score.  But don't even try
         * when the byte was already changed.  And don't try when we
         * just deleted this byte, accepting it is always cheaper then
         * delete + substitute. */
        if (c == fword[sp->ts_fidx]
            || (sp->ts_tcharlen > 0 && sp->ts_isdiff != DIFF_NONE)
            )
          newscore = 0;
        else
          newscore = SCORE_SUBST;
        if ((newscore == 0
             || (sp->ts_fidx >= sp->ts_fidxtry
                 && ((sp->ts_flags & TSF_DIDDEL) == 0
                     || c != fword[sp->ts_delidx])))
            && TRY_DEEPER(su, stack, depth, newscore)) {
          go_deeper(stack, depth, newscore);
#ifdef DEBUG_TRIEWALK
          if (newscore > 0)
            sprintf(changename[depth], "%.*s-%s: subst %c to %c",
                sp->ts_twordlen, tword, fword + sp->ts_fidx,
                fword[sp->ts_fidx], c);
          else
            sprintf(changename[depth], "%.*s-%s: accept %c",
                sp->ts_twordlen, tword, fword + sp->ts_fidx,
                fword[sp->ts_fidx]);
#endif
          ++depth;
          sp = &stack[depth];
          ++sp->ts_fidx;
          tword[sp->ts_twordlen++] = c;
          sp->ts_arridx = idxs[arridx];
          if (newscore == SCORE_SUBST)
            sp->ts_isdiff = DIFF_YES;
          if (has_mbyte) {
            /* Multi-byte characters are a bit complicated to
             * handle: They differ when any of the bytes differ
             * and then their length may also differ. */
            if (sp->ts_tcharlen == 0) {
              /* First byte. */
              sp->ts_tcharidx = 0;
              sp->ts_tcharlen = MB_BYTE2LEN(c);
              sp->ts_fcharstart = sp->ts_fidx - 1;
              sp->ts_isdiff = (newscore != 0)
                              ? DIFF_YES : DIFF_NONE;
            } else if (sp->ts_isdiff == DIFF_INSERT)
              /* When inserting trail bytes don't advance in the
               * bad word. */
              --sp->ts_fidx;
            if (++sp->ts_tcharidx == sp->ts_tcharlen) {
              /* Last byte of character. */
              if (sp->ts_isdiff == DIFF_YES) {
                /* Correct ts_fidx for the byte length of the
                * character (we didn't check that before). */
                sp->ts_fidx = sp->ts_fcharstart
                              + MB_BYTE2LEN(
                    fword[sp->ts_fcharstart]);

                /* For changing a composing character adjust
                 * the score from SCORE_SUBST to
                 * SCORE_SUBCOMP. */
                if (enc_utf8
                    && utf_iscomposing(
                        mb_ptr2char(tword
                            + sp->ts_twordlen
                            - sp->ts_tcharlen))
                    && utf_iscomposing(
                        mb_ptr2char(fword
                            + sp->ts_fcharstart)))
                  sp->ts_score -=
                    SCORE_SUBST - SCORE_SUBCOMP;

                /* For a similar character adjust score from
                 * SCORE_SUBST to SCORE_SIMILAR. */
                else if (!soundfold
                         && slang->sl_has_map
                         && similar_chars(slang,
                             mb_ptr2char(tword
                                 + sp->ts_twordlen
                                 - sp->ts_tcharlen),
                             mb_ptr2char(fword
                                 + sp->ts_fcharstart)))
                  sp->ts_score -=
                    SCORE_SUBST - SCORE_SIMILAR;
              } else if (sp->ts_isdiff == DIFF_INSERT
                         && sp->ts_twordlen > sp->ts_tcharlen) {
                p = tword + sp->ts_twordlen - sp->ts_tcharlen;
                c = mb_ptr2char(p);
                if (enc_utf8 && utf_iscomposing(c)) {
                  /* Inserting a composing char doesn't
                   * count that much. */
                  sp->ts_score -= SCORE_INS - SCORE_INSCOMP;
                } else   {
                  /* If the previous character was the same,
                   * thus doubling a character, give a bonus
                   * to the score.  Also for the soundfold
                   * tree (might seem illogical but does
                   * give better scores). */
                  mb_ptr_back(tword, p);
                  if (c == mb_ptr2char(p))
                    sp->ts_score -= SCORE_INS
                                    - SCORE_INSDUP;
                }
              }

              /* Starting a new char, reset the length. */
              sp->ts_tcharlen = 0;
            }
          } else   {
            /* If we found a similar char adjust the score.
             * We do this after calling go_deeper() because
             * it's slow. */
            if (newscore != 0
                && !soundfold
                && slang->sl_has_map
                && similar_chars(slang,
                    c, fword[sp->ts_fidx - 1]))
              sp->ts_score -= SCORE_SUBST - SCORE_SIMILAR;
          }
        }
      }
      break;

    case STATE_DEL:
      /* When past the first byte of a multi-byte char don't try
       * delete/insert/swap a character. */
      if (has_mbyte && sp->ts_tcharlen > 0) {
        sp->ts_state = STATE_FINAL;
        break;
      }
      /*
       * Try skipping one character in the bad word (delete it).
       */
      sp->ts_state = STATE_INS_PREP;
      sp->ts_curi = 1;
      if (soundfold && sp->ts_fidx == 0 && fword[sp->ts_fidx] == '*')
        /* Deleting a vowel at the start of a word counts less, see
         * soundalike_score(). */
        newscore = 2 * SCORE_DEL / 3;
      else
        newscore = SCORE_DEL;
      if (fword[sp->ts_fidx] != NUL
          && TRY_DEEPER(su, stack, depth, newscore)) {
        go_deeper(stack, depth, newscore);
#ifdef DEBUG_TRIEWALK
        sprintf(changename[depth], "%.*s-%s: delete %c",
            sp->ts_twordlen, tword, fword + sp->ts_fidx,
            fword[sp->ts_fidx]);
#endif
        ++depth;

        /* Remember what character we deleted, so that we can avoid
         * inserting it again. */
        stack[depth].ts_flags |= TSF_DIDDEL;
        stack[depth].ts_delidx = sp->ts_fidx;

        /* Advance over the character in fword[].  Give a bonus to the
         * score if the same character is following "nn" -> "n".  It's
         * a bit illogical for soundfold tree but it does give better
         * results. */
        if (has_mbyte) {
          c = mb_ptr2char(fword + sp->ts_fidx);
          stack[depth].ts_fidx += MB_BYTE2LEN(fword[sp->ts_fidx]);
          if (enc_utf8 && utf_iscomposing(c))
            stack[depth].ts_score -= SCORE_DEL - SCORE_DELCOMP;
          else if (c == mb_ptr2char(fword + stack[depth].ts_fidx))
            stack[depth].ts_score -= SCORE_DEL - SCORE_DELDUP;
        } else   {
          ++stack[depth].ts_fidx;
          if (fword[sp->ts_fidx] == fword[sp->ts_fidx + 1])
            stack[depth].ts_score -= SCORE_DEL - SCORE_DELDUP;
        }
        break;
      }
    /*FALLTHROUGH*/

    case STATE_INS_PREP:
      if (sp->ts_flags & TSF_DIDDEL) {
        /* If we just deleted a byte then inserting won't make sense,
         * a substitute is always cheaper. */
        sp->ts_state = STATE_SWAP;
        break;
      }

      /* skip over NUL bytes */
      n = sp->ts_arridx;
      for (;; ) {
        if (sp->ts_curi > byts[n]) {
          /* Only NUL bytes at this node, go to next state. */
          sp->ts_state = STATE_SWAP;
          break;
        }
        if (byts[n + sp->ts_curi] != NUL) {
          /* Found a byte to insert. */
          sp->ts_state = STATE_INS;
          break;
        }
        ++sp->ts_curi;
      }
      break;

    /*FALLTHROUGH*/

    case STATE_INS:
      /* Insert one byte.  Repeat this for each possible byte at this
       * node. */
      n = sp->ts_arridx;
      if (sp->ts_curi > byts[n]) {
        /* Done all bytes at this node, go to next state. */
        sp->ts_state = STATE_SWAP;
        break;
      }

      /* Do one more byte at this node, but:
       * - Skip NUL bytes.
       * - Skip the byte if it's equal to the byte in the word,
       *   accepting that byte is always better.
       */
      n += sp->ts_curi++;
      c = byts[n];
      if (soundfold && sp->ts_twordlen == 0 && c == '*')
        /* Inserting a vowel at the start of a word counts less,
         * see soundalike_score(). */
        newscore = 2 * SCORE_INS / 3;
      else
        newscore = SCORE_INS;
      if (c != fword[sp->ts_fidx]
          && TRY_DEEPER(su, stack, depth, newscore)) {
        go_deeper(stack, depth, newscore);
#ifdef DEBUG_TRIEWALK
        sprintf(changename[depth], "%.*s-%s: insert %c",
            sp->ts_twordlen, tword, fword + sp->ts_fidx,
            c);
#endif
        ++depth;
        sp = &stack[depth];
        tword[sp->ts_twordlen++] = c;
        sp->ts_arridx = idxs[n];
        if (has_mbyte) {
          fl = MB_BYTE2LEN(c);
          if (fl > 1) {
            /* There are following bytes for the same character.
             * We must find all bytes before trying
             * delete/insert/swap/etc. */
            sp->ts_tcharlen = fl;
            sp->ts_tcharidx = 1;
            sp->ts_isdiff = DIFF_INSERT;
          }
        } else
          fl = 1;
        if (fl == 1) {
          /* If the previous character was the same, thus doubling a
           * character, give a bonus to the score.  Also for
           * soundfold words (illogical but does give a better
           * score). */
          if (sp->ts_twordlen >= 2
              && tword[sp->ts_twordlen - 2] == c)
            sp->ts_score -= SCORE_INS - SCORE_INSDUP;
        }
      }
      break;

    case STATE_SWAP:
      /*
       * Swap two bytes in the bad word: "12" -> "21".
       * We change "fword" here, it's changed back afterwards at
       * STATE_UNSWAP.
       */
      p = fword + sp->ts_fidx;
      c = *p;
      if (c == NUL) {
        /* End of word, can't swap or replace. */
        sp->ts_state = STATE_FINAL;
        break;
      }

      /* Don't swap if the first character is not a word character.
       * SWAP3 etc. also don't make sense then. */
      if (!soundfold && !spell_iswordp(p, curwin)) {
        sp->ts_state = STATE_REP_INI;
        break;
      }

      if (has_mbyte) {
        n = mb_cptr2len(p);
        c = mb_ptr2char(p);
        if (p[n] == NUL)
          c2 = NUL;
        else if (!soundfold && !spell_iswordp(p + n, curwin))
          c2 = c;           /* don't swap non-word char */
        else
          c2 = mb_ptr2char(p + n);
      } else   {
        if (p[1] == NUL)
          c2 = NUL;
        else if (!soundfold && !spell_iswordp(p + 1, curwin))
          c2 = c;           /* don't swap non-word char */
        else
          c2 = p[1];
      }

      /* When the second character is NUL we can't swap. */
      if (c2 == NUL) {
        sp->ts_state = STATE_REP_INI;
        break;
      }

      /* When characters are identical, swap won't do anything.
       * Also get here if the second char is not a word character. */
      if (c == c2) {
        sp->ts_state = STATE_SWAP3;
        break;
      }
      if (c2 != NUL && TRY_DEEPER(su, stack, depth, SCORE_SWAP)) {
        go_deeper(stack, depth, SCORE_SWAP);
#ifdef DEBUG_TRIEWALK
        sprintf(changename[depth], "%.*s-%s: swap %c and %c",
            sp->ts_twordlen, tword, fword + sp->ts_fidx,
            c, c2);
#endif
        sp->ts_state = STATE_UNSWAP;
        ++depth;
        if (has_mbyte) {
          fl = mb_char2len(c2);
          mch_memmove(p, p + n, fl);
          mb_char2bytes(c, p + fl);
          stack[depth].ts_fidxtry = sp->ts_fidx + n + fl;
        } else   {
          p[0] = c2;
          p[1] = c;
          stack[depth].ts_fidxtry = sp->ts_fidx + 2;
        }
      } else
        /* If this swap doesn't work then SWAP3 won't either. */
        sp->ts_state = STATE_REP_INI;
      break;

    case STATE_UNSWAP:
      /* Undo the STATE_SWAP swap: "21" -> "12". */
      p = fword + sp->ts_fidx;
      if (has_mbyte) {
        n = MB_BYTE2LEN(*p);
        c = mb_ptr2char(p + n);
        mch_memmove(p + MB_BYTE2LEN(p[n]), p, n);
        mb_char2bytes(c, p);
      } else   {
        c = *p;
        *p = p[1];
        p[1] = c;
      }
    /*FALLTHROUGH*/

    case STATE_SWAP3:
      /* Swap two bytes, skipping one: "123" -> "321".  We change
       * "fword" here, it's changed back afterwards at STATE_UNSWAP3. */
      p = fword + sp->ts_fidx;
      if (has_mbyte) {
        n = mb_cptr2len(p);
        c = mb_ptr2char(p);
        fl = mb_cptr2len(p + n);
        c2 = mb_ptr2char(p + n);
        if (!soundfold && !spell_iswordp(p + n + fl, curwin))
          c3 = c;               /* don't swap non-word char */
        else
          c3 = mb_ptr2char(p + n + fl);
      } else   {
        c = *p;
        c2 = p[1];
        if (!soundfold && !spell_iswordp(p + 2, curwin))
          c3 = c;               /* don't swap non-word char */
        else
          c3 = p[2];
      }

      /* When characters are identical: "121" then SWAP3 result is
       * identical, ROT3L result is same as SWAP: "211", ROT3L result is
       * same as SWAP on next char: "112".  Thus skip all swapping.
       * Also skip when c3 is NUL.
       * Also get here when the third character is not a word character.
       * Second character may any char: "a.b" -> "b.a" */
      if (c == c3 || c3 == NUL) {
        sp->ts_state = STATE_REP_INI;
        break;
      }
      if (TRY_DEEPER(su, stack, depth, SCORE_SWAP3)) {
        go_deeper(stack, depth, SCORE_SWAP3);
#ifdef DEBUG_TRIEWALK
        sprintf(changename[depth], "%.*s-%s: swap3 %c and %c",
            sp->ts_twordlen, tword, fword + sp->ts_fidx,
            c, c3);
#endif
        sp->ts_state = STATE_UNSWAP3;
        ++depth;
        if (has_mbyte) {
          tl = mb_char2len(c3);
          mch_memmove(p, p + n + fl, tl);
          mb_char2bytes(c2, p + tl);
          mb_char2bytes(c, p + fl + tl);
          stack[depth].ts_fidxtry = sp->ts_fidx + n + fl + tl;
        } else   {
          p[0] = p[2];
          p[2] = c;
          stack[depth].ts_fidxtry = sp->ts_fidx + 3;
        }
      } else
        sp->ts_state = STATE_REP_INI;
      break;

    case STATE_UNSWAP3:
      /* Undo STATE_SWAP3: "321" -> "123" */
      p = fword + sp->ts_fidx;
      if (has_mbyte) {
        n = MB_BYTE2LEN(*p);
        c2 = mb_ptr2char(p + n);
        fl = MB_BYTE2LEN(p[n]);
        c = mb_ptr2char(p + n + fl);
        tl = MB_BYTE2LEN(p[n + fl]);
        mch_memmove(p + fl + tl, p, n);
        mb_char2bytes(c, p);
        mb_char2bytes(c2, p + tl);
        p = p + tl;
      } else   {
        c = *p;
        *p = p[2];
        p[2] = c;
        ++p;
      }

      if (!soundfold && !spell_iswordp(p, curwin)) {
        /* Middle char is not a word char, skip the rotate.  First and
         * third char were already checked at swap and swap3. */
        sp->ts_state = STATE_REP_INI;
        break;
      }

      /* Rotate three characters left: "123" -> "231".  We change
       * "fword" here, it's changed back afterwards at STATE_UNROT3L. */
      if (TRY_DEEPER(su, stack, depth, SCORE_SWAP3)) {
        go_deeper(stack, depth, SCORE_SWAP3);
#ifdef DEBUG_TRIEWALK
        p = fword + sp->ts_fidx;
        sprintf(changename[depth], "%.*s-%s: rotate left %c%c%c",
            sp->ts_twordlen, tword, fword + sp->ts_fidx,
            p[0], p[1], p[2]);
#endif
        sp->ts_state = STATE_UNROT3L;
        ++depth;
        p = fword + sp->ts_fidx;
        if (has_mbyte) {
          n = mb_cptr2len(p);
          c = mb_ptr2char(p);
          fl = mb_cptr2len(p + n);
          fl += mb_cptr2len(p + n + fl);
          mch_memmove(p, p + n, fl);
          mb_char2bytes(c, p + fl);
          stack[depth].ts_fidxtry = sp->ts_fidx + n + fl;
        } else   {
          c = *p;
          *p = p[1];
          p[1] = p[2];
          p[2] = c;
          stack[depth].ts_fidxtry = sp->ts_fidx + 3;
        }
      } else
        sp->ts_state = STATE_REP_INI;
      break;

    case STATE_UNROT3L:
      /* Undo ROT3L: "231" -> "123" */
      p = fword + sp->ts_fidx;
      if (has_mbyte) {
        n = MB_BYTE2LEN(*p);
        n += MB_BYTE2LEN(p[n]);
        c = mb_ptr2char(p + n);
        tl = MB_BYTE2LEN(p[n]);
        mch_memmove(p + tl, p, n);
        mb_char2bytes(c, p);
      } else   {
        c = p[2];
        p[2] = p[1];
        p[1] = *p;
        *p = c;
      }

      /* Rotate three bytes right: "123" -> "312".  We change "fword"
       * here, it's changed back afterwards at STATE_UNROT3R. */
      if (TRY_DEEPER(su, stack, depth, SCORE_SWAP3)) {
        go_deeper(stack, depth, SCORE_SWAP3);
#ifdef DEBUG_TRIEWALK
        p = fword + sp->ts_fidx;
        sprintf(changename[depth], "%.*s-%s: rotate right %c%c%c",
            sp->ts_twordlen, tword, fword + sp->ts_fidx,
            p[0], p[1], p[2]);
#endif
        sp->ts_state = STATE_UNROT3R;
        ++depth;
        p = fword + sp->ts_fidx;
        if (has_mbyte) {
          n = mb_cptr2len(p);
          n += mb_cptr2len(p + n);
          c = mb_ptr2char(p + n);
          tl = mb_cptr2len(p + n);
          mch_memmove(p + tl, p, n);
          mb_char2bytes(c, p);
          stack[depth].ts_fidxtry = sp->ts_fidx + n + tl;
        } else   {
          c = p[2];
          p[2] = p[1];
          p[1] = *p;
          *p = c;
          stack[depth].ts_fidxtry = sp->ts_fidx + 3;
        }
      } else
        sp->ts_state = STATE_REP_INI;
      break;

    case STATE_UNROT3R:
      /* Undo ROT3R: "312" -> "123" */
      p = fword + sp->ts_fidx;
      if (has_mbyte) {
        c = mb_ptr2char(p);
        tl = MB_BYTE2LEN(*p);
        n = MB_BYTE2LEN(p[tl]);
        n += MB_BYTE2LEN(p[tl + n]);
        mch_memmove(p, p + tl, n);
        mb_char2bytes(c, p + n);
      } else   {
        c = *p;
        *p = p[1];
        p[1] = p[2];
        p[2] = c;
      }
    /*FALLTHROUGH*/

    case STATE_REP_INI:
      /* Check if matching with REP items from the .aff file would work.
       * Quickly skip if:
       * - there are no REP items and we are not in the soundfold trie
       * - the score is going to be too high anyway
       * - already applied a REP item or swapped here  */
      if ((lp->lp_replang == NULL && !soundfold)
          || sp->ts_score + SCORE_REP >= su->su_maxscore
          || sp->ts_fidx < sp->ts_fidxtry) {
        sp->ts_state = STATE_FINAL;
        break;
      }

      /* Use the first byte to quickly find the first entry that may
       * match.  If the index is -1 there is none. */
      if (soundfold)
        sp->ts_curi = slang->sl_repsal_first[fword[sp->ts_fidx]];
      else
        sp->ts_curi = lp->lp_replang->sl_rep_first[fword[sp->ts_fidx]];

      if (sp->ts_curi < 0) {
        sp->ts_state = STATE_FINAL;
        break;
      }

      sp->ts_state = STATE_REP;
    /*FALLTHROUGH*/

    case STATE_REP:
      /* Try matching with REP items from the .aff file.  For each match
       * replace the characters and check if the resulting word is
       * valid. */
      p = fword + sp->ts_fidx;

      if (soundfold)
        gap = &slang->sl_repsal;
      else
        gap = &lp->lp_replang->sl_rep;
      while (sp->ts_curi < gap->ga_len) {
        ftp = (fromto_T *)gap->ga_data + sp->ts_curi++;
        if (*ftp->ft_from != *p) {
          /* past possible matching entries */
          sp->ts_curi = gap->ga_len;
          break;
        }
        if (STRNCMP(ftp->ft_from, p, STRLEN(ftp->ft_from)) == 0
            && TRY_DEEPER(su, stack, depth, SCORE_REP)) {
          go_deeper(stack, depth, SCORE_REP);
#ifdef DEBUG_TRIEWALK
          sprintf(changename[depth], "%.*s-%s: replace %s with %s",
              sp->ts_twordlen, tword, fword + sp->ts_fidx,
              ftp->ft_from, ftp->ft_to);
#endif
          /* Need to undo this afterwards. */
          sp->ts_state = STATE_REP_UNDO;

          /* Change the "from" to the "to" string. */
          ++depth;
          fl = (int)STRLEN(ftp->ft_from);
          tl = (int)STRLEN(ftp->ft_to);
          if (fl != tl) {
            STRMOVE(p + tl, p + fl);
            repextra += tl - fl;
          }
          mch_memmove(p, ftp->ft_to, tl);
          stack[depth].ts_fidxtry = sp->ts_fidx + tl;
          stack[depth].ts_tcharlen = 0;
          break;
        }
      }

      if (sp->ts_curi >= gap->ga_len && sp->ts_state == STATE_REP)
        /* No (more) matches. */
        sp->ts_state = STATE_FINAL;

      break;

    case STATE_REP_UNDO:
      /* Undo a REP replacement and continue with the next one. */
      if (soundfold)
        gap = &slang->sl_repsal;
      else
        gap = &lp->lp_replang->sl_rep;
      ftp = (fromto_T *)gap->ga_data + sp->ts_curi - 1;
      fl = (int)STRLEN(ftp->ft_from);
      tl = (int)STRLEN(ftp->ft_to);
      p = fword + sp->ts_fidx;
      if (fl != tl) {
        STRMOVE(p + fl, p + tl);
        repextra -= tl - fl;
      }
      mch_memmove(p, ftp->ft_from, fl);
      sp->ts_state = STATE_REP;
      break;

    default:
      /* Did all possible states at this level, go up one level. */
      --depth;

      if (depth >= 0 && stack[depth].ts_prefixdepth == PFD_PREFIXTREE) {
        /* Continue in or go back to the prefix tree. */
        byts = pbyts;
        idxs = pidxs;
      }

      /* Don't check for CTRL-C too often, it takes time. */
      if (--breakcheckcount == 0) {
        ui_breakcheck();
        breakcheckcount = 1000;
      }
    }
  }
}


/*
 * Go one level deeper in the tree.
 */
static void go_deeper(trystate_T *stack, int depth, int score_add)
{
  stack[depth + 1] = stack[depth];
  stack[depth + 1].ts_state = STATE_START;
  stack[depth + 1].ts_score = stack[depth].ts_score + score_add;
  stack[depth + 1].ts_curi = 1;         /* start just after length byte */
  stack[depth + 1].ts_flags = 0;
}

/*
 * Case-folding may change the number of bytes: Count nr of chars in
 * fword[flen] and return the byte length of that many chars in "word".
 */
static int nofold_len(char_u *fword, int flen, char_u *word)
{
  char_u      *p;
  int i = 0;

  for (p = fword; p < fword + flen; mb_ptr_adv(p))
    ++i;
  for (p = word; i > 0; mb_ptr_adv(p))
    --i;
  return (int)(p - word);
}

/*
 * "fword" is a good word with case folded.  Find the matching keep-case
 * words and put it in "kword".
 * Theoretically there could be several keep-case words that result in the
 * same case-folded word, but we only find one...
 */
static void find_keepcap_word(slang_T *slang, char_u *fword, char_u *kword)
{
  char_u uword[MAXWLEN];                /* "fword" in upper-case */
  int depth;
  idx_T tryidx;

  /* The following arrays are used at each depth in the tree. */
  idx_T arridx[MAXWLEN];
  int round[MAXWLEN];
  int fwordidx[MAXWLEN];
  int uwordidx[MAXWLEN];
  int kwordlen[MAXWLEN];

  int flen, ulen;
  int l;
  int len;
  int c;
  idx_T lo, hi, m;
  char_u      *p;
  char_u      *byts = slang->sl_kbyts;      /* array with bytes of the words */
  idx_T       *idxs = slang->sl_kidxs;      /* array with indexes */

  if (byts == NULL) {
    /* array is empty: "cannot happen" */
    *kword = NUL;
    return;
  }

  /* Make an all-cap version of "fword". */
  allcap_copy(fword, uword);

  /*
   * Each character needs to be tried both case-folded and upper-case.
   * All this gets very complicated if we keep in mind that changing case
   * may change the byte length of a multi-byte character...
   */
  depth = 0;
  arridx[0] = 0;
  round[0] = 0;
  fwordidx[0] = 0;
  uwordidx[0] = 0;
  kwordlen[0] = 0;
  while (depth >= 0) {
    if (fword[fwordidx[depth]] == NUL) {
      /* We are at the end of "fword".  If the tree allows a word to end
       * here we have found a match. */
      if (byts[arridx[depth] + 1] == 0) {
        kword[kwordlen[depth]] = NUL;
        return;
      }

      /* kword is getting too long, continue one level up */
      --depth;
    } else if (++round[depth] > 2)   {
      /* tried both fold-case and upper-case character, continue one
       * level up */
      --depth;
    } else   {
      /*
       * round[depth] == 1: Try using the folded-case character.
       * round[depth] == 2: Try using the upper-case character.
       */
      if (has_mbyte) {
        flen = mb_cptr2len(fword + fwordidx[depth]);
        ulen = mb_cptr2len(uword + uwordidx[depth]);
      } else
        ulen = flen = 1;
      if (round[depth] == 1) {
        p = fword + fwordidx[depth];
        l = flen;
      } else   {
        p = uword + uwordidx[depth];
        l = ulen;
      }

      for (tryidx = arridx[depth]; l > 0; --l) {
        /* Perform a binary search in the list of accepted bytes. */
        len = byts[tryidx++];
        c = *p++;
        lo = tryidx;
        hi = tryidx + len - 1;
        while (lo < hi) {
          m = (lo + hi) / 2;
          if (byts[m] > c)
            hi = m - 1;
          else if (byts[m] < c)
            lo = m + 1;
          else {
            lo = hi = m;
            break;
          }
        }

        /* Stop if there is no matching byte. */
        if (hi < lo || byts[lo] != c)
          break;

        /* Continue at the child (if there is one). */
        tryidx = idxs[lo];
      }

      if (l == 0) {
        /*
         * Found the matching char.  Copy it to "kword" and go a
         * level deeper.
         */
        if (round[depth] == 1) {
          STRNCPY(kword + kwordlen[depth], fword + fwordidx[depth],
              flen);
          kwordlen[depth + 1] = kwordlen[depth] + flen;
        } else   {
          STRNCPY(kword + kwordlen[depth], uword + uwordidx[depth],
              ulen);
          kwordlen[depth + 1] = kwordlen[depth] + ulen;
        }
        fwordidx[depth + 1] = fwordidx[depth] + flen;
        uwordidx[depth + 1] = uwordidx[depth] + ulen;

        ++depth;
        arridx[depth] = tryidx;
        round[depth] = 0;
      }
    }
  }

  /* Didn't find it: "cannot happen". */
  *kword = NUL;
}

/*
 * Compute the sound-a-like score for suggestions in su->su_ga and add them to
 * su->su_sga.
 */
static void score_comp_sal(suginfo_T *su)
{
  langp_T     *lp;
  char_u badsound[MAXWLEN];
  int i;
  suggest_T   *stp;
  suggest_T   *sstp;
  int score;
  int lpi;

  if (ga_grow(&su->su_sga, su->su_ga.ga_len) == FAIL)
    return;

  /*	Use the sound-folding of the first language that supports it. */
  for (lpi = 0; lpi < curwin->w_s->b_langp.ga_len; ++lpi) {
    lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    if (lp->lp_slang->sl_sal.ga_len > 0) {
      /* soundfold the bad word */
      spell_soundfold(lp->lp_slang, su->su_fbadword, TRUE, badsound);

      for (i = 0; i < su->su_ga.ga_len; ++i) {
        stp = &SUG(su->su_ga, i);

        /* Case-fold the suggested word, sound-fold it and compute the
         * sound-a-like score. */
        score = stp_sal_score(stp, su, lp->lp_slang, badsound);
        if (score < SCORE_MAXMAX) {
          /* Add the suggestion. */
          sstp = &SUG(su->su_sga, su->su_sga.ga_len);
          sstp->st_word = vim_strsave(stp->st_word);
          if (sstp->st_word != NULL) {
            sstp->st_wordlen = stp->st_wordlen;
            sstp->st_score = score;
            sstp->st_altscore = 0;
            sstp->st_orglen = stp->st_orglen;
            ++su->su_sga.ga_len;
          }
        }
      }
      break;
    }
  }
}

/*
 * Combine the list of suggestions in su->su_ga and su->su_sga.
 * They are entwined.
 */
static void score_combine(suginfo_T *su)
{
  int i;
  int j;
  garray_T ga;
  garray_T    *gap;
  langp_T     *lp;
  suggest_T   *stp;
  char_u      *p;
  char_u badsound[MAXWLEN];
  int round;
  int lpi;
  slang_T     *slang = NULL;

  /* Add the alternate score to su_ga. */
  for (lpi = 0; lpi < curwin->w_s->b_langp.ga_len; ++lpi) {
    lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    if (lp->lp_slang->sl_sal.ga_len > 0) {
      /* soundfold the bad word */
      slang = lp->lp_slang;
      spell_soundfold(slang, su->su_fbadword, TRUE, badsound);

      for (i = 0; i < su->su_ga.ga_len; ++i) {
        stp = &SUG(su->su_ga, i);
        stp->st_altscore = stp_sal_score(stp, su, slang, badsound);
        if (stp->st_altscore == SCORE_MAXMAX)
          stp->st_score = (stp->st_score * 3 + SCORE_BIG) / 4;
        else
          stp->st_score = (stp->st_score * 3
                           + stp->st_altscore) / 4;
        stp->st_salscore = FALSE;
      }
      break;
    }
  }

  if (slang == NULL) {  /* Using "double" without sound folding. */
    (void)cleanup_suggestions(&su->su_ga, su->su_maxscore,
        su->su_maxcount);
    return;
  }

  /* Add the alternate score to su_sga. */
  for (i = 0; i < su->su_sga.ga_len; ++i) {
    stp = &SUG(su->su_sga, i);
    stp->st_altscore = spell_edit_score(slang,
        su->su_badword, stp->st_word);
    if (stp->st_score == SCORE_MAXMAX)
      stp->st_score = (SCORE_BIG * 7 + stp->st_altscore) / 8;
    else
      stp->st_score = (stp->st_score * 7 + stp->st_altscore) / 8;
    stp->st_salscore = TRUE;
  }

  /* Remove bad suggestions, sort the suggestions and truncate at "maxcount"
   * for both lists. */
  check_suggestions(su, &su->su_ga);
  (void)cleanup_suggestions(&su->su_ga, su->su_maxscore, su->su_maxcount);
  check_suggestions(su, &su->su_sga);
  (void)cleanup_suggestions(&su->su_sga, su->su_maxscore, su->su_maxcount);

  ga_init2(&ga, (int)sizeof(suginfo_T), 1);
  if (ga_grow(&ga, su->su_ga.ga_len + su->su_sga.ga_len) == FAIL)
    return;

  stp = &SUG(ga, 0);
  for (i = 0; i < su->su_ga.ga_len || i < su->su_sga.ga_len; ++i) {
    /* round 1: get a suggestion from su_ga
     * round 2: get a suggestion from su_sga */
    for (round = 1; round <= 2; ++round) {
      gap = round == 1 ? &su->su_ga : &su->su_sga;
      if (i < gap->ga_len) {
        /* Don't add a word if it's already there. */
        p = SUG(*gap, i).st_word;
        for (j = 0; j < ga.ga_len; ++j)
          if (STRCMP(stp[j].st_word, p) == 0)
            break;
        if (j == ga.ga_len)
          stp[ga.ga_len++] = SUG(*gap, i);
        else
          vim_free(p);
      }
    }
  }

  ga_clear(&su->su_ga);
  ga_clear(&su->su_sga);

  /* Truncate the list to the number of suggestions that will be displayed. */
  if (ga.ga_len > su->su_maxcount) {
    for (i = su->su_maxcount; i < ga.ga_len; ++i)
      vim_free(stp[i].st_word);
    ga.ga_len = su->su_maxcount;
  }

  su->su_ga = ga;
}

/*
 * For the goodword in "stp" compute the soundalike score compared to the
 * badword.
 */
static int 
stp_sal_score (
    suggest_T *stp,
    suginfo_T *su,
    slang_T *slang,
    char_u *badsound          /* sound-folded badword */
)
{
  char_u      *p;
  char_u      *pbad;
  char_u      *pgood;
  char_u badsound2[MAXWLEN];
  char_u fword[MAXWLEN];
  char_u goodsound[MAXWLEN];
  char_u goodword[MAXWLEN];
  int lendiff;

  lendiff = (int)(su->su_badlen - stp->st_orglen);
  if (lendiff >= 0)
    pbad = badsound;
  else {
    /* soundfold the bad word with more characters following */
    (void)spell_casefold(su->su_badptr, stp->st_orglen, fword, MAXWLEN);

    /* When joining two words the sound often changes a lot.  E.g., "t he"
     * sounds like "t h" while "the" sounds like "@".  Avoid that by
     * removing the space.  Don't do it when the good word also contains a
     * space. */
    if (vim_iswhite(su->su_badptr[su->su_badlen])
        && *skiptowhite(stp->st_word) == NUL)
      for (p = fword; *(p = skiptowhite(p)) != NUL; )
        STRMOVE(p, p + 1);

    spell_soundfold(slang, fword, TRUE, badsound2);
    pbad = badsound2;
  }

  if (lendiff > 0 && stp->st_wordlen + lendiff < MAXWLEN) {
    /* Add part of the bad word to the good word, so that we soundfold
     * what replaces the bad word. */
    STRCPY(goodword, stp->st_word);
    vim_strncpy(goodword + stp->st_wordlen,
        su->su_badptr + su->su_badlen - lendiff, lendiff);
    pgood = goodword;
  } else
    pgood = stp->st_word;

  /* Sound-fold the word and compute the score for the difference. */
  spell_soundfold(slang, pgood, FALSE, goodsound);

  return soundalike_score(goodsound, pbad);
}

/* structure used to store soundfolded words that add_sound_suggest() has
 * handled already. */
typedef struct {
  short sft_score;              /* lowest score used */
  char_u sft_word[1];           /* soundfolded word, actually longer */
} sftword_T;

static sftword_T dumsft;
#define HIKEY2SFT(p)  ((sftword_T *)(p - (dumsft.sft_word - (char_u *)&dumsft)))
#define HI2SFT(hi)     HIKEY2SFT((hi)->hi_key)

/*
 * Prepare for calling suggest_try_soundalike().
 */
static void suggest_try_soundalike_prep(void)                 {
  langp_T     *lp;
  int lpi;
  slang_T     *slang;

  /* Do this for all languages that support sound folding and for which a
   * .sug file has been loaded. */
  for (lpi = 0; lpi < curwin->w_s->b_langp.ga_len; ++lpi) {
    lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    slang = lp->lp_slang;
    if (slang->sl_sal.ga_len > 0 && slang->sl_sbyts != NULL)
      /* prepare the hashtable used by add_sound_suggest() */
      hash_init(&slang->sl_sounddone);
  }
}

/*
 * Find suggestions by comparing the word in a sound-a-like form.
 * Note: This doesn't support postponed prefixes.
 */
static void suggest_try_soundalike(suginfo_T *su)
{
  char_u salword[MAXWLEN];
  langp_T     *lp;
  int lpi;
  slang_T     *slang;

  /* Do this for all languages that support sound folding and for which a
   * .sug file has been loaded. */
  for (lpi = 0; lpi < curwin->w_s->b_langp.ga_len; ++lpi) {
    lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    slang = lp->lp_slang;
    if (slang->sl_sal.ga_len > 0 && slang->sl_sbyts != NULL) {
      /* soundfold the bad word */
      spell_soundfold(slang, su->su_fbadword, TRUE, salword);

      /* try all kinds of inserts/deletes/swaps/etc. */
      /* TODO: also soundfold the next words, so that we can try joining
       * and splitting */
      suggest_trie_walk(su, lp, salword, TRUE);
    }
  }
}

/*
 * Finish up after calling suggest_try_soundalike().
 */
static void suggest_try_soundalike_finish(void)                 {
  langp_T     *lp;
  int lpi;
  slang_T     *slang;
  int todo;
  hashitem_T  *hi;

  /* Do this for all languages that support sound folding and for which a
   * .sug file has been loaded. */
  for (lpi = 0; lpi < curwin->w_s->b_langp.ga_len; ++lpi) {
    lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    slang = lp->lp_slang;
    if (slang->sl_sal.ga_len > 0 && slang->sl_sbyts != NULL) {
      /* Free the info about handled words. */
      todo = (int)slang->sl_sounddone.ht_used;
      for (hi = slang->sl_sounddone.ht_array; todo > 0; ++hi)
        if (!HASHITEM_EMPTY(hi)) {
          vim_free(HI2SFT(hi));
          --todo;
        }

      /* Clear the hashtable, it may also be used by another region. */
      hash_clear(&slang->sl_sounddone);
      hash_init(&slang->sl_sounddone);
    }
  }
}

/*
 * A match with a soundfolded word is found.  Add the good word(s) that
 * produce this soundfolded word.
 */
static void 
add_sound_suggest (
    suginfo_T *su,
    char_u *goodword,
    int score,                      /* soundfold score  */
    langp_T *lp
)
{
  slang_T     *slang = lp->lp_slang;    /* language for sound folding */
  int sfwordnr;
  char_u      *nrline;
  int orgnr;
  char_u theword[MAXWLEN];
  int i;
  int wlen;
  char_u      *byts;
  idx_T       *idxs;
  int n;
  int wordcount;
  int wc;
  int goodscore;
  hash_T hash;
  hashitem_T  *hi;
  sftword_T   *sft;
  int bc, gc;
  int limit;

  /*
   * It's very well possible that the same soundfold word is found several
   * times with different scores.  Since the following is quite slow only do
   * the words that have a better score than before.  Use a hashtable to
   * remember the words that have been done.
   */
  hash = hash_hash(goodword);
  hi = hash_lookup(&slang->sl_sounddone, goodword, hash);
  if (HASHITEM_EMPTY(hi)) {
    sft = (sftword_T *)alloc((unsigned)(sizeof(sftword_T)
                                        + STRLEN(goodword)));
    if (sft != NULL) {
      sft->sft_score = score;
      STRCPY(sft->sft_word, goodword);
      hash_add_item(&slang->sl_sounddone, hi, sft->sft_word, hash);
    }
  } else   {
    sft = HI2SFT(hi);
    if (score >= sft->sft_score)
      return;
    sft->sft_score = score;
  }

  /*
   * Find the word nr in the soundfold tree.
   */
  sfwordnr = soundfold_find(slang, goodword);
  if (sfwordnr < 0) {
    EMSG2(_(e_intern2), "add_sound_suggest()");
    return;
  }

  /*
   * go over the list of good words that produce this soundfold word
   */
  nrline = ml_get_buf(slang->sl_sugbuf, (linenr_T)(sfwordnr + 1), FALSE);
  orgnr = 0;
  while (*nrline != NUL) {
    /* The wordnr was stored in a minimal nr of bytes as an offset to the
     * previous wordnr. */
    orgnr += bytes2offset(&nrline);

    byts = slang->sl_fbyts;
    idxs = slang->sl_fidxs;

    /* Lookup the word "orgnr" one of the two tries. */
    n = 0;
    wordcount = 0;
    for (wlen = 0; wlen < MAXWLEN - 3; ++wlen) {
      i = 1;
      if (wordcount == orgnr && byts[n + 1] == NUL)
        break;          /* found end of word */

      if (byts[n + 1] == NUL)
        ++wordcount;

      /* skip over the NUL bytes */
      for (; byts[n + i] == NUL; ++i)
        if (i > byts[n]) {              /* safety check */
          STRCPY(theword + wlen, "BAD");
          wlen += 3;
          goto badword;
        }

      /* One of the siblings must have the word. */
      for (; i < byts[n]; ++i) {
        wc = idxs[idxs[n + i]];         /* nr of words under this byte */
        if (wordcount + wc > orgnr)
          break;
        wordcount += wc;
      }

      theword[wlen] = byts[n + i];
      n = idxs[n + i];
    }
badword:
    theword[wlen] = NUL;

    /* Go over the possible flags and regions. */
    for (; i <= byts[n] && byts[n + i] == NUL; ++i) {
      char_u cword[MAXWLEN];
      char_u      *p;
      int flags = (int)idxs[n + i];

      /* Skip words with the NOSUGGEST flag */
      if (flags & WF_NOSUGGEST)
        continue;

      if (flags & WF_KEEPCAP) {
        /* Must find the word in the keep-case tree. */
        find_keepcap_word(slang, theword, cword);
        p = cword;
      } else   {
        flags |= su->su_badflags;
        if ((flags & WF_CAPMASK) != 0) {
          /* Need to fix case according to "flags". */
          make_case_word(theword, cword, flags);
          p = cword;
        } else
          p = theword;
      }

      /* Add the suggestion. */
      if (sps_flags & SPS_DOUBLE) {
        /* Add the suggestion if the score isn't too bad. */
        if (score <= su->su_maxscore)
          add_suggestion(su, &su->su_sga, p, su->su_badlen,
              score, 0, FALSE, slang, FALSE);
      } else   {
        /* Add a penalty for words in another region. */
        if ((flags & WF_REGION)
            && (((unsigned)flags >> 16) & lp->lp_region) == 0)
          goodscore = SCORE_REGION;
        else
          goodscore = 0;

        /* Add a small penalty for changing the first letter from
         * lower to upper case.  Helps for "tath" -> "Kath", which is
         * less common than "tath" -> "path".  Don't do it when the
         * letter is the same, that has already been counted. */
        gc = PTR2CHAR(p);
        if (SPELL_ISUPPER(gc)) {
          bc = PTR2CHAR(su->su_badword);
          if (!SPELL_ISUPPER(bc)
              && SPELL_TOFOLD(bc) != SPELL_TOFOLD(gc))
            goodscore += SCORE_ICASE / 2;
        }

        /* Compute the score for the good word.  This only does letter
         * insert/delete/swap/replace.  REP items are not considered,
         * which may make the score a bit higher.
         * Use a limit for the score to make it work faster.  Use
         * MAXSCORE(), because RESCORE() will change the score.
         * If the limit is very high then the iterative method is
         * inefficient, using an array is quicker. */
        limit = MAXSCORE(su->su_sfmaxscore - goodscore, score);
        if (limit > SCORE_LIMITMAX)
          goodscore += spell_edit_score(slang, su->su_badword, p);
        else
          goodscore += spell_edit_score_limit(slang, su->su_badword,
              p, limit);

        /* When going over the limit don't bother to do the rest. */
        if (goodscore < SCORE_MAXMAX) {
          /* Give a bonus to words seen before. */
          goodscore = score_wordcount_adj(slang, goodscore, p, FALSE);

          /* Add the suggestion if the score isn't too bad. */
          goodscore = RESCORE(goodscore, score);
          if (goodscore <= su->su_sfmaxscore)
            add_suggestion(su, &su->su_ga, p, su->su_badlen,
                goodscore, score, TRUE, slang, TRUE);
        }
      }
    }
    /* smsg("word %s (%d): %s (%d)", sftword, sftnr, theword, orgnr); */
  }
}

/*
 * Find word "word" in fold-case tree for "slang" and return the word number.
 */
static int soundfold_find(slang_T *slang, char_u *word)
{
  idx_T arridx = 0;
  int len;
  int wlen = 0;
  int c;
  char_u      *ptr = word;
  char_u      *byts;
  idx_T       *idxs;
  int wordnr = 0;

  byts = slang->sl_sbyts;
  idxs = slang->sl_sidxs;

  for (;; ) {
    /* First byte is the number of possible bytes. */
    len = byts[arridx++];

    /* If the first possible byte is a zero the word could end here.
     * If the word ends we found the word.  If not skip the NUL bytes. */
    c = ptr[wlen];
    if (byts[arridx] == NUL) {
      if (c == NUL)
        break;

      /* Skip over the zeros, there can be several. */
      while (len > 0 && byts[arridx] == NUL) {
        ++arridx;
        --len;
      }
      if (len == 0)
        return -1;            /* no children, word should have ended here */
      ++wordnr;
    }

    /* If the word ends we didn't find it. */
    if (c == NUL)
      return -1;

    /* Perform a binary search in the list of accepted bytes. */
    if (c == TAB)           /* <Tab> is handled like <Space> */
      c = ' ';
    while (byts[arridx] < c) {
      /* The word count is in the first idxs[] entry of the child. */
      wordnr += idxs[idxs[arridx]];
      ++arridx;
      if (--len == 0)           /* end of the bytes, didn't find it */
        return -1;
    }
    if (byts[arridx] != c)      /* didn't find the byte */
      return -1;

    /* Continue at the child (if there is one). */
    arridx = idxs[arridx];
    ++wlen;

    /* One space in the good word may stand for several spaces in the
     * checked word. */
    if (c == ' ')
      while (ptr[wlen] == ' ' || ptr[wlen] == TAB)
        ++wlen;
  }

  return wordnr;
}

/*
 * Copy "fword" to "cword", fixing case according to "flags".
 */
static void make_case_word(char_u *fword, char_u *cword, int flags)
{
  if (flags & WF_ALLCAP)
    /* Make it all upper-case */
    allcap_copy(fword, cword);
  else if (flags & WF_ONECAP)
    /* Make the first letter upper-case */
    onecap_copy(fword, cword, TRUE);
  else
    /* Use goodword as-is. */
    STRCPY(cword, fword);
}

/*
 * Use map string "map" for languages "lp".
 */
static void set_map_str(slang_T *lp, char_u *map)
{
  char_u      *p;
  int headc = 0;
  int c;
  int i;

  if (*map == NUL) {
    lp->sl_has_map = FALSE;
    return;
  }
  lp->sl_has_map = TRUE;

  /* Init the array and hash tables empty. */
  for (i = 0; i < 256; ++i)
    lp->sl_map_array[i] = 0;
  hash_init(&lp->sl_map_hash);

  /*
   * The similar characters are stored separated with slashes:
   * "aaa/bbb/ccc/".  Fill sl_map_array[c] with the character before c and
   * before the same slash.  For characters above 255 sl_map_hash is used.
   */
  for (p = map; *p != NUL; ) {
    c = mb_cptr2char_adv(&p);
    if (c == '/')
      headc = 0;
    else {
      if (headc == 0)
        headc = c;

      /* Characters above 255 don't fit in sl_map_array[], put them in
       * the hash table.  Each entry is the char, a NUL the headchar and
       * a NUL. */
      if (c >= 256) {
        int cl = mb_char2len(c);
        int headcl = mb_char2len(headc);
        char_u      *b;
        hash_T hash;
        hashitem_T  *hi;

        b = alloc((unsigned)(cl + headcl + 2));
        if (b == NULL)
          return;
        mb_char2bytes(c, b);
        b[cl] = NUL;
        mb_char2bytes(headc, b + cl + 1);
        b[cl + 1 + headcl] = NUL;
        hash = hash_hash(b);
        hi = hash_lookup(&lp->sl_map_hash, b, hash);
        if (HASHITEM_EMPTY(hi))
          hash_add_item(&lp->sl_map_hash, hi, b, hash);
        else {
          /* This should have been checked when generating the .spl
           * file. */
          EMSG(_("E783: duplicate char in MAP entry"));
          vim_free(b);
        }
      } else
        lp->sl_map_array[c] = headc;
    }
  }
}

/*
 * Return TRUE if "c1" and "c2" are similar characters according to the MAP
 * lines in the .aff file.
 */
static int similar_chars(slang_T *slang, int c1, int c2)
{
  int m1, m2;
  char_u buf[MB_MAXBYTES + 1];
  hashitem_T  *hi;

  if (c1 >= 256) {
    buf[mb_char2bytes(c1, buf)] = 0;
    hi = hash_find(&slang->sl_map_hash, buf);
    if (HASHITEM_EMPTY(hi))
      m1 = 0;
    else
      m1 = mb_ptr2char(hi->hi_key + STRLEN(hi->hi_key) + 1);
  } else
    m1 = slang->sl_map_array[c1];
  if (m1 == 0)
    return FALSE;


  if (c2 >= 256) {
    buf[mb_char2bytes(c2, buf)] = 0;
    hi = hash_find(&slang->sl_map_hash, buf);
    if (HASHITEM_EMPTY(hi))
      m2 = 0;
    else
      m2 = mb_ptr2char(hi->hi_key + STRLEN(hi->hi_key) + 1);
  } else
    m2 = slang->sl_map_array[c2];

  return m1 == m2;
}

/*
 * Add a suggestion to the list of suggestions.
 * For a suggestion that is already in the list the lowest score is remembered.
 */
static void 
add_suggestion (
    suginfo_T *su,
    garray_T *gap,               /* either su_ga or su_sga */
    char_u *goodword,
    int badlenarg,                  /* len of bad word replaced with "goodword" */
    int score,
    int altscore,
    int had_bonus,                  /* value for st_had_bonus */
    slang_T *slang,             /* language for sound folding */
    int maxsf                      /* su_maxscore applies to soundfold score,
                                   su_sfmaxscore to the total score. */
)
{
  int goodlen;                  /* len of goodword changed */
  int badlen;                   /* len of bad word changed */
  suggest_T   *stp;
  suggest_T new_sug;
  int i;
  char_u      *pgood, *pbad;

  /* Minimize "badlen" for consistency.  Avoids that changing "the the" to
   * "thee the" is added next to changing the first "the" the "thee".  */
  pgood = goodword + STRLEN(goodword);
  pbad = su->su_badptr + badlenarg;
  for (;; ) {
    goodlen = (int)(pgood - goodword);
    badlen = (int)(pbad - su->su_badptr);
    if (goodlen <= 0 || badlen <= 0)
      break;
    mb_ptr_back(goodword, pgood);
    mb_ptr_back(su->su_badptr, pbad);
    if (has_mbyte) {
      if (mb_ptr2char(pgood) != mb_ptr2char(pbad))
        break;
    } else if (*pgood != *pbad)
      break;
  }

  if (badlen == 0 && goodlen == 0)
    /* goodword doesn't change anything; may happen for "the the" changing
     * the first "the" to itself. */
    return;

  if (gap->ga_len == 0)
    i = -1;
  else {
    /* Check if the word is already there.  Also check the length that is
     * being replaced "thes," -> "these" is a different suggestion from
     * "thes" -> "these". */
    stp = &SUG(*gap, 0);
    for (i = gap->ga_len; --i >= 0; ++stp)
      if (stp->st_wordlen == goodlen
          && stp->st_orglen == badlen
          && STRNCMP(stp->st_word, goodword, goodlen) == 0) {
        /*
         * Found it.  Remember the word with the lowest score.
         */
        if (stp->st_slang == NULL)
          stp->st_slang = slang;

        new_sug.st_score = score;
        new_sug.st_altscore = altscore;
        new_sug.st_had_bonus = had_bonus;

        if (stp->st_had_bonus != had_bonus) {
          /* Only one of the two had the soundalike score computed.
           * Need to do that for the other one now, otherwise the
           * scores can't be compared.  This happens because
           * suggest_try_change() doesn't compute the soundalike
           * word to keep it fast, while some special methods set
           * the soundalike score to zero. */
          if (had_bonus)
            rescore_one(su, stp);
          else {
            new_sug.st_word = stp->st_word;
            new_sug.st_wordlen = stp->st_wordlen;
            new_sug.st_slang = stp->st_slang;
            new_sug.st_orglen = badlen;
            rescore_one(su, &new_sug);
          }
        }

        if (stp->st_score > new_sug.st_score) {
          stp->st_score = new_sug.st_score;
          stp->st_altscore = new_sug.st_altscore;
          stp->st_had_bonus = new_sug.st_had_bonus;
        }
        break;
      }
  }

  if (i < 0 && ga_grow(gap, 1) == OK) {
    /* Add a suggestion. */
    stp = &SUG(*gap, gap->ga_len);
    stp->st_word = vim_strnsave(goodword, goodlen);
    if (stp->st_word != NULL) {
      stp->st_wordlen = goodlen;
      stp->st_score = score;
      stp->st_altscore = altscore;
      stp->st_had_bonus = had_bonus;
      stp->st_orglen = badlen;
      stp->st_slang = slang;
      ++gap->ga_len;

      /* If we have too many suggestions now, sort the list and keep
       * the best suggestions. */
      if (gap->ga_len > SUG_MAX_COUNT(su)) {
        if (maxsf)
          su->su_sfmaxscore = cleanup_suggestions(gap,
              su->su_sfmaxscore, SUG_CLEAN_COUNT(su));
        else
          su->su_maxscore = cleanup_suggestions(gap,
              su->su_maxscore, SUG_CLEAN_COUNT(su));
      }
    }
  }
}

/*
 * Suggestions may in fact be flagged as errors.  Esp. for banned words and
 * for split words, such as "the the".  Remove these from the list here.
 */
static void 
check_suggestions (
    suginfo_T *su,
    garray_T *gap                   /* either su_ga or su_sga */
)
{
  suggest_T   *stp;
  int i;
  char_u longword[MAXWLEN + 1];
  int len;
  hlf_T attr;

  stp = &SUG(*gap, 0);
  for (i = gap->ga_len - 1; i >= 0; --i) {
    /* Need to append what follows to check for "the the". */
    vim_strncpy(longword, stp[i].st_word, MAXWLEN);
    len = stp[i].st_wordlen;
    vim_strncpy(longword + len, su->su_badptr + stp[i].st_orglen,
        MAXWLEN - len);
    attr = HLF_COUNT;
    (void)spell_check(curwin, longword, &attr, NULL, FALSE);
    if (attr != HLF_COUNT) {
      /* Remove this entry. */
      vim_free(stp[i].st_word);
      --gap->ga_len;
      if (i < gap->ga_len)
        mch_memmove(stp + i, stp + i + 1,
            sizeof(suggest_T) * (gap->ga_len - i));
    }
  }
}


/*
 * Add a word to be banned.
 */
static void add_banned(suginfo_T *su, char_u *word)
{
  char_u      *s;
  hash_T hash;
  hashitem_T  *hi;

  hash = hash_hash(word);
  hi = hash_lookup(&su->su_banned, word, hash);
  if (HASHITEM_EMPTY(hi)) {
    s = vim_strsave(word);
    if (s != NULL)
      hash_add_item(&su->su_banned, hi, s, hash);
  }
}

/*
 * Recompute the score for all suggestions if sound-folding is possible.  This
 * is slow, thus only done for the final results.
 */
static void rescore_suggestions(suginfo_T *su)
{
  int i;

  if (su->su_sallang != NULL)
    for (i = 0; i < su->su_ga.ga_len; ++i)
      rescore_one(su, &SUG(su->su_ga, i));
}

/*
 * Recompute the score for one suggestion if sound-folding is possible.
 */
static void rescore_one(suginfo_T *su, suggest_T *stp)
{
  slang_T     *slang = stp->st_slang;
  char_u sal_badword[MAXWLEN];
  char_u      *p;

  /* Only rescore suggestions that have no sal score yet and do have a
   * language. */
  if (slang != NULL && slang->sl_sal.ga_len > 0 && !stp->st_had_bonus) {
    if (slang == su->su_sallang)
      p = su->su_sal_badword;
    else {
      spell_soundfold(slang, su->su_fbadword, TRUE, sal_badword);
      p = sal_badword;
    }

    stp->st_altscore = stp_sal_score(stp, su, slang, p);
    if (stp->st_altscore == SCORE_MAXMAX)
      stp->st_altscore = SCORE_BIG;
    stp->st_score = RESCORE(stp->st_score, stp->st_altscore);
    stp->st_had_bonus = TRUE;
  }
}

static int
sug_compare(const void *s1, const void *s2);

/*
 * Function given to qsort() to sort the suggestions on st_score.
 * First on "st_score", then "st_altscore" then alphabetically.
 */
static int sug_compare(const void *s1, const void *s2)
{
  suggest_T   *p1 = (suggest_T *)s1;
  suggest_T   *p2 = (suggest_T *)s2;
  int n = p1->st_score - p2->st_score;

  if (n == 0) {
    n = p1->st_altscore - p2->st_altscore;
    if (n == 0)
      n = STRICMP(p1->st_word, p2->st_word);
  }
  return n;
}

/*
 * Cleanup the suggestions:
 * - Sort on score.
 * - Remove words that won't be displayed.
 * Returns the maximum score in the list or "maxscore" unmodified.
 */
static int 
cleanup_suggestions (
    garray_T *gap,
    int maxscore,
    int keep                       /* nr of suggestions to keep */
)
{
  suggest_T   *stp = &SUG(*gap, 0);
  int i;

  /* Sort the list. */
  qsort(gap->ga_data, (size_t)gap->ga_len, sizeof(suggest_T), sug_compare);

  /* Truncate the list to the number of suggestions that will be displayed. */
  if (gap->ga_len > keep) {
    for (i = keep; i < gap->ga_len; ++i)
      vim_free(stp[i].st_word);
    gap->ga_len = keep;
    return stp[keep - 1].st_score;
  }
  return maxscore;
}

/*
 * Soundfold a string, for soundfold().
 * Result is in allocated memory, NULL for an error.
 */
char_u *eval_soundfold(char_u *word)
{
  langp_T     *lp;
  char_u sound[MAXWLEN];
  int lpi;

  if (curwin->w_p_spell && *curwin->w_s->b_p_spl != NUL)
    /* Use the sound-folding of the first language that supports it. */
    for (lpi = 0; lpi < curwin->w_s->b_langp.ga_len; ++lpi) {
      lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
      if (lp->lp_slang->sl_sal.ga_len > 0) {
        /* soundfold the word */
        spell_soundfold(lp->lp_slang, word, FALSE, sound);
        return vim_strsave(sound);
      }
    }

  /* No language with sound folding, return word as-is. */
  return vim_strsave(word);
}

/*
 * Turn "inword" into its sound-a-like equivalent in "res[MAXWLEN]".
 *
 * There are many ways to turn a word into a sound-a-like representation.  The
 * oldest is Soundex (1918!).   A nice overview can be found in "Approximate
 * swedish name matching - survey and test of different algorithms" by Klas
 * Erikson.
 *
 * We support two methods:
 * 1. SOFOFROM/SOFOTO do a simple character mapping.
 * 2. SAL items define a more advanced sound-folding (and much slower).
 */
static void 
spell_soundfold (
    slang_T *slang,
    char_u *inword,
    int folded,                 /* "inword" is already case-folded */
    char_u *res
)
{
  char_u fword[MAXWLEN];
  char_u      *word;

  if (slang->sl_sofo)
    /* SOFOFROM and SOFOTO used */
    spell_soundfold_sofo(slang, inword, res);
  else {
    /* SAL items used.  Requires the word to be case-folded. */
    if (folded)
      word = inword;
    else {
      (void)spell_casefold(inword, (int)STRLEN(inword), fword, MAXWLEN);
      word = fword;
    }

    if (has_mbyte)
      spell_soundfold_wsal(slang, word, res);
    else
      spell_soundfold_sal(slang, word, res);
  }
}

/*
 * Perform sound folding of "inword" into "res" according to SOFOFROM and
 * SOFOTO lines.
 */
static void spell_soundfold_sofo(slang_T *slang, char_u *inword, char_u *res)
{
  char_u      *s;
  int ri = 0;
  int c;

  if (has_mbyte) {
    int prevc = 0;
    int     *ip;

    /* The sl_sal_first[] table contains the translation for chars up to
     * 255, sl_sal the rest. */
    for (s = inword; *s != NUL; ) {
      c = mb_cptr2char_adv(&s);
      if (enc_utf8 ? utf_class(c) == 0 : vim_iswhite(c))
        c = ' ';
      else if (c < 256)
        c = slang->sl_sal_first[c];
      else {
        ip = ((int **)slang->sl_sal.ga_data)[c & 0xff];
        if (ip == NULL)                 /* empty list, can't match */
          c = NUL;
        else
          for (;; ) {                   /* find "c" in the list */
            if (*ip == 0) {             /* not found */
              c = NUL;
              break;
            }
            if (*ip == c) {             /* match! */
              c = ip[1];
              break;
            }
            ip += 2;
          }
      }

      if (c != NUL && c != prevc) {
        ri += mb_char2bytes(c, res + ri);
        if (ri + MB_MAXBYTES > MAXWLEN)
          break;
        prevc = c;
      }
    }
  } else   {
    /* The sl_sal_first[] table contains the translation. */
    for (s = inword; (c = *s) != NUL; ++s) {
      if (vim_iswhite(c))
        c = ' ';
      else
        c = slang->sl_sal_first[c];
      if (c != NUL && (ri == 0 || res[ri - 1] != c))
        res[ri++] = c;
    }
  }

  res[ri] = NUL;
}

static void spell_soundfold_sal(slang_T *slang, char_u *inword, char_u *res)
{
  salitem_T   *smp;
  char_u word[MAXWLEN];
  char_u      *s = inword;
  char_u      *t;
  char_u      *pf;
  int i, j, z;
  int reslen;
  int n, k = 0;
  int z0;
  int k0;
  int n0;
  int c;
  int pri;
  int p0 = -333;
  int c0;

  /* Remove accents, if wanted.  We actually remove all non-word characters.
   * But keep white space.  We need a copy, the word may be changed here. */
  if (slang->sl_rem_accents) {
    t = word;
    while (*s != NUL) {
      if (vim_iswhite(*s)) {
        *t++ = ' ';
        s = skipwhite(s);
      } else   {
        if (spell_iswordp_nmw(s, curwin))
          *t++ = *s;
        ++s;
      }
    }
    *t = NUL;
  } else
    vim_strncpy(word, s, MAXWLEN - 1);

  smp = (salitem_T *)slang->sl_sal.ga_data;

  /*
   * This comes from Aspell phonet.cpp.  Converted from C++ to C.
   * Changed to keep spaces.
   */
  i = reslen = z = 0;
  while ((c = word[i]) != NUL) {
    /* Start with the first rule that has the character in the word. */
    n = slang->sl_sal_first[c];
    z0 = 0;

    if (n >= 0) {
      /* check all rules for the same letter */
      for (; (s = smp[n].sm_lead)[0] == c; ++n) {
        /* Quickly skip entries that don't match the word.  Most
         * entries are less then three chars, optimize for that. */
        k = smp[n].sm_leadlen;
        if (k > 1) {
          if (word[i + 1] != s[1])
            continue;
          if (k > 2) {
            for (j = 2; j < k; ++j)
              if (word[i + j] != s[j])
                break;
            if (j < k)
              continue;
          }
        }

        if ((pf = smp[n].sm_oneof) != NULL) {
          /* Check for match with one of the chars in "sm_oneof". */
          while (*pf != NUL && *pf != word[i + k])
            ++pf;
          if (*pf == NUL)
            continue;
          ++k;
        }
        s = smp[n].sm_rules;
        pri = 5;            /* default priority */

        p0 = *s;
        k0 = k;
        while (*s == '-' && k > 1) {
          k--;
          s++;
        }
        if (*s == '<')
          s++;
        if (VIM_ISDIGIT(*s)) {
          /* determine priority */
          pri = *s - '0';
          s++;
        }
        if (*s == '^' && *(s + 1) == '^')
          s++;

        if (*s == NUL
            || (*s == '^'
                && (i == 0 || !(word[i - 1] == ' '
                                || spell_iswordp(word + i - 1, curwin)))
                && (*(s + 1) != '$'
                    || (!spell_iswordp(word + i + k0, curwin))))
            || (*s == '$' && i > 0
                && spell_iswordp(word + i - 1, curwin)
                && (!spell_iswordp(word + i + k0, curwin)))) {
          /* search for followup rules, if:    */
          /* followup and k > 1  and  NO '-' in searchstring */
          c0 = word[i + k - 1];
          n0 = slang->sl_sal_first[c0];

          if (slang->sl_followup && k > 1 && n0 >= 0
              && p0 != '-' && word[i + k] != NUL) {
            /* test follow-up rule for "word[i + k]" */
            for (; (s = smp[n0].sm_lead)[0] == c0; ++n0) {
              /* Quickly skip entries that don't match the word.
               * */
              k0 = smp[n0].sm_leadlen;
              if (k0 > 1) {
                if (word[i + k] != s[1])
                  continue;
                if (k0 > 2) {
                  pf = word + i + k + 1;
                  for (j = 2; j < k0; ++j)
                    if (*pf++ != s[j])
                      break;
                  if (j < k0)
                    continue;
                }
              }
              k0 += k - 1;

              if ((pf = smp[n0].sm_oneof) != NULL) {
                /* Check for match with one of the chars in
                 * "sm_oneof". */
                while (*pf != NUL && *pf != word[i + k0])
                  ++pf;
                if (*pf == NUL)
                  continue;
                ++k0;
              }

              p0 = 5;
              s = smp[n0].sm_rules;
              while (*s == '-') {
                /* "k0" gets NOT reduced because
                 * "if (k0 == k)" */
                s++;
              }
              if (*s == '<')
                s++;
              if (VIM_ISDIGIT(*s)) {
                p0 = *s - '0';
                s++;
              }

              if (*s == NUL
                  /* *s == '^' cuts */
                  || (*s == '$'
                      && !spell_iswordp(word + i + k0,
                          curwin))) {
                if (k0 == k)
                  /* this is just a piece of the string */
                  continue;

                if (p0 < pri)
                  /* priority too low */
                  continue;
                /* rule fits; stop search */
                break;
              }
            }

            if (p0 >= pri && smp[n0].sm_lead[0] == c0)
              continue;
          }

          /* replace string */
          s = smp[n].sm_to;
          if (s == NULL)
            s = (char_u *)"";
          pf = smp[n].sm_rules;
          p0 = (vim_strchr(pf, '<') != NULL) ? 1 : 0;
          if (p0 == 1 && z == 0) {
            /* rule with '<' is used */
            if (reslen > 0 && *s != NUL && (res[reslen - 1] == c
                                            || res[reslen - 1] == *s))
              reslen--;
            z0 = 1;
            z = 1;
            k0 = 0;
            while (*s != NUL && word[i + k0] != NUL) {
              word[i + k0] = *s;
              k0++;
              s++;
            }
            if (k > k0)
              STRMOVE(word + i + k0, word + i + k);

            /* new "actual letter" */
            c = word[i];
          } else   {
            /* no '<' rule used */
            i += k - 1;
            z = 0;
            while (*s != NUL && s[1] != NUL && reslen < MAXWLEN) {
              if (reslen == 0 || res[reslen - 1] != *s)
                res[reslen++] = *s;
              s++;
            }
            /* new "actual letter" */
            c = *s;
            if (strstr((char *)pf, "^^") != NULL) {
              if (c != NUL)
                res[reslen++] = c;
              STRMOVE(word, word + i + 1);
              i = 0;
              z0 = 1;
            }
          }
          break;
        }
      }
    } else if (vim_iswhite(c))   {
      c = ' ';
      k = 1;
    }

    if (z0 == 0) {
      if (k && !p0 && reslen < MAXWLEN && c != NUL
          && (!slang->sl_collapse || reslen == 0
              || res[reslen - 1] != c))
        /* condense only double letters */
        res[reslen++] = c;

      i++;
      z = 0;
      k = 0;
    }
  }

  res[reslen] = NUL;
}

/*
 * Turn "inword" into its sound-a-like equivalent in "res[MAXWLEN]".
 * Multi-byte version of spell_soundfold().
 */
static void spell_soundfold_wsal(slang_T *slang, char_u *inword, char_u *res)
{
  salitem_T   *smp = (salitem_T *)slang->sl_sal.ga_data;
  int word[MAXWLEN];
  int wres[MAXWLEN];
  int l;
  char_u      *s;
  int         *ws;
  char_u      *t;
  int         *pf;
  int i, j, z;
  int reslen;
  int n, k = 0;
  int z0;
  int k0;
  int n0;
  int c;
  int pri;
  int p0 = -333;
  int c0;
  int did_white = FALSE;
  int wordlen;


  /*
   * Convert the multi-byte string to a wide-character string.
   * Remove accents, if wanted.  We actually remove all non-word characters.
   * But keep white space.
   */
  wordlen = 0;
  for (s = inword; *s != NUL; ) {
    t = s;
    c = mb_cptr2char_adv(&s);
    if (slang->sl_rem_accents) {
      if (enc_utf8 ? utf_class(c) == 0 : vim_iswhite(c)) {
        if (did_white)
          continue;
        c = ' ';
        did_white = TRUE;
      } else   {
        did_white = FALSE;
        if (!spell_iswordp_nmw(t, curwin))
          continue;
      }
    }
    word[wordlen++] = c;
  }
  word[wordlen] = NUL;

  /*
   * This algorithm comes from Aspell phonet.cpp.
   * Converted from C++ to C.  Added support for multi-byte chars.
   * Changed to keep spaces.
   */
  i = reslen = z = 0;
  while ((c = word[i]) != NUL) {
    /* Start with the first rule that has the character in the word. */
    n = slang->sl_sal_first[c & 0xff];
    z0 = 0;

    if (n >= 0) {
      /* Check all rules for the same index byte.
       * If c is 0x300 need extra check for the end of the array, as
       * (c & 0xff) is NUL. */
      for (; ((ws = smp[n].sm_lead_w)[0] & 0xff) == (c & 0xff)
           && ws[0] != NUL; ++n) {
        /* Quickly skip entries that don't match the word.  Most
         * entries are less then three chars, optimize for that. */
        if (c != ws[0])
          continue;
        k = smp[n].sm_leadlen;
        if (k > 1) {
          if (word[i + 1] != ws[1])
            continue;
          if (k > 2) {
            for (j = 2; j < k; ++j)
              if (word[i + j] != ws[j])
                break;
            if (j < k)
              continue;
          }
        }

        if ((pf = smp[n].sm_oneof_w) != NULL) {
          /* Check for match with one of the chars in "sm_oneof". */
          while (*pf != NUL && *pf != word[i + k])
            ++pf;
          if (*pf == NUL)
            continue;
          ++k;
        }
        s = smp[n].sm_rules;
        pri = 5;            /* default priority */

        p0 = *s;
        k0 = k;
        while (*s == '-' && k > 1) {
          k--;
          s++;
        }
        if (*s == '<')
          s++;
        if (VIM_ISDIGIT(*s)) {
          /* determine priority */
          pri = *s - '0';
          s++;
        }
        if (*s == '^' && *(s + 1) == '^')
          s++;

        if (*s == NUL
            || (*s == '^'
                && (i == 0 || !(word[i - 1] == ' '
                                || spell_iswordp_w(word + i - 1, curwin)))
                && (*(s + 1) != '$'
                    || (!spell_iswordp_w(word + i + k0, curwin))))
            || (*s == '$' && i > 0
                && spell_iswordp_w(word + i - 1, curwin)
                && (!spell_iswordp_w(word + i + k0, curwin)))) {
          /* search for followup rules, if:    */
          /* followup and k > 1  and  NO '-' in searchstring */
          c0 = word[i + k - 1];
          n0 = slang->sl_sal_first[c0 & 0xff];

          if (slang->sl_followup && k > 1 && n0 >= 0
              && p0 != '-' && word[i + k] != NUL) {
            /* Test follow-up rule for "word[i + k]"; loop over
             * all entries with the same index byte. */
            for (; ((ws = smp[n0].sm_lead_w)[0] & 0xff)
                 == (c0 & 0xff); ++n0) {
              /* Quickly skip entries that don't match the word.
               */
              if (c0 != ws[0])
                continue;
              k0 = smp[n0].sm_leadlen;
              if (k0 > 1) {
                if (word[i + k] != ws[1])
                  continue;
                if (k0 > 2) {
                  pf = word + i + k + 1;
                  for (j = 2; j < k0; ++j)
                    if (*pf++ != ws[j])
                      break;
                  if (j < k0)
                    continue;
                }
              }
              k0 += k - 1;

              if ((pf = smp[n0].sm_oneof_w) != NULL) {
                /* Check for match with one of the chars in
                 * "sm_oneof". */
                while (*pf != NUL && *pf != word[i + k0])
                  ++pf;
                if (*pf == NUL)
                  continue;
                ++k0;
              }

              p0 = 5;
              s = smp[n0].sm_rules;
              while (*s == '-') {
                /* "k0" gets NOT reduced because
                 * "if (k0 == k)" */
                s++;
              }
              if (*s == '<')
                s++;
              if (VIM_ISDIGIT(*s)) {
                p0 = *s - '0';
                s++;
              }

              if (*s == NUL
                  /* *s == '^' cuts */
                  || (*s == '$'
                      && !spell_iswordp_w(word + i + k0,
                          curwin))) {
                if (k0 == k)
                  /* this is just a piece of the string */
                  continue;

                if (p0 < pri)
                  /* priority too low */
                  continue;
                /* rule fits; stop search */
                break;
              }
            }

            if (p0 >= pri && (smp[n0].sm_lead_w[0] & 0xff)
                == (c0 & 0xff))
              continue;
          }

          /* replace string */
          ws = smp[n].sm_to_w;
          s = smp[n].sm_rules;
          p0 = (vim_strchr(s, '<') != NULL) ? 1 : 0;
          if (p0 == 1 && z == 0) {
            /* rule with '<' is used */
            if (reslen > 0 && ws != NULL && *ws != NUL
                && (wres[reslen - 1] == c
                    || wres[reslen - 1] == *ws))
              reslen--;
            z0 = 1;
            z = 1;
            k0 = 0;
            if (ws != NULL)
              while (*ws != NUL && word[i + k0] != NUL) {
                word[i + k0] = *ws;
                k0++;
                ws++;
              }
            if (k > k0)
              mch_memmove(word + i + k0, word + i + k,
                  sizeof(int) * (wordlen - (i + k) + 1));

            /* new "actual letter" */
            c = word[i];
          } else   {
            /* no '<' rule used */
            i += k - 1;
            z = 0;
            if (ws != NULL)
              while (*ws != NUL && ws[1] != NUL
                     && reslen < MAXWLEN) {
                if (reslen == 0 || wres[reslen - 1] != *ws)
                  wres[reslen++] = *ws;
                ws++;
              }
            /* new "actual letter" */
            if (ws == NULL)
              c = NUL;
            else
              c = *ws;
            if (strstr((char *)s, "^^") != NULL) {
              if (c != NUL)
                wres[reslen++] = c;
              mch_memmove(word, word + i + 1,
                  sizeof(int) * (wordlen - (i + 1) + 1));
              i = 0;
              z0 = 1;
            }
          }
          break;
        }
      }
    } else if (vim_iswhite(c))   {
      c = ' ';
      k = 1;
    }

    if (z0 == 0) {
      if (k && !p0 && reslen < MAXWLEN && c != NUL
          && (!slang->sl_collapse || reslen == 0
              || wres[reslen - 1] != c))
        /* condense only double letters */
        wres[reslen++] = c;

      i++;
      z = 0;
      k = 0;
    }
  }

  /* Convert wide characters in "wres" to a multi-byte string in "res". */
  l = 0;
  for (n = 0; n < reslen; ++n) {
    l += mb_char2bytes(wres[n], res + l);
    if (l + MB_MAXBYTES > MAXWLEN)
      break;
  }
  res[l] = NUL;
}

/*
 * Compute a score for two sound-a-like words.
 * This permits up to two inserts/deletes/swaps/etc. to keep things fast.
 * Instead of a generic loop we write out the code.  That keeps it fast by
 * avoiding checks that will not be possible.
 */
static int 
soundalike_score (
    char_u *goodstart,         /* sound-folded good word */
    char_u *badstart          /* sound-folded bad word */
)
{
  char_u      *goodsound = goodstart;
  char_u      *badsound = badstart;
  int goodlen;
  int badlen;
  int n;
  char_u      *pl, *ps;
  char_u      *pl2, *ps2;
  int score = 0;

  /* Adding/inserting "*" at the start (word starts with vowel) shouldn't be
   * counted so much, vowels halfway the word aren't counted at all. */
  if ((*badsound == '*' || *goodsound == '*') && *badsound != *goodsound) {
    if ((badsound[0] == NUL && goodsound[1] == NUL)
        || (goodsound[0] == NUL && badsound[1] == NUL))
      /* changing word with vowel to word without a sound */
      return SCORE_DEL;
    if (badsound[0] == NUL || goodsound[0] == NUL)
      /* more than two changes */
      return SCORE_MAXMAX;

    if (badsound[1] == goodsound[1]
        || (badsound[1] != NUL
            && goodsound[1] != NUL
            && badsound[2] == goodsound[2])) {
      /* handle like a substitute */
    } else   {
      score = 2 * SCORE_DEL / 3;
      if (*badsound == '*')
        ++badsound;
      else
        ++goodsound;
    }
  }

  goodlen = (int)STRLEN(goodsound);
  badlen = (int)STRLEN(badsound);

  /* Return quickly if the lengths are too different to be fixed by two
   * changes. */
  n = goodlen - badlen;
  if (n < -2 || n > 2)
    return SCORE_MAXMAX;

  if (n > 0) {
    pl = goodsound;         /* goodsound is longest */
    ps = badsound;
  } else   {
    pl = badsound;          /* badsound is longest */
    ps = goodsound;
  }

  /* Skip over the identical part. */
  while (*pl == *ps && *pl != NUL) {
    ++pl;
    ++ps;
  }

  switch (n) {
  case -2:
  case 2:
    /*
     * Must delete two characters from "pl".
     */
    ++pl;               /* first delete */
    while (*pl == *ps) {
      ++pl;
      ++ps;
    }
    /* strings must be equal after second delete */
    if (STRCMP(pl + 1, ps) == 0)
      return score + SCORE_DEL * 2;

    /* Failed to compare. */
    break;

  case -1:
  case 1:
    /*
     * Minimal one delete from "pl" required.
     */

    /* 1: delete */
    pl2 = pl + 1;
    ps2 = ps;
    while (*pl2 == *ps2) {
      if (*pl2 == NUL)                  /* reached the end */
        return score + SCORE_DEL;
      ++pl2;
      ++ps2;
    }

    /* 2: delete then swap, then rest must be equal */
    if (pl2[0] == ps2[1] && pl2[1] == ps2[0]
        && STRCMP(pl2 + 2, ps2 + 2) == 0)
      return score + SCORE_DEL + SCORE_SWAP;

    /* 3: delete then substitute, then the rest must be equal */
    if (STRCMP(pl2 + 1, ps2 + 1) == 0)
      return score + SCORE_DEL + SCORE_SUBST;

    /* 4: first swap then delete */
    if (pl[0] == ps[1] && pl[1] == ps[0]) {
      pl2 = pl + 2;                 /* swap, skip two chars */
      ps2 = ps + 2;
      while (*pl2 == *ps2) {
        ++pl2;
        ++ps2;
      }
      /* delete a char and then strings must be equal */
      if (STRCMP(pl2 + 1, ps2) == 0)
        return score + SCORE_SWAP + SCORE_DEL;
    }

    /* 5: first substitute then delete */
    pl2 = pl + 1;                   /* substitute, skip one char */
    ps2 = ps + 1;
    while (*pl2 == *ps2) {
      ++pl2;
      ++ps2;
    }
    /* delete a char and then strings must be equal */
    if (STRCMP(pl2 + 1, ps2) == 0)
      return score + SCORE_SUBST + SCORE_DEL;

    /* Failed to compare. */
    break;

  case 0:
    /*
     * Lengths are equal, thus changes must result in same length: An
     * insert is only possible in combination with a delete.
     * 1: check if for identical strings
     */
    if (*pl == NUL)
      return score;

    /* 2: swap */
    if (pl[0] == ps[1] && pl[1] == ps[0]) {
      pl2 = pl + 2;                 /* swap, skip two chars */
      ps2 = ps + 2;
      while (*pl2 == *ps2) {
        if (*pl2 == NUL)                /* reached the end */
          return score + SCORE_SWAP;
        ++pl2;
        ++ps2;
      }
      /* 3: swap and swap again */
      if (pl2[0] == ps2[1] && pl2[1] == ps2[0]
          && STRCMP(pl2 + 2, ps2 + 2) == 0)
        return score + SCORE_SWAP + SCORE_SWAP;

      /* 4: swap and substitute */
      if (STRCMP(pl2 + 1, ps2 + 1) == 0)
        return score + SCORE_SWAP + SCORE_SUBST;
    }

    /* 5: substitute */
    pl2 = pl + 1;
    ps2 = ps + 1;
    while (*pl2 == *ps2) {
      if (*pl2 == NUL)                  /* reached the end */
        return score + SCORE_SUBST;
      ++pl2;
      ++ps2;
    }

    /* 6: substitute and swap */
    if (pl2[0] == ps2[1] && pl2[1] == ps2[0]
        && STRCMP(pl2 + 2, ps2 + 2) == 0)
      return score + SCORE_SUBST + SCORE_SWAP;

    /* 7: substitute and substitute */
    if (STRCMP(pl2 + 1, ps2 + 1) == 0)
      return score + SCORE_SUBST + SCORE_SUBST;

    /* 8: insert then delete */
    pl2 = pl;
    ps2 = ps + 1;
    while (*pl2 == *ps2) {
      ++pl2;
      ++ps2;
    }
    if (STRCMP(pl2 + 1, ps2) == 0)
      return score + SCORE_INS + SCORE_DEL;

    /* 9: delete then insert */
    pl2 = pl + 1;
    ps2 = ps;
    while (*pl2 == *ps2) {
      ++pl2;
      ++ps2;
    }
    if (STRCMP(pl2, ps2 + 1) == 0)
      return score + SCORE_INS + SCORE_DEL;

    /* Failed to compare. */
    break;
  }

  return SCORE_MAXMAX;
}

/*
 * Compute the "edit distance" to turn "badword" into "goodword".  The less
 * deletes/inserts/substitutes/swaps are required the lower the score.
 *
 * The algorithm is described by Du and Chang, 1992.
 * The implementation of the algorithm comes from Aspell editdist.cpp,
 * edit_distance().  It has been converted from C++ to C and modified to
 * support multi-byte characters.
 */
static int spell_edit_score(slang_T *slang, char_u *badword, char_u *goodword)
{
  int         *cnt;
  int badlen, goodlen;                  /* lengths including NUL */
  int j, i;
  int t;
  int bc, gc;
  int pbc, pgc;
  char_u      *p;
  int wbadword[MAXWLEN];
  int wgoodword[MAXWLEN];

  if (has_mbyte) {
    /* Get the characters from the multi-byte strings and put them in an
     * int array for easy access. */
    for (p = badword, badlen = 0; *p != NUL; )
      wbadword[badlen++] = mb_cptr2char_adv(&p);
    wbadword[badlen++] = 0;
    for (p = goodword, goodlen = 0; *p != NUL; )
      wgoodword[goodlen++] = mb_cptr2char_adv(&p);
    wgoodword[goodlen++] = 0;
  } else   {
    badlen = (int)STRLEN(badword) + 1;
    goodlen = (int)STRLEN(goodword) + 1;
  }

  /* We use "cnt" as an array: CNT(badword_idx, goodword_idx). */
#define CNT(a, b)   cnt[(a) + (b) * (badlen + 1)]
  cnt = (int *)lalloc((long_u)(sizeof(int) * (badlen + 1) * (goodlen + 1)),
      TRUE);
  if (cnt == NULL)
    return 0;           /* out of memory */

  CNT(0, 0) = 0;
  for (j = 1; j <= goodlen; ++j)
    CNT(0, j) = CNT(0, j - 1) + SCORE_INS;

  for (i = 1; i <= badlen; ++i) {
    CNT(i, 0) = CNT(i - 1, 0) + SCORE_DEL;
    for (j = 1; j <= goodlen; ++j) {
      if (has_mbyte) {
        bc = wbadword[i - 1];
        gc = wgoodword[j - 1];
      } else   {
        bc = badword[i - 1];
        gc = goodword[j - 1];
      }
      if (bc == gc)
        CNT(i, j) = CNT(i - 1, j - 1);
      else {
        /* Use a better score when there is only a case difference. */
        if (SPELL_TOFOLD(bc) == SPELL_TOFOLD(gc))
          CNT(i, j) = SCORE_ICASE + CNT(i - 1, j - 1);
        else {
          /* For a similar character use SCORE_SIMILAR. */
          if (slang != NULL
              && slang->sl_has_map
              && similar_chars(slang, gc, bc))
            CNT(i, j) = SCORE_SIMILAR + CNT(i - 1, j - 1);
          else
            CNT(i, j) = SCORE_SUBST + CNT(i - 1, j - 1);
        }

        if (i > 1 && j > 1) {
          if (has_mbyte) {
            pbc = wbadword[i - 2];
            pgc = wgoodword[j - 2];
          } else   {
            pbc = badword[i - 2];
            pgc = goodword[j - 2];
          }
          if (bc == pgc && pbc == gc) {
            t = SCORE_SWAP + CNT(i - 2, j - 2);
            if (t < CNT(i, j))
              CNT(i, j) = t;
          }
        }
        t = SCORE_DEL + CNT(i - 1, j);
        if (t < CNT(i, j))
          CNT(i, j) = t;
        t = SCORE_INS + CNT(i, j - 1);
        if (t < CNT(i, j))
          CNT(i, j) = t;
      }
    }
  }

  i = CNT(badlen - 1, goodlen - 1);
  vim_free(cnt);
  return i;
}

typedef struct {
  int badi;
  int goodi;
  int score;
} limitscore_T;

/*
 * Like spell_edit_score(), but with a limit on the score to make it faster.
 * May return SCORE_MAXMAX when the score is higher than "limit".
 *
 * This uses a stack for the edits still to be tried.
 * The idea comes from Aspell leditdist.cpp.  Rewritten in C and added support
 * for multi-byte characters.
 */
static int spell_edit_score_limit(slang_T *slang, char_u *badword, char_u *goodword, int limit)
{
  limitscore_T stack[10];               /* allow for over 3 * 2 edits */
  int stackidx;
  int bi, gi;
  int bi2, gi2;
  int bc, gc;
  int score;
  int score_off;
  int minscore;
  int round;

  /* Multi-byte characters require a bit more work, use a different function
   * to avoid testing "has_mbyte" quite often. */
  if (has_mbyte)
    return spell_edit_score_limit_w(slang, badword, goodword, limit);

  /*
   * The idea is to go from start to end over the words.  So long as
   * characters are equal just continue, this always gives the lowest score.
   * When there is a difference try several alternatives.  Each alternative
   * increases "score" for the edit distance.  Some of the alternatives are
   * pushed unto a stack and tried later, some are tried right away.  At the
   * end of the word the score for one alternative is known.  The lowest
   * possible score is stored in "minscore".
   */
  stackidx = 0;
  bi = 0;
  gi = 0;
  score = 0;
  minscore = limit + 1;

  for (;; ) {
    /* Skip over an equal part, score remains the same. */
    for (;; ) {
      bc = badword[bi];
      gc = goodword[gi];
      if (bc != gc)             /* stop at a char that's different */
        break;
      if (bc == NUL) {          /* both words end */
        if (score < minscore)
          minscore = score;
        goto pop;               /* do next alternative */
      }
      ++bi;
      ++gi;
    }

    if (gc == NUL) {      /* goodword ends, delete badword chars */
      do {
        if ((score += SCORE_DEL) >= minscore)
          goto pop;                 /* do next alternative */
      } while (badword[++bi] != NUL);
      minscore = score;
    } else if (bc == NUL)   { /* badword ends, insert badword chars */
      do {
        if ((score += SCORE_INS) >= minscore)
          goto pop;                 /* do next alternative */
      } while (goodword[++gi] != NUL);
      minscore = score;
    } else   {                  /* both words continue */
      /* If not close to the limit, perform a change.  Only try changes
       * that may lead to a lower score than "minscore".
       * round 0: try deleting a char from badword
       * round 1: try inserting a char in badword */
      for (round = 0; round <= 1; ++round) {
        score_off = score + (round == 0 ? SCORE_DEL : SCORE_INS);
        if (score_off < minscore) {
          if (score_off + SCORE_EDIT_MIN >= minscore) {
            /* Near the limit, rest of the words must match.  We
             * can check that right now, no need to push an item
             * onto the stack. */
            bi2 = bi + 1 - round;
            gi2 = gi + round;
            while (goodword[gi2] == badword[bi2]) {
              if (goodword[gi2] == NUL) {
                minscore = score_off;
                break;
              }
              ++bi2;
              ++gi2;
            }
          } else   {
            /* try deleting/inserting a character later */
            stack[stackidx].badi = bi + 1 - round;
            stack[stackidx].goodi = gi + round;
            stack[stackidx].score = score_off;
            ++stackidx;
          }
        }
      }

      if (score + SCORE_SWAP < minscore) {
        /* If swapping two characters makes a match then the
         * substitution is more expensive, thus there is no need to
         * try both. */
        if (gc == badword[bi + 1] && bc == goodword[gi + 1]) {
          /* Swap two characters, that is: skip them. */
          gi += 2;
          bi += 2;
          score += SCORE_SWAP;
          continue;
        }
      }

      /* Substitute one character for another which is the same
       * thing as deleting a character from both goodword and badword.
       * Use a better score when there is only a case difference. */
      if (SPELL_TOFOLD(bc) == SPELL_TOFOLD(gc))
        score += SCORE_ICASE;
      else {
        /* For a similar character use SCORE_SIMILAR. */
        if (slang != NULL
            && slang->sl_has_map
            && similar_chars(slang, gc, bc))
          score += SCORE_SIMILAR;
        else
          score += SCORE_SUBST;
      }

      if (score < minscore) {
        /* Do the substitution. */
        ++gi;
        ++bi;
        continue;
      }
    }
pop:
    /*
     * Get here to try the next alternative, pop it from the stack.
     */
    if (stackidx == 0)                  /* stack is empty, finished */
      break;

    /* pop an item from the stack */
    --stackidx;
    gi = stack[stackidx].goodi;
    bi = stack[stackidx].badi;
    score = stack[stackidx].score;
  }

  /* When the score goes over "limit" it may actually be much higher.
   * Return a very large number to avoid going below the limit when giving a
   * bonus. */
  if (minscore > limit)
    return SCORE_MAXMAX;
  return minscore;
}

/*
 * Multi-byte version of spell_edit_score_limit().
 * Keep it in sync with the above!
 */
static int spell_edit_score_limit_w(slang_T *slang, char_u *badword, char_u *goodword, int limit)
{
  limitscore_T stack[10];               /* allow for over 3 * 2 edits */
  int stackidx;
  int bi, gi;
  int bi2, gi2;
  int bc, gc;
  int score;
  int score_off;
  int minscore;
  int round;
  char_u          *p;
  int wbadword[MAXWLEN];
  int wgoodword[MAXWLEN];

  /* Get the characters from the multi-byte strings and put them in an
   * int array for easy access. */
  bi = 0;
  for (p = badword; *p != NUL; )
    wbadword[bi++] = mb_cptr2char_adv(&p);
  wbadword[bi++] = 0;
  gi = 0;
  for (p = goodword; *p != NUL; )
    wgoodword[gi++] = mb_cptr2char_adv(&p);
  wgoodword[gi++] = 0;

  /*
   * The idea is to go from start to end over the words.  So long as
   * characters are equal just continue, this always gives the lowest score.
   * When there is a difference try several alternatives.  Each alternative
   * increases "score" for the edit distance.  Some of the alternatives are
   * pushed unto a stack and tried later, some are tried right away.  At the
   * end of the word the score for one alternative is known.  The lowest
   * possible score is stored in "minscore".
   */
  stackidx = 0;
  bi = 0;
  gi = 0;
  score = 0;
  minscore = limit + 1;

  for (;; ) {
    /* Skip over an equal part, score remains the same. */
    for (;; ) {
      bc = wbadword[bi];
      gc = wgoodword[gi];

      if (bc != gc)             /* stop at a char that's different */
        break;
      if (bc == NUL) {          /* both words end */
        if (score < minscore)
          minscore = score;
        goto pop;               /* do next alternative */
      }
      ++bi;
      ++gi;
    }

    if (gc == NUL) {      /* goodword ends, delete badword chars */
      do {
        if ((score += SCORE_DEL) >= minscore)
          goto pop;                 /* do next alternative */
      } while (wbadword[++bi] != NUL);
      minscore = score;
    } else if (bc == NUL)   { /* badword ends, insert badword chars */
      do {
        if ((score += SCORE_INS) >= minscore)
          goto pop;                 /* do next alternative */
      } while (wgoodword[++gi] != NUL);
      minscore = score;
    } else   {                  /* both words continue */
      /* If not close to the limit, perform a change.  Only try changes
       * that may lead to a lower score than "minscore".
       * round 0: try deleting a char from badword
       * round 1: try inserting a char in badword */
      for (round = 0; round <= 1; ++round) {
        score_off = score + (round == 0 ? SCORE_DEL : SCORE_INS);
        if (score_off < minscore) {
          if (score_off + SCORE_EDIT_MIN >= minscore) {
            /* Near the limit, rest of the words must match.  We
             * can check that right now, no need to push an item
             * onto the stack. */
            bi2 = bi + 1 - round;
            gi2 = gi + round;
            while (wgoodword[gi2] == wbadword[bi2]) {
              if (wgoodword[gi2] == NUL) {
                minscore = score_off;
                break;
              }
              ++bi2;
              ++gi2;
            }
          } else   {
            /* try deleting a character from badword later */
            stack[stackidx].badi = bi + 1 - round;
            stack[stackidx].goodi = gi + round;
            stack[stackidx].score = score_off;
            ++stackidx;
          }
        }
      }

      if (score + SCORE_SWAP < minscore) {
        /* If swapping two characters makes a match then the
         * substitution is more expensive, thus there is no need to
         * try both. */
        if (gc == wbadword[bi + 1] && bc == wgoodword[gi + 1]) {
          /* Swap two characters, that is: skip them. */
          gi += 2;
          bi += 2;
          score += SCORE_SWAP;
          continue;
        }
      }

      /* Substitute one character for another which is the same
       * thing as deleting a character from both goodword and badword.
       * Use a better score when there is only a case difference. */
      if (SPELL_TOFOLD(bc) == SPELL_TOFOLD(gc))
        score += SCORE_ICASE;
      else {
        /* For a similar character use SCORE_SIMILAR. */
        if (slang != NULL
            && slang->sl_has_map
            && similar_chars(slang, gc, bc))
          score += SCORE_SIMILAR;
        else
          score += SCORE_SUBST;
      }

      if (score < minscore) {
        /* Do the substitution. */
        ++gi;
        ++bi;
        continue;
      }
    }
pop:
    /*
     * Get here to try the next alternative, pop it from the stack.
     */
    if (stackidx == 0)                  /* stack is empty, finished */
      break;

    /* pop an item from the stack */
    --stackidx;
    gi = stack[stackidx].goodi;
    bi = stack[stackidx].badi;
    score = stack[stackidx].score;
  }

  /* When the score goes over "limit" it may actually be much higher.
   * Return a very large number to avoid going below the limit when giving a
   * bonus. */
  if (minscore > limit)
    return SCORE_MAXMAX;
  return minscore;
}

/*
 * ":spellinfo"
 */
void ex_spellinfo(exarg_T *eap)
{
  int lpi;
  langp_T     *lp;
  char_u      *p;

  if (no_spell_checking(curwin))
    return;

  msg_start();
  for (lpi = 0; lpi < curwin->w_s->b_langp.ga_len && !got_int; ++lpi) {
    lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    msg_puts((char_u *)"file: ");
    msg_puts(lp->lp_slang->sl_fname);
    msg_putchar('\n');
    p = lp->lp_slang->sl_info;
    if (p != NULL) {
      msg_puts(p);
      msg_putchar('\n');
    }
  }
  msg_end();
}

#define DUMPFLAG_KEEPCASE   1   /* round 2: keep-case tree */
#define DUMPFLAG_COUNT      2   /* include word count */
#define DUMPFLAG_ICASE      4   /* ignore case when finding matches */
#define DUMPFLAG_ONECAP     8   /* pattern starts with capital */
#define DUMPFLAG_ALLCAP     16  /* pattern is all capitals */

/*
 * ":spelldump"
 */
void ex_spelldump(exarg_T *eap)
{
  char_u  *spl;
  long dummy;

  if (no_spell_checking(curwin))
    return;
  get_option_value((char_u*)"spl", &dummy, &spl, OPT_LOCAL);

  /* Create a new empty buffer in a new window. */
  do_cmdline_cmd((char_u *)"new");

  /* enable spelling locally in the new window */
  set_option_value((char_u*)"spell", TRUE, (char_u*)"", OPT_LOCAL);
  set_option_value((char_u*)"spl",  dummy,         spl, OPT_LOCAL);
  vim_free(spl);

  if (!bufempty() || !buf_valid(curbuf))
    return;

  spell_dump_compl(NULL, 0, NULL, eap->forceit ? DUMPFLAG_COUNT : 0);

  /* Delete the empty line that we started with. */
  if (curbuf->b_ml.ml_line_count > 1)
    ml_delete(curbuf->b_ml.ml_line_count, FALSE);

  redraw_later(NOT_VALID);
}

/*
 * Go through all possible words and:
 * 1. When "pat" is NULL: dump a list of all words in the current buffer.
 *	"ic" and "dir" are not used.
 * 2. When "pat" is not NULL: add matching words to insert mode completion.
 */
void 
spell_dump_compl (
    char_u *pat,           /* leading part of the word */
    int ic,                     /* ignore case */
    int *dir,           /* direction for adding matches */
    int dumpflags_arg              /* DUMPFLAG_* */
)
{
  langp_T     *lp;
  slang_T     *slang;
  idx_T arridx[MAXWLEN];
  int curi[MAXWLEN];
  char_u word[MAXWLEN];
  int c;
  char_u      *byts;
  idx_T       *idxs;
  linenr_T lnum = 0;
  int round;
  int depth;
  int n;
  int flags;
  char_u      *region_names = NULL;         /* region names being used */
  int do_region = TRUE;                     /* dump region names and numbers */
  char_u      *p;
  int lpi;
  int dumpflags = dumpflags_arg;
  int patlen;

  /* When ignoring case or when the pattern starts with capital pass this on
   * to dump_word(). */
  if (pat != NULL) {
    if (ic)
      dumpflags |= DUMPFLAG_ICASE;
    else {
      n = captype(pat, NULL);
      if (n == WF_ONECAP)
        dumpflags |= DUMPFLAG_ONECAP;
      else if (n == WF_ALLCAP
               && (int)STRLEN(pat) > mb_ptr2len(pat)
               )
        dumpflags |= DUMPFLAG_ALLCAP;
    }
  }

  /* Find out if we can support regions: All languages must support the same
   * regions or none at all. */
  for (lpi = 0; lpi < curwin->w_s->b_langp.ga_len; ++lpi) {
    lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    p = lp->lp_slang->sl_regions;
    if (p[0] != 0) {
      if (region_names == NULL)             /* first language with regions */
        region_names = p;
      else if (STRCMP(region_names, p) != 0) {
        do_region = FALSE;                  /* region names are different */
        break;
      }
    }
  }

  if (do_region && region_names != NULL) {
    if (pat == NULL) {
      vim_snprintf((char *)IObuff, IOSIZE, "/regions=%s", region_names);
      ml_append(lnum++, IObuff, (colnr_T)0, FALSE);
    }
  } else
    do_region = FALSE;

  /*
   * Loop over all files loaded for the entries in 'spelllang'.
   */
  for (lpi = 0; lpi < curwin->w_s->b_langp.ga_len; ++lpi) {
    lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    slang = lp->lp_slang;
    if (slang->sl_fbyts == NULL)            /* reloading failed */
      continue;

    if (pat == NULL) {
      vim_snprintf((char *)IObuff, IOSIZE, "# file: %s", slang->sl_fname);
      ml_append(lnum++, IObuff, (colnr_T)0, FALSE);
    }

    /* When matching with a pattern and there are no prefixes only use
     * parts of the tree that match "pat". */
    if (pat != NULL && slang->sl_pbyts == NULL)
      patlen = (int)STRLEN(pat);
    else
      patlen = -1;

    /* round 1: case-folded tree
    * round 2: keep-case tree */
    for (round = 1; round <= 2; ++round) {
      if (round == 1) {
        dumpflags &= ~DUMPFLAG_KEEPCASE;
        byts = slang->sl_fbyts;
        idxs = slang->sl_fidxs;
      } else   {
        dumpflags |= DUMPFLAG_KEEPCASE;
        byts = slang->sl_kbyts;
        idxs = slang->sl_kidxs;
      }
      if (byts == NULL)
        continue;                       /* array is empty */

      depth = 0;
      arridx[0] = 0;
      curi[0] = 1;
      while (depth >= 0 && !got_int
             && (pat == NULL || !compl_interrupted)) {
        if (curi[depth] > byts[arridx[depth]]) {
          /* Done all bytes at this node, go up one level. */
          --depth;
          line_breakcheck();
          ins_compl_check_keys(50);
        } else   {
          /* Do one more byte at this node. */
          n = arridx[depth] + curi[depth];
          ++curi[depth];
          c = byts[n];
          if (c == 0) {
            /* End of word, deal with the word.
             * Don't use keep-case words in the fold-case tree,
             * they will appear in the keep-case tree.
             * Only use the word when the region matches. */
            flags = (int)idxs[n];
            if ((round == 2 || (flags & WF_KEEPCAP) == 0)
                && (flags & WF_NEEDCOMP) == 0
                && (do_region
                    || (flags & WF_REGION) == 0
                    || (((unsigned)flags >> 16)
                        & lp->lp_region) != 0)) {
              word[depth] = NUL;
              if (!do_region)
                flags &= ~WF_REGION;

              /* Dump the basic word if there is no prefix or
               * when it's the first one. */
              c = (unsigned)flags >> 24;
              if (c == 0 || curi[depth] == 2) {
                dump_word(slang, word, pat, dir,
                    dumpflags, flags, lnum);
                if (pat == NULL)
                  ++lnum;
              }

              /* Apply the prefix, if there is one. */
              if (c != 0)
                lnum = dump_prefixes(slang, word, pat, dir,
                    dumpflags, flags, lnum);
            }
          } else   {
            /* Normal char, go one level deeper. */
            word[depth++] = c;
            arridx[depth] = idxs[n];
            curi[depth] = 1;

            /* Check if this characters matches with the pattern.
             * If not skip the whole tree below it.
             * Always ignore case here, dump_word() will check
             * proper case later.  This isn't exactly right when
             * length changes for multi-byte characters with
             * ignore case... */
            if (depth <= patlen
                && MB_STRNICMP(word, pat, depth) != 0)
              --depth;
          }
        }
      }
    }
  }
}

/*
 * Dump one word: apply case modifications and append a line to the buffer.
 * When "lnum" is zero add insert mode completion.
 */
static void dump_word(slang_T *slang, char_u *word, char_u *pat, int *dir, int dumpflags, int wordflags, linenr_T lnum)
{
  int keepcap = FALSE;
  char_u      *p;
  char_u      *tw;
  char_u cword[MAXWLEN];
  char_u badword[MAXWLEN + 10];
  int i;
  int flags = wordflags;

  if (dumpflags & DUMPFLAG_ONECAP)
    flags |= WF_ONECAP;
  if (dumpflags & DUMPFLAG_ALLCAP)
    flags |= WF_ALLCAP;

  if ((dumpflags & DUMPFLAG_KEEPCASE) == 0 && (flags & WF_CAPMASK) != 0) {
    /* Need to fix case according to "flags". */
    make_case_word(word, cword, flags);
    p = cword;
  } else   {
    p = word;
    if ((dumpflags & DUMPFLAG_KEEPCASE)
        && ((captype(word, NULL) & WF_KEEPCAP) == 0
            || (flags & WF_FIXCAP) != 0))
      keepcap = TRUE;
  }
  tw = p;

  if (pat == NULL) {
    /* Add flags and regions after a slash. */
    if ((flags & (WF_BANNED | WF_RARE | WF_REGION)) || keepcap) {
      STRCPY(badword, p);
      STRCAT(badword, "/");
      if (keepcap)
        STRCAT(badword, "=");
      if (flags & WF_BANNED)
        STRCAT(badword, "!");
      else if (flags & WF_RARE)
        STRCAT(badword, "?");
      if (flags & WF_REGION)
        for (i = 0; i < 7; ++i)
          if (flags & (0x10000 << i))
            sprintf((char *)badword + STRLEN(badword), "%d", i + 1);
      p = badword;
    }

    if (dumpflags & DUMPFLAG_COUNT) {
      hashitem_T  *hi;

      /* Include the word count for ":spelldump!". */
      hi = hash_find(&slang->sl_wordcount, tw);
      if (!HASHITEM_EMPTY(hi)) {
        vim_snprintf((char *)IObuff, IOSIZE, "%s\t%d",
            tw, HI2WC(hi)->wc_count);
        p = IObuff;
      }
    }

    ml_append(lnum, p, (colnr_T)0, FALSE);
  } else if (((dumpflags & DUMPFLAG_ICASE)
              ? MB_STRNICMP(p, pat, STRLEN(pat)) == 0
              : STRNCMP(p, pat, STRLEN(pat)) == 0)
             && ins_compl_add_infercase(p, (int)STRLEN(p),
                 p_ic, NULL, *dir, 0) == OK)
    /* if dir was BACKWARD then honor it just once */
    *dir = FORWARD;
}

/*
 * For ":spelldump": Find matching prefixes for "word".  Prepend each to
 * "word" and append a line to the buffer.
 * When "lnum" is zero add insert mode completion.
 * Return the updated line number.
 */
static linenr_T 
dump_prefixes (
    slang_T *slang,
    char_u *word,          /* case-folded word */
    char_u *pat,
    int *dir,
    int dumpflags,
    int flags,                  /* flags with prefix ID */
    linenr_T startlnum
)
{
  idx_T arridx[MAXWLEN];
  int curi[MAXWLEN];
  char_u prefix[MAXWLEN];
  char_u word_up[MAXWLEN];
  int has_word_up = FALSE;
  int c;
  char_u      *byts;
  idx_T       *idxs;
  linenr_T lnum = startlnum;
  int depth;
  int n;
  int len;
  int i;

  /* If the word starts with a lower-case letter make the word with an
   * upper-case letter in word_up[]. */
  c = PTR2CHAR(word);
  if (SPELL_TOUPPER(c) != c) {
    onecap_copy(word, word_up, TRUE);
    has_word_up = TRUE;
  }

  byts = slang->sl_pbyts;
  idxs = slang->sl_pidxs;
  if (byts != NULL) {           /* array not is empty */
    /*
     * Loop over all prefixes, building them byte-by-byte in prefix[].
     * When at the end of a prefix check that it supports "flags".
     */
    depth = 0;
    arridx[0] = 0;
    curi[0] = 1;
    while (depth >= 0 && !got_int) {
      n = arridx[depth];
      len = byts[n];
      if (curi[depth] > len) {
        /* Done all bytes at this node, go up one level. */
        --depth;
        line_breakcheck();
      } else   {
        /* Do one more byte at this node. */
        n += curi[depth];
        ++curi[depth];
        c = byts[n];
        if (c == 0) {
          /* End of prefix, find out how many IDs there are. */
          for (i = 1; i < len; ++i)
            if (byts[n + i] != 0)
              break;
          curi[depth] += i - 1;

          c = valid_word_prefix(i, n, flags, word, slang, FALSE);
          if (c != 0) {
            vim_strncpy(prefix + depth, word, MAXWLEN - depth - 1);
            dump_word(slang, prefix, pat, dir, dumpflags,
                (c & WF_RAREPFX) ? (flags | WF_RARE)
                : flags, lnum);
            if (lnum != 0)
              ++lnum;
          }

          /* Check for prefix that matches the word when the
           * first letter is upper-case, but only if the prefix has
           * a condition. */
          if (has_word_up) {
            c = valid_word_prefix(i, n, flags, word_up, slang,
                TRUE);
            if (c != 0) {
              vim_strncpy(prefix + depth, word_up,
                  MAXWLEN - depth - 1);
              dump_word(slang, prefix, pat, dir, dumpflags,
                  (c & WF_RAREPFX) ? (flags | WF_RARE)
                  : flags, lnum);
              if (lnum != 0)
                ++lnum;
            }
          }
        } else   {
          /* Normal char, go one level deeper. */
          prefix[depth++] = c;
          arridx[depth] = idxs[n];
          curi[depth] = 1;
        }
      }
    }
  }

  return lnum;
}

/*
 * Move "p" to the end of word "start".
 * Uses the spell-checking word characters.
 */
char_u *spell_to_word_end(char_u *start, win_T *win)
{
  char_u  *p = start;

  while (*p != NUL && spell_iswordp(p, win))
    mb_ptr_adv(p);
  return p;
}

/*
 * For Insert mode completion CTRL-X s:
 * Find start of the word in front of column "startcol".
 * We don't check if it is badly spelled, with completion we can only change
 * the word in front of the cursor.
 * Returns the column number of the word.
 */
int spell_word_start(int startcol)
{
  char_u      *line;
  char_u      *p;
  int col = 0;

  if (no_spell_checking(curwin))
    return startcol;

  /* Find a word character before "startcol". */
  line = ml_get_curline();
  for (p = line + startcol; p > line; ) {
    mb_ptr_back(line, p);
    if (spell_iswordp_nmw(p, curwin))
      break;
  }

  /* Go back to start of the word. */
  while (p > line) {
    col = (int)(p - line);
    mb_ptr_back(line, p);
    if (!spell_iswordp(p, curwin))
      break;
    col = 0;
  }

  return col;
}

/*
 * Need to check for 'spellcapcheck' now, the word is removed before
 * expand_spelling() is called.  Therefore the ugly global variable.
 */
static int spell_expand_need_cap;

void spell_expand_check_cap(colnr_T col)
{
  spell_expand_need_cap = check_need_cap(curwin->w_cursor.lnum, col);
}

/*
 * Get list of spelling suggestions.
 * Used for Insert mode completion CTRL-X ?.
 * Returns the number of matches.  The matches are in "matchp[]", array of
 * allocated strings.
 */
int expand_spelling(linenr_T lnum, char_u *pat, char_u ***matchp)
{
  garray_T ga;

  spell_suggest_list(&ga, pat, 100, spell_expand_need_cap, TRUE);
  *matchp = ga.ga_data;
  return ga.ga_len;
}

