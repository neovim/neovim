// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <inttypes.h>
#include <stdint.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/misc1.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/edit.h"
#include "nvim/indent.h"
#include "nvim/indent_c.h"
#include "nvim/mark.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/option.h"
#include "nvim/search.h"
#include "nvim/strings.h"

// Find result cache for cpp_baseclass
typedef struct {
    int found;
    lpos_T lpos;
} cpp_baseclass_cache_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "indent_c.c.generated.h"
#endif
/*
 * Find the start of a comment, not knowing if we are in a comment right now.
 * Search starts at w_cursor.lnum and goes backwards.
 * Return NULL when not inside a comment.
 */
static pos_T *ind_find_start_comment(void)
{ /* XXX */
  return find_start_comment(curbuf->b_ind_maxcomment);
}

pos_T *
find_start_comment (  /* XXX */
    int ind_maxcomment
)
{
  pos_T       *pos;
  char_u      *line;
  char_u      *p;
  int64_t cur_maxcomment = ind_maxcomment;

  for (;; ) {
    pos = findmatchlimit(NULL, '*', FM_BACKWARD, cur_maxcomment);
    if (pos == NULL)
      break;

    /*
     * Check if the comment start we found is inside a string.
     * If it is then restrict the search to below this line and try again.
     */
    line = ml_get(pos->lnum);
    for (p = line; *p && (colnr_T)(p - line) < pos->col; ++p)
      p = skip_string(p);
    if ((colnr_T)(p - line) <= pos->col)
      break;
    cur_maxcomment = curwin->w_cursor.lnum - pos->lnum - 1;
    if (cur_maxcomment <= 0) {
      pos = NULL;
      break;
    }
  }
  return pos;
}

/// Find the start of a comment or raw string, not knowing if we are in a
/// comment or raw string right now.
/// Search starts at w_cursor.lnum and goes backwards.
///
/// @returns NULL when not inside a comment or raw string.
///
/// @note "CORS" -> Comment Or Raw String
static pos_T *ind_find_start_CORS(void)
{
  // XXX
  static pos_T comment_pos_copy;

  pos_T *comment_pos = find_start_comment(curbuf->b_ind_maxcomment);
  if (comment_pos != NULL) {
    // Need to make a copy of the static pos in findmatchlimit(),
    // calling find_start_rawstring() may change it.
    comment_pos_copy = *comment_pos;
    comment_pos = &comment_pos_copy;
  }
  pos_T *rs_pos = find_start_rawstring(curbuf->b_ind_maxcomment);

  // If comment_pos is before rs_pos the raw string is inside the comment.
  // If rs_pos is before comment_pos the comment is inside the raw string.
  if (comment_pos == NULL || (rs_pos != NULL && lt(*rs_pos, *comment_pos))) {
    return rs_pos;
  }
  return comment_pos;
}

/*
 * Find the start of a raw string, not knowing if we are in one right now.
 * Search starts at w_cursor.lnum and goes backwards.
 * Return NULL when not inside a raw string.
 */
static pos_T *find_start_rawstring(int ind_maxcomment)
{ /* XXX */
    pos_T *pos;
    char_u *line;
    char_u *p;
    long cur_maxcomment = ind_maxcomment;

    for (;;)
    {
        pos = findmatchlimit(NULL, 'R', FM_BACKWARD, cur_maxcomment);
        if (pos == NULL)
            break;

        /*
         * Check if the raw string start we found is inside a string.
         * If it is then restrict the search to below this line and try again.
         */
        line = ml_get(pos->lnum);
        for (p = line; *p && (colnr_T)(p - line) < pos->col; ++p)
            p = skip_string(p);
        if ((colnr_T)(p - line) <= pos->col)
            break;
        cur_maxcomment = curwin->w_cursor.lnum - pos->lnum - 1;
        if (cur_maxcomment <= 0)
        {
            pos = NULL;
            break;
        }
    }
    return pos;
}

/*
 * Skip to the end of a "string" and a 'c' character.
 * If there is no string or character, return argument unmodified.
 */
static char_u *skip_string(char_u *p)
{
  int i;

  /*
   * We loop, because strings may be concatenated: "date""time".
   */
  for (;; ++p) {
    if (p[0] == '\'') {                     /* 'c' or '\n' or '\000' */
      if (!p[1])                            /* ' at end of line */
        break;
      i = 2;
      if (p[1] == '\\') {                   /* '\n' or '\000' */
        ++i;
        while (ascii_isdigit(p[i - 1]))           /* '\000' */
          ++i;
      }
      if (p[i] == '\'') {                   /* check for trailing ' */
        p += i;
        continue;
      }
    } else if (p[0] == '"') {             /* start of string */
      for (++p; p[0]; ++p) {
        if (p[0] == '\\' && p[1] != NUL)
          ++p;
        else if (p[0] == '"')               /* end of string */
          break;
      }
      if (p[0] == '"')
          continue; /* continue for another string */
    } else if (p[0] == 'R' && p[1] == '"') {
        /* Raw string: R"[delim](...)[delim]" */
        char_u *delim = p + 2;
        char_u *paren = vim_strchr(delim, '(');

        if (paren != NULL) {
            const ptrdiff_t delim_len = paren - delim;

            for (p += 3; *p; ++p)
                if (p[0] == ')' && STRNCMP(p + 1, delim, delim_len) == 0
                        && p[delim_len + 1] == '"')
                {
                    p += delim_len + 1;
                    break;
                }
            if (p[0] == '"')
                continue; /* continue for another string */
        }
    }
    break;                                  /* no string found */
  }
  if (!*p)
    --p;                                    /* backup from NUL */
  return p;
}


/*
 * Functions for C-indenting.
 * Most of this originally comes from Eric Fischer.
 */
/*
 * Below "XXX" means that this function may unlock the current line.
 */


/*
 * Return true if the string "line" starts with a word from 'cinwords'.
 */
bool cin_is_cinword(char_u *line)
{
  bool retval = false;

  size_t cinw_len = STRLEN(curbuf->b_p_cinw) + 1;
  char_u *cinw_buf = xmalloc(cinw_len);
  line = skipwhite(line);

  for (char_u *cinw = curbuf->b_p_cinw; *cinw; ) {
    size_t len = copy_option_part(&cinw, cinw_buf, cinw_len, ",");
    if (STRNCMP(line, cinw_buf, len) == 0
        && (!vim_iswordc(line[len]) || !vim_iswordc(line[len - 1]))) {
      retval = true;
      break;
    }
  }

  xfree(cinw_buf);

  return retval;
}



/*
 * Skip over white space and C comments within the line.
 * Also skip over Perl/shell comments if desired.
 */
static char_u *cin_skipcomment(char_u *s)
{
  while (*s) {
    char_u *prev_s = s;

    s = skipwhite(s);

    /* Perl/shell # comment comment continues until eol.  Require a space
     * before # to avoid recognizing $#array. */
    if (curbuf->b_ind_hash_comment != 0 && s != prev_s && *s == '#') {
      s += STRLEN(s);
      break;
    }
    if (*s != '/')
      break;
    ++s;
    if (*s == '/') {            /* slash-slash comment continues till eol */
      s += STRLEN(s);
      break;
    }
    if (*s != '*')
      break;
    for (++s; *s; ++s)          /* skip slash-star comment */
      if (s[0] == '*' && s[1] == '/') {
        s += 2;
        break;
      }
  }
  return s;
}

/*
 * Return TRUE if there is no code at *s.  White space and comments are
 * not considered code.
 */
static int cin_nocode(char_u *s)
{
  return *cin_skipcomment(s) == NUL;
}

/*
 * Check previous lines for a "//" line comment, skipping over blank lines.
 */
static pos_T *find_line_comment(void)   /* XXX */
{
  static pos_T pos;
  char_u       *line;
  char_u       *p;

  pos = curwin->w_cursor;
  while (--pos.lnum > 0) {
    line = ml_get(pos.lnum);
    p = skipwhite(line);
    if (cin_islinecomment(p)) {
      pos.col = (int)(p - line);
      return &pos;
    }
    if (*p != NUL)
      break;
  }
  return NULL;
}

/// Checks if `text` starts with "key:".
static bool cin_has_js_key(char_u *text)
{
  char_u *s = skipwhite(text);

  char_u quote = 0;
  if (*s == '\'' || *s == '"') {
    // can be 'key': or "key":
    quote = *s;
    ++s;
  }
  if (!vim_isIDc(*s))	{   // need at least one ID character
    return FALSE;
  }

  while (vim_isIDc(*s)) {
    ++s;
  }
  if (*s && *s == quote) {
    ++s;
  }

  s = cin_skipcomment(s);

  // "::" is not a label, it's C++
  return (*s == ':' && s[1] != ':');
}

/// Checks if string matches "label:"; move to character after ':' if true.
/// "*s" must point to the start of the label, if there is one.
static int cin_islabel_skip(char_u **s)
{
  if (!vim_isIDc(**s))              /* need at least one ID character */
    return FALSE;

  while (vim_isIDc(**s))
    (*s)++;

  *s = cin_skipcomment(*s);

  /* "::" is not a label, it's C++ */
  return **s == ':' && *++*s != ':';
}

/*
 * Recognize a label: "label:".
 * Note: curwin->w_cursor must be where we are looking for the label.
 */
int cin_islabel(void)
{ /* XXX */
  char_u *s = cin_skipcomment(get_cursor_line_ptr());

  /*
   * Exclude "default" from labels, since it should be indented
   * like a switch label.  Same for C++ scope declarations.
   */
  if (cin_isdefault(s))
    return FALSE;
  if (cin_isscopedecl(s))
    return FALSE;

  if (!cin_islabel_skip(&s)) {
    return FALSE;
  }

  /*
   * Only accept a label if the previous line is terminated or is a case
   * label.
   */
  pos_T cursor_save;
  pos_T   *trypos;
  char_u  *line;

  cursor_save = curwin->w_cursor;
  while (curwin->w_cursor.lnum > 1) {
    --curwin->w_cursor.lnum;

    /*
     * If we're in a comment or raw string now, skip to the start of
     * it.
     */
    curwin->w_cursor.col = 0;
    if ((trypos = ind_find_start_CORS()) != NULL) /* XXX */
      curwin->w_cursor = *trypos;

    line = get_cursor_line_ptr();
    if (cin_ispreproc(line))          /* ignore #defines, #if, etc. */
      continue;
    if (*(line = cin_skipcomment(line)) == NUL)
      continue;

    curwin->w_cursor = cursor_save;
    if (cin_isterminated(line, TRUE, FALSE)
        || cin_isscopedecl(line)
        || cin_iscase(line, TRUE)
        || (cin_islabel_skip(&line) && cin_nocode(line)))
      return TRUE;
    return FALSE;
  }
  curwin->w_cursor = cursor_save;
  return TRUE;                /* label at start of file??? */
}

/*
 * Recognize structure initialization and enumerations:
 * "[typedef] [static|public|protected|private] enum"
 * "[typedef] [static|public|protected|private] = {"
 */
static int cin_isinit(void)
{
  char_u      *s;
  static char *skip[] = {"static", "public", "protected", "private"};

  s = cin_skipcomment(get_cursor_line_ptr());

  if (cin_starts_with(s, "typedef"))
    s = cin_skipcomment(s + 7);

  for (;; ) {
    int i, l;

    for (i = 0; i < (int)ARRAY_SIZE(skip); ++i) {
      l = (int)strlen(skip[i]);
      if (cin_starts_with(s, skip[i])) {
        s = cin_skipcomment(s + l);
        l = 0;
        break;
      }
    }
    if (l != 0)
      break;
  }

  if (cin_starts_with(s, "enum"))
    return TRUE;

  if (cin_ends_in(s, (char_u *)"=", (char_u *)"{"))
    return TRUE;

  return FALSE;
}

/*
 * Recognize a switch label: "case .*:" or "default:".
 */
int 
cin_iscase (
    char_u *s,
    int strict     /* Allow relaxed check of case statement for JS */
)
{
  s = cin_skipcomment(s);
  if (cin_starts_with(s, "case")) {
    for (s += 4; *s; ++s) {
      s = cin_skipcomment(s);
      if (*s == ':') {
        if (s[1] == ':')                /* skip over "::" for C++ */
          ++s;
        else
          return TRUE;
      }
      if (*s == '\'' && s[1] && s[2] == '\'')
        s += 2;                         /* skip over ':' */
      else if (*s == '/' && (s[1] == '*' || s[1] == '/'))
        return FALSE;                   /* stop at comment */
      else if (*s == '"') {
        /* JS etc. */
        if (strict)
          return FALSE;                         /* stop at string */
        else
          return TRUE;
      }
    }
    return FALSE;
  }

  if (cin_isdefault(s))
    return TRUE;
  return FALSE;
}

/*
 * Recognize a "default" switch label.
 */
static int cin_isdefault(char_u *s)
{
  return STRNCMP(s, "default", 7) == 0
         && *(s = cin_skipcomment(s + 7)) == ':'
         && s[1] != ':';
}

/*
 * Recognize a "public/private/protected" scope declaration label.
 */
int cin_isscopedecl(char_u *s)
{
  int i;

  s = cin_skipcomment(s);
  if (STRNCMP(s, "public", 6) == 0)
    i = 6;
  else if (STRNCMP(s, "protected", 9) == 0)
    i = 9;
  else if (STRNCMP(s, "private", 7) == 0)
    i = 7;
  else
    return FALSE;
  return *(s = cin_skipcomment(s + i)) == ':' && s[1] != ':';
}

/* Maximum number of lines to search back for a "namespace" line. */
#define FIND_NAMESPACE_LIM 20

