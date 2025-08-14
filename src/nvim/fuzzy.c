// fuzzy.c: fuzzy matching algorithm and related functions
//
// Portions of this file are adapted from fzy (https://github.com/jhawthorn/fzy)
// Original code:
//   Copyright (c) 2014 John Hawthorn
//   Licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#include <assert.h>
#include <limits.h>
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/charset.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/fuzzy.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/globals.h"
#include "nvim/insexpand.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"

typedef double score_t;

#define SCORE_MAX INFINITY
#define SCORE_MIN (-INFINITY)
#define SCORE_SCALE 1000

typedef struct {
  int idx;  ///< used for stable sort
  listitem_T *item;
  int score;
  list_T *lmatchpos;
  char *pat;
  char *itemstr;
  bool itemstr_allocated;
  int startpos;
} fuzzyItem_T;

typedef struct match_struct match_struct;

#include "fuzzy.c.generated.h"

/// fuzzy_match()
///
/// @return true if "pat_arg" matches "str". Also returns the match score in
/// "outScore" and the matching character positions in "matches".
bool fuzzy_match(char *const str, const char *const pat_arg, const bool matchseq,
                 int *const outScore, uint32_t *const matches, const int maxMatches)
  FUNC_ATTR_NONNULL_ALL
{
  bool complete = false;
  int numMatches = 0;

  *outScore = 0;

  char *const save_pat = xstrdup(pat_arg);
  char *pat = save_pat;
  char *p = pat;

  // Try matching each word in "pat_arg" in "str"
  while (true) {
    if (matchseq) {
      complete = true;
    } else {
      // Extract one word from the pattern (separated by space)
      p = skipwhite(p);
      if (*p == NUL) {
        break;
      }
      pat = p;
      while (*p != NUL && !ascii_iswhite(utf_ptr2char(p))) {
        MB_PTR_ADV(p);
      }
      if (*p == NUL) {  // processed all the words
        complete = true;
      }
      *p = NUL;
    }

    int score = FUZZY_SCORE_NONE;
    if (has_match(pat, str)) {
      score_t fzy_score = match_positions(pat, str, matches + numMatches);
      score = (fzy_score == (score_t)SCORE_MIN
               ? INT_MIN + 1
               : (fzy_score == (score_t)SCORE_MAX
                  ? INT_MAX
                  : (fzy_score < 0
                     ? (int)ceil(fzy_score * SCORE_SCALE - 0.5)
                     : (int)floor(fzy_score * SCORE_SCALE + 0.5))));
    }

    if (score == FUZZY_SCORE_NONE) {
      numMatches = 0;
      *outScore = FUZZY_SCORE_NONE;
      break;
    }

    if (score > 0 && *outScore > INT_MAX - score) {
      *outScore = INT_MAX;
    } else if (score < 0 && *outScore < INT_MIN + 1 - score) {
      *outScore = INT_MIN + 1;
    } else {
      *outScore += score;
    }

    numMatches += mb_charlen(pat);

    if (complete || numMatches >= maxMatches) {
      break;
    }

    // try matching the next word
    p++;
  }

  xfree(save_pat);
  return numMatches != 0;
}

/// Sort the fuzzy matches in the descending order of the match score.
/// For items with same score, retain the order using the index (stable sort)
static int fuzzy_match_item_compare(const void *const s1, const void *const s2)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  const int v1 = ((const fuzzyItem_T *)s1)->score;
  const int v2 = ((const fuzzyItem_T *)s2)->score;

  if (v1 == v2) {
    const char *const pat = ((const fuzzyItem_T *)s1)->pat;
    const size_t patlen = strlen(pat);
    int startpos = ((const fuzzyItem_T *)s1)->startpos;
    const bool exact_match1 = startpos >= 0
                              && strncmp(pat, ((fuzzyItem_T *)s1)->itemstr + startpos, patlen) == 0;
    startpos = ((const fuzzyItem_T *)s2)->startpos;
    const bool exact_match2 = startpos >= 0
                              && strncmp(pat, ((fuzzyItem_T *)s2)->itemstr + startpos, patlen) == 0;

    if (exact_match1 == exact_match2) {
      const int idx1 = ((const fuzzyItem_T *)s1)->idx;
      const int idx2 = ((const fuzzyItem_T *)s2)->idx;
      return idx1 == idx2 ? 0 : idx1 > idx2 ? 1 : -1;
    } else if (exact_match2) {
      return 1;
    }
    return -1;
  } else {
    return v1 > v2 ? -1 : 1;
  }
}

