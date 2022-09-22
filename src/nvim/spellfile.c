// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// spellfile.c: code for reading and writing spell files.
//
// See spell.c for information about spell checking.

// Vim spell file format: <HEADER>
//                        <SECTIONS>
//                        <LWORDTREE>
//                        <KWORDTREE>
//                        <PREFIXTREE>
//
// <HEADER>: <fileID> <versionnr>
//
// <fileID>     8 bytes    "VIMspell"
// <versionnr>  1 byte      VIMSPELLVERSION
//
//
// Sections make it possible to add information to the .spl file without
// making it incompatible with previous versions.  There are two kinds of
// sections:
// 1. Not essential for correct spell checking.  E.g. for making suggestions.
//    These are skipped when not supported.
// 2. Optional information, but essential for spell checking when present.
//    E.g. conditions for affixes.  When this section is present but not
//    supported an error message is given.
//
// <SECTIONS>: <section> ... <sectionend>
//
// <section>: <sectionID> <sectionflags> <sectionlen> (section contents)
//
// <sectionID>    1 byte    number from 0 to 254 identifying the section
//
// <sectionflags> 1 byte    SNF_REQUIRED: this section is required for correct
//                                          spell checking
//
// <sectionlen>   4 bytes   length of section contents, MSB first
//
// <sectionend>   1 byte    SN_END
//
//
// sectionID == SN_INFO: <infotext>
// <infotext>    N bytes    free format text with spell file info (version,
//                          website, etc)
//
// sectionID == SN_REGION: <regionname> ...
// <regionname>  2 bytes    Up to MAXREGIONS region names: ca, au, etc.
//                          Lower case.
//                          First <regionname> is region 1.
//
// sectionID == SN_CHARFLAGS: <charflagslen> <charflags>
//                              <folcharslen> <folchars>
// <charflagslen> 1 byte    Number of bytes in <charflags> (should be 128).
// <charflags>  N bytes     List of flags (first one is for character 128):
//                          0x01  word character        CF_WORD
//                          0x02  upper-case character  CF_UPPER
// <folcharslen>  2 bytes   Number of bytes in <folchars>.
// <folchars>     N bytes   Folded characters, first one is for character 128.
//
// sectionID == SN_MIDWORD: <midword>
// <midword>     N bytes    Characters that are word characters only when used
//                          in the middle of a word.
//
// sectionID == SN_PREFCOND: <prefcondcnt> <prefcond> ...
// <prefcondcnt> 2 bytes    Number of <prefcond> items following.
// <prefcond> : <condlen> <condstr>
// <condlen>    1 byte      Length of <condstr>.
// <condstr>    N bytes     Condition for the prefix.
//
// sectionID == SN_REP: <repcount> <rep> ...
// <repcount>    2 bytes    number of <rep> items, MSB first.
// <rep> : <repfromlen> <repfrom> <reptolen> <repto>
// <repfromlen>  1 byte     length of <repfrom>
// <repfrom>     N bytes    "from" part of replacement
// <reptolen>    1 byte     length of <repto>
// <repto>       N bytes    "to" part of replacement
//
// sectionID == SN_REPSAL: <repcount> <rep> ...
//   just like SN_REP but for soundfolded words
//
// sectionID == SN_SAL: <salflags> <salcount> <sal> ...
// <salflags>    1 byte     flags for soundsalike conversion:
//                          SAL_F0LLOWUP
//                          SAL_COLLAPSE
//                          SAL_REM_ACCENTS
// <salcount>    2 bytes    number of <sal> items following
// <sal> : <salfromlen> <salfrom> <saltolen> <salto>
// <salfromlen>  1 byte     length of <salfrom>
// <salfrom>     N bytes    "from" part of soundsalike
// <saltolen>    1 byte     length of <salto>
// <salto>       N bytes    "to" part of soundsalike
//
// sectionID == SN_SOFO: <sofofromlen> <sofofrom> <sofotolen> <sofoto>
// <sofofromlen> 2 bytes    length of <sofofrom>
// <sofofrom>    N bytes    "from" part of soundfold
// <sofotolen>   2 bytes    length of <sofoto>
// <sofoto>      N bytes    "to" part of soundfold
//
// sectionID == SN_SUGFILE: <timestamp>
// <timestamp>   8 bytes    time in seconds that must match with .sug file
//
// sectionID == SN_NOSPLITSUGS: nothing
//
// sectionID == SN_NOCOMPOUNDSUGS: nothing
//
// sectionID == SN_WORDS: <word> ...
// <word>        N bytes    NUL terminated common word
//
// sectionID == SN_MAP: <mapstr>
// <mapstr>      N bytes    String with sequences of similar characters,
//                          separated by slashes.
//
// sectionID == SN_COMPOUND: <compmax> <compminlen> <compsylmax> <compoptions>
//                              <comppatcount> <comppattern> ... <compflags>
// <compmax>     1 byte     Maximum nr of words in compound word.
// <compminlen>  1 byte     Minimal word length for compounding.
// <compsylmax>  1 byte     Maximum nr of syllables in compound word.
// <compoptions> 2 bytes    COMP_ flags.
// <comppatcount> 2 bytes   number of <comppattern> following
// <compflags>   N bytes    Flags from COMPOUNDRULE items, separated by
//                          slashes.
//
// <comppattern>: <comppatlen> <comppattext>
// <comppatlen>  1 byte     length of <comppattext>
// <comppattext> N bytes    end or begin chars from CHECKCOMPOUNDPATTERN
//
// sectionID == SN_NOBREAK: (empty, its presence is what matters)
//
// sectionID == SN_SYLLABLE: <syllable>
// <syllable>    N bytes    String from SYLLABLE item.
//
// <LWORDTREE>: <wordtree>
//
// <KWORDTREE>: <wordtree>
//
// <PREFIXTREE>: <wordtree>
//
//
// <wordtree>: <nodecount> <nodedata> ...
//
// <nodecount>  4 bytes     Number of nodes following.  MSB first.
//
// <nodedata>: <siblingcount> <sibling> ...
//
// <siblingcount> 1 byte    Number of siblings in this node.  The siblings
//                          follow in sorted order.
//
// <sibling>: <byte> [ <nodeidx> <xbyte>
//                    | <flags> [<flags2>] [<region>] [<affixID>]
//                    | [<pflags>] <affixID> <prefcondnr> ]
//
// <byte>       1 byte      Byte value of the sibling.  Special cases:
//                          BY_NOFLAGS: End of word without flags and for all
//                                      regions.
//                                      For PREFIXTREE <affixID> and
//                                      <prefcondnr> follow.
//                          BY_FLAGS:   End of word, <flags> follow.
//                                      For PREFIXTREE <pflags>, <affixID>
//                                      and <prefcondnr> follow.
//                          BY_FLAGS2:  End of word, <flags> and <flags2>
//                                      follow.  Not used in PREFIXTREE.
//                          BY_INDEX:   Child of sibling is shared, <nodeidx>
//                                      and <xbyte> follow.
//
// <nodeidx>    3 bytes     Index of child for this sibling, MSB first.
//
// <xbyte>      1 byte      Byte value of the sibling.
//
// <flags>      1 byte      Bitmask of:
//                          WF_ALLCAP   word must have only capitals
//                          WF_ONECAP   first char of word must be capital
//                          WF_KEEPCAP  keep-case word
//                          WF_FIXCAP   keep-case word, all caps not allowed
//                          WF_RARE     rare word
//                          WF_BANNED   bad word
//                          WF_REGION   <region> follows
//                          WF_AFX      <affixID> follows
//
// <flags2>     1 byte      Bitmask of:
//                          WF_HAS_AFF >> 8   word includes affix
//                          WF_NEEDCOMP >> 8  word only valid in compound
//                          WF_NOSUGGEST >> 8  word not used for suggestions
//                          WF_COMPROOT >> 8  word already a compound
//                          WF_NOCOMPBEF >> 8 no compounding before this word
//                          WF_NOCOMPAFT >> 8 no compounding after this word
//
// <pflags>     1 byte      Bitmask of:
//                          WFP_RARE    rare prefix
//                          WFP_NC      non-combining prefix
//                          WFP_UP      letter after prefix made upper case
//
// <region>     1 byte      Bitmask for regions in which word is valid.  When
//                          omitted it's valid in all regions.
//                          Lowest bit is for region 1.
//
// <affixID>    1 byte      ID of affix that can be used with this word.  In
//                          PREFIXTREE used for the required prefix ID.
//
// <prefcondnr> 2 bytes     Prefix condition number, index in <prefcond> list
//                          from HEADER.
//
// All text characters are in 'encoding', but stored as single bytes.

// Vim .sug file format:  <SUGHEADER>
//                        <SUGWORDTREE>
//                        <SUGTABLE>
//
// <SUGHEADER>: <fileID> <versionnr> <timestamp>
//
// <fileID>     6 bytes     "VIMsug"
// <versionnr>  1 byte      VIMSUGVERSION
// <timestamp>  8 bytes     timestamp that must match with .spl file
//
//
// <SUGWORDTREE>: <wordtree>  (see above, no flags or region used)
//
//
// <SUGTABLE>: <sugwcount> <sugline> ...
//
// <sugwcount>  4 bytes     number of <sugline> following
//
// <sugline>: <sugnr> ... NUL
//
// <sugnr>:     X bytes     word number that results in this soundfolded word,
//                          stored as an offset to the previous number in as
//                          few bytes as possible, see offset2bytes())

#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <wctype.h>

#include "hunspell/hunspell_wrapper.h"
#include "nvim/arglist.h"
#include "nvim/ascii.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/drawscreen.h"
#include "nvim/ex_cmds2.h"
#include "nvim/fileio.h"
#include "nvim/globals.h"
#include "nvim/lib/kvec.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/option.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/path.h"
#include "nvim/regexp.h"
#include "nvim/runtime.h"
#include "nvim/spell.h"
#include "nvim/spell_defs.h"
#include "nvim/spellfile.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/vim.h"