// Recognize a "namespace" scope declaration.
static bool cin_is_cpp_namespace(char_u *s)
{
  char_u *p;
  bool has_name = false;
  bool has_name_start = false;

  s = cin_skipcomment(s);
  if (STRNCMP(s, "namespace", 9) == 0 && (s[9] == NUL || !vim_iswordc(s[9]))) {
    p = cin_skipcomment(skipwhite(s + 9));
    while (*p != NUL) {
      if (ascii_iswhite(*p)) {
        has_name = true;         // found end of a name
        p = cin_skipcomment(skipwhite(p));
      } else if (*p == '{') {
        break;
      } else if (vim_iswordc(*p)) {
        has_name_start = true;
        if (has_name) {
          return false;           // word character after skipping past name
        }
        p++;
      } else if (p[0] == ':' && p[1] == ':' && vim_iswordc(p[2])) {
        if (!has_name_start || has_name) {
          return false;
        }
        // C++ 17 nested namespace
        p += 3;
      } else {
        return false;
      }
    }
    return true;
  }
  return false;
}

/*
 * Return a pointer to the first non-empty non-comment character after a ':'.
 * Return NULL if not found.
 *	  case 234:    a = b;
 *		       ^
 */
static char_u *after_label(char_u *l)
{
  for (; *l; ++l) {
    if (*l == ':') {
      if (l[1] == ':')              /* skip over "::" for C++ */
        ++l;
      else if (!cin_iscase(l + 1, FALSE))
        break;
    } else if (*l == '\'' && l[1] && l[2] == '\'')
      l += 2;                       /* skip over 'x' */
  }
  if (*l == NUL)
    return NULL;
  l = cin_skipcomment(l + 1);
  if (*l == NUL)
    return NULL;
  return l;
}

/*
 * Get indent of line "lnum", skipping a label.
 * Return 0 if there is nothing after the label.
 */
static int 
get_indent_nolabel (     /* XXX */
    linenr_T lnum
)
{
  char_u      *l;
  pos_T fp;
  colnr_T col;
  char_u      *p;

  l = ml_get(lnum);
  p = after_label(l);
  if (p == NULL)
    return 0;

  fp.col = (colnr_T)(p - l);
  fp.lnum = lnum;
  getvcol(curwin, &fp, &col, NULL, NULL);
  return (int)col;
}

/*
 * Find indent for line "lnum", ignoring any case or jump label.
 * Also return a pointer to the text (after the label) in "pp".
 *   label:	if (asdf && asdfasdf)
 *		^
 */
static int skip_label(linenr_T lnum, char_u **pp)
{
  char_u      *l;
  int amount;
  pos_T cursor_save;

  cursor_save = curwin->w_cursor;
  curwin->w_cursor.lnum = lnum;
  l = get_cursor_line_ptr();
  /* XXX */
  if (cin_iscase(l, FALSE) || cin_isscopedecl(l) || cin_islabel()) {
    amount = get_indent_nolabel(lnum);
    l = after_label(get_cursor_line_ptr());
    if (l == NULL)              /* just in case */
      l = get_cursor_line_ptr();
  } else {
    amount = get_indent();
    l = get_cursor_line_ptr();
  }
  *pp = l;

  curwin->w_cursor = cursor_save;
  return amount;
}

/*
 * Return the indent of the first variable name after a type in a declaration.
 *  int	    a,			indent of "a"
 *  static struct foo    b,	indent of "b"
 *  enum bla    c,		indent of "c"
 * Returns zero when it doesn't look like a declaration.
 */
static int cin_first_id_amount(void)
{
  char_u      *line, *p, *s;
  int len;
  pos_T fp;
  colnr_T col;

  line = get_cursor_line_ptr();
  p = skipwhite(line);
  len = (int)(skiptowhite(p) - p);
  if (len == 6 && STRNCMP(p, "static", 6) == 0) {
    p = skipwhite(p + 6);
    len = (int)(skiptowhite(p) - p);
  }
  if (len == 6 && STRNCMP(p, "struct", 6) == 0)
    p = skipwhite(p + 6);
  else if (len == 4 && STRNCMP(p, "enum", 4) == 0)
    p = skipwhite(p + 4);
  else if ((len == 8 && STRNCMP(p, "unsigned", 8) == 0)
           || (len == 6 && STRNCMP(p, "signed", 6) == 0)) {
    s = skipwhite(p + len);
    if ((STRNCMP(s, "int", 3) == 0 && ascii_iswhite(s[3]))
        || (STRNCMP(s, "long", 4) == 0 && ascii_iswhite(s[4]))
        || (STRNCMP(s, "short", 5) == 0 && ascii_iswhite(s[5]))
        || (STRNCMP(s, "char", 4) == 0 && ascii_iswhite(s[4])))
      p = s;
  }
  for (len = 0; vim_isIDc(p[len]); ++len)
    ;
  if (len == 0 || !ascii_iswhite(p[len]) || cin_nocode(p))
    return 0;

  p = skipwhite(p + len);
  fp.lnum = curwin->w_cursor.lnum;
  fp.col = (colnr_T)(p - line);
  getvcol(curwin, &fp, &col, NULL, NULL);
  return (int)col;
}

/*
 * Return the indent of the first non-blank after an equal sign.
 *       char *foo = "here";
 * Return zero if no (useful) equal sign found.
 * Return -1 if the line above "lnum" ends in a backslash.
 *      foo = "asdf\
 *	       asdf\
 *	       here";
 */
static int cin_get_equal_amount(linenr_T lnum)
{
  char_u      *line;
  char_u      *s;
  colnr_T col;
  pos_T fp;

  if (lnum > 1) {
    line = ml_get(lnum - 1);
    if (*line != NUL && line[STRLEN(line) - 1] == '\\')
      return -1;
  }

  line = s = ml_get(lnum);
  while (*s != NUL && vim_strchr((char_u *)"=;{}\"'", *s) == NULL) {
    if (cin_iscomment(s))       /* ignore comments */
      s = cin_skipcomment(s);
    else
      ++s;
  }
  if (*s != '=')
    return 0;

  s = skipwhite(s + 1);
  if (cin_nocode(s))
    return 0;

  if (*s == '"')        /* nice alignment for continued strings */
    ++s;

  fp.lnum = lnum;
  fp.col = (colnr_T)(s - line);
  getvcol(curwin, &fp, &col, NULL, NULL);
  return (int)col;
}

/*
 * Recognize a preprocessor statement: Any line that starts with '#'.
 */
static int cin_ispreproc(char_u *s)
{
  if (*skipwhite(s) == '#')
    return TRUE;
  return FALSE;
}

/// Return TRUE if line "*pp" at "*lnump" is a preprocessor statement or a
/// continuation line of a preprocessor statement.  Decrease "*lnump" to the
/// start and return the line in "*pp".
/// Put the amount of indent in "*amount".
static int cin_ispreproc_cont(char_u **pp, linenr_T *lnump, int *amount)
{
  char_u      *line = *pp;
  linenr_T lnum = *lnump;
  int retval = false;
  int candidate_amount = *amount;

  if (*line != NUL && line[STRLEN(line) - 1] == '\\') {
    candidate_amount = get_indent_lnum(lnum);
  }

  for (;; ) {
    if (cin_ispreproc(line)) {
      retval = TRUE;
      *lnump = lnum;
      break;
    }
    if (lnum == 1)
      break;
    line = ml_get(--lnum);
    if (*line == NUL || line[STRLEN(line) - 1] != '\\')
      break;
  }

  if (lnum != *lnump) {
    *pp = ml_get(*lnump);
  }
  if (retval) {
    *amount = candidate_amount;
  }
  return retval;
}

/*
 * Recognize the start of a C or C++ comment.
 */
static int cin_iscomment(char_u *p)
{
  return p[0] == '/' && (p[1] == '*' || p[1] == '/');
}

/*
 * Recognize the start of a "//" comment.
 */
static int cin_islinecomment(char_u *p)
{
  return p[0] == '/' && p[1] == '/';
}

/*
 * Recognize a line that starts with '{' or '}', or ends with ';', ',', '{' or
 * '}'.
 * Don't consider "} else" a terminated line.
 * If a line begins with an "else", only consider it terminated if no unmatched
 * opening braces follow (handle "else { foo();" correctly).
 * Return the character terminating the line (ending char's have precedence if
 * both apply in order to determine initializations).
 */
static char_u
cin_isterminated (
    char_u *s,
    int incl_open,                  /* include '{' at the end as terminator */
    int incl_comma                 /* recognize a trailing comma */
)
{
  char_u found_start = 0;
  unsigned n_open = 0;
  int is_else = FALSE;

  s = cin_skipcomment(s);

  if (*s == '{' || (*s == '}' && !cin_iselse(s)))
    found_start = *s;

  if (!found_start)
    is_else = cin_iselse(s);

  while (*s) {
    /* skip over comments, "" strings and 'c'haracters */
    s = skip_string(cin_skipcomment(s));
    if (*s == '}' && n_open > 0)
      --n_open;
    if ((!is_else || n_open == 0)
        && (*s == ';' || *s == '}' || (incl_comma && *s == ','))
        && cin_nocode(s + 1))
      return *s;
    else if (*s == '{') {
      if (incl_open && cin_nocode(s + 1))
        return *s;
      else
        ++n_open;
    }

    if (*s)
      s++;
  }
  return found_start;
}

/// Recognizes the basic picture of a function declaration -- it needs to
/// have an open paren somewhere and a close paren at the end of the line and
/// no semicolons anywhere.
/// When a line ends in a comma we continue looking in the next line.
///
/// @param[in]  sp  Points to a string with the line. When looking at other
///                 lines it must be restored to the line. When it's NULL fetch
///                 lines here.
/// @param[in]  first_lnum Where to start looking.
/// @param[in]  min_lnum The line before which we will not be looking.
static int cin_isfuncdecl(char_u **sp, linenr_T first_lnum, linenr_T min_lnum)
{
  char_u      *s;
  linenr_T lnum = first_lnum;
  linenr_T save_lnum = curwin->w_cursor.lnum;
  int retval = false;
  pos_T       *trypos;
  int just_started = TRUE;

  if (sp == NULL)
    s = ml_get(lnum);
  else
    s = *sp;

  curwin->w_cursor.lnum = lnum;
  if (find_last_paren(s, '(', ')')
      && (trypos = find_match_paren(curbuf->b_ind_maxparen)) != NULL) {
    lnum = trypos->lnum;
    if (lnum < min_lnum) {
      curwin->w_cursor.lnum = save_lnum;
      return false;
    }
    s = ml_get(lnum);
  }

  curwin->w_cursor.lnum = save_lnum;
  // Ignore line starting with #.
  if (cin_ispreproc(s)) {
    return false;
  }

  while (*s && *s != '(' && *s != ';' && *s != '\'' && *s != '"') {
    // ignore comments
    if (cin_iscomment(s)) {
      s = cin_skipcomment(s);
    } else if (*s == ':') {
      if (*(s + 1) == ':') {
        s += 2;
      } else {
        // To avoid a mistake in the following situation:
        // A::A(int a, int b)
        //     : a(0)  // <--not a function decl
        //     , b(0)
        // {...
        return false;
      }
    } else {
      s++;
    }
  }
  if (*s != '(') {
    return false;  // ';', ' or "  before any () or no '('
  }

  while (*s && *s != ';' && *s != '\'' && *s != '"') {
    if (*s == ')' && cin_nocode(s + 1)) {
      /* ')' at the end: may have found a match
       * Check for he previous line not to end in a backslash:
       *       #if defined(x) && \
       *		 defined(y)
       */
      lnum = first_lnum - 1;
      s = ml_get(lnum);
      if (*s == NUL || s[STRLEN(s) - 1] != '\\')
        retval = TRUE;
      goto done;
    }
    if ((*s == ',' && cin_nocode(s + 1)) || s[1] == NUL || cin_nocode(s)) {
      int comma = (*s == ',');

      /* ',' at the end: continue looking in the next line.
       * At the end: check for ',' in the next line, for this style:
       * func(arg1
       *       , arg2) */
      for (;; ) {
        if (lnum >= curbuf->b_ml.ml_line_count)
          break;
        s = ml_get(++lnum);
        if (!cin_ispreproc(s))
          break;
      }
      if (lnum >= curbuf->b_ml.ml_line_count)
        break;
      /* Require a comma at end of the line or a comma or ')' at the
       * start of next line. */
      s = skipwhite(s);
      if (!just_started && (!comma && *s != ',' && *s != ')'))
        break;
      just_started = FALSE;
    } else if (cin_iscomment(s))        /* ignore comments */
      s = cin_skipcomment(s);
    else {
      ++s;
      just_started = FALSE;
    }
  }

done:
  if (lnum != first_lnum && sp != NULL)
    *sp = ml_get(first_lnum);

  return retval;
}

static int cin_isif(char_u *p)
{
  return STRNCMP(p, "if", 2) == 0 && !vim_isIDc(p[2]);
}

static int cin_iselse(char_u *p)
{
  if (*p == '}')            /* accept "} else" */
    p = cin_skipcomment(p + 1);
  return STRNCMP(p, "else", 4) == 0 && !vim_isIDc(p[4]);
}

static int cin_isdo(char_u *p)
{
  return STRNCMP(p, "do", 2) == 0 && !vim_isIDc(p[2]);
}

/*
 * Check if this is a "while" that should have a matching "do".
 * We only accept a "while (condition) ;", with only white space between the
 * ')' and ';'. The condition may be spread over several lines.
 */
static int 
cin_iswhileofdo ( /* XXX */
    char_u *p,
    linenr_T lnum
)
{
  pos_T cursor_save;
  pos_T       *trypos;
  int retval = FALSE;

  p = cin_skipcomment(p);
  if (*p == '}')                /* accept "} while (cond);" */
    p = cin_skipcomment(p + 1);
  if (cin_starts_with(p, "while")) {
    cursor_save = curwin->w_cursor;
    curwin->w_cursor.lnum = lnum;
    curwin->w_cursor.col = 0;
    p = get_cursor_line_ptr();
    while (*p && *p != 'w') {   /* skip any '}', until the 'w' of the "while" */
      ++p;
      ++curwin->w_cursor.col;
    }
    if ((trypos = findmatchlimit(NULL, 0, 0,
             curbuf->b_ind_maxparen)) != NULL
        && *cin_skipcomment(ml_get_pos(trypos) + 1) == ';')
      retval = TRUE;
    curwin->w_cursor = cursor_save;
  }
  return retval;
}