/// Fuzzy search the string "str" in a list of "items" and return the matching
/// strings in "fmatchlist".
/// If "matchseq" is true, then for multi-word search strings, match all the
/// words in sequence.
/// If "items" is a list of strings, then search for "str" in the list.
/// If "items" is a list of dicts, then either use "key" to lookup the string
/// for each item or use "item_cb" Funcref function to get the string.
/// If "retmatchpos" is true, then return a list of positions where "str"
/// matches for each item.
static void fuzzy_match_in_list(list_T *const l, char *const str, const bool matchseq,
                                const char *const key, Callback *const item_cb,
                                const bool retmatchpos, list_T *const fmatchlist,
                                const int max_matches)
  FUNC_ATTR_NONNULL_ARG(2, 5, 7)
{
  int len = tv_list_len(l);
  if (len == 0) {
    return;
  }
  if (max_matches > 0 && len > max_matches) {
    len = max_matches;
  }

  fuzzyItem_T *const items = xcalloc((size_t)len, sizeof(fuzzyItem_T));
  int match_count = 0;
  uint32_t matches[FUZZY_MATCH_MAX_LEN];

  // For all the string items in items, get the fuzzy matching score
  TV_LIST_ITER(l, li, {
    if (max_matches > 0 && match_count >= max_matches) {
      break;
    }

    char *itemstr = NULL;
    bool itemstr_allocate = false;
    typval_T rettv;
    rettv.v_type = VAR_UNKNOWN;
    const typval_T *const tv = TV_LIST_ITEM_TV(li);
    if (tv->v_type == VAR_STRING) {  // list of strings
      itemstr = tv->vval.v_string;
    } else if (tv->v_type == VAR_DICT
               && (key != NULL || item_cb->type != kCallbackNone)) {
      // For a dict, either use the specified key to lookup the string or
      // use the specified callback function to get the string.
      if (key != NULL) {
        itemstr = tv_dict_get_string(tv->vval.v_dict, key, false);
      } else {
        typval_T argv[2];

        // Invoke the supplied callback (if any) to get the dict item
        tv->vval.v_dict->dv_refcount++;
        argv[0].v_type = VAR_DICT;
        argv[0].vval.v_dict = tv->vval.v_dict;
        argv[1].v_type = VAR_UNKNOWN;
        if (callback_call(item_cb, 1, argv, &rettv)) {
          if (rettv.v_type == VAR_STRING) {
            itemstr = rettv.vval.v_string;
            itemstr_allocate = true;
          }
        }
        tv_dict_unref(tv->vval.v_dict);
      }
    }

    int score;
    if (itemstr != NULL
        && fuzzy_match(itemstr, str, matchseq, &score, matches, FUZZY_MATCH_MAX_LEN)) {
      items[match_count].idx = (int)match_count;
      items[match_count].item = li;
      items[match_count].score = score;
      items[match_count].pat = str;
      items[match_count].startpos = (int)matches[0];
      items[match_count].itemstr = itemstr_allocate ? xstrdup(itemstr) : itemstr;
      items[match_count].itemstr_allocated = itemstr_allocate;

      // Copy the list of matching positions in itemstr to a list, if
      // "retmatchpos" is set.
      if (retmatchpos) {
        items[match_count].lmatchpos = tv_list_alloc(kListLenMayKnow);
        int j = 0;
        const char *p = str;
        while (*p != NUL && j < FUZZY_MATCH_MAX_LEN) {
          if (!ascii_iswhite(utf_ptr2char(p)) || matchseq) {
            tv_list_append_number(items[match_count].lmatchpos, matches[j]);
            j++;
          }
          MB_PTR_ADV(p);
        }
      }
      match_count++;
    }
    tv_clear(&rettv);
  });

  if (match_count > 0) {
    // Sort the list by the descending order of the match score
    qsort(items, (size_t)match_count, sizeof(fuzzyItem_T), fuzzy_match_item_compare);

    // For matchfuzzy(), return a list of matched strings.
    //          ['str1', 'str2', 'str3']
    // For matchfuzzypos(), return a list with three items.
    // The first item is a list of matched strings. The second item
    // is a list of lists where each list item is a list of matched
    // character positions. The third item is a list of matching scores.
    //      [['str1', 'str2', 'str3'], [[1, 3], [1, 3], [1, 3]]]
    list_T *retlist;
    if (retmatchpos) {
      const listitem_T *const li = tv_list_find(fmatchlist, 0);
      assert(li != NULL && TV_LIST_ITEM_TV(li)->vval.v_list != NULL);
      retlist = TV_LIST_ITEM_TV(li)->vval.v_list;
    } else {
      retlist = fmatchlist;
    }

    // Copy the matching strings to the return list
    for (int i = 0; i < match_count; i++) {
      tv_list_append_tv(retlist, TV_LIST_ITEM_TV(items[i].item));
    }

    // next copy the list of matching positions
    if (retmatchpos) {
      const listitem_T *li = tv_list_find(fmatchlist, -2);
      assert(li != NULL && TV_LIST_ITEM_TV(li)->vval.v_list != NULL);
      retlist = TV_LIST_ITEM_TV(li)->vval.v_list;

      for (int i = 0; i < match_count; i++) {
        assert(items[i].lmatchpos != NULL);
        tv_list_append_list(retlist, items[i].lmatchpos);
        items[i].lmatchpos = NULL;
      }

      // copy the matching scores
      li = tv_list_find(fmatchlist, -1);
      assert(li != NULL && TV_LIST_ITEM_TV(li)->vval.v_list != NULL);
      retlist = TV_LIST_ITEM_TV(li)->vval.v_list;
      for (int i = 0; i < match_count; i++) {
        tv_list_append_number(retlist, items[i].score);
      }
    }
  }

  for (int i = 0; i < match_count; i++) {
    if (items[i].itemstr_allocated) {
      xfree(items[i].itemstr);
    }
    assert(items[i].lmatchpos == NULL);
  }
  xfree(items);
}

