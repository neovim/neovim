#include <assert.h>
#include <limits.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "auto/config.h"
#include "nvim/ascii_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand.h"
#include "nvim/eval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/file_search.h"
#include "nvim/fileio.h"
#include "nvim/garray.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/os/fs.h"
#include "nvim/os/fs_defs.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/os/shell.h"
#include "nvim/path.h"
#include "nvim/regexp.h"
#include "nvim/regexp_defs.h"
#include "nvim/strings.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

enum {
  URL_SLASH = 1,      // path_is_url() has found ":/"
  URL_BACKSLASH = 2,  // path_is_url() has found ":\\"
};

#ifdef gen_expand_wildcards
# undef gen_expand_wildcards
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "path.c.generated.h"
#endif

/// Compare two file names.
///
/// @param s1 First file name. Environment variables in this name will be
///   expanded.
/// @param s2 Second file name.
/// @param checkname When both files don't exist, only compare their names.
/// @param expandenv Whether to expand environment variables in file names.
/// @return Enum of type FileComparison. @see FileComparison.
FileComparison path_full_compare(char *const s1, char *const s2, const bool checkname,
                                 const bool expandenv)
{
  assert(s1 && s2);
  char exp1[MAXPATHL];
  char full1[MAXPATHL];
  char full2[MAXPATHL];
  FileID file_id_1, file_id_2;

  if (expandenv) {
    expand_env(s1, exp1, MAXPATHL);
  } else {
    xstrlcpy(exp1, s1, MAXPATHL);
  }
  bool id_ok_1 = os_fileid(exp1, &file_id_1);
  bool id_ok_2 = os_fileid(s2, &file_id_2);
  if (!id_ok_1 && !id_ok_2) {
    // If os_fileid() doesn't work, may compare the names.
    if (checkname) {
      vim_FullName(exp1, full1, MAXPATHL, false);
      vim_FullName(s2, full2, MAXPATHL, false);
      if (path_fnamecmp(full1, full2) == 0) {
        return kEqualFileNames;
      }
    }
    return kBothFilesMissing;
  }
  if (!id_ok_1 || !id_ok_2) {
    return kOneFileMissing;
  }
  if (os_fileid_equal(&file_id_1, &file_id_2)) {
    return kEqualFiles;
  }
  return kDifferentFiles;
}

/// Gets the tail (filename segment) of path `fname`.
///
/// Examples:
/// - "dir/file.txt" => "file.txt"
/// - "file.txt" => "file.txt"
/// - "dir/" => ""
///
/// @return pointer just past the last path separator (empty string, if fname
///         ends in a slash), or empty string if fname is NULL.
char *path_tail(const char *fname)
  FUNC_ATTR_NONNULL_RET
{
  if (fname == NULL) {
    return "";
  }

  const char *tail = get_past_head(fname);
  const char *p = tail;
  // Find last part of path.
  while (*p != NUL) {
    if (vim_ispathsep_nocolon(*p)) {
      tail = p + 1;
    }
    MB_PTR_ADV(p);
  }
  return (char *)tail;
}

/// Get pointer to tail of "fname", including path separators.
///
/// Takes care of "c:/" and "//". That means `path_tail_with_sep("dir///file.txt")`
/// will return a pointer to `"///file.txt"`.
/// @param fname A file path. (Must be != NULL.)
/// @return
///   - Pointer to the last path separator of `fname`, if there is any.
///   - `fname` if it contains no path separator.
///   - Never NULL.
char *path_tail_with_sep(char *fname)
{
  assert(fname != NULL);

  // Don't remove the '/' from "c:/file".
  char *past_head = get_past_head(fname);
  char *tail = path_tail(fname);
  while (tail > past_head && after_pathsep(fname, tail)) {
    tail--;
  }
  return tail;
}

/// Finds the path tail (or executable) in an invocation.
///
/// @param[in]  invocation A program invocation in the form:
///                        "path/to/exe [args]".
/// @param[out] len Stores the length of the executable name.
///
/// @post if `len` is not null, stores the length of the executable name.
///
/// @return The position of the last path separator + 1.
const char *invocation_path_tail(const char *invocation, size_t *len)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_NONNULL_ARG(1)
{
  const char *tail = get_past_head(invocation);
  const char *p = tail;
  while (*p != NUL && *p != ' ') {
    bool was_sep = vim_ispathsep_nocolon(*p);
    MB_PTR_ADV(p);
    if (was_sep) {
      tail = p;  // Now tail points one past the separator.
    }
  }

  if (len != NULL) {
    *len = (size_t)(p - tail);
  }

  return tail;
}

/// Get the next path component of a path name.
///
/// @param fname A file path. (Must be != NULL.)
/// @return Pointer to first found path separator + 1.
/// An empty string, if `fname` doesn't contain a path separator,
const char *path_next_component(const char *fname)
{
  assert(fname != NULL);
  while (*fname != NUL && !vim_ispathsep(*fname)) {
    MB_PTR_ADV(fname);
  }
  if (*fname != NUL) {
    fname++;
  }
  return fname;
}

/// Returns the length of the path head on the current platform.
/// @return
///   - 3 on windows
///   - 1 otherwise
int path_head_length(void)
{
#ifdef MSWIN
  return 3;
#else
  return 1;
#endif
}

/// Returns true if path begins with characters denoting the head of a path
/// (e.g. '/' on linux and 'D:' on windows).
/// @param path The path to be checked.
/// @return
///   - True if path begins with a path head
///   - False otherwise
bool is_path_head(const char *path)
{
#ifdef MSWIN
  return isalpha((uint8_t)path[0]) && path[1] == ':';
#else
  return vim_ispathsep(*path);
#endif
}

/// Get a pointer to one character past the head of a path name.
/// Unix: after "/"; Win: after "c:\"
/// If there is no head, path is returned.
char *get_past_head(const char *path)
{
  const char *retval = path;

#ifdef MSWIN
  // May skip "c:"
  if (is_path_head(path)) {
    retval = path + 2;
  }
#endif

  while (vim_ispathsep(*retval)) {
    retval++;
  }

  return (char *)retval;
}

/// @return true if 'c' is a path separator.
/// Note that for MS-Windows this includes the colon.
bool vim_ispathsep(int c)
{
#ifdef UNIX
  return c == '/';          // Unix has ':' inside file names
#else
# ifdef BACKSLASH_IN_FILENAME
  return c == ':' || c == '/' || c == '\\';
# else
  return c == ':' || c == '/';
# endif
#endif
}

// Like vim_ispathsep(c), but exclude the colon for MS-Windows.
bool vim_ispathsep_nocolon(int c)
{
  return vim_ispathsep(c)
#ifdef BACKSLASH_IN_FILENAME
         && c != ':'
#endif
  ;
}

/// @return true if 'c' is a path list separator.
bool vim_ispathlistsep(int c)
{
#ifdef UNIX
  return c == ':';
#else
  return c == ';';      // might not be right for every system...
#endif
}

/// Shorten the path of a file from "~/foo/../.bar/fname" to "~/f/../.b/fname"
/// "trim_len" specifies how many characters to keep for each directory.
/// Must be 1 or more.
/// It's done in-place.
void shorten_dir_len(char *str, int trim_len)
{
  char *tail = path_tail(str);
  char *d = str;
  bool skip = false;
  int dirchunk_len = 0;
  for (char *s = str;; s++) {
    if (s >= tail) {                // copy the whole tail
      *d++ = *s;
      if (*s == NUL) {
        break;
      }
    } else if (vim_ispathsep(*s)) {       // copy '/' and next char
      *d++ = *s;
      skip = false;
      dirchunk_len = 0;
    } else if (!skip) {
      *d++ = *s;                     // copy next char
      if (*s != '~' && *s != '.') {  // and leading "~" and "."
        dirchunk_len++;  // only count word chars for the size
        // keep copying chars until we have our preferred length (or
        // until the above if/else branches move us along)
        if (dirchunk_len >= trim_len) {
          skip = true;
        }
      }
      int l = utfc_ptr2len(s);
      while (--l > 0) {
        *d++ = *++s;
      }
    }
  }
}

/// Shorten the path of a file from "~/foo/../.bar/fname" to "~/f/../.b/fname"
/// It's done in-place.
void shorten_dir(char *str)
{
  shorten_dir_len(str, 1);
}

/// Return true if the directory of "fname" exists, false otherwise.
/// Also returns true if there is no directory name.
/// "fname" must be writable!.
bool dir_of_file_exists(char *fname)
{
  char *p = path_tail_with_sep(fname);
  if (p == fname) {
    return true;
  }
  char c = *p;
  *p = NUL;
  bool retval = os_isdir(fname);
  *p = c;
  return retval;
}

/// Compare two file names
///
/// On some systems case in a file name does not matter, on others it does.
///
/// @note Does not account for maximum name lengths and things like "../dir",
///       thus it is not 100% accurate. OS may also use different algorithm for
///       case-insensitive comparison.
///
/// Handles '/' and '\\' correctly and deals with &fileignorecase option.
///
/// @param[in]  fname1  First file name.
/// @param[in]  fname2  Second file name.
///
/// @return 0 if they are equal, non-zero otherwise.
int path_fnamecmp(const char *fname1, const char *fname2)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
#ifdef BACKSLASH_IN_FILENAME
  const size_t len1 = strlen(fname1);
  const size_t len2 = strlen(fname2);
  return path_fnamencmp(fname1, fname2, MAX(len1, len2));
#else
  return mb_strcmp_ic((bool)p_fic, fname1, fname2);
