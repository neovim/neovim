#ifndef NVIM_SIGN_DEFS_H
#define NVIM_SIGN_DEFS_H

// signs: line annotations

typedef struct signlist signlist_T;

struct signlist
{
    int id;             /* unique identifier for each placed sign */
    linenr_T lnum;      /* line number which has this sign */
    int typenr;         /* typenr of sign */
    signlist_T *next;   /* next signlist entry */
};

/* type argument for buf_getsigntype() */
#define SIGN_ANY	0
#define SIGN_LINEHL	1
#define SIGN_ICON	2
#define SIGN_TEXT	3



#endif // NVIM_SIGN_DEFS_H