/*
 * Check whether in "p" there is an "if", "for" or "while" before "*poffset".
 * Return 0 if there is none.
 * Otherwise return !0 and update "*poffset" to point to the place where the
 * string was found.
 */
static int cin_is_if_for_while_before_offset(char_u *line, int *poffset)
{
  int offset = *poffset;

  if (offset-- < 2)
    return 0;
  while (offset > 2 && ascii_iswhite(line[offset]))
    --offset;

  offset -= 1;
  if (!STRNCMP(line + offset, "if", 2))
    goto probablyFound;

  if (offset >= 1) {
    offset -= 1;
    if (!STRNCMP(line + offset, "for", 3))
      goto probablyFound;

    if (offset >= 2) {
      offset -= 2;
      if (!STRNCMP(line + offset, "while", 5))
        goto probablyFound;
    }
  }
  return 0;

probablyFound:
  if (!offset || !vim_isIDc(line[offset - 1])) {
    *poffset = offset;
    return 1;
  }
  return 0;
}

/*
 * Return TRUE if we are at the end of a do-while.
 *    do
 *       nothing;
 *    while (foo
 *	       && bar);  <-- here
 * Adjust the cursor to the line with "while".
 */
static int cin_iswhileofdo_end(int terminated)
{
  char_u      *line;
  char_u      *p;
  char_u      *s;
  pos_T       *trypos;
  int i;

  if (terminated != ';')        /* there must be a ';' at the end */
    return FALSE;

  p = line = get_cursor_line_ptr();
  while (*p != NUL) {
    p = cin_skipcomment(p);
    if (*p == ')') {
      s = skipwhite(p + 1);
      if (*s == ';' && cin_nocode(s + 1)) {
        /* Found ");" at end of the line, now check there is "while"
         * before the matching '('.  XXX */
        i = (int)(p - line);
        curwin->w_cursor.col = i;
        trypos = find_match_paren(curbuf->b_ind_maxparen);
        if (trypos != NULL) {
          s = cin_skipcomment(ml_get(trypos->lnum));
          if (*s == '}')                        /* accept "} while (cond);" */
            s = cin_skipcomment(s + 1);
          if (cin_starts_with(s, "while")) {
            curwin->w_cursor.lnum = trypos->lnum;
            return TRUE;
          }
        }

        /* Searching may have made "line" invalid, get it again. */
        line = get_cursor_line_ptr();
        p = line + i;
      }
    }
    if (*p != NUL)
      ++p;
  }
  return FALSE;
}

static int cin_isbreak(char_u *p)
{
  return STRNCMP(p, "break", 5) == 0 && !vim_isIDc(p[5]);
}

/*
 * Find the position of a C++ base-class declaration or
 * constructor-initialization. eg:
 *
 * class MyClass :
 *	baseClass		<-- here
 * class MyClass : public baseClass,
 *	anotherBaseClass	<-- here (should probably lineup ??)
 * MyClass::MyClass(...) :
 *	baseClass(...)		<-- here (constructor-initialization)
 *
 * This is a lot of guessing.  Watch out for "cond ? func() : foo".
 */
static int cin_is_cpp_baseclass(cpp_baseclass_cache_T *cached) {
  lpos_T *pos = &cached->lpos;  // find position
  char_u      *s;
  int class_or_struct, lookfor_ctor_init, cpp_base_class;
  linenr_T lnum = curwin->w_cursor.lnum;
  char_u      *line = get_cursor_line_ptr();

  if (pos->lnum <= lnum) {
    return cached->found;  // Use the cached result
  }

  pos->col = 0;

  s = skipwhite(line);
  if (*s == '#')                /* skip #define FOO x ? (x) : x */
    return FALSE;
  s = cin_skipcomment(s);
  if (*s == NUL)
    return FALSE;

  cpp_base_class = lookfor_ctor_init = class_or_struct = FALSE;

  /* Search for a line starting with '#', empty, ending in ';' or containing
   * '{' or '}' and start below it.  This handles the following situations:
   *	a = cond ?
   *	      func() :
   *		   asdf;
   *	func::foo()
   *	      : something
   *	{}
   *	Foo::Foo (int one, int two)
   *		: something(4),
   *		somethingelse(3)
   *	{}
   */
  while (lnum > 1) {
    line = ml_get(lnum - 1);
    s = skipwhite(line);
    if (*s == '#' || *s == NUL)
      break;
    while (*s != NUL) {
      s = cin_skipcomment(s);
      if (*s == '{' || *s == '}'
          || (*s == ';' && cin_nocode(s + 1)))
        break;
      if (*s != NUL)
        ++s;
    }
    if (*s != NUL)
      break;
    --lnum;
  }

  pos->lnum = lnum;
  line = ml_get(lnum);
  s = line;
  for (;; ) {
    if (*s == NUL) {
      if (lnum == curwin->w_cursor.lnum) {
        break;
      }
      // Continue in the cursor line.
      line = ml_get(++lnum);
      s = line;
    }
    if (s == line) {
      // don't recognize "case (foo):" as a baseclass */
      if (cin_iscase(s, false)) {
        break;
      }
      s = cin_skipcomment(line);
      if (*s == NUL)
        continue;
    }

    if (s[0] == '"' || (s[0] == 'R' && s[1] == '"'))
      s = skip_string(s) + 1;
    else if (s[0] == ':') {
      if (s[1] == ':') {
        /* skip double colon. It can't be a constructor
         * initialization any more */
        lookfor_ctor_init = FALSE;
        s = cin_skipcomment(s + 2);
      } else if (lookfor_ctor_init || class_or_struct) {
        /* we have something found, that looks like the start of
         * cpp-base-class-declaration or constructor-initialization */
        cpp_base_class = true;
        lookfor_ctor_init = class_or_struct = false;
        pos->col = 0;
        s = cin_skipcomment(s + 1);
      } else
        s = cin_skipcomment(s + 1);
    } else if ((STRNCMP(s, "class", 5) == 0 && !vim_isIDc(s[5]))
               || (STRNCMP(s, "struct", 6) == 0 && !vim_isIDc(s[6]))) {
      class_or_struct = TRUE;
      lookfor_ctor_init = FALSE;

      if (*s == 'c')
        s = cin_skipcomment(s + 5);
      else
        s = cin_skipcomment(s + 6);
    } else {
      if (s[0] == '{' || s[0] == '}' || s[0] == ';') {
        cpp_base_class = lookfor_ctor_init = class_or_struct = FALSE;
      } else if (s[0] == ')') {
        /* Constructor-initialization is assumed if we come across
         * something like "):" */
        class_or_struct = FALSE;
        lookfor_ctor_init = TRUE;
      } else if (s[0] == '?') {
        /* Avoid seeing '() :' after '?' as constructor init. */
        return FALSE;
      } else if (!vim_isIDc(s[0])) {
        /* if it is not an identifier, we are wrong */
        class_or_struct = false;
        lookfor_ctor_init = false;
      } else if (pos->col == 0) {
        /* it can't be a constructor-initialization any more */
        lookfor_ctor_init = FALSE;

        /* the first statement starts here: lineup with this one... */
        if (cpp_base_class) {
          pos->col = (colnr_T)(s - line);
        }
      }

      /* When the line ends in a comma don't align with it. */
      if (lnum == curwin->w_cursor.lnum && *s == ',' && cin_nocode(s + 1)) {
        pos->col = 0;
      }

      s = cin_skipcomment(s + 1);
    }
  }

  cached->found = cpp_base_class;
  if (cpp_base_class) {
    pos->lnum = lnum;
  }
  return cpp_base_class;
}

static int get_baseclass_amount(int col)
{
  int amount;
  colnr_T vcol;
  pos_T       *trypos;

  if (col == 0) {
    amount = get_indent();
    if (find_last_paren(get_cursor_line_ptr(), '(', ')')
        && (trypos = find_match_paren(curbuf->b_ind_maxparen)) != NULL)
      amount = get_indent_lnum(trypos->lnum);       /* XXX */
    if (!cin_ends_in(get_cursor_line_ptr(), (char_u *)",", NULL))
      amount += curbuf->b_ind_cpp_baseclass;
  } else {
    curwin->w_cursor.col = col;
    getvcol(curwin, &curwin->w_cursor, &vcol, NULL, NULL);
    amount = (int)vcol;
  }
  if (amount < curbuf->b_ind_cpp_baseclass)
    amount = curbuf->b_ind_cpp_baseclass;
  return amount;
}

/*
 * Return TRUE if string "s" ends with the string "find", possibly followed by
 * white space and comments.  Skip strings and comments.
 * Ignore "ignore" after "find" if it's not NULL.
 */
static int cin_ends_in(char_u *s, char_u *find, char_u *ignore)
{
  char_u      *p = s;
  char_u      *r;
  int len = (int)STRLEN(find);

  while (*p != NUL) {
    p = cin_skipcomment(p);
    if (STRNCMP(p, find, len) == 0) {
      r = skipwhite(p + len);
      if (ignore != NULL && STRNCMP(r, ignore, STRLEN(ignore)) == 0)
        r = skipwhite(r + STRLEN(ignore));
      if (cin_nocode(r))
        return TRUE;
    }
    if (*p != NUL)
      ++p;
  }
  return FALSE;
}

/*
 * Return TRUE when "s" starts with "word" and then a non-ID character.
 */
static int cin_starts_with(char_u *s, char *word)
{
  int l = (int)STRLEN(word);

  return STRNCMP(s, word, l) == 0 && !vim_isIDc(s[l]);
}

/// Recognize a `extern "C"` or `extern "C++"` linkage specifications.
static int cin_is_cpp_extern_c(char_u *s)
{
  char_u  *p;
  int     has_string_literal = false;

  s = cin_skipcomment(s);
  if (STRNCMP(s, "extern", 6) == 0 && (s[6] == NUL || !vim_iswordc(s[6]))) {
    p = cin_skipcomment(skipwhite(s + 6));
    while (*p != NUL) {
      if (ascii_iswhite(*p)) {
        p = cin_skipcomment(skipwhite(p));
      } else if (*p == '{') {
        break;
      } else if (p[0] == '"' && p[1] == 'C' && p[2] == '"') {
        if (has_string_literal) {
          return false;
        }
        has_string_literal = true;
        p += 3;
      } else if (p[0] == '"' && p[1] == 'C' && p[2] == '+' && p[3] == '+'
                 && p[4] == '"') {
        if (has_string_literal) {
          return false;
        }
        has_string_literal = true;
        p += 5;
      } else {
        return false;
      }
    }
    return has_string_literal ? true : false;
  }
  return false;
}


/*
 * Skip strings, chars and comments until at or past "trypos".
 * Return the column found.
 */
static int cin_skip2pos(pos_T *trypos)
{
  char_u      *line;
  char_u      *p;
  char_u      *new_p;

  p = line = ml_get(trypos->lnum);
  while (*p && (colnr_T)(p - line) < trypos->col) {
    if (cin_iscomment(p)) {
      p = cin_skipcomment(p);
    } else {
      new_p = skip_string(p);
      if (new_p == p) {
        p++;
      } else {
        p = new_p;
      }
    }
  }
  return (int)(p - line);
}

/*
 * Find the '{' at the start of the block we are in.
 * Return NULL if no match found.
 * Ignore a '{' that is in a comment, makes indenting the next three lines
 * work. */
/* foo()    */
/* {	    */
/* }	    */

static pos_T *find_start_brace(void)
{ /* XXX */
  pos_T cursor_save;
  pos_T       *trypos;
  pos_T       *pos;
  static pos_T pos_copy;

  cursor_save = curwin->w_cursor;
  while ((trypos = findmatchlimit(NULL, '{', FM_BLOCKSTOP, 0)) != NULL) {
    pos_copy = *trypos;         /* copy pos_T, next findmatch will change it */
    trypos = &pos_copy;
    curwin->w_cursor = *trypos;
    pos = NULL;
    /* ignore the { if it's in a // or / *  * / comment */
    if ((colnr_T)cin_skip2pos(trypos) == trypos->col
            && (pos = ind_find_start_CORS()) == NULL) /* XXX */
      break;
    if (pos != NULL)
      curwin->w_cursor.lnum = pos->lnum;
  }
  curwin->w_cursor = cursor_save;
  return trypos;
}

/// Find the matching '(', ignoring it if it is in a comment.
/// @returns NULL or the found match.
static pos_T *find_match_paren(int ind_maxparen)
{
  return find_match_char('(', ind_maxparen);
}

static pos_T * find_match_char(char_u c, int ind_maxparen)
{
  pos_T cursor_save;
  pos_T       *trypos;
  static pos_T pos_copy;
  int ind_maxp_wk;

  cursor_save = curwin->w_cursor;
  ind_maxp_wk = ind_maxparen;
retry:
  if ((trypos = findmatchlimit(NULL, c, 0, ind_maxp_wk)) != NULL) {
    // check if the ( is in a // comment
    if ((colnr_T)cin_skip2pos(trypos) > trypos->col) {
      ind_maxp_wk = ind_maxparen - (int)(cursor_save.lnum - trypos->lnum);
      if (ind_maxp_wk > 0) {
        curwin->w_cursor = *trypos;
        curwin->w_cursor.col = 0;  // XXX
        goto retry;
      }
      trypos = NULL;
    } else {
      pos_T *trypos_wk;

      pos_copy = *trypos;           /* copy trypos, findmatch will change it */
      trypos = &pos_copy;
      curwin->w_cursor = *trypos;
      if ((trypos_wk = ind_find_start_CORS()) != NULL) { /* XXX */
        ind_maxp_wk = ind_maxparen - (int)(cursor_save.lnum
            - trypos_wk->lnum);
        if (ind_maxp_wk > 0) {
          curwin->w_cursor = *trypos_wk;
          goto retry;
        }
        trypos = NULL;
      }
    }
  }
  curwin->w_cursor = cursor_save;
  return trypos;
}

