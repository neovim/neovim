#ifndef NEOVIM_SHA256_H
#define NEOVIM_SHA256_H
/* sha256.c */
void sha256_start __ARGS((context_sha256_T *ctx));
void sha256_update __ARGS((context_sha256_T *ctx, char_u *input,
                           UINT32_T length));
void sha256_finish __ARGS((context_sha256_T *ctx, char_u digest[32]));
char_u *sha256_bytes __ARGS((char_u *buf, int buf_len, char_u *salt,
                             int salt_len));
char_u *sha256_key __ARGS((char_u *buf, char_u *salt, int salt_len));
int sha256_self_test __ARGS((void));
void sha2_seed __ARGS((char_u *header, int header_len, char_u *salt,
                       int salt_len));
/* vim: set ft=c : */
#endif /* NEOVIM_SHA256_H */
