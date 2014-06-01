#ifndef NVIM_TAG_H
#define NVIM_TAG_H

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
