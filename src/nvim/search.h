#ifndef NVIM_SEARCH_H
#define NVIM_SEARCH_H

#include <stdbool.h>
#include <stdint.h>

#include "nvim/vim.h"
#include "nvim/buffer_defs.h"
#include "nvim/eval/typval.h"
#include "nvim/normal.h"
#include "nvim/os/time.h"

/* Values for the find_pattern_in_path() function args 'type' and 'action': */
#define FIND_ANY        1
#define FIND_DEFINE     2
#define CHECK_PATH      3

#define ACTION_SHOW     1
#define ACTION_GOTO     2
#define ACTION_SPLIT    3
#define ACTION_SHOW_ALL 4
#define ACTION_EXPAND   5

// Values for 'options' argument in do_search() and searchit()
#define SEARCH_REV    0x01  ///< go in reverse of previous dir.
#define SEARCH_ECHO   0x02  ///< echo the search command and handle options
#define SEARCH_MSG    0x0c  ///< give messages (yes, it's not 0x04)
#define SEARCH_NFMSG  0x08  ///< give all messages except not found
#define SEARCH_OPT    0x10  ///< interpret optional flags
#define SEARCH_HIS    0x20  ///< put search pattern in history
#define SEARCH_END    0x40  ///< put cursor at end of match
#define SEARCH_NOOF   0x80  ///< don't add offset to position
#define SEARCH_START 0x100  ///< start search without col offset
#define SEARCH_MARK  0x200  ///< set previous context mark
#define SEARCH_KEEP  0x400  ///< keep previous search pattern
#define SEARCH_PEEK  0x800  ///< peek for typed char, cancel search
#define SEARCH_COL  0x1000  ///< start at specified column instead of zero

/* Values for flags argument for findmatchlimit() */
#define FM_BACKWARD     0x01    /* search backwards */
#define FM_FORWARD      0x02    /* search forwards */
#define FM_BLOCKSTOP    0x04    /* stop at start/end of block */
#define FM_SKIPCOMM     0x08    /* skip comments */

/* Values for sub_cmd and which_pat argument for search_regcomp() */
/* Also used for which_pat argument for searchit() */
#define RE_SEARCH       0       /* save/use pat in/from search_pattern */
#define RE_SUBST        1       /* save/use pat in/from subst_pattern */
#define RE_BOTH         2       /* save pat in both patterns */
#define RE_LAST         2       /* use last used pattern if "pat" is NULL */

/// Structure containing offset definition for the last search pattern
///
/// @note Only offset for the last search pattern is used, not for the last
///       substitute pattern.
typedef struct soffset {
  char dir;     ///< Search direction: forward ('/') or backward ('?')
  bool line;    ///< True if search has line offset.
  bool end;     ///< True if search sets cursor at the end.
  int64_t off;  ///< Actual offset value.
} SearchOffset;

/// Structure containing last search pattern and its attributes.
typedef struct spat {
  char_u *pat;          ///< The pattern (in allocated memory) or NULL.
  bool magic;           ///< Magicness of the pattern.
  bool no_scs;          ///< No smartcase for this pattern.
  Timestamp timestamp;  ///< Time of the last change.
  SearchOffset off;     ///< Pattern offset.
  dict_T *additional_data;  ///< Additional data from ShaDa file.
} SearchPattern;

/// Optional extra arguments for searchit().
typedef struct {
    linenr_T    sa_stop_lnum;  ///< stop after this line number when != 0
    proftime_T  *sa_tm;        ///< timeout limit or NULL
    int         sa_timed_out;  ///< set when timed out
    int         sa_wrapped;    ///< search wrapped around
} searchit_arg_T;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "search.h.generated.h"
#endif
#endif  // NVIM_SEARCH_H