#ifndef UNIX            // it's in os/unix_defs.h for Unix
# include <time.h>      // for time_t
#endif

// Special byte values for <byte>.  Some are only used in the tree for
// postponed prefixes, some only in the other trees.  This is a bit messy...
#define BY_NOFLAGS      0       // end of word without flags or region; for
                                // postponed prefix: no <pflags>
#define BY_INDEX        1       // child is shared, index follows
#define BY_FLAGS        2       // end of word, <flags> byte follows; for
                                // postponed prefix: <pflags> follows
#define BY_FLAGS2       3       // end of word, <flags> and <flags2> bytes
                                // follow; never used in prefix tree
#define BY_SPECIAL  BY_FLAGS2   // highest special byte value

#define ZERO_FLAG   65009       // used when flag is zero: "0"

// Flags used in .spl file for soundsalike flags.
#define SAL_F0LLOWUP            1
#define SAL_COLLAPSE            2
#define SAL_REM_ACCENTS         4

#define VIMSPELLMAGIC "VIMspell"  // string at start of Vim spell file
#define VIMSPELLMAGICL (sizeof(VIMSPELLMAGIC) - 1)
#define VIMSPELLVERSION 50

// Section IDs.  Only renumber them when VIMSPELLVERSION changes!
#define SN_REGION       0       // <regionname> section
#define SN_CHARFLAGS    1       // charflags section
#define SN_MIDWORD      2       // <midword> section
#define SN_PREFCOND     3       // <prefcond> section
#define SN_REP          4       // REP items section
#define SN_SAL          5       // SAL items section
#define SN_SOFO         6       // soundfolding section
#define SN_MAP          7       // MAP items section
#define SN_COMPOUND     8       // compound words section
#define SN_SYLLABLE     9       // syllable section
#define SN_NOBREAK      10      // NOBREAK section
#define SN_SUGFILE      11      // timestamp for .sug file
#define SN_REPSAL       12      // REPSAL items section
#define SN_WORDS        13      // common words
#define SN_NOSPLITSUGS  14      // don't split word for suggestions
#define SN_INFO         15      // info section
#define SN_NOCOMPOUNDSUGS 16    // don't compound for suggestions
#define SN_END          255     // end of sections

#define SNF_REQUIRED    1       // <sectionflags>: required section

#define CF_WORD         0x01
#define CF_UPPER        0x02

static char *e_spell_trunc = N_("E758: Truncated spell file");
static char *e_illegal_character_in_word = N_("E1280: Illegal character in word");

#define MAXLINELEN  500         // Maximum length in bytes of a line in a .aff
                                // and .dic file.
// Main structure to store the contents of a ".aff" file.
typedef struct afffile_S {
  char_u *af_enc;          // "SET", normalized, alloc'ed string or NULL
  int af_flagtype;              // AFT_CHAR, AFT_LONG, AFT_NUM or AFT_CAPLONG
  unsigned af_rare;             // RARE ID for rare word
  unsigned af_keepcase;         // KEEPCASE ID for keep-case word
  unsigned af_bad;              // BAD ID for banned word
  unsigned af_needaffix;        // NEEDAFFIX ID
  unsigned af_circumfix;        // CIRCUMFIX ID
  unsigned af_needcomp;         // NEEDCOMPOUND ID
  unsigned af_comproot;         // COMPOUNDROOT ID
  unsigned af_compforbid;       // COMPOUNDFORBIDFLAG ID
  unsigned af_comppermit;       // COMPOUNDPERMITFLAG ID
  unsigned af_nosuggest;        // NOSUGGEST ID
  int af_pfxpostpone;           // postpone prefixes without chop string and
                                // without flags
  bool af_ignoreextra;          // IGNOREEXTRA present
  hashtab_T af_pref;            // hashtable for prefixes, affheader_T
  hashtab_T af_suff;            // hashtable for suffixes, affheader_T
  hashtab_T af_comp;            // hashtable for compound flags, compitem_T
} afffile_T;

#define AFT_CHAR        0       // flags are one character
#define AFT_LONG        1       // flags are two characters
#define AFT_CAPLONG     2       // flags are one or two characters
#define AFT_NUM         3       // flags are numbers, comma separated

typedef struct affentry_S affentry_T;
// Affix entry from ".aff" file.  Used for prefixes and suffixes.
struct affentry_S {
  affentry_T *ae_next;         // next affix with same name/number
  char_u *ae_chop;         // text to chop off basic word (can be NULL)
  char_u *ae_add;          // text to add to basic word (can be NULL)
  char_u *ae_flags;        // flags on the affix (can be NULL)
  char_u *ae_cond;         // condition (NULL for ".")
  regprog_T *ae_prog;         // regexp program for ae_cond or NULL
  char ae_compforbid;           // COMPOUNDFORBIDFLAG found
  char ae_comppermit;           // COMPOUNDPERMITFLAG found
};

#define AH_KEY_LEN 17          // 2 x 8 bytes + NUL

// Affix header from ".aff" file.  Used for af_pref and af_suff.
typedef struct affheader_S {
  char ah_key[AH_KEY_LEN];      // key for hashtab == name of affix
  unsigned ah_flag;             // affix name as number, uses "af_flagtype"
  int ah_newID;                 // prefix ID after renumbering; 0 if not used
  int ah_combine;               // suffix may combine with prefix
  int ah_follows;               // another affix block should be following
  affentry_T *ah_first;         // first affix entry
} affheader_T;

#define HI2AH(hi)   ((affheader_T *)(hi)->hi_key)

// Flag used in compound items.
typedef struct compitem_S {
  char_u ci_key[AH_KEY_LEN];    // key for hashtab == name of compound
  unsigned ci_flag;             // affix name as number, uses "af_flagtype"
  int ci_newID;                 // affix ID after renumbering.
} compitem_T;

#define HI2CI(hi)   ((compitem_T *)(hi)->hi_key)

// Structure that is used to store the items in the word tree.  This avoids
// the need to keep track of each allocated thing, everything is freed all at
// once after ":mkspell" is done.
// Note: "sb_next" must be just before "sb_data" to make sure the alignment of
// "sb_data" is correct for systems where pointers must be aligned on
// pointer-size boundaries and sizeof(pointer) > sizeof(int) (e.g., Sparc).
#define  SBLOCKSIZE 16000       // size of sb_data
typedef struct sblock_S sblock_T;
struct sblock_S {
  int sb_used;                  // nr of bytes already in use
  sblock_T *sb_next;         // next block in list
  char_u sb_data[1];            // data, actually longer
};

// A node in the tree.
typedef struct wordnode_S wordnode_T;
struct wordnode_S {
  union {   // shared to save space
    char_u hashkey[6];          // the hash key, only used while compressing
    int index;                  // index in written nodes (valid after first
                                // round)
  } wn_u1;
  union {   // shared to save space
    wordnode_T *next;           // next node with same hash key
    wordnode_T *wnode;          // parent node that will write this node
  } wn_u2;
  wordnode_T *wn_child;        // child (next byte in word)
  wordnode_T *wn_sibling;      // next sibling (alternate byte in word,
                               //   always sorted)
  int wn_refs;                  // Nr. of references to this node.  Only
                                //   relevant for first node in a list of
                                //   siblings, in following siblings it is
                                //   always one.
  char_u wn_byte;               // Byte for this node. NUL for word end

  // Info for when "wn_byte" is NUL.
  // In PREFIXTREE "wn_region" is used for the prefcondnr.
  // In the soundfolded word tree "wn_flags" has the MSW of the wordnr and
  // "wn_region" the LSW of the wordnr.
  char_u wn_affixID;            // supported/required prefix ID or 0
  uint16_t wn_flags;            // WF_ flags
  short wn_region;              // region mask

#ifdef SPELL_PRINTTREE
  int wn_nr;                    // sequence nr for printing
#endif
};

#define WN_MASK  0xffff         // mask relevant bits of "wn_flags"

#define HI2WN(hi)    (wordnode_T *)((hi)->hi_key)

// Info used while reading the spell files.
typedef struct spellinfo_S {
  wordnode_T *si_foldroot;     // tree with case-folded words
  long si_foldwcount;           // nr of words in si_foldroot

  wordnode_T *si_keeproot;     // tree with keep-case words
  long si_keepwcount;           // nr of words in si_keeproot

  wordnode_T *si_prefroot;     // tree with postponed prefixes

  long si_sugtree;              // creating the soundfolding trie

  sblock_T *si_blocks;       // memory blocks used
  long si_blocks_cnt;           // memory blocks allocated
  int si_did_emsg;              // true when ran out of memory

  long si_compress_cnt;         // words to add before lowering
                                // compression limit
  wordnode_T *si_first_free;   // List of nodes that have been freed during
                               // compression, linked by "wn_child" field.
  long si_free_count;           // number of nodes in si_first_free
#ifdef SPELL_PRINTTREE
  int si_wordnode_nr;           // sequence nr for nodes
#endif
  buf_T *si_spellbuf;     // buffer used to store soundfold word table

  int si_ascii;                 // handling only ASCII words
  int si_add;                   // addition file
  int si_clear_chartab;             // when true clear char tables
  int si_region;                // region mask
  vimconv_T si_conv;            // for conversion to 'encoding'
  int si_memtot;                // runtime memory used
  int si_verbose;               // verbose messages
  int si_msg_count;             // number of words added since last message
  char_u *si_info;         // info text chars or NULL
  int si_region_count;          // number of regions supported (1 when there
                                // are no regions)
  char_u si_region_name[MAXREGIONS * 2 + 1];
  // region names; used only if
  // si_region_count > 1)

  garray_T si_rep;              // list of fromto_T entries from REP lines
  garray_T si_repsal;           // list of fromto_T entries from REPSAL lines
  garray_T si_sal;              // list of fromto_T entries from SAL lines
  char_u *si_sofofr;       // SOFOFROM text
  char_u *si_sofoto;       // SOFOTO text
  int si_nosugfile;             // NOSUGFILE item found
  int si_nosplitsugs;           // NOSPLITSUGS item found
  int si_nocompoundsugs;        // NOCOMPOUNDSUGS item found
  int si_followup;              // soundsalike: ?
  int si_collapse;              // soundsalike: ?
  hashtab_T si_commonwords;     // hashtable for common words
  time_t si_sugtime;            // timestamp for .sug file
  int si_rem_accents;           // soundsalike: remove accents
  garray_T si_map;              // MAP info concatenated
  char_u *si_midword;      // MIDWORD chars or NULL
  int si_compmax;               // max nr of words for compounding
  int si_compminlen;            // minimal length for compounding
  int si_compsylmax;            // max nr of syllables for compounding
  int si_compoptions;           // COMP_ flags
  garray_T si_comppat;          // CHECKCOMPOUNDPATTERN items, each stored as
                                // a string
  char_u *si_compflags;    // flags used for compounding
  char_u si_nobreak;            // NOBREAK
  char_u *si_syllable;     // syllable string
  garray_T si_prefcond;         // table with conditions for postponed
                                // prefixes, each stored as a string
  int si_newprefID;             // current value for ah_newID
  int si_newcompID;             // current value for compound ID
} spellinfo_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "spellfile.c.generated.h"
#endif