/// Find the matching '(', ignoring it if it is in a comment or before an
/// unmatched {.
/// @returns NULL or the found match.
static pos_T *find_match_paren_after_brace(int ind_maxparen)
{
  pos_T *trypos = find_match_paren(ind_maxparen);
  if (trypos == NULL) {
    return NULL;
  }

  pos_T *tryposBrace = find_start_brace();
  // If both an unmatched '(' and '{' is found.  Ignore the '('
  // position if the '{' is further down.
  if (tryposBrace != NULL
      && (trypos->lnum != tryposBrace->lnum
          ? trypos->lnum < tryposBrace->lnum
          : trypos->col < tryposBrace->col)) {
    trypos = NULL;
  }
  return trypos;
}


/*
 * Return ind_maxparen corrected for the difference in line number between the
 * cursor position and "startpos".  This makes sure that searching for a
 * matching paren above the cursor line doesn't find a match because of
 * looking a few lines further.
 */
static int corr_ind_maxparen(pos_T *startpos)
{
  long n = (long)startpos->lnum - (long)curwin->w_cursor.lnum;

  if (n > 0 && n < curbuf->b_ind_maxparen / 2)
    return curbuf->b_ind_maxparen - (int)n;
  return curbuf->b_ind_maxparen;
}

/*
 * Set w_cursor.col to the column number of the last unmatched ')' or '{' in
 * line "l".  "l" must point to the start of the line.
 */
static int find_last_paren(char_u *l, int start, int end)
{
  int i;
  int retval = FALSE;
  int open_count = 0;

  curwin->w_cursor.col = 0;                 /* default is start of line */

  for (i = 0; l[i] != NUL; i++) {
    i = (int)(cin_skipcomment(l + i) - l);     /* ignore parens in comments */
    i = (int)(skip_string(l + i) - l);        /* ignore parens in quotes */
    if (l[i] == start)
      ++open_count;
    else if (l[i] == end) {
      if (open_count > 0)
        --open_count;
      else {
        curwin->w_cursor.col = i;
        retval = TRUE;
      }
    }
  }
  return retval;
}

/*
 * Parse 'cinoptions' and set the values in "curbuf".
 * Must be called when 'cinoptions', 'shiftwidth' and/or 'tabstop' changes.
 */
void parse_cino(buf_T *buf)
{
  char_u      *p;
  char_u      *l;
  int divider;
  int fraction = 0;
  int sw = get_sw_value(buf);

  /*
   * Set the default values.
   */
  /* Spaces from a block's opening brace the prevailing indent for that
   * block should be. */
  buf->b_ind_level = sw;

  /* Spaces from the edge of the line an open brace that's at the end of a
   * line is imagined to be. */
  buf->b_ind_open_imag = 0;

  /* Spaces from the prevailing indent for a line that is not preceded by
   * an opening brace. */
  buf->b_ind_no_brace = 0;

  /* Column where the first { of a function should be located }. */
  buf->b_ind_first_open = 0;

  /* Spaces from the prevailing indent a leftmost open brace should be
   * located. */
  buf->b_ind_open_extra = 0;

  /* Spaces from the matching open brace (real location for one at the left
   * edge; imaginary location from one that ends a line) the matching close
   * brace should be located. */
  buf->b_ind_close_extra = 0;

  /* Spaces from the edge of the line an open brace sitting in the leftmost
   * column is imagined to be. */
  buf->b_ind_open_left_imag = 0;

  /* Spaces jump labels should be shifted to the left if N is non-negative,
   * otherwise the jump label will be put to column 1. */
  buf->b_ind_jump_label = -1;

  /* Spaces from the switch() indent a "case xx" label should be located. */
  buf->b_ind_case = sw;

  /* Spaces from the "case xx:" code after a switch() should be located. */
  buf->b_ind_case_code = sw;

  /* Lineup break at end of case in switch() with case label. */
  buf->b_ind_case_break = 0;

  /* Spaces from the class declaration indent a scope declaration label
   * should be located. */
  buf->b_ind_scopedecl = sw;

  /* Spaces from the scope declaration label code should be located. */
  buf->b_ind_scopedecl_code = sw;

  /* Amount K&R-style parameters should be indented. */
  buf->b_ind_param = sw;

  /* Amount a function type spec should be indented. */
  buf->b_ind_func_type = sw;

  /* Amount a cpp base class declaration or constructor initialization
   * should be indented. */
  buf->b_ind_cpp_baseclass = sw;

  /* additional spaces beyond the prevailing indent a continuation line
   * should be located. */
  buf->b_ind_continuation = sw;

  /* Spaces from the indent of the line with an unclosed parentheses. */
  buf->b_ind_unclosed = sw * 2;

  /* Spaces from the indent of the line with an unclosed parentheses, which
   * itself is also unclosed. */
  buf->b_ind_unclosed2 = sw;

  /* Suppress ignoring spaces from the indent of a line starting with an
   * unclosed parentheses. */
  buf->b_ind_unclosed_noignore = 0;

  /* If the opening paren is the last nonwhite character on the line, and
   * b_ind_unclosed_wrapped is nonzero, use this indent relative to the outer
   * context (for very long lines). */
  buf->b_ind_unclosed_wrapped = 0;

  /* Suppress ignoring white space when lining up with the character after
   * an unclosed parentheses. */
  buf->b_ind_unclosed_whiteok = 0;

  /* Indent a closing parentheses under the line start of the matching
   * opening parentheses. */
  buf->b_ind_matching_paren = 0;

  /* Indent a closing parentheses under the previous line. */
  buf->b_ind_paren_prev = 0;

  /* Extra indent for comments. */
  buf->b_ind_comment = 0;

  /* Spaces from the comment opener when there is nothing after it. */
  buf->b_ind_in_comment = 3;

  /* Boolean: if non-zero, use b_ind_in_comment even if there is something
   * after the comment opener. */
  buf->b_ind_in_comment2 = 0;

  /* Max lines to search for an open paren. */
  buf->b_ind_maxparen = 20;

  /* Max lines to search for an open comment. */
  buf->b_ind_maxcomment = 70;

  /* Handle braces for java code. */
  buf->b_ind_java = 0;

  /* Not to confuse JS object properties with labels. */
  buf->b_ind_js = 0;

  /* Handle blocked cases correctly. */
  buf->b_ind_keep_case_label = 0;

  /* Handle C++ namespace. */
  buf->b_ind_cpp_namespace = 0;

  /* Handle continuation lines containing conditions of if(), for() and
   * while(). */
  buf->b_ind_if_for_while = 0;

  // indentation for # comments
  buf->b_ind_hash_comment = 0;

  // Handle C++ extern "C" or "C++"
  buf->b_ind_cpp_extern_c = 0;

  for (p = buf->b_p_cino; *p; ) {
    l = p++;
    if (*p == '-')
      ++p;
    char_u *digits_start = p;             /* remember where the digits start */
    int n = getdigits_int(&p);
    divider = 0;
    if (*p == '.') {        /* ".5s" means a fraction */
      fraction = atoi((char *)++p);
      while (ascii_isdigit(*p)) {
        ++p;
        if (divider)
          divider *= 10;
        else
          divider = 10;
      }
    }
    if (*p == 's') {        /* "2s" means two times 'shiftwidth' */
      if (p == digits_start)
        n = sw;         /* just "s" is one 'shiftwidth' */
      else {
        n *= sw;
        if (divider)
          n += (sw * fraction + divider / 2) / divider;
      }
      ++p;
    }
    if (l[1] == '-')
      n = -n;

    /* When adding an entry here, also update the default 'cinoptions' in
     * doc/indent.txt, and add explanation for it! */
    switch (*l) {
    case '>': buf->b_ind_level = n; break;
    case 'e': buf->b_ind_open_imag = n; break;
    case 'n': buf->b_ind_no_brace = n; break;
    case 'f': buf->b_ind_first_open = n; break;
    case '{': buf->b_ind_open_extra = n; break;
    case '}': buf->b_ind_close_extra = n; break;
    case '^': buf->b_ind_open_left_imag = n; break;
    case 'L': buf->b_ind_jump_label = n; break;
    case ':': buf->b_ind_case = n; break;
    case '=': buf->b_ind_case_code = n; break;
    case 'b': buf->b_ind_case_break = n; break;
    case 'p': buf->b_ind_param = n; break;
    case 't': buf->b_ind_func_type = n; break;
    case '/': buf->b_ind_comment = n; break;
    case 'c': buf->b_ind_in_comment = n; break;
    case 'C': buf->b_ind_in_comment2 = n; break;
    case 'i': buf->b_ind_cpp_baseclass = n; break;
    case '+': buf->b_ind_continuation = n; break;
    case '(': buf->b_ind_unclosed = n; break;
    case 'u': buf->b_ind_unclosed2 = n; break;
    case 'U': buf->b_ind_unclosed_noignore = n; break;
    case 'W': buf->b_ind_unclosed_wrapped = n; break;
    case 'w': buf->b_ind_unclosed_whiteok = n; break;
    case 'm': buf->b_ind_matching_paren = n; break;
    case 'M': buf->b_ind_paren_prev = n; break;
    case ')': buf->b_ind_maxparen = n; break;
    case '*': buf->b_ind_maxcomment = n; break;
    case 'g': buf->b_ind_scopedecl = n; break;
    case 'h': buf->b_ind_scopedecl_code = n; break;
    case 'j': buf->b_ind_java = n; break;
    case 'J': buf->b_ind_js = n; break;
    case 'l': buf->b_ind_keep_case_label = n; break;
    case '#': buf->b_ind_hash_comment = n; break;
    case 'N': buf->b_ind_cpp_namespace = n; break;
    case 'k': buf->b_ind_if_for_while = n; break;
    case 'E': buf->b_ind_cpp_extern_c = n; break;
    }
    if (*p == ',')
      ++p;
  }
}

/*
 * Return the desired indent for C code.
 * Return -1 if the indent should be left alone (inside a raw string).
 */
