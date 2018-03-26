#ifndef MATCH_H
#define MATCH_H MATCH_H

#include <math.h>

typedef double score_t;
#define SCORE_MAX INFINITY
#define SCORE_MIN -INFINITY

#define SCORE_GAP_LEADING -0.005
#define SCORE_GAP_TRAILING -0.005
#define SCORE_GAP_INNER -0.01
#define SCORE_MATCH_CONSECUTIVE 1.0
#define SCORE_MATCH_SLASH 0.9
#define SCORE_MATCH_WORD 0.8
#define SCORE_MATCH_CAPITAL 0.7
#define SCORE_MATCH_DOT 0.6

int has_match(const char *needle, const char *haystack);
score_t match_positions(const char *needle, const char *haystack, size_t *positions);
score_t match(const char *needle, const char *haystack);

#endif
