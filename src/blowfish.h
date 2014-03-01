#ifndef NEOVIM_BLOWFISH_H
#define NEOVIM_BLOWFISH_H
/* blowfish.c */
void bf_key_init(char_u *password, char_u *salt, int salt_len);
void bf_ofb_init(char_u *iv, int iv_len);
void bf_crypt_encode(char_u *from, size_t len, char_u *to);
void bf_crypt_decode(char_u *ptr, long len);
void bf_crypt_init_keys(char_u *passwd);
void bf_crypt_save(void);
void bf_crypt_restore(void);
int blowfish_self_test(void);
/* vim: set ft=c : */
#endif /* NEOVIM_BLOWFISH_H */
