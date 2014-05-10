static int64_t normalize_index(buf_T *buf, int64_t index);
static void fix_cursor(linenr_T lo, linenr_T hi, linenr_T extra);
static void restore_win_for_buf(win_T *save_curwin,
                                tabpage_T *save_curtab,
                                buf_T *save_curbuf);
static void switch_to_win_for_buf(buf_T *buf,
                                  win_T **save_curwinp,
                                  tabpage_T **save_curtabp,
                                  buf_T **save_curbufp);
static int64_t normalize_index(buf_T *buf, int64_t index);
static void fix_cursor(linenr_T lo, linenr_T hi, linenr_T extra);
static void restore_win_for_buf(win_T *save_curwin,
                                tabpage_T *save_curtab,
                                buf_T *save_curbuf);
static void switch_to_win_for_buf(buf_T *buf,
                                  win_T **save_curwinp,
                                  tabpage_T **save_curtabp,
                                  buf_T **save_curbufp);
