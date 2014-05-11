#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static int qf_init_ext(qf_info_T *qi, char_u *efile, buf_T *buf, typval_T *tv, char_u *errorformat, int newlist, linenr_T lnumfirst, linenr_T lnumlast, char_u *qf_title);
static void qf_new_list(qf_info_T *qi, char_u *qf_title);
static void ll_free_all(qf_info_T **pqi);
static int qf_add_entry(qf_info_T *qi, qfline_T **prevp, char_u *dir, char_u *fname, int bufnum, char_u *mesg, long lnum, int col, int vis_col, char_u *pattern, int nr, int type, int valid);
static qf_info_T *ll_new_list(void);
static qf_info_T *ll_get_or_alloc_list(win_T *wp);
static int qf_get_fnum(char_u *directory, char_u *fname);
static char_u *qf_push_dir(char_u *dirbuf, struct dir_stack_T **stackptr);
static char_u *qf_pop_dir(struct dir_stack_T **stackptr);
static void qf_clean_dir_stack(struct dir_stack_T **stackptr);
static char_u *qf_guess_filepath(char_u *filename);
static void qf_fmt_text(char_u *text, char_u *buf, int bufsize);
static void qf_msg(qf_info_T *qi);
static void qf_free(qf_info_T *qi, int idx);
static char_u *qf_types(int c, int nr);
static int qf_win_pos_update(qf_info_T *qi, int old_qf_index);
static int is_qf_win(win_T *win, qf_info_T *qi);
static win_T *qf_find_win(qf_info_T *qi);
static buf_T *qf_find_buf(qf_info_T *qi);
static void qf_update_buffer(qf_info_T *qi);
static void qf_set_title(qf_info_T *qi);
static void qf_fill_buffer(qf_info_T *qi);
static char_u *get_mef_name(void);
static void restore_start_dir(char_u *dirname_start);
static buf_T *load_dummy_buffer(char_u *fname, char_u *dirname_start, char_u *resulting_dir);
static void wipe_dummy_buffer(buf_T *buf, char_u *dirname_start);
static void unload_dummy_buffer(buf_T *buf, char_u *dirname_start);
#include "func_attr.h"
