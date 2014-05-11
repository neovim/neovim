#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
FileComparison path_full_compare(char_u *s1, char_u *s2, int checkname);
char_u *path_tail(char_u *fname);
char_u *path_tail_with_sep(char_u *fname);
char_u *path_next_component(char_u *fname);
char_u *get_past_head(char_u *path);
int vim_ispathsep(int c);
int vim_ispathsep_nocolon(int c);
int vim_ispathlistsep(int c);
void shorten_dir(char_u *str);
int dir_of_file_exists(char_u *fname);
int vim_fnamecmp(char_u *x, char_u *y);
int vim_fnamencmp(char_u *x, char_u *y, size_t len);
char_u *concat_fnames(char_u *fname1, char_u *fname2, int sep) FUNC_ATTR_NONNULL_RET;
void add_pathsep(char_u *p);
char_u *FullName_save(char_u *fname, int force);
int unix_expandpath(garray_T *gap, char_u *path, int wildoff, int flags, int didstar);
int gen_expand_wildcards(int num_pat, char_u **pat, int *num_file, char_u ***file, int flags);
void addfile(garray_T *gap, char_u *f, int flags);
void simplify_filename(char_u *filename);
char_u *find_file_name_in_path(char_u *ptr, int len, int options, long count, char_u *rel_fname);
int path_is_url(char_u *p);
int path_with_url(char_u *fname);
int vim_isAbsName(char_u *name);
int vim_FullName(char_u *fname, char_u *buf, int len, int force);
char_u *fix_fname(char_u *fname);
int after_pathsep(char_u *b, char_u *p);
int same_directory(char_u *f1, char_u *f2);
int pathcmp(const char *p, const char *q, int maxlen);
char_u *path_shorten_fname_if_possible(char_u *full_path);
char_u *path_shorten_fname(char_u *full_path, char_u *dir_name);
int expand_wildcards_eval(char_u **pat, int *num_file, char_u ***file, int flags);
int expand_wildcards(int num_pat, char_u **pat, int *num_file, char_u ***file, int flags);
int match_suffix(char_u *fname);
int path_full_dir_name(char *directory, char *buffer, int len);
int append_path(char *path, const char *to_append, int max_len);
int path_is_absolute_path(const char_u *fname);
#include "func_attr.h"
int mch_expandpath(garray_T *gap, char_u *path, int flags);
