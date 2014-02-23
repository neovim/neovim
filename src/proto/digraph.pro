/* digraph.c */
int do_digraph(int c);
int get_digraph(int cmdline);
int getdigraph(int char1, int char2, int meta_char);
void putdigraph(char_u *str);
void listdigraphs(void);
char_u *keymap_init(void);
void ex_loadkeymap(exarg_T *eap);
/* vim: set ft=c : */
