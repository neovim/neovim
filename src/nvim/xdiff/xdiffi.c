/*
 *  LibXDiff by Davide Libenzi ( File Differential Library )
 *  Copyright (C) 2003	Davide Libenzi
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, see
 *  <http://www.gnu.org/licenses/>.
 *
 *  Davide Libenzi <davidel@xmailserver.org>
 *
 */

#include "xinclude.h"

#define XDL_MAX_COST_MIN 256
#define XDL_HEUR_MIN_COST 256
#define XDL_LINE_MAX (long)((1UL << (CHAR_BIT * sizeof(long) - 1)) - 1)
#define XDL_SNAKE_CNT 20
#define XDL_K_HEUR 4

typedef struct s_xdpsplit {
	long i1, i2;
	int min_lo, min_hi;
} xdpsplit_t;

/*
 * See "An O(ND) Difference Algorithm and its Variations", by Eugene Myers.
 * Basically considers a "box" (off1, off2, lim1, lim2) and scan from both
 * the forward diagonal starting from (off1, off2) and the backward diagonal
 * starting from (lim1, lim2). If the K values on the same diagonal crosses
 * returns the furthest point of reach. We might end up having to expensive
 * cases using this algorithm is full, so a little bit of heuristic is needed
 * to cut the search and to return a suboptimal point.
 */
