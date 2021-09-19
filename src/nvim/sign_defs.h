#ifndef NVIM_SIGN_DEFS_H
#define NVIM_SIGN_DEFS_H

#include <stdbool.h>
#include "nvim/pos.h"
#include "nvim/types.h"

// signs: line annotations

// Sign group
typedef struct signgroup_S
{
    uint16_t sg_refcount;      // number of signs in this group
    int      sg_next_sign_id;  // next sign id for this group
    char_u   sg_name[1];       // sign group name
} signgroup_T;

// Macros to get the sign group structure from the group name
#define SGN_KEY_OFF offsetof(signgroup_T, sg_name)
#define HI2SG(hi) ((signgroup_T *)((hi)->hi_key - SGN_KEY_OFF))

typedef struct sign_entry sign_entry_T;

struct sign_entry {
    int           se_id;               // unique identifier for each placed sign
    int           se_typenr;           // typenr of sign
    int           se_priority;         // priority for highlighting
    bool          se_has_text_or_icon;  // has text or icon
    linenr_T      se_lnum;             // line number which has this sign
    signgroup_T  *se_group;            // sign group
    sign_entry_T *se_next;             // next entry in a list of signs
    sign_entry_T *se_prev;             // previous entry -- for easy reordering
};

/// Sign attributes. Used by the screen refresh routines.
typedef struct sign_attrs_S {
    int     sat_typenr;
    char_u *sat_text;
    int     sat_texthl;
    int     sat_linehl;
    int     sat_numhl;
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