int get_c_indent(void)
{
  pos_T cur_curpos;
  int amount;
  int scope_amount;
  int cur_amount = MAXCOL;
  colnr_T col;
  char_u      *theline;
  char_u      *linecopy;
  pos_T       *trypos;
  pos_T       *comment_pos;
  pos_T       *tryposBrace = NULL;
  pos_T       tryposCopy;
  pos_T our_paren_pos;
  char_u      *start;
  int start_brace;
#define BRACE_IN_COL0           1           /* '{' is in column 0 */
#define BRACE_AT_START          2           /* '{' is at start of line */
#define BRACE_AT_END            3           /* '{' is at end of line */
  linenr_T ourscope;
  char_u      *l;
  char_u      *look;
  char_u terminated;
  int lookfor;
#define LOOKFOR_INITIAL         0
#define LOOKFOR_IF              1
#define LOOKFOR_DO              2
#define LOOKFOR_CASE            3
#define LOOKFOR_ANY             4
#define LOOKFOR_TERM            5
#define LOOKFOR_UNTERM          6
#define LOOKFOR_SCOPEDECL       7
#define LOOKFOR_NOBREAK         8
#define LOOKFOR_CPP_BASECLASS   9
#define LOOKFOR_ENUM_OR_INIT    10
#define LOOKFOR_JS_KEY          11
#define LOOKFOR_COMMA           12

  int whilelevel;
  linenr_T lnum;
  int n;
  int iscase;
  int lookfor_break;
  int lookfor_cpp_namespace = FALSE;
  int cont_amount = 0;              /* amount for continuation line */
  int original_line_islabel;
  int added_to_amount = 0;
  cpp_baseclass_cache_T cache_cpp_baseclass = { false, { MAXLNUM, 0 } };

  /* make a copy, value is changed below */
  int ind_continuation = curbuf->b_ind_continuation;

  /* remember where the cursor was when we started */
  cur_curpos = curwin->w_cursor;

  /* if we are at line 1 zero indent is fine, right? */
  if (cur_curpos.lnum == 1)
    return 0;

  /* Get a copy of the current contents of the line.
   * This is required, because only the most recent line obtained with
   * ml_get is valid! */
  linecopy = vim_strsave(ml_get(cur_curpos.lnum));

  /*
   * In insert mode and the cursor is on a ')' truncate the line at the
   * cursor position.  We don't want to line up with the matching '(' when
   * inserting new stuff.
   * For unknown reasons the cursor might be past the end of the line, thus
   * check for that.
   */
  if ((State & INSERT)
      && curwin->w_cursor.col < (colnr_T)STRLEN(linecopy)
      && linecopy[curwin->w_cursor.col] == ')')
    linecopy[curwin->w_cursor.col] = NUL;

  theline = skipwhite(linecopy);

  /* move the cursor to the start of the line */

  curwin->w_cursor.col = 0;

  original_line_islabel = cin_islabel();    /* XXX */

  /*
   * If we are inside a raw string don't change the indent.
   * Ignore a raw string inside a comment.
   */
  comment_pos = ind_find_start_comment();
  if (comment_pos != NULL) {
    /* findmatchlimit() static pos is overwritten, make a copy */
    tryposCopy = *comment_pos;
    comment_pos = &tryposCopy;
  }
  trypos = find_start_rawstring(curbuf->b_ind_maxcomment);
  if (trypos != NULL && (comment_pos == NULL || lt(*trypos, *comment_pos))) {
    amount = -1;
    goto laterend;
  }

  /*
   * #defines and so on always go at the left when included in 'cinkeys'.
   */
  if (*theline == '#' && (*linecopy == '#' || in_cinkeys('#', ' ', true))) {
    amount = curbuf->b_ind_hash_comment;
    goto theend;
  }

  /*
   * Is it a non-case label?	Then that goes at the left margin too unless:
   *  - JS flag is set.
   *  - 'L' item has a positive value.
   */
  if (original_line_islabel && !curbuf->b_ind_js
           && curbuf->b_ind_jump_label < 0) {
    amount = 0;
    goto theend;
  }
  /*
   * If we're inside a "//" comment and there is a "//" comment in a
   * previous line, lineup with that one.
   */
  if (cin_islinecomment(theline)
           && (trypos = find_line_comment()) != NULL) { /* XXX */
    /* find how indented the line beginning the comment is */
    getvcol(curwin, trypos, &col, NULL, NULL);
    amount = col;
    goto theend;
  }
  /*
   * If we're inside a comment and not looking at the start of the
   * comment, try using the 'comments' option.
   */
  if (!cin_iscomment(theline) && comment_pos != NULL) { /* XXX */
    int lead_start_len = 2;
    int lead_middle_len = 1;
    char_u lead_start[COM_MAX_LEN];             /* start-comment string */
    char_u lead_middle[COM_MAX_LEN];            /* middle-comment string */
    char_u lead_end[COM_MAX_LEN];               /* end-comment string */
    char_u  *p;
    int start_align = 0;
    int start_off = 0;
    int done = FALSE;

    /* find how indented the line beginning the comment is */
    getvcol(curwin, comment_pos, &col, NULL, NULL);
    amount = col;
    *lead_start = NUL;
    *lead_middle = NUL;

    p = curbuf->b_p_com;
    while (*p != NUL) {
      int align = 0;
      int off = 0;
      int what = 0;

      while (*p != NUL && *p != ':') {
        if (*p == COM_START || *p == COM_END || *p == COM_MIDDLE)
          what = *p++;
        else if (*p == COM_LEFT || *p == COM_RIGHT)
          align = *p++;
        else if (ascii_isdigit(*p) || *p == '-') {
          off = getdigits_int(&p);
        }
        else
          ++p;
      }

      if (*p == ':')
        ++p;
      (void)copy_option_part(&p, lead_end, COM_MAX_LEN, ",");
      if (what == COM_START) {
        STRCPY(lead_start, lead_end);
        lead_start_len = (int)STRLEN(lead_start);
        start_off = off;
        start_align = align;
      } else if (what == COM_MIDDLE) {
        STRCPY(lead_middle, lead_end);
        lead_middle_len = (int)STRLEN(lead_middle);
      } else if (what == COM_END) {
        /* If our line starts with the middle comment string, line it
         * up with the comment opener per the 'comments' option. */
        if (STRNCMP(theline, lead_middle, lead_middle_len) == 0
            && STRNCMP(theline, lead_end, STRLEN(lead_end)) != 0) {
          done = TRUE;
          if (curwin->w_cursor.lnum > 1) {
            /* If the start comment string matches in the previous
             * line, use the indent of that line plus offset.  If
             * the middle comment string matches in the previous
             * line, use the indent of that line.  XXX */
            look = skipwhite(ml_get(curwin->w_cursor.lnum - 1));
            if (STRNCMP(look, lead_start, lead_start_len) == 0)
              amount = get_indent_lnum(curwin->w_cursor.lnum - 1);
            else if (STRNCMP(look, lead_middle,
                         lead_middle_len) == 0) {
              amount = get_indent_lnum(curwin->w_cursor.lnum - 1);
              break;
            } else if (STRNCMP(ml_get(comment_pos->lnum) + comment_pos->col,
                        lead_start, lead_start_len) != 0) {
              /* If the start comment string doesn't match with the
               * start of the comment, skip this entry. XXX */
              continue;
            }
          }
          if (start_off != 0)
            amount += start_off;
          else if (start_align == COM_RIGHT)
            amount += vim_strsize(lead_start)
                      - vim_strsize(lead_middle);
          break;
        }

        /* If our line starts with the end comment string, line it up
         * with the middle comment */
        if (STRNCMP(theline, lead_middle, lead_middle_len) != 0
            && STRNCMP(theline, lead_end, STRLEN(lead_end)) == 0) {
          amount = get_indent_lnum(curwin->w_cursor.lnum - 1);
          /* XXX */
          if (off != 0)
            amount += off;
          else if (align == COM_RIGHT)
            amount += vim_strsize(lead_start)
                      - vim_strsize(lead_middle);
          done = TRUE;
          break;
        }
      }
    }

    /* If our line starts with an asterisk, line up with the
     * asterisk in the comment opener; otherwise, line up
     * with the first character of the comment text.
     */
    if (done)
      ;
    else if (theline[0] == '*')
      amount += 1;
    else {
      /*
       * If we are more than one line away from the comment opener, take
       * the indent of the previous non-empty line.  If 'cino' has "CO"
       * and we are just below the comment opener and there are any
       * white characters after it line up with the text after it;
       * otherwise, add the amount specified by "c" in 'cino'
       */
      amount = -1;
      for (lnum = cur_curpos.lnum - 1; lnum > comment_pos->lnum; --lnum) {
        if (linewhite(lnum))                        /* skip blank lines */
          continue;
        amount = get_indent_lnum(lnum);             /* XXX */
        break;
      }
      if (amount == -1) {                           /* use the comment opener */
        if (!curbuf->b_ind_in_comment2) {
            start = ml_get(comment_pos->lnum);
            look = start + comment_pos->col + 2; /* skip / and * */
          if (*look != NUL)                         /* if something after it */
              comment_pos->col = (colnr_T)(skipwhite(look) - start);
        }
        getvcol(curwin, comment_pos, &col, NULL, NULL);
        amount = col;
        if (curbuf->b_ind_in_comment2 || *look == NUL)
          amount += curbuf->b_ind_in_comment;
      }
    }
  goto theend;
  }
  // Are we looking at a ']' that has a match?
  if (*skipwhite(theline) == ']'
           && (trypos = find_match_char('[', curbuf->b_ind_maxparen)) != NULL) {
    // align with the line containing the '['.
    amount = get_indent_lnum(trypos->lnum);
    goto theend;
  }
  /*
   * Are we inside parentheses or braces?
   */						    /* XXX */
  if (((trypos = find_match_paren(curbuf->b_ind_maxparen)) != NULL
            && curbuf->b_ind_java == 0)
           || (tryposBrace = find_start_brace()) != NULL
           || trypos != NULL) {
    if (trypos != NULL && tryposBrace != NULL) {
      /* Both an unmatched '(' and '{' is found.  Use the one which is
       * closer to the current cursor position, set the other to NULL. */
      if (trypos->lnum != tryposBrace->lnum
          ? trypos->lnum < tryposBrace->lnum
          : trypos->col < tryposBrace->col)
        trypos = NULL;
      else
        tryposBrace = NULL;
    }

    if (trypos != NULL) {
      our_paren_pos = *trypos;
      /*
       * If the matching paren is more than one line away, use the indent of
       * a previous non-empty line that matches the same paren.
       */
      if (theline[0] == ')' && curbuf->b_ind_paren_prev) {
        /* Line up with the start of the matching paren line. */
        amount = get_indent_lnum(curwin->w_cursor.lnum - 1);      /* XXX */
      } else {
        amount = -1;
        for (lnum = cur_curpos.lnum - 1; lnum > our_paren_pos.lnum; --lnum) {
          l = skipwhite(ml_get(lnum));
          if (cin_nocode(l)) {                   // skip comment lines
            continue;
          }
          if (cin_ispreproc_cont(&l, &lnum, &amount)) {
            continue;                           // ignore #define, #if, etc.
          }
          curwin->w_cursor.lnum = lnum;

          /* Skip a comment or raw string. XXX */
          if ((trypos = ind_find_start_CORS()) != NULL) {
            lnum = trypos->lnum + 1;
            continue;
          }

          /* XXX */
          if ((trypos = find_match_paren(
                   corr_ind_maxparen(&cur_curpos))) != NULL
              && trypos->lnum == our_paren_pos.lnum
              && trypos->col == our_paren_pos.col) {
            amount = get_indent_lnum(lnum);             /* XXX */

            if (theline[0] == ')') {
              if (our_paren_pos.lnum != lnum
                  && cur_amount > amount)
                cur_amount = amount;
              amount = -1;
            }
            break;
          }
        }
      }

      /*
       * Line up with line where the matching paren is. XXX
       * If the line starts with a '(' or the indent for unclosed
       * parentheses is zero, line up with the unclosed parentheses.
       */
      if (amount == -1) {
        int ignore_paren_col = 0;
        int is_if_for_while = 0;

        if (curbuf->b_ind_if_for_while) {
          /* Look for the outermost opening parenthesis on this line
           * and check whether it belongs to an "if", "for" or "while". */

          pos_T cursor_save = curwin->w_cursor;
          pos_T outermost;
          char_u      *line;

          trypos = &our_paren_pos;
          do {
            outermost = *trypos;
            curwin->w_cursor.lnum = outermost.lnum;
            curwin->w_cursor.col = outermost.col;

            trypos = find_match_paren(curbuf->b_ind_maxparen);
          } while (trypos && trypos->lnum == outermost.lnum);

          curwin->w_cursor = cursor_save;

          line = ml_get(outermost.lnum);

          is_if_for_while =
            cin_is_if_for_while_before_offset(line, &outermost.col);
        }

        amount = skip_label(our_paren_pos.lnum, &look);
        look = skipwhite(look);
        if (*look == '(') {
          linenr_T save_lnum = curwin->w_cursor.lnum;
          char_u      *line;
          int look_col;

          /* Ignore a '(' in front of the line that has a match before
           * our matching '('. */
          curwin->w_cursor.lnum = our_paren_pos.lnum;
          line = get_cursor_line_ptr();
          look_col = (int)(look - line);
          curwin->w_cursor.col = look_col + 1;
          if ((trypos = findmatchlimit(NULL, ')', 0,
                   curbuf->b_ind_maxparen))
              != NULL
              && trypos->lnum == our_paren_pos.lnum
              && trypos->col < our_paren_pos.col)
            ignore_paren_col = trypos->col + 1;

          curwin->w_cursor.lnum = save_lnum;
          look = ml_get(our_paren_pos.lnum) + look_col;
        }
        if (theline[0] == ')' || (curbuf->b_ind_unclosed == 0
                                  && is_if_for_while == 0)
            || (!curbuf->b_ind_unclosed_noignore && *look == '('
                && ignore_paren_col == 0)) {
          /*
           * If we're looking at a close paren, line up right there;
           * otherwise, line up with the next (non-white) character.
           * When b_ind_unclosed_wrapped is set and the matching paren is
           * the last nonwhite character of the line, use either the
           * indent of the current line or the indentation of the next
           * outer paren and add b_ind_unclosed_wrapped (for very long
           * lines).
           */
          if (theline[0] != ')') {
            cur_amount = MAXCOL;
            l = ml_get(our_paren_pos.lnum);
            if (curbuf->b_ind_unclosed_wrapped
                && cin_ends_in(l, (char_u *)"(", NULL)) {
              /* look for opening unmatched paren, indent one level
               * for each additional level */
              n = 1;
              for (col = 0; col < our_paren_pos.col; ++col) {
                switch (l[col]) {
                case '(':
                case '{': ++n;
                  break;

                case ')':
                case '}': if (n > 1)
                    --n;
                  break;
                }
              }

              our_paren_pos.col = 0;
              amount += n * curbuf->b_ind_unclosed_wrapped;
            } else if (curbuf->b_ind_unclosed_whiteok)
              our_paren_pos.col++;
            else {
              col = our_paren_pos.col + 1;
              while (ascii_iswhite(l[col]))
                col++;
              if (l[col] != NUL)                /* In case of trailing space */
                our_paren_pos.col = col;
              else
                our_paren_pos.col++;
            }
          }

          /*
           * Find how indented the paren is, or the character after it
           * if we did the above "if".
           */
          if (our_paren_pos.col > 0) {
            getvcol(curwin, &our_paren_pos, &col, NULL, NULL);
            if (cur_amount > (int)col)
              cur_amount = col;
          }
        }

        if (theline[0] == ')' && curbuf->b_ind_matching_paren) {
          /* Line up with the start of the matching paren line. */
        } else if ((curbuf->b_ind_unclosed == 0 && is_if_for_while == 0)
                   || (!curbuf->b_ind_unclosed_noignore
                       && *look == '(' && ignore_paren_col == 0)) {
          if (cur_amount != MAXCOL)
            amount = cur_amount;
        } else {
          /* Add b_ind_unclosed2 for each '(' before our matching one,
           * but ignore (void) before the line (ignore_paren_col). */
          col = our_paren_pos.col;
          while ((int)our_paren_pos.col > ignore_paren_col) {
            --our_paren_pos.col;
            switch (*ml_get_pos(&our_paren_pos)) {
            case '(': amount += curbuf->b_ind_unclosed2;
              col = our_paren_pos.col;
              break;
            case ')': amount -= curbuf->b_ind_unclosed2;
              col = MAXCOL;
              break;
            }
          }

          /* Use b_ind_unclosed once, when the first '(' is not inside
           * braces */
          if (col == MAXCOL)
            amount += curbuf->b_ind_unclosed;
          else {
            curwin->w_cursor.lnum = our_paren_pos.lnum;
            curwin->w_cursor.col = col;
            if (find_match_paren_after_brace(curbuf->b_ind_maxparen)) {
              amount += curbuf->b_ind_unclosed2;
            } else {
              if (is_if_for_while) {
                amount += curbuf->b_ind_if_for_while;
              } else {
                amount += curbuf->b_ind_unclosed;
              }
            }
          }
          /*
           * For a line starting with ')' use the minimum of the two
           * positions, to avoid giving it more indent than the previous
           * lines:
           *  func_long_name(		    if (x
           *	arg				    && yy
           *	)	  ^ not here	       )    ^ not here
           */
          if (cur_amount < amount)
            amount = cur_amount;
        }
      }

      /* add extra indent for a comment */
      if (cin_iscomment(theline))
        amount += curbuf->b_ind_comment;
    } else {
      // We are inside braces, there is a { before this line at the position
      // stored in tryposBrace.
      // Make a copy of tryposBrace, it may point to pos_copy inside
      // find_start_brace(), which may be changed somewhere.
      tryposCopy = *tryposBrace;
      tryposBrace = &tryposCopy;
      trypos = tryposBrace;
      ourscope = trypos->lnum;
      start = ml_get(ourscope);

      /*
       * Now figure out how indented the line is in general.
       * If the brace was at the start of the line, we use that;
       * otherwise, check out the indentation of the line as
       * a whole and then add the "imaginary indent" to that.
       */
      look = skipwhite(start);
      if (*look == '{') {
        getvcol(curwin, trypos, &col, NULL, NULL);
        amount = col;
        if (*start == '{')
          start_brace = BRACE_IN_COL0;
        else
          start_brace = BRACE_AT_START;
      } else {
        // That opening brace might have been on a continuation
        // line.  If so, find the start of the line.
        curwin->w_cursor.lnum = ourscope;

        // Position the cursor over the rightmost paren, so that
        // matching it will take us back to the start of the line.
        lnum = ourscope;
        if (find_last_paren(start, '(', ')')
            && (trypos = find_match_paren(curbuf->b_ind_maxparen)) != NULL) {
          lnum = trypos->lnum;
        }

        // It could have been something like
        //	   case 1: if (asdf &&
        //			ldfd) {
        //		    }
        if ((curbuf->b_ind_js || curbuf->b_ind_keep_case_label)
            && cin_iscase(skipwhite(get_cursor_line_ptr()), FALSE)) {
          amount = get_indent();
        } else if (curbuf->b_ind_js) {
          amount = get_indent_lnum(lnum);
        } else {
          amount = skip_label(lnum, &l);
        }

        start_brace = BRACE_AT_END;
      }

      // For Javascript check if the line starts with "key:".
      bool js_cur_has_key = curbuf->b_ind_js ? cin_has_js_key(theline) : false;

      // If we're looking at a closing brace, that's where
      // we want to be.  Otherwise, add the amount of room
      // that an indent is supposed to be.
      if (theline[0] == '}') {
        /*
         * they may want closing braces to line up with something
         * other than the open brace.  indulge them, if so.
         */
        amount += curbuf->b_ind_close_extra;
      } else {
        /*
         * If we're looking at an "else", try to find an "if"
         * to match it with.
         * If we're looking at a "while", try to find a "do"
         * to match it with.
         */
        lookfor = LOOKFOR_INITIAL;
        if (cin_iselse(theline))
          lookfor = LOOKFOR_IF;
        else if (cin_iswhileofdo(theline, cur_curpos.lnum))     /* XXX */
          lookfor = LOOKFOR_DO;
        if (lookfor != LOOKFOR_INITIAL) {
          curwin->w_cursor.lnum = cur_curpos.lnum;
          if (find_match(lookfor, ourscope) == OK) {
            amount = get_indent();              /* XXX */
            goto theend;
          }
        }

        /*
         * We get here if we are not on an "while-of-do" or "else" (or
         * failed to find a matching "if").
         * Search backwards for something to line up with.
         * First set amount for when we don't find anything.
         */

        /*
         * if the '{' is  _really_ at the left margin, use the imaginary
         * location of a left-margin brace.  Otherwise, correct the
         * location for b_ind_open_extra.
         */

        if (start_brace == BRACE_IN_COL0) {     // '{' is in column 0
          amount = curbuf->b_ind_open_left_imag;
          lookfor_cpp_namespace = true;
        } else if (start_brace == BRACE_AT_START
                   && lookfor_cpp_namespace) {  // '{' is at start
          lookfor_cpp_namespace = true;
        } else {
          if (start_brace == BRACE_AT_END) {    // '{' is at end of line
            amount += curbuf->b_ind_open_imag;

            l = skipwhite(get_cursor_line_ptr());
            if (cin_is_cpp_namespace(l)) {
              amount += curbuf->b_ind_cpp_namespace;
            } else if (cin_is_cpp_extern_c(l)) {
              amount += curbuf->b_ind_cpp_extern_c;
            }
          } else {
            /* Compensate for adding b_ind_open_extra later. */
            amount -= curbuf->b_ind_open_extra;
            if (amount < 0)
              amount = 0;
          }
        }

        lookfor_break = FALSE;

        if (cin_iscase(theline, FALSE)) {       /* it's a switch() label */
          lookfor = LOOKFOR_CASE;       /* find a previous switch() label */
          amount += curbuf->b_ind_case;
        } else if (cin_isscopedecl(theline)) { /* private:, ... */
          lookfor = LOOKFOR_SCOPEDECL;          /* class decl is this block */
          amount += curbuf->b_ind_scopedecl;
        } else {
          if (curbuf->b_ind_case_break && cin_isbreak(theline))
            /* break; ... */
            lookfor_break = TRUE;

          lookfor = LOOKFOR_INITIAL;
          /* b_ind_level from start of block */
          amount += curbuf->b_ind_level;
        }
        scope_amount = amount;
        whilelevel = 0;

        // Search backwards.  If we find something we recognize, line up
        // with that.
        //
        // If we're looking at an open brace, indent
        // the usual amount relative to the conditional
        // that opens the block.
        curwin->w_cursor = cur_curpos;
        for (;; ) {
          curwin->w_cursor.lnum--;
          curwin->w_cursor.col = 0;

          /*
           * If we went all the way back to the start of our scope, line
           * up with it.
           */
          if (curwin->w_cursor.lnum <= ourscope) {
            // We reached end of scope:
            // If looking for a enum or structure initialization
            // go further back:
            // If it is an initializer (enum xxx or xxx =), then
            // don't add ind_continuation, otherwise it is a variable
            // declaration:
            // int x,
            //     here; <-- add ind_continuation
            if (lookfor == LOOKFOR_ENUM_OR_INIT) {
              if (curwin->w_cursor.lnum == 0
                  || curwin->w_cursor.lnum
                  < ourscope - curbuf->b_ind_maxparen) {
                /* nothing found (abuse curbuf->b_ind_maxparen as
                 * limit) assume terminated line (i.e. a variable
                 * initialization) */
                if (cont_amount > 0)
                  amount = cont_amount;
                else if (!curbuf->b_ind_js)
                  amount += ind_continuation;
                break;
              }

              l = get_cursor_line_ptr();

              /*
               * If we're in a comment or raw string now, skip to
               * the start of it.
               */
              trypos = ind_find_start_CORS();
              if (trypos != NULL) {
                curwin->w_cursor.lnum = trypos->lnum + 1;
                curwin->w_cursor.col = 0;
                continue;
              }

              //
              // Skip preprocessor directives and blank lines.
              //
              if (cin_ispreproc_cont(&l, &curwin->w_cursor.lnum, &amount)) {
                continue;
              }

              if (cin_nocode(l))
                continue;

              terminated = cin_isterminated(l, FALSE, TRUE);

              /*
               * If we are at top level and the line looks like a
               * function declaration, we are done
               * (it's a variable declaration).
               */
              if (start_brace != BRACE_IN_COL0
                  || !cin_isfuncdecl(&l, curwin->w_cursor.lnum, 0)) {
                /* if the line is terminated with another ','
                 * it is a continued variable initialization.
                 * don't add extra indent.
                 * TODO: does not work, if  a function
                 * declaration is split over multiple lines:
                 * cin_isfuncdecl returns FALSE then.
                 */
                if (terminated == ',')
                  break;

                /* if it is an enum declaration or an assignment,
                 * we are done.
                 */
                if (terminated != ';' && cin_isinit())
                  break;

                /* nothing useful found */
                if (terminated == 0 || terminated == '{')
                  continue;
              }

              if (terminated != ';') {
                /* Skip parens and braces. Position the cursor
                 * over the rightmost paren, so that matching it
                 * will take us back to the start of the line.
                 */					/* XXX */
                trypos = NULL;
                if (find_last_paren(l, '(', ')'))
                  trypos = find_match_paren(
                      curbuf->b_ind_maxparen);

                if (trypos == NULL && find_last_paren(l, '{', '}'))
                  trypos = find_start_brace();

                if (trypos != NULL) {
                  curwin->w_cursor.lnum = trypos->lnum + 1;
                  curwin->w_cursor.col = 0;
                  continue;
                }
              }

              /* it's a variable declaration, add indentation
               * like in
               * int a,
               *    b;
               */
              if (cont_amount > 0)
                amount = cont_amount;
              else
                amount += ind_continuation;
            } else if (lookfor == LOOKFOR_UNTERM) {
              if (cont_amount > 0)
                amount = cont_amount;
              else
                amount += ind_continuation;
            } else {
              if (lookfor != LOOKFOR_TERM
                  && lookfor != LOOKFOR_CPP_BASECLASS
                  && lookfor != LOOKFOR_COMMA) {
                amount = scope_amount;
                if (theline[0] == '{') {
                  amount += curbuf->b_ind_open_extra;
                  added_to_amount = curbuf->b_ind_open_extra;
                }
              }

              if (lookfor_cpp_namespace) {
                /*
                 * Looking for C++ namespace, need to look further
                 * back.
                 */
                if (curwin->w_cursor.lnum == ourscope)
                  continue;

                if (curwin->w_cursor.lnum == 0
                    || curwin->w_cursor.lnum
                    < ourscope - FIND_NAMESPACE_LIM)
                  break;

                l = get_cursor_line_ptr();

                /* If we're in a comment or raw string now, skip
                 * to the start of it. */
                trypos = ind_find_start_CORS();
                if (trypos != NULL) {
                  curwin->w_cursor.lnum = trypos->lnum + 1;
                  curwin->w_cursor.col = 0;
                  continue;
                }

                // Skip preprocessor directives and blank lines.
                if (cin_ispreproc_cont(&l, &curwin->w_cursor.lnum, &amount)) {
                  continue;
                }

                /* Finally the actual check for "namespace". */
                if (cin_is_cpp_namespace(l)) {
                  amount += curbuf->b_ind_cpp_namespace
                            - added_to_amount;
                  break;
                } else if (cin_is_cpp_extern_c(l)) {
                  amount += curbuf->b_ind_cpp_extern_c - added_to_amount;
                  break;
                }

                if (cin_nocode(l))
                  continue;
              }
            }
            break;
          }

          /*
           * If we're in a comment or raw string now, skip to the start
           * of it.
           */					    /* XXX */
          if ((trypos = ind_find_start_CORS()) != NULL) {
            curwin->w_cursor.lnum = trypos->lnum + 1;
            curwin->w_cursor.col = 0;
            continue;
          }

          l = get_cursor_line_ptr();

          /*
           * If this is a switch() label, may line up relative to that.
           * If this is a C++ scope declaration, do the same.
           */
          iscase = cin_iscase(l, FALSE);
          if (iscase || cin_isscopedecl(l)) {
            /* we are only looking for cpp base class
             * declaration/initialization any longer */
            if (lookfor == LOOKFOR_CPP_BASECLASS)
              break;

            /* When looking for a "do" we are not interested in
             * labels. */
            if (whilelevel > 0)
              continue;

            /*
             *	case xx:
             *	    c = 99 +	    <- this indent plus continuation
             **->	   here;
             */
            if (lookfor == LOOKFOR_UNTERM
                || lookfor == LOOKFOR_ENUM_OR_INIT) {
              if (cont_amount > 0)
                amount = cont_amount;
              else
                amount += ind_continuation;
              break;
            }

            /*
             *	case xx:	<- line up with this case
             *	    x = 333;
             *	case yy:
             */
            if (       (iscase && lookfor == LOOKFOR_CASE)
                       || (iscase && lookfor_break)
                       || (!iscase && lookfor == LOOKFOR_SCOPEDECL)) {
              /*
               * Check that this case label is not for another
               * switch()
               */				    /* XXX */
              if ((trypos = find_start_brace()) == NULL
                  || trypos->lnum == ourscope) {
                amount = get_indent();                  /* XXX */
                break;
              }
              continue;
            }

            n = get_indent_nolabel(curwin->w_cursor.lnum);          /* XXX */

            /*
             *	 case xx: if (cond)	    <- line up with this if
             *		      y = y + 1;
             * ->	  s = 99;
             *
             *	 case xx:
             *	     if (cond)		<- line up with this line
             *		 y = y + 1;
             * ->    s = 99;
             */
            if (lookfor == LOOKFOR_TERM) {
              if (n)
                amount = n;

              if (!lookfor_break)
                break;
            }

            /*
             *	 case xx: x = x + 1;	    <- line up with this x
             * ->	  y = y + 1;
             *
             *	 case xx: if (cond)	    <- line up with this if
             * ->	       y = y + 1;
             */
            if (n) {
              amount = n;
              l = after_label(get_cursor_line_ptr());
              if (l != NULL && cin_is_cinword(l)) {
                if (theline[0] == '{')
                  amount += curbuf->b_ind_open_extra;
                else
                  amount += curbuf->b_ind_level
                            + curbuf->b_ind_no_brace;
              }
              break;
            }

            /*
             * Try to get the indent of a statement before the switch
             * label.  If nothing is found, line up relative to the
             * switch label.
             *	    break;		<- may line up with this line
             *	 case xx:
             * ->   y = 1;
             */
            scope_amount = get_indent() + (iscase            /* XXX */
                                           ? curbuf->b_ind_case_code
                                           : curbuf->b_ind_scopedecl_code);
            lookfor = curbuf->b_ind_case_break
                      ? LOOKFOR_NOBREAK : LOOKFOR_ANY;
            continue;
          }

          /*
           * Looking for a switch() label or C++ scope declaration,
           * ignore other lines, skip {}-blocks.
           */
          if (lookfor == LOOKFOR_CASE || lookfor == LOOKFOR_SCOPEDECL) {
            if (find_last_paren(l, '{', '}')
                && (trypos = find_start_brace()) != NULL) {
              curwin->w_cursor.lnum = trypos->lnum + 1;
              curwin->w_cursor.col = 0;
            }
            continue;
          }

          /*
           * Ignore jump labels with nothing after them.
           */
          if (!curbuf->b_ind_js && cin_islabel()) {
            l = after_label(get_cursor_line_ptr());
            if (l == NULL || cin_nocode(l))
              continue;
          }

          /*
           * Ignore #defines, #if, etc.
           * Ignore comment and empty lines.
           * (need to get the line again, cin_islabel() may have
           * unlocked it)
           */
          l = get_cursor_line_ptr();
          if (cin_ispreproc_cont(&l, &curwin->w_cursor.lnum, &amount)
              || cin_nocode(l)) {
            continue;
          }

          /*
           * Are we at the start of a cpp base class declaration or
           * constructor initialization?
           */						    /* XXX */
          n = FALSE;
          if (lookfor != LOOKFOR_TERM && curbuf->b_ind_cpp_baseclass > 0) {
            n = cin_is_cpp_baseclass(&cache_cpp_baseclass);
            l = get_cursor_line_ptr();
          }
          if (n) {
            if (lookfor == LOOKFOR_UNTERM) {
              if (cont_amount > 0)
                amount = cont_amount;
              else
                amount += ind_continuation;
            } else if (theline[0] == '{') {
              /* Need to find start of the declaration. */
              lookfor = LOOKFOR_UNTERM;
              ind_continuation = 0;
              continue;
            } else
              /* XXX */
              amount = get_baseclass_amount(cache_cpp_baseclass.lpos.col);
            break;
          } else if (lookfor == LOOKFOR_CPP_BASECLASS) {
            /* only look, whether there is a cpp base class
             * declaration or initialization before the opening brace.
             */
            if (cin_isterminated(l, TRUE, FALSE))
              break;
            else
              continue;
          }

          /*
           * What happens next depends on the line being terminated.
           * If terminated with a ',' only consider it terminating if
           * there is another unterminated statement behind, eg:
           *   123,
           *   sizeof
           *	  here
           * Otherwise check whether it is an enumeration or structure
           * initialisation (not indented) or a variable declaration
           * (indented).
           */
          terminated = cin_isterminated(l, FALSE, TRUE);

          if (js_cur_has_key) {
            js_cur_has_key = false; // only check the first line
            if (curbuf->b_ind_js && terminated == ',') {
              // For Javascript we might be inside an object:
              //   key: something,  <- align with this
              //   key: something
              // or:
              //   key: something +  <- align with this
              //       something,
              //   key: something
              lookfor = LOOKFOR_JS_KEY;
            }
          }
          if (lookfor == LOOKFOR_JS_KEY && cin_has_js_key(l)) {
            amount = get_indent();
            break;
          }
          if (lookfor == LOOKFOR_COMMA) {
            if (tryposBrace != NULL && tryposBrace->lnum
                >= curwin->w_cursor.lnum) {
              break;
            }
            if (terminated == ',') {
              // Line below current line is the one that starts a
              // (possibly broken) line ending in a comma.
              break;
            } else {
              amount = get_indent();
              if (curwin->w_cursor.lnum - 1 == ourscope) {
                // line above is start of the scope, thus current
                // line is the one that stars a (possibly broken)
                // line ending in a comma.
                break;
              }
            }
          }

          if (terminated == 0 || (lookfor != LOOKFOR_UNTERM
                                  && terminated == ',')) {
            if (lookfor != LOOKFOR_ENUM_OR_INIT
                && (*skipwhite(l) == '[' || l[STRLEN(l) - 1] == '[')) {
              amount += ind_continuation;
            }
            // If we're in the middle of a paren thing, Go back to the line
            // that starts it so we can get the right prevailing indent
            //	   if ( foo &&
            //		    bar )

            // Position the cursor over the rightmost paren, so that
            // matching it will take us back to the start of the line.
            // Ignore a match before the start of the block.
            (void)find_last_paren(l, '(', ')');
            trypos = find_match_paren(corr_ind_maxparen(&cur_curpos));
            if (trypos != NULL && (trypos->lnum < tryposBrace->lnum
                                   || (trypos->lnum == tryposBrace->lnum
                                       && trypos->col < tryposBrace->col))) {
              trypos = NULL;
            }

            // If we are looking for ',', we also look for matching
            // braces.
            if (trypos == NULL && terminated == ','
                && find_last_paren(l, '{', '}'))
              trypos = find_start_brace();

            if (trypos != NULL) {
              /*
               * Check if we are on a case label now.  This is
               * handled above.
               *     case xx:  if ( asdf &&
               *			asdf)
               */
              curwin->w_cursor = *trypos;
              l = get_cursor_line_ptr();
              if (cin_iscase(l, FALSE) || cin_isscopedecl(l)) {
                ++curwin->w_cursor.lnum;
                curwin->w_cursor.col = 0;
                continue;
              }
            }

            /*
             * Skip over continuation lines to find the one to get the
             * indent from
             * char *usethis = "bla\
             *		 bla",
             *      here;
             */
            if (terminated == ',') {
              while (curwin->w_cursor.lnum > 1) {
                l = ml_get(curwin->w_cursor.lnum - 1);
                if (*l == NUL || l[STRLEN(l) - 1] != '\\')
                  break;
                --curwin->w_cursor.lnum;
                curwin->w_cursor.col = 0;
              }
            }

            /*
             * Get indent and pointer to text for current line,
             * ignoring any jump label.	    XXX
             */
            if (curbuf->b_ind_js) {
              cur_amount = get_indent();
            } else {
              cur_amount = skip_label(curwin->w_cursor.lnum, &l);
            }
            /*
             * If this is just above the line we are indenting, and it
             * starts with a '{', line it up with this line.
             *		while (not)
             * ->	{
             *		}
             */
            if (terminated != ',' && lookfor != LOOKFOR_TERM
                && theline[0] == '{') {
              amount = cur_amount;
              /*
               * Only add b_ind_open_extra when the current line
               * doesn't start with a '{', which must have a match
               * in the same line (scope is the same).  Probably:
               *	{ 1, 2 },
               * ->	{ 3, 4 }
               */
              if (*skipwhite(l) != '{')
                amount += curbuf->b_ind_open_extra;

              if (curbuf->b_ind_cpp_baseclass && !curbuf->b_ind_js) {
                /* have to look back, whether it is a cpp base
                 * class declaration or initialization */
                lookfor = LOOKFOR_CPP_BASECLASS;
                continue;
              }
              break;
            }

            /*
             * Check if we are after an "if", "while", etc.
             * Also allow "   } else".
             */
            if (cin_is_cinword(l) || cin_iselse(skipwhite(l))) {
              /*
               * Found an unterminated line after an if (), line up
               * with the last one.
               *   if (cond)
               *	    100 +
               * ->		here;
               */
              if (lookfor == LOOKFOR_UNTERM
                  || lookfor == LOOKFOR_ENUM_OR_INIT) {
                if (cont_amount > 0)
                  amount = cont_amount;
                else
                  amount += ind_continuation;
                break;
              }

              /*
               * If this is just above the line we are indenting, we
               * are finished.
               *	    while (not)
               * ->		here;
               * Otherwise this indent can be used when the line
               * before this is terminated.
               *	yyy;
               *	if (stat)
               *	    while (not)
               *		xxx;
               * ->	here;
               */
              amount = cur_amount;
              if (theline[0] == '{')
                amount += curbuf->b_ind_open_extra;
              if (lookfor != LOOKFOR_TERM) {
                amount += curbuf->b_ind_level
                          + curbuf->b_ind_no_brace;
                break;
              }

              /*
               * Special trick: when expecting the while () after a
               * do, line up with the while()
               *     do
               *	    x = 1;
               * ->  here
               */
              l = skipwhite(get_cursor_line_ptr());
              if (cin_isdo(l)) {
                if (whilelevel == 0)
                  break;
                --whilelevel;
              }

              /*
               * When searching for a terminated line, don't use the
               * one between the "if" and the matching "else".
               * Need to use the scope of this "else".  XXX
               * If whilelevel != 0 continue looking for a "do {".
               */
              if (cin_iselse(l) && whilelevel == 0) {
                /* If we're looking at "} else", let's make sure we
                 * find the opening brace of the enclosing scope,
                 * not the one from "if () {". */
                if (*l == '}')
                  curwin->w_cursor.col =
                    (colnr_T)(l - get_cursor_line_ptr()) + 1;

                if ((trypos = find_start_brace()) == NULL
                    || find_match(LOOKFOR_IF, trypos->lnum)
                    == FAIL)
                  break;
              }
            }
            /*
             * If we're below an unterminated line that is not an
             * "if" or something, we may line up with this line or
             * add something for a continuation line, depending on
             * the line before this one.
             */
            else {
              /*
               * Found two unterminated lines on a row, line up with
               * the last one.
               *   c = 99 +
               *	    100 +
               * ->	    here;
               */
              if (lookfor == LOOKFOR_UNTERM) {
                /* When line ends in a comma add extra indent */
                if (terminated == ',')
                  amount += ind_continuation;
                break;
              }

              if (lookfor == LOOKFOR_ENUM_OR_INIT) {
                /* Found two lines ending in ',', lineup with the
                 * lowest one, but check for cpp base class
                 * declaration/initialization, if it is an
                 * opening brace or we are looking just for
                 * enumerations/initializations. */
                if (terminated == ',') {
                  if (curbuf->b_ind_cpp_baseclass == 0)
                    break;

                  lookfor = LOOKFOR_CPP_BASECLASS;
                  continue;
                }

                // Ignore unterminated lines in between, but
                // reduce indent.
                if (amount > cur_amount) {
                  amount = cur_amount;
                }
              } else {
                // Found first unterminated line on a row, may
                // line up with this line, remember its indent
                // 	    100 +  //  NOLINT(whitespace/tab)
                // ->	    here;  //  NOLINT(whitespace/tab)
                l = get_cursor_line_ptr();
                amount = cur_amount;

                n = (int)STRLEN(l);
                if (terminated == ','
                    && (*skipwhite(l) == ']'
                        || (n >=2 && l[n - 2] == ']'))) {
                  break;
                }

                // If previous line ends in ',', check whether we
                // are in an initialization or enum
                // struct xxx =
                // {
                //      sizeof a,
                //      124 };
                // or a normal possible continuation line.
                // but only, of no other statement has been found
                // yet.
                if (lookfor == LOOKFOR_INITIAL && terminated == ',') {
                  if (curbuf->b_ind_js) {
                    // Search for a line ending in a comma
                    // and line up with the line below it
                    // (could be the current line).
                    // some = [
                    //     1,     <- line up here
                    //     2,
                    // some = [
                    //     3 +    <- line up here
                    //       4 *
                    //        5,
                    //     6,
                    if (cin_iscomment(skipwhite(l))) {
                      break;
                    }
                    lookfor = LOOKFOR_COMMA;
                    trypos = find_match_char('[', curbuf->b_ind_maxparen);
                    if (trypos != NULL) {
                      if (trypos->lnum == curwin->w_cursor.lnum - 1) {
                        // Current line is first inside
                        // [], line up with it.
                        break;
                      }
                      ourscope = trypos->lnum;
                    }
                  } else {
                    lookfor = LOOKFOR_ENUM_OR_INIT;
                    cont_amount = cin_first_id_amount();
                  }
                } else {
                  if (lookfor == LOOKFOR_INITIAL
                      && *l != NUL
                      && l[STRLEN(l) - 1] == '\\') {
                    // XXX
                    cont_amount = cin_get_equal_amount( curwin->w_cursor.lnum);
                  }
                  if (lookfor != LOOKFOR_TERM
                      && lookfor != LOOKFOR_JS_KEY
                      && lookfor != LOOKFOR_COMMA) {
                    lookfor = LOOKFOR_UNTERM;
                  }
                }
              }
            }
          }
          /*
           * Check if we are after a while (cond);
           * If so: Ignore until the matching "do".
           */
          else if (cin_iswhileofdo_end(terminated)) {  // XXX
            /*
             * Found an unterminated line after a while ();, line up
             * with the last one.
             *	    while (cond);
             *	    100 +		<- line up with this one
             * ->	    here;
             */
            if (lookfor == LOOKFOR_UNTERM
                || lookfor == LOOKFOR_ENUM_OR_INIT) {
              if (cont_amount > 0)
                amount = cont_amount;
              else
                amount += ind_continuation;
              break;
            }

            if (whilelevel == 0) {
              lookfor = LOOKFOR_TERM;
              amount = get_indent();                /* XXX */
              if (theline[0] == '{')
                amount += curbuf->b_ind_open_extra;
            }
            ++whilelevel;
          }
          /*
           * We are after a "normal" statement.
           * If we had another statement we can stop now and use the
           * indent of that other statement.
           * Otherwise the indent of the current statement may be used,
           * search backwards for the next "normal" statement.
           */
          else {
            /*
             * Skip single break line, if before a switch label. It
             * may be lined up with the case label.
             */
            if (lookfor == LOOKFOR_NOBREAK
                && cin_isbreak(skipwhite(get_cursor_line_ptr()))) {
              lookfor = LOOKFOR_ANY;
              continue;
            }

            /*
             * Handle "do {" line.
             */
            if (whilelevel > 0) {
              l = cin_skipcomment(get_cursor_line_ptr());
              if (cin_isdo(l)) {
                amount = get_indent();                  /* XXX */
                --whilelevel;
                continue;
              }
            }

            /*
             * Found a terminated line above an unterminated line. Add
             * the amount for a continuation line.
             *	 x = 1;
             *	 y = foo +
             * ->	here;
             * or
             *	 int x = 1;
             *	 int foo,
             * ->	here;
             */
            if (lookfor == LOOKFOR_UNTERM
                || lookfor == LOOKFOR_ENUM_OR_INIT) {
              if (cont_amount > 0)
                amount = cont_amount;
              else
                amount += ind_continuation;
              break;
            }

            /*
             * Found a terminated line above a terminated line or "if"
             * etc. line. Use the amount of the line below us.
             *	 x = 1;				x = 1;
             *	 if (asdf)		    y = 2;
             *	     while (asdf)	  ->here;
             *		here;
             * ->foo;
             */
            if (lookfor == LOOKFOR_TERM) {
              if (!lookfor_break && whilelevel == 0)
                break;
            }
            /*
             * First line above the one we're indenting is terminated.
             * To know what needs to be done look further backward for
             * a terminated line.
             */
            else {
              /*
               * position the cursor over the rightmost paren, so
               * that matching it will take us back to the start of
               * the line.  Helps for:
               *     func(asdr,
               *	      asdfasdf);
               *     here;
               */
term_again:
              l = get_cursor_line_ptr();
              if (find_last_paren(l, '(', ')')
                  && (trypos = find_match_paren(
                          curbuf->b_ind_maxparen)) != NULL) {
                /*
                 * Check if we are on a case label now.  This is
                 * handled above.
                 *	   case xx:  if ( asdf &&
                 *			    asdf)
                 */
                curwin->w_cursor = *trypos;
                l = get_cursor_line_ptr();
                if (cin_iscase(l, FALSE) || cin_isscopedecl(l)) {
                  ++curwin->w_cursor.lnum;
                  curwin->w_cursor.col = 0;
                  continue;
                }
              }

              /* When aligning with the case statement, don't align
               * with a statement after it.
               *  case 1: {   <-- don't use this { position
               *	stat;
               *  }
               *  case 2:
               *	stat;
               * }
               */
              iscase = (curbuf->b_ind_keep_case_label
                        && cin_iscase(l, FALSE));

              /*
               * Get indent and pointer to text for current line,
               * ignoring any jump label.
               */
              amount = skip_label(curwin->w_cursor.lnum, &l);

              if (theline[0] == '{')
                amount += curbuf->b_ind_open_extra;
              /* See remark above: "Only add b_ind_open_extra.." */
              l = skipwhite(l);
              if (*l == '{')
                amount -= curbuf->b_ind_open_extra;
              lookfor = iscase ? LOOKFOR_ANY : LOOKFOR_TERM;

              /*
               * When a terminated line starts with "else" skip to
               * the matching "if":
               *       else 3;
               *	     indent this;
               * Need to use the scope of this "else".  XXX
               * If whilelevel != 0 continue looking for a "do {".
               */
              if (lookfor == LOOKFOR_TERM
                  && *l != '}'
                  && cin_iselse(l)
                  && whilelevel == 0) {
                if ((trypos = find_start_brace()) == NULL
                    || find_match(LOOKFOR_IF, trypos->lnum)
                    == FAIL)
                  break;
                continue;
              }

              /*
               * If we're at the end of a block, skip to the start of
               * that block.
               */
              l = get_cursor_line_ptr();
              if (find_last_paren(l, '{', '}')           /* XXX */
                  && (trypos = find_start_brace()) != NULL) {
                curwin->w_cursor = *trypos;
                /* if not "else {" check for terminated again */
                /* but skip block for "} else {" */
                l = cin_skipcomment(get_cursor_line_ptr());
                if (*l == '}' || !cin_iselse(l))
                  goto term_again;
                ++curwin->w_cursor.lnum;
                curwin->w_cursor.col = 0;
              }
            }
          }
        }
      }
    }

    /* add extra indent for a comment */
    if (cin_iscomment(theline))
      amount += curbuf->b_ind_comment;

    /* subtract extra left-shift for jump labels */
    if (curbuf->b_ind_jump_label > 0 && original_line_islabel)
      amount -= curbuf->b_ind_jump_label;

    goto theend;
  }

  // Ok -- we're not inside any sort of structure at all!
  //
  // this means we're at the top level, and everything should
  // basically just match where the previous line is, except
  // for the lines immediately following a function declaration,
  // which are K&R-style parameters and need to be indented.

  // if our line starts with an open brace, forget about any
  // prevailing indent and make sure it looks like the start
  // of a function

  if (theline[0] == '{') {
      amount = curbuf->b_ind_first_open;
      goto theend;
  }
  /*
   * If the NEXT line is a function declaration, the current
   * line needs to be indented as a function type spec.
   * Don't do this if the current line looks like a comment or if the
   * current line is terminated, ie. ends in ';', or if the current line
   * contains { or }: "void f() {\n if (1)"
   */
  if (cur_curpos.lnum < curbuf->b_ml.ml_line_count
          && !cin_nocode(theline)
          && vim_strchr(theline, '{') == NULL
          && vim_strchr(theline, '}') == NULL
          && !cin_ends_in(theline, (char_u *)":", NULL)
          && !cin_ends_in(theline, (char_u *)",", NULL)
          && cin_isfuncdecl(NULL, cur_curpos.lnum + 1,
              cur_curpos.lnum + 1)
          && !cin_isterminated(theline, false, true)) {
    amount = curbuf->b_ind_func_type;
    goto theend;
  }

  /* search backwards until we find something we recognize */
  amount = 0;
  curwin->w_cursor = cur_curpos;
  while (curwin->w_cursor.lnum > 1) {
    curwin->w_cursor.lnum--;
    curwin->w_cursor.col = 0;

    l = get_cursor_line_ptr();

    /*
     * If we're in a comment or raw string now, skip to the start
     * of it.
     */						/* XXX */
    if ((trypos = ind_find_start_CORS()) != NULL) {
      curwin->w_cursor.lnum = trypos->lnum + 1;
      curwin->w_cursor.col = 0;
      continue;
    }

    /*
     * Are we at the start of a cpp base class declaration or
     * constructor initialization?
     */						    /* XXX */
    n = false;
    if (curbuf->b_ind_cpp_baseclass != 0 && theline[0] != '{') {
      n = cin_is_cpp_baseclass(&cache_cpp_baseclass);
      l = get_cursor_line_ptr();
    }
    if (n) {
      /* XXX */
      amount = get_baseclass_amount(cache_cpp_baseclass.lpos.col);
      break;
    }

    //
    // Skip preprocessor directives and blank lines.
    //
    if (cin_ispreproc_cont(&l, &curwin->w_cursor.lnum, &amount)) {
      continue;
    }

    if (cin_nocode(l))
      continue;

    /*
     * If the previous line ends in ',', use one level of
     * indentation:
     * int foo,
     *     bar;
     * do this before checking for '}' in case of eg.
     * enum foobar
     * {
     *   ...
     * } foo,
     *   bar;
     */
    n = 0;
    if (cin_ends_in(l, (char_u *)",", NULL)
        || (*l != NUL && (n = l[STRLEN(l) - 1]) == '\\')) {
      /* take us back to opening paren */
      if (find_last_paren(l, '(', ')')
          && (trypos = find_match_paren(
              curbuf->b_ind_maxparen)) != NULL)
        curwin->w_cursor = *trypos;

      /* For a line ending in ',' that is a continuation line go
       * back to the first line with a backslash:
       * char *foo = "bla\
       *		 bla",
       *      here;
       */
      while (n == 0 && curwin->w_cursor.lnum > 1) {
        l = ml_get(curwin->w_cursor.lnum - 1);
        if (*l == NUL || l[STRLEN(l) - 1] != '\\')
          break;
        --curwin->w_cursor.lnum;
        curwin->w_cursor.col = 0;
      }

      amount = get_indent();                    /* XXX */

      if (amount == 0)
        amount = cin_first_id_amount();
      if (amount == 0)
        amount = ind_continuation;
      break;
    }

    /*
     * If the line looks like a function declaration, and we're
     * not in a comment, put it the left margin.
     */
    if (cin_isfuncdecl(NULL, cur_curpos.lnum, 0))          /* XXX */
      break;
    l = get_cursor_line_ptr();

    /*
     * Finding the closing '}' of a previous function.  Put
     * current line at the left margin.  For when 'cino' has "fs".
     */
    if (*skipwhite(l) == '}')
      break;

    /*			    (matching {)
     * If the previous line ends on '};' (maybe followed by
     * comments) align at column 0.  For example:
     * char *string_array[] = { "foo",
     *     / * x * / "b};ar" }; / * foobar * /
     */
    if (cin_ends_in(l, (char_u *)"};", NULL))
      break;

    // If the previous line ends on '[' we are probably in an
    // array constant:
    // something = [
    //     234,  <- extra indent
    if (cin_ends_in(l, (char_u *)"[", NULL)) {
      amount = get_indent() + ind_continuation;
      break;
    }

    /*
     * Find a line only has a semicolon that belongs to a previous
     * line ending in '}', e.g. before an #endif.  Don't increase
     * indent then.
     */
    if (*(look = skipwhite(l)) == ';' && cin_nocode(look + 1)) {
      pos_T curpos_save = curwin->w_cursor;

      while (curwin->w_cursor.lnum > 1) {
        look = ml_get(--curwin->w_cursor.lnum);
        if (!(cin_nocode(look)
              || cin_ispreproc_cont(&look, &curwin->w_cursor.lnum, &amount))) {
          break;
        }
      }
      if (curwin->w_cursor.lnum > 0
          && cin_ends_in(look, (char_u *)"}", NULL))
        break;

      curwin->w_cursor = curpos_save;
    }

    /*
     * If the PREVIOUS line is a function declaration, the current
     * line (and the ones that follow) needs to be indented as
     * parameters.
     */
    if (cin_isfuncdecl(&l, curwin->w_cursor.lnum, 0)) {
      amount = curbuf->b_ind_param;
      break;
    }

    /*
     * If the previous line ends in ';' and the line before the
     * previous line ends in ',' or '\', ident to column zero:
     * int foo,
     *     bar;
     * indent_to_0 here;
     */
    if (cin_ends_in(l, (char_u *)";", NULL)) {
      l = ml_get(curwin->w_cursor.lnum - 1);
      if (cin_ends_in(l, (char_u *)",", NULL)
          || (*l != NUL && l[STRLEN(l) - 1] == '\\'))
        break;
      l = get_cursor_line_ptr();
    }

    /*
     * Doesn't look like anything interesting -- so just
     * use the indent of this line.
     *
     * Position the cursor over the rightmost paren, so that
     * matching it will take us back to the start of the line.
     */
    find_last_paren(l, '(', ')');

    if ((trypos = find_match_paren(curbuf->b_ind_maxparen)) != NULL)
      curwin->w_cursor = *trypos;
    amount = get_indent();              /* XXX */
    break;
  }

  /* add extra indent for a comment */
  if (cin_iscomment(theline))
    amount += curbuf->b_ind_comment;

  /* add extra indent if the previous line ended in a backslash:
   *	      "asdfasdf\
   *		  here";
   *	    char *foo = "asdf\
   *			 here";
   */
  if (cur_curpos.lnum > 1) {
    l = ml_get(cur_curpos.lnum - 1);
    if (*l != NUL && l[STRLEN(l) - 1] == '\\') {
      cur_amount = cin_get_equal_amount(cur_curpos.lnum - 1);
      if (cur_amount > 0)
        amount = cur_amount;
      else if (cur_amount == 0)
        amount += ind_continuation;
    }
  }

theend:
  if (amount < 0)
    amount = 0;

laterend:
  /* put the cursor back where it belongs */
  curwin->w_cursor = cur_curpos;

  xfree(linecopy);

  return amount;
}

