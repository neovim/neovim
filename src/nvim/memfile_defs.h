#ifndef NVIM_MEMFILE_DEFS_H
#define NVIM_MEMFILE_DEFS_H

#include "nvim/types.h"

typedef struct block_hdr bhdr_T;
typedef long blocknr_T;

/*
 * mf_hashtab_T is a chained hashtable with blocknr_T key and arbitrary
 * structures as items.  This is an intrusive data structure: we require
 * that items begin with mf_hashitem_T which contains the key and linked
 * list pointers.  List of items in each bucket is doubly-linked.
 */

typedef struct mf_hashitem_S mf_hashitem_T;

struct mf_hashitem_S {
  mf_hashitem_T   *mhi_next;
  mf_hashitem_T   *mhi_prev;
  blocknr_T mhi_key;
};

#define MHT_INIT_SIZE   64

typedef struct mf_hashtab_S {
  long_u mht_mask;                  /* mask used for hash value (nr of items
                                     * in array is "mht_mask" + 1) */
  long_u mht_count;                 /* nr of items inserted into hashtable */
  mf_hashitem_T   **mht_buckets;    /* points to mht_small_buckets or
                                     *dynamically allocated array */
  mf_hashitem_T   *mht_small_buckets[MHT_INIT_SIZE];     /* initial buckets */
  char mht_fixed;                   /* non-zero value forbids growth */
} mf_hashtab_T;

/*
 * for each (previously) used block in the memfile there is one block header.
 *
 * The block may be linked in the used list OR in the free list.
 * The used blocks are also kept in hash lists.
 *
 * The used list is a doubly linked list, most recently used block first.
 *	The blocks in the used list have a block of memory allocated.
 *	mf_used_count is the number of pages in the used list.
 * The hash lists are used to quickly find a block in the used list.
 * The free list is a single linked list, not sorted.
 *	The blocks in the free list have no block of memory allocated and
 *	the contents of the block in the file (if any) is irrelevant.
 */

struct block_hdr {
  mf_hashitem_T bh_hashitem;        /* header for hash table and key */
#define bh_bnum bh_hashitem.mhi_key /* block number, part of bh_hashitem */

  bhdr_T      *bh_next;             /* next block_hdr in free or used list */
  bhdr_T      *bh_prev;             /* previous block_hdr in used list */
  char_u      *bh_data;             /* pointer to memory (for used block) */
  int bh_page_count;                /* number of pages in this block */

#define BH_DIRTY    1
#define BH_LOCKED   2
  char bh_flags;                    /* BH_DIRTY or BH_LOCKED */
};

/*
 * when a block with a negative number is flushed to the file, it gets
 * a positive number. Because the reference to the block is still the negative
 * number, we remember the translation to the new positive number in the
 * double linked trans lists. The structure is the same as the hash lists.
 */
typedef struct nr_trans NR_TRANS;

struct nr_trans {
  mf_hashitem_T nt_hashitem;            /* header for hash table and key */
#define nt_old_bnum nt_hashitem.mhi_key /* old, negative, number */

  blocknr_T nt_new_bnum;                /* new, positive, number */
};

struct memfile {
  char_u      *mf_fname;                /* name of the file */
  char_u      *mf_ffname;               /* idem, full path */
  int mf_fd;                            /* file descriptor */
  bhdr_T      *mf_free_first;           /* first block_hdr in free list */
  bhdr_T      *mf_used_first;           /* mru block_hdr in used list */
  bhdr_T      *mf_used_last;            /* lru block_hdr in used list */
  unsigned mf_used_count;               /* number of pages in used list */
  unsigned mf_used_count_max;           /* maximum number of pages in memory */
  mf_hashtab_T mf_hash;                 /* hash lists */
  mf_hashtab_T mf_trans;                /* trans lists */
  blocknr_T mf_blocknr_max;             /* highest positive block number + 1*/
  blocknr_T mf_blocknr_min;             /* lowest negative block number - 1 */
  blocknr_T mf_neg_count;               /* number of negative blocks numbers */
  blocknr_T mf_infile_count;            /* number of pages in the file */
  unsigned mf_page_size;                /* number of bytes in a page */
  int mf_dirty;                         /* TRUE if there are dirty blocks */
};

#endif // NVIM_MEMFILE_DEFS_H