/// Do fuzzy matching. Returns the list of matched strings in "rettv".
/// If "retmatchpos" is true, also returns the matching character positions.
static void do_fuzzymatch(const typval_T *const argvars, typval_T *const rettv,
                          const bool retmatchpos)
  FUNC_ATTR_NONNULL_ALL
{
  // validate and get the arguments
  if (argvars[0].v_type != VAR_LIST || argvars[0].vval.v_list == NULL) {
    semsg(_(e_listarg), retmatchpos ? "matchfuzzypos()" : "matchfuzzy()");
    return;
  }
  if (argvars[1].v_type != VAR_STRING || argvars[1].vval.v_string == NULL) {
    semsg(_(e_invarg2), tv_get_string(&argvars[1]));
    return;
  }

  Callback cb = CALLBACK_NONE;
  const char *key = NULL;
  bool matchseq = false;
  int max_matches = 0;
  if (argvars[2].v_type != VAR_UNKNOWN) {
    if (tv_check_for_nonnull_dict_arg(argvars, 2) == FAIL) {
      return;
    }

    // To search a dict, either a callback function or a key can be
    // specified.
    dict_T *const d = argvars[2].vval.v_dict;
    const dictitem_T *di;
    if ((di = tv_dict_find(d, "key", -1)) != NULL) {
      if (di->di_tv.v_type != VAR_STRING || di->di_tv.vval.v_string == NULL
          || *di->di_tv.vval.v_string == NUL) {
        semsg(_(e_invargNval), "key", tv_get_string(&di->di_tv));
        return;
      }
      key = tv_get_string(&di->di_tv);
    } else if (!tv_dict_get_callback(d, "text_cb", -1, &cb)) {
      semsg(_(e_invargval), "text_cb");
      return;
    }

    if ((di = tv_dict_find(d, "limit", -1)) != NULL) {
      if (di->di_tv.v_type != VAR_NUMBER) {
        semsg(_(e_invargval), "limit");
        return;
      }
      max_matches = (int)tv_get_number_chk(&di->di_tv, NULL);
    }

    if (tv_dict_has_key(d, "matchseq")) {
      matchseq = true;
    }
  }

  // get the fuzzy matches
  tv_list_alloc_ret(rettv, retmatchpos ? 3 : kListLenUnknown);
  if (retmatchpos) {
    // For matchfuzzypos(), a list with three items are returned. First
    // item is a list of matching strings, the second item is a list of
    // lists with matching positions within each string and the third item
    // is the list of scores of the matches.
    tv_list_append_list(rettv->vval.v_list, tv_list_alloc(kListLenUnknown));
    tv_list_append_list(rettv->vval.v_list, tv_list_alloc(kListLenUnknown));
    tv_list_append_list(rettv->vval.v_list, tv_list_alloc(kListLenUnknown));
  }

  fuzzy_match_in_list(argvars[0].vval.v_list, (char *)tv_get_string(&argvars[1]),
                      matchseq, key, &cb, retmatchpos, rettv->vval.v_list, max_matches);

  callback_free(&cb);
}