#endif
}

/// Compare two file names
///
/// Handles '/' and '\\' correctly and deals with &fileignorecase option.
///
/// @param[in]  fname1  First file name.
/// @param[in]  fname2  Second file name.
/// @param[in]  len  Compare at most len bytes.
///
/// @return 0 if they are equal, non-zero otherwise.
int path_fnamencmp(const char *const fname1, const char *const fname2, size_t len)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
#ifdef BACKSLASH_IN_FILENAME
  int c1 = NUL;
  int c2 = NUL;

  const char *p1 = fname1;
  const char *p2 = fname2;
  while (len > 0) {
    c1 = utf_ptr2char(p1);
    c2 = utf_ptr2char(p2);
    if ((c1 == NUL || c2 == NUL
         || (!((c1 == '/' || c1 == '\\') && (c2 == '\\' || c2 == '/'))))
        && (p_fic ? (c1 != c2 && CH_FOLD(c1) != CH_FOLD(c2)) : c1 != c2)) {
      break;
    }
    len -= (size_t)utfc_ptr2len(p1);
    p1 += utfc_ptr2len(p1);
    p2 += utfc_ptr2len(p2);
  }
  return p_fic ? CH_FOLD(c1) - CH_FOLD(c2) : c1 - c2;
#else
  if (p_fic) {
    return mb_strnicmp(fname1, fname2, len);
  }
  return strncmp(fname1, fname2, len);
#endif
}

/// Append fname2 to fname1
///
/// @param[in]  fname1  First fname to append to.
/// @param[in]  len1    Length of fname1.
/// @param[in]  fname2  Second part of the file name.
/// @param[in]  len2    Length of fname2.
/// @param[in]  sep     If true and fname1 does not end with a path separator,
///                     add a path separator before fname2.
///
/// @return fname1
static inline char *do_concat_fnames(char *fname1, const size_t len1, const char *fname2,
                                     const size_t len2, const bool sep)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  if (sep && *fname1 && !after_pathsep(fname1, fname1 + len1)) {
    fname1[len1] = PATHSEP;
    memmove(fname1 + len1 + 1, fname2, len2 + 1);
  } else {
    memmove(fname1 + len1, fname2, len2 + 1);
  }

  return fname1;
}

/// Concatenate file names fname1 and fname2 into allocated memory.
///
/// Only add a '/' or '\\' when 'sep' is true and it is necessary.
///
/// @param fname1 is the first part of the path or filename
/// @param fname2 is the second half of the path or filename
/// @param sep    is a flag to indicate a path separator should be added
///               if necessary
/// @return [allocated] Concatenation of fname1 and fname2.
char *concat_fnames(const char *fname1, const char *fname2, bool sep)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  const size_t len1 = strlen(fname1);
  const size_t len2 = strlen(fname2);
  char *dest = xmalloc(len1 + len2 + 3);
  memmove(dest, fname1, len1 + 1);
  return do_concat_fnames(dest, len1, fname2, len2, sep);
}

/// Concatenate file names fname1 and fname2
///
/// Like concat_fnames(), but in place of allocating new memory it reallocates
/// fname1. For this reason fname1 must be allocated with xmalloc, and can no
/// longer be used after running concat_fnames_realloc.
///
/// @param fname1 is the first part of the path or filename
/// @param fname2 is the second half of the path or filename
/// @param sep    is a flag to indicate a path separator should be added
///               if necessary
/// @return [allocated] Concatenation of fname1 and fname2.
char *concat_fnames_realloc(char *fname1, const char *fname2, bool sep)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  const size_t len1 = strlen(fname1);
  const size_t len2 = strlen(fname2);
  return do_concat_fnames(xrealloc(fname1, len1 + len2 + 3), len1,
                          fname2, len2, sep);
}

/// Adds a path separator to a filename, unless it already ends in one.
///
/// @return `true` if the path separator was added or already existed.
///         `false` if the filename is too long.
bool add_pathsep(char *p)
  FUNC_ATTR_NONNULL_ALL
{
  const size_t len = strlen(p);
  if (*p != NUL && !after_pathsep(p, p + len)) {
    const size_t pathsep_len = sizeof(PATHSEPSTR);
    if (len > MAXPATHL - pathsep_len) {
      return false;
    }
    memcpy(p + len, PATHSEPSTR, pathsep_len);
  }
  return true;
}

/// Get an allocated copy of the full path to a file.
///
/// @param fname is the filename to save
/// @param force is a flag to expand `fname` even if it looks absolute
///
/// @return [allocated] Copy of absolute path to `fname` or NULL when
///                     `fname` is NULL.
char *FullName_save(const char *fname, bool force)
  FUNC_ATTR_MALLOC
{
  if (fname == NULL) {
    return NULL;
  }

  char *buf = xmalloc(MAXPATHL);
  if (vim_FullName(fname, buf, MAXPATHL, force) == FAIL) {
    xfree(buf);
    return xstrdup(fname);
  }
  return buf;
}

/// Saves the absolute path.
/// @param name An absolute or relative path.
/// @return The absolute path of `name`.
char *save_abs_path(const char *name)
  FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  if (!path_is_absolute(name)) {
    return FullName_save(name, true);
  }
  return xstrdup(name);
}

/// Checks if a path has a wildcard character including '~', unless at the end.
/// @param p  The path to expand.
/// @returns Unix: True if it contains one of "?[{`'$".
/// @returns Windows: True if it contains one of "*?$[".
bool path_has_wildcard(const char *p)
  FUNC_ATTR_NONNULL_ALL
{
  for (; *p; MB_PTR_ADV(p)) {
#if defined(UNIX)
    if (p[0] == '\\' && p[1] != NUL) {
      p++;
      continue;
    }

    const char *wildcards = "*?[{`'$";
#else
    // Windows:
    const char *wildcards = "?*$[`";
#endif
    if (vim_strchr(wildcards, (uint8_t)(*p)) != NULL
        || (p[0] == '~' && p[1] != NUL)) {
      return true;
    }
  }
  return false;
}

// Unix style wildcard expansion code.
static int pstrcmp(const void *a, const void *b)
{
  return pathcmp(*(char **)a, *(char **)b, -1);
}

/// Checks if a path has a character path_expand can expand.
/// @param p  The path to expand.
/// @returns Unix: True if it contains one of *?[{.
/// @returns Windows: True if it contains one of *?[.
bool path_has_exp_wildcard(const char *p)
  FUNC_ATTR_NONNULL_ALL
{
  for (; *p != NUL; MB_PTR_ADV(p)) {
#if defined(UNIX)
    if (p[0] == '\\' && p[1] != NUL) {
      p++;
      continue;
    }

    const char *wildcards = "*?[{";
#else
    const char *wildcards = "*?[";  // Windows.
#endif
    if (vim_strchr(wildcards, (uint8_t)(*p)) != NULL) {
      return true;
    }
  }
  return false;
}

/// Recursively expands one path component into all matching files and/or
/// directories. Handles "*", "?", "[a-z]", "**", etc.
/// @remark "**" in `path` requests recursive expansion.
///
/// @param[out] gap  The matches found.
/// @param path     The path to search.
/// @param flags    Flags for regexp expansion.
///   - EW_ICASE: Ignore case.
///   - EW_NOERROR: Silence error messages.
///   - EW_NOTWILD: Add matches literally.
/// @returns the number of matches found.
static size_t path_expand(garray_T *gap, const char *path, int flags)
  FUNC_ATTR_NONNULL_ALL
{
  return do_path_expand(gap, path, 0, flags, false);
}

static const char *scandir_next_with_dots(Directory *dir)
{
  static int count = 0;
  if (dir == NULL) {  // initialize
    count = 0;
    return NULL;
  }

  count += 1;
  if (count == 1 || count == 2) {
    return (count == 1) ? "." : "..";
  }
  return os_scandir_next(dir);
}

