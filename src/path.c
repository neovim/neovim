#include "vim.h"
#include "path.h"
#include "charset.h"
#include "eval.h"
#include "ex_getln.h"
#include "fileio.h"
#include "garray.h"
#include "memline.h"
#include "misc1.h"
#include "misc2.h"
#include "os/os.h"
#include "os/shell.h"
#include "os_unix.h"
#include "regexp.h"
#include "tag.h"
#include "types.h"
#include "ui.h"
#include "window.h"

/*
 * Compare two file names and return:
 * FPC_SAME   if they both exist and are the same file.
 * FPC_SAMEX  if they both don't exist and have the same file name.
 * FPC_DIFF   if they both exist and are different files.
 * FPC_NOTX   if they both don't exist.
 * FPC_DIFFX  if one of them doesn't exist.
 * For the first name environment variables are expanded
 */
int 
fullpathcmp (
    char_u *s1,
    char_u *s2,
    int checkname                  /* when both don't exist, check file names */
)
{
#ifdef UNIX
  char_u exp1[MAXPATHL];
  char_u full1[MAXPATHL];
  char_u full2[MAXPATHL];
  struct stat st1, st2;
  int r1, r2;

  expand_env(s1, exp1, MAXPATHL);
  r1 = mch_stat((char *)exp1, &st1);
  r2 = mch_stat((char *)s2, &st2);
  if (r1 != 0 && r2 != 0) {
    /* if mch_stat() doesn't work, may compare the names */
    if (checkname) {
      if (fnamecmp(exp1, s2) == 0)
        return FPC_SAMEX;
      r1 = vim_FullName(exp1, full1, MAXPATHL, FALSE);
      r2 = vim_FullName(s2, full2, MAXPATHL, FALSE);
      if (r1 == OK && r2 == OK && fnamecmp(full1, full2) == 0)
        return FPC_SAMEX;
    }
    return FPC_NOTX;
  }
  if (r1 != 0 || r2 != 0)
    return FPC_DIFFX;
  if (st1.st_dev == st2.st_dev && st1.st_ino == st2.st_ino)
    return FPC_SAME;
  return FPC_DIFF;
#else
  char_u  *exp1;                /* expanded s1 */
  char_u  *full1;               /* full path of s1 */
  char_u  *full2;               /* full path of s2 */
  int retval = FPC_DIFF;
  int r1, r2;

  /* allocate one buffer to store three paths (alloc()/free() is slow!) */
  if ((exp1 = alloc(MAXPATHL * 3)) != NULL) {
    full1 = exp1 + MAXPATHL;
    full2 = full1 + MAXPATHL;

    expand_env(s1, exp1, MAXPATHL);
    r1 = vim_FullName(exp1, full1, MAXPATHL, FALSE);
    r2 = vim_FullName(s2, full2, MAXPATHL, FALSE);

    /* If vim_FullName() fails, the file probably doesn't exist. */
    if (r1 != OK && r2 != OK) {
      if (checkname && fnamecmp(exp1, s2) == 0)
        retval = FPC_SAMEX;
      else
        retval = FPC_NOTX;
    } else if (r1 != OK || r2 != OK)
      retval = FPC_DIFFX;
    else if (fnamecmp(full1, full2))
      retval = FPC_DIFF;
    else
      retval = FPC_SAME;
    vim_free(exp1);
  }
  return retval;
#endif
}

/*
 * Get the tail of a path: the file name.
 * When the path ends in a path separator the tail is the NUL after it.
 * Fail safe: never returns NULL.
 */
char_u *gettail(char_u *fname)
{
  char_u  *p1, *p2;

  if (fname == NULL)
    return (char_u *)"";
  for (p1 = p2 = get_past_head(fname); *p2; ) { /* find last part of path */
    if (vim_ispathsep_nocolon(*p2))
      p1 = p2 + 1;
    mb_ptr_adv(p2);
  }
  return p1;
}

static char_u *gettail_dir(char_u *fname);

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
 * Get pointer to tail of "fname", including path separators.  Putting a NUL
 * here leaves the directory name.  Takes care of "c:/" and "//".
 * Always returns a valid pointer.
 */
char_u *gettail_sep(char_u *fname)
{
  char_u      *p;
  char_u      *t;

  p = get_past_head(fname);     /* don't remove the '/' from "c:/file" */
  t = gettail(fname);
  while (t > p && after_pathsep(fname, t))
    --t;
  return t;
}

/*
 * get the next path component (just after the next path separator).
 */