/// Read n bytes from fd to buf, returning on errors
///
/// @param[out]  buf  Buffer to read to, must be at least n bytes long.
/// @param[in]  n  Amount of bytes to read.
/// @param  fd  FILE* to read from.
/// @param  exit_code  Code to run before returning.
///
/// @return Allows to proceed if everything is OK, returns SP_TRUNCERROR if
///         there are not enough bytes, returns SP_OTHERERROR if reading failed.
#define SPELL_READ_BYTES(buf, n, fd, exit_code) \
  do { \
    const size_t n__SPRB = (n); \
    FILE *const fd__SPRB = (fd); \
    char *const buf__SPRB = (buf); \
    const size_t read_bytes__SPRB = fread(buf__SPRB, 1, n__SPRB, fd__SPRB); \
    if (read_bytes__SPRB != n__SPRB) { \
      exit_code; \
      return feof(fd__SPRB) ? SP_TRUNCERROR : SP_OTHERERROR; \
    } \
  } while (0)

/// Like #SPELL_READ_BYTES, but also error out if NUL byte was read
///
/// @return Allows to proceed if everything is OK, returns SP_TRUNCERROR if
///         there are not enough bytes, returns SP_OTHERERROR if reading failed,
///         returns SP_FORMERROR if read out a NUL byte.
#define SPELL_READ_NONNUL_BYTES(buf, n, fd, exit_code) \
  do { \
    const size_t n__SPRNB = (n); \
    FILE *const fd__SPRNB = (fd); \
    char *const buf__SPRNB = (buf); \
    SPELL_READ_BYTES(buf__SPRNB, n__SPRNB, fd__SPRNB, exit_code); \
    if (memchr(buf__SPRNB, NUL, (size_t)n__SPRNB)) { \
      exit_code; \
      return SP_FORMERROR; \
    } \
  } while (0)

/// Check that spell file starts with a magic string
///
/// Does not check for version of the file.
///
/// @param  fd  File to check.
///
/// @return 0 in case of success, SP_TRUNCERROR if file contains not enough
///         bytes, SP_FORMERROR if it does not match magic string and
///         SP_OTHERERROR if reading file failed.
static inline int spell_check_magic_string(FILE *const fd)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_ALWAYS_INLINE
{
  char buf[VIMSPELLMAGICL];
  SPELL_READ_BYTES(buf, VIMSPELLMAGICL, fd,; );
  if (memcmp(buf, VIMSPELLMAGIC, VIMSPELLMAGICL) != 0) {
    return SP_FORMERROR;
  }
  return 0;
}

/// Load one spell file and store the info into a slang_T.
///
/// This is invoked in three ways:
/// - From spell_load_cb() to load a spell file for the first time.  "lang" is
///   the language name, "old_lp" is NULL.  Will allocate an slang_T.
/// - To reload a spell file that was changed.  "lang" is NULL and "old_lp"
///   points to the existing slang_T.
/// - Just after writing a .spl file; it's read back to produce the .sug file.
///   "old_lp" is NULL and "lang" is NULL.  Will allocate an slang_T.
///
/// @param silent  no error if file doesn't exist
///
/// @return  the slang_T the spell file was loaded into.  NULL for error.
slang_T *spell_load_file(char *fname, char *lang, slang_T *old_lp, bool silent)
{
  FILE *fd;
  char *p;
  int n;
  int len;
  slang_T *lp = NULL;
  int c = 0;
  int res;
  bool did_estack_push = false;

  fd = os_fopen(fname, "r");
  if (fd == NULL) {
    if (!silent) {
      semsg(_(e_notopen), fname);
    } else if (p_verbose > 2) {
      verbose_enter();
      smsg((char *)e_notopen, fname);
      verbose_leave();
    }
    goto endFAIL;
  }
  if (p_verbose > 2) {
    verbose_enter();
    smsg(_("Reading spell file \"%s\""), fname);
    verbose_leave();
  }

  if (old_lp == NULL) {
    lp = slang_alloc(lang);

    // Remember the file name, used to reload the file when it's updated.
    lp->sl_fname = xstrdup(fname);

    // Check for .add.spl.
    lp->sl_add = strstr(path_tail(fname), SPL_FNAME_ADD) != NULL;
  } else {
    lp = old_lp;
  }

  // Set sourcing_name, so that error messages mention the file name.
  estack_push(ETYPE_SPELL, fname, 0);
  did_estack_push = true;

  // <HEADER>: <fileID>
  const int scms_ret = spell_check_magic_string(fd);
  switch (scms_ret) {
  case SP_FORMERROR:
  case SP_TRUNCERROR:
    semsg("%s", _("E757: This does not look like a spell file"));
    goto endFAIL;
  case SP_OTHERERROR:
    semsg(_("E5042: Failed to read spell file %s: %s"),
          fname, strerror(ferror(fd)));
    goto endFAIL;
  case 0:
    break;
  }
  c = getc(fd);                                         // <versionnr>
  if (c < VIMSPELLVERSION) {
    emsg(_("E771: Old spell file, needs to be updated"));
    goto endFAIL;
  } else if (c > VIMSPELLVERSION) {
    emsg(_("E772: Spell file is for newer version of Vim"));
    goto endFAIL;
  }

  // <SECTIONS>: <section> ... <sectionend>
  // <section>: <sectionID> <sectionflags> <sectionlen> (section contents)
  for (;;) {
    n = getc(fd);                           // <sectionID> or <sectionend>
    if (n == SN_END) {
      break;
    }
    c = getc(fd);                                       // <sectionflags>
    len = get4c(fd);                                    // <sectionlen>
    if (len < 0) {
      goto truncerr;
    }

    res = 0;
    switch (n) {
    case SN_INFO:
      lp->sl_info = READ_STRING(fd, len);               // <infotext>
      if (lp->sl_info == NULL) {
        goto endFAIL;
      }
      break;

    case SN_REGION:
      res = read_region_section(fd, lp, len);
      break;

    case SN_CHARFLAGS:
      res = read_charflags_section(fd);
      break;

    case SN_MIDWORD:
      lp->sl_midword = READ_STRING(fd, len);            // <midword>
      if (lp->sl_midword == NULL) {
        goto endFAIL;
      }
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
      p = (char *)READ_STRING(fd, len);                         // <mapstr>
      if (p == NULL) {
        goto endFAIL;
      }
      set_map_str(lp, (char_u *)p);
      xfree(p);
      break;

    case SN_WORDS:
      res = read_words_section(fd, lp, len);
      break;

    case SN_SUGFILE:
      lp->sl_sugtime = get8ctime(fd);                   // <timestamp>
      break;

    case SN_NOSPLITSUGS:
      lp->sl_nosplitsugs = true;
      break;

    case SN_NOCOMPOUNDSUGS:
      lp->sl_nocompoundsugs = true;
      break;

    case SN_COMPOUND:
      res = read_compound(fd, lp, len);
      break;

    case SN_NOBREAK:
      lp->sl_nobreak = true;
      break;

    case SN_SYLLABLE:
      lp->sl_syllable = READ_STRING(fd, len);           // <syllable>
      if (lp->sl_syllable == NULL) {
        goto endFAIL;
      }
      if (init_syl_tab(lp) != OK) {
        goto endFAIL;
      }
      break;

    default:
      // Unsupported section.  When it's required give an error
      // message.  When it's not required skip the contents.
      if (c & SNF_REQUIRED) {
        emsg(_("E770: Unsupported section in spell file"));
        goto endFAIL;
      }
      while (--len >= 0) {
        if (getc(fd) < 0) {
          goto truncerr;
        }
      }
      break;
    }
someerror:
    if (res == SP_FORMERROR) {
      emsg(_(e_format));
      goto endFAIL;
    }
    if (res == SP_TRUNCERROR) {
truncerr:
      emsg(_(e_spell_trunc));
      goto endFAIL;
    }
    if (res == SP_OTHERERROR) {
      goto endFAIL;
    }
  }

  // <LWORDTREE>
  res = spell_read_tree(fd, &lp->sl_fbyts, &lp->sl_fbyts_len,
                        &lp->sl_fidxs, false, 0);
  if (res != 0) {
    goto someerror;
  }

  // <KWORDTREE>
  res = spell_read_tree(fd, &lp->sl_kbyts, NULL, &lp->sl_kidxs, false, 0);
  if (res != 0) {
    goto someerror;
  }

  // <PREFIXTREE>
  res = spell_read_tree(fd, &lp->sl_pbyts, NULL, &lp->sl_pidxs, true,
                        lp->sl_prefixcnt);
  if (res != 0) {
    goto someerror;
  }

  // For a new file link it in the list of spell files.
  if (old_lp == NULL && lang != NULL) {
    lp->sl_next = first_lang;
    first_lang = lp;
  }

  goto endOK;

endFAIL:
  if (lang != NULL) {
    // truncating the name signals the error to spell_load_lang()
    *lang = NUL;
  }
  if (lp != NULL && old_lp == NULL) {
    slang_free(lp);
  }
  lp = NULL;

endOK:
  if (fd != NULL) {
    fclose(fd);
  }
  if (did_estack_push) {
    estack_pop();
  }

  return lp;
}