/// "matchfuzzy()" function
void f_matchfuzzy(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  do_fuzzymatch(argvars, rettv, false);
}

/// "matchfuzzypos()" function
void f_matchfuzzypos(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  do_fuzzymatch(argvars, rettv, true);
}

/// Same as fuzzy_match_item_compare() except for use with a string match
static int fuzzy_match_str_compare(const void *const s1, const void *const s2)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  const int v1 = ((fuzmatch_str_T *)s1)->score;
  const int v2 = ((fuzmatch_str_T *)s2)->score;
  const int idx1 = ((fuzmatch_str_T *)s1)->idx;
  const int idx2 = ((fuzmatch_str_T *)s2)->idx;

  if (v1 == v2) {
    return idx1 == idx2 ? 0 : idx1 > idx2 ? 1 : -1;
  } else {
    return v1 > v2 ? -1 : 1;
  }
}

/// Sort fuzzy matches by score
static void fuzzy_match_str_sort(fuzmatch_str_T *const fm, const int sz)
  FUNC_ATTR_NONNULL_ALL
{
  // Sort the list by the descending order of the match score
  qsort(fm, (size_t)sz, sizeof(fuzmatch_str_T), fuzzy_match_str_compare);
}

/// Same as fuzzy_match_item_compare() except for use with a function name
/// string match. <SNR> functions should be sorted to the end.
static int fuzzy_match_func_compare(const void *const s1, const void *const s2)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  const int v1 = ((fuzmatch_str_T *)s1)->score;
  const int v2 = ((fuzmatch_str_T *)s2)->score;
  const int idx1 = ((fuzmatch_str_T *)s1)->idx;
  const int idx2 = ((fuzmatch_str_T *)s2)->idx;
  const char *const str1 = ((fuzmatch_str_T *)s1)->str;
  const char *const str2 = ((fuzmatch_str_T *)s2)->str;

  if (*str1 != '<' && *str2 == '<') {
    return -1;
  }
  if (*str1 == '<' && *str2 != '<') {
    return 1;
  }
  if (v1 == v2) {
    return idx1 == idx2 ? 0 : idx1 > idx2 ? 1 : -1;
  }
  return v1 > v2 ? -1 : 1;
}

/// Sort fuzzy matches of function names by score.
/// <SNR> functions should be sorted to the end.
static void fuzzy_match_func_sort(fuzmatch_str_T *const fm, const int sz)
  FUNC_ATTR_NONNULL_ALL
{
  // Sort the list by the descending order of the match score
  qsort(fm, (size_t)sz, sizeof(fuzmatch_str_T), fuzzy_match_func_compare);
}

/// Fuzzy match "pat" in "str".
/// @returns 0 if there is no match. Otherwise, returns the match score.
int fuzzy_match_str(char *const str, const char *const pat)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (str == NULL || pat == NULL) {
    return 0;
  }

  int score = FUZZY_SCORE_NONE;
  uint32_t matchpos[FUZZY_MATCH_MAX_LEN];
  fuzzy_match(str, pat, true, &score, matchpos, ARRAY_SIZE(matchpos));

  return score;
}

/// Fuzzy match the position of string "pat" in string "str".
/// @returns a dynamic array of matching positions. If there is no match, returns NULL.
garray_T *fuzzy_match_str_with_pos(char *const str, const char *const pat)
{
  if (str == NULL || pat == NULL) {
    return NULL;
  }

  garray_T *match_positions = xmalloc(sizeof(garray_T));
  ga_init(match_positions, sizeof(uint32_t), 10);

  int score = FUZZY_SCORE_NONE;
  uint32_t matches[FUZZY_MATCH_MAX_LEN];
  if (!fuzzy_match(str, pat, false, &score, matches, FUZZY_MATCH_MAX_LEN)
      || score == FUZZY_SCORE_NONE) {
    ga_clear(match_positions);
    xfree(match_positions);
    return NULL;
  }

  int j = 0;
  for (const char *p = pat; *p != NUL; MB_PTR_ADV(p)) {
    if (!ascii_iswhite(utf_ptr2char(p))) {
      GA_APPEND(uint32_t, match_positions, matches[j]);
      j++;
    }
  }

  return match_positions;
}

