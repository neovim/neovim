void farsi_fkey(cmdarg_T *cap);
int F_ischar(int c);
int F_isdigit(int c);
int F_isalpha(int c);
int cmdl_fkmap(int c);
char_u *lrF_sub(char_u *ibuf);
char_u *lrFswap(char_u *cmdbuf, int len);
char_u *lrswap(char_u *ibuf);
void conv_to_pstd(void);
void conv_to_pvim(void);
int fkmap(int c);
int toF_TyA(int c);