// Fill in the wordcount fields for a trie.
// Returns the total number of words.
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
      // Done all bytes at this node, go up one level.
      idxs[arridx[depth]] = wordcount[depth];
      if (depth > 0) {
        wordcount[depth - 1] += wordcount[depth];
      }

      depth--;
      fast_breakcheck();
    } else {
      // Do one more byte at this node.
      n = arridx[depth] + curi[depth];
      curi[depth]++;

      c = byts[n];
      if (c == 0) {
        // End of word, count it.
        wordcount[depth]++;

        // Skip over any other NUL bytes (same word with different
        // flags).
        while (byts[n + 1] == 0) {
          n++;
          curi[depth]++;
        }
      } else {
        // Normal char, go one level deeper to count the words.
        depth++;
        arridx[depth] = idxs[n];
        curi[depth] = 1;
        wordcount[depth] = 0;
      }
    }
  }
}

/// Load the .sug files for languages that have one and weren't loaded yet.
void suggest_load_files(void)
{
  langp_T *lp;
  slang_T *slang;
  char *dotp;
  FILE *fd;
  char_u buf[MAXWLEN];
  int i;
  time_t timestamp;
  int wcount;
  int wordnr;
  garray_T ga;
  int c;

  // Do this for all languages that support sound folding.
  for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len; lpi++) {
    lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
    slang = lp->lp_slang;
    if (slang->sl_sugtime != 0 && !slang->sl_sugloaded) {
      // Change ".spl" to ".sug" and open the file.  When the file isn't
      // found silently skip it.  Do set "sl_sugloaded" so that we
      // don't try again and again.
      slang->sl_sugloaded = true;

      dotp = strrchr(slang->sl_fname, '.');
      if (dotp == NULL || path_fnamecmp(dotp, ".spl") != 0) {
        continue;
      }
      STRCPY(dotp, ".sug");
      fd = os_fopen(slang->sl_fname, "r");
      if (fd == NULL) {
        goto nextone;
      }

      // <SUGHEADER>: <fileID> <versionnr> <timestamp>
      for (i = 0; i < VIMSUGMAGICL; i++) {
        buf[i] = (char_u)getc(fd);                              // <fileID>
      }
      if (STRNCMP(buf, VIMSUGMAGIC, VIMSUGMAGICL) != 0) {
        semsg(_("E778: This does not look like a .sug file: %s"),
              slang->sl_fname);
        goto nextone;
      }
      c = getc(fd);                                     // <versionnr>
      if (c < VIMSUGVERSION) {
        semsg(_("E779: Old .sug file, needs to be updated: %s"),
              slang->sl_fname);
        goto nextone;
      } else if (c > VIMSUGVERSION) {
        semsg(_("E780: .sug file is for newer version of Vim: %s"),
              slang->sl_fname);
        goto nextone;
      }

      // Check the timestamp, it must be exactly the same as the one in
      // the .spl file.  Otherwise the word numbers won't match.
      timestamp = get8ctime(fd);                        // <timestamp>
      if (timestamp != slang->sl_sugtime) {
        semsg(_("E781: .sug file doesn't match .spl file: %s"),
              slang->sl_fname);
        goto nextone;
      }

      // <SUGWORDTREE>: <wordtree>
      // Read the trie with the soundfolded words.
      if (spell_read_tree(fd, &slang->sl_sbyts, NULL, &slang->sl_sidxs,
                          false, 0) != 0) {
someerror:
        semsg(_("E782: error while reading .sug file: %s"),
              slang->sl_fname);
        slang_clear_sug(slang);
        goto nextone;
      }

      // <SUGTABLE>: <sugwcount> <sugline> ...
      //
      // Read the table with word numbers.  We use a file buffer for
      // this, because it's so much like a file with lines.  Makes it
      // possible to swap the info and save on memory use.
      slang->sl_sugbuf = open_spellbuf();

      // <sugwcount>
      wcount = get4c(fd);
      if (wcount < 0) {
        goto someerror;
      }

      // Read all the wordnr lists into the buffer, one NUL terminated
      // list per line.
      ga_init(&ga, 1, 100);
      for (wordnr = 0; wordnr < wcount; wordnr++) {
        ga.ga_len = 0;
        for (;;) {
          c = getc(fd);                                     // <sugline>
          if (c < 0) {
            goto someerror;
          }
          GA_APPEND(char_u, &ga, (char_u)c);
          if (c == NUL) {
            break;
          }
        }
        if (ml_append_buf(slang->sl_sugbuf, (linenr_T)wordnr,
                          ga.ga_data, ga.ga_len, true) == FAIL) {
          goto someerror;
        }
      }
      ga_clear(&ga);

      // Need to put word counts in the word tries, so that we can find
      // a word by its number.
      tree_count_words(slang->sl_fbyts, slang->sl_fidxs);
      tree_count_words(slang->sl_sbyts, slang->sl_sidxs);

nextone:
      if (fd != NULL) {
        fclose(fd);
      }
      STRCPY(dotp, ".spl");
    }
  }
}

// Read a length field from "fd" in "cnt_bytes" bytes.
// Allocate memory, read the string into it and add a NUL at the end.
// Returns NULL when the count is zero.
// Sets "*cntp" to SP_*ERROR when there is an error, length of the result
// otherwise.
static char_u *read_cnt_string(FILE *fd, int cnt_bytes, int *cntp)
{
  int cnt = 0;
  char_u *str;

  // read the length bytes, MSB first
  for (int i = 0; i < cnt_bytes; i++) {
    const int c = getc(fd);

    if (c == EOF) {
      *cntp = SP_TRUNCERROR;
      return NULL;
    }
    cnt = (int)(((unsigned)cnt << 8) + (unsigned)c);
  }
  *cntp = cnt;
  if (cnt == 0) {
    return NULL;            // nothing to read, return NULL
  }
  str = READ_STRING(fd, cnt);
  if (str == NULL) {
    *cntp = SP_OTHERERROR;
  }
  return str;
}

// Read SN_REGION: <regionname> ...
// Return SP_*ERROR flags.
static int read_region_section(FILE *fd, slang_T *lp, int len)
{
  if (len > MAXREGIONS * 2) {
    return SP_FORMERROR;
  }
  SPELL_READ_NONNUL_BYTES((char *)lp->sl_regions, (size_t)len, fd,; );
  lp->sl_regions[len] = NUL;
  return 0;
}

// Read SN_CHARFLAGS section: <charflagslen> <charflags>
//                              <folcharslen> <folchars>
// Return SP_*ERROR flags.
static int read_charflags_section(FILE *fd)
{
  char_u *flags;
  char_u *fol;
  int flagslen, follen;

  // <charflagslen> <charflags>
  flags = read_cnt_string(fd, 1, &flagslen);
  if (flagslen < 0) {
    return flagslen;
  }

  // <folcharslen> <folchars>
  fol = read_cnt_string(fd, 2, &follen);
  if (follen < 0) {
    xfree(flags);
    return follen;
  }

  // Set the word-char flags and fill SPELL_ISUPPER() table.
  if (flags != NULL && fol != NULL) {
    set_spell_charflags(flags, flagslen, fol);
  }

  xfree(flags);
  xfree(fol);

  // When <charflagslen> is zero then <fcharlen> must also be zero.
  if ((flags == NULL) != (fol == NULL)) {
    return SP_FORMERROR;
  }
  return 0;
}

// Read SN_PREFCOND section.
// Return SP_*ERROR flags.
static int read_prefcond_section(FILE *fd, slang_T *lp)
{
  // <prefcondcnt> <prefcond> ...
  const int cnt = get2c(fd);  // <prefcondcnt>
  if (cnt <= 0) {
    return SP_FORMERROR;
  }

  lp->sl_prefprog = xcalloc((size_t)cnt, sizeof(regprog_T *));
  lp->sl_prefixcnt = cnt;

  for (int i = 0; i < cnt; i++) {
    // <prefcond> : <condlen> <condstr>
    const int n = getc(fd);  // <condlen>
    if (n < 0 || n >= MAXWLEN) {
      return SP_FORMERROR;
    }

    // When <condlen> is zero we have an empty condition.  Otherwise
    // compile the regexp program used to check for the condition.
    if (n > 0) {
      char buf[MAXWLEN + 1];
      buf[0] = '^';  // always match at one position only
      SPELL_READ_NONNUL_BYTES(buf + 1, (size_t)n, fd,; );
      buf[n + 1] = NUL;
      lp->sl_prefprog[i] = vim_regcomp(buf, RE_MAGIC | RE_STRING);
    }
  }
  return 0;
}

// Read REP or REPSAL items section from "fd": <repcount> <rep> ...
// Return SP_*ERROR flags.
static int read_rep_section(FILE *fd, garray_T *gap, int16_t *first)
{
  int cnt;
  fromto_T *ftp;

  cnt = get2c(fd);                                      // <repcount>
  if (cnt < 0) {
    return SP_TRUNCERROR;
  }

  ga_grow(gap, cnt);

  // <rep> : <repfromlen> <repfrom> <reptolen> <repto>
  for (; gap->ga_len < cnt; ++gap->ga_len) {
    int c;
    ftp = &((fromto_T *)gap->ga_data)[gap->ga_len];
    ftp->ft_from = read_cnt_string(fd, 1, &c);
    if (c < 0) {
      return c;
    }
    if (c == 0) {
      return SP_FORMERROR;
    }
    ftp->ft_to = read_cnt_string(fd, 1, &c);
    if (c <= 0) {
      xfree(ftp->ft_from);
      if (c < 0) {
        return c;
      }
      return SP_FORMERROR;
    }
  }

  // Fill the first-index table.
  for (int i = 0; i < 256; i++) {
    first[i] = -1;
  }
  for (int i = 0; i < gap->ga_len; i++) {
    ftp = &((fromto_T *)gap->ga_data)[i];
    if (first[*ftp->ft_from] == -1) {
      first[*ftp->ft_from] = (int16_t)i;
    }
  }
  return 0;
}