static int find_match(int lookfor, linenr_T ourscope)
{
  char_u      *look;
  pos_T       *theirscope;
  char_u      *mightbeif;
  int elselevel;
  int whilelevel;

  if (lookfor == LOOKFOR_IF) {
    elselevel = 1;
    whilelevel = 0;
  } else {
    elselevel = 0;
    whilelevel = 1;
  }

  curwin->w_cursor.col = 0;

  while (curwin->w_cursor.lnum > ourscope + 1) {
    curwin->w_cursor.lnum--;
    curwin->w_cursor.col = 0;

    look = cin_skipcomment(get_cursor_line_ptr());
    if (!cin_iselse(look)
        && !cin_isif(look)
        && !cin_isdo(look)                                   /* XXX */
        && !cin_iswhileofdo(look, curwin->w_cursor.lnum)) {
      continue;
    }

    /*
     * if we've gone outside the braces entirely,
     * we must be out of scope...
     */
    theirscope = find_start_brace();        /* XXX */
    if (theirscope == NULL)
      break;

    /*
     * and if the brace enclosing this is further
     * back than the one enclosing the else, we're
     * out of luck too.
     */
    if (theirscope->lnum < ourscope)
      break;

    /*
     * and if they're enclosed in a *deeper* brace,
     * then we can ignore it because it's in a
     * different scope...
     */
    if (theirscope->lnum > ourscope)
      continue;

    /*
     * if it was an "else" (that's not an "else if")
     * then we need to go back to another if, so
     * increment elselevel
     */
    look = cin_skipcomment(get_cursor_line_ptr());
    if (cin_iselse(look)) {
      mightbeif = cin_skipcomment(look + 4);
      if (!cin_isif(mightbeif))
        ++elselevel;
      continue;
    }

    /*
     * if it was a "while" then we need to go back to
     * another "do", so increment whilelevel.  XXX
     */
    if (cin_iswhileofdo(look, curwin->w_cursor.lnum)) {
      ++whilelevel;
      continue;
    }

    /* If it's an "if" decrement elselevel */
    look = cin_skipcomment(get_cursor_line_ptr());
    if (cin_isif(look)) {
      elselevel--;
      /*
       * When looking for an "if" ignore "while"s that
       * get in the way.
       */
      if (elselevel == 0 && lookfor == LOOKFOR_IF)
        whilelevel = 0;
    }

    /* If it's a "do" decrement whilelevel */
    if (cin_isdo(look))
      whilelevel--;

    /*
     * if we've used up all the elses, then
     * this must be the if that we want!
     * match the indent level of that if.
     */
    if (elselevel <= 0 && whilelevel <= 0) {
      return OK;
    }
  }
  return FAIL;
}

/*
 * Do C or expression indenting on the current line.
 */
void do_c_expr_indent(void)
{
  if (*curbuf->b_p_inde != NUL)
    fixthisline(get_expr_indent);
  else
    fixthisline(get_c_indent);
}