static long xdl_split(unsigned long const *ha1, long off1, long lim1,
		      unsigned long const *ha2, long off2, long lim2,
		      long *kvdf, long *kvdb, int need_min, xdpsplit_t *spl,
		      xdalgoenv_t *xenv) {
	long dmin = off1 - lim2, dmax = lim1 - off2;
	long fmid = off1 - off2, bmid = lim1 - lim2;
	long odd = (fmid - bmid) & 1;
	long fmin = fmid, fmax = fmid;
	long bmin = bmid, bmax = bmid;
	long ec, d, i1, i2, prev1, best, dd, v, k;

	/*
	 * Set initial diagonal values for both forward and backward path.
	 */
	kvdf[fmid] = off1;
	kvdb[bmid] = lim1;

	for (ec = 1;; ec++) {
		int got_snake = 0;

		/*
		 * We need to extent the diagonal "domain" by one. If the next
		 * values exits the box boundaries we need to change it in the
		 * opposite direction because (max - min) must be a power of two.
		 * Also we initialize the external K value to -1 so that we can
		 * avoid extra conditions check inside the core loop.
		 */
		if (fmin > dmin)
			kvdf[--fmin - 1] = -1;
		else
			++fmin;
		if (fmax < dmax)
			kvdf[++fmax + 1] = -1;
		else
			--fmax;

		for (d = fmax; d >= fmin; d -= 2) {
			if (kvdf[d - 1] >= kvdf[d + 1])
				i1 = kvdf[d - 1] + 1;
			else
				i1 = kvdf[d + 1];
			prev1 = i1;
			i2 = i1 - d;
			for (; i1 < lim1 && i2 < lim2 && ha1[i1] == ha2[i2]; i1++, i2++);
			if (i1 - prev1 > xenv->snake_cnt)
				got_snake = 1;
			kvdf[d] = i1;
			if (odd && bmin <= d && d <= bmax && kvdb[d] <= i1) {
				spl->i1 = i1;
				spl->i2 = i2;
				spl->min_lo = spl->min_hi = 1;
				return ec;
			}
		}

		/*
		 * We need to extent the diagonal "domain" by one. If the next
		 * values exits the box boundaries we need to change it in the
		 * opposite direction because (max - min) must be a power of two.
		 * Also we initialize the external K value to -1 so that we can
		 * avoid extra conditions check inside the core loop.
		 */
		if (bmin > dmin)
			kvdb[--bmin - 1] = XDL_LINE_MAX;
		else
			++bmin;
		if (bmax < dmax)
			kvdb[++bmax + 1] = XDL_LINE_MAX;
		else
			--bmax;

		for (d = bmax; d >= bmin; d -= 2) {
			if (kvdb[d - 1] < kvdb[d + 1])
				i1 = kvdb[d - 1];
			else
				i1 = kvdb[d + 1] - 1;
			prev1 = i1;
			i2 = i1 - d;
			for (; i1 > off1 && i2 > off2 && ha1[i1 - 1] == ha2[i2 - 1]; i1--, i2--);
			if (prev1 - i1 > xenv->snake_cnt)
				got_snake = 1;
			kvdb[d] = i1;
			if (!odd && fmin <= d && d <= fmax && i1 <= kvdf[d]) {
				spl->i1 = i1;
				spl->i2 = i2;
				spl->min_lo = spl->min_hi = 1;
				return ec;
			}
		}

		if (need_min)
			continue;

		/*
		 * If the edit cost is above the heuristic trigger and if
		 * we got a good snake, we sample current diagonals to see
		 * if some of the, have reached an "interesting" path. Our
		 * measure is a function of the distance from the diagonal
		 * corner (i1 + i2) penalized with the distance from the
		 * mid diagonal itself. If this value is above the current
		 * edit cost times a magic factor (XDL_K_HEUR) we consider
		 * it interesting.
		 */
		if (got_snake && ec > xenv->heur_min) {
			for (best = 0, d = fmax; d >= fmin; d -= 2) {
				dd = d > fmid ? d - fmid: fmid - d;
				i1 = kvdf[d];
				i2 = i1 - d;
				v = (i1 - off1) + (i2 - off2) - dd;

				if (v > XDL_K_HEUR * ec && v > best &&
				    off1 + xenv->snake_cnt <= i1 && i1 < lim1 &&
				    off2 + xenv->snake_cnt <= i2 && i2 < lim2) {
					for (k = 1; ha1[i1 - k] == ha2[i2 - k]; k++)
						if (k == xenv->snake_cnt) {
							best = v;
							spl->i1 = i1;
							spl->i2 = i2;
							break;
						}
				}
			}
			if (best > 0) {
				spl->min_lo = 1;
				spl->min_hi = 0;
				return ec;
			}

			for (best = 0, d = bmax; d >= bmin; d -= 2) {
				dd = d > bmid ? d - bmid: bmid - d;
				i1 = kvdb[d];
				i2 = i1 - d;
				v = (lim1 - i1) + (lim2 - i2) - dd;

				if (v > XDL_K_HEUR * ec && v > best &&
				    off1 < i1 && i1 <= lim1 - xenv->snake_cnt &&
				    off2 < i2 && i2 <= lim2 - xenv->snake_cnt) {
					for (k = 0; ha1[i1 + k] == ha2[i2 + k]; k++)
						if (k == xenv->snake_cnt - 1) {
							best = v;
							spl->i1 = i1;
							spl->i2 = i2;
							break;
						}
				}
			}
			if (best > 0) {
				spl->min_lo = 0;
				spl->min_hi = 1;
				return ec;
			}
		}

		/*
		 * Enough is enough. We spent too much time here and now we collect
		 * the furthest reaching path using the (i1 + i2) measure.
		 */
		if (ec >= xenv->mxcost) {
			long fbest, fbest1, bbest, bbest1;

			fbest = fbest1 = -1;
			for (d = fmax; d >= fmin; d -= 2) {
				i1 = XDL_MIN(kvdf[d], lim1);
				i2 = i1 - d;
				if (lim2 < i2)
					i1 = lim2 + d, i2 = lim2;
				if (fbest < i1 + i2) {
					fbest = i1 + i2;
					fbest1 = i1;
				}
			}

			bbest = bbest1 = XDL_LINE_MAX;
			for (d = bmax; d >= bmin; d -= 2) {
				i1 = XDL_MAX(off1, kvdb[d]);
				i2 = i1 - d;
				if (i2 < off2)
					i1 = off2 + d, i2 = off2;
				if (i1 + i2 < bbest) {
					bbest = i1 + i2;
					bbest1 = i1;
				}
			}

			if ((lim1 + lim2) - bbest < fbest - (off1 + off2)) {
				spl->i1 = fbest1;
				spl->i2 = fbest - fbest1;
				spl->min_lo = 1;
				spl->min_hi = 0;
			} else {
				spl->i1 = bbest1;
				spl->i2 = bbest - bbest1;
				spl->min_lo = 0;
				spl->min_hi = 1;
			}
			return ec;
		}
	}
}


