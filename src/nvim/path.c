#include <stdlib.h>

#include "nvim/vim.h"
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
#include "nvim/misc2.h"
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
#include "nvim/ui.h"
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
  uv_stat_t st1, st2;

  expand_env(s1, exp1, MAXPATHL);
  int r1 = os_stat(exp1, &st1);
  int r2 = os_stat(s2, &st2);
  if (r1 != OK && r2 != OK) {
    // If os_stat() doesn't work, may compare the names.
    if (checkname) {
      vim_FullName(exp1, full1, MAXPATHL, FALSE);
      vim_FullName(s2, full2, MAXPATHL, FALSE);
      if (fnamecmp(full1, full2) == 0) {
        return kEqualFileNames;
      }
    }
    return kBothFilesMissing;
  }
  if (r1 != OK || r2 != OK) {
    return kOneFileMissing;
  }
  if (st1.st_dev == st2.st_dev && st1.st_ino == st2.st_ino) {
    return kEqualFiles;
  }
  return kDifferentFiles;
}

/// Get the tail of a path: the file name.
///
/// @param fname A file path.
/// @return
///   - Empty string, if fname is NULL.
///   - The position of the last path separator + 1. (i.e. empty string, if
///   fname ends in a slash).
///   - Never NULL.
char_u *path_tail(char_u *fname)
{
  if (fname == NULL) {
    return (char_u *)"";
  }

  char_u *tail = get_past_head(fname);
  char_u *p = tail;
  // Find last part of path.
  while (*p != NUL) {
    if (vim_ispathsep_nocolon(*p)) {
      tail = p + 1;
    }
    mb_ptr_adv(p);
  }
  return tail;
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
  while (tail > past_head && after_pathsep(fname, tail)) {
    tail--;
  }
  return tail;
}

/// Get the next path component of a path name.
///
/// @param fname A file path. (Must be != NULL.)
/// @return Pointer to first found path separator + 1.
/// An empty string, if `fname` doesn't contain a path separator,
char_u *path_next_component(char_u *fname)
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

/*
 * Get a pointer to one character past the head of a path name.
 * Unix: after "/"; DOS: after "c:\"; Amiga: after "disk:/"; Mac: no head.
 * If there is no head, path is returned.
 */
char_u *get_past_head(char_u *path)
{
  char_u  *retval;

  retval = path;

  while (vim_ispathsep(*retval))
    ++retval;

  return retval;
}

/*
 * Return TRUE if 'c' is a path separator.
 * Note that for MS-Windows this includes the colon.
 */
