#ifndef NVIM_SIGN_DEFS_H
#define NVIM_SIGN_DEFS_H

#include "nvim/pos.h"
#include "nvim/types.h"

// signs: line annotations

// Sign group
typedef struct signgroup_S
{
    uint16_t  refcount;   // number of signs in this group
    int next_sign_id;     // next sign id for this group
    char_u  sg_name[1];   // sign group name
} signgroup_T;

// Macros to get the sign group structure from the group name
#define SGN_KEY_OFF offsetof(signgroup_T, sg_name)
#define HI2SG(hi) ((signgroup_T *)((hi)->hi_key - SGN_KEY_OFF))

typedef struct signlist signlist_T;

struct signlist
{
    int id;              // unique identifier for each placed sign
    linenr_T lnum;       // line number which has this sign
    int typenr;          // typenr of sign
    signgroup_T *group;  // sign group
    int priority;        // priority for highlighting
    signlist_T *next;    // next signlist entry
    signlist_T *prev;    // previous entry -- for easy reordering
};

// Default sign priority for highlighting
#define SIGN_DEF_PRIO 10

// type argument for buf_getsigntype() and sign_get_attr()
typedef enum {
  SIGN_ANY,
  SIGN_LINEHL,
  SIGN_ICON,
  SIGN_TEXT,
  SIGN_NUMHL,
} SignType;



#endif // NVIM_SIGN_DEFS_H