/// This function splits the line pointed to by `*ptr` into words and performs
/// a fuzzy match for the pattern `pat` on each word. It iterates through the
/// line, moving `*ptr` to the start of each word during the process.
///
/// If a match is found:
/// - `*ptr` points to the start of the matched word.
/// - `*len` is set to the length of the matched word.
/// - `*score` contains the match score.
///
/// If no match is found, `*ptr` is updated to the end of the line.
bool fuzzy_match_str_in_line(char **ptr, char *pat, int *len, pos_T *current_pos, int *score)
{
  char *str = *ptr;
  char *strBegin = str;
  char *end = NULL;
  char *start = NULL;
  bool found = false;

  if (str == NULL || pat == NULL) {
    return found;
  }
  char *line_end = find_line_end(str);

  while (str < line_end) {
    // Skip non-word characters
    start = find_word_start(str);
    if (*start == NUL) {
      break;
    }
    end = find_word_end(start);

    // Extract the word from start to end
    char save_end = *end;
    *end = NUL;

    // Perform fuzzy match
    *score = fuzzy_match_str(start, pat);
    *end = save_end;

    if (*score != FUZZY_SCORE_NONE) {
      *len = (int)(end - start);
      found = true;
      *ptr = start;
      if (current_pos) {
        current_pos->col += (int)(end - strBegin);
      }
      break;
    }

    // Move to the end of the current word for the next iteration
    str = end;
    // Ensure we continue searching after the current word
    while (*str != NUL && !vim_iswordp(str)) {
      MB_PTR_ADV(str);
    }
  }

  if (!found) {
    *ptr = line_end;
  }

  return found;
}

/// Search for the next fuzzy match in the specified buffer.
/// This function attempts to find the next occurrence of the given pattern
/// in the buffer, starting from the current position. It handles line wrapping
/// and direction of search.
///
/// Return true if a match is found, otherwise false.
bool search_for_fuzzy_match(buf_T *buf, pos_T *pos, char *pattern, int dir, pos_T *start_pos,
                            int *len, char **ptr, int *score)
{
  pos_T current_pos = *pos;
  pos_T circly_end;
  bool found_new_match = false;
  bool looped_around = false;

  bool whole_line = ctrl_x_mode_whole_line();

  if (buf == curbuf) {
    circly_end = *start_pos;
  } else {
    circly_end.lnum = buf->b_ml.ml_line_count;
    circly_end.col = 0;
    circly_end.coladd = 0;
  }

  if (whole_line && start_pos->lnum != pos->lnum) {
    current_pos.lnum += dir;
  }

  while (true) {
    // Check if looped around and back to start position
    if (looped_around && equalpos(current_pos, circly_end)) {
      break;
    }

    // Ensure current_pos is valid
    if (current_pos.lnum >= 1 && current_pos.lnum <= buf->b_ml.ml_line_count) {
      // Get the current line buffer
      *ptr = ml_get_buf(buf, current_pos.lnum);
      if (!whole_line) {
        *ptr += current_pos.col;
      }

      // If ptr is end of line is reached, move to next line
      // or previous line based on direction
      if (*ptr != NULL && **ptr != NUL) {
        if (!whole_line) {
          // Try to find a fuzzy match in the current line starting
          // from current position
          found_new_match = fuzzy_match_str_in_line(ptr, pattern,
                                                    len, &current_pos, score);
          if (found_new_match) {
            *pos = current_pos;
            break;
          } else if (looped_around && current_pos.lnum == circly_end.lnum) {
            break;
          }
        } else {
          if (fuzzy_match_str(*ptr, pattern) != FUZZY_SCORE_NONE) {
            found_new_match = true;
            *pos = current_pos;
            *len = ml_get_buf_len(buf, current_pos.lnum);
            break;
          }
        }
      }
    }

    // Move to the next line or previous line based on direction
    if (dir == FORWARD) {
      if (++current_pos.lnum > buf->b_ml.ml_line_count) {
        if (p_ws) {
          current_pos.lnum = 1;
          looped_around = true;
        } else {
          break;
        }
      }
    } else {
      if (--current_pos.lnum < 1) {
        if (p_ws) {
          current_pos.lnum = buf->b_ml.ml_line_count;
          looped_around = true;
        } else {
          break;
        }
      }
    }
    current_pos.col = 0;
  }

  return found_new_match;
}

