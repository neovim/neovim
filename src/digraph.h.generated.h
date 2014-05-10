void ex_loadkeymap(exarg_T *eap);
char_u *keymap_init(void);
void listdigraphs(void);
void putdigraph(char_u *str);
int getdigraph(int char1, int char2, int meta_char);
int get_digraph(int cmdline);
int do_digraph(int c);
