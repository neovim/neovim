#ifndef NEOVIM_STRINGS_H
#define NEOVIM_STRINGS_H
char_u *vim_strsave(char_u *string);
char_u *vim_strnsave(char_u *string, int len);
char_u *vim_strsave_escaped(char_u *string, char_u *esc_chars);
char_u *vim_strsave_escaped_ext(char_u *string, char_u *esc_chars,
                                int cc,
                                int bsl);
char_u *vim_strsave_shellescape(char_u *string, bool do_special, bool do_newline);
char_u *vim_strsave_up(char_u *string);
char_u *vim_strnsave_up(char_u *string, int len);
void vim_strup(char_u *p);
char_u *strup_save(char_u *orig);
void copy_spaces(char_u *ptr, size_t count);
void copy_chars(char_u *ptr, size_t count, int c);
void del_trailing_spaces(char_u *ptr);
void vim_strncpy(char_u *to, char_u *from, size_t len);
void vim_strcat(char_u *to, char_u *from, size_t tosize);
int vim_stricmp(char *s1, char *s2);
int vim_strnicmp(char *s1, char *s2, size_t len);
char_u *vim_strchr(char_u *string, int c);
char_u *vim_strbyte(char_u *string, int c);
char_u *vim_strrchr(char_u *string, int c);
int vim_isspace(int x);
void sort_strings(char_u **files, int count);
char_u *concat_str(char_u *str1, char_u *str2);
#endif