int vim_ispathsep(int c)
{
#ifdef UNIX
  return c == '/';          /* UNIX has ':' inside file names */
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
void shorten_dir(char_u *str)
{
  char_u      *tail, *s, *d;
  int skip = FALSE;

  tail = path_tail(str);
  d = str;
  for (s = str;; ++s) {
    if (s >= tail) {                /* copy the whole tail */
      *d++ = *s;
      if (*s == NUL)
        break;
    } else if (vim_ispathsep(*s)) {       /* copy '/' and next char */
      *d++ = *s;
      skip = FALSE;
    } else if (!skip) {
      *d++ = *s;                    /* copy next char */
      if (*s != '~' && *s != '.')       /* and leading "~" and "." */
        skip = TRUE;
      if (has_mbyte) {
        int l = mb_ptr2len(s);

        while (--l > 0)
          *d++ = *++s;
      }
    }
  }
}

/*
 * Return TRUE if the directory of "fname" exists, FALSE otherwise.
 * Also returns TRUE if there is no directory name.
 * "fname" must be writable!.
 */
int dir_of_file_exists(char_u *fname)
{
  char_u      *p;
  int c;
  int retval;

  p = path_tail_with_sep(fname);
  if (p == fname)
    return TRUE;
  c = *p;
  *p = NUL;
  retval = os_isdir(fname);
  *p = c;
  return retval;
}

/*
 * Versions of fnamecmp() and fnamencmp() that handle '/' and '\' equally
 * and deal with 'fileignorecase'.
 */
int vim_fnamecmp(char_u *x, char_u *y)
{
#ifdef BACKSLASH_IN_FILENAME
  return vim_fnamencmp(x, y, MAXPATHL);
#else
  if (p_fic)
    return MB_STRICMP(x, y);
  return STRCMP(x, y);
#endif
}

int vim_fnamencmp(char_u *x, char_u *y, size_t len)
{
#ifdef BACKSLASH_IN_FILENAME
  char_u      *px = x;
  char_u      *py = y;
  int cx = NUL;
  int cy = NUL;

  while (len > 0) {
    cx = PTR2CHAR(px);
    cy = PTR2CHAR(py);
    if (cx == NUL || cy == NUL
        || ((p_fic ? vim_tolower(cx) != vim_tolower(cy) : cx != cy)
            && !(cx == '/' && cy == '\\')
            && !(cx == '\\' && cy == '/')))
      break;
    len -= MB_PTR2LEN(px);
    px += MB_PTR2LEN(px);
    py += MB_PTR2LEN(py);
  }
  if (len == 0)
    return 0;
  return cx - cy;
#else
  if (p_fic)
    return MB_STRNICMP(x, y, len);
  return STRNCMP(x, y, len);
#endif
}

/*
 * Concatenate file names fname1 and fname2 into allocated memory.
 * Only add a '/' or '\\' when 'sep' is TRUE and it is necessary.
 */
char_u *concat_fnames(char_u *fname1, char_u *fname2, int sep)
  FUNC_ATTR_NONNULL_RET
{
  char_u *dest = xmalloc(STRLEN(fname1) + STRLEN(fname2) + 3);

  STRCPY(dest, fname1);
  if (sep) {
    add_pathsep(dest);
  }
  STRCAT(dest, fname2);

  return dest;
}

/*
 * Add a path separator to a file name, unless it already ends in a path
 * separator.
 */
void add_pathsep(char_u *p)
{
  if (*p != NUL && !after_pathsep(p, p + STRLEN(p)))
    STRCAT(p, PATHSEPSTR);
}

/*
 * FullName_save - Make an allocated copy of a full file name.
 * Returns NULL when fname is NULL.
 */
char_u *
FullName_save (
    char_u *fname,
    int force                      /* force expansion, even when it already looks
                                 * like a full path name */
)
{
  char_u      *new_fname = NULL;

  if (fname == NULL)
    return NULL;

  char_u *buf = xmalloc(MAXPATHL);

  if (vim_FullName(fname, buf, MAXPATHL, force) != FAIL) {
    new_fname = vim_strsave(buf);
  } else {
    new_fname = vim_strsave(fname);
  }
  free(buf);

  return new_fname;
}

#if !defined(NO_EXPANDPATH) || defined(PROTO)

#if defined(UNIX) || defined(USE_UNIXFILENAME) || defined(PROTO)
/*
 * Unix style wildcard expansion code.
 * It's here because it's used both for Unix and Mac.
 */
static int pstrcmp(const void *a, const void *b)
{
  return pathcmp(*(char **)a, *(char **)b, -1);
}

/*
 * Recursively expand one path component into all matching files and/or
 * directories.  Adds matches to "gap".  Handles "*", "?", "[a-z]", "**", etc.
 * "path" has backslashes before chars that are not to be expanded, starting
 * at "path + wildoff".
 * Return the number of matches found.
 * NOTE: much of this is identical to dos_expandpath(), keep in sync!
 */
int 
unix_expandpath (
    garray_T *gap,
    char_u *path,
    int wildoff,
    int flags,                      /* EW_* flags */
    int didstar                    /* expanded "**" once already */
)
{
  char_u      *buf;
  char_u      *path_end;
  char_u      *p, *s, *e;
  int start_len = gap->ga_len;
  char_u      *pat;
  regmatch_T regmatch;
  int starts_with_dot;
  int matches;
  int len;
  int starstar = FALSE;
  static int stardepth = 0;         /* depth for "**" expansion */

  DIR         *dirp;
  struct dirent *dp;

  /* Expanding "**" may take a long time, check for CTRL-C. */
  if (stardepth > 0) {
    ui_breakcheck();
    if (got_int)
      return 0;
  }

  /* make room for file name */
  buf = xmalloc(STRLEN(path) + BASENAMELEN + 5);

  /*
   * Find the first part in the path name that contains a wildcard.
   * When EW_ICASE is set every letter is considered to be a wildcard.
   * Copy it into "buf", including the preceding characters.
   */
  p = buf;
  s = buf;
  e = NULL;
  path_end = path;
  while (*path_end != NUL) {
    /* May ignore a wildcard that has a backslash before it; it will
     * be removed by rem_backslash() or file_pat_to_reg_pat() below. */
    if (path_end >= path + wildoff && rem_backslash(path_end))
      *p++ = *path_end++;
    else if (*path_end == '/') {
      if (e != NULL)
        break;
      s = p + 1;
    } else if (path_end >= path + wildoff
               && (vim_strchr((char_u *)"*?[{~$", *path_end) != NULL
                   || (!p_fic && (flags & EW_ICASE)
                       && isalpha(PTR2CHAR(path_end)))))
      e = p;
    if (has_mbyte) {
      len = (*mb_ptr2len)(path_end);
      STRNCPY(p, path_end, len);
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
      starstar = TRUE;

  /* convert the file pattern to a regexp pattern */
  starts_with_dot = (*s == '.');
  pat = file_pat_to_reg_pat(s, e, NULL, FALSE);
  if (pat == NULL) {
    free(buf);
    return 0;
  }

  /* compile the regexp into a program */
  if (flags & EW_ICASE)
    regmatch.rm_ic = TRUE;              /* 'wildignorecase' set */
  else
    regmatch.rm_ic = p_fic;     /* ignore case when 'fileignorecase' is set */
  if (flags & (EW_NOERROR | EW_NOTWILD))
    ++emsg_silent;
  regmatch.regprog = vim_regcomp(pat, RE_MAGIC);
  if (flags & (EW_NOERROR | EW_NOTWILD))
    --emsg_silent;
  free(pat);

  if (regmatch.regprog == NULL && (flags & EW_NOTWILD) == 0) {
    free(buf);
    return 0;
  }

  /* If "**" is by itself, this is the first time we encounter it and more
   * is following then find matches without any directory. */
  if (!didstar && stardepth < 100 && starstar && e - s == 2
      && *path_end == '/') {
    STRCPY(s, path_end + 1);
    ++stardepth;
    (void)unix_expandpath(gap, buf, (int)(s - buf), flags, TRUE);
    --stardepth;
  }

  /* open the directory for scanning */
  *s = NUL;
  dirp = opendir(*buf == NUL ? "." : (char *)buf);

  /* Find all matching entries */
  if (dirp != NULL) {
    for (;; ) {
      dp = readdir(dirp);
      if (dp == NULL)
        break;
      if ((dp->d_name[0] != '.' || starts_with_dot)
          && ((regmatch.regprog != NULL && vim_regexec(&regmatch,
                   (char_u *)dp->d_name, (colnr_T)0))
              || ((flags & EW_NOTWILD)
                  && fnamencmp(path + (s - buf), dp->d_name, e - s) == 0))) {
        STRCPY(s, dp->d_name);
        len = STRLEN(buf);

        if (starstar && stardepth < 100) {
          /* For "**" in the pattern first go deeper in the tree to
           * find matches. */
          STRCPY(buf + len, "/**");
          STRCPY(buf + len + 3, path_end);
          ++stardepth;
          (void)unix_expandpath(gap, buf, len + 1, flags, TRUE);
          --stardepth;
        }

        STRCPY(buf + len, path_end);
        if (mch_has_exp_wildcard(path_end)) {       /* handle more wildcards */
          /* need to expand another component of the path */
          /* remove backslashes for the remaining components only */
          (void)unix_expandpath(gap, buf, len + 1, flags, FALSE);
        } else {
          /* no more wildcards, check if there is a match */
          /* remove backslashes for the remaining components only */
          if (*path_end != NUL)
            backslash_halve(buf + len + 1);
          if (os_file_exists(buf)) {          /* add existing file */
#ifdef MACOS_CONVERT
            size_t precomp_len = STRLEN(buf)+1;
            char_u *precomp_buf =
              mac_precompose_path(buf, precomp_len, &precomp_len);

            if (precomp_buf) {
              memmove(buf, precomp_buf, precomp_len);
              free(precomp_buf);
            }
#endif
            addfile(gap, buf, flags);
          }
        }
      }
    }

    closedir(dirp);
  }

  free(buf);
  vim_regfree(regmatch.regprog);

  matches = gap->ga_len - start_len;
  if (matches > 0)
    qsort(((char_u **)gap->ga_data) + start_len, matches,
        sizeof(char_u *), pstrcmp);
  return matches;
}
#endif

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
static int is_unique(char_u *maybe_unique, garray_T *gap, int i)
{
  int candidate_len;
  int other_path_len;
  char_u  **other_paths = (char_u **)gap->ga_data;
  char_u  *rival;

  for (int j = 0; j < gap->ga_len; j++) {
    if (j == i)
      continue;        /* don't compare it with itself */

    candidate_len = (int)STRLEN(maybe_unique);
    other_path_len = (int)STRLEN(other_paths[j]);
    if (other_path_len < candidate_len)
      continue;        /* it's different when it's shorter */

    rival = other_paths[j] + other_path_len - candidate_len;
    if (fnamecmp(maybe_unique, rival) == 0
        && (rival == other_paths[j] || vim_ispathsep(*(rival - 1))))
      return FALSE;        /* match */
  }

  return TRUE;    /* no match found */
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
  char_u      *path_option = *curbuf->b_p_path == NUL
                             ? p_path : curbuf->b_p_path;
  char_u      *buf;
  char_u      *p;
  int len;

  buf = xmalloc(MAXPATHL);

  while (*path_option != NUL) {
    copy_option_part(&path_option, buf, MAXPATHL, " ,");

    if (buf[0] == '.' && (buf[1] == NUL || vim_ispathsep(buf[1]))) {
      /* Relative to current buffer:
       * "/path/file" + "." -> "/path/"
       * "/path/file"  + "./subdir" -> "/path/subdir" */
      if (curbuf->b_ffname == NULL)
        continue;
      p = path_tail(curbuf->b_ffname);
      len = (int)(p - curbuf->b_ffname);
      if (len + (int)STRLEN(buf) >= MAXPATHL)
        continue;
      if (buf[1] == NUL)
        buf[len] = NUL;
      else
        STRMOVE(buf + len, buf + 2);
      memmove(buf, curbuf->b_ffname, len);
      simplify_filename(buf);
    } else if (buf[0] == NUL)
      /* relative to current directory */
      STRCPY(buf, curdir);
    else if (path_with_url(buf))
      /* URL can't be used here */
      continue;
    else if (!path_is_absolute_path(buf)) {
      /* Expand relative path to their full path equivalent */
      len = (int)STRLEN(curdir);
      if (len + (int)STRLEN(buf) + 3 > MAXPATHL)
        continue;
      STRMOVE(buf + len + 1, buf);
      STRCPY(buf, curdir);
      buf[len] = PATHSEP;
      simplify_filename(buf);
    }

    ga_grow(gap, 1);

    p = vim_strsave(buf);
    ((char_u **)gap->ga_data)[gap->ga_len++] = p;
  }

  free(buf);
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
  int len;
  char_u      **fnames = (char_u **)gap->ga_data;
  int sort_again = FALSE;
  char_u      *pat;
  char_u      *file_pattern;
  char_u      *curdir;
  regmatch_T regmatch;
  garray_T path_ga;
  char_u      **in_curdir = NULL;
  char_u      *short_name;

  ga_remove_duplicate_strings(gap);
  ga_init(&path_ga, (int)sizeof(char_u *), 1);

  /*
   * We need to prepend a '*' at the beginning of file_pattern so that the
   * regex matches anywhere in the path. FIXME: is this valid for all
   * possible patterns?
   */
  len = (int)STRLEN(pattern);
  file_pattern = xmalloc(len + 2);
  file_pattern[0] = '*';
  file_pattern[1] = NUL;
  STRCAT(file_pattern, pattern);
  pat = file_pat_to_reg_pat(file_pattern, NULL, NULL, TRUE);
  free(file_pattern);
  if (pat == NULL)
    return;

  regmatch.rm_ic = TRUE;                /* always ignore case */
  regmatch.regprog = vim_regcomp(pat, RE_MAGIC + RE_STRING);
  free(pat);
  if (regmatch.regprog == NULL)
    return;

  curdir = xmalloc(MAXPATHL);
  os_dirname(curdir, MAXPATHL);
  expand_path_option(curdir, &path_ga);

  in_curdir = xcalloc(gap->ga_len, sizeof(char_u *));

  for (int i = 0; i < gap->ga_len && !got_int; i++) {
    char_u      *path = fnames[i];
    int is_in_curdir;
    char_u      *dir_end = gettail_dir(path);
    char_u      *pathsep_p;
    char_u      *path_cutoff;

    len = (int)STRLEN(path);
    is_in_curdir = fnamencmp(curdir, path, dir_end - path) == 0
                   && curdir[dir_end - path] == NUL;
    if (is_in_curdir)
      in_curdir[i] = vim_strsave(path);

    /* Shorten the filename while maintaining its uniqueness */
    path_cutoff = get_path_cutoff(path, &path_ga);

    /* we start at the end of the path */
    pathsep_p = path + len - 1;

    while (find_previous_pathsep(path, &pathsep_p))
      if (vim_regexec(&regmatch, pathsep_p + 1, (colnr_T)0)
          && is_unique(pathsep_p + 1, gap, i)
          && path_cutoff != NULL && pathsep_p + 1 >= path_cutoff) {
        sort_again = TRUE;
        memmove(path, pathsep_p + 1, STRLEN(pathsep_p));
        break;
      }

    if (path_is_absolute_path(path)) {
      /*
       * Last resort: shorten relative to curdir if possible.
       * 'possible' means:
       * 1. It is under the current directory.
       * 2. The result is actually shorter than the original.
       *
       *	    Before		  curdir	After
       *	    /foo/bar/file.txt	  /foo/bar	./file.txt
       *	    c:\foo\bar\file.txt   c:\foo\bar	.\file.txt
       *	    /file.txt		  /		/file.txt
       *	    c:\file.txt		  c:\		.\file.txt
       */
      short_name = path_shorten_fname(path, curdir);
      if (short_name != NULL && short_name > path + 1
          ) {
        STRCPY(path, ".");
        add_pathsep(path);
        STRMOVE(path + STRLEN(path), short_name);
      }
    }
    ui_breakcheck();
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
    add_pathsep(rel_path);
    STRCAT(rel_path, short_name);

    free(fnames[i]);
    fnames[i] = rel_path;
    sort_again = TRUE;
    ui_breakcheck();
  }

  free(curdir);
  if (in_curdir != NULL) {
    for (int i = 0; i < gap->ga_len; i++)
      free(in_curdir[i]);
    free(in_curdir);
  }
  ga_clear_strings(&path_ga);
  vim_regfree(regmatch.regprog);

  if (sort_again)
    ga_remove_duplicate_strings(gap);
}

/*
 * Return the end of the directory name, on the first path
 * separator:
 * "/path/file", "/path/dir/", "/path//dir", "/file"
 *	 ^	       ^	     ^	      ^
 */
static char_u *gettail_dir(char_u *fname)
{
  char_u      *dir_end = fname;
  char_u      *next_dir_end = fname;
  int look_for_sep = TRUE;
  char_u      *p;

  for (p = fname; *p != NUL; ) {
    if (vim_ispathsep(*p)) {
      if (look_for_sep) {
        next_dir_end = p;
        look_for_sep = FALSE;
      }
    } else {
      if (!look_for_sep)
        dir_end = next_dir_end;
      look_for_sep = TRUE;
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
  char_u      *files = NULL;
  char_u      *s;       /* start */
  char_u      *e;       /* end */
  char_u      *paths = NULL;

  curdir = xmalloc(MAXPATHL);
  os_dirname(curdir, MAXPATHL);

  ga_init(&path_ga, (int)sizeof(char_u *), 1);
  expand_path_option(curdir, &path_ga);
  free(curdir);
  if (GA_EMPTY(&path_ga))
    return 0;

  paths = ga_concat_strings(&path_ga);
  ga_clear_strings(&path_ga);

  files = globpath(paths, pattern, (flags & EW_ICASE) ? WILD_ICASE : 0);
  free(paths);
  if (files == NULL)
    return 0;

  /* Copy each path in files into gap */
  s = e = files;
  while (*s != NUL) {
    while (*e != '\n' && *e != NUL)
      e++;
    if (*e == NUL) {
      addfile(gap, s, flags);
      break;
    } else {
      /* *e is '\n' */
      *e = NUL;
      addfile(gap, s, flags);
      e++;
      s = e;
    }
  }
  free(files);

  return gap->ga_len;
}


/*
 * Return TRUE if "p" contains what looks like an environment variable.
 * Allowing for escaping.
 */
static int has_env_var(char_u *p)
{
  for (; *p; mb_ptr_adv(p)) {
    if (*p == '\\' && p[1] != NUL)
      ++p;
    else if (vim_strchr((char_u *)
                 "$"
                 , *p) != NULL)
      return TRUE;
  }
  return FALSE;
}

#ifdef SPECIAL_WILDCHAR
/*
 * Return TRUE if "p" contains a special wildcard character.
 * Allowing for escaping.
 */
static int has_special_wildchar(char_u *p)
{
  for (; *p; mb_ptr_adv(p)) {
    if (*p == '\\' && p[1] != NUL)
      ++p;
    else if (vim_strchr((char_u *)SPECIAL_WILDCHAR, *p) != NULL)
      return TRUE;
  }
  return FALSE;
}
#endif

/*
 * Generic wildcard expansion code.
 *
 * Characters in "pat" that should not be expanded must be preceded with a
 * backslash. E.g., "/path\ with\ spaces/my\*star*"
 *
 * Return FAIL when no single file was found.  In this case "num_file" is not
 * set, and "file" may contain an error message.
 * Return OK when some files found.  "num_file" is set to the number of
 * matches, "file" to the array of matches.  Call FreeWild() later.
 */
int 
gen_expand_wildcards (
    int num_pat,                    /* number of input patterns */
    char_u **pat,              /* array of input patterns */
    int *num_file,          /* resulting number of files */
    char_u ***file,            /* array of resulting files */
    int flags                      /* EW_* flags */
)
{
  int i;
  garray_T ga;
  char_u              *p;
  static int recursive = FALSE;
  int add_pat;
  int did_expand_in_path = FALSE;

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
  for (i = 0; i < num_pat; i++) {
    if (has_special_wildchar(pat[i])
        && !(vim_backtick(pat[i]) && pat[i][1] == '=')
        )
      return mch_expand_wildcards(num_pat, pat, num_file, file, flags);
  }
#endif

  recursive = TRUE;

  /*
   * The matching file names are stored in a growarray.  Init it empty.
   */
  ga_init(&ga, (int)sizeof(char_u *), 30);

  for (i = 0; i < num_pat; ++i) {
    add_pat = -1;
    p = pat[i];

    if (vim_backtick(p))
      add_pat = expand_backtick(&ga, p, flags);
    else {
      /*
       * First expand environment variables, "~/" and "~user/".
       */
      if (has_env_var(p) || *p == '~') {
        p = expand_env_save_opt(p, TRUE);
        if (p == NULL)
          p = pat[i];
#ifdef UNIX
        /*
         * On Unix, if expand_env() can't expand an environment
         * variable, use the shell to do that.  Discard previously
         * found file names and start all over again.
         */
        else if (has_env_var(p) || *p == '~') {
          free(p);
          ga_clear_strings(&ga);
          i = mch_expand_wildcards(num_pat, pat, num_file, file,
              flags);
          recursive = FALSE;
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
      if (mch_has_exp_wildcard(p)) {
        if ((flags & EW_PATH)
            && !path_is_absolute_path(p)
            && !(p[0] == '.'
                 && (vim_ispathsep(p[1])
                     || (p[1] == '.' && vim_ispathsep(p[2]))))
            ) {
          /* :find completion where 'path' is used.
           * Recursiveness is OK here. */
          recursive = FALSE;
          add_pat = expand_in_path(&ga, p, flags);
          recursive = TRUE;
          did_expand_in_path = TRUE;
        } else
          add_pat = mch_expandpath(&ga, p, flags);
      }
    }

    if (add_pat == -1 || (add_pat == 0 && (flags & EW_NOTFOUND))) {
      char_u      *t = backslash_halve_save(p);

      /* When EW_NOTFOUND is used, always add files and dirs.  Makes
       * "vim c:/" work. */
      if (flags & EW_NOTFOUND)
        addfile(&ga, t, flags | EW_DIR | EW_FILE);
      else if (os_file_exists(t))
        addfile(&ga, t, flags);
      free(t);
    }

    if (did_expand_in_path && !GA_EMPTY(&ga) && (flags & EW_PATH))
      uniquefy_paths(&ga, p);
    if (p != pat[i])
      free(p);
  }

  *num_file = ga.ga_len;
  *file = (ga.ga_data != NULL) ? (char_u **)ga.ga_data : (char_u **)"";

  recursive = FALSE;

  return (ga.ga_data != NULL) ? OK : FAIL;
}


/*
 * Return TRUE if we can expand this backtick thing here.
 */
static int vim_backtick(char_u *p)
{
  return *p == '`' && *(p + 1) != NUL && *(p + STRLEN(p) - 1) == '`';
}

/*
 * Expand an item in `backticks` by executing it as a command.
 * Currently only works when pat[] starts and ends with a `.
 * Returns number of file names found.
 */
static int 
expand_backtick (
    garray_T *gap,
    char_u *pat,
    int flags              /* EW_* flags */
)
{
  char_u      *p;
  char_u      *cmd;
  char_u      *buffer;
  int cnt = 0;
  int i;

  /* Create the command: lop off the backticks. */
  cmd = vim_strnsave(pat + 1, (int)STRLEN(pat) - 2);

  if (*cmd == '=')          /* `={expr}`: Expand expression */
    buffer = eval_to_string(cmd + 1, &p, TRUE);
  else
    buffer = get_cmd_output(cmd, NULL,
        (flags & EW_SILENT) ? kShellOptSilent : 0);
  free(cmd);
  if (buffer == NULL)
    return 0;

  cmd = buffer;
  while (*cmd != NUL) {
    cmd = skipwhite(cmd);               /* skip over white space */
    p = cmd;
    while (*p != NUL && *p != '\r' && *p != '\n')     /* skip over entry */
      ++p;
    /* add an entry if it is not empty */
    if (p > cmd) {
      i = *p;
      *p = NUL;
      addfile(gap, cmd, flags);
      *p = i;
      ++cnt;
    }
    cmd = p;
    while (*cmd != NUL && (*cmd == '\r' || *cmd == '\n'))
      ++cmd;
  }

  free(buffer);
  return cnt;
}

/*
 * Add a file to a file list.  Accepted flags:
 * EW_DIR	add directories
 * EW_FILE	add files
 * EW_EXEC	add executable files
 * EW_NOTFOUND	add even when it doesn't exist
 * EW_ADDSLASH	add slash after directory name
 */
void 
addfile (
    garray_T *gap,
    char_u *f,         /* filename */
    int flags
)
{
  char_u      *p;
  bool isdir;

  /* if the file/dir doesn't exist, may not add it */
  if (!(flags & EW_NOTFOUND) && !os_file_exists(f))
    return;

#ifdef FNAME_ILLEGAL
  /* if the file/dir contains illegal characters, don't add it */
  if (vim_strpbrk(f, (char_u *)FNAME_ILLEGAL) != NULL)
    return;
#endif

  isdir = os_isdir(f);
  if ((isdir && !(flags & EW_DIR)) || (!isdir && !(flags & EW_FILE)))
    return;

  /* If the file isn't executable, may not add it.  Do accept directories. */
  if (!isdir && (flags & EW_EXEC) && !os_can_exe(f))
    return;

  /* Make room for another item in the file list. */
  ga_grow(gap, 1);

  p = xmalloc(STRLEN(f) + 1 + isdir);

  STRCPY(p, f);
#ifdef BACKSLASH_IN_FILENAME
  slash_adjust(p);
#endif
  /*
   * Append a slash or backslash after directory names if none is present.
   */
#ifndef DONT_ADD_PATHSEP_TO_DIR
  if (isdir && (flags & EW_ADDSLASH))
    add_pathsep(p);
#endif
  ((char_u **)gap->ga_data)[gap->ga_len++] = p;
}
#endif /* !NO_EXPANDPATH */

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
  int stripping_disabled = FALSE;
  int relative = TRUE;

  p = filename;
#ifdef BACKSLASH_IN_FILENAME
  if (p[1] == ':')          /* skip "x:" */
    p += 2;
#endif

  if (vim_ispathsep(*p)) {
    relative = FALSE;
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
    } else if (p[0] == '.' && p[1] == '.' &&
               (vim_ispathsep(p[2]) || p[2] == NUL)) {
      /* Skip to after ".." or "../" or "..///". */
      tail = p + 2;
      while (vim_ispathsep(*tail))
        mb_ptr_adv(tail);

      if (components > 0) {             /* strip one preceding component */
        int do_strip = FALSE;
        char_u saved_char;

        /* Don't strip for an erroneous file name. */
        if (!stripping_disabled) {
          /* If the preceding component does not exist in the file
           * system, we strip it.  On Unix, we don't accept a symbolic
           * link that refers to a non-existent file. */
          saved_char = p[-1];
          p[-1] = NUL;
          FileInfo file_info;
          if (!os_get_file_info_link((char *)filename, &file_info)) {
            do_strip = TRUE;
          }
          p[-1] = saved_char;

          --p;
          /* Skip back to after previous '/'. */
          while (p > start && !after_pathsep(start, p))
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
            if (os_get_file_info((char *)filename, &file_info)) {
              do_strip = TRUE;
            }
            else
              stripping_disabled = TRUE;
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
                os_get_file_info(".", &new_file_info);
              } else {
                saved_char = *p;
                *p = NUL;
                os_get_file_info((char *)filename, &new_file_info);
                *p = saved_char;
              }

              if (!os_file_info_id_equal(&file_info, &new_file_info)) {
                do_strip = FALSE;
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
      ++components;                     /* simple path component */
      p = path_next_component(p);
    }
  } while (*p != NUL);
}

static char_u *eval_includeexpr(char_u *ptr, int len)
{
  char_u      *res;

  set_vim_var_string(VV_FNAME, ptr, len);
  res = eval_to_string_safe(curbuf->b_p_inex, NULL,
      was_set_insecurely((char_u *)"includeexpr", OPT_LOCAL));
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
    int len,
    int options,
    long count,
    char_u *rel_fname         /* file we are searching relative to */
)
{
  char_u      *file_name;
  int c;
  char_u      *tofree = NULL;

  if ((options & FNAME_INCL) && *curbuf->b_p_inex != NUL) {
    tofree = eval_includeexpr(ptr, len);
    if (tofree != NULL) {
      ptr = tofree;
      len = (int)STRLEN(ptr);
    }
  }

  if (options & FNAME_EXP) {
    file_name = find_file_in_path(ptr, len, options & ~FNAME_MESS,
        TRUE, rel_fname);

    /*
     * If the file could not be found in a normal way, try applying
     * 'includeexpr' (unless done already).
     */
    if (file_name == NULL
        && !(options & FNAME_INCL) && *curbuf->b_p_inex != NUL) {
      tofree = eval_includeexpr(ptr, len);
      if (tofree != NULL) {
        ptr = tofree;
        len = (int)STRLEN(ptr);
        file_name = find_file_in_path(ptr, len, options & ~FNAME_MESS,
            TRUE, rel_fname);
      }
    }
    if (file_name == NULL && (options & FNAME_MESS)) {
      c = ptr[len];
      ptr[len] = NUL;
      EMSG2(_("E447: Can't find file \"%s\" in path"), ptr);
      ptr[len] = c;
    }

    /* Repeat finding the file "count" times.  This matters when it
     * appears several times in the path. */
    while (file_name != NULL && --count > 0) {
      free(file_name);
      file_name = find_file_in_path(ptr, len, options, FALSE, rel_fname);
    }
  } else
    file_name = vim_strnsave(ptr, len);

  free(tofree);

  return file_name;
}

/*
 * Check if the "://" of a URL is at the pointer, return URL_SLASH.
 * Also check for ":\\", which MS Internet Explorer accepts, return
 * URL_BACKSLASH.
 */
int path_is_url(char_u *p)
{
  if (STRNCMP(p, "://", (size_t)3) == 0)
    return URL_SLASH;
  else if (STRNCMP(p, ":\\\\", (size_t)3) == 0)
    return URL_BACKSLASH;
  return 0;
}

/*
 * Check if "fname" starts with "name://".  Return URL_SLASH if it does.
 * Return URL_BACKSLASH for "name:\\".
 * Return zero otherwise.
 */
int path_with_url(char_u *fname)
{
  char_u *p;

  for (p = fname; isalpha(*p); ++p)
    ;
  return path_is_url(p);
}

/*
 * Return TRUE if "name" is a full (absolute) path name or URL.
 */
int vim_isAbsName(char_u *name)
{
  return path_with_url(name) != 0 || path_is_absolute_path(name);
}

/*
 * Get absolute file name into buffer "buf[len]".
 *
 * return FAIL for failure, OK otherwise
 */
int 
vim_FullName (
    char_u *fname,
    char_u *buf,
    int len,
    int force                  /* force expansion even when already absolute */
)
{
  int retval = OK;
  int url;

  *buf = NUL;
  if (fname == NULL)
    return FAIL;

  url = path_with_url(fname);
  if (!url)
    retval = path_get_absolute_path(fname, buf, len, force);
  if (url || retval == FAIL) {
    /* something failed; use the file name (truncate when too long) */
    vim_strncpy(buf, fname, len - 1);
  }
  return retval;
}

/*
 * If fname is not a full path, make it a full path.
 * Returns pointer to allocated memory (NULL for failure).
 */
char_u *fix_fname(char_u *fname)
{
  /*
   * Force expanding the path always for Unix, because symbolic links may
   * mess up the full path name, even though it starts with a '/'.
   * Also expand when there is ".." in the file name, try to remove it,
   * because "c:/src/../README" is equal to "c:/README".
   * Similarly "c:/src//file" is equal to "c:/src/file".
   * For MS-Windows also expand names like "longna~1" to "longname".
   */
#ifdef UNIX
  return FullName_save(fname, TRUE);
#else
  if (!vim_isAbsName(fname)
      || strstr((char *)fname, "..") != NULL
      || strstr((char *)fname, "//") != NULL
# ifdef BACKSLASH_IN_FILENAME
      || strstr((char *)fname, "\\\\") != NULL
# endif
      )
    return FullName_save(fname, FALSE);

  fname = vim_strsave(fname);

# ifdef USE_FNAME_CASE
  fname_case(fname, 0);  // set correct case for file name
# endif

  return fname;
#endif
}

/*
 * Return TRUE if "p" points to just after a path separator.
 * Takes care of multi-byte characters.
 * "b" must point to the start of the file name
 */
int after_pathsep(char_u *b, char_u *p)
{
  return p > b && vim_ispathsep(p[-1])
         && (!has_mbyte || (*mb_head_off)(b, p - 1) == 0);
}

/*
 * Return TRUE if file names "f1" and "f2" are in the same directory.
 * "f1" may be a short name, "f2" must be a full path.
 */
int same_directory(char_u *f1, char_u *f2)
{
  char_u ffname[MAXPATHL];
  char_u      *t1;
  char_u      *t2;

  /* safety check */
  if (f1 == NULL || f2 == NULL)
    return FALSE;

  (void)vim_FullName(f1, ffname, MAXPATHL, FALSE);
  t1 = path_tail_with_sep(ffname);
  t2 = path_tail_with_sep(f2);
  return t1 - ffname == t2 - f2
         && pathcmp((char *)ffname, (char *)f2, (int)(t1 - ffname)) == 0;
}

#if !defined(NO_EXPANDPATH) || defined(PROTO)
/*
 * Compare path "p[]" to "q[]".
 * If "maxlen" >= 0 compare "p[maxlen]" to "q[maxlen]"
 * Return value like strcmp(p, q), but consider path separators.
 */
int pathcmp(const char *p, const char *q, int maxlen)
{
  int i;
  int c1, c2;
  const char  *s = NULL;

  for (i = 0; maxlen < 0 || i < maxlen; i += MB_PTR2LEN((char_u *)p + i)) {
    c1 = PTR2CHAR((char_u *)p + i);
    c2 = PTR2CHAR((char_u *)q + i);

    /* End of "p": check if "q" also ends or just has a slash. */
    if (c1 == NUL) {
      if (c2 == NUL)        /* full match */
        return 0;
      s = q;
      break;
    }

    /* End of "q": check if "p" just has a slash. */
    if (c2 == NUL) {
      s = p;
      break;
    }

    if ((p_fic ? vim_toupper(c1) != vim_toupper(c2) : c1 != c2)
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
      return p_fic ? vim_toupper(c1) - vim_toupper(c2)
             : c1 - c2;         /* no match */
    }
  }
  if (s == NULL)        /* "i" ran into "maxlen" */
    return 0;

  c1 = PTR2CHAR((char_u *)s + i);
  c2 = PTR2CHAR((char_u *)s + i + MB_PTR2LEN((char_u *)s + i));
  /* ignore a trailing slash, but not "//" or ":/" */
  if (c2 == NUL
      && i > 0
      && !after_pathsep((char_u *)s, (char_u *)s + i)
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
#endif

#ifndef NO_EXPANDPATH
/*
 * Expand a path into all matching files and/or directories.  Handles "*",
 * "?", "[a-z]", "**", etc.
 * "path" has backslashes before chars that are not to be expanded.
 * Returns the number of matches found.
 *
 * Uses EW_* flags
 */
int mch_expandpath(garray_T *gap, char_u *path, int flags)
{
  return unix_expandpath(gap, path, 0, flags, FALSE);
}
#endif

/// Try to find a shortname by comparing the fullname with the current
/// directory.
///
/// @param full_path The full path of the file.
/// @return
///   - Pointer into `full_path` if shortened.
///   - `full_path` unchanged if no shorter name is possible.
///   - NULL if `full_path` is NULL.
char_u *path_shorten_fname_if_possible(char_u *full_path)
{
  char_u *dirname = xmalloc(MAXPATHL);
  char_u *p = full_path;

  if (os_dirname(dirname, MAXPATHL) == OK) {
    p = path_shorten_fname(full_path, dirname);
    if (p == NULL || *p == NUL) {
      p = full_path;
    }
  }
  free(dirname);
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
/// @return OK or FAIL.
int expand_wildcards_eval(char_u **pat, int *num_file, char_u ***file,
                          int flags)
{
  int ret = FAIL;
  char_u      *eval_pat = NULL;
  char_u      *exp_pat = *pat;
  char_u      *ignored_msg;
  int usedlen;

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
    free(exp_pat);
    free(eval_pat);
  }

  return ret;
}

/*
 * Expand wildcards.  Calls gen_expand_wildcards() and removes files matching
 * 'wildignore'.
 * Returns OK or FAIL.  When FAIL then "num_file" won't be set.
 */
int 
expand_wildcards (
    int num_pat,                    /* number of input patterns */
    char_u **pat,             /* array of input patterns */
    int *num_file,        /* resulting number of files */
    char_u ***file,            /* array of resulting files */
    int flags                      /* EW_DIR, etc. */
)
{
  int retval;
  int i, j;
  char_u      *p;
  int non_suf_match;            /* number without matching suffix */

  retval = gen_expand_wildcards(num_pat, pat, num_file, file, flags);

  /* When keeping all matches, return here */
  if ((flags & EW_KEEPALL) || retval == FAIL)
    return retval;

  /*
   * Remove names that match 'wildignore'.
   */
  if (*p_wig) {
    char_u  *ffname;

    /* check all files in (*file)[] */
    for (i = 0; i < *num_file; ++i) {
      ffname = FullName_save((*file)[i], FALSE);
      if (ffname == NULL)               /* out of memory */
        break;
      if (match_file_list(p_wig, (*file)[i], ffname)) {
        /* remove this matching file from the list */
        free((*file)[i]);
        for (j = i; j + 1 < *num_file; ++j)
          (*file)[j] = (*file)[j + 1];
        --*num_file;
        --i;
      }
      free(ffname);
    }
  }

  /*
   * Move the names where 'suffixes' match to the end.
   */
  if (*num_file > 1) {
    non_suf_match = 0;
    for (i = 0; i < *num_file; ++i) {
      if (!match_suffix((*file)[i])) {
        /*
         * Move the name without matching suffix to the front
         * of the list.
         */
        p = (*file)[i];
        for (j = i; j > non_suf_match; --j)
          (*file)[j] = (*file)[j - 1];
        (*file)[non_suf_match++] = p;
      }
    }
  }

  return retval;
}

/*
 * Return TRUE if "fname" matches with an entry in 'suffixes'.
 */
int match_suffix(char_u *fname)
{
  int fnamelen, setsuflen;
  char_u      *setsuf;
#define MAXSUFLEN 30        /* maximum length of a file suffix */
  char_u suf_buf[MAXSUFLEN];

  fnamelen = (int)STRLEN(fname);
  setsuflen = 0;
  for (setsuf = p_su; *setsuf; ) {
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
          && fnamencmp(suf_buf, fname + fnamelen - setsuflen,
              (size_t)setsuflen) == 0)
        break;
      setsuflen = 0;
    }
  }
  return setsuflen != 0;
}

/// Get the absolute name of the given relative directory.
///
/// @param directory Directory name, relative to current directory.
/// @return `FAIL` for failure, `OK` for success.
int path_full_dir_name(char *directory, char *buffer, int len)
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
// Append to_append to path with a slash in between.
int append_path(char *path, const char *to_append, int max_len)
{
  int current_length = STRLEN(path);
  int to_append_length = STRLEN(to_append);

  // Do not append empty strings.
  if (to_append_length == 0) {
    return OK;
  }

  // Do not append a dot.
  if (STRCMP(to_append, ".") == 0) {
    return OK;
  }

  // Glue both paths with a slash.
  if (current_length > 0 && path[current_length-1] != '/') {
    current_length += 1;  // Count the trailing slash.

    // +1 for the NUL at the end.
    if (current_length + 1 > max_len) {
      return FAIL;
    }

    STRCAT(path, "/");
  }

  // +1 for the NUL at the end.
  if (current_length + to_append_length + 1 > max_len) {
    return FAIL;
  }

  STRCAT(path, to_append);
  return OK;
}

/// Expand a given file to its absolute path.
///
/// @param fname The filename which should be expanded.
/// @param buf Buffer to store the absolute path of `fname`.
/// @param len Length of `buf`.
/// @param force Also expand when `fname` is already absolute.
/// @return `FAIL` for failure, `OK` for success.
static int path_get_absolute_path(char_u *fname, char_u *buf, int len, int force)
{
  char_u *p;
  *buf = NUL;

  char relative_directory[len];
  char *end_of_path = (char *) fname;

  // expand it if forced or not an absolute path
  if (force || !path_is_absolute_path(fname)) {
    if ((p = vim_strrchr(fname, '/')) != NULL) {
      STRNCPY(relative_directory, fname, p-fname);
      relative_directory[p-fname] = NUL;
      end_of_path = (char *) (p + 1);
    } else {
      relative_directory[0] = NUL;
      end_of_path = (char *) fname;
    }

    if (FAIL == path_full_dir_name(relative_directory, (char *) buf, len)) {
      return FAIL;
    }
  }
  return append_path((char *) buf, (char *) end_of_path, len);
}

/// Check if the given file is absolute.
///
/// This just checks if the file name starts with '/' or '~'.
/// @return `TRUE` if "fname" is absolute.
int path_is_absolute_path(const char_u *fname)
{
  return *fname == '/' || *fname == '~';
}
