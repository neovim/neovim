#ifndef NEOVIM_WINDOW_H
#define NEOVIM_WINDOW_H
/* window.c */
void do_window __ARGS((int nchar, long Prenum, int xchar));
int win_split __ARGS((int size, int flags));
int win_split_ins __ARGS((int size, int flags, win_T *new_wp, int dir));
int win_valid __ARGS((win_T *win));
int win_count __ARGS((void));
int make_windows __ARGS((int count, int vertical));
void win_move_after __ARGS((win_T *win1, win_T *win2));
void win_equal __ARGS((win_T *next_curwin, int current, int dir));
void close_windows __ARGS((buf_T *buf, int keep_curwin));
int one_window __ARGS((void));
int win_close __ARGS((win_T *win, int free_buf));
void win_close_othertab __ARGS((win_T *win, int free_buf, tabpage_T *tp));
void win_free_all __ARGS((void));
win_T *winframe_remove __ARGS((win_T *win, int *dirp, tabpage_T *tp));
void close_others __ARGS((int message, int forceit));
void curwin_init __ARGS((void));
void win_init_empty __ARGS((win_T *wp));
int win_alloc_first __ARGS((void));
void win_alloc_aucmd_win __ARGS((void));
void win_init_size __ARGS((void));
void free_tabpage __ARGS((tabpage_T *tp));
int win_new_tabpage __ARGS((int after));
int may_open_tabpage __ARGS((void));
int make_tabpages __ARGS((int maxcount));
int valid_tabpage __ARGS((tabpage_T *tpc));
tabpage_T *find_tabpage __ARGS((int n));
int tabpage_index __ARGS((tabpage_T *ftp));
void goto_tabpage __ARGS((int n));
void goto_tabpage_tp __ARGS((tabpage_T *tp, int trigger_enter_autocmds,
                             int trigger_leave_autocmds));
void goto_tabpage_win __ARGS((tabpage_T *tp, win_T *wp));
void tabpage_move __ARGS((int nr));
void win_goto __ARGS((win_T *wp));
win_T *win_find_nr __ARGS((int winnr));
tabpage_T *win_find_tabpage __ARGS((win_T *win));
void win_enter __ARGS((win_T *wp, int undo_sync));
win_T *buf_jump_open_win __ARGS((buf_T *buf));
win_T *buf_jump_open_tab __ARGS((buf_T *buf));
void win_append __ARGS((win_T *after, win_T *wp));
void win_remove __ARGS((win_T *wp, tabpage_T *tp));
int win_alloc_lines __ARGS((win_T *wp));
void win_free_lsize __ARGS((win_T *wp));
void shell_new_rows __ARGS((void));
void shell_new_columns __ARGS((void));
void win_size_save __ARGS((garray_T *gap));
void win_size_restore __ARGS((garray_T *gap));
int win_comp_pos __ARGS((void));
void win_setheight __ARGS((int height));
void win_setheight_win __ARGS((int height, win_T *win));
void win_setwidth __ARGS((int width));
void win_setwidth_win __ARGS((int width, win_T *wp));
void win_setminheight __ARGS((void));
void win_drag_status_line __ARGS((win_T *dragwin, int offset));
void win_drag_vsep_line __ARGS((win_T *dragwin, int offset));
void win_new_height __ARGS((win_T *wp, int height));
void win_new_width __ARGS((win_T *wp, int width));
void win_comp_scroll __ARGS((win_T *wp));
void command_height __ARGS((void));
void last_status __ARGS((int morewin));
int tabline_height __ARGS((void));
char_u *grab_file_name __ARGS((long count, linenr_T *file_lnum));
char_u *file_name_at_cursor __ARGS((int options, long count,
                                    linenr_T *file_lnum));
char_u *file_name_in_line __ARGS((char_u *line, int col, int options,
                                  long count, char_u *rel_fname,
                                  linenr_T *file_lnum));
char_u *find_file_name_in_path __ARGS((char_u *ptr, int len, int options,
                                       long count,
                                       char_u *rel_fname));
int path_with_url __ARGS((char_u *fname));
int vim_isAbsName __ARGS((char_u *name));
int vim_FullName __ARGS((char_u *fname, char_u *buf, int len, int force));
int min_rows __ARGS((void));
int only_one_window __ARGS((void));
void check_lnums __ARGS((int do_curwin));
void make_snapshot __ARGS((int idx));
void restore_snapshot __ARGS((int idx, int close_curwin));
int switch_win __ARGS((win_T **save_curwin, tabpage_T **save_curtab, win_T *win,
                       tabpage_T *tp,
                       int no_display));
void restore_win __ARGS((win_T *save_curwin, tabpage_T *save_curtab,
                         int no_display));
void switch_buffer __ARGS((buf_T **save_curbuf, buf_T *buf));
void restore_buffer __ARGS((buf_T *save_curbuf));
int win_hasvertsplit __ARGS((void));
int match_add __ARGS((win_T *wp, char_u *grp, char_u *pat, int prio, int id));
int match_delete __ARGS((win_T *wp, int id, int perr));
void clear_matches __ARGS((win_T *wp));
matchitem_T *get_match __ARGS((win_T *wp, int id));
int get_win_number __ARGS((win_T *wp, win_T *first_win));
int get_tab_number __ARGS((tabpage_T *tp));
/* vim: set ft=c : */
#endif /* NEOVIM_WINDOW_H */
