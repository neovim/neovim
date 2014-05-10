static void mf_hash_grow(mf_hashtab_T *);
static void mf_hash_rem_item(mf_hashtab_T *, mf_hashitem_T *);
static void mf_hash_add_item(mf_hashtab_T *, mf_hashitem_T *);
static mf_hashitem_T *mf_hash_find(mf_hashtab_T *, blocknr_T);
static void mf_hash_free_all(mf_hashtab_T *);
static void mf_hash_free(mf_hashtab_T *);
static void mf_hash_init(mf_hashtab_T *);
static void mf_do_open(memfile_T *, char_u *, int);
static int mf_trans_add(memfile_T *, bhdr_T *);
static int mf_write_block(memfile_T *mfp, bhdr_T *hp, off_t offset,
                          unsigned size);
static int mf_write(memfile_T *, bhdr_T *);
static int mf_read(memfile_T *, bhdr_T *);
static bhdr_T *mf_rem_free(memfile_T *);
static void mf_ins_free(memfile_T *, bhdr_T *);
static void mf_free_bhdr(bhdr_T *);
static bhdr_T *mf_alloc_bhdr(memfile_T *, int);
static bhdr_T *mf_release(memfile_T *, int);
static void mf_rem_used(memfile_T *, bhdr_T *);
static void mf_ins_used(memfile_T *, bhdr_T *);
static bhdr_T *mf_find_hash(memfile_T *, blocknr_T);
static void mf_rem_hash(memfile_T *, bhdr_T *);
static void mf_ins_hash(memfile_T *, bhdr_T *);