/// Implementation of path_expand().
///
/// Chars before `path + wildoff` do not get expanded.
static size_t do_path_expand(garray_T *gap, const char *path, size_t wildoff, int flags,
                             bool didstar)
  FUNC_ATTR_NONNULL_ALL
{
  int start_len = gap->ga_len;
  size_t len;
  bool starstar = false;
  static int stardepth = 0;  // depth for "**" expansion

  // Expanding "**" may take a long time, check for CTRL-C.
  if (stardepth > 0 && !(flags & EW_NOBREAK)) {
    os_breakcheck();
    if (got_int) {
      return 0;
    }
  }

  // Make room for file name.  When doing encoding conversion the actual
  // length may be quite a bit longer, thus use the maximum possible length.
  char *buf = xmalloc(MAXPATHL);

  // Find the first part in the path name that contains a wildcard.
  // When EW_ICASE is set every letter is considered to be a wildcard.
  // Copy it into "buf", including the preceding characters.
  char *p = buf;
  char *s = buf;
  char *e = NULL;
  const char *path_end = path;
  while (*path_end != NUL) {
    // May ignore a wildcard that has a backslash before it; it will
    // be removed by rem_backslash() or file_pat_to_reg_pat() below.
    if (path_end >= path + wildoff && rem_backslash(path_end)) {
      *p++ = *path_end++;
    } else if (vim_ispathsep_nocolon(*path_end)) {
      if (e != NULL) {
        break;
      }
      s = p + 1;
    } else if (path_end >= path + wildoff
#ifdef MSWIN
               && vim_strchr("*?[~", (uint8_t)(*path_end)) != NULL
#else
               && (vim_strchr("*?[{~$", (uint8_t)(*path_end)) != NULL
                   || (!p_fic && (flags & EW_ICASE) && mb_isalpha(utf_ptr2char(path_end))))
#endif
               ) {
      e = p;
    }
    len = (size_t)(utfc_ptr2len(path_end));
    memcpy(p, path_end, len);
    p += len;
    path_end += len;
  }
  e = p;
  *e = NUL;

  // Now we have one wildcard component between "s" and "e".
  // Remove backslashes between "wildoff" and the start of the wildcard
  // component.
  for (p = buf + wildoff; p < s; p++) {
    if (rem_backslash(p)) {
      STRMOVE(p, p + 1);
      e--;
      s--;
    }
  }

  // Check for "**" between "s" and "e".
  for (p = s; p < e; p++) {
    if (p[0] == '*' && p[1] == '*') {
      starstar = true;
    }
  }

  // convert the file pattern to a regexp pattern
  int starts_with_dot = *s == '.';
  char *pat = file_pat_to_reg_pat(s, e, NULL, false);
  if (pat == NULL) {
    xfree(buf);
    return 0;
  }

  // compile the regexp into a program
  regmatch_T regmatch;
#if defined(UNIX)
  // Ignore case if given 'wildignorecase', else respect 'fileignorecase'.
  regmatch.rm_ic = (flags & EW_ICASE) || p_fic;
#else
  regmatch.rm_ic = true;  // Always ignore case on Windows.
#endif
  if (flags & (EW_NOERROR | EW_NOTWILD)) {
    emsg_silent++;
  }
  bool nobreak = (flags & EW_NOBREAK);
  regmatch.regprog = vim_regcomp(pat, RE_MAGIC | (nobreak ? RE_NOBREAK : 0));
  if (flags & (EW_NOERROR | EW_NOTWILD)) {
    emsg_silent--;
  }
  xfree(pat);

  if (regmatch.regprog == NULL && (flags & EW_NOTWILD) == 0) {
    xfree(buf);
    return 0;
  }

  // If "**" is by itself, this is the first time we encounter it and more
  // is following then find matches without any directory.
  if (!didstar && stardepth < 100 && starstar && e - s == 2
      && *path_end == '/') {
    STRCPY(s, path_end + 1);
    stardepth++;
    do_path_expand(gap, buf, (size_t)(s - buf), flags, true);
    stardepth--;
  }
  *s = NUL;

  Directory dir;
  char *dirpath = (*buf == NUL ? "." : buf);
  if (os_file_is_readable(dirpath) && os_scandir(&dir, dirpath)) {
    // Find all matching entries.
    const char *name;
    scandir_next_with_dots(NULL);  // initialize
    while (!got_int && (name = scandir_next_with_dots(&dir)) != NULL) {
      if ((name[0] != '.'
           || starts_with_dot
           || ((flags & EW_DODOT)
               && name[1] != NUL
               && (name[1] != '.' || name[2] != NUL)))
          && ((regmatch.regprog != NULL && vim_regexec(&regmatch, name, 0))
              || ((flags & EW_NOTWILD)
                  && path_fnamencmp(path + (s - buf), name, (size_t)(e - s)) == 0))) {
        STRCPY(s, name);
        len = strlen(buf);

        if (starstar && stardepth < 100) {
          // For "**" in the pattern first go deeper in the tree to
          // find matches.
          STRCPY(buf + len, "/**");  // NOLINT
          STRCPY(buf + len + 3, path_end);
          stardepth++;
          do_path_expand(gap, buf, len + 1, flags, true);
          stardepth--;
        }

        STRCPY(buf + len, path_end);
        if (path_has_exp_wildcard(path_end)) {      // handle more wildcards
          // need to expand another component of the path
          // remove backslashes for the remaining components only
          do_path_expand(gap, buf, len + 1, flags, false);
        } else {
          FileInfo file_info;

          // no more wildcards, check if there is a match
          // remove backslashes for the remaining components only
          if (*path_end != NUL) {
            backslash_halve(buf + len + 1);
          }
          // add existing file or symbolic link
          if ((flags & EW_ALLLINKS)
              ? os_fileinfo_link(buf, &file_info)
              : os_path_exists(buf)) {
            addfile(gap, buf, flags);
          }
        }
      }
    }
    os_closedir(&dir);
  }

  xfree(buf);
  vim_regfree(regmatch.regprog);

  // When interrupted the matches probably won't be used and sorting can be
  // slow, thus skip it.
  size_t matches = (size_t)(gap->ga_len - start_len);
  if (matches > 0 && !got_int) {
    qsort(((char **)gap->ga_data) + start_len, matches,
          sizeof(char *), pstrcmp);
  }
  return matches;
}

// Moves "*psep" back to the previous path separator in "path".
// Returns FAIL is "*psep" ends up at the beginning of "path".
static int find_previous_pathsep(char *path, char **psep)
{
  // skip the current separator
  if (*psep > path && vim_ispathsep(**psep)) {
    (*psep)--;
  }

  // find the previous separator
  while (*psep > path) {
    if (vim_ispathsep(**psep)) {
      return OK;
    }
    MB_PTR_BACK(path, *psep);
  }

  return FAIL;
}

/// Returns true if "maybe_unique" is unique wrt other_paths in "gap".
/// "maybe_unique" is the end portion of "((char **)gap->ga_data)[i]".
static bool is_unique(char *maybe_unique, garray_T *gap, int i)
{
  char **other_paths = gap->ga_data;

  for (int j = 0; j < gap->ga_len; j++) {
    if (j == i) {
      continue;  // don't compare it with itself
    }
    size_t candidate_len = strlen(maybe_unique);
    size_t other_path_len = strlen(other_paths[j]);
    if (other_path_len < candidate_len) {
      continue;  // it's different when it's shorter
    }
    char *rival = other_paths[j] + other_path_len - candidate_len;
    if (path_fnamecmp(maybe_unique, rival) == 0
        && (rival == other_paths[j] || vim_ispathsep(*(rival - 1)))) {
      return false;  // match
    }
  }
  return true;  // no match found
}

// Split the 'path' option into an array of strings in garray_T.  Relative
// paths are expanded to their equivalent fullpath.  This includes the "."
// (relative to current buffer directory) and empty path (relative to current
// directory) notations.
//
// TODO(vim): handle upward search (;) and path limiter (**N) notations by
// expanding each into their equivalent path(s).
static void expand_path_option(char *curdir, garray_T *gap)
{
  char *path_option = *curbuf->b_p_path == NUL ? p_path : curbuf->b_p_path;
  char *buf = xmalloc(MAXPATHL);

  while (*path_option != NUL) {
    copy_option_part(&path_option, buf, MAXPATHL, " ,");

    if (buf[0] == '.' && (buf[1] == NUL || vim_ispathsep(buf[1]))) {
      // Relative to current buffer:
      // "/path/file" + "." -> "/path/"
      // "/path/file"  + "./subdir" -> "/path/subdir"
      if (curbuf->b_ffname == NULL) {
        continue;
      }
      char *p = path_tail(curbuf->b_ffname);
      size_t len = (size_t)(p - curbuf->b_ffname);
      if (len + strlen(buf) >= MAXPATHL) {
        continue;
      }
      if (buf[1] == NUL) {
        buf[len] = NUL;
      } else {
        STRMOVE(buf + len, buf + 2);
      }
      memmove(buf, curbuf->b_ffname, len);
      simplify_filename(buf);
    } else if (buf[0] == NUL) {
      STRCPY(buf, curdir);  // relative to current directory
    } else if (path_with_url(buf)) {
      continue;  // URL can't be used here
    } else if (!path_is_absolute(buf)) {
      // Expand relative path to their full path equivalent
      size_t len = strlen(curdir);
      if (len + strlen(buf) + 3 > MAXPATHL) {
        continue;
      }
      STRMOVE(buf + len + 1, buf);
      STRCPY(buf, curdir);
      buf[len] = PATHSEP;
      simplify_filename(buf);
    }

    GA_APPEND(char *, gap, xstrdup(buf));
  }

  xfree(buf);
}

// Returns a pointer to the file or directory name in "fname" that matches the
// longest path in "ga"p, or NULL if there is no match. For example:
//
//    path: /foo/bar/baz
//   fname: /foo/bar/baz/quux.txt
// returns:              ^this
static char *get_path_cutoff(char *fname, garray_T *gap)
{
  int maxlen = 0;
  char **path_part = gap->ga_data;
  char *cutoff = NULL;

  for (int i = 0; i < gap->ga_len; i++) {
    int j = 0;

    while ((fname[j] == path_part[i][j]
#ifdef MSWIN
            || (vim_ispathsep(fname[j]) && vim_ispathsep(path_part[i][j]))
#endif
            )
           && fname[j] != NUL && path_part[i][j] != NUL) {
      j++;
    }
    if (j > maxlen) {
      maxlen = j;
      cutoff = &fname[j];
    }
  }

  // skip to the file or directory name
  if (cutoff != NULL) {
    while (vim_ispathsep(*cutoff)) {
      MB_PTR_ADV(cutoff);
    }
  }

  return cutoff;
}