/*
 * Rule: "Divide et Impera". Recursively split the box in sub-boxes by calling
 * the box splitting function. Note that the real job (marking changed lines)
 * is done in the two boundary reaching checks.
 */
int xdl_recs_cmp(diffdata_t *dd1, long off1, long lim1,
		 diffdata_t *dd2, long off2, long lim2,
		 long *kvdf, long *kvdb, int need_min, xdalgoenv_t *xenv) {
	unsigned long const *ha1 = dd1->ha, *ha2 = dd2->ha;

	/*
	 * Shrink the box by walking through each diagonal snake (SW and NE).
	 */
	for (; off1 < lim1 && off2 < lim2 && ha1[off1] == ha2[off2]; off1++, off2++);
	for (; off1 < lim1 && off2 < lim2 && ha1[lim1 - 1] == ha2[lim2 - 1]; lim1--, lim2--);

	/*
	 * If one dimension is empty, then all records on the other one must
	 * be obviously changed.
	 */
	if (off1 == lim1) {
		char *rchg2 = dd2->rchg;
		long *rindex2 = dd2->rindex;

		for (; off2 < lim2; off2++)
			rchg2[rindex2[off2]] = 1;
	} else if (off2 == lim2) {
		char *rchg1 = dd1->rchg;
		long *rindex1 = dd1->rindex;

		for (; off1 < lim1; off1++)
			rchg1[rindex1[off1]] = 1;
	} else {
		xdpsplit_t spl;
		spl.i1 = spl.i2 = 0;

		/*
		 * Divide ...
		 */
		if (xdl_split(ha1, off1, lim1, ha2, off2, lim2, kvdf, kvdb,
			      need_min, &spl, xenv) < 0) {

			return -1;
		}

		/*
		 * ... et Impera.
		 */
		if (xdl_recs_cmp(dd1, off1, spl.i1, dd2, off2, spl.i2,
				 kvdf, kvdb, spl.min_lo, xenv) < 0 ||
		    xdl_recs_cmp(dd1, spl.i1, lim1, dd2, spl.i2, lim2,
				 kvdf, kvdb, spl.min_hi, xenv) < 0) {

			return -1;
		}
	}

	return 0;
}


int xdl_do_diff(mmfile_t *mf1, mmfile_t *mf2, xpparam_t const *xpp,
		xdfenv_t *xe) {
	long ndiags;
	long *kvd, *kvdf, *kvdb;
	xdalgoenv_t xenv;
	diffdata_t dd1, dd2;

	if (XDF_DIFF_ALG(xpp->flags) == XDF_PATIENCE_DIFF)
		return xdl_do_patience_diff(mf1, mf2, xpp, xe);

	if (XDF_DIFF_ALG(xpp->flags) == XDF_HISTOGRAM_DIFF)
		return xdl_do_histogram_diff(mf1, mf2, xpp, xe);

	if (xdl_prepare_env(mf1, mf2, xpp, xe) < 0) {

		return -1;
	}

	/*
	 * Allocate and setup K vectors to be used by the differential algorithm.
	 * One is to store the forward path and one to store the backward path.
	 */
	ndiags = xe->xdf1.nreff + xe->xdf2.nreff + 3;
	if (!(kvd = (long *) xdl_malloc((2 * ndiags + 2) * sizeof(long)))) {

		xdl_free_env(xe);
		return -1;
	}
	kvdf = kvd;
	kvdb = kvdf + ndiags;
	kvdf += xe->xdf2.nreff + 1;
	kvdb += xe->xdf2.nreff + 1;

	xenv.mxcost = xdl_bogosqrt(ndiags);
	if (xenv.mxcost < XDL_MAX_COST_MIN)
		xenv.mxcost = XDL_MAX_COST_MIN;
	xenv.snake_cnt = XDL_SNAKE_CNT;
	xenv.heur_min = XDL_HEUR_MIN_COST;

	dd1.nrec = xe->xdf1.nreff;
	dd1.ha = xe->xdf1.ha;
	dd1.rchg = xe->xdf1.rchg;
	dd1.rindex = xe->xdf1.rindex;
	dd2.nrec = xe->xdf2.nreff;
	dd2.ha = xe->xdf2.ha;
	dd2.rchg = xe->xdf2.rchg;
	dd2.rindex = xe->xdf2.rindex;

	if (xdl_recs_cmp(&dd1, 0, dd1.nrec, &dd2, 0, dd2.nrec,
			 kvdf, kvdb, (xpp->flags & XDF_NEED_MINIMAL) != 0, &xenv) < 0) {

		xdl_free(kvd);
		xdl_free_env(xe);
		return -1;
	}

	xdl_free(kvd);

	return 0;
}