/// Free an array of fuzzy string matches "fuzmatch[count]".
void fuzmatch_str_free(fuzmatch_str_T *const fuzmatch, int count)
{
  if (fuzmatch == NULL) {
    return;
  }
  for (int i = 0; i < count; i++) {
    xfree(fuzmatch[count].str);
  }
  xfree(fuzmatch);
}

/// Copy a list of fuzzy matches into a string list after sorting the matches by
/// the fuzzy score. Frees the memory allocated for "fuzmatch".
void fuzzymatches_to_strmatches(fuzmatch_str_T *const fuzmatch, char ***const matches,
                                const int count, const bool funcsort)
  FUNC_ATTR_NONNULL_ARG(2)
{
  if (count <= 0) {
    goto theend;
  }

  *matches = xmalloc((size_t)count * sizeof(char *));

  // Sort the list by the descending order of the match score
  if (funcsort) {
    fuzzy_match_func_sort(fuzmatch, count);
  } else {
    fuzzy_match_str_sort(fuzmatch, count);
  }

  for (int i = 0; i < count; i++) {
    (*matches)[i] = fuzmatch[i].str;
  }

theend:
  xfree(fuzmatch);
}

/// Fuzzy match algorithm ported from https://github.com/jhawthorn/fzy.
/// This implementation extends the original by supporting multibyte characters.

#define MATCH_MAX_LEN FUZZY_MATCH_MAX_LEN

#define SCORE_GAP_LEADING -0.005
#define SCORE_GAP_TRAILING -0.005
#define SCORE_GAP_INNER -0.01
#define SCORE_MATCH_CONSECUTIVE 1.0
#define SCORE_MATCH_SLASH 0.9
#define SCORE_MATCH_WORD 0.8
#define SCORE_MATCH_CAPITAL 0.7
#define SCORE_MATCH_DOT 0.6

static int has_match(const char *needle, const char *haystack)
{
  while (*needle != NUL) {
    const int n_char = utf_ptr2char(needle);
    const char *p = haystack;
    bool matched = false;

    while (*p != NUL) {
      const int h_char = utf_ptr2char(p);

      if (n_char == h_char || mb_toupper(n_char) == h_char) {
        matched = true;
        break;
      }
      p += utfc_ptr2len(p);
    }

    if (!matched) {
      return 0;
    }

    needle += utfc_ptr2len(needle);
    haystack = p + utfc_ptr2len(p);
  }
  return 1;
}

struct match_struct {
  int needle_len;
  int haystack_len;
  int lower_needle[MATCH_MAX_LEN];    ///< stores codepoints
  int lower_haystack[MATCH_MAX_LEN];  ///< stores codepoints
  score_t match_bonus[MATCH_MAX_LEN];
};

#define IS_WORD_SEP(c) ((c) == '-' || (c) == '_' || (c) == ' ')
#define IS_PATH_SEP(c) ((c) == '/')
#define IS_DOT(c)      ((c) == '.')

static score_t compute_bonus_codepoint(int last_c, int c)
{
  if (ASCII_ISALNUM(c) || vim_iswordc(c)) {
    if (IS_PATH_SEP(last_c)) {
      return SCORE_MATCH_SLASH;
    }
    if (IS_WORD_SEP(last_c)) {
      return SCORE_MATCH_WORD;
    }
    if (IS_DOT(last_c)) {
      return SCORE_MATCH_DOT;
    }
    if (mb_isupper(c) && mb_islower(last_c)) {
      return SCORE_MATCH_CAPITAL;
    }
  }
  return 0;
}

static void setup_match_struct(match_struct *const match, const char *const needle,
                               const char *const haystack)
{
  int i = 0;
  const char *p = needle;
  while (*p != NUL && i < MATCH_MAX_LEN) {
    const int c = utf_ptr2char(p);
    match->lower_needle[i++] = mb_tolower(c);
    MB_PTR_ADV(p);
  }
  match->needle_len = i;

  i = 0;
  p = haystack;
  int prev_c = '/';
  while (*p != NUL && i < MATCH_MAX_LEN) {
    const int c = utf_ptr2char(p);
    match->lower_haystack[i] = mb_tolower(c);
    match->match_bonus[i] = compute_bonus_codepoint(prev_c, c);
    prev_c = c;
    MB_PTR_ADV(p);
    i++;
  }
  match->haystack_len = i;
}