/// Sorts, removes duplicates and modifies all the fullpath names in "gap" so
/// that they are unique with respect to each other while conserving the part
/// that matches the pattern. Beware, this is at least O(n^2) wrt "gap->ga_len".
static void uniquefy_paths(garray_T *gap, char *pattern)
{
  char **fnames = gap->ga_data;
  bool sort_again = false;
  regmatch_T regmatch;
  garray_T path_ga;
  char **in_curdir = NULL;
  char *short_name;

  ga_remove_duplicate_strings(gap);
  ga_init(&path_ga, (int)sizeof(char *), 1);

  // We need to prepend a '*' at the beginning of file_pattern so that the
  // regex matches anywhere in the path. FIXME: is this valid for all
  // possible patterns?
  size_t len = strlen(pattern);
  char *file_pattern = xmalloc(len + 2);
  file_pattern[0] = '*';
  file_pattern[1] = NUL;
  STRCAT(file_pattern, pattern);
  char *pat = file_pat_to_reg_pat(file_pattern, NULL, NULL, true);
  xfree(file_pattern);
  if (pat == NULL) {
    return;
  }

  regmatch.rm_ic = true;                // always ignore case
  regmatch.regprog = vim_regcomp(pat, RE_MAGIC + RE_STRING);
  xfree(pat);
  if (regmatch.regprog == NULL) {
    return;
  }

  char *curdir = xmalloc(MAXPATHL);
  os_dirname(curdir, MAXPATHL);
  expand_path_option(curdir, &path_ga);

  in_curdir = xcalloc((size_t)gap->ga_len, sizeof(char *));

  for (int i = 0; i < gap->ga_len && !got_int; i++) {
    char *path = fnames[i];
    const char *dir_end = gettail_dir(path);

    len = strlen(path);
    bool is_in_curdir = path_fnamencmp(curdir, path, (size_t)(dir_end - path)) == 0
                        && curdir[dir_end - path] == NUL;
    if (is_in_curdir) {
      in_curdir[i] = xstrdup(path);
    }

    // Shorten the filename while maintaining its uniqueness
    char *path_cutoff = get_path_cutoff(path, &path_ga);

    // Don't assume all files can be reached without path when search
    // pattern starts with **/, so only remove path_cutoff
    // when possible.
    if (pattern[0] == '*' && pattern[1] == '*'
        && vim_ispathsep_nocolon(pattern[2])
        && path_cutoff != NULL
        && vim_regexec(&regmatch, path_cutoff, 0)
        && is_unique(path_cutoff, gap, i)) {
      sort_again = true;
      memmove(path, path_cutoff, strlen(path_cutoff) + 1);
    } else {
      // Here all files can be reached without path, so get shortest
      // unique path.  We start at the end of the path. */
      char *pathsep_p = path + len - 1;
      while (find_previous_pathsep(path, &pathsep_p)) {
        if (vim_regexec(&regmatch, pathsep_p + 1, 0)
            && is_unique(pathsep_p + 1, gap, i)
            && path_cutoff != NULL && pathsep_p + 1 >= path_cutoff) {
          sort_again = true;
          memmove(path, pathsep_p + 1, strlen(pathsep_p));
          break;
        }
      }
    }

    if (path_is_absolute(path)) {
      // Last resort: shorten relative to curdir if possible.
      // 'possible' means:
      // 1. It is under the current directory.
      // 2. The result is actually shorter than the original.
      //
      //     Before                curdir        After
      //     /foo/bar/file.txt     /foo/bar      ./file.txt
      //     c:\foo\bar\file.txt   c:\foo\bar    .\file.txt
      //     /file.txt             /             /file.txt
      //     c:\file.txt           c:\           .\file.txt
      short_name = path_shorten_fname(path, curdir);
      if (short_name != NULL && short_name > path + 1) {
        STRCPY(path, ".");
        add_pathsep(path);
        STRMOVE(path + strlen(path), short_name);
      }
    }
    os_breakcheck();
  }

  // Shorten filenames in /in/current/directory/{filename}
  for (int i = 0; i < gap->ga_len && !got_int; i++) {
    char *rel_path;
    char *path = in_curdir[i];

    if (path == NULL) {
      continue;
    }

    // If the {filename} is not unique, change it to ./{filename}.
    // Else reduce it to {filename}
    short_name = path_shorten_fname(path, curdir);
    if (short_name == NULL) {
      short_name = path;
    }
    if (is_unique(short_name, gap, i)) {
      STRCPY(fnames[i], short_name);
      continue;
    }

    rel_path = xmalloc(strlen(short_name) + strlen(PATHSEPSTR) + 2);
    STRCPY(rel_path, ".");
    add_pathsep(rel_path);
    STRCAT(rel_path, short_name);

    xfree(fnames[i]);
    fnames[i] = rel_path;
    sort_again = true;
    os_breakcheck();
  }

  xfree(curdir);
  for (int i = 0; i < gap->ga_len; i++) {
    xfree(in_curdir[i]);
  }
  xfree(in_curdir);
  ga_clear_strings(&path_ga);
  vim_regfree(regmatch.regprog);

  if (sort_again) {
    ga_remove_duplicate_strings(gap);
  }
}

/// Find end of the directory name
///
/// @param[in]  fname  File name to process.
///
/// @return end of the directory name, on the first path separator:
///
///            "/path/file", "/path/dir/", "/path//dir", "/file"
///                  ^             ^             ^        ^
const char *gettail_dir(const char *const fname)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  const char *dir_end = fname;
  const char *next_dir_end = fname;
  bool look_for_sep = true;

  for (const char *p = fname; *p != NUL;) {
    if (vim_ispathsep(*p)) {
      if (look_for_sep) {
        next_dir_end = p;
        look_for_sep = false;
      }
    } else {
      if (!look_for_sep) {
        dir_end = next_dir_end;
      }
      look_for_sep = true;
    }
    MB_PTR_ADV(p);
  }
  return dir_end;
}

/// Calls globpath() with 'path' values for the given pattern and stores the
/// result in "gap".
/// Returns the total number of matches.
///
/// @param flags  EW_* flags
static int expand_in_path(garray_T *const gap, char *const pattern, const int flags)
{
  garray_T path_ga;

  char *const curdir = xmalloc(MAXPATHL);
  os_dirname(curdir, MAXPATHL);

  ga_init(&path_ga, (int)sizeof(char *), 1);
  expand_path_option(curdir, &path_ga);
  xfree(curdir);
  if (GA_EMPTY(&path_ga)) {
    return 0;
  }

  char *const paths = ga_concat_strings(&path_ga);
  ga_clear_strings(&path_ga);

  int glob_flags = 0;
  if (flags & EW_ICASE) {
    glob_flags |= WILD_ICASE;
  }
  if (flags & EW_ADDSLASH) {
    glob_flags |= WILD_ADD_SLASH;
  }
  globpath(paths, pattern, gap, glob_flags, false);
  xfree(paths);

  return gap->ga_len;
}

/// Return true if "p" contains what looks like an environment variable.
/// Allowing for escaping.
static bool has_env_var(char *p)
{
  for (; *p; MB_PTR_ADV(p)) {
    if (*p == '\\' && p[1] != NUL) {
      p++;
    } else if (vim_strchr("$", (uint8_t)(*p)) != NULL) {
      return true;
    }
  }
  return false;
}

#ifdef SPECIAL_WILDCHAR

// Return true if "p" contains a special wildcard character, one that Vim
// cannot expand, requires using a shell.
static bool has_special_wildchar(char *p, int flags)
{
  for (; *p; MB_PTR_ADV(p)) {
    // Disallow line break characters.
    if (*p == '\r' || *p == '\n') {
      break;
    }
    // Allow for escaping.
    if (*p == '\\' && p[1] != NUL && p[1] != '\r' && p[1] != '\n') {
      p++;
    } else if (vim_strchr(SPECIAL_WILDCHAR, (uint8_t)(*p)) != NULL) {
      // Need a shell for curly braces only when including non-existing files.
      if (*p == '{' && !(flags & EW_NOTFOUND)) {
        continue;
      }
      // A { must be followed by a matching }.
      if (*p == '{' && vim_strchr(p, '}') == NULL) {
        continue;
      }
      // A quote and backtick must be followed by another one.
      if ((*p == '`' || *p == '\'') && vim_strchr(p, (uint8_t)(*p)) == NULL) {
        continue;
      }
      return true;
    }
  }
  return false;
}
#endif