static xdchange_t *xdl_add_change(xdchange_t *xscr, long i1, long i2, long chg1, long chg2) {
	xdchange_t *xch;

	if (!(xch = (xdchange_t *) xdl_malloc(sizeof(xdchange_t))))
		return NULL;

	xch->next = xscr;
	xch->i1 = i1;
	xch->i2 = i2;
	xch->chg1 = chg1;
	xch->chg2 = chg2;
	xch->ignore = 0;

	return xch;
}


static int recs_match(xrecord_t *rec1, xrecord_t *rec2, long flags)
{
	return (rec1->ha == rec2->ha &&
		xdl_recmatch(rec1->ptr, rec1->size,
			     rec2->ptr, rec2->size,
			     flags));
}

/*
 * If a line is indented more than this, xget_indent() just returns this value.
 * This avoids having to do absurd amounts of work for data that are not
 * human-readable text, and also ensures that the output of xget_indent fits within
 * an int.
 */
#define MAX_INDENT 200

/*
 * Return the amount of indentation of the specified line, treating TAB as 8
 * columns. Return -1 if line is empty or contains only whitespace. Clamp the
 * output value at MAX_INDENT.
 */
static int xget_indent(xrecord_t *rec)
{
	long i;
	int ret = 0;

	for (i = 0; i < rec->size; i++) {
		char c = rec->ptr[i];

		if (!XDL_ISSPACE(c))
			return ret;
		else if (c == ' ')
			ret += 1;
		else if (c == '\t')
			ret += 8 - ret % 8;
		/* ignore other whitespace characters */

		if (ret >= MAX_INDENT)
			return MAX_INDENT;
	}

	/* The line contains only whitespace. */
	return -1;
}

/*
 * If more than this number of consecutive blank rows are found, just return this
 * value. This avoids requiring O(N^2) work for pathological cases, and also
 * ensures that the output of score_split fits in an int.
 */
#define MAX_BLANKS 20

/* Characteristics measured about a hypothetical split position. */
struct split_measurement {
	/*
	 * Is the split at the end of the file (aside from any blank lines)?
	 */
	int end_of_file;

	/*
	 * How much is the line immediately following the split indented (or -1 if
	 * the line is blank):
	 */
	int indent;

	/*
	 * How many consecutive lines above the split are blank?
	 */
	int pre_blank;

	/*
	 * How much is the nearest non-blank line above the split indented (or -1
	 * if there is no such line)?
	 */
	int pre_indent;

	/*
	 * How many lines after the line following the split are blank?
	 */
	int post_blank;

	/*
	 * How much is the nearest non-blank line after the line following the
	 * split indented (or -1 if there is no such line)?
	 */
	int post_indent;
};

struct split_score {
	/* The effective indent of this split (smaller is preferred). */
	int effective_indent;

	/* Penalty for this split (smaller is preferred). */
	int penalty;
};

/*
 * Fill m with information about a hypothetical split of xdf above line split.
 */
static void measure_split(const xdfile_t *xdf, long split,
			  struct split_measurement *m)
{
	long i;

	if (split >= xdf->nrec) {
		m->end_of_file = 1;
		m->indent = -1;
	} else {
		m->end_of_file = 0;
		m->indent = xget_indent(xdf->recs[split]);
	}

	m->pre_blank = 0;
	m->pre_indent = -1;
	for (i = split - 1; i >= 0; i--) {
		m->pre_indent = xget_indent(xdf->recs[i]);
		if (m->pre_indent != -1)
			break;
		m->pre_blank += 1;
		if (m->pre_blank == MAX_BLANKS) {
			m->pre_indent = 0;
			break;
		}
	}

