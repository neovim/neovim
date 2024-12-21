#include <assert.h>
#include <math.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nvim/linematch.h"
#include "nvim/macros_defs.h"
#include "nvim/memory.h"
#include "nvim/pos_defs.h"
#include "nvim/strings.h"
#include "xdiff/xdiff.h"

#define LN_MAX_BUFS 8
#define LN_DECISION_MAX 255  // pow(2, LN_MAX_BUFS(8)) - 1 = 255

// struct for running the diff linematch algorithm
typedef struct diffcmppath_S diffcmppath_T;
struct diffcmppath_S {
  int df_lev_score;  // to keep track of the total score of this path
  size_t df_path_n;   // current index of this path
  int df_choice_mem[LN_DECISION_MAX + 1];
  int df_choice[LN_DECISION_MAX];
  diffcmppath_T *df_decision[LN_DECISION_MAX];  // to keep track of this path traveled
  size_t df_optimal_choice;
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "linematch.c.generated.h"
#endif

static size_t line_len(const mmfile_t *m)
{
  char *s = m->ptr;
  size_t n = (size_t)m->size;
  char *end = strnchr(s, &n, '\n');
  if (end) {
    return (size_t)(end - s);
  }
  return (size_t)m->size;
}

#define MATCH_CHAR_MAX_LEN 800

/// Same as matching_chars but ignore whitespace
///
/// @param s1
/// @param s2
static int matching_chars_iwhite(const mmfile_t *s1, const mmfile_t *s2)
{
  // the newly processed strings that will be compared
  // delete the white space characters
  mmfile_t sp[2];
  char p[2][MATCH_CHAR_MAX_LEN];
  for (int k = 0; k < 2; k++) {
    const mmfile_t *s = k == 0 ? s1 : s2;
    size_t pi = 0;
    size_t slen = MIN(MATCH_CHAR_MAX_LEN - 1, line_len(s));
    for (size_t i = 0; i <= slen; i++) {
      char e = s->ptr[i];
      if (e != ' ' && e != '\t') {
        p[k][pi] = e;
        pi++;
      }
    }

    sp[k] = (mmfile_t){
      .ptr = p[k],
      .size = (int)pi,
    };
  }
  return matching_chars(&sp[0], &sp[1]);
}

/// Return matching characters between "s1" and "s2" whilst respecting sequence order.
/// Consider the case of two strings 'AAACCC' and 'CCCAAA', the
/// return value from this function will be 3, either to match
/// the 3 C's, or the 3 A's.
///
/// Examples:
///   matching_chars("aabc", "acba")               -> 2  // 'a' and 'b' in common
///   matching_chars("123hello567", "he123ll567o") -> 8  // '123', 'll' and '567' in common
///   matching_chars("abcdefg", "gfedcba")         -> 1  // all characters in common,
///                                                      // but only at most 1 in sequence
///
/// @param m1
/// @param m2
static int matching_chars(const mmfile_t *m1, const mmfile_t *m2)
{
  size_t s1len = MIN(MATCH_CHAR_MAX_LEN - 1, line_len(m1));
  size_t s2len = MIN(MATCH_CHAR_MAX_LEN - 1, line_len(m2));
  char *s1 = m1->ptr;
  char *s2 = m2->ptr;
  int matrix[2][MATCH_CHAR_MAX_LEN] = { 0 };
  bool icur = 1;  // save space by storing only two rows for i axis
  for (size_t i = 0; i < s1len; i++) {
    icur = !icur;
    int *e1 = matrix[icur];
    int *e2 = matrix[!icur];
    for (size_t j = 0; j < s2len; j++) {
      // skip char in s1
      if (e2[j + 1] > e1[j + 1]) {
        e1[j + 1] = e2[j + 1];
      }
      // skip char in s2
      if (e1[j] > e1[j + 1]) {
        e1[j + 1] = e1[j];
      }
      // compare char in s1 and s2
      if ((s1[i] == s2[j]) && (e2[j] + 1) > e1[j + 1]) {
        e1[j + 1] = e2[j] + 1;
      }
    }
  }
  return matrix[icur][s2len];
}

/// count the matching characters between a variable number of strings "sp"
/// mark the strings that have already been compared to extract them later
/// without re-running the character match counting.
/// @param sp
/// @param fomvals
/// @param n
static int count_n_matched_chars(mmfile_t **sp, const size_t n, bool iwhite)
{
  int matched_chars = 0;
  int matched = 0;
  for (size_t i = 0; i < n; i++) {
    for (size_t j = i + 1; j < n; j++) {
      if (sp[i]->ptr != NULL && sp[j]->ptr != NULL) {
        matched++;
        // TODO(lewis6991): handle whitespace ignoring higher up in the stack
        matched_chars += iwhite ? matching_chars_iwhite(sp[i], sp[j])
                                : matching_chars(sp[i], sp[j]);
      }
    }
  }

  // prioritize a match of 3 (or more lines) equally to a match of 2 lines
  if (matched >= 2) {
    matched_chars *= 2;
    matched_chars /= matched;
  }

  return matched_chars;
}

mmfile_t fastforward_buf_to_lnum(mmfile_t s, linenr_T lnum)
{
  for (int i = 0; i < lnum - 1; i++) {
    size_t n = (size_t)s.size;
    s.ptr = strnchr(s.ptr, &n, '\n');
    s.size = (int)n;
    if (!s.ptr) {
      break;
    }
    s.ptr++;
    s.size--;
  }
  return s;
}

/// try all the different ways to compare these lines and use the one that
/// results in the most matching characters
/// @param df_iters
/// @param paths
/// @param npaths
/// @param path_idx
/// @param choice
/// @param diffcmppath
/// @param diff_len
/// @param ndiffs
/// @param diff_blk
static void try_possible_paths(const int *df_iters, const size_t *paths, const int npaths,
                               const int path_idx, int *choice, diffcmppath_T *diffcmppath,
                               const int *diff_len, const size_t ndiffs, const mmfile_t **diff_blk,
                               bool iwhite)
{
  if (path_idx == npaths) {
    if ((*choice) > 0) {
      int from_vals[LN_MAX_BUFS] = { 0 };
      const int *to_vals = df_iters;
      mmfile_t mm[LN_MAX_BUFS];  // stack memory for current_lines
      mmfile_t *current_lines[LN_MAX_BUFS];
      for (size_t k = 0; k < ndiffs; k++) {
        from_vals[k] = df_iters[k];
        // get the index at all of the places
        if ((*choice) & (1 << k)) {
          from_vals[k]--;
          mm[k] = fastforward_buf_to_lnum(*diff_blk[k], df_iters[k]);
        } else {
          mm[k] = (mmfile_t){ 0 };
        }
        current_lines[k] = &mm[k];
      }
      size_t unwrapped_idx_from = unwrap_indexes(from_vals, diff_len, ndiffs);
      size_t unwrapped_idx_to = unwrap_indexes(to_vals, diff_len, ndiffs);
      int matched_chars = count_n_matched_chars(current_lines, ndiffs, iwhite);
      int score = diffcmppath[unwrapped_idx_from].df_lev_score + matched_chars;
      if (score > diffcmppath[unwrapped_idx_to].df_lev_score) {
        diffcmppath[unwrapped_idx_to].df_path_n = 1;
        diffcmppath[unwrapped_idx_to].df_decision[0] = &diffcmppath[unwrapped_idx_from];
        diffcmppath[unwrapped_idx_to].df_choice[0] = *choice;
        diffcmppath[unwrapped_idx_to].df_lev_score = score;
      } else if (score == diffcmppath[unwrapped_idx_to].df_lev_score) {
        size_t k = diffcmppath[unwrapped_idx_to].df_path_n++;
        diffcmppath[unwrapped_idx_to].df_decision[k] = &diffcmppath[unwrapped_idx_from];
        diffcmppath[unwrapped_idx_to].df_choice[k] = *choice;
      }
    }
    return;
  }
  size_t bit_place = paths[path_idx];
  *(choice) |= (1 << bit_place);  // set it to 1
  try_possible_paths(df_iters, paths, npaths, path_idx + 1, choice,
                     diffcmppath, diff_len, ndiffs, diff_blk, iwhite);
  *(choice) &= ~(1 << bit_place);  // set it to 0
  try_possible_paths(df_iters, paths, npaths, path_idx + 1, choice,
                     diffcmppath, diff_len, ndiffs, diff_blk, iwhite);
}

/// unwrap indexes to access n dimensional tensor
/// @param values
/// @param diff_len
/// @param ndiffs
static size_t unwrap_indexes(const int *values, const int *diff_len, const size_t ndiffs)
{
  size_t num_unwrap_scalar = 1;
  for (size_t k = 0; k < ndiffs; k++) {
    num_unwrap_scalar *= (size_t)diff_len[k] + 1;
  }

  size_t path_idx = 0;
  for (size_t k = 0; k < ndiffs; k++) {
    num_unwrap_scalar /= (size_t)diff_len[k] + 1;

    int n = values[k];
    path_idx += num_unwrap_scalar * (size_t)n;
  }
  return path_idx;
}

/// populate the values of the linematch algorithm tensor, and find the best
/// decision for how to compare the relevant lines from each of the buffers at
/// each point in the tensor
/// @param df_iters
/// @param ch_dim
/// @param diffcmppath
/// @param diff_len
/// @param ndiffs
/// @param diff_blk
static void populate_tensor(int *df_iters, const size_t ch_dim, diffcmppath_T *diffcmppath,
                            const int *diff_len, const size_t ndiffs, const mmfile_t **diff_blk,
                            bool iwhite)
{
  if (ch_dim == ndiffs) {
    int npaths = 0;
    size_t paths[LN_MAX_BUFS];

    for (size_t j = 0; j < ndiffs; j++) {
      if (df_iters[j] > 0) {
        paths[npaths] = j;
        npaths++;
      }
    }
    int choice = 0;
    size_t unwrapper_idx_to = unwrap_indexes(df_iters, diff_len, ndiffs);
    diffcmppath[unwrapper_idx_to].df_lev_score = -1;
    try_possible_paths(df_iters, paths, npaths, 0, &choice, diffcmppath,
                       diff_len, ndiffs, diff_blk, iwhite);
    return;
  }

  for (int i = 0; i <= diff_len[ch_dim]; i++) {
    df_iters[ch_dim] = i;
    populate_tensor(df_iters, ch_dim + 1, diffcmppath, diff_len,
                    ndiffs, diff_blk, iwhite);
  }
}

/// algorithm to find an optimal alignment of lines of a diff block with 2 or
/// more files. The algorithm is generalized to work for any number of files
/// which corresponds to another dimension added to the tensor used in the
/// algorithm
///
/// for questions and information about the linematch algorithm please contact
/// Jonathon White (jonathonwhite@protonmail.com)
///
/// for explanation, a summary of the algorithm in 3 dimensions (3 files
///     compared) follows
///
/// The 3d case (for 3 buffers) of the algorithm implemented when diffopt
/// 'linematch' is enabled. The algorithm constructs a 3d tensor to
/// compare a diff between 3 buffers. The dimensions of the tensor are
/// the length of the diff in each buffer plus 1 A path is constructed by
/// moving from one edge of the cube/3d tensor to the opposite edge.
/// Motions from one cell of the cube to the next represent decisions. In
/// a 3d cube, there are a total of 7 decisions that can be made,
/// represented by the enum df_path3_choice which is defined in
/// buffer_defs.h a comparison of buffer 0 and 1 represents a motion
/// toward the opposite edge of the cube with components along the 0 and
/// 1 axes.  a comparison of buffer 0, 1, and 2 represents a motion
/// toward the opposite edge of the cube with components along the 0, 1,
/// and 2 axes. A skip of buffer 0 represents a motion along only the 0
/// axis. For each action, a point value is awarded, and the path is
/// saved for reference later, if it is found to have been the optimal
/// path. The optimal path has the highest score.  The score is
/// calculated as the summation of the total characters matching between
/// all of the lines which were compared. The structure of the algorithm
/// is that of a dynamic programming problem.  We can calculate a point
/// i,j,k in the cube as a function of i-1, j-1, and k-1. To find the
/// score and path at point i,j,k, we must determine which path we want
/// to use, this is done by looking at the possibilities and choosing
/// the one which results in the local highest score.  The total highest
/// scored path is, then in the end represented by the cell in the
/// opposite corner from the start location.  The entire algorithm
/// consists of populating the 3d cube with the optimal paths from which
/// it may have came.
///
/// Optimizations:
/// As the function to calculate the cell of a tensor at point i,j,k is a
/// function of the cells at i-1, j-1, k-1, the whole tensor doesn't need
/// to be stored in memory at once. In the case of the 3d cube, only two
/// slices (along k and j axis) are stored in memory. For the 2d matrix
/// (for 2 files), only two rows are stored at a time. The next/previous
/// slice (or row) is always calculated from the other, and they alternate
/// at each iteration.
/// In the 3d case, 3 arrays are populated to memorize the score (matched
/// characters) of the 3 buffers, so a redundant calculation of the
/// scores does not occur
/// @param diff_blk
/// @param diff_len
/// @param ndiffs
/// @param [out] [allocated] decisions
/// @return the length of decisions
size_t linematch_nbuffers(const mmfile_t **diff_blk, const int *diff_len, const size_t ndiffs,
                          int **decisions, bool iwhite)
{
  assert(ndiffs <= LN_MAX_BUFS);

  size_t memsize = 1;
  size_t memsize_decisions = 0;
  for (size_t i = 0; i < ndiffs; i++) {
    assert(diff_len[i] >= 0);
    memsize *= (size_t)(diff_len[i] + 1);
    memsize_decisions += (size_t)diff_len[i];
  }

  // create the flattened path matrix
  diffcmppath_T *diffcmppath = xmalloc(sizeof(diffcmppath_T) * memsize);
  // allocate memory here
  for (size_t i = 0; i < memsize; i++) {
    diffcmppath[i].df_lev_score = 0;
    diffcmppath[i].df_path_n = 0;
    for (size_t j = 0; j < (size_t)pow(2, (double)ndiffs); j++) {
      diffcmppath[i].df_choice_mem[j] = -1;
    }
  }

  // memory for avoiding repetitive calculations of score
  int df_iters[LN_MAX_BUFS];
  populate_tensor(df_iters, 0, diffcmppath, diff_len, ndiffs, diff_blk, iwhite);

  const size_t u = unwrap_indexes(diff_len, diff_len, ndiffs);
  diffcmppath_T *startNode = &diffcmppath[u];

  *decisions = xmalloc(sizeof(int) * memsize_decisions);
  size_t n_optimal = 0;
  test_charmatch_paths(startNode, 0);
  while (startNode->df_path_n > 0) {
    size_t j = startNode->df_optimal_choice;
    (*decisions)[n_optimal++] = startNode->df_choice[j];
    startNode = startNode->df_decision[j];
  }
  // reverse array
  for (size_t i = 0; i < (n_optimal / 2); i++) {
    int tmp = (*decisions)[i];
    (*decisions)[i] = (*decisions)[n_optimal - 1 - i];
    (*decisions)[n_optimal - 1 - i] = tmp;
  }

  xfree(diffcmppath);

  return n_optimal;
}

// returns the minimum amount of path changes from start to end
static size_t test_charmatch_paths(diffcmppath_T *node, int lastdecision)
{
  // memoization
  if (node->df_choice_mem[lastdecision] == -1) {
    if (node->df_path_n == 0) {
      // we have reached the end of the tree
      node->df_choice_mem[lastdecision] = 0;
    } else {
      size_t minimum_turns = SIZE_MAX;  // the minimum amount of turns required to reach the end
      for (size_t i = 0; i < node->df_path_n; i++) {
        // recurse
        size_t t = test_charmatch_paths(node->df_decision[i], node->df_choice[i]) +
                   (lastdecision != node->df_choice[i] ? 1 : 0);
        if (t < minimum_turns) {
          node->df_optimal_choice = i;
          minimum_turns = t;
        }
      }
      node->df_choice_mem[lastdecision] = (int)minimum_turns;
    }
  }
  return (size_t)node->df_choice_mem[lastdecision];
}