// Read SN_SAL section: <salflags> <salcount> <sal> ...
// Return SP_*ERROR flags.
static int read_sal_section(FILE *fd, slang_T *slang)
{
  int cnt;
  garray_T *gap;
  salitem_T *smp;
  int ccnt;
  char_u *p;

  slang->sl_sofo = false;

  const int flags = getc(fd);                   // <salflags>
  if (flags & SAL_F0LLOWUP) {
    slang->sl_followup = true;
  }
  if (flags & SAL_COLLAPSE) {
    slang->sl_collapse = true;
  }
  if (flags & SAL_REM_ACCENTS) {
    slang->sl_rem_accents = true;
  }

  cnt = get2c(fd);                              // <salcount>
  if (cnt < 0) {
    return SP_TRUNCERROR;
  }

  gap = &slang->sl_sal;
  ga_init(gap, sizeof(salitem_T), 10);
  ga_grow(gap, cnt + 1);

  // <sal> : <salfromlen> <salfrom> <saltolen> <salto>
  for (; gap->ga_len < cnt; gap->ga_len++) {
    int c = NUL;

    smp = &((salitem_T *)gap->ga_data)[gap->ga_len];
    ccnt = getc(fd);                            // <salfromlen>
    if (ccnt < 0) {
      return SP_TRUNCERROR;
    }
    p = xmalloc((size_t)ccnt + 2);
    smp->sm_lead = p;

    // Read up to the first special char into sm_lead.
    int i = 0;
    for (; i < ccnt; i++) {
      c = getc(fd);                             // <salfrom>
      if (vim_strchr("0123456789(-<^$", c) != NULL) {
        break;
      }
      *p++ = (char_u)c;
    }
    smp->sm_leadlen = (int)(p - smp->sm_lead);
    *p++ = NUL;

    // Put (abc) chars in sm_oneof, if any.
    if (c == '(') {
      smp->sm_oneof = p;
      for (++i; i < ccnt; i++) {
        c = getc(fd);                           // <salfrom>
        if (c == ')') {
          break;
        }
        *p++ = (char_u)c;
      }
      *p++ = NUL;
      if (++i < ccnt) {
        c = getc(fd);
      }
    } else {
      smp->sm_oneof = NULL;
    }

    // Any following chars go in sm_rules.
    smp->sm_rules = p;
    if (i < ccnt) {
      // store the char we got while checking for end of sm_lead
      *p++ = (char_u)c;
    }
    i++;
    if (i < ccnt) {
      SPELL_READ_NONNUL_BYTES(                  // <salfrom>
                                                (char *)p, (size_t)(ccnt - i), fd,
                                                xfree(smp->sm_lead));
      p += (ccnt - i);
    }
    *p++ = NUL;

    // <saltolen> <salto>
    smp->sm_to = read_cnt_string(fd, 1, &ccnt);
    if (ccnt < 0) {
      xfree(smp->sm_lead);
      return ccnt;
    }

    // convert the multi-byte strings to wide char strings
    smp->sm_lead_w = mb_str2wide(smp->sm_lead);
    smp->sm_leadlen = mb_charlen(smp->sm_lead);
    if (smp->sm_oneof == NULL) {
      smp->sm_oneof_w = NULL;
    } else {
      smp->sm_oneof_w = mb_str2wide(smp->sm_oneof);
    }
    if (smp->sm_to == NULL) {
      smp->sm_to_w = NULL;
    } else {
      smp->sm_to_w = mb_str2wide(smp->sm_to);
    }
  }

  if (!GA_EMPTY(gap)) {
    // Add one extra entry to mark the end with an empty sm_lead.  Avoids
    // that we need to check the index every time.
    smp = &((salitem_T *)gap->ga_data)[gap->ga_len];
    p = xmalloc(1);
    p[0] = NUL;
    smp->sm_lead = p;
    smp->sm_lead_w = mb_str2wide(smp->sm_lead);
    smp->sm_leadlen = 0;
    smp->sm_oneof = NULL;
    smp->sm_oneof_w = NULL;
    smp->sm_rules = p;
    smp->sm_to = NULL;
    smp->sm_to_w = NULL;
    gap->ga_len++;
  }

  // Fill the first-index table.
  set_sal_first(slang);

  return 0;
}

// Read SN_WORDS: <word> ...
// Return SP_*ERROR flags.
static int read_words_section(FILE *fd, slang_T *lp, int len)
{
  int done = 0;
  int i;
  int c;
  char_u word[MAXWLEN];

  while (done < len) {
    // Read one word at a time.
    for (i = 0;; i++) {
      c = getc(fd);
      if (c == EOF) {
        return SP_TRUNCERROR;
      }
      word[i] = (char_u)c;
      if (word[i] == NUL) {
        break;
      }
      if (i == MAXWLEN - 1) {
        return SP_FORMERROR;
      }
    }

    // Init the count to 10.
    count_common_word(lp, word, -1, 10);
    done += i + 1;
  }
  return 0;
}

// SN_SOFO: <sofofromlen> <sofofrom> <sofotolen> <sofoto>
// Return SP_*ERROR flags.
static int read_sofo_section(FILE *fd, slang_T *slang)
{
  int cnt;
  char_u *from, *to;
  int res;

  slang->sl_sofo = true;

  // <sofofromlen> <sofofrom>
  from = read_cnt_string(fd, 2, &cnt);
  if (cnt < 0) {
    return cnt;
  }

  // <sofotolen> <sofoto>
  to = read_cnt_string(fd, 2, &cnt);
  if (cnt < 0) {
    xfree(from);
    return cnt;
  }

  // Store the info in slang->sl_sal and/or slang->sl_sal_first.
  if (from != NULL && to != NULL) {
    res = set_sofo(slang, from, to);
  } else if (from != NULL || to != NULL) {
    res = SP_FORMERROR;        // only one of two strings is an error
  } else {
    res = 0;
  }

  xfree(from);
  xfree(to);
  return res;
}

// Read the compound section from the .spl file:
//      <compmax> <compminlen> <compsylmax> <compoptions> <compflags>
// Returns SP_*ERROR flags.
static int read_compound(FILE *fd, slang_T *slang, int len)
{
  int todo = len;
  int c;
  int atstart;
  int cnt;
  garray_T *gap;

  if (todo < 2) {
    return SP_FORMERROR;        // need at least two bytes
  }
  todo--;
  c = getc(fd);                                         // <compmax>
  if (c < 2) {
    c = MAXWLEN;
  }
  slang->sl_compmax = c;

  todo--;
  c = getc(fd);                                         // <compminlen>
  if (c < 1) {
    c = 0;
  }
  slang->sl_compminlen = c;

  todo--;
  c = getc(fd);                                         // <compsylmax>
  if (c < 1) {
    c = MAXWLEN;
  }
  slang->sl_compsylmax = c;

  c = getc(fd);                                         // <compoptions>
  if (c != 0) {
    ungetc(c, fd);          // be backwards compatible with Vim 7.0b
  } else {
    todo--;
    c = getc(fd);           // only use the lower byte for now
    todo--;
    slang->sl_compoptions = c;

    gap = &slang->sl_comppat;
    c = get2c(fd);                                      // <comppatcount>
    if (c < 0) {
      return SP_TRUNCERROR;
    }
    todo -= 2;
    ga_init(gap, sizeof(char_u *), c);
    ga_grow(gap, c);
    while (--c >= 0) {
      ((char **)(gap->ga_data))[gap->ga_len++] = (char *)read_cnt_string(fd, 1, &cnt);
      // <comppatlen> <comppattext>
      if (cnt < 0) {
        return cnt;
      }
      todo -= cnt + 1;
    }
  }
  if (todo < 0) {
    return SP_FORMERROR;
  }

  // Turn the COMPOUNDRULE items into a regexp pattern:
  // "a[bc]/a*b+" -> "^\(a[bc]\|a*b\+\)$".
  // Inserting backslashes may double the length, "^\(\)$<Nul>" is 7 bytes.
  // Conversion to utf-8 may double the size.
  c = todo * 2 + 7;
  c += todo * 2;
  char_u *pat = xmalloc((size_t)c);

  // We also need a list of all flags that can appear at the start and one
  // for all flags.
  char_u *cp = xmalloc((size_t)todo + 1);
  slang->sl_compstartflags = cp;
  *cp = NUL;

  char_u *ap = xmalloc((size_t)todo + 1);
  slang->sl_compallflags = ap;
  *ap = NUL;

  // And a list of all patterns in their original form, for checking whether
  // compounding may work in match_compoundrule().  This is freed when we
  // encounter a wildcard, the check doesn't work then.
  char_u *crp = xmalloc((size_t)todo + 1);
  slang->sl_comprules = crp;

  char_u *pp = pat;
  *pp++ = '^';
  *pp++ = '\\';
  *pp++ = '(';

  atstart = 1;
  while (todo-- > 0) {
    c = getc(fd);                                       // <compflags>
    if (c == EOF) {
      xfree(pat);
      return SP_TRUNCERROR;
    }

    // Add all flags to "sl_compallflags".
    if (vim_strchr("?*+[]/", c) == NULL
        && !byte_in_str(slang->sl_compallflags, c)) {
      *ap++ = (char_u)c;
      *ap = NUL;
    }

    if (atstart != 0) {
      // At start of item: copy flags to "sl_compstartflags".  For a
      // [abc] item set "atstart" to 2 and copy up to the ']'.
      if (c == '[') {
        atstart = 2;
      } else if (c == ']') {
        atstart = 0;
      } else {
        if (!byte_in_str(slang->sl_compstartflags, c)) {
          *cp++ = (char_u)c;
          *cp = NUL;
        }
        if (atstart == 1) {
          atstart = 0;
        }
      }
    }

    // Copy flag to "sl_comprules", unless we run into a wildcard.
    if (crp != NULL) {
      if (c == '?' || c == '+' || c == '*') {
        XFREE_CLEAR(slang->sl_comprules);
        crp = NULL;
      } else {
        *crp++ = (char_u)c;
      }
    }

    if (c == '/') {         // slash separates two items
      *pp++ = '\\';
      *pp++ = '|';
      atstart = 1;
    } else {              // normal char, "[abc]" and '*' are copied as-is
      if (c == '?' || c == '+' || c == '~') {
        *pp++ = '\\';               // "a?" becomes "a\?", "a+" becomes "a\+"
      }
      pp += utf_char2bytes(c, (char *)pp);
    }
  }

  *pp++ = '\\';
  *pp++ = ')';
  *pp++ = '$';
  *pp = NUL;

  if (crp != NULL) {
    *crp = NUL;
  }

  slang->sl_compprog = vim_regcomp((char *)pat, RE_MAGIC + RE_STRING + RE_STRICT);
  xfree(pat);
  if (slang->sl_compprog == NULL) {
    return SP_FORMERROR;
  }

  return 0;
}

