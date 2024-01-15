#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "nvim/buffer_defs.h"

enum {
  /// Assume max. word len is this many bytes.
  /// Some places assume a word length fits in a byte, thus it can't be above 255.
  MAXWLEN = 254,
};

enum { MAXREGIONS = 8, };  ///< Number of regions supported.

/// Type used for indexes in the word tree need to be at least 4 bytes.  If int
/// is 8 bytes we could use something smaller, but what?
typedef int idx_T;

#define SPL_FNAME_TMPL  "%s.%s.spl"
#define SPL_FNAME_ADD   ".add."
#define SPL_FNAME_ASCII ".ascii."

/// Flags used for a word.  Only the lowest byte can be used, the region byte
/// comes above it.
enum {
  WF_REGION  = 0x01,  ///< region byte follows
  WF_ONECAP  = 0x02,  ///< word with one capital (or all capitals)
  WF_ALLCAP  = 0x04,  ///< word must be all capitals
  WF_RARE    = 0x08,  ///< rare word
  WF_BANNED  = 0x10,  ///< bad word
  WF_AFX     = 0x20,  ///< affix ID follows
  WF_FIXCAP  = 0x40,  ///< keep-case word, allcap not allowed
  WF_KEEPCAP = 0x80,  ///< keep-case word
  WF_CAPMASK = (WF_ONECAP | WF_ALLCAP | WF_KEEPCAP | WF_FIXCAP),
};

/// for <flags2>, shifted up one byte to be used in wn_flags
enum {
  WF_HAS_AFF   = 0x0100,  ///< word includes affix
  WF_NEEDCOMP  = 0x0200,  ///< word only valid in compound
  WF_NOSUGGEST = 0x0400,  ///< word not to be suggested
  WF_COMPROOT  = 0x0800,  ///< already compounded word, COMPOUNDROOT
  WF_NOCOMPBEF = 0x1000,  ///< no compounding before this word
  WF_NOCOMPAFT = 0x2000,  ///< no compounding after this word
};

/// flags for <pflags>
enum {
  WFP_RARE       = 0x01,  ///< rare prefix
  WFP_NC         = 0x02,  ///< prefix is not combining
  WFP_UP         = 0x04,  ///< to-upper prefix
  WFP_COMPPERMIT = 0x08,  ///< prefix with COMPOUNDPERMITFLAG
  WFP_COMPFORBID = 0x10,  ///< prefix with COMPOUNDFORBIDFLAG
};

/// Flags for postponed prefixes in "sl_pidxs".  Must be above affixID (one
/// byte) and prefcondnr (two bytes).
enum {
  WF_RAREPFX        = WFP_RARE << 24,        ///< rare postponed prefix
  WF_PFX_NC         = WFP_NC << 24,          ///< non-combining postponed prefix
  WF_PFX_UP         = WFP_UP << 24,          ///< to-upper postponed prefix
  WF_PFX_COMPPERMIT = WFP_COMPPERMIT << 24,  ///< postponed prefix with COMPOUNDPERMITFLAG
  WF_PFX_COMPFORBID = WFP_COMPFORBID << 24,  ///< postponed prefix with COMPOUNDFORBIDFLAG
};

/// flags for <compoptions>
enum {
  COMP_CHECKDUP    = 1,  ///< CHECKCOMPOUNDDUP
  COMP_CHECKREP    = 2,  ///< CHECKCOMPOUNDREP
  COMP_CHECKCASE   = 4,  ///< CHECKCOMPOUNDCASE
  COMP_CHECKTRIPLE = 8,  ///< CHECKCOMPOUNDTRIPLE
};

/// Info from "REP", "REPSAL" and "SAL" entries in ".aff" file used in si_rep,
/// si_repsal, sl_rep, and si_sal.  Not for sl_sal!
/// One replacement: from "ft_from" to "ft_to".
typedef struct {
  char *ft_from;
  char *ft_to;
} fromto_T;

/// Info from "SAL" entries in ".aff" file used in sl_sal.
/// The info is split for quick processing by spell_soundfold().
/// Note that "sm_oneof" and "sm_rules" point into sm_lead.
typedef struct {
  char *sm_lead;    ///< leading letters
  int sm_leadlen;   ///< length of "sm_lead"
  char *sm_oneof;   ///< letters from () or NULL
  char *sm_rules;   ///< rules like ^, $, priority
  char *sm_to;      ///< replacement.
  int *sm_lead_w;   ///< wide character copy of "sm_lead"
  int *sm_oneof_w;  ///< wide character copy of "sm_oneof"
  int *sm_to_w;     ///< wide character copy of "sm_to"
} salitem_T;

typedef int salfirst_T;

/// Values for SP_*ERROR are negative, positive values are used by
/// read_cnt_string().
enum {
  SP_TRUNCERROR = -1,  ///< spell file truncated error
  SP_FORMERROR  = -2,  ///< format error in spell file
  SP_OTHERERROR = -3,  ///< other error while reading spell file
};

/// Structure used to store words and other info for one language, loaded from
/// a .spl file.
/// The main access is through the tree in "sl_fbyts/sl_fidxs", storing the
/// case-folded words.  "sl_kbyts/sl_kidxs" is for keep-case words.
///
/// The "byts" array stores the possible bytes in each tree node, preceded by
/// the number of possible bytes, sorted on byte value:
///      <len> <byte1> <byte2> ...
/// The "idxs" array stores the index of the child node corresponding to the
/// byte in "byts".
/// Exception: when the byte is zero, the word may end here and "idxs" holds
/// the flags, region mask and affixID for the word.  There may be several
/// zeros in sequence for alternative flag/region/affixID combinations.
typedef struct slang_S slang_T;