	m->post_blank = 0;
	m->post_indent = -1;
	for (i = split + 1; i < xdf->nrec; i++) {
		m->post_indent = xget_indent(xdf->recs[i]);
		if (m->post_indent != -1)
			break;
		m->post_blank += 1;
		if (m->post_blank == MAX_BLANKS) {
			m->post_indent = 0;
			break;
		}
	}
}

/*
 * The empirically-determined weight factors used by score_split() below.
 * Larger values means that the position is a less favorable place to split.
 *
 * Note that scores are only ever compared against each other, so multiplying
 * all of these weight/penalty values by the same factor wouldn't change the
 * heuristic's behavior. Still, we need to set that arbitrary scale *somehow*.
 * In practice, these numbers are chosen to be large enough that they can be
 * adjusted relative to each other with sufficient precision despite using
 * integer math.
 */

/* Penalty if there are no non-blank lines before the split */
#define START_OF_FILE_PENALTY 1

/* Penalty if there are no non-blank lines after the split */
#define END_OF_FILE_PENALTY 21

/* Multiplier for the number of blank lines around the split */
#define TOTAL_BLANK_WEIGHT (-30)

/* Multiplier for the number of blank lines after the split */
#define POST_BLANK_WEIGHT 6

/*
 * Penalties applied if the line is indented more than its predecessor
 */
#define RELATIVE_INDENT_PENALTY (-4)
#define RELATIVE_INDENT_WITH_BLANK_PENALTY 10

/*
 * Penalties applied if the line is indented less than both its predecessor and
 * its successor
 */
#define RELATIVE_OUTDENT_PENALTY 24
#define RELATIVE_OUTDENT_WITH_BLANK_PENALTY 17

/*
 * Penalties applied if the line is indented less than its predecessor but not
 * less than its successor
 */
#define RELATIVE_DEDENT_PENALTY 23
#define RELATIVE_DEDENT_WITH_BLANK_PENALTY 17

/*
 * We only consider whether the sum of the effective indents for splits are
 * less than (-1), equal to (0), or greater than (+1) each other. The resulting
 * value is multiplied by the following weight and combined with the penalty to
 * determine the better of two scores.
 */
#define INDENT_WEIGHT 60

/*
 * How far do we slide a hunk at most?
 */
#define INDENT_HEURISTIC_MAX_SLIDING 100

/*
 * Compute a badness score for the hypothetical split whose measurements are
 * stored in m. The weight factors were determined empirically using the tools and
 * corpus described in
 *
 *     https://github.com/mhagger/diff-slider-tools
 *
 * Also see that project if you want to improve the weights based on, for example,
 * a larger or more diverse corpus.
 */
static void score_add_split(const struct split_measurement *m, struct split_score *s)
{
	/*
	 * A place to accumulate penalty factors (positive makes this index more
	 * favored):
	 */
	int post_blank, total_blank, indent, any_blanks;

	if (m->pre_indent == -1 && m->pre_blank == 0)
		s->penalty += START_OF_FILE_PENALTY;

	if (m->end_of_file)
		s->penalty += END_OF_FILE_PENALTY;

	/*
	 * Set post_blank to the number of blank lines following the split,
	 * including the line immediately after the split:
	 */
	post_blank = (m->indent == -1) ? 1 + m->post_blank : 0;
	total_blank = m->pre_blank + post_blank;

	/* Penalties based on nearby blank lines: */
	s->penalty += TOTAL_BLANK_WEIGHT * total_blank;
	s->penalty += POST_BLANK_WEIGHT * post_blank;

	if (m->indent != -1)
		indent = m->indent;
	else
		indent = m->post_indent;

	any_blanks = (total_blank != 0);

	/* Note that the effective indent is -1 at the end of the file: */
	s->effective_indent += indent;

	if (indent == -1) {
		/* No additional adjustments needed. */
	} else if (m->pre_indent == -1) {
		/* No additional adjustments needed. */
	} else if (indent > m->pre_indent) {
		/*
		 * The line is indented more than its predecessor.
		 */
		s->penalty += any_blanks ?
			RELATIVE_INDENT_WITH_BLANK_PENALTY :
			RELATIVE_INDENT_PENALTY;
	} else if (indent == m->pre_indent) {
		/*
		 * The line has the same indentation level as its predecessor.
		 * No additional adjustments needed.
		 */
	} else {
		/*
		 * The line is indented less than its predecessor. It could be
		 * the block terminator of the previous block, but it could
		 * also be the start of a new block (e.g., an "else" block, or
		 * maybe the previous block didn't have a block terminator).
		 * Try to distinguish those cases based on what comes next:
		 */
		if (m->post_indent != -1 && m->post_indent > indent) {
			/*
			 * The following line is indented more. So it is likely
			 * that this line is the start of a block.
			 */
			s->penalty += any_blanks ?
				RELATIVE_OUTDENT_WITH_BLANK_PENALTY :
				RELATIVE_OUTDENT_PENALTY;
		} else {
			/*
			 * That was probably the end of a block.
			 */
			s->penalty += any_blanks ?
				RELATIVE_DEDENT_WITH_BLANK_PENALTY :
				RELATIVE_DEDENT_PENALTY;
		}
	}
}

