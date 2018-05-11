// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdlib.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/path.h"
#include "nvim/charset.h"
#include "nvim/eval.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/fileio.h"
#include "nvim/file_search.h"
#include "nvim/garray.h"
#include "nvim/memfile.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/option.h"
#include "nvim/os/os.h"
#include "nvim/os/shell.h"
#include "nvim/os_unix.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/strings.h"
#include "nvim/tag.h"
#include "nvim/types.h"
#include "nvim/os/input.h"
#include "nvim/window.h"

#define URL_SLASH       1               /* path_is_url() has found "://" */
#define URL_BACKSLASH   2               /* path_is_url() has found ":\\" */

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
/// @return Enum of type FileComparison. @see FileComparison.
FileComparison path_full_compare(char_u *s1, char_u *s2, int checkname)
{
  assert(s1 && s2);
  char_u exp1[MAXPATHL];
  char_u full1[MAXPATHL];
  char_u full2[MAXPATHL];
  FileID file_id_1, file_id_2;

  expand_env(s1, exp1, MAXPATHL);
  bool id_ok_1 = os_fileid((char *)exp1, &file_id_1);
  bool id_ok_2 = os_fileid((char *)s2, &file_id_2);
  if (!id_ok_1 && !id_ok_2) {
    // If os_fileid() doesn't work, may compare the names.
    if (checkname) {
      vim_FullName((char *)exp1, (char *)full1, MAXPATHL, FALSE);
      vim_FullName((char *)s2, (char *)full2, MAXPATHL, FALSE);
      if (fnamecmp(full1, full2) == 0) {
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

/// Gets the tail (i.e., the filename segment) of a path `fname`.
///
/// @return pointer just past the last path separator (empty string, if fname
///         ends in a slash), or empty string if fname is NULL.
char_u *path_tail(const char_u *fname)
  FUNC_ATTR_NONNULL_RET
{
  if (fname == NULL) {
    return (char_u *)"";
  }

  const char_u *tail = get_past_head(fname);
  const char_u *p = tail;
  // Find last part of path.
  while (*p != NUL) {
    if (vim_ispathsep_nocolon(*p)) {
      tail = p + 1;
    }
    mb_ptr_adv(p);
  }
  return (char_u *)tail;
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
char_u *path_tail_with_sep(char_u *fname)
{
  assert(fname != NULL);

  // Don't remove the '/' from "c:/file".
  char_u *past_head = get_past_head(fname);
  char_u *tail = path_tail(fname);
  while (tail > past_head && after_pathsep((char *)fname, (char *)tail)) {
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
const char_u *invocation_path_tail(const char_u *invocation, size_t *len)
    FUNC_ATTR_NONNULL_RET FUNC_ATTR_NONNULL_ARG(1)
{
  const char_u *tail = get_past_head((char_u *) invocation);
  const char_u *p = tail;
  while (*p != NUL && *p != ' ') {
    bool was_sep = vim_ispathsep_nocolon(*p);
    mb_ptr_adv(p);
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
    mb_ptr_adv(fname);
  }
  if (*fname != NUL) {
    fname++;
  }
  return fname;
}

/// Get a pointer to one character past the head of a path name.
/// Unix: after "/"; Win: after "c:\"
/// If there is no head, path is returned.
char_u *get_past_head(const char_u *path)
{
  const char_u *retval = path;

#ifdef WIN32
  // May skip "c:"
  if (isalpha(path[0]) && path[1] == ':') {
    retval = path + 2;
  }
#endif

  while (vim_ispathsep(*retval)) {
    ++retval;
  }

  return (char_u *)retval;
}

/*
 * Return TRUE if 'c' is a path separator.
 * Note that for MS-Windows this includes the colon.
 */
int vim_ispathsep(int c)
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

/*
 * Like vim_ispathsep(c), but exclude the colon for MS-Windows.
 */
int vim_ispathsep_nocolon(int c)
{
  return vim_ispathsep(c)
#ifdef BACKSLASH_IN_FILENAME
         && c != ':'
#endif
  ;
}

/*
 * return TRUE if 'c' is a path list separator.
 */
int vim_ispathlistsep(int c)
{
#ifdef UNIX
  return c == ':';
#else
  return c == ';';      /* might not be right for every system... */
#endif
}

/*
 * Shorten the path of a file from "~/foo/../.bar/fname" to "~/f/../.b/fname"
 * It's done in-place.
 */
char_u *shorten_dir(char_u *str)
{
  char_u *tail = path_tail(str);
  char_u *d = str;
  bool skip = false;
  for (char_u *s = str;; ++s) {
    if (s >= tail) {                /* copy the whole tail */
      *d++ = *s;
      if (*s == NUL)
        break;
    } else if (vim_ispathsep(*s)) {       /* copy '/' and next char */
      *d++ = *s;
      skip = false;
    } else if (!skip) {
      *d++ = *s;                    /* copy next char */
      if (*s != '~' && *s != '.')       /* and leading "~" and "." */
        skip = true;
      if (has_mbyte) {
        int l = mb_ptr2len(s);
        while (--l > 0)
          *d++ = *++s;
      }
    }
  }
  return str;
}

/*
 * Return TRUE if the directory of "fname" exists, FALSE otherwise.
 * Also returns TRUE if there is no directory name.
 * "fname" must be writable!.
 */
bool dir_of_file_exists(char_u *fname)
{
  char_u *p = path_tail_with_sep(fname);
  if (p == fname) {
    return true;
  }
  char_u c = *p;
  *p = NUL;
  bool retval = os_isdir(fname);
  *p = c;
  return retval;
}

/// Compare two file names
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
int path_fnamencmp(const char *const fname1, const char *const fname2,
                   size_t len)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
#ifdef BACKSLASH_IN_FILENAME
  int c1 = NUL;
  int c2 = NUL;

  const char *p1 = fname1;
  const char *p2 = fname2;
  while (len > 0) {
    c1 = PTR2CHAR((const char_u *)p1);
    c2 = PTR2CHAR((const char_u *)p2);
    if ((c1 == NUL || c2 == NUL
         || (!((c1 == '/' || c1 == '\\') && (c2 == '\\' || c2 == '/'))))
        && (p_fic ? (c1 != c2 && CH_FOLD(c1) != CH_FOLD(c2)) : c1 != c2)) {
      break;
    }
    len -= (size_t)MB_PTR2LEN((const char_u *)p1);
    p1 += MB_PTR2LEN((const char_u *)p1);
    p2 += MB_PTR2LEN((const char_u *)p2);
  }
  return c1 - c2;
#else
  if (p_fic) {
    return mb_strnicmp((const char_u *)fname1, (const char_u *)fname2, len);
  }
  return strncmp(fname1, fname2, len);
#endif
}

/// Append fname2 to fname1
///
/// @param[in]  fname1  First fname to append to.
/// @param[in]  len1    Length of fname1.
/// @param[in]  fname2  Secord part of the file name.
/// @param[in]  len2    Length of fname2.
/// @param[in]  sep     If true and fname1 does not end with a path separator,
///                     add a path separator before fname2.
///
/// @return fname1
static inline char *do_concat_fnames(char *fname1, const size_t len1,
                                     const char *fname2, const size_t len2,
                                     const bool sep)
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
char_u *save_abs_path(const char_u *name)
  FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_ALL
{
  if (!path_is_absolute(name)) {
    return (char_u *)FullName_save((char *)name, true);
  }
  return vim_strsave((char_u *) name);
}

/// Checks if a path has a wildcard character including '~', unless at the end.
/// @param p  The path to expand.
/// @returns Unix: True if it contains one of "?[{`'$".
/// @returns Windows: True if it contains one of "*?$[".
bool path_has_wildcard(const char_u *p)
  FUNC_ATTR_NONNULL_ALL
{
  for (; *p; mb_ptr_adv(p)) {
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
    if (vim_strchr((char_u *)wildcards, *p) != NULL
        || (p[0] == '~' && p[1] != NUL)) {
      return true;
    }
  }
  return false;
}

/*
 * Unix style wildcard expansion code.
 */
static int pstrcmp(const void *a, const void *b)
{
  return pathcmp(*(char **)a, *(char **)b, -1);
}

/// Checks if a path has a character path_expand can expand.
/// @param p  The path to expand.
/// @returns Unix: True if it contains one of *?[{.
/// @returns Windows: True if it contains one of *?[.
bool path_has_exp_wildcard(const char_u *p)
  FUNC_ATTR_NONNULL_ALL
{
  for (; *p != NUL; mb_ptr_adv(p)) {
#if defined(UNIX)
    if (p[0] == '\\' && p[1] != NUL) {
      p++;
      continue;
    }

    const char *wildcards = "*?[{";
#else
    const char *wildcards = "*?[";  // Windows.
#endif
    if (vim_strchr((char_u *) wildcards, *p) != NULL) {
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
///   - EW_NOERROR: Silence error messeges.
///   - EW_NOTWILD: Add matches literally.
/// @returns the number of matches found.
static size_t path_expand(garray_T *gap, const char_u *path, int flags)
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
static size_t do_path_expand(garray_T *gap, const char_u *path,
                             size_t wildoff, int flags, bool didstar)
  FUNC_ATTR_NONNULL_ALL
{
  int start_len = gap->ga_len;
  size_t len;
  bool starstar = false;
  static int stardepth = 0;  // depth for "**" expansion

  /* Expanding "**" may take a long time, check for CTRL-C. */
  if (stardepth > 0) {
    os_breakcheck();
    if (got_int)
      return 0;
  }

  // Make room for file name.  When doing encoding conversion the actual
  // length may be quite a bit longer, thus use the maximum possible length.
  char_u *buf = xmalloc(MAXPATHL);

  // Find the first part in the path name that contains a wildcard.
  // When EW_ICASE is set every letter is considered to be a wildcard.
  // Copy it into "buf", including the preceding characters.
  char_u *p = buf;
  char_u *s = buf;
  char_u *e = NULL;
  const char_u *path_end = path;
  while (*path_end != NUL) {
    /* May ignore a wildcard that has a backslash before it; it will
     * be removed by rem_backslash() or file_pat_to_reg_pat() below. */
    if (path_end >= path + wildoff && rem_backslash(path_end)) {
      *p++ = *path_end++;
    } else if (vim_ispathsep_nocolon(*path_end)) {
      if (e != NULL) {
        break;
      }
      s = p + 1;
    } else if (path_end >= path + wildoff
               && (vim_strchr((char_u *)"*?[{~$", *path_end) != NULL
#ifndef WIN32
                   || (!p_fic && (flags & EW_ICASE)
                       && isalpha(PTR2CHAR(path_end)))
#endif
    )) {
      e = p;
    }
    if (has_mbyte) {
      len = (size_t)(*mb_ptr2len)(path_end);
      memcpy(p, path_end, len);
      p += len;
      path_end += len;
    } else
      *p++ = *path_end++;
  }
  e = p;
  *e = NUL;

  /* Now we have one wildcard component between "s" and "e". */
  /* Remove backslashes between "wildoff" and the start of the wildcard
   * component. */
  for (p = buf + wildoff; p < s; ++p)
    if (rem_backslash(p)) {
      STRMOVE(p, p + 1);
      --e;
      --s;
    }

  /* Check for "**" between "s" and "e". */
  for (p = s; p < e; ++p)
    if (p[0] == '*' && p[1] == '*')
      starstar = true;

  // convert the file pattern to a regexp pattern
  int starts_with_dot = *s == '.';
  char_u *pat = file_pat_to_reg_pat(s, e, NULL, false);
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
  if (flags & (EW_NOERROR | EW_NOTWILD))
    ++emsg_silent;
  regmatch.regprog = vim_regcomp(pat, RE_MAGIC);
  if (flags & (EW_NOERROR | EW_NOTWILD))
    --emsg_silent;
  xfree(pat);

  if (regmatch.regprog == NULL && (flags & EW_NOTWILD) == 0) {
    xfree(buf);
    return 0;
  }

  /* If "**" is by itself, this is the first time we encounter it and more
   * is following then find matches without any directory. */
  if (!didstar && stardepth < 100 && starstar && e - s == 2
      && *path_end == '/') {
    STRCPY(s, path_end + 1);
    stardepth++;
    (void)do_path_expand(gap, buf, (size_t)(s - buf), flags, true);
    stardepth--;
  }
  *s = NUL;

  Directory dir;
  char *dirpath = (*buf == NUL ? "." : (char *)buf);
  if (os_file_is_readable(dirpath) && os_scandir(&dir, dirpath)) {
    // Find all matching entries.
    char_u *name;
    scandir_next_with_dots(NULL);  // initialize
    while ((name = (char_u *)scandir_next_with_dots(&dir)) != NULL) {
      if ((name[0] != '.'
           || starts_with_dot
           || ((flags & EW_DODOT)
               && name[1] != NUL
               && (name[1] != '.' || name[2] != NUL)))  // -V557
          && ((regmatch.regprog != NULL && vim_regexec(&regmatch, name, 0))
              || ((flags & EW_NOTWILD)
                  && fnamencmp(path + (s - buf), name, e - s) == 0))) {
        STRCPY(s, name);
        len = STRLEN(buf);

        if (starstar && stardepth < 100) {
          /* For "**" in the pattern first go deeper in the tree to
           * find matches. */
          STRCPY(buf + len, "/**");
          STRCPY(buf + len + 3, path_end);
          ++stardepth;
          (void)do_path_expand(gap, buf, len + 1, flags, true);
          --stardepth;
        }

        STRCPY(buf + len, path_end);
        if (path_has_exp_wildcard(path_end)) {      /* handle more wildcards */
          /* need to expand another component of the path */
          /* remove backslashes for the remaining components only */
          (void)do_path_expand(gap, buf, len + 1, flags, false);
        } else {
          FileInfo file_info;

          // no more wildcards, check if there is a match
          // remove backslashes for the remaining components only
          if (*path_end != NUL) {
            backslash_halve(buf + len + 1);
          }
          // add existing file or symbolic link
          if ((flags & EW_ALLLINKS) ? os_fileinfo_link((char *)buf, &file_info)
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

  size_t matches = (size_t)(gap->ga_len - start_len);
  if (matches > 0) {
    qsort(((char_u **)gap->ga_data) + start_len, matches,
          sizeof(char_u *), pstrcmp);
  }
  return matches;
}

/*
 * Moves "*psep" back to the previous path separator in "path".
 * Returns FAIL is "*psep" ends up at the beginning of "path".
 */
static int find_previous_pathsep(char_u *path, char_u **psep)
{
  /* skip the current separator */
  if (*psep > path && vim_ispathsep(**psep))
    --*psep;

  /* find the previous separator */
  while (*psep > path) {
    if (vim_ispathsep(**psep))
      return OK;
    mb_ptr_back(path, *psep);
  }

  return FAIL;
}

/*
 * Returns TRUE if "maybe_unique" is unique wrt other_paths in "gap".
 * "maybe_unique" is the end portion of "((char_u **)gap->ga_data)[i]".
 */
static bool is_unique(char_u *maybe_unique, garray_T *gap, int i)
{
  char_u **other_paths = (char_u **)gap->ga_data;

  for (int j = 0; j < gap->ga_len; j++) {
    if (j == i) {
      continue;  // don't compare it with itself
    }
    size_t candidate_len = STRLEN(maybe_unique);
    size_t other_path_len = STRLEN(other_paths[j]);
    if (other_path_len < candidate_len) {
      continue;  // it's different when it's shorter
    }
    char_u *rival = other_paths[j] + other_path_len - candidate_len;
    if (fnamecmp(maybe_unique, rival) == 0
        && (rival == other_paths[j] || vim_ispathsep(*(rival - 1)))) {
      return false;  // match
    }
  }
  return true;  // no match found
}

/*
 * Split the 'path' option into an array of strings in garray_T.  Relative
 * paths are expanded to their equivalent fullpath.  This includes the "."
 * (relative to current buffer directory) and empty path (relative to current
 * directory) notations.
 *
 * TODO: handle upward search (;) and path limiter (**N) notations by
 * expanding each into their equivalent path(s).
 */
static void expand_path_option(char_u *curdir, garray_T *gap)
{
  char_u *path_option = *curbuf->b_p_path == NUL ? p_path : curbuf->b_p_path;
  char_u *buf = xmalloc(MAXPATHL);

  while (*path_option != NUL) {
    copy_option_part(&path_option, buf, MAXPATHL, " ,");

    if (buf[0] == '.' && (buf[1] == NUL || vim_ispathsep(buf[1]))) {
      /* Relative to current buffer:
       * "/path/file" + "." -> "/path/"
       * "/path/file"  + "./subdir" -> "/path/subdir" */
      if (curbuf->b_ffname == NULL)
        continue;
      char_u *p = path_tail(curbuf->b_ffname);
      size_t len = (size_t)(p - curbuf->b_ffname);
      if (len + STRLEN(buf) >= MAXPATHL) {
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
    } else if (path_with_url((char *)buf)) {
      continue;  // URL can't be used here
    } else if (!path_is_absolute(buf)) {
      // Expand relative path to their full path equivalent
      size_t len = STRLEN(curdir);
      if (len + STRLEN(buf) + 3 > MAXPATHL) {
        continue;
      }
      STRMOVE(buf + len + 1, buf);
      STRCPY(buf, curdir);
      buf[len] = (char_u)PATHSEP;
      simplify_filename(buf);
    }

    GA_APPEND(char_u *, gap, vim_strsave(buf));
  }

  xfree(buf);
}

/*
 * Returns a pointer to the file or directory name in "fname" that matches the
 * longest path in "ga"p, or NULL if there is no match. For example:
 *
 *    path: /foo/bar/baz
 *   fname: /foo/bar/baz/quux.txt
 * returns:		 ^this
 */
static char_u *get_path_cutoff(char_u *fname, garray_T *gap)
{
  int maxlen = 0;
  char_u  **path_part = (char_u **)gap->ga_data;
  char_u  *cutoff = NULL;

  for (int i = 0; i < gap->ga_len; i++) {
    int j = 0;

    while ((fname[j] == path_part[i][j]
            ) && fname[j] != NUL && path_part[i][j] != NUL)
      j++;
    if (j > maxlen) {
      maxlen = j;
      cutoff = &fname[j];
    }
  }

  /* skip to the file or directory name */
  if (cutoff != NULL)
    while (vim_ispathsep(*cutoff))
      mb_ptr_adv(cutoff);

  return cutoff;
}

/*
 * Sorts, removes duplicates and modifies all the fullpath names in "gap" so
 * that they are unique with respect to each other while conserving the part
 * that matches the pattern. Beware, this is at least O(n^2) wrt "gap->ga_len".
 */
static void uniquefy_paths(garray_T *gap, char_u *pattern)
{
  char_u **fnames = (char_u **)gap->ga_data;
  bool sort_again = false;
  regmatch_T regmatch;
  garray_T path_ga;
  char_u **in_curdir = NULL;
  char_u *short_name;

  ga_remove_duplicate_strings(gap);
  ga_init(&path_ga, (int)sizeof(char_u *), 1);

  // We need to prepend a '*' at the beginning of file_pattern so that the
  // regex matches anywhere in the path. FIXME: is this valid for all
  // possible patterns?
  size_t len = STRLEN(pattern);
  char_u *file_pattern = xmalloc(len + 2);
  file_pattern[0] = '*';
  file_pattern[1] = NUL;
  STRCAT(file_pattern, pattern);
  char_u *pat = file_pat_to_reg_pat(file_pattern, NULL, NULL, true);
  xfree(file_pattern);
  if (pat == NULL)
    return;

  regmatch.rm_ic = TRUE;                /* always ignore case */
  regmatch.regprog = vim_regcomp(pat, RE_MAGIC + RE_STRING);
  xfree(pat);
  if (regmatch.regprog == NULL)
    return;

  char_u *curdir = xmalloc(MAXPATHL);
  os_dirname(curdir, MAXPATHL);
  expand_path_option(curdir, &path_ga);

  in_curdir = xcalloc((size_t)gap->ga_len, sizeof(char_u *));

  for (int i = 0; i < gap->ga_len && !got_int; i++) {
    char_u *path = fnames[i];
    int is_in_curdir;
    char_u *dir_end = (char_u *)gettail_dir((const char *)path);
    char_u      *pathsep_p;
    char_u      *path_cutoff;

    len = STRLEN(path);
    is_in_curdir = fnamencmp(curdir, path, dir_end - path) == 0
                   && curdir[dir_end - path] == NUL;
    if (is_in_curdir)
      in_curdir[i] = vim_strsave(path);

    /* Shorten the filename while maintaining its uniqueness */
    path_cutoff = get_path_cutoff(path, &path_ga);

    // Don't assume all files can be reached without path when search
    // pattern starts with **/, so only remove path_cutoff
    // when possible.
    if (pattern[0] == '*' && pattern[1] == '*'
        && vim_ispathsep_nocolon(pattern[2])
        && path_cutoff != NULL
        && vim_regexec(&regmatch, path_cutoff, (colnr_T)0)
        && is_unique(path_cutoff, gap, i)) {
      sort_again = true;
      memmove(path, path_cutoff, STRLEN(path_cutoff) + 1);
    } else {
      // Here all files can be reached without path, so get shortest
      // unique path.  We start at the end of the path. */
      pathsep_p = path + len - 1;
      while (find_previous_pathsep(path, &pathsep_p)) {
        if (vim_regexec(&regmatch, pathsep_p + 1, (colnr_T)0)
            && is_unique(pathsep_p + 1, gap, i)
            && path_cutoff != NULL && pathsep_p + 1 >= path_cutoff) {
          sort_again = true;
          memmove(path, pathsep_p + 1, STRLEN(pathsep_p));
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
      if (short_name != NULL && short_name > path + 1
          ) {
        STRCPY(path, ".");
        add_pathsep((char *)path);
        STRMOVE(path + STRLEN(path), short_name);
      }
    }
    os_breakcheck();
  }

  /* Shorten filenames in /in/current/directory/{filename} */
  for (int i = 0; i < gap->ga_len && !got_int; i++) {
    char_u *rel_path;
    char_u *path = in_curdir[i];

    if (path == NULL)
      continue;

    /* If the {filename} is not unique, change it to ./{filename}.
     * Else reduce it to {filename} */
    short_name = path_shorten_fname(path, curdir);
    if (short_name == NULL)
      short_name = path;
    if (is_unique(short_name, gap, i)) {
      STRCPY(fnames[i], short_name);
      continue;
    }

    rel_path = xmalloc(STRLEN(short_name) + STRLEN(PATHSEPSTR) + 2);
    STRCPY(rel_path, ".");
    add_pathsep((char *)rel_path);
    STRCAT(rel_path, short_name);

    xfree(fnames[i]);
    fnames[i] = rel_path;
    sort_again = true;
    os_breakcheck();
  }

  xfree(curdir);
  for (int i = 0; i < gap->ga_len; i++)
    xfree(in_curdir[i]);
  xfree(in_curdir);
  ga_clear_strings(&path_ga);
  vim_regfree(regmatch.regprog);

  if (sort_again)
    ga_remove_duplicate_strings(gap);
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

  for (const char *p = fname; *p != NUL; ) {
    if (vim_ispathsep(*p)) {
      if (look_for_sep) {
        next_dir_end = p;
        look_for_sep = false;
      }
    } else {
      if (!look_for_sep)
        dir_end = next_dir_end;
      look_for_sep = true;
    }
    mb_ptr_adv(p);
  }
  return dir_end;
}


/*
 * Calls globpath() with 'path' values for the given pattern and stores the
 * result in "gap".
 * Returns the total number of matches.
 */
static int 
expand_in_path (
    garray_T *gap,
    char_u *pattern,
    int flags                      /* EW_* flags */
)
{
  char_u      *curdir;
  garray_T path_ga;
  char_u      *paths = NULL;

  curdir = xmalloc(MAXPATHL);
  os_dirname(curdir, MAXPATHL);

  ga_init(&path_ga, (int)sizeof(char_u *), 1);
  expand_path_option(curdir, &path_ga);
  xfree(curdir);
  if (GA_EMPTY(&path_ga))
    return 0;

  paths = ga_concat_strings(&path_ga);
  ga_clear_strings(&path_ga);

  globpath(paths, pattern, gap, (flags & EW_ICASE) ? WILD_ICASE : 0);
  xfree(paths);

  return gap->ga_len;
}


/*
 * Return TRUE if "p" contains what looks like an environment variable.
 * Allowing for escaping.
 */
static bool has_env_var(char_u *p)
{
  for (; *p; mb_ptr_adv(p)) {
    if (*p == '\\' && p[1] != NUL)
      ++p;
    else if (vim_strchr((char_u *)
                 "$"
                 , *p) != NULL)
      return true;
  }
  return false;
}

#ifdef SPECIAL_WILDCHAR
/*
 * Return TRUE if "p" contains a special wildcard character.
 * Allowing for escaping.
 */
static bool has_special_wildchar(char_u *p)
{
  for (; *p; mb_ptr_adv(p)) {
    if (*p == '\\' && p[1] != NUL)
      ++p;
    else if (vim_strchr((char_u *)SPECIAL_WILDCHAR, *p) != NULL)
      return true;
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
int gen_expand_wildcards(int num_pat, char_u **pat, int *num_file,
                         char_u ***file, int flags)
{
  garray_T ga;
  char_u *p;
  static bool recursive = false;
  int add_pat;
  bool did_expand_in_path = false;

  /*
   * expand_env() is called to expand things like "~user".  If this fails,
   * it calls ExpandOne(), which brings us back here.  In this case, always
   * call the machine specific expansion function, if possible.  Otherwise,
   * return FAIL.
   */
  if (recursive)
#ifdef SPECIAL_WILDCHAR
    return mch_expand_wildcards(num_pat, pat, num_file, file, flags);
#else
    return FAIL;
#endif

#ifdef SPECIAL_WILDCHAR
  /*
   * If there are any special wildcard characters which we cannot handle
   * here, call machine specific function for all the expansion.  This
   * avoids starting the shell for each argument separately.
   * For `=expr` do use the internal function.
   */
  for (int i = 0; i < num_pat; i++) {
    if (has_special_wildchar(pat[i])
        && !(vim_backtick(pat[i]) && pat[i][1] == '=')) {
      return mch_expand_wildcards(num_pat, pat, num_file, file, flags);
    }
  }
#endif

  recursive = true;

  /*
   * The matching file names are stored in a growarray.  Init it empty.
   */
  ga_init(&ga, (int)sizeof(char_u *), 30);

  for (int i = 0; i < num_pat; ++i) {
    add_pat = -1;
    p = pat[i];

    if (vim_backtick(p)) {
      add_pat = expand_backtick(&ga, p, flags);
      if (add_pat == -1) {
        recursive = false;
        FreeWild(ga.ga_len, (char_u **)ga.ga_data);
        *num_file = 0;
        *file = NULL;
        return FAIL;
      }
    } else {
      // First expand environment variables, "~/" and "~user/".
      if (has_env_var(p) || *p == '~') {
        p = expand_env_save_opt(p, true);
        if (p == NULL)
          p = pat[i];
#ifdef UNIX
        /*
         * On Unix, if expand_env() can't expand an environment
         * variable, use the shell to do that.  Discard previously
         * found file names and start all over again.
         */
        else if (has_env_var(p) || *p == '~') {
          xfree(p);
          ga_clear_strings(&ga);
          i = mch_expand_wildcards(num_pat, pat, num_file, file,
              flags | EW_KEEPDOLLAR);
          recursive = false;
          return i;
        }
#endif
      }

      /*
       * If there are wildcards: Expand file names and add each match to
       * the list.  If there is no match, and EW_NOTFOUND is given, add
       * the pattern.
       * If there are no wildcards: Add the file name if it exists or
       * when EW_NOTFOUND is given.
       */
      if (path_has_exp_wildcard(p)) {
        if ((flags & EW_PATH)
            && !path_is_absolute(p)
            && !(p[0] == '.'
                 && (vim_ispathsep(p[1])
                     || (p[1] == '.' && vim_ispathsep(p[2]))))
            ) {
          /* :find completion where 'path' is used.
           * Recursiveness is OK here. */
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
      char_u      *t = backslash_halve_save(p);

      /* When EW_NOTFOUND is used, always add files and dirs.  Makes
       * "vim c:/" work. */
      if (flags & EW_NOTFOUND) {
        addfile(&ga, t, flags | EW_DIR | EW_FILE);
      } else {
        addfile(&ga, t, flags);
      }
      xfree(t);
    }

    if (did_expand_in_path && !GA_EMPTY(&ga) && (flags & EW_PATH))
      uniquefy_paths(&ga, p);
    if (p != pat[i])
      xfree(p);
  }

  *num_file = ga.ga_len;
  *file = (ga.ga_data != NULL) ? (char_u **)ga.ga_data : (char_u **)"";

  recursive = false;

  return ((flags & EW_EMPTYOK) || ga.ga_data != NULL) ? OK : FAIL;
}


/*
 * Return TRUE if we can expand this backtick thing here.
 */
static int vim_backtick(char_u *p)
{
  return *p == '`' && *(p + 1) != NUL && *(p + STRLEN(p) - 1) == '`';
}

// Expand an item in `backticks` by executing it as a command.
// Currently only works when pat[] starts and ends with a `.
// Returns number of file names found, -1 if an error is encountered.
static int expand_backtick(
    garray_T *gap,
    char_u *pat,
    int flags              /* EW_* flags */
)
{
  char_u *p;
  char_u *buffer;
  int cnt = 0;

  // Create the command: lop off the backticks.
  char_u *cmd = vim_strnsave(pat + 1, STRLEN(pat) - 2);

  if (*cmd == '=')          /* `={expr}`: Expand expression */
    buffer = eval_to_string(cmd + 1, &p, TRUE);
  else
    buffer = get_cmd_output(cmd, NULL,
        (flags & EW_SILENT) ? kShellOptSilent : 0, NULL);
  xfree(cmd);
  if (buffer == NULL) {
    return -1;
  }

  cmd = buffer;
  while (*cmd != NUL) {
    cmd = skipwhite(cmd);               /* skip over white space */
    p = cmd;
    while (*p != NUL && *p != '\r' && *p != '\n')     /* skip over entry */
      ++p;
    /* add an entry if it is not empty */
    if (p > cmd) {
      char_u i = *p;
      *p = NUL;
      addfile(gap, cmd, flags);
      *p = i;
      ++cnt;
    }
    cmd = p;
    while (*cmd != NUL && (*cmd == '\r' || *cmd == '\n'))
      ++cmd;
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
void slash_adjust(char_u *p)
{
  if (path_with_url((const char *)p)) {
    return;
  }
  while (*p) {
    if (*p == (char_u)psepcN) {
      *p = (char_u)psepc;
    }
    mb_ptr_adv(p);
  }
}
#endif

// Add a file to a file list.  Accepted flags:
// EW_DIR      add directories
// EW_FILE     add files
// EW_EXEC     add executable files
// EW_NOTFOUND add even when it doesn't exist
// EW_ADDSLASH add slash after directory name
// EW_ALLLINKS add symlink also when the referred file does not exist
void addfile(
    garray_T *gap,
    char_u *f,         /* filename */
    int flags
)
{
  bool isdir;
  FileInfo file_info;

  // if the file/dir/link doesn't exist, may not add it
  if (!(flags & EW_NOTFOUND)
      && ((flags & EW_ALLLINKS)
          ? !os_fileinfo_link((char *)f, &file_info)
          : !os_path_exists(f))) {
    return;
  }

#ifdef FNAME_ILLEGAL
  /* if the file/dir contains illegal characters, don't add it */
  if (vim_strpbrk(f, (char_u *)FNAME_ILLEGAL) != NULL)
    return;
#endif

  isdir = os_isdir(f);
  if ((isdir && !(flags & EW_DIR)) || (!isdir && !(flags & EW_FILE)))
    return;

  // If the file isn't executable, may not add it.  Do accept directories.
  // When invoked from expand_shellcmd() do not use $PATH.
  if (!isdir && (flags & EW_EXEC)
      && !os_can_exe(f, NULL, !(flags & EW_SHELLCMD))) {
    return;
  }

  char_u *p = xmalloc(STRLEN(f) + 1 + isdir);

  STRCPY(p, f);
#ifdef BACKSLASH_IN_FILENAME
  slash_adjust(p);
#endif
  /*
   * Append a slash or backslash after directory names if none is present.
   */
  if (isdir && (flags & EW_ADDSLASH))
    add_pathsep((char *)p);
  GA_APPEND(char_u *, gap, p);
}

/*
 * Converts a file name into a canonical form. It simplifies a file name into
 * its simplest form by stripping out unneeded components, if any.  The
 * resulting file name is simplified in place and will either be the same
 * length as that supplied, or shorter.
 */
void simplify_filename(char_u *filename)
{
  int components = 0;
  char_u      *p, *tail, *start;
  bool stripping_disabled = false;
  bool relative = true;

  p = filename;
#ifdef BACKSLASH_IN_FILENAME
  if (p[1] == ':')          /* skip "x:" */
    p += 2;
#endif

  if (vim_ispathsep(*p)) {
    relative = false;
    do
      ++p;
    while (vim_ispathsep(*p));
  }
  start = p;        /* remember start after "c:/" or "/" or "///" */

  do {
    /* At this point "p" is pointing to the char following a single "/"
     * or "p" is at the "start" of the (absolute or relative) path name. */
    if (vim_ispathsep(*p))
      STRMOVE(p, p + 1);                /* remove duplicate "/" */
    else if (p[0] == '.' && (vim_ispathsep(p[1]) || p[1] == NUL)) {
      if (p == start && relative)
        p += 1 + (p[1] != NUL);         /* keep single "." or leading "./" */
      else {
        /* Strip "./" or ".///".  If we are at the end of the file name
         * and there is no trailing path separator, either strip "/." if
         * we are after "start", or strip "." if we are at the beginning
         * of an absolute path name . */
        tail = p + 1;
        if (p[1] != NUL)
          while (vim_ispathsep(*tail))
            mb_ptr_adv(tail);
        else if (p > start)
          --p;                          /* strip preceding path separator */
        STRMOVE(p, tail);
      }
    } else if (p[0] == '.' && p[1] == '.'
               && (vim_ispathsep(p[2]) || p[2] == NUL)) {
      // Skip to after ".." or "../" or "..///".
      tail = p + 2;
      while (vim_ispathsep(*tail))
        mb_ptr_adv(tail);

      if (components > 0) {             /* strip one preceding component */
        bool do_strip = false;
        char_u saved_char;

        /* Don't strip for an erroneous file name. */
        if (!stripping_disabled) {
          /* If the preceding component does not exist in the file
           * system, we strip it.  On Unix, we don't accept a symbolic
           * link that refers to a non-existent file. */
          saved_char = p[-1];
          p[-1] = NUL;
          FileInfo file_info;
          if (!os_fileinfo_link((char *)filename, &file_info)) {
            do_strip = true;
          }
          p[-1] = saved_char;

          --p;
          /* Skip back to after previous '/'. */
          while (p > start && !after_pathsep((char *)start, (char *)p))
            mb_ptr_back(start, p);

          if (!do_strip) {
            /* If the component exists in the file system, check
             * that stripping it won't change the meaning of the
             * file name.  First get information about the
             * unstripped file name.  This may fail if the component
             * to strip is not a searchable directory (but a regular
             * file, for instance), since the trailing "/.." cannot
             * be applied then.  We don't strip it then since we
             * don't want to replace an erroneous file name by
             * a valid one, and we disable stripping of later
             * components. */
            saved_char = *tail;
            *tail = NUL;
            if (os_fileinfo((char *)filename, &file_info)) {
              do_strip = true;
            } else {
              stripping_disabled = true;
            }
            *tail = saved_char;
            if (do_strip) {
              /* The check for the unstripped file name
               * above works also for a symbolic link pointing to
               * a searchable directory.  But then the parent of
               * the directory pointed to by the link must be the
               * same as the stripped file name.  (The latter
               * exists in the file system since it is the
               * component's parent directory.) */
              FileInfo new_file_info;
              if (p == start && relative) {
                os_fileinfo(".", &new_file_info);
              } else {
                saved_char = *p;
                *p = NUL;
                os_fileinfo((char *)filename, &new_file_info);
                *p = saved_char;
              }

              if (!os_fileinfo_id_equal(&file_info, &new_file_info)) {
                do_strip = false;
                /* We don't disable stripping of later
                 * components since the unstripped path name is
                 * still valid. */
              }
            }
          }
        }

        if (!do_strip) {
          /* Skip the ".." or "../" and reset the counter for the
           * components that might be stripped later on. */
          p = tail;
          components = 0;
        } else {
          /* Strip previous component.  If the result would get empty
           * and there is no trailing path separator, leave a single
           * "." instead.  If we are at the end of the file name and
           * there is no trailing path separator and a preceding
           * component is left after stripping, strip its trailing
           * path separator as well. */
          if (p == start && relative && tail[-1] == '.') {
            *p++ = '.';
            *p = NUL;
          } else {
            if (p > start && tail[-1] == '.')
              --p;
            STRMOVE(p, tail);                   /* strip previous component */
          }

          --components;
        }
      } else if (p == start && !relative)       /* leading "/.." or "/../" */
        STRMOVE(p, tail);                       /* strip ".." or "../" */
      else {
        if (p == start + 2 && p[-2] == '.') {           /* leading "./../" */
          STRMOVE(p - 2, p);                            /* strip leading "./" */
          tail -= 2;
        }
        p = tail;                       /* skip to char after ".." or "../" */
      }
    } else {
      components++;  // Simple path component.
      p = (char_u *)path_next_component((const char *)p);
    }
  } while (*p != NUL);
}

static char *eval_includeexpr(const char *const ptr, const size_t len)
{
  set_vim_var_string(VV_FNAME, ptr, (ptrdiff_t) len);
  char *res = (char *) eval_to_string_safe(
      curbuf->b_p_inex, NULL, was_set_insecurely((char_u *)"includeexpr",
                                                 OPT_LOCAL));
  set_vim_var_string(VV_FNAME, NULL, 0);
  return res;
}

/*
 * Return the name of the file ptr[len] in 'path'.
 * Otherwise like file_name_at_cursor().
 */
char_u *
find_file_name_in_path (
    char_u *ptr,
    size_t len,
    int options,
    long count,
    char_u *rel_fname         /* file we are searching relative to */
)
{
  char_u *file_name;
  char_u *tofree = NULL;

  if ((options & FNAME_INCL) && *curbuf->b_p_inex != NUL) {
    tofree = (char_u *) eval_includeexpr((char *) ptr, len);
    if (tofree != NULL) {
      ptr = tofree;
      len = STRLEN(ptr);
    }
  }

  if (options & FNAME_EXP) {
    file_name = find_file_in_path(ptr, len, options & ~FNAME_MESS, true,
                                  rel_fname);

    /*
     * If the file could not be found in a normal way, try applying
     * 'includeexpr' (unless done already).
     */
    if (file_name == NULL
        && !(options & FNAME_INCL) && *curbuf->b_p_inex != NUL) {
      tofree = (char_u *) eval_includeexpr((char *) ptr, len);
      if (tofree != NULL) {
        ptr = tofree;
        len = STRLEN(ptr);
        file_name = find_file_in_path(ptr, len, options & ~FNAME_MESS,
                                      TRUE, rel_fname);
      }
    }
    if (file_name == NULL && (options & FNAME_MESS)) {
      char_u c = ptr[len];
      ptr[len] = NUL;
      EMSG2(_("E447: Can't find file \"%s\" in path"), ptr);
      ptr[len] = c;
    }

    /* Repeat finding the file "count" times.  This matters when it
     * appears several times in the path. */
    while (file_name != NULL && --count > 0) {
      xfree(file_name);
      file_name = find_file_in_path(ptr, len, options, FALSE, rel_fname);
    }
  } else
    file_name = vim_strnsave(ptr, len);

  xfree(tofree);

  return file_name;
}

// Check if the "://" of a URL is at the pointer, return URL_SLASH.
// Also check for ":\\", which MS Internet Explorer accepts, return
// URL_BACKSLASH.
int path_is_url(const char *p)
{
  if (strncmp(p, "://", 3) == 0)
    return URL_SLASH;
  else if (strncmp(p, ":\\\\", 3) == 0)
    return URL_BACKSLASH;
  return 0;
}

/// Check if "fname" starts with "name://".  Return URL_SLASH if it does.
///
/// @param  fname         is the filename to test
/// @return URL_BACKSLASH for "name:\\", zero otherwise.
int path_with_url(const char *fname)
{
  const char *p;
  for (p = fname; isalpha(*p); p++) {}
  return path_is_url(p);
}

/*
 * Return TRUE if "name" is a full (absolute) path name or URL.
 */
bool vim_isAbsName(char_u *name)
{
  return path_with_url((char *)name) != 0 || path_is_absolute(name);
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
#ifdef WIN32
    slash_adjust((char_u *)buf);
#endif
    return FAIL;
  }

  if (path_with_url(fname)) {
    xstrlcpy(buf, fname, len);
    return OK;
  }

  int rv = path_to_absolute((char_u *)fname, (char_u *)buf, len, force);
  if (rv == FAIL) {
    xstrlcpy(buf, fname, len);  // something failed; use the filename
  }
#ifdef WIN32
  slash_adjust((char_u *)buf);
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
  if (!vim_isAbsName((char_u *)fname)
      || strstr(fname, "..") != NULL
      || strstr(fname, "//") != NULL
# ifdef BACKSLASH_IN_FILENAME
      || strstr(fname, "\\\\") != NULL
# endif
      )
    return FullName_save(fname, false);

  fname = xstrdup(fname);

# ifdef USE_FNAME_CASE
  path_fix_case((char_u *)fname);  // set correct case for file name
# endif

  return (char *)fname;
#endif
}

/// Set the case of the file name, if it already exists.  This will cause the
/// file name to remain exactly the same.
/// Only required for file systems where case is ignored and preserved.
// TODO(SplinterOfChaos): Could also be used when mounting case-insensitive
// file systems.
void path_fix_case(char_u *name)
  FUNC_ATTR_NONNULL_ALL
{
  FileInfo file_info;
  if (!os_fileinfo_link((char *)name, &file_info)) {
    return;
  }

  // Open the directory where the file is located.
  char_u *slash = vim_strrchr(name, '/');
  char_u *tail;
  Directory dir;
  bool ok;
  if (slash == NULL) {
    ok = os_scandir(&dir, ".");
    tail = name;
  } else {
    *slash = NUL;
    ok = os_scandir(&dir, (char *) name);
    *slash = '/';
    tail = slash + 1;
  }

  if (!ok) {
    return;
  }

  char_u *entry;
  while ((entry = (char_u *) os_scandir_next(&dir))) {
    // Only accept names that differ in case and are the same byte
    // length. TODO: accept different length name.
    if (STRICMP(tail, entry) == 0 && STRLEN(tail) == STRLEN(entry)) {
      char_u newname[MAXPATHL + 1];

      // Verify the inode is equal.
      STRLCPY(newname, name, MAXPATHL + 1);
      STRLCPY(newname + (tail - name), entry,
              MAXPATHL - (tail - name) + 1);
      FileInfo file_info_new;
      if (os_fileinfo_link((char *)newname, &file_info_new)
          && os_fileinfo_id_equal(&file_info, &file_info_new)) {
        STRCPY(tail, entry);
        break;
      }
    }
  }

  os_closedir(&dir);
}

/*
 * Return TRUE if "p" points to just after a path separator.
 * Takes care of multi-byte characters.
 * "b" must point to the start of the file name
 */
int after_pathsep(const char *b, const char *p)
{
  return p > b && vim_ispathsep(p[-1])
         && (!has_mbyte || (*mb_head_off)((char_u *)b, (char_u *)p - 1) == 0);
}

/*
 * Return TRUE if file names "f1" and "f2" are in the same directory.
 * "f1" may be a short name, "f2" must be a full path.
 */
bool same_directory(char_u *f1, char_u *f2)
{
  char_u ffname[MAXPATHL];
  char_u      *t1;
  char_u      *t2;

  /* safety check */
  if (f1 == NULL || f2 == NULL)
    return false;

  (void)vim_FullName((char *)f1, (char *)ffname, MAXPATHL, FALSE);
  t1 = path_tail_with_sep(ffname);
  t2 = path_tail_with_sep(f2);
  return t1 - ffname == t2 - f2
         && pathcmp((char *)ffname, (char *)f2, (int)(t1 - ffname)) == 0;
}

/*
 * Compare path "p[]" to "q[]".
 * If "maxlen" >= 0 compare "p[maxlen]" to "q[maxlen]"
 * Return value like strcmp(p, q), but consider path separators.
 */
int pathcmp(const char *p, const char *q, int maxlen)
{
  int i, j;
  int c1, c2;
  const char  *s = NULL;

  for (i = 0, j = 0; maxlen < 0 || (i < maxlen && j < maxlen);) {
    c1 = PTR2CHAR((char_u *)p + i);
    c2 = PTR2CHAR((char_u *)q + j);

    /* End of "p": check if "q" also ends or just has a slash. */
    if (c1 == NUL) {
      if (c2 == NUL)        /* full match */
        return 0;
      s = q;
      i = j;
      break;
    }

    /* End of "q": check if "p" just has a slash. */
    if (c2 == NUL) {
      s = p;
      break;
    }

    if ((p_fic ? mb_toupper(c1) != mb_toupper(c2) : c1 != c2)
#ifdef BACKSLASH_IN_FILENAME
        /* consider '/' and '\\' to be equal */
        && !((c1 == '/' && c2 == '\\')
             || (c1 == '\\' && c2 == '/'))
#endif
        ) {
      if (vim_ispathsep(c1))
        return -1;
      if (vim_ispathsep(c2))
        return 1;
      return p_fic ? mb_toupper(c1) - mb_toupper(c2)
                   : c1 - c2;  // no match
    }

    i += MB_PTR2LEN((char_u *)p + i);
    j += MB_PTR2LEN((char_u *)q + j);
  }
  if (s == NULL) {  // "i" or "j" ran into "maxlen"
    return 0;
  }

  c1 = PTR2CHAR((char_u *)s + i);
  c2 = PTR2CHAR((char_u *)s + i + MB_PTR2LEN((char_u *)s + i));
  /* ignore a trailing slash, but not "//" or ":/" */
  if (c2 == NUL
      && i > 0
      && !after_pathsep((char *)s, (char *)s + i)
#ifdef BACKSLASH_IN_FILENAME
      && (c1 == '/' || c1 == '\\')
#else
      && c1 == '/'
#endif
      )
    return 0;       /* match with trailing slash */
  if (s == q)
    return -1;              /* no match */
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
char_u *path_try_shorten_fname(char_u *full_path)
{
  char_u *dirname = xmalloc(MAXPATHL);
  char_u *p = full_path;

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
char_u *path_shorten_fname(char_u *full_path, char_u *dir_name)
{
  if (full_path == NULL) {
    return NULL;
  }

  assert(dir_name != NULL);
  size_t len = strlen((char *)dir_name);
  char_u *p = full_path + len;

  if (fnamencmp(dir_name, full_path, len) != 0
      || !vim_ispathsep(*p)) {
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
int expand_wildcards_eval(char_u **pat, int *num_file, char_u ***file,
                          int flags)
{
  int ret = FAIL;
  char_u      *eval_pat = NULL;
  char_u      *exp_pat = *pat;
  char_u      *ignored_msg;
  size_t usedlen;

  if (*exp_pat == '%' || *exp_pat == '#' || *exp_pat == '<') {
    ++emsg_off;
    eval_pat = eval_vars(exp_pat, exp_pat, &usedlen,
        NULL, &ignored_msg, NULL);
    --emsg_off;
    if (eval_pat != NULL)
      exp_pat = concat_str(eval_pat, exp_pat + usedlen);
  }

  if (exp_pat != NULL)
    ret = expand_wildcards(1, &exp_pat, num_file, file, flags);

  if (eval_pat != NULL) {
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
int expand_wildcards(int num_pat, char_u **pat, int *num_files, char_u ***files,
                     int flags)
{
  int retval;
  int i, j;
  char_u      *p;
  int non_suf_match;            /* number without matching suffix */

  retval = gen_expand_wildcards(num_pat, pat, num_files, files, flags);

  /* When keeping all matches, return here */
  if ((flags & EW_KEEPALL) || retval == FAIL)
    return retval;

  /*
   * Remove names that match 'wildignore'.
   */
  if (*p_wig) {
    char_u  *ffname;

    // check all filess in (*files)[]
    for (i = 0; i < *num_files; i++) {
      ffname = (char_u *)FullName_save((char *)(*files)[i], false);
      if (ffname == NULL) {               // out of memory
        break;
      }
      if (match_file_list(p_wig, (*files)[i], ffname)) {
        // remove this matching files from the list
        xfree((*files)[i]);
        for (j = i; j + 1 < *num_files; j++) {
          (*files)[j] = (*files)[j + 1];
        }
        (*num_files)--;
        i--;
      }
      xfree(ffname);
    }
  }

  /*
   * Move the names where 'suffixes' match to the end.
   */
  if (*num_files > 1) {
    non_suf_match = 0;
    for (i = 0; i < *num_files; i++) {
      if (!match_suffix((*files)[i])) {
        //
        // Move the name without matching suffix to the front
        // of the list.
        //
        p = (*files)[i];
        for (j = i; j > non_suf_match; j--) {
          (*files)[j] = (*files)[j - 1];
        }
        (*files)[non_suf_match++] = p;
      }
    }
  }

  // Free empty array of matches
  if (*num_files == 0) {
    xfree(*files);
    *files = NULL;
    return FAIL;
  }

  return retval;
}

/*
 * Return TRUE if "fname" matches with an entry in 'suffixes'.
 */
int match_suffix(char_u *fname)
{
#define MAXSUFLEN 30  // maximum length of a file suffix
  char_u suf_buf[MAXSUFLEN];

  size_t fnamelen = STRLEN(fname);
  size_t setsuflen = 0;
  for (char_u *setsuf = p_su; *setsuf; ) {
    setsuflen = copy_option_part(&setsuf, suf_buf, MAXSUFLEN, ".,");
    if (setsuflen == 0) {
      char_u *tail = path_tail(fname);

      /* empty entry: match name without a '.' */
      if (vim_strchr(tail, '.') == NULL) {
        setsuflen = 1;
        break;
      }
    } else {
      if (fnamelen >= setsuflen
          && fnamencmp(suf_buf, fname + fnamelen - setsuflen, setsuflen) == 0) {
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

  if (STRLEN(directory) == 0) {
    return os_dirname((char_u *) buffer, len);
  }

  char old_dir[MAXPATHL];

  // Get current directory name.
  if (os_dirname((char_u *) old_dir, MAXPATHL) == FAIL) {
    return FAIL;
  }

  // We have to get back to the current dir at the end, check if that works.
  if (os_chdir(old_dir) != SUCCESS) {
    return FAIL;
  }

  if (os_chdir(directory) != SUCCESS) {
    // Do not return immediately since we may be in the wrong directory.
    retval = FAIL;
  }

  if (retval == FAIL || os_dirname((char_u *) buffer, len) == FAIL) {
    // Do not return immediately since we are in the wrong directory.
    retval = FAIL;
  }

  if (os_chdir(old_dir) != SUCCESS) {
    // That shouldn't happen, since we've tested if it works.
    retval = FAIL;
    EMSG(_(e_prev_dir));
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
  if (current_length > 0 && !vim_ispathsep_nocolon(path[current_length-1])) {
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
static int path_to_absolute(const char_u *fname, char_u *buf, size_t len,
                            int force)
{
  char_u *p;
  *buf = NUL;

  char *relative_directory = xmalloc(len);
  char *end_of_path = (char *) fname;

  // expand it if forced or not an absolute path
  if (force || !path_is_absolute(fname)) {
    p = vim_strrchr(fname, '/');
#ifdef WIN32
    if (p == NULL) {
      p = vim_strrchr(fname, '\\');
    }
#endif
    if (p != NULL) {
      // relative to root
      if (p == fname) {
        // only one path component
        relative_directory[0] = PATHSEP;
        relative_directory[1] = NUL;
      } else {
        assert(p >= fname);
        memcpy(relative_directory, fname, (size_t)(p - fname));
        relative_directory[p-fname] = NUL;
      }
      end_of_path = (char *) (p + 1);
    } else {
      relative_directory[0] = NUL;
      end_of_path = (char *) fname;
    }

    if (FAIL == path_full_dir_name(relative_directory, (char *) buf, len)) {
      xfree(relative_directory);
      return FAIL;
    }
  }
  xfree(relative_directory);
  return append_path((char *)buf, end_of_path, len);
}

/// Check if file `fname` is a full (absolute) path.
///
/// @return `TRUE` if "fname" is absolute.
int path_is_absolute(const char_u *fname)
{
#ifdef WIN32
  // A name like "d:/foo" and "//server/share" is absolute
  return ((isalpha(fname[0]) && fname[1] == ':'
           && vim_ispathsep_nocolon(fname[2]))
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
  char *path = getenv("PATH");

  if (path == NULL || path_is_absolute((char_u *)argv0)) {
    xstrlcpy(buf, argv0, bufsize);
  } else if (argv0[0] == '.' || strchr(argv0, PATHSEP)) {
    // Relative to CWD.
    if (os_dirname((char_u *)buf, MAXPATHL) != OK) {
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
      xstrlcpy((char *)NameBuff, dir, dir_len + 1);
      xstrlcat((char *)NameBuff, PATHSEPSTR, sizeof(NameBuff));
      xstrlcat((char *)NameBuff, argv0, sizeof(NameBuff));
      if (os_can_exe(NameBuff, NULL, false)) {
        xstrlcpy(buf, (char *)NameBuff, bufsize);
        return;
      }
    } while (iter != NULL);
    // Not found in $PATH, fall back to argv0.
    xstrlcpy(buf, argv0, bufsize);
  }
}