struct slang_S {
  slang_T *sl_next;   ///< next language
  char *sl_name;      ///< language name "en", "en.rare", "nl", etc.
  char *sl_fname;     ///< name of .spl file
  bool sl_add;        ///< true if it's a .add file.

  uint8_t *sl_fbyts;  ///< case-folded word bytes
  int sl_fbyts_len;   ///< length of sl_fbyts
  idx_T *sl_fidxs;    ///< case-folded word indexes
  uint8_t *sl_kbyts;  ///< keep-case word bytes
  idx_T *sl_kidxs;    ///< keep-case word indexes
  uint8_t *sl_pbyts;  ///< prefix tree word bytes
  idx_T *sl_pidxs;    ///< prefix tree word indexes

  char *sl_info;      ///< infotext string or NULL

  /// table with up to 8 region names plus NUL
  char sl_regions[MAXREGIONS * 2 + 1];

  char *sl_midword;              ///< MIDWORD string or NULL

  hashtab_T sl_wordcount;        ///< hashtable with word count, wordcount_T

  int sl_compmax;                ///< COMPOUNDWORDMAX (default: MAXWLEN)
  int sl_compminlen;             ///< COMPOUNDMIN (default: 0)
  int sl_compsylmax;             ///< COMPOUNDSYLMAX (default: MAXWLEN)
  int sl_compoptions;            ///< COMP_* flags
  garray_T sl_comppat;           ///< CHECKCOMPOUNDPATTERN items
  regprog_T *sl_compprog;        ///< COMPOUNDRULE turned into a regexp progrm
                                 ///< (NULL when no compounding)
  uint8_t *sl_comprules;         ///< all COMPOUNDRULE concatenated (or NULL)
  uint8_t *sl_compstartflags;    ///< flags for first compound word
  uint8_t *sl_compallflags;      ///< all flags for compound words
  bool sl_nobreak;               ///< When true: no spaces between words
  char *sl_syllable;             ///< SYLLABLE repeatable chars or NULL
  garray_T sl_syl_items;         ///< syllable items

  int sl_prefixcnt;              ///< number of items in "sl_prefprog"
  regprog_T **sl_prefprog;       ///< table with regprogs for prefixes

  garray_T sl_rep;               ///< list of fromto_T entries from REP lines
  int16_t sl_rep_first[256];     ///< indexes where byte first appears, -1 if there is none
  garray_T sl_sal;               ///< list of salitem_T entries from SAL lines
  salfirst_T sl_sal_first[256];  ///< indexes where byte first appears, -1 if there is none
  bool sl_followup;              ///< SAL followup
  bool sl_collapse;              ///< SAL collapse_result
  bool sl_rem_accents;           ///< SAL remove_accents
  bool sl_sofo;                  ///< SOFOFROM and SOFOTO instead of SAL items:
                                 ///< "sl_sal_first" maps chars
                                 ///< "sl_sal" is a list of wide char lists.
  garray_T sl_repsal;            ///< list of fromto_T entries from REPSAL lines
  int16_t sl_repsal_first[256];  ///< sl_rep_first for REPSAL lines
  bool sl_nosplitsugs;           ///< don't suggest splitting a word
  bool sl_nocompoundsugs;        ///< don't suggest compounding

  // Info from the .sug file.  Loaded on demand.
  time_t sl_sugtime;       ///< timestamp for .sug file
  uint8_t *sl_sbyts;       ///< soundfolded word bytes
  idx_T *sl_sidxs;         ///< soundfolded word indexes
  buf_T *sl_sugbuf;        ///< buffer with word number table
  bool sl_sugloaded;       ///< true when .sug file was loaded or failed to load

  bool sl_has_map;         ///< true, if there is a MAP line
  hashtab_T sl_map_hash;   ///< MAP for multi-byte chars
  int sl_map_array[256];   ///< MAP for first 256 chars
  hashtab_T sl_sounddone;  ///< table with soundfolded words that have
                           ///< handled, see add_sound_suggest()
};

/// Structure used in "b_langp", filled from 'spelllang'.
typedef struct {
  slang_T *lp_slang;    ///< info for this language
  slang_T *lp_sallang;  ///< language used for sound folding or NULL
  slang_T *lp_replang;  ///< language used for REP items or NULL
  int lp_region;        ///< bitmask for region or REGION_ALL
} langp_T;

#define LANGP_ENTRY(ga, i)      (((langp_T *)(ga).ga_data) + (i))

#define VIMSUGMAGIC "VIMsug"    // string at start of Vim .sug file
#define VIMSUGMAGICL 6
#define VIMSUGVERSION 1

enum { REGION_ALL = 0xff, };  ///< word valid in all regions

/// The tables used for recognizing word characters according to spelling.
/// These are only used for the first 256 characters of 'encoding'.
typedef struct {
  bool st_isw[256];       ///< flags: is word char
  bool st_isu[256];       ///< flags: is uppercase char
  uint8_t st_fold[256];   ///< chars: folded case
  uint8_t st_upper[256];  ///< chars: upper case
} spelltab_T;

/// Values for "what" argument of spell_add_word()
typedef enum {
  SPELL_ADD_GOOD = 0,
  SPELL_ADD_BAD = 1,
  SPELL_ADD_RARE = 2,
} SpellAddType;

typedef struct {
  uint16_t wc_count;  ///< nr of times word was seen
  char wc_word[];     ///< word
} wordcount_T;

#define WC_KEY_OFF   offsetof(wordcount_T, wc_word)
#define HI2WC(hi)    ((wordcount_T *)((hi)->hi_key - WC_KEY_OFF))
enum { MAXWORDCOUNT = 0xffff, };
