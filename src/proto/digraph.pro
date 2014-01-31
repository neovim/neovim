/* digraph.c */
int do_digraph __ARGS((int c));
int get_digraph __ARGS((int cmdline));
int getdigraph __ARGS((int char1, int char2, int meta_char));
void putdigraph __ARGS((char_u *str));
void listdigraphs __ARGS((void));
char_u *keymap_init __ARGS((void));
void ex_loadkeymap __ARGS((exarg_T *eap));
/* vim: set ft=c : */
