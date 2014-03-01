#ifndef NEOVIM_FOLD_H
#define NEOVIM_FOLD_H
/* fold.c */
void copyFoldingState(win_T *wp_from, win_T *wp_to);
int hasAnyFolding(win_T *win);
int hasFolding(linenr_T lnum, linenr_T *firstp, linenr_T *lastp);
int hasFoldingWin(win_T *win, linenr_T lnum, linenr_T *firstp,
                  linenr_T *lastp, int cache,
                  foldinfo_T *infop);
int foldLevel(linenr_T lnum);
int lineFolded(win_T *win, linenr_T lnum);
long foldedCount(win_T *win, linenr_T lnum, foldinfo_T *infop);
int foldmethodIsManual(win_T *wp);
int foldmethodIsIndent(win_T *wp);
int foldmethodIsExpr(win_T *wp);
int foldmethodIsMarker(win_T *wp);
int foldmethodIsSyntax(win_T *wp);
int foldmethodIsDiff(win_T *wp);
void closeFold(linenr_T lnum, long count);
void closeFoldRecurse(linenr_T lnum);
void opFoldRange(linenr_T first, linenr_T last, int opening,
                 int recurse,
                 int had_visual);
void openFold(linenr_T lnum, long count);
void openFoldRecurse(linenr_T lnum);
void foldOpenCursor(void);
void newFoldLevel(void);
void foldCheckClose(void);
int foldManualAllowed(int create);
void foldCreate(linenr_T start, linenr_T end);
void deleteFold(linenr_T start, linenr_T end, int recursive,
                int had_visual);
void clearFolding(win_T *win);
void foldUpdate(win_T *wp, linenr_T top, linenr_T bot);
void foldUpdateAll(win_T *win);
int foldMoveTo(int updown, int dir, long count);
void foldInitWin(win_T *new_win);
int find_wl_entry(win_T *win, linenr_T lnum);
void foldAdjustVisual(void);
void foldAdjustCursor(void);
void cloneFoldGrowArray(garray_T *from, garray_T *to);
void deleteFoldRecurse(garray_T *gap);
void foldMarkAdjust(win_T *wp, linenr_T line1, linenr_T line2,
                    long amount,
                    long amount_after);
int getDeepestNesting(void);
char_u *get_foldtext(win_T *wp, linenr_T lnum, linenr_T lnume,
                     foldinfo_T *foldinfo,
                     char_u *buf);
void foldtext_cleanup(char_u *str);
int put_folds(FILE *fd, win_T *wp);
/* vim: set ft=c : */
#endif /* NEOVIM_FOLD_H */
