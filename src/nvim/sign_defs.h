#ifndef NVIM_SIGN_DEFS_H
#define NVIM_SIGN_DEFS_H

#include <stdbool.h>
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
    int id;                 // unique identifier for each placed sign
    int typenr;             // typenr of sign
    int priority;           // priority for highlighting
    bool has_text_or_icon;  // has text or icon
    linenr_T lnum;          // line number which has this sign
    signgroup_T *group;     // sign group
    signlist_T *next;       // next signlist entry
    signlist_T *prev;       // previous entry -- for easy reordering
};

/// Sign attributes. Used by the screen refresh routines.
typedef struct sign_attrs_S {
    int     typenr;
    char_u *text;
    int     texthl;
    int     linehl;
    int     numhl;
} sign_attrs_T;

#define SIGN_SHOW_MAX 9

// Default sign priority for highlighting
#define SIGN_DEF_PRIO 10

// type argument for sign_get_attr()
typedef enum {
  SIGN_LINEHL,
  SIGN_NUMHL,
  SIGN_TEXT,
} SignType;



#endif // NVIM_SIGN_DEFS_H