/// Generic wildcard expansion code.
///
/// Characters in pat that should not be expanded must be preceded with a
/// backslash. E.g., "/path\ with\ spaces/my\*star*".
///
/// @param      num_pat  is number of input patterns.
/// @param      pat      is an array of pointers to input patterns.
/// @param[out] num_file is pointer to number of matched file names.
/// @param[out] file     is pointer to array of pointers to matched file names.
/// @param      flags    is a combination of EW_* flags used in
///                      expand_wildcards().
///
/// @returns             OK when some files were found. *num_file is set to the
///                      number of matches, *file to the allocated array of
///                      matches. Call FreeWild() later.
///                      If FAIL is returned, *num_file and *file are either
///                      unchanged or *num_file is set to 0 and *file is set
///                      to NULL or points to "".
int gen_expand_wildcards(int num_pat, char **pat, int *num_file, char ***file, int flags)
{
  garray_T ga;
  char *p;
  static bool recursive = false;
  int add_pat;
  bool did_expand_in_path = false;

  // expand_env() is called to expand things like "~user".  If this fails,
  // it calls ExpandOne(), which brings us back here.  In this case, always
  // call the machine specific expansion function, if possible.  Otherwise,
  // return FAIL.
  if (recursive) {
#ifdef SPECIAL_WILDCHAR
    return os_expand_wildcards(num_pat, pat, num_file, file, flags);
#else
    return FAIL;
#endif
  }

#ifdef SPECIAL_WILDCHAR
  // If there are any special wildcard characters which we cannot handle
  // here, call machine specific function for all the expansion.  This
  // avoids starting the shell for each argument separately.
  // For `=expr` do use the internal function.
  for (int i = 0; i < num_pat; i++) {
    if (has_special_wildchar(pat[i], flags)
        && !(vim_backtick(pat[i]) && pat[i][1] == '=')) {
      return os_expand_wildcards(num_pat, pat, num_file, file, flags);
    }
  }
#endif

  recursive = true;

  // The matching file names are stored in a growarray.  Init it empty.
  ga_init(&ga, (int)sizeof(char *), 30);

  for (int i = 0; i < num_pat && !got_int; i++) {
    add_pat = -1;
    p = pat[i];

    if (vim_backtick(p)) {
      add_pat = expand_backtick(&ga, p, flags);
      if (add_pat == -1) {
        recursive = false;
        ga_clear_strings(&ga);
        *num_file = 0;
        *file = NULL;
        return FAIL;
      }
    } else {
      // First expand environment variables, "~/" and "~user/".
      if ((has_env_var(p) && !(flags & EW_NOTENV)) || *p == '~') {
        p = expand_env_save_opt(p, true);
        if (p == NULL) {
          p = pat[i];
        } else {
#ifdef UNIX
          // On Unix, if expand_env() can't expand an environment
          // variable, use the shell to do that.  Discard previously
          // found file names and start all over again.
          if (has_env_var(p) || *p == '~') {
            xfree(p);
            ga_clear_strings(&ga);
            i = os_expand_wildcards(num_pat, pat, num_file, file,
                                    flags | EW_KEEPDOLLAR);
            recursive = false;
            return i;
          }
#endif
        }
      }

      // If there are wildcards or case-insensitive expansion is
      // required: Expand file names and add each match to the list.  If
      // there is no match, and EW_NOTFOUND is given, add the pattern.
      // Otherwise: Add the file name if it exists or when EW_NOTFOUND is
      // given.
      if (path_has_exp_wildcard(p) || (flags & EW_ICASE)) {
        if ((flags & EW_PATH)
            && !path_is_absolute(p)
            && !(p[0] == '.'
                 && (vim_ispathsep(p[1])
                     || (p[1] == '.'
                         && vim_ispathsep(p[2]))))) {
          // :find completion where 'path' is used.
          // Recursiveness is OK here.
          recursive = false;
          add_pat = expand_in_path(&ga, p, flags);
          recursive = true;
          did_expand_in_path = true;
        } else {
          size_t tmp_add_pat = path_expand(&ga, p, flags);
          assert(tmp_add_pat <= INT_MAX);
          add_pat = (int)tmp_add_pat;
        }
      }
    }

    if (add_pat == -1 || (add_pat == 0 && (flags & EW_NOTFOUND))) {
      char *t = backslash_halve_save(p);

      // When EW_NOTFOUND is used, always add files and dirs.  Makes
      // "vim c:/" work.
      if (flags & EW_NOTFOUND) {
        addfile(&ga, t, flags | EW_DIR | EW_FILE);
      } else {
        addfile(&ga, t, flags);
      }

      if (t != p) {
        xfree(t);
      }
    }

    if (did_expand_in_path && !GA_EMPTY(&ga) && (flags & EW_PATH)) {
      uniquefy_paths(&ga, p);
    }
    if (p != pat[i]) {
      xfree(p);
    }
  }

  *num_file = ga.ga_len;
  *file = (ga.ga_data != NULL) ? ga.ga_data : NULL;

  recursive = false;

  return ((flags & EW_EMPTYOK) || ga.ga_data != NULL) ? OK : FAIL;
}

/// Free the list of files returned by expand_wildcards() or other expansion functions.
void FreeWild(int count, char **files)
{
  if (count <= 0 || files == NULL) {
    return;
  }
  while (count--) {
    xfree(files[count]);
  }
  xfree(files);
}

/// @return  true if we can expand this backtick thing here.
static bool vim_backtick(char *p)
{
  return *p == '`' && *(p + 1) != NUL && *(p + strlen(p) - 1) == '`';
}

/// Expand an item in `backticks` by executing it as a command.
/// Currently only works when pat[] starts and ends with a `.
/// Returns number of file names found, -1 if an error is encountered.
///
/// @param flags  EW_* flags
static int expand_backtick(garray_T *gap, char *pat, int flags)
{
  char *p;
  char *buffer;
  int cnt = 0;

  // Create the command: lop off the backticks.
  char *cmd = xmemdupz(pat + 1, strlen(pat) - 2);

  if (*cmd == '=') {          // `={expr}`: Expand expression
    buffer = eval_to_string(cmd + 1, true);
  } else {
    buffer = get_cmd_output(cmd, NULL, (flags & EW_SILENT) ? kShellOptSilent : 0, NULL);
  }
  xfree(cmd);
  if (buffer == NULL) {
    return -1;
  }

  cmd = buffer;
  while (*cmd != NUL) {
    cmd = skipwhite(cmd);               // skip over white space
    p = cmd;
    while (*p != NUL && *p != '\r' && *p != '\n') {  // skip over entry
      p++;
    }
    // add an entry if it is not empty
    if (p > cmd) {
      char i = *p;
      *p = NUL;
      addfile(gap, cmd, flags);
      *p = i;
      cnt++;
    }
    cmd = p;
    while (*cmd != NUL && (*cmd == '\r' || *cmd == '\n')) {
      cmd++;
    }
  }

  xfree(buffer);
  return cnt;
}

#ifdef BACKSLASH_IN_FILENAME
/// Replace all slashes by backslashes.
/// This used to be the other way around, but MS-DOS sometimes has problems
/// with slashes (e.g. in a command name).  We can't have mixed slashes and
/// backslashes, because comparing file names will not work correctly.  The
/// commands that use a file name should try to avoid the need to type a
/// backslash twice.
/// When 'shellslash' set do it the other way around.
/// When the path looks like a URL leave it unmodified.
void slash_adjust(char *p)
{
  if (path_with_url(p)) {
    return;
  }

  if (*p == '`') {
    // don't replace backslash in backtick quoted strings
    const size_t len = strlen(p);
    if (len > 2 && *(p + len - 1) == '`') {
      return;
    }
  }

  while (*p) {
    if (*p == psepcN) {
      *p = psepc;
    }
    MB_PTR_ADV(p);
  }
}
#endif

/// Add a file to a file list.  Accepted flags:
/// EW_DIR      add directories
/// EW_FILE     add files
/// EW_EXEC     add executable files
/// EW_NOTFOUND add even when it doesn't exist
/// EW_ADDSLASH add slash after directory name
/// EW_ALLLINKS add symlink also when the referred file does not exist
///
/// @param f  filename
void addfile(garray_T *gap, char *f, int flags)
{
  bool isdir;
  FileInfo file_info;

  // if the file/dir/link doesn't exist, may not add it
  if (!(flags & EW_NOTFOUND)
      && ((flags & EW_ALLLINKS)
          ? !os_fileinfo_link(f, &file_info)
          : !os_path_exists(f))) {
    return;
  }

#ifdef FNAME_ILLEGAL
  // if the file/dir contains illegal characters, don't add it
  if (strpbrk(f, FNAME_ILLEGAL) != NULL) {
    return;
  }
#endif

  isdir = os_isdir(f);
  if ((isdir && !(flags & EW_DIR)) || (!isdir && !(flags & EW_FILE))) {
    return;
  }

  // If the file isn't executable, may not add it.  Do accept directories.
  // When invoked from expand_shellcmd() do not use $PATH.
  if (!isdir && (flags & EW_EXEC)
      && !os_can_exe(f, NULL, !(flags & EW_SHELLCMD))) {
    return;
  }

  char *p = xmalloc(strlen(f) + 1 + isdir);

  STRCPY(p, f);
#ifdef BACKSLASH_IN_FILENAME
  slash_adjust(p);
#endif
  // Append a slash or backslash after directory names if none is present.
  if (isdir && (flags & EW_ADDSLASH)) {
    add_pathsep(p);
  }
  GA_APPEND(char *, gap, p);
}

