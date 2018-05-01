#ifndef NVIM_SYNTAX_DEFS_H
#define NVIM_SYNTAX_DEFS_H

#include "nvim/highlight_defs.h"

# define SST_MIN_ENTRIES 150    /* minimal size for state stack array */
# define SST_MAX_ENTRIES 1000   /* maximal size for state stack array */
# define SST_FIX_STATES  7      /* size of sst_stack[]. */
# define SST_DIST        16     /* normal distance between entries */
# define SST_INVALID    (synstate_T *)-1        /* invalid syn_state pointer */

typedef struct syn_state synstate_T;

#include "nvim/buffer_defs.h"
#include "nvim/regexp_defs.h"

typedef unsigned short disptick_T;      /* display tick type */

/* struct passed to in_id_list() */
struct sp_syn {
  int inc_tag;                  /* ":syn include" unique tag */
  short id;                     /* highlight group ID of item */
  short       *cont_in_list;    /* cont.in group IDs, if non-zero */
};

/*
 * Each keyword has one keyentry, which is linked in a hash list.
 */
typedef struct keyentry keyentry_T;

struct keyentry {
  keyentry_T  *ke_next;         /* next entry with identical "keyword[]" */
  struct sp_syn k_syn;          /* struct passed to in_id_list() */
  short       *next_list;       /* ID list for next match (if non-zero) */
  int flags;
  int k_char;                   /* conceal substitute character */
  char_u keyword[1];            /* actually longer */
};

/*
 * Struct used to store one state of the state stack.
 */
typedef struct buf_state {
  int bs_idx;                    /* index of pattern */
  int bs_flags;                  /* flags for pattern */
  int bs_seqnr;                  /* stores si_seqnr */
  int bs_cchar;                  /* stores si_cchar */
  reg_extmatch_T *bs_extmatch;   /* external matches from start pattern */
} bufstate_T;

/*
 * syn_state contains the syntax state stack for the start of one line.
 * Used by b_sst_array[].
 */
struct syn_state {
  synstate_T  *sst_next;        /* next entry in used or free list */
  linenr_T sst_lnum;            /* line number for this state */
  union {
    bufstate_T sst_stack[SST_FIX_STATES];          /* short state stack */
    garray_T sst_ga;            /* growarray for long state stack */
  } sst_union;
  int sst_next_flags;           /* flags for sst_next_list */
  int sst_stacksize;            /* number of states on the stack */
  short       *sst_next_list;   /* "nextgroup" list in this state
                                 * (this is a copy, don't free it! */
  disptick_T sst_tick;          /* tick when last displayed */
  linenr_T sst_change_lnum;     /* when non-zero, change in this line
                                 * may have made the state invalid */
};

#endif // NVIM_SYNTAX_DEFS_H
