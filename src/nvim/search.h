#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "nvim/eval/typval_defs.h"
#include "nvim/normal_defs.h"  // IWYU pragma: keep
#include "nvim/os/time_defs.h"
#include "nvim/pos_defs.h"
#include "nvim/regexp_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"  // IWYU pragma: keep

/// Values for the find_pattern_in_path() function args 'type' and 'action':
enum {
  FIND_ANY    = 1,
  FIND_DEFINE = 2,
  CHECK_PATH  = 3,
};

enum {
  ACTION_SHOW     = 1,
  ACTION_GOTO     = 2,
  ACTION_SPLIT    = 3,
  ACTION_SHOW_ALL = 4,
  ACTION_EXPAND   = 5,
};

/// Values for "options" argument in do_search() and searchit()
enum {
  SEARCH_REV   = 0x01,    ///< go in reverse of previous dir.
  SEARCH_ECHO  = 0x02,    ///< echo the search command and handle options
  SEARCH_MSG   = 0x0c,    ///< give messages (yes, it's not 0x04)
  SEARCH_NFMSG = 0x08,    ///< give all messages except not found
  SEARCH_OPT   = 0x10,    ///< interpret optional flags
  SEARCH_HIS   = 0x20,    ///< put search pattern in history
  SEARCH_END   = 0x40,    ///< put cursor at end of match
  SEARCH_NOOF  = 0x80,    ///< don't add offset to position
  SEARCH_START = 0x100,   ///< start search without col offset
  SEARCH_MARK  = 0x200,   ///< set previous context mark
  SEARCH_KEEP  = 0x400,   ///< keep previous search pattern
  SEARCH_PEEK  = 0x800,   ///< peek for typed char, cancel search
  SEARCH_COL   = 0x1000,  ///< start at specified column instead of zero
};

/// Values for flags argument for findmatchlimit()
enum {
  FM_BACKWARD  = 0x01,  ///< search backwards
  FM_FORWARD   = 0x02,  ///< search forwards
  FM_BLOCKSTOP = 0x04,  ///< stop at start/end of block
  FM_SKIPCOMM  = 0x08,  ///< skip comments
};

/// Values for sub_cmd and which_pat argument for search_regcomp()
/// Also used for which_pat argument for searchit()
enum {
  RE_SEARCH = 0,  ///< save/use pat in/from search_pattern
  RE_SUBST  = 1,  ///< save/use pat in/from subst_pattern
  RE_BOTH   = 2,  ///< save pat in both patterns
  RE_LAST   = 2,  ///< use last used pattern if "pat" is NULL
};

// Values for searchcount()
enum { SEARCH_STAT_DEF_TIMEOUT = 40, };
enum { SEARCH_STAT_DEF_MAX_COUNT = 99, };
enum { SEARCH_STAT_BUF_LEN = 12, };

enum {
  /// Maximum number of characters that can be fuzzy matched
  MAX_FUZZY_MATCHES = 256,
};

/// Structure containing offset definition for the last search pattern
///
/// @note Only offset for the last search pattern is used, not for the last
///       substitute pattern.
typedef struct {
  char dir;     ///< Search direction: forward ('/') or backward ('?')
  bool line;    ///< True if search has line offset.
  bool end;     ///< True if search sets cursor at the end.
  int64_t off;  ///< Actual offset value.
} SearchOffset;

/// Structure containing last search pattern and its attributes.
typedef struct {
  char *pat;            ///< The pattern (in allocated memory) or NULL.
  size_t patlen;        ///< The length of the pattern (0 if pat is NULL).
  bool magic;           ///< Magicness of the pattern.
  bool no_scs;          ///< No smartcase for this pattern.
  Timestamp timestamp;  ///< Time of the last change.
  SearchOffset off;     ///< Pattern offset.
  dict_T *additional_data;  ///< Additional data from ShaDa file.
} SearchPattern;

/// Optional extra arguments for searchit().
typedef struct {
  linenr_T sa_stop_lnum;  ///< stop after this line number when != 0
  proftime_T *sa_tm;        ///< timeout limit or NULL
  int sa_timed_out;  ///< set when timed out
  int sa_wrapped;    ///< search wrapped around
} searchit_arg_T;

typedef struct {
  int cur;      // current position of found words
  int cnt;      // total count of found words
  bool exact_match;    // true if matched exactly on specified position
  int incomplete;     // 0: search was fully completed
  // 1: recomputing was timed out
  // 2: max count exceeded
  int last_maxcount;  // the max count of the last search
} searchstat_T;

/// Fuzzy matched string list item. Used for fuzzy match completion. Items are
/// usually sorted by "score". The "idx" member is used for stable-sort.
typedef struct {
  int idx;
  char *str;
  int score;
} fuzmatch_str_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "search.h.generated.h"
#endif
