#ifndef NVIM_MEMFILE_H
#define NVIM_MEMFILE_H

#include "nvim/buffer_defs.h"
#include "nvim/memfile_defs.h"

/* flags for mf_sync() */
#define MFS_ALL         1       /* also sync blocks with negative numbers */
#define MFS_STOP        2       /* stop syncing when a character is available */
#define MFS_FLUSH       4       /* flushed file to disk */
#define MFS_ZERO        8       /* only write block 0 */


/* memfile.c */
memfile_T *mf_open(char_u *fname, int flags);
int mf_open_file(memfile_T *mfp, char_u *fname);
void mf_close(memfile_T *mfp, int del_file);
void mf_close_file(buf_T *buf, int getlines);
void mf_new_page_size(memfile_T *mfp, unsigned new_size);
bhdr_T *mf_new(memfile_T *mfp, int negative, int page_count);
bhdr_T *mf_get(memfile_T *mfp, blocknr_T nr, int page_count);
void mf_put(memfile_T *mfp, bhdr_T *hp, int dirty, int infile);
void mf_free(memfile_T *mfp, bhdr_T *hp);
int mf_sync(memfile_T *mfp, int flags);
void mf_set_dirty(memfile_T *mfp);
int mf_release_all(void);
blocknr_T mf_trans_del(memfile_T *mfp, blocknr_T old_nr);
void mf_set_ffname(memfile_T *mfp);
void mf_fullname(memfile_T *mfp);
int mf_need_trans(memfile_T *mfp);

#endif /* NVIM_MEMFILE_H */