static int score_cmp(struct split_score *s1, struct split_score *s2)
{
	/* -1 if s1.effective_indent < s2->effective_indent, etc. */
	int cmp_indents = ((s1->effective_indent > s2->effective_indent) -
			   (s1->effective_indent < s2->effective_indent));

	return INDENT_WEIGHT * cmp_indents + (s1->penalty - s2->penalty);
}

/*
 * Represent a group of changed lines in an xdfile_t (i.e., a contiguous group
 * of lines that was inserted or deleted from the corresponding version of the
 * file). We consider there to be such a group at the beginning of the file, at
 * the end of the file, and between any two unchanged lines, though most such
 * groups will usually be empty.
 *
 * If the first line in a group is equal to the line following the group, then
 * the group can be slid down. Similarly, if the last line in a group is equal
 * to the line preceding the group, then the group can be slid up. See
 * group_slide_down() and group_slide_up().
 *
 * Note that loops that are testing for changed lines in xdf->rchg do not need
 * index bounding since the array is prepared with a zero at position -1 and N.
 */
struct xdlgroup {
	/*
	 * The index of the first changed line in the group, or the index of
	 * the unchanged line above which the (empty) group is located.
	 */
	long start;

	/*
	 * The index of the first unchanged line after the group. For an empty
	 * group, end is equal to start.
	 */
	long end;
};

/*
 * Initialize g to point at the first group in xdf.
 */
static void group_init(xdfile_t *xdf, struct xdlgroup *g)
{
	g->start = g->end = 0;
	while (xdf->rchg[g->end])
		g->end++;
}

/*
 * Move g to describe the next (possibly empty) group in xdf and return 0. If g
 * is already at the end of the file, do nothing and return -1.
 */
static inline int group_next(xdfile_t *xdf, struct xdlgroup *g)
{
	if (g->end == xdf->nrec)
		return -1;

	g->start = g->end + 1;
	for (g->end = g->start; xdf->rchg[g->end]; g->end++)
		;

	return 0;
}

/*
 * Move g to describe the previous (possibly empty) group in xdf and return 0.
 * If g is already at the beginning of the file, do nothing and return -1.
 */
static inline int group_previous(xdfile_t *xdf, struct xdlgroup *g)
{
	if (g->start == 0)
		return -1;

	g->end = g->start - 1;
	for (g->start = g->end; xdf->rchg[g->start - 1]; g->start--)
		;

	return 0;
}

/*
 * If g can be slid toward the end of the file, do so, and if it bumps into a
 * following group, expand this group to include it. Return 0 on success or -1
 * if g cannot be slid down.
 */
static int group_slide_down(xdfile_t *xdf, struct xdlgroup *g, long flags)
{
	if (g->end < xdf->nrec &&
	    recs_match(xdf->recs[g->start], xdf->recs[g->end], flags)) {
		xdf->rchg[g->start++] = 0;
		xdf->rchg[g->end++] = 1;

		while (xdf->rchg[g->end])
			g->end++;

		return 0;
	} else {
		return -1;
	}
}

/*
 * If g can be slid toward the beginning of the file, do so, and if it bumps
 * into a previous group, expand this group to include it. Return 0 on success
 * or -1 if g cannot be slid up.
 */