static inline void match_row(const match_struct *match, int row, score_t *curr_D, score_t *curr_M,
                             const score_t *last_D, const score_t *last_M)
{
  int n = match->needle_len;
  int m = match->haystack_len;
  int i = row;

  const int *lower_needle = match->lower_needle;
  const int *lower_haystack = match->lower_haystack;
  const score_t *match_bonus = match->match_bonus;

  score_t prev_score = (score_t)SCORE_MIN;
  score_t gap_score = i == n - 1 ? SCORE_GAP_TRAILING : SCORE_GAP_INNER;

  // These will not be used with this value, but not all compilers see it
  score_t prev_M = (score_t)SCORE_MIN, prev_D = (score_t)SCORE_MIN;

  for (int j = 0; j < m; j++) {
    if (lower_needle[i] == lower_haystack[j]) {
      score_t score = (score_t)SCORE_MIN;
      if (!i) {
        score = (j * SCORE_GAP_LEADING) + match_bonus[j];
      } else if (j) {  // i > 0 && j > 0
        score = MAX(prev_M + match_bonus[j],
                    // consecutive match, doesn't stack with match_bonus
                    prev_D + SCORE_MATCH_CONSECUTIVE);
      }
      prev_D = last_D[j];
      prev_M = last_M[j];
      curr_D[j] = score;
      curr_M[j] = prev_score = MAX(score, prev_score + gap_score);
    } else {
      prev_D = last_D[j];
      prev_M = last_M[j];
      curr_D[j] = (score_t)SCORE_MIN;
      curr_M[j] = prev_score = prev_score + gap_score;
    }
  }
}

static score_t match_positions(const char *const needle, const char *const haystack,
                               uint32_t *const positions)
{
  if (!*needle) {
    return (score_t)SCORE_MIN;
  }

  match_struct match;
  setup_match_struct(&match, needle, haystack);

  int n = match.needle_len;
  int m = match.haystack_len;

  if (m > MATCH_MAX_LEN || n > m) {
    // Unreasonably large candidate: return no score
    // If it is a valid match it will still be returned, it will
    // just be ranked below any reasonably sized candidates
    return (score_t)SCORE_MIN;
  } else if (n == m) {
    // Since this method can only be called with a haystack which
    // matches needle. If the lengths of the strings are equal the
    // strings themselves must also be equal (ignoring case).
    if (positions) {
      for (int i = 0; i < n; i++) {
        positions[i] = (uint32_t)i;
      }
    }
    return (score_t)SCORE_MAX;
  }

  // D[][] Stores the best score for this position ending with a match.
  // M[][] Stores the best possible score at this position.
  score_t(*D)[MATCH_MAX_LEN] = xmalloc(sizeof(score_t) * MATCH_MAX_LEN * (size_t)n);
  score_t(*M)[MATCH_MAX_LEN] = xmalloc(sizeof(score_t) * MATCH_MAX_LEN * (size_t)n);

  match_row(&match, 0, D[0], M[0], D[0], M[0]);
  for (int i = 1; i < n; i++) {
    match_row(&match, i, D[i], M[i], D[i - 1], M[i - 1]);
  }

  // backtrace to find the positions of optimal matching
  if (positions) {
    int match_required = 0;
    for (int i = n - 1, j = m - 1; i >= 0; i--) {
      for (; j >= 0; j--) {
        // There may be multiple paths which result in
        // the optimal weight.
        //
        // For simplicity, we will pick the first one
        // we encounter, the latest in the candidate
        // string.
        if (D[i][j] != (score_t)SCORE_MIN
            && (match_required || D[i][j] == M[i][j])) {
          // If this score was determined using
          // SCORE_MATCH_CONSECUTIVE, the
          // previous character MUST be a match
          match_required = i && j
                           && M[i][j] == D[i - 1][j - 1] + SCORE_MATCH_CONSECUTIVE;
          positions[i] = (uint32_t)(j--);
          break;
        }
      }
    }
  }

  score_t result = M[n - 1][m - 1];

  xfree(M);
  xfree(D);

  return result;
}
