/* fold.c */
void copyFoldingState __ARGS((win_T *wp_from, win_T *wp_to));
int hasAnyFolding __ARGS((win_T *win));
int hasFolding __ARGS((linenr_T lnum, linenr_T *firstp, linenr_T *lastp));
int hasFoldingWin __ARGS((win_T *win, linenr_T lnum, linenr_T *firstp,
                          linenr_T *lastp, int cache,
                          foldinfo_T *infop));
int foldLevel __ARGS((linenr_T lnum));
int lineFolded __ARGS((win_T *win, linenr_T lnum));
long foldedCount __ARGS((win_T *win, linenr_T lnum, foldinfo_T *infop));
int foldmethodIsManual __ARGS((win_T *wp));
int foldmethodIsIndent __ARGS((win_T *wp));
int foldmethodIsExpr __ARGS((win_T *wp));
int foldmethodIsMarker __ARGS((win_T *wp));
int foldmethodIsSyntax __ARGS((win_T *wp));
int foldmethodIsDiff __ARGS((win_T *wp));
void closeFold __ARGS((linenr_T lnum, long count));
void closeFoldRecurse __ARGS((linenr_T lnum));
void opFoldRange __ARGS((linenr_T first, linenr_T last, int opening,
                         int recurse,
                         int had_visual));
void openFold __ARGS((linenr_T lnum, long count));
void openFoldRecurse __ARGS((linenr_T lnum));
void foldOpenCursor __ARGS((void));
void newFoldLevel __ARGS((void));
void foldCheckClose __ARGS((void));
int foldManualAllowed __ARGS((int create));
void foldCreate __ARGS((linenr_T start, linenr_T end));
void deleteFold __ARGS((linenr_T start, linenr_T end, int recursive,
                        int had_visual));
void clearFolding __ARGS((win_T *win));
void foldUpdate __ARGS((win_T *wp, linenr_T top, linenr_T bot));
void foldUpdateAll __ARGS((win_T *win));
int foldMoveTo __ARGS((int updown, int dir, long count));
void foldInitWin __ARGS((win_T *new_win));
int find_wl_entry __ARGS((win_T *win, linenr_T lnum));
void foldAdjustVisual __ARGS((void));
void foldAdjustCursor __ARGS((void));
void cloneFoldGrowArray __ARGS((garray_T *from, garray_T *to));
void deleteFoldRecurse __ARGS((garray_T *gap));
void foldMarkAdjust __ARGS((win_T *wp, linenr_T line1, linenr_T line2,
                            long amount,
                            long amount_after));
int getDeepestNesting __ARGS((void));
char_u *get_foldtext __ARGS((win_T *wp, linenr_T lnum, linenr_T lnume,
                             foldinfo_T *foldinfo,
                             char_u *buf));
void foldtext_cleanup __ARGS((char_u *str));
int put_folds __ARGS((FILE *fd, win_T *wp));
/* vim: set ft=c : */
