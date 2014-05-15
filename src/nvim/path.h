#ifndef NVIM_PATH_H
#define NVIM_PATH_H

#include "nvim/func_attr.h"
#include "nvim/types.h"
#include "nvim/garray.h"

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
char_u *concat_fnames(char_u *fname1, char_u *fname2, int sep)
  FUNC_ATTR_NONNULL_RET;
int unix_expandpath(garray_T *gap, char_u *path, int wildoff, int flags,
                    int didstar);
int gen_expand_wildcards(int num_pat, char_u **pat, int *num_file,
                         char_u ***file,
                         int flags);
void addfile(garray_T *gap, char_u *f, int flags);
char_u *get_past_head(char_u *path);
char_u *concat_str(char_u *str1, char_u *str2) FUNC_ATTR_NONNULL_RET;
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

/// Try to find a shortname by comparing the fullname with the current
/// directory.
///
/// @param full_path The full path of the file.
/// @return
///   - Pointer into `full_path` if shortened.
///   - `full_path` unchanged if no shorter name is possible.
///   - NULL if `full_path` is NULL.
char_u *path_shorten_fname_if_possible(char_u *full_path);

/// Try to find a shortname by comparing the fullname with `dir_name`.
///
/// @param full_path The full path of the file.
/// @param dir_name The directory to shorten relative to.
/// @return
///   - Pointer into `full_path` if shortened.
///   - NULL if no shorter name is possible.
char_u *path_shorten_fname(char_u *full_path, char_u *dir_name);

int expand_wildcards_eval(char_u **pat, int *num_file, char_u ***file,
                          int flags);
int expand_wildcards(int num_pat, char_u **pat, int *num_file, char_u *
                     **file,
                     int flags);
int match_suffix(char_u *fname);

/// Get the absolute name of the given relative directory.
///
/// @param directory Directory name, relative to current directory.
/// @return `FAIL` for failure, `OK` for success.
int path_full_dir_name(char *directory, char *buffer, int len);

// Append to_append to path with a slash in between.
int append_path(char *path, const char *to_append, int max_len);

/// Check if the given file is absolute.
///
/// This just checks if the file name starts with '/' or '~'.
/// @return `TRUE` if "fname" is absolute.
int path_is_absolute_path(const char_u *fname);

#endif