char_u *getnextcomp(char_u *fname)
{
  while (*fname && !vim_ispathsep(*fname))
    mb_ptr_adv(fname);
  if (*fname)
    ++fname;
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

#if defined(FEAT_GUI_TABLINE) || defined(FEAT_WINDOWS) \
  || defined(FEAT_EVAL) || defined(PROTO)
/*
 * Shorten the path of a file from "~/foo/../.bar/fname" to "~/f/../.b/fname"
 * It's done in-place.
 */
void shorten_dir(char_u *str)
{
  char_u      *tail, *s, *d;
  int skip = FALSE;

  tail = gettail(str);
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
#endif

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

  p = gettail_sep(fname);
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
        || ((p_fic ? MB_TOLOWER(cx) != MB_TOLOWER(cy) : cx != cy)
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
{
  char_u  *dest;

  dest = alloc((unsigned)(STRLEN(fname1) + STRLEN(fname2) + 3));
  if (dest != NULL) {
    STRCPY(dest, fname1);
    if (sep)
      add_pathsep(dest);
    STRCAT(dest, fname2);
  }
  return dest;
}

/*
 * Concatenate two strings and return the result in allocated memory.
 * Returns NULL when out of memory.
 */
char_u *concat_str(char_u *str1, char_u *str2)
{
  char_u  *dest;
  size_t l = STRLEN(str1);

  dest = alloc((unsigned)(l + STRLEN(str2) + 1L));
  if (dest != NULL) {
    STRCPY(dest, str1);
    STRCPY(dest + l, str2);
  }
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
 * Returns NULL when out of memory.
 */
char_u *
FullName_save (
    char_u *fname,
    int force                      /* force expansion, even when it already looks
                                 * like a full path name */
)
{
  char_u      *buf;
  char_u      *new_fname = NULL;

  if (fname == NULL)
    return NULL;

  buf = alloc((unsigned)MAXPATHL);
  if (buf != NULL) {
    if (vim_FullName(fname, buf, MAXPATHL, force) != FAIL)
      new_fname = vim_strsave(buf);
    else
      new_fname = vim_strsave(fname);
    vim_free(buf);
  }
  return new_fname;
}

#if !defined(NO_EXPANDPATH) || defined(PROTO)

static int vim_backtick(char_u *p);
static int expand_backtick(garray_T *gap, char_u *pat, int flags);


#if (defined(UNIX) && !defined(VMS)) || defined(USE_UNIXFILENAME) \
  || defined(PROTO)
/*
 * Unix style wildcard expansion code.
 * It's here because it's used both for Unix and Mac.
 */
static int pstrcmp(const void *, const void *);

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
  buf = alloc((int)STRLEN(path) + BASENAMELEN + 5);
  if (buf == NULL)
    return 0;

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
    vim_free(buf);
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
  vim_free(pat);

  if (regmatch.regprog == NULL && (flags & EW_NOTWILD) == 0) {
    vim_free(buf);
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
              vim_free(precomp_buf);
            }
#endif
            addfile(gap, buf, flags);
          }
        }
      }
    }

    closedir(dirp);
  }

  vim_free(buf);
  vim_regfree(regmatch.regprog);

  matches = gap->ga_len - start_len;
  if (matches > 0)
    qsort(((char_u **)gap->ga_data) + start_len, matches,
        sizeof(char_u *), pstrcmp);
  return matches;
}
#endif

