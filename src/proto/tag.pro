/* tag.c */
int do_tag __ARGS((char_u *tag, int type, int count, int forceit, int verbose));
void tag_freematch __ARGS((void));
void do_tags __ARGS((exarg_T *eap));
int find_tags __ARGS((char_u *pat, int *num_matches, char_u ***matchesp,
                      int flags, int mincount,
                      char_u *buf_ffname));
void free_tag_stuff __ARGS((void));
int get_tagfname __ARGS((tagname_T *tnp, int first, char_u *buf));
void tagname_free __ARGS((tagname_T *tnp));
void simplify_filename __ARGS((char_u *filename));
int expand_tags __ARGS((int tagnames, char_u *pat, int *num_file,
                        char_u ***file));
int get_tags __ARGS((list_T *list, char_u *pat));
/* vim: set ft=c : */
