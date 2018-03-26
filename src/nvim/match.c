// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/*
 * match.c: functions for custom completion matching
 */

#include "edit.h"
#include "match.h"
#include "fzy/match.h"

/*
 * Returns true if needle can be found in haystack. Both are null-terminated.
 */
bool has_custom_match(const char_u *needle, const char_u *haystack,
                      bool ignore_case) {
  (void)ignore_case; // not used in fuzzy matching
  return has_match((const char *)needle, (const char *)haystack);
}

typedef struct {
  compl_T   *cs_compl;
  score_t   cs_score;
} compl_score_T;

/* Comparator for compl_score_T based on fuzzy match score. */
static int compl_score_cmp(const void *l, const void *r) {
  const compl_score_T *li = (const compl_score_T *)l;
  const compl_score_T *ri = (const compl_score_T *)r;
  if (li->cs_score > ri->cs_score)
    return -1;
  if (li->cs_score < ri->cs_score)
    return 1;
  return 0;
}

/*
 * Resort match list based on fuzzy match score. Modifies *first_match to
 * point to the new list head.
 */
void sort_custom_matches(const char_u *pattern, compl_T **first_match) {
  if (!first_match || !*first_match) {
    return;
  }
  compl_T *compl_first_match = *first_match;
  const bool cyclic = (compl_first_match->cp_prev != NULL);
  int num = 0;
  compl_T *c;
  for (c = compl_first_match; c != NULL;
       c = (c->cp_next == compl_first_match) ? NULL : c->cp_next) {
    ++num;
  }
  compl_score_T *compl_score =
    (compl_score_T *)xcalloc((size_t)num, sizeof(compl_score_T));
  if (!compl_score) {
    return;
  }
  c = compl_first_match;
  for (int i = 0; i < num; ++i, c = c->cp_next) {
    compl_score[i].cs_compl = c;
    const char *text = (const char *)
      (c->cp_text[CPT_ABBR] ? c->cp_text[CPT_ABBR] : c->cp_str);
    compl_score[i].cs_score = match((const char *)pattern, text);
  }
  qsort(compl_score, (size_t)num, sizeof(compl_score_T), compl_score_cmp);
  for (int i = 1; i < num; ++i) {
    compl_T *prev = compl_score[i - 1].cs_compl;
    compl_T *cur = compl_score[i].cs_compl;
    prev->cp_next = cur;
    cur->cp_prev = prev;
  }
  compl_T *first = compl_score[0].cs_compl;
  compl_T *last = compl_score[num - 1].cs_compl;
  first->cp_prev = cyclic ? last : NULL;
  last->cp_next = cyclic ? first : NULL;

  *first_match = compl_score[0].cs_compl;
  xfree(compl_score);
}
