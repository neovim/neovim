#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static void mf_ins_hash(memfile_T *mfp, bhdr_T *hp);
static void mf_rem_hash(memfile_T *mfp, bhdr_T *hp);
static bhdr_T *mf_find_hash(memfile_T *mfp, blocknr_T nr);
static void mf_ins_used(memfile_T *mfp, bhdr_T *hp);
static void mf_rem_used(memfile_T *mfp, bhdr_T *hp);
static bhdr_T *mf_release(memfile_T *mfp, int page_count);
static bhdr_T *mf_alloc_bhdr(memfile_T *mfp, int page_count);
static void mf_free_bhdr(bhdr_T *hp);
static void mf_ins_free(memfile_T *mfp, bhdr_T *hp);
static bhdr_T *mf_rem_free(memfile_T *mfp);
static int mf_read(memfile_T *mfp, bhdr_T *hp);
static int mf_write(memfile_T *mfp, bhdr_T *hp);
static int mf_write_block(memfile_T *mfp, bhdr_T *hp, off_t offset, unsigned size);
static int mf_trans_add(memfile_T *mfp, bhdr_T *hp);
static void mf_do_open(memfile_T *mfp, char_u *fname, int flags);
static void mf_hash_init(mf_hashtab_T *mht);
static void mf_hash_free(mf_hashtab_T *mht);
static void mf_hash_free_all(mf_hashtab_T *mht);
static mf_hashitem_T *mf_hash_find(mf_hashtab_T *mht, blocknr_T key);
static void mf_hash_add_item(mf_hashtab_T *mht, mf_hashitem_T *mhi);
static void mf_hash_rem_item(mf_hashtab_T *mht, mf_hashitem_T *mhi);
static void mf_hash_grow(mf_hashtab_T *mht);
#include "func_attr.h"
