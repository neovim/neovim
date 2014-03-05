#ifndef NEOVIM_CRYPT_H
#define NEOVIM_CRYPT_H

int crypt_method_from_string(char_u *s);
int get_crypt_method(buf_T *buf);
void set_crypt_method(buf_T *buf, int method);
void crypt_push_state(void);
void crypt_pop_state(void);
void crypt_encode(char_u *from, size_t len, char_u *to);
void crypt_decode(char_u *ptr, long len);
void crypt_init_keys(char_u *passwd);
void free_crypt_key(char_u *key);
char_u *get_crypt_key(int store, int twice);

#endif /* NEOVIM_CRYPT_H */
