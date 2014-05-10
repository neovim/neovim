int get_tags(list_T *list, char_u *pat);
int expand_tags(int tagnames, char_u *pat, int *num_file,
                char_u ***file);
void tagname_free(tagname_T *tnp);
int get_tagfname(tagname_T *tnp, int first, char_u *buf);
int find_tags(char_u *pat, int *num_matches, char_u ***matchesp,
              int flags, int mincount,
              char_u *buf_ffname);
void do_tags(exarg_T *eap);
void tag_freematch(void);
int do_tag(char_u *tag, int type, int count, int forceit, int verbose);
void free_tag_stuff(void);
