#ifndef NEOVIM_PATH_H
#define NEOVIM_PATH_H

/// Return value for the comparison of two files. Also @see path_full_compare.
typedef enum file_comparison {
  kEqualFiles = 1,        ///< Both exist and are the same file.
  kDifferentFiles = 2,    ///< Both exist and are different files.
  kBothFilesMissing = 4,  ///< Both don't exist.
  kOneFileMissing = 6,    ///< One of them doesn't exist.
  kEqualFileNames = 7     ///< Both don't exist and file names are same.
} FileComparison;

/// Compare two file names.
///
/// @param s1 First file name. Environment variables in this name will be
///   expanded.
/// @param s2 Second file name.
/// @param checkname When both files don't exist, only compare their names.
/// @return Enum of type FileComparison. @see FileComparison.
FileComparison path_full_compare(char_u *s1, char_u *s2, int checkname);

/// Get the tail of a path: the file name.
/// 
/// @param fname A file path.
/// @return
///   - Empty string, if fname is NULL.
///   - The position of the last path separator + 1. (i.e. empty string, if
///   fname ends in a slash).
///   - Never NULL.
char_u *path_tail(char_u *fname);

/// Get pointer to tail of "fname", including path separators.
///
/// Takes care of "c:/" and "//". That means `path_tail_with_sep("dir///file.txt")`
/// will return a pointer to `"///file.txt"`.
/// @param fname A file path. (Must be != NULL.)
/// @return
///   - Pointer to the last path separator of `fname`, if there is any.
///   - `fname` if it contains no path separator.
///   - Never NULL.
char_u *path_tail_with_sep(char_u *fname);

/// Get the next path component of a path name.
///
/// @param fname A file path. (Must be != NULL.)
/// @return Pointer to first found path separator + 1.
/// An empty string, if `fname` doesn't contain a path separator, 
char_u *path_next_component(char_u *fname);

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
int after_pathsep(char_u *b, char_u *p);
int same_directory(char_u *f1, char_u *f2);
int pathcmp(const char *p, const char *q, int maxlen);
int mch_expandpath(garray_T *gap, char_u *path, int flags);
char_u *shorten_fname1(char_u *full_path);
char_u *shorten_fname(char_u *full_path, char_u *dir_name);
void shorten_filenames(char_u **fnames, int count);
int expand_wildcards_eval(char_u **pat, int *num_file, char_u ***file,
                          int flags);
int expand_wildcards(int num_pat, char_u **pat, int *num_file, char_u *
                     **file,
                     int flags);
int match_suffix(char_u *fname);
#endif
