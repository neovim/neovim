/* memline.c */
int ml_open __ARGS((buf_T *buf));
void ml_set_crypt_key __ARGS((buf_T *buf, char_u *old_key, int old_cm));
void ml_setname __ARGS((buf_T *buf));
void ml_open_files __ARGS((void));
void ml_open_file __ARGS((buf_T *buf));
void check_need_swap __ARGS((int newfile));
void ml_close __ARGS((buf_T *buf, int del_file));
void ml_close_all __ARGS((int del_file));
void ml_close_notmod __ARGS((void));
void ml_timestamp __ARGS((buf_T *buf));
void ml_recover __ARGS((void));
int recover_names __ARGS((char_u *fname, int list, int nr, char_u **fname_out));
void ml_sync_all __ARGS((int check_file, int check_char));
void ml_preserve __ARGS((buf_T *buf, int message));
char_u *ml_get __ARGS((linenr_T lnum));
char_u *ml_get_pos __ARGS((pos_T *pos));
char_u *ml_get_curline __ARGS((void));
char_u *ml_get_cursor __ARGS((void));
char_u *ml_get_buf __ARGS((buf_T *buf, linenr_T lnum, int will_change));
int ml_line_alloced __ARGS((void));
int ml_append __ARGS((linenr_T lnum, char_u *line, colnr_T len, int newfile));
int ml_append_buf __ARGS((buf_T *buf, linenr_T lnum, char_u *line, colnr_T len,
                          int newfile));
int ml_replace __ARGS((linenr_T lnum, char_u *line, int copy));
int ml_delete __ARGS((linenr_T lnum, int message));
void ml_setmarked __ARGS((linenr_T lnum));
linenr_T ml_firstmarked __ARGS((void));
void ml_clearmarked __ARGS((void));
int resolve_symlink __ARGS((char_u *fname, char_u *buf));
char_u *makeswapname __ARGS((char_u *fname, char_u *ffname, buf_T *buf,
                             char_u *dir_name));
char_u *get_file_in_dir __ARGS((char_u *fname, char_u *dname));
void ml_setflags __ARGS((buf_T *buf));
char_u *ml_encrypt_data __ARGS((memfile_T *mfp, char_u *data, off_t offset,
                                unsigned size));
void ml_decrypt_data __ARGS((memfile_T *mfp, char_u *data, off_t offset,
                             unsigned size));
long ml_find_line_or_offset __ARGS((buf_T *buf, linenr_T lnum, long *offp));
void goto_byte __ARGS((long cnt));
/* vim: set ft=c : */
