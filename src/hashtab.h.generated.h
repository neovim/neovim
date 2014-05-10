hash_T hash_hash(char_u *key);
void hash_unlock(hashtab_T *ht);
void hash_lock(hashtab_T *ht);
void hash_remove(hashtab_T *ht, hashitem_T *hi);
int hash_add_item(hashtab_T *ht, hashitem_T *hi, char_u *key,
                  hash_T hash);
int hash_add(hashtab_T *ht, char_u *key);
void hash_debug_results(void);
hashitem_T *hash_lookup(hashtab_T *ht, char_u *key, hash_T hash);
hashitem_T *hash_find(hashtab_T *ht, char_u *key);
void hash_clear_all(hashtab_T *ht, int off);
void hash_clear(hashtab_T *ht);
void hash_init(hashtab_T *ht);
