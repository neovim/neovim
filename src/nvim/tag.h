#ifndef NVIM_TAG_H
#define NVIM_TAG_H

#include "nvim/types.h"
#include "nvim/ex_cmds_defs.h"

/*
 * Values for do_tag().
 */
#define DT_TAG          1       /* jump to newer position or same tag again */
#define DT_POP          2       /* jump to older position */
#define DT_NEXT         3       /* jump to next match of same tag */
#define DT_PREV         4       /* jump to previous match of same tag */
#define DT_FIRST        5       /* jump to first match of same tag */
#define DT_LAST         6       /* jump to first match of same tag */
#define DT_SELECT       7       /* jump to selection from list */
#define DT_HELP         8       /* like DT_TAG, but no wildcards */
#define DT_JUMP         9       /* jump to new tag or selection from list */
#define DT_CSCOPE       10      /* cscope find command (like tjump) */
#define DT_LTAG         11      /* tag using location list */
#define DT_FREE         99      /* free cached matches */

/*
 * flags for find_tags().
 */
#define TAG_HELP        1       /* only search for help tags */
#define TAG_NAMES       2       /* only return name of tag */
#define TAG_REGEXP      4       /* use tag pattern as regexp */
#define TAG_NOIC        8       /* don't always ignore case */
#define TAG_CSCOPE      16      /* cscope tag */
#define TAG_VERBOSE     32      /* message verbosity */
#define TAG_INS_COMP    64      /* Currently doing insert completion */
#define TAG_KEEP_LANG   128     /* keep current language */

#define TAG_MANY        300     /* When finding many tags (for completion),
                                   find up to this many tags */

/*
 * Structure used for get_tagfname().
 */
typedef struct {
  char_u      *tn_tags;         /* value of 'tags' when starting */
  char_u      *tn_np;           /* current position in tn_tags */
  int tn_did_filefind_init;
  int tn_hf_idx;
  void        *tn_search_ctx;
} tagname_T;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tag.h.generated.h"
#endif
#endif  // NVIM_TAG_H
