/*
 *  LibXDiff by Davide Libenzi ( File Differential Library )
 *  Copyright (C) 2003  Davide Libenzi
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

#if !defined(XDIFFI_H)
#define XDIFFI_H


typedef struct s_diffdata {
	long nrec;
	unsigned long const *ha;
	long *rindex;
	char *rchg;
} diffdata_t;

typedef struct s_xdalgoenv {
	long mxcost;
	long snake_cnt;
	long heur_min;
} xdalgoenv_t;

typedef struct s_xdchange {
	struct s_xdchange *next;
	long i1, i2;
	long chg1, chg2;
	int ignore;
} xdchange_t;



int xdl_recs_cmp(diffdata_t *dd1, long off1, long lim1,
		 diffdata_t *dd2, long off2, long lim2,
		 long *kvdf, long *kvdb, int need_min, xdalgoenv_t *xenv);
int xdl_do_diff(mmfile_t *mf1, mmfile_t *mf2, xpparam_t const *xpp,
		xdfenv_t *xe);
int xdl_change_compact(xdfile_t *xdf, xdfile_t *xdfo, long flags);
int xdl_build_script(xdfenv_t *xe, xdchange_t **xscr);
void xdl_free_script(xdchange_t *xscr);
int xdl_emit_diff(xdfenv_t *xe, xdchange_t *xscr, xdemitcb_t *ecb,
		  xdemitconf_t const *xecfg);
int xdl_do_patience_diff(mmfile_t *mf1, mmfile_t *mf2, xpparam_t const *xpp,
		xdfenv_t *env);
int xdl_do_histogram_diff(mmfile_t *mf1, mmfile_t *mf2, xpparam_t const *xpp,
		xdfenv_t *env);

#endif /* #if !defined(XDIFFI_H) */
