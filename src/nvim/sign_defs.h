#ifndef NVIM_SIGN_DEFS_H
#define NVIM_SIGN_DEFS_H

#include "nvim/pos.h"

// signs: line annotations

typedef struct signlist signlist_T;

struct signlist
{
    int id;             // unique identifier for each placed sign
    linenr_T lnum;      // line number which has this sign
    int typenr;         // typenr of sign
    signlist_T *next;   // next signlist entry
    signlist_T *prev;   // previous entry -- for easy reordering
};

// type argument for buf_getsigntype() and sign_get_attr()
typedef enum {
  SIGN_ANY,
  SIGN_LINEHL,
  SIGN_ICON,
  SIGN_TEXT,
  SIGN_NUMHL,
} SignType;



#endif // NVIM_SIGN_DEFS_H
