#include <ctype.h>
#include <string.h>
#include <strings.h>
#include <stdio.h>
#include <float.h>
#include <math.h>

#include "match.h"
#include "bonus.h"

char *strcasechr(const char *s, char c) {
	const char accept[3] = {c, toupper(c), 0};
	return strpbrk(s, accept);
}

int has_match(const char *needle, const char *haystack) {
	while (*needle) {
		char nch = *needle++;

		if (!(haystack = strcasechr(haystack, nch))) {
			return 0;
		}
		haystack++;
	}
	return 1;
}

#define max(a, b) (((a) > (b)) ? (a) : (b))

#ifdef DEBUG_VERBOSE
/* print one of the internal matrices */
void mat_print(score_t *mat, char name, const char *needle, const char *haystack) {
	int n = strlen(needle);
	int m = strlen(haystack);
	int i, j;
	fprintf(stderr, "%c   ", name);
	for (j = 0; j < m; j++) {
		fprintf(stderr, "     %c", haystack[j]);
	}
	fprintf(stderr, "\n");
	for (i = 0; i < n; i++) {
		fprintf(stderr, " %c |", needle[i]);
		for (j = 0; j < m; j++) {
			score_t val = mat[i * m + j];
			if (val == SCORE_MIN) {
				fprintf(stderr, "    -\u221E");
			} else {
				fprintf(stderr, " %.3f", val);
			}
		}
		fprintf(stderr, "\n");
	}
	fprintf(stderr, "\n\n");
}
#endif

static void precompute_bonus(const char *haystack, score_t *match_bonus) {
	/* Which positions are beginning of words */
	int m = strlen(haystack);
	char last_ch = '/';
	for (int i = 0; i < m; i++) {
		char ch = haystack[i];
		match_bonus[i] = COMPUTE_BONUS(last_ch, ch);
		last_ch = ch;
	}
}

score_t match_positions(const char *needle, const char *haystack, size_t *positions) {
	if (!*needle)
		return SCORE_MIN;

	int n = strlen(needle);
	int m = strlen(haystack);

	if (n == m) {
		/* Since this method can only be called with a haystack which
		 * matches needle. If the lengths of the strings are equal the
		 * strings themselves must also be equal (ignoring case).
		 */
		if (positions)
			for (int i = 0; i < n; i++)
				positions[i] = i;
		return SCORE_MAX;
	}

	if (m > 1024) {
		/*
		 * Unreasonably large candidate: return no score
		 * If it is a valid match it will still be returned, it will
		 * just be ranked below any reasonably sized candidates
		 */
		return SCORE_MIN;
	}

	score_t match_bonus[m];
	score_t D[n][m], M[n][m];

	/*
	 * D[][] Stores the best score for this position ending with a match.
	 * M[][] Stores the best possible score at this position.
	 */
	precompute_bonus(haystack, match_bonus);

	for (int i = 0; i < n; i++) {
		score_t prev_score = SCORE_MIN;
		score_t gap_score = i == n - 1 ? SCORE_GAP_TRAILING : SCORE_GAP_INNER;

		for (int j = 0; j < m; j++) {
			if (tolower(needle[i]) == tolower(haystack[j])) {
				score_t score = SCORE_MIN;
				if (!i) {
					score = (j * SCORE_GAP_LEADING) + match_bonus[j];
				} else if (j) { /* i > 0 && j > 0*/
					score = max(
					    M[i - 1][j - 1] + match_bonus[j],

					    /* consecutive match, doesn't stack with match_bonus */
					    D[i - 1][j - 1] + SCORE_MATCH_CONSECUTIVE);
				}
				D[i][j] = score;
				M[i][j] = prev_score = max(score, prev_score + gap_score);
			} else {
				D[i][j] = SCORE_MIN;
				M[i][j] = prev_score = prev_score + gap_score;
			}
		}
	}

#ifdef DEBUG_VERBOSE
	fprintf(stderr, "\"%s\" =~ \"%s\"\n", needle, haystack);
	mat_print(&D[0][0], 'D', needle, haystack);
	mat_print(&M[0][0], 'M', needle, haystack);
	fprintf(stderr, "\n");
#endif

	/* backtrace to find the positions of optimal matching */
	if (positions) {
		int match_required = 0;
		for (int i = n - 1, j = m - 1; i >= 0; i--) {
			for (; j >= 0; j--) {
				/*
				 * There may be multiple paths which result in
				 * the optimal weight.
				 *
				 * For simplicity, we will pick the first one
				 * we encounter, the latest in the candidate
				 * string.
				 */
				if (D[i][j] != SCORE_MIN &&
				    (match_required || D[i][j] == M[i][j])) {
					/* If this score was determined using
					 * SCORE_MATCH_CONSECUTIVE, the
					 * previous character MUST be a match
					 */
					match_required =
					    i && j &&
					    M[i][j] == D[i - 1][j - 1] + SCORE_MATCH_CONSECUTIVE;
					positions[i] = j--;
					break;
				}
			}
		}
	}

	return M[n - 1][m - 1];
}

score_t match(const char *needle, const char *haystack) {
	return match_positions(needle, haystack, NULL);
}
