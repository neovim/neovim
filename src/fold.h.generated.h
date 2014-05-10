int put_folds(FILE *fd, win_T *wp);
void foldtext_cleanup(char_u *str);
char_u *get_foldtext(win_T *wp, linenr_T lnum, linenr_T lnume,
                     foldinfo_T *foldinfo,
                     char_u *buf);
int getDeepestNesting(void);
void foldMarkAdjust(win_T *wp, linenr_T line1, linenr_T line2,
                    long amount,
                    long amount_after);
void deleteFoldRecurse(garray_T *gap);
void cloneFoldGrowArray(garray_T *from, garray_T *to);
void foldAdjustCursor(void);
void foldAdjustVisual(void);
int find_wl_entry(win_T *win, linenr_T lnum);
void foldInitWin(win_T *new_win);
int foldMoveTo(int updown, int dir, long count);
void foldUpdateAll(win_T *win);
void foldUpdate(win_T *wp, linenr_T top, linenr_T bot);
void clearFolding(win_T *win);
void deleteFold(linenr_T start, linenr_T end, int recursive,
                int had_visual);
void foldCreate(linenr_T start, linenr_T end);
int foldManualAllowed(int create);
void foldCheckClose(void);
void newFoldLevel(void);
void foldOpenCursor(void);
void openFoldRecurse(linenr_T lnum);
void openFold(linenr_T lnum, long count);
void opFoldRange(linenr_T first, linenr_T last, int opening,
                 int recurse,
                 int had_visual);
void closeFoldRecurse(linenr_T lnum);
void closeFold(linenr_T lnum, long count);
int foldmethodIsDiff(win_T *wp);
int foldmethodIsSyntax(win_T *wp);
int foldmethodIsMarker(win_T *wp);
int foldmethodIsExpr(win_T *wp);
int foldmethodIsIndent(win_T *wp);
int foldmethodIsManual(win_T *wp);
long foldedCount(win_T *win, linenr_T lnum, foldinfo_T *infop);
int lineFolded(win_T *win, linenr_T lnum);
int foldLevel(linenr_T lnum);
int hasFoldingWin(win_T *win, linenr_T lnum, linenr_T *firstp,
                  linenr_T *lastp, int cache,
                  foldinfo_T *infop);
int hasFolding(linenr_T lnum, linenr_T *firstp, linenr_T *lastp);
int hasAnyFolding(win_T *win);
void copyFoldingState(win_T *wp_from, win_T *wp_to);