// Set the SOFOFROM and SOFOTO items in language "lp".
// Returns SP_*ERROR flags when there is something wrong.
static int set_sofo(slang_T *lp, char_u *from, char_u *to)
{
  char_u *s;
  char_u *p;

  // Use "sl_sal" as an array with 256 pointers to a list of wide
  // characters.  The index is the low byte of the character.
  // The list contains from-to pairs with a terminating NUL.
  // sl_sal_first[] is used for latin1 "from" characters.
  garray_T *gap = &lp->sl_sal;
  ga_init(gap, sizeof(int *), 1);
  ga_grow(gap, 256);
  memset(gap->ga_data, 0, sizeof(int *) * 256);
  gap->ga_len = 256;

  // First count the number of items for each list.  Temporarily use
  // sl_sal_first[] for this.
  for (p = from, s = to; *p != NUL && *s != NUL;) {
    const int c = mb_cptr2char_adv((const char_u **)&p);
    MB_CPTR_ADV(s);
    if (c >= 256) {
      lp->sl_sal_first[c & 0xff]++;
    }
  }
  if (*p != NUL || *s != NUL) {  // lengths differ
    return SP_FORMERROR;
  }

  // Allocate the lists.
  for (int i = 0; i < 256; i++) {
    if (lp->sl_sal_first[i] > 0) {
      p = xmalloc(sizeof(int) * (size_t)(lp->sl_sal_first[i] * 2 + 1));
      ((int **)gap->ga_data)[i] = (int *)p;
      *(int *)p = 0;
    }
  }

  // Put the characters up to 255 in sl_sal_first[] the rest in a sl_sal
  // list.
  memset(lp->sl_sal_first, 0, sizeof(salfirst_T) * 256);
  for (p = from, s = to; *p != NUL && *s != NUL;) {
    const int c = mb_cptr2char_adv((const char_u **)&p);
    const int i = mb_cptr2char_adv((const char_u **)&s);
    if (c >= 256) {
      // Append the from-to chars at the end of the list with
      // the low byte.
      int *inp = ((int **)gap->ga_data)[c & 0xff];
      while (*inp != 0) {
        inp++;
      }
      *inp++ = c;                     // from char
      *inp++ = i;                     // to char
      *inp++ = NUL;                   // NUL at the end
    } else {
      // mapping byte to char is done in sl_sal_first[]
      lp->sl_sal_first[c] = i;
    }
  }

  return 0;
}

// Fill the first-index table for "lp".
static void set_sal_first(slang_T *lp)
{
  salfirst_T *sfirst;
  salitem_T *smp;
  int c;
  garray_T *gap = &lp->sl_sal;

  sfirst = lp->sl_sal_first;
  for (int i = 0; i < 256; i++) {
    sfirst[i] = -1;
  }
  smp = (salitem_T *)gap->ga_data;
  for (int i = 0; i < gap->ga_len; i++) {
    // Use the lowest byte of the first character.  For latin1 it's
    // the character, for other encodings it should differ for most
    // characters.
    c = *smp[i].sm_lead_w & 0xff;
    if (sfirst[c] == -1) {
      sfirst[c] = i;

      // Make sure all entries with this byte are following each
      // other.  Move the ones that are in the wrong position.  Do
      // keep the same ordering!
      while (i + 1 < gap->ga_len
             && (*smp[i + 1].sm_lead_w & 0xff) == c) {
        // Skip over entry with same index byte.
        i++;
      }

      for (int n = 1; i + n < gap->ga_len; n++) {
        if ((*smp[i + n].sm_lead_w & 0xff) == c) {
          salitem_T tsal;

          // Move entry with same index byte after the entries
          // we already found.
          i++;
          n--;
          tsal = smp[i + n];
          memmove(smp + i + 1, smp + i, sizeof(salitem_T) * (size_t)n);
          smp[i] = tsal;
        }
      }
    }
  }
}

// Turn a multi-byte string into a wide character string.
// Return it in allocated memory.
static int *mb_str2wide(char_u *s)
{
  int i = 0;

  int *res = xmalloc(((size_t)mb_charlen(s) + 1) * sizeof(int));
  for (char_u *p = s; *p != NUL;) {
    res[i++] = mb_ptr2char_adv((const char_u **)&p);
  }
  res[i] = NUL;

  return res;
}

/// Reads a tree from the .spl or .sug file.
/// Allocates the memory and stores pointers in "bytsp" and "idxsp".
/// This is skipped when the tree has zero length.
///
/// @param prefixtree  true for the prefix tree
/// @param prefixcnt  when "prefixtree" is true: prefix count
///
/// @return  zero when OK, SP_ value for an error.
static int spell_read_tree(FILE *fd, char_u **bytsp, long *bytsp_len, idx_T **idxsp,
                           bool prefixtree, int prefixcnt)
  FUNC_ATTR_NONNULL_ARG(1, 2, 4)
{
  int idx;
  char_u *bp;
  idx_T *ip;

  // The tree size was computed when writing the file, so that we can
  // allocate it as one long block. <nodecount>
  long len = get4c(fd);
  if (len < 0) {
    return SP_TRUNCERROR;
  }
  if ((size_t)len >= SIZE_MAX / sizeof(int)) {  // -V547
    // Invalid length, multiply with sizeof(int) would overflow.
    return SP_FORMERROR;
  }
  if (len > 0) {
    // Allocate the byte array.
    bp = xmalloc((size_t)len);
    *bytsp = bp;
    if (bytsp_len != NULL) {
      *bytsp_len = len;
    }

    // Allocate the index array.
    ip = xcalloc((size_t)len, sizeof(*ip));
    *idxsp = ip;

    // Recursively read the tree and store it in the array.
    idx = read_tree_node(fd, bp, ip, (int)len, 0, prefixtree, prefixcnt);
    if (idx < 0) {
      return idx;
    }
  }
  return 0;
}

/// Read one row of siblings from the spell file and store it in the byte array
/// "byts" and index array "idxs".  Recursively read the children.
///
/// NOTE: The code here must match put_node()!
///
/// Returns the index (>= 0) following the siblings.
/// Returns SP_TRUNCERROR if the file is shorter than expected.
/// Returns SP_FORMERROR if there is a format error.
///
/// @param maxidx  size of arrays
/// @param startidx  current index in "byts" and "idxs"
/// @param prefixtree  true for reading PREFIXTREE
/// @param maxprefcondnr  maximum for <prefcondnr>
static idx_T read_tree_node(FILE *fd, char_u *byts, idx_T *idxs, int maxidx, idx_T startidx,
                            bool prefixtree, int maxprefcondnr)
{
  int len;
  int i;
  int n;
  idx_T idx = startidx;
  int c;
  int c2;
#define SHARED_MASK     0x8000000

  len = getc(fd);                                       // <siblingcount>
  if (len <= 0) {
    return SP_TRUNCERROR;
  }

  if (startidx + len >= maxidx) {
    return SP_FORMERROR;
  }
  byts[idx++] = (char_u)len;

  // Read the byte values, flag/region bytes and shared indexes.
  for (i = 1; i <= len; i++) {
    c = getc(fd);                                       // <byte>
    if (c < 0) {
      return SP_TRUNCERROR;
    }
    if (c <= BY_SPECIAL) {
      if (c == BY_NOFLAGS && !prefixtree) {
        // No flags, all regions.
        idxs[idx] = 0;
      } else if (c != BY_INDEX) {
        if (prefixtree) {
          // Read the optional pflags byte, the prefix ID and the
          // condition nr.  In idxs[] store the prefix ID in the low
          // byte, the condition index shifted up 8 bits, the flags
          // shifted up 24 bits.
          if (c == BY_FLAGS) {
            c = getc(fd) << 24;                         // <pflags>
          } else {
            c = 0;
          }

          c |= getc(fd);                                // <affixID>

          n = get2c(fd);                                // <prefcondnr>
          if (n >= maxprefcondnr) {
            return SP_FORMERROR;
          }
          c |= (n << 8);
        } else {    // c must be BY_FLAGS or BY_FLAGS2
                    // Read flags and optional region and prefix ID.  In
                    // idxs[] the flags go in the low two bytes, region above
                    // that and prefix ID above the region.
          c2 = c;
          c = getc(fd);                                 // <flags>
          if (c2 == BY_FLAGS2) {
            c = (getc(fd) << 8) + c;                    // <flags2>
          }
          if (c & WF_REGION) {
            c = (getc(fd) << 16) + c;                   // <region>
          }
          if (c & WF_AFX) {
            c = (getc(fd) << 24) + c;                   // <affixID>
          }
        }

        idxs[idx] = c;
        c = 0;
      } else {  // c == BY_INDEX
        // <nodeidx>
        n = get3c(fd);
        if (n < 0 || n >= maxidx) {
          return SP_FORMERROR;
        }
        idxs[idx] = n + SHARED_MASK;
        c = getc(fd);                                   // <xbyte>
      }
    }
    byts[idx++] = (char_u)c;
  }

  // Recursively read the children for non-shared siblings.
  // Skip the end-of-word ones (zero byte value) and the shared ones (and
  // remove SHARED_MASK)
  for (i = 1; i <= len; i++) {
    if (byts[startidx + i] != 0) {
      if (idxs[startidx + i] & SHARED_MASK) {
        idxs[startidx + i] &= ~SHARED_MASK;
      } else {
        idxs[startidx + i] = idx;
        idx = read_tree_node(fd, byts, idxs, maxidx, idx,
                             prefixtree, maxprefcondnr);
        if (idx < 0) {
          break;
        }
      }
    }
  }

  return idx;
}