static int group_slide_up(xdfile_t *xdf, struct xdlgroup *g, long flags)
{
	if (g->start > 0 &&
	    recs_match(xdf->recs[g->start - 1], xdf->recs[g->end - 1], flags)) {
		xdf->rchg[--g->start] = 1;
		xdf->rchg[--g->end] = 0;

		while (xdf->rchg[g->start - 1])
			g->start--;

		return 0;
	} else {
		return -1;
	}
}

static void xdl_bug(const char *msg)
{
	fprintf(stderr, "BUG: %s\n", msg);
	exit(1);
}

/*
 * Move back and forward change groups for a consistent and pretty diff output.
 * This also helps in finding joinable change groups and reducing the diff
 * size.
 */
int xdl_change_compact(xdfile_t *xdf, xdfile_t *xdfo, long flags) {
	struct xdlgroup g, go;
	long earliest_end, end_matching_other;
	long groupsize;

	group_init(xdf, &g);
	group_init(xdfo, &go);

	while (1) {
		/* If the group is empty in the to-be-compacted file, skip it: */
		if (g.end == g.start)
			goto next;

		/*
		 * Now shift the change up and then down as far as possible in
		 * each direction. If it bumps into any other changes, merge them.
		 */
		do {
			groupsize = g.end - g.start;

			/*
			 * Keep track of the last "end" index that causes this
			 * group to align with a group of changed lines in the
			 * other file. -1 indicates that we haven't found such
			 * a match yet:
			 */
			end_matching_other = -1;

			/* Shift the group backward as much as possible: */
			while (!group_slide_up(xdf, &g, flags))
				if (group_previous(xdfo, &go))
					xdl_bug("group sync broken sliding up");

			/*
			 * This is this highest that this group can be shifted.
			 * Record its end index:
			 */
			earliest_end = g.end;

			if (go.end > go.start)
				end_matching_other = g.end;

			/* Now shift the group forward as far as possible: */
			while (1) {
				if (group_slide_down(xdf, &g, flags))
					break;
				if (group_next(xdfo, &go))
					xdl_bug("group sync broken sliding down");

				if (go.end > go.start)
					end_matching_other = g.end;
			}
		} while (groupsize != g.end - g.start);

		/*
		 * If the group can be shifted, then we can possibly use this
		 * freedom to produce a more intuitive diff.
		 *
		 * The group is currently shifted as far down as possible, so the
		 * heuristics below only have to handle upwards shifts.
		 */

		if (g.end == earliest_end) {
			/* no shifting was possible */
		} else if (end_matching_other != -1) {
			/*
			 * Move the possibly merged group of changes back to line
			 * up with the last group of changes from the other file
			 * that it can align with.
			 */
			while (go.end == go.start) {
				if (group_slide_up(xdf, &g, flags))
					xdl_bug("match disappeared");
				if (group_previous(xdfo, &go))
					xdl_bug("group sync broken sliding to match");
			}
		} else if (flags & XDF_INDENT_HEURISTIC) {
			/*
			 * Indent heuristic: a group of pure add/delete lines
			 * implies two splits, one between the end of the "before"
			 * context and the start of the group, and another between
			 * the end of the group and the beginning of the "after"
			 * context. Some splits are aesthetically better and some
			 * are worse. We compute a badness "score" for each split,
			 * and add the scores for the two splits to define a
			 * "score" for each position that the group can be shifted
			 * to. Then we pick the shift with the lowest score.
			 */
			long shift, best_shift = -1;
			struct split_score best_score;

			shift = earliest_end;
			if (g.end - groupsize - 1 > shift)
				shift = g.end - groupsize - 1;
			if (g.end - INDENT_HEURISTIC_MAX_SLIDING > shift)
				shift = g.end - INDENT_HEURISTIC_MAX_SLIDING;
			for (; shift <= g.end; shift++) {
				struct split_measurement m;
				struct split_score score = {0, 0};

				measure_split(xdf, shift, &m);
				score_add_split(&m, &score);
				measure_split(xdf, shift - groupsize, &m);
				score_add_split(&m, &score);
				if (best_shift == -1 ||
				    score_cmp(&score, &best_score) <= 0) {
					best_score.effective_indent = score.effective_indent;
					best_score.penalty = score.penalty;
					best_shift = shift;
				}
			}

			while (g.end > best_shift) {
				if (group_slide_up(xdf, &g, flags))
					xdl_bug("best shift unreached");
				if (group_previous(xdfo, &go))
					xdl_bug("group sync broken sliding to blank line");
			}
		}

	next:
		/* Move past the just-processed group: */
		if (group_next(xdf, &g))
			break;
		if (group_next(xdfo, &go))
			xdl_bug("group sync broken moving to next group");
	}

	if (!group_next(xdfo, &go))
		xdl_bug("group sync broken at end of file");

	return 0;
}


