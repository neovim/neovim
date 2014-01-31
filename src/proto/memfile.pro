/* memfile.c */
memfile_T *mf_open __ARGS((char_u *fname, int flags));
int mf_open_file __ARGS((memfile_T *mfp, char_u *fname));
void mf_close __ARGS((memfile_T *mfp, int del_file));
void mf_close_file __ARGS((buf_T *buf, int getlines));
void mf_new_page_size __ARGS((memfile_T *mfp, unsigned new_size));
bhdr_T *mf_new __ARGS((memfile_T *mfp, int negative, int page_count));
bhdr_T *mf_get __ARGS((memfile_T *mfp, blocknr_T nr, int page_count));
void mf_put __ARGS((memfile_T *mfp, bhdr_T *hp, int dirty, int infile));
void mf_free __ARGS((memfile_T *mfp, bhdr_T *hp));
int mf_sync __ARGS((memfile_T *mfp, int flags));
void mf_set_dirty __ARGS((memfile_T *mfp));
int mf_release_all __ARGS((void));
blocknr_T mf_trans_del __ARGS((memfile_T *mfp, blocknr_T old_nr));
void mf_set_ffname __ARGS((memfile_T *mfp));
void mf_fullname __ARGS((memfile_T *mfp));
int mf_need_trans __ARGS((memfile_T *mfp));
/* vim: set ft=c : */