// Functions for ":mkspell".

// In the postponed prefixes tree wn_flags is used to store the WFP_ flags,
// but it must be negative to indicate the prefix tree to tree_add_word().
// Use a negative number with the lower 8 bits zero.
#define PFX_FLAGS       (-256)

// flags for "condit" argument of store_aff_word()
#define CONDIT_COMB     1       // affix must combine
#define CONDIT_CFIX     2       // affix must have CIRCUMFIX flag
#define CONDIT_SUF      4       // add a suffix for matching flags
#define CONDIT_AFF      8       // word already has an affix

// Tunable parameters for when the tree is compressed.  Filled from the
// 'mkspellmem' option.
static long compress_start = 30000;     // memory / SBLOCKSIZE
static long compress_inc = 100;         // memory / SBLOCKSIZE
static long compress_added = 500000;    // word count

// Check the 'mkspellmem' option.  Return FAIL if it's wrong.
// Sets "sps_flags".
int spell_check_msm(void)
{
  char *p = p_msm;
  long start = 0;
  long incr = 0;
  long added = 0;

  if (!ascii_isdigit(*p)) {
    return FAIL;
  }
  // block count = (value * 1024) / SBLOCKSIZE (but avoid overflow)
  start = (getdigits_long(&p, true, 0) * 10) / (SBLOCKSIZE / 102);
  if (*p != ',') {
    return FAIL;
  }
  p++;
  if (!ascii_isdigit(*p)) {
    return FAIL;
  }
  incr = (getdigits_long(&p, true, 0) * 102) / (SBLOCKSIZE / 10);
  if (*p != ',') {
    return FAIL;
  }
  p++;
  if (!ascii_isdigit(*p)) {
    return FAIL;
  }
  added = getdigits_long(&p, true, 0) * 1024;
  if (*p != NUL) {
    return FAIL;
  }

  if (start == 0 || incr == 0 || added == 0 || incr > start) {
    return FAIL;
  }

  compress_start = start;
  compress_inc = incr;
  compress_added = added;
  return OK;
}

#ifdef SPELL_PRINTTREE
// For debugging the tree code: print the current tree in a (more or less)
// readable format, so that we can see what happens when adding a word and/or
// compressing the tree.
// Based on code from Olaf Seibert.
# define PRINTLINESIZE   1000
# define PRINTWIDTH      6

# define PRINTSOME(l, depth, fmt, a1, a2) vim_snprintf(l + depth * PRINTWIDTH, \
                                                       PRINTLINESIZE - PRINTWIDTH * depth, fmt, a1, \
                                                       a2)

static char line1[PRINTLINESIZE];
static char line2[PRINTLINESIZE];
static char line3[PRINTLINESIZE];

static void spell_clear_flags(wordnode_T *node)
{
  wordnode_T *np;

  for (np = node; np != NULL; np = np->wn_sibling) {
    np->wn_u1.index = false;
    spell_clear_flags(np->wn_child);
  }
}

static void spell_print_node(wordnode_T *node, int depth)
{
  if (node->wn_u1.index) {
    // Done this node before, print the reference.
    PRINTSOME(line1, depth, "(%d)", node->wn_nr, 0);
    PRINTSOME(line2, depth, "    ", 0, 0);
    PRINTSOME(line3, depth, "    ", 0, 0);
    msg((char_u *)line1);
    msg((char_u *)line2);
    msg((char_u *)line3);
  } else {
    node->wn_u1.index = true;

    if (node->wn_byte != NUL) {
      if (node->wn_child != NULL) {
        PRINTSOME(line1, depth, " %c -> ", node->wn_byte, 0);
      } else {
        // Cannot happen?
        PRINTSOME(line1, depth, " %c ???", node->wn_byte, 0);
      }
    } else {
      PRINTSOME(line1, depth, " $    ", 0, 0);
    }

    PRINTSOME(line2, depth, "%d/%d    ", node->wn_nr, node->wn_refs);

    if (node->wn_sibling != NULL) {
      PRINTSOME(line3, depth, " |    ", 0, 0);
    } else {
      PRINTSOME(line3, depth, "      ", 0, 0);
    }

    if (node->wn_byte == NUL) {
      msg((char_u *)line1);
      msg((char_u *)line2);
      msg((char_u *)line3);
    }

    // do the children
    if (node->wn_byte != NUL && node->wn_child != NULL) {
      spell_print_node(node->wn_child, depth + 1);
    }

    // do the siblings
    if (node->wn_sibling != NULL) {
      // get rid of all parent details except |
      STRCPY(line1, line3);
      STRCPY(line2, line3);
      spell_print_node(node->wn_sibling, depth);
    }
  }
}

static void spell_print_tree(wordnode_T *root)
{
  if (root != NULL) {
    // Clear the "wn_u1.index" fields, used to remember what has been
    // done.
    spell_clear_flags(root);

    // Recursively print the tree.
    spell_print_node(root, 0);
  }
}

#endif  // SPELL_PRINTTREE

/// Return true if "word" contains valid word characters.
/// Control characters and trailing '/' are invalid.  Space is OK.
static bool valid_spell_word(const char *word, const char *end)
{
  if (!utf_valid_string((char_u *)word, (char_u *)end)) {
    return false;
  }
  for (const char *p = word; *p != NUL && p < end; p += utfc_ptr2len(p)) {
    if ((uint8_t)(*p) < ' ' || (p[0] == '/' && p[1] == NUL)) {
      return false;
    }
  }
  return true;
}

// ":mkspell [-ascii] outfile  infile ..."
// ":mkspell [-ascii] addfile"
void ex_mkspell(exarg_T *eap)
{
  emsg("mkspell is now deprecated");
}

// ":[count]spellgood  {word}"
// ":[count]spellwrong {word}"
// ":[count]spellundo  {word}"
// ":[count]spellrare  {word}"
void ex_spell(exarg_T *eap)
{
  spell_add_word((char_u *)eap->arg, (int)strlen(eap->arg),
                 eap->cmdidx == CMD_spellwrong ? SPELL_ADD_BAD :
                 eap->cmdidx == CMD_spellrare ? SPELL_ADD_RARE : SPELL_ADD_GOOD,
                 eap->forceit ? 0 : (int)eap->line2,
                 eap->cmdidx == CMD_spellundo);
}

void spell_hunspell_format_dic(const char *path)
{
  kvec_t(char *) words = KV_INITIAL_VALUE;
  char line[MAXWLEN * 2];
  FILE *fd = os_fopen(path, "r+");

  bool first_line = true;
  if (fd != NULL) {
    // First read the amount of lines
    while (!vim_fgets((char_u *)line, MAXWLEN * 2, fd)) {
      if (first_line && *line >= '0' && *line <= '9') {
        // Ignore the first line
        // TODO(vigoux): maybe use that to reserve the correct amount of memory
        // for the words array ?
        first_line = false;
      } else if (STRLEN(line) > 1 && *line != '#') {
        kv_push(words, xstrdup(line));
      }
    }

    if (fseek(fd, 0, SEEK_SET) != 0) {
      PERROR(_("Seek error in spellfile"));
      return;
    }
    fprintf(fd, "%lu\n", kv_size(words));
    for (size_t i = 0; i < kv_size(words); i++) {
      fprintf(fd, "%s", kv_A(words, i));
      xfree(kv_A(words, i));
    }

    fclose(fd);
    kv_destroy(words);
  }
}