int xdl_build_script(xdfenv_t *xe, xdchange_t **xscr) {
	xdchange_t *cscr = NULL, *xch;
	char *rchg1 = xe->xdf1.rchg, *rchg2 = xe->xdf2.rchg;
	long i1, i2, l1, l2;

	/*
	 * Trivial. Collects "groups" of changes and creates an edit script.
	 */
	for (i1 = xe->xdf1.nrec, i2 = xe->xdf2.nrec; i1 >= 0 || i2 >= 0; i1--, i2--)
		if (rchg1[i1 - 1] || rchg2[i2 - 1]) {
			for (l1 = i1; rchg1[i1 - 1]; i1--);
			for (l2 = i2; rchg2[i2 - 1]; i2--);

			if (!(xch = xdl_add_change(cscr, i1, i2, l1 - i1, l2 - i2))) {
				xdl_free_script(cscr);
				return -1;
			}
			cscr = xch;
		}

	*xscr = cscr;

	return 0;
}


void xdl_free_script(xdchange_t *xscr) {
	xdchange_t *xch;

	while ((xch = xscr) != NULL) {
		xscr = xscr->next;
		xdl_free(xch);
	}
}

static int xdl_call_hunk_func(xdfenv_t *xe UNUSED, xdchange_t *xscr, xdemitcb_t *ecb,
			      xdemitconf_t const *xecfg)
{
	xdchange_t *xch, *xche;

	for (xch = xscr; xch; xch = xche->next) {
		xche = xdl_get_hunk(&xch, xecfg);
		if (!xch)
			break;
		if (xecfg->hunk_func(xch->i1, xche->i1 + xche->chg1 - xch->i1,
				     xch->i2, xche->i2 + xche->chg2 - xch->i2,
				     ecb->priv) < 0)
			return -1;
	}
	return 0;
}

static void xdl_mark_ignorable(xdchange_t *xscr, xdfenv_t *xe, long flags)
{
	xdchange_t *xch;

	for (xch = xscr; xch; xch = xch->next) {
		int ignore = 1;
		xrecord_t **rec;
		long i;

		rec = &xe->xdf1.recs[xch->i1];
		for (i = 0; i < xch->chg1 && ignore; i++)
			ignore = xdl_blankline(rec[i]->ptr, rec[i]->size, flags);

		rec = &xe->xdf2.recs[xch->i2];
		for (i = 0; i < xch->chg2 && ignore; i++)
			ignore = xdl_blankline(rec[i]->ptr, rec[i]->size, flags);

		xch->ignore = ignore;
	}
}

int xdl_diff(mmfile_t *mf1, mmfile_t *mf2, xpparam_t const *xpp,
	     xdemitconf_t const *xecfg, xdemitcb_t *ecb) {
	xdchange_t *xscr;
	xdfenv_t xe;
	emit_func_t ef = xecfg->hunk_func ? xdl_call_hunk_func : xdl_emit_diff;

	if (xdl_do_diff(mf1, mf2, xpp, &xe) < 0) {

		return -1;
	}
	if (xdl_change_compact(&xe.xdf1, &xe.xdf2, xpp->flags) < 0 ||
	    xdl_change_compact(&xe.xdf2, &xe.xdf1, xpp->flags) < 0 ||
	    xdl_build_script(&xe, &xscr) < 0) {

		xdl_free_env(&xe);
		return -1;
	}
	if (xscr) {
		if (xpp->flags & XDF_IGNORE_BLANK_LINES)
			xdl_mark_ignorable(xscr, &xe, xpp->flags);

		if (ef(&xe, xscr, ecb, xecfg) < 0) {

			xdl_free_script(xscr);
			xdl_free_env(&xe);
			return -1;
		}
		xdl_free_script(xscr);
	}
	xdl_free_env(&xe);

	return 0;
}
