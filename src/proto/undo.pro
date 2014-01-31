/* undo.c */
int u_save_cursor __ARGS((void));
int u_save __ARGS((linenr_T top, linenr_T bot));
int u_savesub __ARGS((linenr_T lnum));
int u_inssub __ARGS((linenr_T lnum));
int u_savedel __ARGS((linenr_T lnum, long nlines));
int undo_allowed __ARGS((void));
int u_savecommon __ARGS((linenr_T top, linenr_T bot, linenr_T newbot,
                         int reload));
void u_compute_hash __ARGS((char_u *hash));
char_u *u_get_undo_file_name __ARGS((char_u *buf_ffname, int reading));
void u_write_undo __ARGS((char_u *name, int forceit, buf_T *buf, char_u *hash));
void u_read_undo __ARGS((char_u *name, char_u *hash, char_u *orig_name));
void u_undo __ARGS((int count));
void u_redo __ARGS((int count));
void undo_time __ARGS((long step, int sec, int file, int absolute));
void u_sync __ARGS((int force));
void ex_undolist __ARGS((exarg_T *eap));
void ex_undojoin __ARGS((exarg_T *eap));
void u_unchanged __ARGS((buf_T *buf));
void u_find_first_changed __ARGS((void));
void u_update_save_nr __ARGS((buf_T *buf));
void u_clearall __ARGS((buf_T *buf));
void u_saveline __ARGS((linenr_T lnum));
void u_clearline __ARGS((void));
void u_undoline __ARGS((void));
void u_blockfree __ARGS((buf_T *buf));
int bufIsChanged __ARGS((buf_T *buf));
int curbufIsChanged __ARGS((void));
void u_eval_tree __ARGS((u_header_T *first_uhp, list_T *list));
/* vim: set ft=c : */
