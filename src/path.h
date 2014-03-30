#ifndef NEOVIM_PATH_H
#define NEOVIM_PATH_H
int vim_ispathsep(int c);
int vim_ispathsep_nocolon(int c);
int vim_ispathlistsep(int c);
void shorten_dir(char_u *str);
int dir_of_file_exists(char_u *fname);
int vim_fnamecmp(char_u *x, char_u *y);
int vim_fnamencmp(char_u *x, char_u *y, size_t len);
char_u *concat_fnames(char_u *fname1, char_u *fname2, int sep);
int unix_expandpath(garray_T *gap, char_u *path, int wildoff, int flags,
                    int didstar);
int gen_expand_wildcards(int num_pat, char_u **pat, int *num_file,
                         char_u ***file,
                         int flags);
void addfile(garray_T *gap, char_u *f, int flags);
int fullpathcmp(char_u *s1, char_u *s2, int checkname);
char_u *gettail(char_u *fname);
char_u *gettail_sep(char_u *fname);
char_u *getnextcomp(char_u *fname);
char_u *get_past_head(char_u *path);
char_u *concat_str(char_u *str1, char_u *str2);
void add_pathsep(char_u *p);
char_u *FullName_save(char_u *fname, int force);
void simplify_filename(char_u *filename);
char_u *find_file_name_in_path(char_u *ptr, int len, int options,
                               long count,
                               char_u *rel_fname);
int path_is_url(char_u *p);
int path_with_url(char_u *fname);
int vim_isAbsName(char_u *name);
int vim_FullName(char_u *fname, char_u *buf, int len, int force);
char_u *fix_fname(char_u *fname);
#endif