// Converts a file name into a canonical form. It simplifies a file name into
// its simplest form by stripping out unneeded components, if any.  The
// resulting file name is simplified in place and will either be the same
// length as that supplied, or shorter.
void simplify_filename(char *filename)
{
  int components = 0;
  bool stripping_disabled = false;
  bool relative = true;

  char *p = filename;
#ifdef BACKSLASH_IN_FILENAME
  if (p[0] != NUL && p[1] == ':') {        // skip "x:"
    p += 2;
  }
#endif

  if (vim_ispathsep(*p)) {
    relative = false;
    do {
      p++;
    } while (vim_ispathsep(*p));
  }
  char *start = p;        // remember start after "c:/" or "/" or "///"

  do {
    // At this point "p" is pointing to the char following a single "/"
    // or "p" is at the "start" of the (absolute or relative) path name.
    if (vim_ispathsep(*p)) {
      STRMOVE(p, p + 1);                // remove duplicate "/"
    } else if (p[0] == '.'
               && (vim_ispathsep(p[1]) || p[1] == NUL)) {
      if (p == start && relative) {
        p += 1 + (p[1] != NUL);         // keep single "." or leading "./"
      } else {
        // Strip "./" or ".///".  If we are at the end of the file name
        // and there is no trailing path separator, either strip "/." if
        // we are after "start", or strip "." if we are at the beginning
        // of an absolute path name.
        char *tail = p + 1;
        if (p[1] != NUL) {
          while (vim_ispathsep(*tail)) {
            MB_PTR_ADV(tail);
          }
        } else if (p > start) {
          p--;                          // strip preceding path separator
        }
        STRMOVE(p, tail);
      }
    } else if (p[0] == '.' && p[1] == '.'
               && (vim_ispathsep(p[2]) || p[2] == NUL)) {
      // Skip to after ".." or "../" or "..///".
      char *tail = p + 2;
      while (vim_ispathsep(*tail)) {
        MB_PTR_ADV(tail);
      }

      if (components > 0) {             // strip one preceding component
        bool do_strip = false;

        // Don't strip for an erroneous file name.
        if (!stripping_disabled) {
          // If the preceding component does not exist in the file
          // system, we strip it.  On Unix, we don't accept a symbolic
          // link that refers to a non-existent file.
          char saved_char = p[-1];
          p[-1] = NUL;
          FileInfo file_info;
          if (!os_fileinfo_link(filename, &file_info)) {
            do_strip = true;
          }
          p[-1] = saved_char;

          p--;
          // Skip back to after previous '/'.
          while (p > start && !after_pathsep(start, p)) {
            MB_PTR_BACK(start, p);
          }

          if (!do_strip) {
            // If the component exists in the file system, check
            // that stripping it won't change the meaning of the
            // file name.  First get information about the
            // unstripped file name.  This may fail if the component
            // to strip is not a searchable directory (but a regular
            // file, for instance), since the trailing "/.." cannot
            // be applied then.  We don't strip it then since we
            // don't want to replace an erroneous file name by
            // a valid one, and we disable stripping of later
            // components.
            saved_char = *tail;
            *tail = NUL;
            if (os_fileinfo(filename, &file_info)) {
              do_strip = true;
            } else {
              stripping_disabled = true;
            }
            *tail = saved_char;
            if (do_strip) {
              // The check for the unstripped file name
              // above works also for a symbolic link pointing to
              // a searchable directory.  But then the parent of
              // the directory pointed to by the link must be the
              // same as the stripped file name.  (The latter
              // exists in the file system since it is the
              // component's parent directory.)
              FileInfo new_file_info;
              if (p == start && relative) {
                os_fileinfo(".", &new_file_info);
              } else {
                saved_char = *p;
                *p = NUL;
                os_fileinfo(filename, &new_file_info);
                *p = saved_char;
              }

              if (!os_fileinfo_id_equal(&file_info, &new_file_info)) {
                do_strip = false;
                // We don't disable stripping of later
                // components since the unstripped path name is
                // still valid.
              }
            }
          }
        }

        if (!do_strip) {
          // Skip the ".." or "../" and reset the counter for the
          // components that might be stripped later on.
          p = tail;
          components = 0;
        } else {
          // Strip previous component.  If the result would get empty
          // and there is no trailing path separator, leave a single
          // "." instead.  If we are at the end of the file name and
          // there is no trailing path separator and a preceding
          // component is left after stripping, strip its trailing
          // path separator as well.
          if (p == start && relative && tail[-1] == '.') {
            *p++ = '.';
            *p = NUL;
          } else {
            if (p > start && tail[-1] == '.') {
              p--;
            }
            STRMOVE(p, tail);                   // strip previous component
          }

          components--;
        }
      } else if (p == start && !relative) {     // leading "/.." or "/../"
        STRMOVE(p, tail);                       // strip ".." or "../"
      } else {
        if (p == start + 2 && p[-2] == '.') {           // leading "./../"
          STRMOVE(p - 2, p);                            // strip leading "./"
          tail -= 2;
        }
        p = tail;                       // skip to char after ".." or "../"
      }
    } else {
      components++;  // Simple path component.
      p = (char *)path_next_component(p);
    }
  } while (*p != NUL);
}

static char *eval_includeexpr(const char *const ptr, const size_t len)
{
  const sctx_T save_sctx = current_sctx;
  set_vim_var_string(VV_FNAME, ptr, (ptrdiff_t)len);
  current_sctx = curbuf->b_p_script_ctx[BV_INEX].script_ctx;

  char *res = eval_to_string_safe(curbuf->b_p_inex,
                                  was_set_insecurely(curwin, kOptIncludeexpr, OPT_LOCAL));

  set_vim_var_string(VV_FNAME, NULL, 0);
  current_sctx = save_sctx;
  return res;
}

/// Return the name of the file ptr[len] in 'path'.
/// Otherwise like file_name_at_cursor().
///
/// @param rel_fname  file we are searching relative to
char *find_file_name_in_path(char *ptr, size_t len, int options, long count, char *rel_fname)
{
  char *file_name;
  char *tofree = NULL;

  if (len == 0) {
    return NULL;
  }

  if ((options & FNAME_INCL) && *curbuf->b_p_inex != NUL) {
    tofree = eval_includeexpr(ptr, len);
    if (tofree != NULL) {
      ptr = tofree;
      len = strlen(ptr);
    }
  }

  if (options & FNAME_EXP) {
    char *file_to_find = NULL;
    char *search_ctx = NULL;

    file_name = find_file_in_path(ptr, len, options & ~FNAME_MESS,
                                  true, rel_fname, &file_to_find, &search_ctx);

    // If the file could not be found in a normal way, try applying
    // 'includeexpr' (unless done already).
    if (file_name == NULL
        && !(options & FNAME_INCL) && *curbuf->b_p_inex != NUL) {
      tofree = eval_includeexpr(ptr, len);
      if (tofree != NULL) {
        ptr = tofree;
        len = strlen(ptr);
        file_name = find_file_in_path(ptr, len, options & ~FNAME_MESS,
                                      true, rel_fname, &file_to_find, &search_ctx);
      }
    }
    if (file_name == NULL && (options & FNAME_MESS)) {
      char c = ptr[len];
      ptr[len] = NUL;
      semsg(_("E447: Can't find file \"%s\" in path"), ptr);
      ptr[len] = c;
    }

    // Repeat finding the file "count" times.  This matters when it
    // appears several times in the path.
    while (file_name != NULL && --count > 0) {
      xfree(file_name);
      file_name = find_file_in_path(ptr, len, options, false, rel_fname,
                                    &file_to_find, &search_ctx);
    }

    xfree(file_to_find);
    vim_findfile_cleanup(search_ctx);
  } else {
    file_name = xstrnsave(ptr, len);
  }

  xfree(tofree);

  return file_name;
}

/// Checks for a Windows drive letter ("C:/") at the start of the path.
///
/// @see https://url.spec.whatwg.org/#start-with-a-windows-drive-letter
bool path_has_drive_letter(const char *p)
  FUNC_ATTR_NONNULL_ALL
{
  return strlen(p) >= 2
         && ASCII_ISALPHA(p[0])
         && (p[1] == ':' || p[1] == '|')
         && (strlen(p) == 2 || ((p[2] == '/') | (p[2] == '\\') | (p[2] == '?') | (p[2] == '#')));
}

// Check if the ":/" of a URL is at the pointer, return URL_SLASH.
// Also check for ":\\", which MS Internet Explorer accepts, return
// URL_BACKSLASH.
int path_is_url(const char *p)
{
  // In the spec ':' is enough to recognize a scheme
  // https://url.spec.whatwg.org/#scheme-state
  if (strncmp(p, ":/", 2) == 0) {
    return URL_SLASH;
  } else if (strncmp(p, ":\\\\", 3) == 0) {
    return URL_BACKSLASH;
  }
  return 0;
}

/// Check if "fname" starts with "name://" or "name:\\".
///
/// @param  fname         is the filename to test
/// @return URL_SLASH for "name://", URL_BACKSLASH for "name:\\", zero otherwise.
int path_with_url(const char *fname)
{
  const char *p;

  // We accept alphabetic characters and a dash in scheme part.
  // RFC 3986 allows for more, but it increases the risk of matching
  // non-URL text.

  // first character must be alpha
  if (!ASCII_ISALPHA(*fname)) {
    return 0;
  }

  if (path_has_drive_letter(fname)) {
    return 0;
  }

  // check body: alpha or dash
  for (p = fname + 1; (ASCII_ISALPHA(*p) || (*p == '-')); p++) {}

  // check last char is not a dash
  if (p[-1] == '-') {
    return 0;
  }

  // ":/" or ":\\" must follow
  return path_is_url(p);
}

bool path_with_extension(const char *path, const char *extension)
{
  const char *last_dot = strrchr(path, '.');
  if (!last_dot) {
    return false;
  }
  return mb_strcmp_ic((bool)p_fic, last_dot + 1, extension) == 0;
}

/// Return true if "name" is a full (absolute) path name or URL.
bool vim_isAbsName(const char *name)
{
  return path_with_url(name) != 0 || path_is_absolute(name);
}

/// Save absolute file name to "buf[len]".
///
/// @param      fname filename to evaluate
/// @param[out] buf   contains `fname` absolute path, or:
///                   - truncated `fname` if longer than `len`
///                   - unmodified `fname` if absolute path fails or is a URL
/// @param      len   length of `buf`
/// @param      force flag to force expanding even if the path is absolute
///
/// @return           FAIL for failure, OK otherwise
int vim_FullName(const char *fname, char *buf, size_t len, bool force)
  FUNC_ATTR_NONNULL_ARG(2)
{
  *buf = NUL;
  if (fname == NULL) {
    return FAIL;
  }

  if (strlen(fname) > (len - 1)) {
    xstrlcpy(buf, fname, len);  // truncate
#ifdef MSWIN
    slash_adjust(buf);
#endif
    return FAIL;
  }

  if (path_with_url(fname)) {
    xstrlcpy(buf, fname, len);
    return OK;
  }

  int rv = path_to_absolute(fname, buf, len, force);
  if (rv == FAIL) {
    xstrlcpy(buf, fname, len);  // something failed; use the filename
  }
#ifdef MSWIN
  slash_adjust(buf);
#endif
  return rv;
}