static int find_previous_pathsep(char_u *path, char_u **psep);
static int is_unique(char_u *maybe_unique, garray_T *gap, int i);
static void expand_path_option(char_u *curdir, garray_T *gap);
static char_u *get_path_cutoff(char_u *fname, garray_T *gap);
static void uniquefy_paths(garray_T *gap, char_u *pattern);
static int expand_in_path(garray_T *gap, char_u *pattern, int flags);

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
  int j;
  int candidate_len;
  int other_path_len;
  char_u  **other_paths = (char_u **)gap->ga_data;
  char_u  *rival;

  for (j = 0; j < gap->ga_len; j++) {
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

  if ((buf = alloc((int)MAXPATHL)) == NULL)
    return;

  while (*path_option != NUL) {
    copy_option_part(&path_option, buf, MAXPATHL, " ,");

    if (buf[0] == '.' && (buf[1] == NUL || vim_ispathsep(buf[1]))) {
      /* Relative to current buffer:
       * "/path/file" + "." -> "/path/"
       * "/path/file"  + "./subdir" -> "/path/subdir" */
      if (curbuf->b_ffname == NULL)
        continue;
      p = gettail(curbuf->b_ffname);
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
    else if (!os_is_absolute_path(buf)) {
      /* Expand relative path to their full path equivalent */
      len = (int)STRLEN(curdir);
      if (len + (int)STRLEN(buf) + 3 > MAXPATHL)
        continue;
      STRMOVE(buf + len + 1, buf);
      STRCPY(buf, curdir);
      buf[len] = PATHSEP;
      simplify_filename(buf);
    }

    if (ga_grow(gap, 1) == FAIL)
      break;


    p = vim_strsave(buf);
    if (p == NULL)
      break;
    ((char_u **)gap->ga_data)[gap->ga_len++] = p;
  }

  vim_free(buf);
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
  int i;
  int maxlen = 0;
  char_u  **path_part = (char_u **)gap->ga_data;
  char_u  *cutoff = NULL;

  for (i = 0; i < gap->ga_len; i++) {
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
  int i;
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
  file_pattern = alloc(len + 2);
  if (file_pattern == NULL)
    return;
  file_pattern[0] = '*';
  file_pattern[1] = NUL;
  STRCAT(file_pattern, pattern);
  pat = file_pat_to_reg_pat(file_pattern, NULL, NULL, TRUE);
  vim_free(file_pattern);
  if (pat == NULL)
    return;

  regmatch.rm_ic = TRUE;                /* always ignore case */
  regmatch.regprog = vim_regcomp(pat, RE_MAGIC + RE_STRING);
  vim_free(pat);
  if (regmatch.regprog == NULL)
    return;

  if ((curdir = alloc((int)(MAXPATHL))) == NULL)
    goto theend;
  os_dirname(curdir, MAXPATHL);
  expand_path_option(curdir, &path_ga);

  in_curdir = (char_u **)alloc_clear(gap->ga_len * sizeof(char_u *));
  if (in_curdir == NULL)
    goto theend;

  for (i = 0; i < gap->ga_len && !got_int; i++) {
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

    if (os_is_absolute_path(path)) {
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
      short_name = shorten_fname(path, curdir);
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
  for (i = 0; i < gap->ga_len && !got_int; i++) {
    char_u *rel_path;
    char_u *path = in_curdir[i];

    if (path == NULL)
      continue;

    /* If the {filename} is not unique, change it to ./{filename}.
     * Else reduce it to {filename} */
    short_name = shorten_fname(path, curdir);
    if (short_name == NULL)
      short_name = path;
    if (is_unique(short_name, gap, i)) {
      STRCPY(fnames[i], short_name);
      continue;
    }

    rel_path = alloc((int)(STRLEN(short_name) + STRLEN(PATHSEPSTR) + 2));
    if (rel_path == NULL)
      goto theend;
    STRCPY(rel_path, ".");
    add_pathsep(rel_path);
    STRCAT(rel_path, short_name);

    vim_free(fnames[i]);
    fnames[i] = rel_path;
    sort_again = TRUE;
    ui_breakcheck();
  }

theend:
  vim_free(curdir);
  if (in_curdir != NULL) {
    for (i = 0; i < gap->ga_len; i++)
      vim_free(in_curdir[i]);
    vim_free(in_curdir);
  }
  ga_clear_strings(&path_ga);
  vim_regfree(regmatch.regprog);

  if (sort_again)
    ga_remove_duplicate_strings(gap);
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

  if ((curdir = alloc((unsigned)MAXPATHL)) == NULL)
    return 0;
  os_dirname(curdir, MAXPATHL);

  ga_init(&path_ga, (int)sizeof(char_u *), 1);
  expand_path_option(curdir, &path_ga);
  vim_free(curdir);
  if (path_ga.ga_len == 0)
    return 0;

  paths = ga_concat_strings(&path_ga);
  ga_clear_strings(&path_ga);
  if (paths == NULL)
    return 0;

  files = globpath(paths, pattern, (flags & EW_ICASE) ? WILD_ICASE : 0);
  vim_free(paths);
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
  vim_free(files);

  return gap->ga_len;
}


static int has_env_var(char_u *p);

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
static int has_special_wildchar(char_u *p);

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
          vim_free(p);
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
            && !os_is_absolute_path(p)
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
      vim_free(t);
    }

    if (did_expand_in_path && ga.ga_len > 0 && (flags & EW_PATH))
      uniquefy_paths(&ga, p);
    if (p != pat[i])
      vim_free(p);
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
  if (cmd == NULL)
    return 0;

  if (*cmd == '=')          /* `={expr}`: Expand expression */
    buffer = eval_to_string(cmd + 1, &p, TRUE);
  else
    buffer = get_cmd_output(cmd, NULL,
        (flags & EW_SILENT) ? kShellOptSilent : 0);
  vim_free(cmd);
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

  vim_free(buffer);
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
  int isdir;

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
  if (ga_grow(gap, 1) == FAIL)
    return;

  p = alloc((unsigned)(STRLEN(f) + 1 + isdir));
  if (p == NULL)
    return;

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
