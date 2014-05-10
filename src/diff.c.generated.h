static diff_T* diff_alloc_new(tabpage_T *tp, diff_T *dprev, diff_T *dp);
static void diff_copy_entry(diff_T *dprev, diff_T *dp, int idx_orig,
                            int idx_new);
static void diff_read(int idx_orig, int idx_new, char_u *fname);
static void diff_fold_update(diff_T *dp, int skip_idx);
static int diff_cmp(char_u *s1, char_u *s2);
static int diff_equal_entry(diff_T *dp, int idx1, int idx2);
static void diff_file(char_u *tmp_orig, char_u *tmp_new, char_u *tmp_diff);
static int diff_write(buf_T *buf, char_u *fname);
static void diff_redraw(int dofold);
static int diff_check_sanity(tabpage_T *tp, diff_T *dp);
static void diff_check_unchanged(tabpage_T *tp, diff_T *dp);
static void diff_mark_adjust_tp(tabpage_T *tp, int idx, linenr_T line1,
                                linenr_T line2, long amount,
                                long amount_after);
static int diff_buf_idx_tp(buf_T *buf, tabpage_T *tp);
static int diff_buf_idx(buf_T *buf);
