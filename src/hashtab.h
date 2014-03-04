#ifndef NEOVIM_HASHTAB_H
#define NEOVIM_HASHTAB_H
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
/* vim: set ft=c : */
#endif /* NEOVIM_HASHTAB_H */
