#ifndef NEOVIM_WINDOW_H
#define NEOVIM_WINDOW_H
/* window.c */
void do_window(int nchar, long Prenum, int xchar);
int win_split(int size, int flags);
int win_split_ins(int size, int flags, win_T *new_wp, int dir);
int win_valid(win_T *win);
int win_count(void);
int make_windows(int count, int vertical);
void win_move_after(win_T *win1, win_T *win2);
void win_equal(win_T *next_curwin, int current, int dir);
void close_windows(buf_T *buf, int keep_curwin);
int one_window(void);
int win_close(win_T *win, int free_buf);
void win_close_othertab(win_T *win, int free_buf, tabpage_T *tp);
void win_free_all(void);
win_T *winframe_remove(win_T *win, int *dirp, tabpage_T *tp);
void close_others(int message, int forceit);
void curwin_init(void);
void win_init_empty(win_T *wp);
int win_alloc_first(void);
void win_alloc_aucmd_win(void);
void win_init_size(void);
void free_tabpage(tabpage_T *tp);
int win_new_tabpage(int after);
int may_open_tabpage(void);
int make_tabpages(int maxcount);
int valid_tabpage(tabpage_T *tpc);
tabpage_T *find_tabpage(int n);
int tabpage_index(tabpage_T *ftp);
void goto_tabpage(int n);
void goto_tabpage_tp(tabpage_T *tp, int trigger_enter_autocmds,
                     int trigger_leave_autocmds);
void goto_tabpage_win(tabpage_T *tp, win_T *wp);
void tabpage_move(int nr);
void win_goto(win_T *wp);
win_T *win_find_nr(int winnr);
tabpage_T *win_find_tabpage(win_T *win);
void win_enter(win_T *wp, int undo_sync);
win_T *buf_jump_open_win(buf_T *buf);
win_T *buf_jump_open_tab(buf_T *buf);
void win_append(win_T *after, win_T *wp);
void win_remove(win_T *wp, tabpage_T *tp);
int win_alloc_lines(win_T *wp);
void win_free_lsize(win_T *wp);
void shell_new_rows(void);
void shell_new_columns(void);
void win_size_save(garray_T *gap);
void win_size_restore(garray_T *gap);
int win_comp_pos(void);
void win_setheight(int height);
void win_setheight_win(int height, win_T *win);
void win_setwidth(int width);
void win_setwidth_win(int width, win_T *wp);
void win_setminheight(void);
void win_drag_status_line(win_T *dragwin, int offset);
void win_drag_vsep_line(win_T *dragwin, int offset);
void win_new_height(win_T *wp, int height);
void win_new_width(win_T *wp, int width);
void win_comp_scroll(win_T *wp);
void command_height(void);
void last_status(int morewin);
int tabline_height(void);
char_u *grab_file_name(long count, linenr_T *file_lnum);
char_u *file_name_at_cursor(int options, long count,
                            linenr_T *file_lnum);
char_u *file_name_in_line(char_u *line, int col, int options,
                          long count, char_u *rel_fname,
                          linenr_T *file_lnum);
char_u *find_file_name_in_path(char_u *ptr, int len, int options,
                               long count,
                               char_u *rel_fname);
int path_with_url(char_u *fname);
int vim_isAbsName(char_u *name);
int vim_FullName(char_u *fname, char_u *buf, int len, int force);
int min_rows(void);
int only_one_window(void);
void check_lnums(int do_curwin);
void make_snapshot(int idx);
void restore_snapshot(int idx, int close_curwin);
int switch_win(win_T **save_curwin, tabpage_T **save_curtab, win_T *win,
               tabpage_T *tp,
               int no_display);
void restore_win(win_T *save_curwin, tabpage_T *save_curtab,
                 int no_display);
void switch_buffer(buf_T **save_curbuf, buf_T *buf);
void restore_buffer(buf_T *save_curbuf);
int win_hasvertsplit(void);
int match_add(win_T *wp, char_u *grp, char_u *pat, int prio, int id);
int match_delete(win_T *wp, int id, int perr);
void clear_matches(win_T *wp);
matchitem_T *get_match(win_T *wp, int id);
int get_win_number(win_T *wp, win_T *first_win);
int get_tab_number(tabpage_T *tp);
/* vim: set ft=c : */
#endif /* NEOVIM_WINDOW_H */
