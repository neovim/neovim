#ifndef NVIM_HASHTAB_H
#define NVIM_HASHTAB_H

/* Item for a hashtable.  "hi_key" can be one of three values:
 * NULL:	   Never been used
 * HI_KEY_REMOVED: Entry was removed
 * Otherwise:	   Used item, pointer to the actual key; this usually is
 *		   inside the item, subtract an offset to locate the item.
 *		   This reduces the size of hashitem by 1/3.
 */
typedef struct hashitem_S {
  long_u hi_hash;               /* cached hash number of hi_key */
  char_u      *hi_key;
} hashitem_T;

/* The address of "hash_removed" is used as a magic number for hi_key to
 * indicate a removed item. */
#define HI_KEY_REMOVED &hash_removed
#define HASHITEM_EMPTY(hi) ((hi)->hi_key == NULL || (hi)->hi_key == \
                            &hash_removed)

/* Initial size for a hashtable.  Our items are relatively small and growing
 * is expensive, thus use 16 as a start.  Must be a power of 2. */
#define HT_INIT_SIZE 16

typedef struct hashtable_S {
  long_u ht_mask;               /* mask used for hash value (nr of items in
                                 * array is "ht_mask" + 1) */
  long_u ht_used;               /* number of items used */
  long_u ht_filled;             /* number of items used + removed */
  int ht_locked;                /* counter for hash_lock() */
  int ht_error;                 /* when set growing failed, can't add more
                                   items before growing works */
  hashitem_T  *ht_array;        /* points to the array, allocated when it's
                                   not "ht_smallarray" */
  hashitem_T ht_smallarray[HT_INIT_SIZE];      /* initial array */
} hashtab_T;

typedef long_u hash_T;          /* Type for hi_hash */

/* hashtab.c */
void hash_init(hashtab_T *ht);
void hash_clear(hashtab_T *ht);
void hash_clear_all(hashtab_T *ht, int off);
hashitem_T *hash_find(hashtab_T *ht, char_u *key);
hashitem_T *hash_lookup(hashtab_T *ht, char_u *key, hash_T hash);
void hash_debug_results(void);
int hash_add(hashtab_T *ht, char_u *key);
int hash_add_item(hashtab_T *ht, hashitem_T *hi, char_u *key,
                  hash_T hash);
void hash_remove(hashtab_T *ht, hashitem_T *hi);
void hash_lock(hashtab_T *ht);
void hash_unlock(hashtab_T *ht);
hash_T hash_hash(char_u *key);

#endif /* NVIM_HASHTAB_H */