/// Add "word[len]" to 'spellfile' as a good or bad word.
///
/// @param what  SPELL_ADD_ values
/// @param idx  "zG" and "zW": zero, otherwise index in 'spellfile'
/// @param bool  // true for "zug", "zuG", "zuw" and "zuW"
void spell_add_word(char_u *word, int len, SpellAddType what, int idx, bool undo)
{
  FILE *fd = NULL;
  buf_T *buf = NULL;
  bool new_spf = false;
  char *fname;
  char_u *fnamebuf = NULL;
  char_u line[MAXWLEN * 2];
  long fpos, fpos_next = 0;
  int i;
  char_u *spf;

  if (!valid_spell_word((char *)word, (char *)word + len)) {
    emsg(_(e_illegal_character_in_word));
    return;
  }

  if (idx == 0) {           // use internal wordlist
    if (int_wordlist == NULL) {
      int_wordlist = (char_u *)vim_tempname();
      if (int_wordlist == NULL) {
        return;
      }
    }
    fname = (char *)int_wordlist;
  } else {
    // If 'spellfile' isn't set figure out a good default value.
    if (*curwin->w_s->b_p_spf == NUL) {
      init_spellfile();
      new_spf = true;
    }

    if (*curwin->w_s->b_p_spf == NUL) {
      semsg(_(e_notset), "spellfile");
      return;
    }
    fnamebuf = xmalloc(MAXPATHL);

    for (spf = (char_u *)curwin->w_s->b_p_spf, i = 1; *spf != NUL; i++) {
      copy_option_part((char **)&spf, (char *)fnamebuf, MAXPATHL, ",");
      if (i == idx) {
        break;
      }
      if (*spf == NUL) {
        semsg(_("E765: 'spellfile' does not have %" PRId64 " entries"), (int64_t)idx);
        xfree(fnamebuf);
        return;
      }
    }

    // Check that the user isn't editing the .add file somewhere.
    buf = buflist_findname_exp((char *)fnamebuf);
    if (buf != NULL && buf->b_ml.ml_mfp == NULL) {
      buf = NULL;
    }
    if (buf != NULL && bufIsChanged(buf)) {
      emsg(_(e_bufloaded));
      xfree(fnamebuf);
      return;
    }

    fname = (char *)fnamebuf;
  }

  if (what == SPELL_ADD_BAD || undo) {
    // When the word appears as good word we need to remove that one,
    // since its flags sort before the one with WF_BANNED.
    fd = os_fopen(fname, "r");
    if (fd != NULL) {
      while (!vim_fgets(line, MAXWLEN * 2, fd)) {
        fpos = fpos_next;
        fpos_next = ftell(fd);
        if (fpos_next < 0) {
          break;  // should never happen
        }
        if (STRNCMP(word, line, len) == 0
            && (line[len] == '/' || line[len] < ' ')) {
          // Found duplicate word.  Remove it by writing a '#' at
          // the start of the line.  Mixing reading and writing
          // doesn't work for all systems, close the file first.
          fclose(fd);
          fd = os_fopen(fname, "r+");
          if (fd == NULL) {
            break;
          }
          if (fseek(fd, fpos, SEEK_SET) == 0) {
            fputc('#', fd);
            if (undo) {
              home_replace(NULL, fname, (char *)NameBuff, MAXPATHL, true);
              smsg(_("Word '%.*s' removed from %s"), len, word, NameBuff);
            }
          }
          if (fseek(fd, fpos_next, SEEK_SET) != 0) {
            PERROR(_("Seek error in spellfile"));
            break;
          }
        }
      }
      if (fd != NULL) {
        fclose(fd);
      }
    }
  }

  if (!undo) {
    fd = os_fopen(fname, "a");
    if (fd == NULL && new_spf) {
      char_u *p;

      // We just initialized the 'spellfile' option and can't open the
      // file.  We may need to create the "spell" directory first.  We
      // already checked the runtime directory is writable in
      // init_spellfile().
      if (!dir_of_file_exists((char_u *)fname)
          && (p = (char_u *)path_tail_with_sep(fname)) != (char_u *)fname) {
        int c = *p;

        // The directory doesn't exist.  Try creating it and opening
        // the file again.
        *p = NUL;
        os_mkdir(fname, 0755);
        *p = (char_u)c;
        fd = os_fopen(fname, "a");
      }
    }

    if (fd == NULL) {
      semsg(_(e_notopen), fname);
    } else {
      // TODO(vigoux): for spo=hunspell the ?/! is recognized only if it is set
      // accordingly in the affix file. So either we'll have to
      if (what == SPELL_ADD_BAD) {
        fprintf(fd, "%.*s/!\n", len, word);
      } else if (what == SPELL_ADD_RARE) {
        fprintf(fd, "%.*s/?\n", len, word);
      } else {
        fprintf(fd, "%.*s\n", len, word);
      }
      fclose(fd);

      home_replace(NULL, fname, (char *)NameBuff, MAXPATHL, true);
      smsg(_("Word '%.*s' added to %s"), len, word, NameBuff);
    }
  }

  if (fd != NULL) {
    // Update the spellchecking
    if (idx == 0) {
      // When `zG` or `zW` add the word to the internal word list
      for (int lpi = 0; lpi < curwin->w_s->b_langp.ga_len; lpi++) {
        langp_T *lp = LANGP_ENTRY(curwin->w_s->b_langp, lpi);
        if (lp->lp_slang->sl_hunspell != NULL) {
          // TODO(vigoux): When adding a bad word, we'll have to remove
          // instead of add
          hunspell_add_word(lp->lp_slang->sl_hunspell, (char *)word);
        }
      }
    } else {
      spell_hunspell_format_dic(fname);
      spell_reload();
    }

    // If the .add file is edited somewhere, reload it.
    if (buf != NULL) {
      buf_reload(buf, buf->b_orig_mode, false);
    }

    redraw_all_later(UPD_SOME_VALID);
  }
  xfree(fnamebuf);
}

// Initialize 'spellfile' for the current buffer.
static void init_spellfile(void)
{
  char_u *buf;
  int l;
  char_u *rtp;
  char_u *lend;
  bool aspath = false;
  char_u *lstart = (char_u *)curbuf->b_s.b_p_spl;

  if (*curwin->w_s->b_p_spl != NUL && !GA_EMPTY(&curwin->w_s->b_langp)) {
    buf = xmalloc(MAXPATHL);

    // Find the end of the language name.  Exclude the region.  If there
    // is a path separator remember the start of the tail.
    for (lend = (char_u *)curwin->w_s->b_p_spl; *lend != NUL
         && vim_strchr(",._", *lend) == NULL; lend++) {
      if (vim_ispathsep(*lend)) {
        aspath = true;
        lstart = lend + 1;
      }
    }

    // Loop over all entries in 'runtimepath'.  Use the first one where we
    // are allowed to write.
    rtp = (char_u *)p_rtp;
    while (*rtp != NUL) {
      if (aspath) {
        // Use directory of an entry with path, e.g., for
        // "/dir/lg.utf-8.spl" use "/dir".
        STRLCPY(buf, curbuf->b_s.b_p_spl, lstart - (char_u *)curbuf->b_s.b_p_spl);
      } else {
        // Copy the path from 'runtimepath' to buf[].
        copy_option_part((char **)&rtp, (char *)buf, MAXPATHL, ",");
      }
      if (os_file_is_writable((char *)buf) == 2) {
        // Use the first language name from 'spelllang' and the
        // encoding used in the first loaded .spl file.
        if (aspath) {
          STRLCPY(buf, curbuf->b_s.b_p_spl, lend - (char_u *)curbuf->b_s.b_p_spl + 1);
        } else {
          // Create the "spell" directory if it doesn't exist yet.
          l = (int)STRLEN(buf);
          vim_snprintf((char *)buf + l, MAXPATHL - (size_t)l, "/spell");
          if (os_file_is_writable((char *)buf) != 2) {
            os_mkdir((char *)buf, 0755);
          }

          l = (int)STRLEN(buf);
          vim_snprintf((char *)buf + l, MAXPATHL - (size_t)l,
                       "/%.*s", (int)(lend - lstart), lstart);
        }
        l = (int)STRLEN(buf);

        vim_snprintf((char *)buf + l, MAXPATHL - (size_t)l, ".add");
        set_option_value_give_err("spellfile", 0L, (const char *)buf, OPT_LOCAL);
        break;
      }
      aspath = false;
    }

    xfree(buf);
  }
}

/// Set the spell character tables from strings in the .spl file.
///
/// @param cnt  length of "flags"
static void set_spell_charflags(char_u *flags, int cnt, char_u *fol)
{
  // We build the new tables here first, so that we can compare with the
  // previous one.
  spelltab_T new_st;
  int i;
  char_u *p = fol;
  int c;

  clear_spell_chartab(&new_st);

  for (i = 0; i < 128; i++) {
    if (i < cnt) {
      new_st.st_isw[i + 128] = (flags[i] & CF_WORD) != 0;
      new_st.st_isu[i + 128] = (flags[i] & CF_UPPER) != 0;
    }

    if (*p != NUL) {
      c = mb_ptr2char_adv((const char_u **)&p);
      new_st.st_fold[i + 128] = (char_u)c;
      if (i + 128 != c && new_st.st_isu[i + 128] && c < 256) {
        new_st.st_upper[c] = (char_u)(i + 128);
      }
    }
  }

  (void)set_spell_finish(&new_st);
}

static int set_spell_finish(spelltab_T *new_st)
{
  int i;

  if (did_set_spelltab) {
    // check that it's the same table
    for (i = 0; i < 256; i++) {
      if (spelltab.st_isw[i] != new_st->st_isw[i]
          || spelltab.st_isu[i] != new_st->st_isu[i]
          || spelltab.st_fold[i] != new_st->st_fold[i]
          || spelltab.st_upper[i] != new_st->st_upper[i]) {
        emsg(_("E763: Word characters differ between spell files"));
        return FAIL;
      }
    }
  } else {
    // copy the new spelltab into the one being used
    spelltab = *new_st;
    did_set_spelltab = true;
  }

  return OK;
}

// Use map string "map" for languages "lp".
static void set_map_str(slang_T *lp, char_u *map)
{
  char_u *p;
  int headc = 0;
  int c;
  int i;

  if (*map == NUL) {
    lp->sl_has_map = false;
    return;
  }
  lp->sl_has_map = true;

  // Init the array and hash tables empty.
  for (i = 0; i < 256; i++) {
    lp->sl_map_array[i] = 0;
  }
  hash_init(&lp->sl_map_hash);

  // The similar characters are stored separated with slashes:
  // "aaa/bbb/ccc/".  Fill sl_map_array[c] with the character before c and
  // before the same slash.  For characters above 255 sl_map_hash is used.
  for (p = map; *p != NUL;) {
    c = mb_cptr2char_adv((const char_u **)&p);
    if (c == '/') {
      headc = 0;
    } else {
      if (headc == 0) {
        headc = c;
      }

      // Characters above 255 don't fit in sl_map_array[], put them in
      // the hash table.  Each entry is the char, a NUL the headchar and
      // a NUL.
      if (c >= 256) {
        int cl = utf_char2len(c);
        int headcl = utf_char2len(headc);
        hash_T hash;
        hashitem_T *hi;

        char *b = xmalloc((size_t)(cl + headcl) + 2);
        utf_char2bytes(c, b);
        b[cl] = NUL;
        utf_char2bytes(headc, b + cl + 1);
        b[cl + 1 + headcl] = NUL;
        hash = hash_hash((char_u *)b);
        hi = hash_lookup(&lp->sl_map_hash, (const char *)b, strlen(b), hash);
        if (HASHITEM_EMPTY(hi)) {
          hash_add_item(&lp->sl_map_hash, hi, (char_u *)b, hash);
        } else {
          // This should have been checked when generating the .spl
          // file.
          emsg(_("E783: duplicate char in MAP entry"));
          xfree(b);
        }
      } else {
        lp->sl_map_array[c] = headc;
      }
    }
  }
}
