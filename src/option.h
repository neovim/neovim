#ifndef NEOVIM_OPTION_H
#define NEOVIM_OPTION_H
/* option.c */
void set_init_1 __ARGS((void));
void set_string_default __ARGS((char *name, char_u *val));
void set_number_default __ARGS((char *name, long val));
void free_all_options __ARGS((void));
void set_init_2 __ARGS((void));
void set_init_3 __ARGS((void));
void set_helplang_default __ARGS((char_u *lang));
void init_gui_options __ARGS((void));
void set_title_defaults __ARGS((void));
int do_set __ARGS((char_u *arg, int opt_flags));
void set_options_bin __ARGS((int oldval, int newval, int opt_flags));
int get_viminfo_parameter __ARGS((int type));
char_u *find_viminfo_parameter __ARGS((int type));
void check_options __ARGS((void));
void check_buf_options __ARGS((buf_T *buf));
void free_string_option __ARGS((char_u *p));
void clear_string_option __ARGS((char_u **pp));
void set_term_option_alloced __ARGS((char_u **p));
int was_set_insecurely __ARGS((char_u *opt, int opt_flags));
void set_string_option_direct __ARGS((char_u *name, int opt_idx, char_u *val,
                                      int opt_flags,
                                      int set_sid));
char_u *check_colorcolumn __ARGS((win_T *wp));
char_u *check_stl_option __ARGS((char_u *s));
int get_option_value __ARGS((char_u *name, long *numval, char_u **stringval,
                             int opt_flags));
int get_option_value_strict __ARGS((char_u *name, long *numval, char_u *
                                    *stringval, int opt_type,
                                    void *from));
char_u *option_iter_next __ARGS((void **option, int opt_type));
char_u *set_option_value __ARGS((char_u *name, long number, char_u *string,
                                 int opt_flags));
char_u *get_term_code __ARGS((char_u *tname));
char_u *get_highlight_default __ARGS((void));
char_u *get_encoding_default __ARGS((void));
int makeset __ARGS((FILE *fd, int opt_flags, int local_only));
int makefoldset __ARGS((FILE *fd));
void clear_termoptions __ARGS((void));
void free_termoptions __ARGS((void));
void free_one_termoption __ARGS((char_u *var));
void set_term_defaults __ARGS((void));
void comp_col __ARGS((void));
void unset_global_local_option __ARGS((char_u *name, void *from));
char_u *get_equalprg __ARGS((void));
void win_copy_options __ARGS((win_T *wp_from, win_T *wp_to));
void copy_winopt __ARGS((winopt_T *from, winopt_T *to));
void check_win_options __ARGS((win_T *win));
void check_winopt __ARGS((winopt_T *wop));
void clear_winopt __ARGS((winopt_T *wop));
void buf_copy_options __ARGS((buf_T *buf, int flags));
void reset_modifiable __ARGS((void));
void set_iminsert_global __ARGS((void));
void set_imsearch_global __ARGS((void));
void set_context_in_set_cmd __ARGS((expand_T *xp, char_u *arg, int opt_flags));
int ExpandSettings __ARGS((expand_T *xp, regmatch_T *regmatch, int *num_file,
                           char_u ***file));
int ExpandOldSetting __ARGS((int *num_file, char_u ***file));
int langmap_adjust_mb __ARGS((int c));
int has_format_option __ARGS((int x));
int shortmess __ARGS((int x));
void vimrc_found __ARGS((char_u *fname, char_u *envname));
void change_compatible __ARGS((int on));
int option_was_set __ARGS((char_u *name));
void reset_option_was_set __ARGS((char_u *name));
int can_bs __ARGS((int what));
void save_file_ff __ARGS((buf_T *buf));
int file_ff_differs __ARGS((buf_T *buf, int ignore_empty));
int check_ff_value __ARGS((char_u *p));
long get_sw_value __ARGS((buf_T *buf));
long get_sts_value __ARGS((void));
void find_mps_values __ARGS((int *initc, int *findc, int *backwards,
                             int switchit));
/* vim: set ft=c : */
#endif /* NEOVIM_OPTION_H */
