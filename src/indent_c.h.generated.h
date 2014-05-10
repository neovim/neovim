pos_T * find_start_comment(int ind_maxcomment);
void parse_cino(buf_T *buf);
void do_c_expr_indent(void);
int get_c_indent(void);
int cin_is_cinword(char_u *line);
int cin_isscopedecl(char_u *s);
int cin_iscase(char_u *s, int strict);
int cin_islabel(void);
