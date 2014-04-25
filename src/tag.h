#ifndef NEOVIM_TAG_H
#define NEOVIM_TAG_H

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

int do_tag(char_u *tag, int type, int count, int forceit, int verbose);
void tag_freematch(void);
void do_tags(exarg_T *eap);
int find_tags(char_u *pat, int *num_matches, char_u ***matchesp,
              int flags, int mincount,
              char_u *buf_ffname);
void free_tag_stuff(void);
int get_tagfname(tagname_T *tnp, int first, char_u *buf);
void tagname_free(tagname_T *tnp);
int expand_tags(int tagnames, char_u *pat, int *num_file,
                char_u ***file);
int get_tags(list_T *list, char_u *pat);

#endif /* NEOVIM_TAG_H */
