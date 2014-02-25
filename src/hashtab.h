#ifndef NEOVIM_HASHTAB_H
#define NEOVIM_HASHTAB_H
/* hashtab.c */
void hash_init __ARGS((hashtab_T *ht));
void hash_clear __ARGS((hashtab_T *ht));
void hash_clear_all __ARGS((hashtab_T *ht, int off));
hashitem_T *hash_find __ARGS((hashtab_T *ht, char_u *key));
hashitem_T *hash_lookup __ARGS((hashtab_T *ht, char_u *key, hash_T hash));
void hash_debug_results __ARGS((void));
int hash_add __ARGS((hashtab_T *ht, char_u *key));
int hash_add_item __ARGS((hashtab_T *ht, hashitem_T *hi, char_u *key,
                          hash_T hash));
void hash_remove __ARGS((hashtab_T *ht, hashitem_T *hi));
void hash_lock __ARGS((hashtab_T *ht));
void hash_unlock __ARGS((hashtab_T *ht));
hash_T hash_hash __ARGS((char_u *key));
/* vim: set ft=c : */
#endif /* NEOVIM_HASHTAB_H */