/// Get the full resolved path for `fname`
///
/// Even filenames that appear to be absolute based on starting from
/// the root may have relative paths (like dir/../subdir) or symlinks
/// embedded, or even extra separators (//).  This function addresses
/// those possibilities, returning a resolved absolute path.
/// For MS-Windows, this also expands names like "longna~1".
///
/// @param fname is the filename to expand
/// @return [allocated] Full path (NULL for failure).
char *fix_fname(const char *fname)
{
#ifdef UNIX
  return FullName_save(fname, true);
#else
  if (!vim_isAbsName(fname)
      || strstr(fname, "..") != NULL
      || strstr(fname, "//") != NULL
# ifdef BACKSLASH_IN_FILENAME
      || strstr(fname, "\\\\") != NULL
# endif
      ) {
    return FullName_save(fname, false);
  }

  fname = xstrdup(fname);

# ifdef USE_FNAME_CASE
  path_fix_case((char *)fname);  // set correct case for file name
# endif

  return (char *)fname;
#endif
}

/// Set the case of the file name, if it already exists.  This will cause the
/// file name to remain exactly the same.
/// Only required for file systems where case is ignored and preserved.
// TODO(SplinterOfChaos): Could also be used when mounting case-insensitive
// file systems.
void path_fix_case(char *name)
  FUNC_ATTR_NONNULL_ALL
{
  FileInfo file_info;
  if (!os_fileinfo_link(name, &file_info)) {
    return;
  }

  // Open the directory where the file is located.
  char *slash = strrchr(name, '/');
  char *tail;
  Directory dir;
  bool ok;
  if (slash == NULL) {
    ok = os_scandir(&dir, ".");
    tail = name;
  } else {
    *slash = NUL;
    ok = os_scandir(&dir, name);
    *slash = '/';
    tail = slash + 1;
  }

  if (!ok) {
    return;
  }

  const char *entry;
  while ((entry = os_scandir_next(&dir))) {
    // Only accept names that differ in case and are the same byte
    // length. TODO: accept different length name.
    if (STRICMP(tail, entry) == 0 && strlen(tail) == strlen(entry)) {
      char newname[MAXPATHL + 1];

      // Verify the inode is equal.
      xstrlcpy(newname, name, MAXPATHL + 1);
      xstrlcpy(newname + (tail - name), entry,
               (size_t)(MAXPATHL - (tail - name) + 1));
      FileInfo file_info_new;
      if (os_fileinfo_link(newname, &file_info_new)
          && os_fileinfo_id_equal(&file_info, &file_info_new)) {
        STRCPY(tail, entry);
        break;
      }
    }
  }

  os_closedir(&dir);
}

/// Return true if "p" points to just after a path separator.
/// Takes care of multi-byte characters.
/// "b" must point to the start of the file name
int after_pathsep(const char *b, const char *p)
{
  return p > b && vim_ispathsep(p[-1])
         && utf_head_off(b, p - 1) == 0;
}

/// Return true if file names "f1" and "f2" are in the same directory.
/// "f1" may be a short name, "f2" must be a full path.
bool same_directory(char *f1, char *f2)
{
  char ffname[MAXPATHL];
  char *t1;
  char *t2;

  // safety check
  if (f1 == NULL || f2 == NULL) {
    return false;
  }

  vim_FullName(f1, ffname, MAXPATHL, false);
  t1 = path_tail_with_sep(ffname);
  t2 = path_tail_with_sep(f2);
  return t1 - ffname == t2 - f2
         && pathcmp(ffname, f2, (int)(t1 - ffname)) == 0;
}

// Compare path "p[]" to "q[]".
// If "maxlen" >= 0 compare "p[maxlen]" to "q[maxlen]"
// Return value like strcmp(p, q), but consider path separators.
int pathcmp(const char *p, const char *q, int maxlen)
{
  int i, j;
  const char *s = NULL;

  for (i = 0, j = 0; maxlen < 0 || (i < maxlen && j < maxlen);) {
    int c1 = utf_ptr2char(p + i);
    int c2 = utf_ptr2char(q + j);

    // End of "p": check if "q" also ends or just has a slash.
    if (c1 == NUL) {
      if (c2 == NUL) {      // full match
        return 0;
      }
      s = q;
      i = j;
      break;
    }

    // End of "q": check if "p" just has a slash.
    if (c2 == NUL) {
      s = p;
      break;
    }

    if ((p_fic ? mb_toupper(c1) != mb_toupper(c2) : c1 != c2)
#ifdef BACKSLASH_IN_FILENAME
        // consider '/' and '\\' to be equal
        && !((c1 == '/' && c2 == '\\')
             || (c1 == '\\' && c2 == '/'))
#endif
        ) {
      if (vim_ispathsep(c1)) {
        return -1;
      }
      if (vim_ispathsep(c2)) {
        return 1;
      }
      return p_fic ? mb_toupper(c1) - mb_toupper(c2)
                   : c1 - c2;  // no match
    }

    i += utfc_ptr2len(p + i);
    j += utfc_ptr2len(q + j);
  }
  if (s == NULL) {  // "i" or "j" ran into "maxlen"
    return 0;
  }

  int c1 = utf_ptr2char(s + i);
  int c2 = utf_ptr2char(s + i + utfc_ptr2len(s + i));
  // ignore a trailing slash, but not "//" or ":/"
  if (c2 == NUL
      && i > 0
      && !after_pathsep(s, s + i)
#ifdef BACKSLASH_IN_FILENAME
      && (c1 == '/' || c1 == '\\')
#else
      && c1 == '/'
#endif
      ) {
    return 0;       // match with trailing slash
  }
  if (s == q) {
    return -1;      // no match
  }
  return 1;
}

/// Try to find a shortname by comparing the fullname with the current
/// directory.
///
/// @param full_path The full path of the file.
/// @return
///   - Pointer into `full_path` if shortened.
///   - `full_path` unchanged if no shorter name is possible.
///   - NULL if `full_path` is NULL.
char *path_try_shorten_fname(char *full_path)
{
  char *dirname = xmalloc(MAXPATHL);
  char *p = full_path;

  if (os_dirname(dirname, MAXPATHL) == OK) {
    p = path_shorten_fname(full_path, dirname);
    if (p == NULL || *p == NUL) {
      p = full_path;
    }
  }
  xfree(dirname);
  return p;
}

/// Try to find a shortname by comparing the fullname with `dir_name`.
///
/// @param full_path The full path of the file.
/// @param dir_name The directory to shorten relative to.
/// @return
///   - Pointer into `full_path` if shortened.
///   - NULL if no shorter name is possible.
char *path_shorten_fname(char *full_path, char *dir_name)
{
  if (full_path == NULL) {
    return NULL;
  }

  assert(dir_name != NULL);
  size_t len = strlen(dir_name);

  // If full_path and dir_name do not match, it's impossible to make one
  // relative to the other.
  if (path_fnamencmp(dir_name, full_path, len) != 0) {
    return NULL;
  }

  // If dir_name is a path head, full_path can always be made relative.
  if (len == (size_t)path_head_length() && is_path_head(dir_name)) {
    return full_path + len;
  }

  char *p = full_path + len;

  // If *p is not pointing to a path separator, this means that full_path's
  // last directory name is longer than *dir_name's last directory, so they
  // don't actually match.
  if (!vim_ispathsep(*p)) {
    return NULL;
  }

  return p + 1;
}

/// Invoke expand_wildcards() for one pattern
///
/// One should expand items like "%:h" before the expansion.
///
/// @param[in]   pat       Pointer to the input pattern.
/// @param[out]  num_file  Resulting number of files.
/// @param[out]  file      Array of resulting files.
/// @param[in]   flags     Flags passed to expand_wildcards().
///
/// @returns               OK when *file is set to allocated array of matches
///                        and *num_file(can be zero) to the number of matches.
///                        If FAIL is returned, *num_file and *file are either
///                        unchanged or *num_file is set to 0 and *file is set
///                        to NULL or points to "".
int expand_wildcards_eval(char **pat, int *num_file, char ***file, int flags)
{
  int ret = FAIL;
  char *eval_pat = NULL;
  char *exp_pat = *pat;
  const char *ignored_msg;
  size_t usedlen;
  const bool is_cur_alt_file = *exp_pat == '%' || *exp_pat == '#';
  bool star_follows = false;

  if (is_cur_alt_file || *exp_pat == '<') {
    emsg_off++;
    eval_pat = eval_vars(exp_pat, exp_pat, &usedlen, NULL, &ignored_msg,
                         NULL,
                         true);
    emsg_off--;
    if (eval_pat != NULL) {
      star_follows = strcmp(exp_pat + usedlen, "*") == 0;
      exp_pat = concat_str(eval_pat, exp_pat + usedlen);
    }
  }

  if (exp_pat != NULL) {
    ret = expand_wildcards(1, &exp_pat, num_file, file, flags);
  }

  if (eval_pat != NULL) {
    if (*num_file == 0 && is_cur_alt_file && star_follows) {
      // Expanding "%" or "#" and the file does not exist: Add the
      // pattern anyway (without the star) so that this works for remote
      // files and non-file buffer names.
      *file = xmalloc(sizeof(char *));
      **file = eval_pat;
      eval_pat = NULL;
      *num_file = 1;
      ret = OK;
    }
    xfree(exp_pat);
    xfree(eval_pat);
  }

  return ret;
}

