static int put_fold_open_close(FILE *fd, fold_T *fp, linenr_T off);
static int put_foldopen_recurse(FILE *fd, win_T *wp, garray_T *gap,
                                linenr_T off);
static int put_folds_recurse(FILE *fd, garray_T *gap, linenr_T off);
static void foldlevelSyntax(fline_T *flp);
static void foldlevelMarker(fline_T *flp);
static void foldlevelExpr(fline_T *flp);
static void foldlevelDiff(fline_T *flp);
static void foldlevelIndent(fline_T *flp);
static void foldMerge(fold_T *fp1, garray_T *gap, fold_T *fp2);
static void foldRemove(garray_T *gap, linenr_T top, linenr_T bot);
static void foldSplit(garray_T *gap, int i, linenr_T top, linenr_T bot);
static void foldInsert(garray_T *gap, int i);
static linenr_T foldUpdateIEMSRecurse(garray_T *gap, int level,
                                      linenr_T startlnum, fline_T *flp,
                                      void (*getlevel)(fline_T *), linenr_T bot,
                                      int topflags);
static void parseMarker(win_T *wp);
static void foldUpdateIEMS(win_T *wp, linenr_T top, linenr_T bot);
static void foldDelMarker(linenr_T lnum, char_u *marker, int markerlen);
static void deleteFoldMarkers(fold_T *fp, int recursive,
                              linenr_T lnum_off);
static void foldAddMarker(linenr_T lnum, char_u *marker, int markerlen);
static void foldCreateMarkers(linenr_T start, linenr_T end);
static void setSmallMaybe(garray_T *gap);
static void checkSmall(win_T *wp, fold_T *fp, linenr_T lnum_off);
static int check_closed(win_T *win, fold_T *fp, int *use_levelp,
                        int level, int *maybe_smallp,
                        linenr_T lnum_off);
static int getDeepestNestingRecurse(garray_T *gap);
static void foldMarkAdjustRecurse(garray_T *gap, linenr_T line1,
                                  linenr_T line2, long amount,
                                  long amount_after);
static void deleteFoldEntry(garray_T *gap, int idx, int recursive);
static void foldOpenNested(fold_T *fpr);
static linenr_T setManualFoldWin(win_T *wp, linenr_T lnum, int opening,
                                 int recurse,
                                 int *donep);
static linenr_T setManualFold(linenr_T lnum, int opening, int recurse,
                              int *donep);
static void setFoldRepeat(linenr_T lnum, long count, int do_open);
static void checkupdate(win_T *wp);
static int foldLevelWin(win_T *wp, linenr_T lnum);
static int foldFind(garray_T *gap, linenr_T lnum, fold_T **fpp);
static int checkCloseRec(garray_T *gap, linenr_T lnum, int level);
static void newFoldLevelWin(win_T *wp);