/// Expand wildcards. Calls gen_expand_wildcards() and removes files matching
/// 'wildignore'.
///
/// @param      num_pat  is number of input patterns.
/// @param      pat      is an array of pointers to input patterns.
/// @param[out] num_file is pointer to number of matched file names.
/// @param[out] file     is pointer to array of pointers to matched file names.
/// @param      flags    is a combination of EW_* flags.
///
/// @returns             OK when *file is set to allocated array of matches
///                      and *num_file (can be zero) to the number of matches.
///                      If FAIL is returned, *num_file and *file are either
///                      unchanged or *num_file is set to 0 and *file is set to
///                      NULL or points to "".
int expand_wildcards(int num_pat, char **pat, int *num_files, char ***files, int flags)
{
  int retval = gen_expand_wildcards(num_pat, pat, num_files, files, flags);

  // When keeping all matches, return here
  if ((flags & EW_KEEPALL) || retval == FAIL) {
    return retval;
  }

  // Remove names that match 'wildignore'.
  if (*p_wig) {
    // check all files in (*files)[]
    assert(*num_files == 0 || *files != NULL);
    for (int i = 0; i < *num_files; i++) {
      char *ffname = FullName_save((*files)[i], false);
      assert((*files)[i] != NULL);
      assert(ffname != NULL);
      if (match_file_list(p_wig, (*files)[i], ffname)) {
        // remove this matching file from the list
        xfree((*files)[i]);
        for (int j = i; j + 1 < *num_files; j++) {
          (*files)[j] = (*files)[j + 1];
        }
        (*num_files)--;
        i--;
      }
      xfree(ffname);
    }
  }

  // Move the names where 'suffixes' match to the end.
  // Skip when interrupted, the result probably won't be used.
  assert(*num_files == 0 || *files != NULL);
  if (*num_files > 1 && !got_int) {
    int non_suf_match = 0;            // number without matching suffix
    for (int i = 0; i < *num_files; i++) {
      if (!match_suffix((*files)[i])) {
        // Move the name without matching suffix to the front of the list.
        char *p = (*files)[i];
        for (int j = i; j > non_suf_match; j--) {
          (*files)[j] = (*files)[j - 1];
        }
        (*files)[non_suf_match++] = p;
      }
    }
  }

  // Free empty array of matches
  if (*num_files == 0) {
    XFREE_CLEAR(*files);
    return FAIL;
  }

  return retval;
}

/// @return  true if "fname" matches with an entry in 'suffixes'.
bool match_suffix(char *fname)
{
#define MAXSUFLEN 30  // maximum length of a file suffix
  char suf_buf[MAXSUFLEN];

  size_t fnamelen = strlen(fname);
  size_t setsuflen = 0;
  for (char *setsuf = p_su; *setsuf;) {
    setsuflen = copy_option_part(&setsuf, suf_buf, MAXSUFLEN, ".,");
    if (setsuflen == 0) {
      char *tail = path_tail(fname);

      // empty entry: match name without a '.'
      if (vim_strchr(tail, '.') == NULL) {
        setsuflen = 1;
        break;
      }
    } else {
      if (fnamelen >= setsuflen
          && path_fnamencmp(suf_buf, fname + fnamelen - setsuflen, setsuflen) == 0) {
        break;
      }
      setsuflen = 0;
    }
  }
  return setsuflen != 0;
}

/// Get the absolute name of the given relative directory.
///
/// @param directory Directory name, relative to current directory.
/// @return `FAIL` for failure, `OK` for success.
int path_full_dir_name(char *directory, char *buffer, size_t len)
{
  int SUCCESS = 0;
  int retval = OK;

  if (strlen(directory) == 0) {
    return os_dirname(buffer, len);
  }

  char old_dir[MAXPATHL];

  // Get current directory name.
  if (os_dirname(old_dir, MAXPATHL) == FAIL) {
    return FAIL;
  }

  // We have to get back to the current dir at the end, check if that works.
  if (os_chdir(old_dir) != SUCCESS) {
    return FAIL;
  }

  if (os_chdir(directory) != SUCCESS) {
    // Path does not exist (yet).  For a full path fail,
    // will use the path as-is.  For a relative path use
    // the current directory and append the file name.
    if (path_is_absolute(directory)) {
      // Do not return immediately since we may be in the wrong directory.
      retval = FAIL;
    } else {
      xstrlcpy(buffer, old_dir, len);
      if (append_path(buffer, directory, len) == FAIL) {
        retval = FAIL;
      }
    }
  } else if (os_dirname(buffer, len) == FAIL) {
    // Do not return immediately since we are in the wrong directory.
    retval = FAIL;
  }

  if (os_chdir(old_dir) != SUCCESS) {
    // That shouldn't happen, since we've tested if it works.
    retval = FAIL;
    emsg(_(e_prev_dir));
  }

  return retval;
}

// Append to_append to path with a slash in between.
int append_path(char *path, const char *to_append, size_t max_len)
{
  size_t current_length = strlen(path);
  size_t to_append_length = strlen(to_append);

  // Do not append empty string or a dot.
  if (to_append_length == 0 || strcmp(to_append, ".") == 0) {
    return OK;
  }

  // Combine the path segments, separated by a slash.
  if (current_length > 0 && !vim_ispathsep_nocolon(path[current_length - 1])) {
    current_length += 1;  // Count the trailing slash.

    // +1 for the NUL at the end.
    if (current_length + 1 > max_len) {
      return FAIL;
    }

    xstrlcat(path, PATHSEPSTR, max_len);
  }

  // +1 for the NUL at the end.
  if (current_length + to_append_length + 1 > max_len) {
    return FAIL;
  }

  xstrlcat(path, to_append, max_len);
  return OK;
}

/// Expand a given file to its absolute path.
///
/// @param  fname  filename which should be expanded.
/// @param  buf    buffer to store the absolute path of "fname".
/// @param  len    length of "buf".
/// @param  force  also expand when "fname" is already absolute.
///
/// @return FAIL for failure, OK for success.
static int path_to_absolute(const char *fname, char *buf, size_t len, int force)
{
  const char *p;
  *buf = NUL;

  char *relative_directory = xmalloc(len);
  const char *end_of_path = fname;

  // expand it if forced or not an absolute path
  if (force || !path_is_absolute(fname)) {
    p = strrchr(fname, '/');
#ifdef MSWIN
    if (p == NULL) {
      p = strrchr(fname, '\\');
    }
#endif
    if (p != NULL) {
      assert(p >= fname);
      memcpy(relative_directory, fname, (size_t)(p - fname + 1));
      relative_directory[p - fname + 1] = NUL;
      end_of_path = p + 1;
    } else {
      relative_directory[0] = NUL;
    }

    if (FAIL == path_full_dir_name(relative_directory, buf, len)) {
      xfree(relative_directory);
      return FAIL;
    }
  }
  xfree(relative_directory);
  return append_path(buf, end_of_path, len);
}

/// Check if file `fname` is a full (absolute) path.
///
/// @return `true` if "fname" is absolute.
bool path_is_absolute(const char *fname)
{
#ifdef MSWIN
  if (*fname == NUL) {
    return false;
  }
  // A name like "d:/foo" and "//server/share" is absolute
  return ((isalpha((uint8_t)fname[0]) && fname[1] == ':' && vim_ispathsep_nocolon(fname[2]))
          || (vim_ispathsep_nocolon(fname[0]) && fname[0] == fname[1]));
#else
  // UNIX: This just checks if the file name starts with '/' or '~'.
  return *fname == '/' || *fname == '~';
#endif
}

/// Builds a full path from an invocation name `argv0`, based on heuristics.
///
/// @param[in]  argv0     Name by which Nvim was invoked.
/// @param[out] buf       Guessed full path to `argv0`.
/// @param[in]  bufsize   Size of `buf`.
///
/// @see os_exepath
void path_guess_exepath(const char *argv0, char *buf, size_t bufsize)
  FUNC_ATTR_NONNULL_ALL
{
  const char *path = os_getenv("PATH");

  if (path == NULL || path_is_absolute(argv0)) {
    xstrlcpy(buf, argv0, bufsize);
  } else if (argv0[0] == '.' || strchr(argv0, PATHSEP)) {
    // Relative to CWD.
    if (os_dirname(buf, MAXPATHL) != OK) {
      buf[0] = NUL;
    }
    xstrlcat(buf, PATHSEPSTR, bufsize);
    xstrlcat(buf, argv0, bufsize);
  } else {
    // Search $PATH for plausible location.
    const void *iter = NULL;
    do {
      const char *dir;
      size_t dir_len;
      iter = vim_env_iter(ENV_SEPCHAR, path, iter, &dir, &dir_len);
      if (dir == NULL || dir_len == 0) {
        break;
      }
      if (dir_len + 1 > sizeof(NameBuff)) {
        continue;
      }
      xmemcpyz(NameBuff, dir, dir_len);
      xstrlcat(NameBuff, PATHSEPSTR, sizeof(NameBuff));
      xstrlcat(NameBuff, argv0, sizeof(NameBuff));
      if (os_can_exe(NameBuff, NULL, false)) {
        xstrlcpy(buf, NameBuff, bufsize);
        return;
      }
    } while (iter != NULL);
    // Not found in $PATH, fall back to argv0.
    xstrlcpy(buf, argv0, bufsize);
  }
}
